"""
MedTrack Flask API
------------------
Endpoints
  Public :
    GET  /health
    POST /api/auth/login
    POST /api/auth/register/manufacturer
    POST /api/auth/register/pharmacy

  Manufacturer (JWT, role=Manufacturer) :
    GET  /api/manufacturer/batches
    POST /api/manufacturer/batches
    POST /api/manufacturer/transfers

  Pharmacy (JWT, role=Pharmacy) :
    GET  /api/pharmacy/transfers/incoming
    POST /api/pharmacy/transfers/<id>/accept
    POST /api/pharmacy/transfers/<id>/reject
    GET  /api/pharmacy/inventory
    POST /api/scan_batch

  Admin (JWT, role=Admin) :
    GET  /api/admin/alerts
    GET  /api/admin/traceback
    POST /api/admin/batches/<id>/status
"""

from __future__ import annotations

import hashlib
import json
import os
import uuid
from datetime import datetime, timedelta, timezone
from functools import wraps

import jwt
from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error, pooling
import redis
from werkzeug.security import check_password_hash, generate_password_hash

# ---------------------------------------------------------------------------
# App + CORS
# ---------------------------------------------------------------------------

app = Flask(__name__)

CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")
CORS(app, origins=CORS_ORIGINS)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_HOURS = int(os.getenv("JWT_EXPIRES_HOURS", "24"))

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "mysql"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "database": os.getenv("MYSQL_DB", "PharmaGuard"),
    "user": os.getenv("MYSQL_USER", "medtrack"),
    "password": os.getenv("MYSQL_PASSWORD", "medtrack123"),
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

# ---------------------------------------------------------------------------
# Redis
# ---------------------------------------------------------------------------


