import logging
import os
import time
from math import asin, cos, radians, sin, sqrt

import mysql.connector
from mysql.connector import Error
import numpy as np
import pandas as pd
from sklearn.cluster import DBSCAN

MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_DB = os.getenv("MYSQL_DB", "PharmaGuard")
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "Arya@ig9809")

SCAN_FETCH_LIMIT = int(os.getenv("SCAN_FETCH_LIMIT", "1000"))
POLL_INTERVAL_SECONDS = int(os.getenv("POLL_INTERVAL_SECONDS", "300"))
MAX_SPEED_KMH = float(os.getenv("MAX_SPEED_KMH", "900"))
DBSCAN_EPS_KM = float(os.getenv("DBSCAN_EPS_KM", "15"))
DBSCAN_MIN_SAMPLES = int(os.getenv("DBSCAN_MIN_SAMPLES", "4"))
ALERT_DEDUP_MINUTES = int(os.getenv("ALERT_DEDUP_MINUTES", "30"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger("ai-worker")


def get_connection():
    return mysql.connector.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        database=MYSQL_DB,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
    )


def haversine_km(lat1, lon1, lat2, lon2):
    if any(pd.isna(v) for v in [lat1, lon1, lat2, lon2]):
        return np.nan

    r = 6371.0088
    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
    c = 2 * asin(sqrt(a))
    return r * c


def load_recent_scans(conn) -> pd.DataFrame:
    query = """
        SELECT scan_id, batch_id, scanned_by, gps_lat, gps_long, scan_timestamp
        FROM SCAN_LOG
        ORDER BY scan_timestamp DESC
        LIMIT %s
    """
    cur = conn.cursor(dictionary=True)
    cur.execute(query, (SCAN_FETCH_LIMIT,))
    rows = cur.fetchall()
    cur.close()

    if not rows:
        return pd.DataFrame()

    df = pd.DataFrame(rows)
    df["scan_timestamp"] = pd.to_datetime(df["scan_timestamp"], errors="coerce")
    df = df.dropna(subset=["gps_lat", "gps_long", "scan_timestamp"])
    return df.sort_values("scan_timestamp").reset_index(drop=True)


def detect_anomalies(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df

    df = df.copy()

    df["prev_lat"] = df.groupby("scanned_by")["gps_lat"].shift(1)
    df["prev_long"] = df.groupby("scanned_by")["gps_long"].shift(1)
    df["prev_timestamp"] = df.groupby("scanned_by")["scan_timestamp"].shift(1)

    df["distance_km"] = df.apply(
        lambda row: haversine_km(row["prev_lat"], row["prev_long"], row["gps_lat"], row["gps_long"]),
        axis=1,
    )
    df["hours_delta"] = (
        (df["scan_timestamp"] - df["prev_timestamp"]).dt.total_seconds() / 3600.0
    )
    df["speed_kmh"] = df["distance_km"] / df["hours_delta"]

    impossible_velocity = (
        df["hours_delta"].notna()
        & (df["hours_delta"] > 0)
        & df["speed_kmh"].notna()
        & (df["speed_kmh"] > MAX_SPEED_KMH)
    )

    coords = np.radians(df[["gps_lat", "gps_long"]].to_numpy())
    if len(coords) >= DBSCAN_MIN_SAMPLES:
        dbscan = DBSCAN(
            eps=DBSCAN_EPS_KM / 6371.0088,
            min_samples=DBSCAN_MIN_SAMPLES,
            metric="haversine",
        )
        df["cluster"] = dbscan.fit_predict(coords)
        geo_outlier = df["cluster"] == -1
    else:
        geo_outlier = pd.Series([False] * len(df), index=df.index)

    anomaly_mask = impossible_velocity | geo_outlier
    anomalies = df[anomaly_mask].copy()

    if not anomalies.empty:
        logger.info(
            "Detected %s anomalies (velocity=%s, geo_outlier=%s)",
            len(anomalies),
            int(impossible_velocity.sum()),
            int(geo_outlier.sum()),
        )

    return anomalies


def write_alerts(conn, anomalies: pd.DataFrame) -> int:
    if anomalies.empty:
        return 0

    batch_ids = [int(x) for x in anomalies["batch_id"].dropna().unique().tolist()]
    if not batch_ids:
        return 0

    dedup_window = max(ALERT_DEDUP_MINUTES, 1)
    query = f"""
        INSERT INTO ALERT (batch_id, alert_type, severity)
        SELECT %s, 'Geo-Anomaly', 'High'
        FROM DUAL
        WHERE NOT EXISTS (
            SELECT 1
            FROM ALERT
            WHERE batch_id = %s
              AND alert_type = 'Geo-Anomaly'
              AND alert_timestamp > DATE_SUB(NOW(), INTERVAL {dedup_window} MINUTE)
        )
    """

    cur = conn.cursor()
    inserted = 0

    for batch_id in batch_ids:
        cur.execute(query, (batch_id, batch_id))
        inserted += cur.rowcount

    conn.commit()
    cur.close()
    return inserted


def run_once() -> None:
    conn = None
    try:
        conn = get_connection()
        scans = load_recent_scans(conn)
        if scans.empty:
            logger.info("No scan data available yet.")
            return

        anomalies = detect_anomalies(scans)
        inserted = write_alerts(conn, anomalies)

        if inserted:
            logger.warning("Inserted %s Geo-Anomaly alert(s).", inserted)
        else:
            logger.info("No new Geo-Anomaly alerts inserted.")

    except Error as exc:
        logger.exception("MySQL error: %s", exc)
    except Exception as exc:  # pragma: no cover
        logger.exception("Unhandled worker error: %s", exc)
    finally:
        if conn:
            conn.close()


def main() -> None:
    logger.info("AI anomaly worker started. Poll interval: %s seconds", POLL_INTERVAL_SECONDS)
    while True:
        run_once()
        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
