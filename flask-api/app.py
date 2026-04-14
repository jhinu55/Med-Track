import json
import os
from datetime import datetime, timezone

# REPLACE WITH / ADD TO:
from flask import Flask, jsonify, request
from flask_cors import CORS  # <-- ADD THIS IMPORT
import mysql.connector
from mysql.connector import Error, pooling
import redis

app = Flask(__name__)
CORS(app)  # <-- ADD THIS LINE

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "database": os.getenv("MYSQL_DB", "PharmaGuard"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "Arya@ig9809"),
}

MYSQL_POOL_SIZE = int(os.getenv("MYSQL_POOL_SIZE", "10"))
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "900"))
REDIS_URL = os.getenv("REDIS_URL", "").strip()

mysql_pool = pooling.MySQLConnectionPool(
    pool_name="medtrack_pool",
    pool_size=MYSQL_POOL_SIZE,
    pool_reset_session=True,
    **MYSQL_CONFIG,
)

def _build_redis_client() -> redis.Redis:
    """
    Priority:
    1. REDIS_URL (single URL, useful for managed Redis providers)
    2. REDIS_HOST/PORT/USERNAME/PASSWORD (+ REDIS_SSL)
    """
    if REDIS_URL:
        return redis.Redis.from_url(REDIS_URL, decode_responses=True)

    redis_kwargs = {
        "host": os.getenv("REDIS_HOST", "redis"),
        "port": int(os.getenv("REDIS_PORT", "6379")),
        "decode_responses": True,
    }

    redis_username = os.getenv("REDIS_USERNAME", "").strip()
    redis_password = os.getenv("REDIS_PASSWORD", "").strip()
    redis_ssl = os.getenv("REDIS_SSL", "false").strip().lower() in {"1", "true", "yes"}

    if redis_username:
        redis_kwargs["username"] = redis_username
    if redis_password:
        redis_kwargs["password"] = redis_password
    if redis_ssl:
        redis_kwargs["ssl"] = True

    return redis.Redis(**redis_kwargs)


redis_client = _build_redis_client()

BLOCKED_STATUSES = {"Expired", "Counterfeit"}


def _cache_key(qr_hash: str) -> str:
    return f"scan_batch:{qr_hash}"


def _read_cache(qr_hash: str) -> dict | None:
    if not redis_client:        # <-- ADD THIS CHECK
        return None             # <-- ADD THIS CHECK
    raw = redis_client.get(_cache_key(qr_hash))
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None

def _write_cache(qr_hash: str, payload: dict, ttl_seconds: int | None = None) -> None:
    if not redis_client:        # <-- ADD THIS CHECK
        return                  # <-- ADD THIS CHECK
    ttl = ttl_seconds if ttl_seconds is not None else CACHE_TTL_SECONDS
    redis_client.setex(_cache_key(qr_hash), ttl, json.dumps(payload))


def _int_required(value, field_name: str) -> int:
    if value is None:
        raise ValueError(f"Missing required field: {field_name}")
    try:
        ivalue = int(value)
    except (TypeError, ValueError):
        raise ValueError(f"Field '{field_name}' must be an integer") from None
    if ivalue <= 0:
        raise ValueError(f"Field '{field_name}' must be > 0")
    return ivalue


def _lookup_batch_by_hash(cursor, qr_hash: str) -> dict | None:
    cursor.execute(
        """
        SELECT
            b.batch_id
        FROM BATCH b
        WHERE b.qr_code_hash = %s
        LIMIT 1
        """,
        (qr_hash,),
    )
    return cursor.fetchone()


@app.get("/health")
def health() -> tuple:
    try:
        redis_client.ping()
        conn = mysql_pool.get_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
        cur.close()
        conn.close()
    except Exception as exc:  # pragma: no cover
        return jsonify({"status": "unhealthy", "error": str(exc)}), 500

    return jsonify({"status": "ok"}), 200