def _build_redis_client() -> redis.Redis:
    if REDIS_URL:
        return redis.Redis.from_url(REDIS_URL, decode_responses=True)

    redis_kwargs: dict = {
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

# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------


def _create_token(payload: dict) -> str:
    data = dict(payload)
    data["exp"] = datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRES_HOURS)
    data["iat"] = datetime.now(timezone.utc)
    return jwt.encode(data, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _decode_token(token: str) -> dict:
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def require_auth(*roles: str):
    """Decorator that verifies JWT and optionally enforces role membership."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            auth_header = request.headers.get("Authorization", "")
            if not auth_header.startswith("Bearer "):
                return jsonify({"error": "Missing or invalid Authorization header"}), 401
            token = auth_header[len("Bearer "):]
            try:
                payload = _decode_token(token)
            except jwt.ExpiredSignatureError:
                return jsonify({"error": "Token expired"}), 401
            except jwt.InvalidTokenError:
                return jsonify({"error": "Invalid token"}), 401

            if roles and payload.get("role") not in roles:
                return jsonify({"error": "Forbidden: insufficient role"}), 403

            request.jwt_payload = payload  # type: ignore[attr-defined]
            return fn(*args, **kwargs)

        return wrapper

    return decorator


# ---------------------------------------------------------------------------
# DB / cache helpers
# ---------------------------------------------------------------------------


def _cache_key(qr_hash: str) -> str:
    return f"scan_batch:{qr_hash}"


def _read_cache(qr_hash: str) -> dict | None:
    raw = redis_client.get(_cache_key(qr_hash))
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _write_cache(qr_hash: str, payload: dict, ttl_seconds: int | None = None) -> None:
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
        "SELECT batch_id FROM BATCH WHERE qr_code_hash = %s LIMIT 1",
        (qr_hash,),
    )
    return cursor.fetchone()


# ---------------------------------------------------------------------------
# Public – health
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# Auth – login
# ---------------------------------------------------------------------------


@app.post("/api/auth/login")
def auth_login() -> tuple:
    body = request.get_json(silent=True) or {}
    email = (body.get("email") or "").strip()
    password = body.get("password") or ""
    role = (body.get("role") or "").strip()

    if not email or not password or not role:
        return jsonify({"error": "email, password and role are required"}), 400

    if role not in ("Manufacturer", "Pharmacy", "Admin"):
        return jsonify({"error": "role must be Manufacturer, Pharmacy or Admin"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(
            "SELECT actor_id, username, password_hash, role_type FROM ACTOR "
            "WHERE email = %s AND role_type = %s LIMIT 1",
            (email, role),
        )
        actor = cur.fetchone()
    finally:
        cur.close()
        conn.close()

    if not actor:
        return jsonify({"error": "Invalid credentials"}), 401

    if not check_password_hash(actor["password_hash"], password):
        return jsonify({"error": "Invalid credentials"}), 401

    actor_id = int(actor["actor_id"])
    payload: dict = {
        "actor_id": actor_id,
        "role": role,
        "username": actor["username"],
    }

    # Fetch role-specific id
    conn2 = mysql_pool.get_connection()
    cur2 = conn2.cursor(dictionary=True)
    try:
        if role == "Manufacturer":
            cur2.execute(
                "SELECT actor_id AS manufacturer_id FROM MANUFACTURER WHERE actor_id = %s",
                (actor_id,),
            )
            row = cur2.fetchone()
            if row:
                payload["manufacturer_id"] = int(row["manufacturer_id"])
        elif role == "Pharmacy":
            cur2.execute(
                "SELECT actor_id AS pharmacy_id FROM PHARMACY WHERE actor_id = %s",
                (actor_id,),
            )
            row = cur2.fetchone()
            if row:
                payload["pharmacy_id"] = int(row["pharmacy_id"])
        elif role == "Admin":
            cur2.execute(
                "SELECT actor_id AS admin_id FROM ADMIN WHERE actor_id = %s",
                (actor_id,),
            )
            row = cur2.fetchone()
            if row:
                payload["admin_id"] = int(row["admin_id"])
    finally:
        cur2.close()
        conn2.close()

    token = _create_token(payload)
    return jsonify({"token": token, **payload}), 200


# ---------------------------------------------------------------------------
# Auth – register manufacturer
# ---------------------------------------------------------------------------


@app.post("/api/auth/register/manufacturer")
def register_manufacturer() -> tuple:
    body = request.get_json(silent=True) or {}
    username = (body.get("username") or "").strip()
    email = (body.get("email") or "").strip()
    password = body.get("password") or ""
    license_no = (body.get("license_no") or "").strip()
    production_capacity = body.get("production_capacity")

    if not username or not email or not password or not license_no:
        return jsonify({"error": "username, email, password, license_no are required"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor()
    try:
        conn.start_transaction()
        pw_hash = generate_password_hash(password)
        cur.execute(
            "INSERT INTO ACTOR (username, password_hash, email, role_type) VALUES (%s,%s,%s,'Manufacturer')",
            (username, pw_hash, email),
        )
        actor_id = int(cur.lastrowid)
        cap = int(production_capacity) if production_capacity is not None else None
        cur.execute(
            "INSERT INTO MANUFACTURER (actor_id, license_no, production_capacity) VALUES (%s,%s,%s)",
            (actor_id, license_no, cap),
        )
        conn.commit()
    except Error as exc:
        conn.rollback()
        msg = str(exc)
        if "Duplicate entry" in msg:
            return jsonify({"error": "username or email or license_no already exists"}), 409
        return jsonify({"error": msg}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"actor_id": actor_id, "manufacturer_id": actor_id, "role": "Manufacturer"}), 201


# ---------------------------------------------------------------------------
# Auth – register pharmacy
# ---------------------------------------------------------------------------


@app.post("/api/auth/register/pharmacy")
def register_pharmacy() -> tuple:
    body = request.get_json(silent=True) or {}
    username = (body.get("username") or "").strip()
    email = (body.get("email") or "").strip()
    password = body.get("password") or ""
    pharmacy_license = (body.get("pharmacy_license") or "").strip()
    address = (body.get("address") or "").strip()
    city = (body.get("city") or "").strip()
    state = (body.get("state") or "").strip()
    pincode = (body.get("pincode") or "").strip()

    gps_lat = body.get("gps_lat")
    gps_long = body.get("gps_long")

    if not username or not email or not password or not pharmacy_license:
        return jsonify({"error": "username, email, password, pharmacy_license are required"}), 400
    if gps_lat is None or gps_long is None:
        return jsonify({"error": "gps_lat and gps_long are required"}), 400

    try:
        gps_lat = float(gps_lat)
        gps_long = float(gps_long)
    except (TypeError, ValueError):
        return jsonify({"error": "gps_lat and gps_long must be numeric"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor()
    try:
        conn.start_transaction()
        pw_hash = generate_password_hash(password)
        cur.execute(
            "INSERT INTO ACTOR (username, password_hash, email, role_type) VALUES (%s,%s,%s,'Pharmacy')",
            (username, pw_hash, email),
        )
        actor_id = int(cur.lastrowid)
        cur.execute(
            """INSERT INTO PHARMACY (actor_id, pharmacy_license, gps_lat, gps_long,
                                     address, city, state, pincode)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
            (actor_id, pharmacy_license, gps_lat, gps_long, address, city, state, pincode),
        )
        conn.commit()
    except Error as exc:
        conn.rollback()
        msg = str(exc)
        if "Duplicate entry" in msg:
            return jsonify({"error": "username or email or pharmacy_license already exists"}), 409
        return jsonify({"error": msg}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"actor_id": actor_id, "pharmacy_id": actor_id, "role": "Pharmacy"}), 201


# ---------------------------------------------------------------------------
# Manufacturer – batches
# ---------------------------------------------------------------------------


@app.get("/api/manufacturer/batches")
@require_auth("Manufacturer")
def list_manufacturer_batches() -> tuple:
    manufacturer_id = request.jwt_payload.get("manufacturer_id")  # type: ignore[attr-defined]
    if not manufacturer_id:
        return jsonify({"error": "manufacturer_id missing from token"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(
            """
            SELECT b.batch_id, b.qr_code_hash, b.mfg_date, b.expiry_date,
                   b.batch_status, b.current_owner_id,
                   m.generic_name, m.brand_name
            FROM BATCH b
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            WHERE b.current_owner_id = %s
               OR b.batch_id IN (
                   SELECT DISTINCT batch_id FROM TRANSFER_LOG WHERE sender_id = %s
               )
            ORDER BY b.batch_id DESC
            """,
            (manufacturer_id, manufacturer_id),
        )
        batches = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    for row in batches:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    return jsonify(batches), 200


@app.post("/api/manufacturer/batches")
@require_auth("Manufacturer")
def create_batch() -> tuple:
    manufacturer_id = request.jwt_payload.get("manufacturer_id")  # type: ignore[attr-defined]
    body = request.get_json(silent=True) or {}

    medicine_id = body.get("medicine_id")
    mfg_date = body.get("mfg_date")
    expiry_date = body.get("expiry_date")

    if not medicine_id or not mfg_date or not expiry_date:
        return jsonify({"error": "medicine_id, mfg_date, expiry_date are required"}), 400

    qr_hash = hashlib.sha256(
        f"{manufacturer_id}-{medicine_id}-{mfg_date}-{expiry_date}-{uuid.uuid4().hex}".encode()
    ).hexdigest()

    conn = mysql_pool.get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO BATCH (medicine_id, qr_code_hash, mfg_date, expiry_date, current_owner_id)
               VALUES (%s, %s, %s, %s, %s)""",
            (medicine_id, qr_hash, mfg_date, expiry_date, manufacturer_id),
        )
        batch_id = int(cur.lastrowid)
        conn.commit()
    except Error as exc:
        conn.rollback()
        return jsonify({"error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"batch_id": batch_id, "qr_code_hash": qr_hash}), 201


# ---------------------------------------------------------------------------
# Manufacturer – transfers
# ---------------------------------------------------------------------------


@app.post("/api/manufacturer/transfers")
@require_auth("Manufacturer")
def create_transfer() -> tuple:
    manufacturer_id = request.jwt_payload.get("manufacturer_id")  # type: ignore[attr-defined]
    body = request.get_json(silent=True) or {}
    batch_id = body.get("batch_id")
    receiver_id = body.get("receiver_id")  # pharmacy actor_id

    if not batch_id or not receiver_id:
        return jsonify({"error": "batch_id and receiver_id are required"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT batch_id FROM BATCH WHERE batch_id = %s AND current_owner_id = %s",
            (batch_id, manufacturer_id),
        )
        if not cur.fetchone():
            return jsonify({"error": "Batch not found or not owned by this manufacturer"}), 404

        cur.execute(
            """INSERT INTO TRANSFER_LOG (batch_id, sender_id, receiver_id, status)
               VALUES (%s, %s, %s, 'Initiated')""",
            (batch_id, manufacturer_id, receiver_id),
        )
        transfer_id = int(cur.lastrowid)
        conn.commit()
    except Error as exc:
        conn.rollback()
        return jsonify({"error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"transfer_id": transfer_id, "status": "Initiated"}), 201


# ---------------------------------------------------------------------------
# Pharmacy – incoming transfers
# ---------------------------------------------------------------------------


@app.get("/api/pharmacy/transfers/incoming")
@require_auth("Pharmacy")
def list_incoming_transfers() -> tuple:
    pharmacy_id = request.jwt_payload.get("pharmacy_id")  # type: ignore[attr-defined]

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(
            """
            SELECT tl.transfer_id, tl.batch_id, tl.sender_id, tl.transfer_date, tl.status,
                   a.username AS sender_username,
                   b.qr_code_hash, b.expiry_date,
                   m.generic_name, m.brand_name
            FROM TRANSFER_LOG tl
            JOIN ACTOR a ON tl.sender_id = a.actor_id
            JOIN BATCH b ON tl.batch_id = b.batch_id
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            WHERE tl.receiver_id = %s AND tl.status IN ('Initiated', 'In-Transit')
            ORDER BY tl.transfer_date DESC
            """,
            (pharmacy_id,),
        )
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    return jsonify(rows), 200


@app.post("/api/pharmacy/transfers/<int:transfer_id>/accept")
@require_auth("Pharmacy")
def accept_transfer(transfer_id: int) -> tuple:
    pharmacy_id = request.jwt_payload.get("pharmacy_id")  # type: ignore[attr-defined]
    body = request.get_json(silent=True) or {}
    quantity = body.get("quantity", 0)

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()
        cur.execute(
            "SELECT * FROM TRANSFER_LOG WHERE transfer_id = %s AND receiver_id = %s FOR UPDATE",
            (transfer_id, pharmacy_id),
        )
        transfer = cur.fetchone()
        if not transfer:
            conn.rollback()
            return jsonify({"error": "Transfer not found"}), 404
        if transfer["status"] not in ("Initiated", "In-Transit"):
            conn.rollback()
            return jsonify({"error": "Transfer already processed"}), 409

        batch_id = int(transfer["batch_id"])
        sender_id = int(transfer["sender_id"])

        cur.execute(
            "UPDATE TRANSFER_LOG SET status = 'Received' WHERE transfer_id = %s",
            (transfer_id,),
        )
        cur.execute(
            "UPDATE BATCH SET current_owner_id = %s WHERE batch_id = %s",
            (pharmacy_id, batch_id),
        )
        cur.execute(
            """INSERT INTO INVENTORY (pharmacy_id, batch_id, quantity_on_hand)
               VALUES (%s, %s, %s)
               ON DUPLICATE KEY UPDATE quantity_on_hand = quantity_on_hand + VALUES(quantity_on_hand)""",
            (pharmacy_id, batch_id, int(quantity)),
        )
        conn.commit()
    except Error as exc:
        conn.rollback()
        return jsonify({"error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"transfer_id": transfer_id, "status": "Received"}), 200


@app.post("/api/pharmacy/transfers/<int:transfer_id>/reject")
@require_auth("Pharmacy")
def reject_transfer(transfer_id: int) -> tuple:
    pharmacy_id = request.jwt_payload.get("pharmacy_id")  # type: ignore[attr-defined]

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()
        cur.execute(
            "SELECT * FROM TRANSFER_LOG WHERE transfer_id = %s AND receiver_id = %s FOR UPDATE",
            (transfer_id, pharmacy_id),
        )
        transfer = cur.fetchone()
        if not transfer:
            conn.rollback()
            return jsonify({"error": "Transfer not found"}), 404
        if transfer["status"] not in ("Initiated", "In-Transit"):
            conn.rollback()
            return jsonify({"error": "Transfer already processed"}), 409

        cur.execute(
            "UPDATE TRANSFER_LOG SET status = 'Rejected' WHERE transfer_id = %s",
            (transfer_id,),
        )
        conn.commit()
    except Error as exc:
        conn.rollback()
        return jsonify({"error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"transfer_id": transfer_id, "status": "Rejected"}), 200


# ---------------------------------------------------------------------------
# Pharmacy – inventory
# ---------------------------------------------------------------------------


@app.get("/api/pharmacy/inventory")
@require_auth("Pharmacy")
def list_pharmacy_inventory() -> tuple:
    pharmacy_id = request.jwt_payload.get("pharmacy_id")  # type: ignore[attr-defined]

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(
            """
            SELECT i.batch_id, i.quantity_on_hand, i.last_updated,
                   b.qr_code_hash, b.mfg_date, b.expiry_date, b.batch_status,
                   m.generic_name, m.brand_name, m.base_price
            FROM INVENTORY i
            JOIN BATCH b ON i.batch_id = b.batch_id
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            WHERE i.pharmacy_id = %s
            ORDER BY b.expiry_date ASC
            """,
            (pharmacy_id,),
        )
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()
            elif hasattr(v, "__str__") and not isinstance(v, (str, int, float, bool, type(None))):
                row[k] = str(v)

    return jsonify(rows), 200


# ---------------------------------------------------------------------------
# Pharmacy – scan batch (existing endpoint, now auth-aware)
# ---------------------------------------------------------------------------


@app.post("/api/scan_batch")
@require_auth("Pharmacy")
def scan_batch() -> tuple:
    payload = request.get_json(silent=True) or {}
    jwt_p = request.jwt_payload  # type: ignore[attr-defined]

    qr_hash = payload.get("qr_hash")
    if not qr_hash:
        return jsonify({"error": "Field 'qr_hash' is required"}), 400

    # Use pharmacy_id from token if not provided in body
    pharmacy_id_body = payload.get("pharmacy_id")
    if pharmacy_id_body is None:
        pharmacy_id_body = jwt_p.get("pharmacy_id")

    try:
        pharmacy_id = _int_required(pharmacy_id_body, "pharmacy_id")
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
    if treatment_duration_days is None and payload.get("duration") is not None:
        try:
            treatment_duration_days = int(payload.get("duration"))
        except (TypeError, ValueError):
            return jsonify({"error": "Field 'duration' must be an integer"}), 400
    if not override_reason and payload.get("reason"):
        override_reason = payload.get("reason")

    has_override_justification = (
        treatment_duration_days is not None and bool((override_reason or "").strip())
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
                        "INSERT INTO ALERT (batch_id, alert_type, severity) VALUES (%s, 'Expired-Attempt', 'High')",
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
                        "INSERT INTO ALERT (batch_id, alert_type, severity) VALUES (%s, 'Counterfeit-Flag', 'High')",
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


# ---------------------------------------------------------------------------
# Admin – alerts
# ---------------------------------------------------------------------------


@app.get("/api/admin/alerts")
@require_auth("Admin")
def list_alerts() -> tuple:
    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(
            """
            SELECT a.alert_id, a.batch_id, a.alert_type, a.severity, a.alert_timestamp,
                   b.qr_code_hash, b.batch_status,
                   m.generic_name, m.brand_name
            FROM ALERT a
            JOIN BATCH b ON a.batch_id = b.batch_id
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            ORDER BY a.alert_timestamp DESC
            LIMIT 500
            """
        )
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    for row in rows:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    return jsonify(rows), 200


# ---------------------------------------------------------------------------
# Admin – traceback
# ---------------------------------------------------------------------------


@app.get("/api/admin/traceback")
@require_auth("Admin")
def traceback_batch() -> tuple:
    batch_id = request.args.get("batch_id")
    qr_hash = request.args.get("qr_hash")

    if not batch_id and not qr_hash:
        return jsonify({"error": "batch_id or qr_hash query param required"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor(dictionary=True)
    try:
        if not batch_id:
            cur.execute(
                "SELECT batch_id FROM BATCH WHERE qr_code_hash = %s LIMIT 1", (qr_hash,)
            )
            row = cur.fetchone()
            if not row:
                return jsonify({"error": "Batch not found"}), 404
            batch_id = row["batch_id"]

        cur.execute(
            """
            SELECT b.batch_id, b.qr_code_hash, b.mfg_date, b.expiry_date, b.batch_status,
                   m.generic_name, m.brand_name,
                   a.username AS current_owner
            FROM BATCH b
            JOIN MEDICINE m ON b.medicine_id = m.medicine_id
            JOIN ACTOR a ON b.current_owner_id = a.actor_id
            WHERE b.batch_id = %s
            """,
            (batch_id,),
        )
        batch = cur.fetchone()
        if not batch:
            return jsonify({"error": "Batch not found"}), 404

        cur.execute(
            """
            SELECT tl.transfer_id, tl.sender_id, tl.receiver_id, tl.transfer_date, tl.status,
                   s.username AS sender_username, r.username AS receiver_username
            FROM TRANSFER_LOG tl
            JOIN ACTOR s ON tl.sender_id = s.actor_id
            JOIN ACTOR r ON tl.receiver_id = r.actor_id
            WHERE tl.batch_id = %s
            ORDER BY tl.transfer_date ASC
            """,
            (batch_id,),
        )
        transfers = cur.fetchall()

        cur.execute(
            """
            SELECT sl.scan_id, sl.scanned_by, sl.gps_lat, sl.gps_long, sl.scan_timestamp,
                   a.username AS scanned_by_username
            FROM SCAN_LOG sl
            JOIN ACTOR a ON sl.scanned_by = a.actor_id
            WHERE sl.batch_id = %s
            ORDER BY sl.scan_timestamp ASC
            """,
            (batch_id,),
        )
        scans = cur.fetchall()

        cur.execute(
            "SELECT * FROM ALERT WHERE batch_id = %s ORDER BY alert_timestamp DESC",
            (batch_id,),
        )
        alerts = cur.fetchall()

    finally:
        cur.close()
        conn.close()

    def _serialize(rows):
        result = []
        for row in rows:
            r = {}
            for k, v in row.items():
                r[k] = v.isoformat() if hasattr(v, "isoformat") else v
            result.append(r)
        return result

    for k, v in batch.items():
        if hasattr(v, "isoformat"):
            batch[k] = v.isoformat()

    return jsonify(
        {
            "batch": batch,
            "transfers": _serialize(transfers),
            "scans": _serialize(scans),
            "alerts": _serialize(alerts),
        }
    ), 200


# ---------------------------------------------------------------------------
# Admin – update batch status
# ---------------------------------------------------------------------------


@app.post("/api/admin/batches/<int:batch_id>/status")
@require_auth("Admin")
def update_batch_status(batch_id: int) -> tuple:
    body = request.get_json(silent=True) or {}
    new_status = (body.get("status") or "").strip()
    if new_status not in ("Active", "WARNING", "BLOCKED"):
        return jsonify({"error": "status must be Active, WARNING or BLOCKED"}), 400

    conn = mysql_pool.get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE BATCH SET batch_status = %s WHERE batch_id = %s",
            (new_status, batch_id),
        )
        if cur.rowcount == 0:
            return jsonify({"error": "Batch not found"}), 404
        conn.commit()
    except Error as exc:
        conn.rollback()
        return jsonify({"error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"batch_id": batch_id, "status": new_status}), 200


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