@app.post("/api/scan_batch")
def scan_batch() -> tuple:
    payload = request.get_json(silent=True) or {}

    qr_hash = payload.get("qr_hash")
    if not qr_hash:
        return jsonify({"error": "Field 'qr_hash' is required"}), 400

    try:
        pharmacy_id = _int_required(payload.get("pharmacy_id"), "pharmacy_id")
        quantity = _int_required(payload.get("quantity"), "quantity")
    except ValueError as err:
        return jsonify({"error": str(err)}), 400

    treatment_duration_days = payload.get("treatment_duration_days")
    if treatment_duration_days is not None:
        try:
            treatment_duration_days = int(treatment_duration_days)
        except (TypeError, ValueError):
            return jsonify({"error": "Field 'treatment_duration_days' must be an integer"}), 400

    override_reason = payload.get("override_reason")
    # Compatibility aliases if client sends shorter keys.
    if treatment_duration_days is None and payload.get("duration") is not None:
        try:
            treatment_duration_days = int(payload.get("duration"))
        except (TypeError, ValueError):
            return jsonify({"error": "Field 'duration' must be an integer"}), 400
    if not override_reason and payload.get("reason"):
        override_reason = payload.get("reason")

    has_override_justification = (
        treatment_duration_days is not None and bool(str(override_reason).strip())
    )

    cached = _read_cache(qr_hash)
    if cached and cached.get("status") == "Counterfeit":
        return (
            jsonify(
                {
                    "allowed": False,
                    "reason": "Counterfeit",
                    "source": "redis_cache",
                    "batch_id": cached.get("batch_id"),
                    "cached_at": cached.get("checked_at"),
                }
            ),
            403,
        )
    if cached and cached.get("status") == "Expired" and not has_override_justification:
        return (
            jsonify(
                {
                    "allowed": False,
                    "reason": "Expired",
                    "source": "redis_cache",
                    "batch_id": cached.get("batch_id"),
                    "cached_at": cached.get("checked_at"),
                }
            ),
            403,
        )

    conn = None
    meta_cursor = None
    proc_cursor = None
    batch_id = cached.get("batch_id") if cached else None

    try:
        conn = mysql_pool.get_connection()
        conn.start_transaction()

        if not batch_id:
            meta_cursor = conn.cursor(dictionary=True)
            batch_meta = _lookup_batch_by_hash(meta_cursor, qr_hash)

            if not batch_meta:
                return jsonify({"error": "Batch not found for provided qr_hash"}), 404

            batch_id = int(batch_meta["batch_id"])

        proc_cursor = conn.cursor()
        proc_cursor.callproc(
            "PROCESS_SALE",
            [
                pharmacy_id,
                int(batch_id),
                quantity,
                treatment_duration_days,
                override_reason,
            ],
        )

        conn.commit()

        cache_payload = {
            "status": "Valid",
            "batch_id": int(batch_id),
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }
        _write_cache(qr_hash, cache_payload)

        return (
            jsonify(
                {
                    "allowed": True,
                    "status": "Valid",
                    "source": "mysql",
                    "batch_id": int(batch_id),
                }
            ),
            200,
        )

    except Error as exc:
        if conn:
            conn.rollback()

        message = str(exc)
        lowered = message.lower()
        status = "Rejected"

        if "medicine is expired" in lowered:
            status = "Expired"
            if conn and batch_id:
                alert_cursor = conn.cursor()
                try:
                    alert_cursor.execute(
                        """
                        INSERT INTO ALERT (batch_id, alert_type, severity)
                        VALUES (%s, 'Expired-Attempt', 'High')
                        """,
                        (int(batch_id),),
                    )
                    conn.commit()
                finally:
                    alert_cursor.close()

            _write_cache(
                qr_hash,
                {
                    "status": "Expired",
                    "batch_id": int(batch_id) if batch_id else None,
                    "checked_at": datetime.now(timezone.utc).isoformat(),
                },
                ttl_seconds=3600,
            )
            return jsonify({"allowed": False, "status": status, "error": message}), 403

        if "counterfeit risk" in lowered:
            status = "Counterfeit"
            if conn and batch_id:
                alert_cursor = conn.cursor()
                try:
                    alert_cursor.execute(
                        """
                        INSERT INTO ALERT (batch_id, alert_type, severity)
                        VALUES (%s, 'Counterfeit-Flag', 'High')
                        """,
                        (int(batch_id),),
                    )
                    conn.commit()
                finally:
                    alert_cursor.close()

            _write_cache(
                qr_hash,
                {
                    "status": "Counterfeit",
                    "batch_id": int(batch_id) if batch_id else None,
                    "checked_at": datetime.now(timezone.utc).isoformat(),
                },
                ttl_seconds=86400,
            )
            return jsonify({"allowed": False, "status": status, "error": message}), 403

        return jsonify({"allowed": False, "status": status, "error": message}), 403

    finally:
        if meta_cursor:
            meta_cursor.close()
        if proc_cursor:
            proc_cursor.close()
        if conn:
            conn.close()

@app.post("/api/process_sale")
def api_process_sale() -> tuple:
    payload = request.get_json(silent=True) or {}
    
    # Extract values from the request payload
    pharmacy_id = payload.get("pharmacy_id")
    batch_id = payload.get("batch_id")
    quantity = payload.get("quantity")
    duration = payload.get("treatment_duration_days")
    reason = payload.get("override_reason")

    conn = None
    cur = None
    try:
        conn = mysql_pool.get_connection()
        conn.start_transaction()
        cur = conn.cursor()
        
        # Call the PROCESS_SALE stored procedure from 03_procedure.sql
        cur.callproc("PROCESS_SALE", [pharmacy_id, batch_id, quantity, duration, reason])
        
        conn.commit()
        return jsonify({"allowed": True, "status": "Success", "message": "Sale committed and inventory updated"}), 200
        
    except Error as exc:
        if conn:
            conn.rollback()
        return jsonify({"allowed": False, "status": "Rejected", "error": str(exc)}), 403
        
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

@app.post("/api/traceback")
def api_traceback() -> tuple:
    payload = request.get_json(silent=True) or {}
    batch_id = payload.get("batch_id")
    actor_id = payload.get("actor_id")

    conn = None
    cur = None
    try:
        conn = mysql_pool.get_connection()
        cur = conn.cursor(dictionary=True)
        
        # Call the TraceSupplyChain recursive procedure from recursive.sql
        cur.callproc("TraceSupplyChain", [batch_id, actor_id])
        
        # Fetch the recursive CTE results
        steps = []
        for result in cur.stored_results():
            steps.extend(result.fetchall())
            
        return jsonify({"status": "Success", "steps": steps}), 200
        
    except Error as exc:
        return jsonify({"status": "Error", "error": str(exc)}), 400
        
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

@app.get("/api/track/<batch_code>")
def track_batch(batch_code):
    # Clean the input (e.g., turn "B-4821" or "#B-4821" into just "4821")
    clean_id = ''.join(filter(str.isdigit, batch_code))
    if not clean_id:
        return jsonify({"error": "Invalid batch code format"}), 400

    conn = None
    cur = None
    try:
        conn = mysql_pool.get_connection()
        cur = conn.cursor(dictionary=True)
        
        # Fetch the details the Flutter app expects
        query = """
            SELECT 
                b.batch_id,
                b.qr_code_hash,
                b.mfg_date,
                b.expiry_date,
                m.generic_name,
                m.brand_name,
                a.username as owner_name,
                a.role_type
            FROM BATCH b
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            JOIN ACTOR a ON b.current_owner_id = a.actor_id
            WHERE b.batch_id = %s
        """
        cur.execute(query, (int(clean_id),))
        result = cur.fetchone()

        if not result:
            return jsonify({"error": "Batch not found"}), 404

        # Format the response exactly how customer_page.dart expects it
        response_data = {
            'name': f"{result['generic_name']} ({result['brand_name']})",
            'manufacturer': "MediCorp Ltd." if result['role_type'] != 'Manufacturer' else result['owner_name'],
            'pharmacy': result['owner_name'] if result['role_type'] == 'Pharmacy' else "In-Transit",
            'batchCode': f"B-{result['batch_id']}",
            'status': 'Verified Safe' if result['expiry_date'] >= datetime.now().date() else 'Expired/Warning',
            'manufacturedDate': result['mfg_date'].strftime('%Y-%m-%d'),
            'expiryDate': result['expiry_date'].strftime('%Y-%m-%d'),
        }

        return jsonify(response_data), 200

    except Error as exc:
        return jsonify({"error": str(exc)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.post("/api/login")
def login_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Missing credentials"}), 400

    conn = None
    cur = None
    try:
        conn = mysql_pool.get_connection()
        cur = conn.cursor(dictionary=True)
        
        # Query the ACTOR table to check credentials
        query = """
            SELECT actor_id, username, role_type 
            FROM ACTOR 
            WHERE username = %s AND password_hash = %s
        """
        cur.execute(query, (username, password))
        user = cur.fetchone()

        if user:
            return jsonify({
                "status": "success", 
                "actor_id": user['actor_id'],
                "username": user['username'],
                "role": user['role_type'] 
            }), 200
        else:
            return jsonify({"status": "error", "message": "Invalid username or password"}), 401

    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
    finally:
        if cur: cur.close()
        if conn: conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
