import json
import os
import hashlib
import secrets
import random
import re
from datetime import datetime, timezone

from flask import Flask, jsonify, request
import psycopg2
from psycopg2 import Error
from psycopg2.extras import RealDictCursor
import redis
from routes.medicine_ai import medicine_ai_bp

app = Flask(__name__)
app.register_blueprint(medicine_ai_bp)

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
PGHOST = os.getenv("PGHOST", "")
PGPORT = int(os.getenv("PGPORT", "5432"))
PGDATABASE = os.getenv("PGDATABASE", "postgres")
PGUSER = os.getenv("PGUSER", "postgres")
PGPASSWORD = os.getenv("PGPASSWORD", "")
DB_SSLMODE = os.getenv("DB_SSLMODE", "require")

CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "900"))
AUTH_TOKEN_TTL_SECONDS = int(os.getenv("AUTH_TOKEN_TTL_SECONDS", "43200"))
REDIS_URL = os.getenv("REDIS_URL", "").strip()


def _get_db_connection():
    if DATABASE_URL:
        return psycopg2.connect(DATABASE_URL)

    if not PGHOST:
        raise ValueError("Database connection is not configured. Set DATABASE_URL or PGHOST.")

    return psycopg2.connect(
        host=PGHOST,
        port=PGPORT,
        dbname=PGDATABASE,
        user=PGUSER,
        password=PGPASSWORD,
        sslmode=DB_SSLMODE,
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


def _auth_cache_key(token: str) -> str:
    return f"auth_token:{token}"


def _hash_password(plain_password: str) -> str:
    return hashlib.sha256(plain_password.encode("utf-8")).hexdigest()


def _normalize_role(role: str) -> str | None:
    role_map = {
        "admin": "Admin",
        "administrator": "Admin",
        "manufacturer": "Manufacturer",
        "pharmacy": "Pharmacy",
        "customer": "Customer",
    }
    key = (role or "").strip().lower()
    return role_map.get(key)


def _slugify_username_seed(raw: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_]+", "_", raw or "").strip("_").lower()
    if not cleaned:
        cleaned = "user"
    return cleaned[:32]


def _generate_unique_username(cur, seed: str) -> str:
    base = _slugify_username_seed(seed)
    for _ in range(30):
        suffix = secrets.token_hex(2)
        candidate = f"{base}_{suffix}"[:50]
        cur.execute("SELECT 1 FROM ACTOR WHERE username = %s LIMIT 1", (candidate,))
        if not cur.fetchone():
            return candidate

    return f"user_{secrets.token_hex(6)}"[:50]


def _generate_unique_code(cur, table: str, column: str, prefix: str, width: int = 10) -> str:
    for _ in range(40):
        candidate = f"{prefix}-{secrets.token_hex(width // 2).upper()}"
        cur.execute(f"SELECT 1 FROM {table} WHERE {column} = %s LIMIT 1", (candidate,))
        if not cur.fetchone():
            return candidate
    return f"{prefix}-{secrets.token_hex(8).upper()}"


def _default_pharmacy_coords() -> tuple[float, float]:
    # Broad spread for mock setup; callers may still provide explicit coords.
    anchors = [
        (19.0760, 72.8777),  # Mumbai
        (28.6139, 77.2090),  # Delhi
        (12.9716, 77.5946),  # Bengaluru
        (17.3850, 78.4867),  # Hyderabad
        (13.0827, 80.2707),  # Chennai
    ]
    lat, lng = random.choice(anchors)
    return round(lat + random.uniform(-0.05, 0.05), 8), round(lng + random.uniform(-0.05, 0.05), 8)


def _build_auth_response(actor: dict) -> tuple:
    token = secrets.token_urlsafe(32)
    now_iso = datetime.now(timezone.utc).isoformat()
    session_payload = {
        "actor_id": int(actor["actor_id"]),
        "username": actor["username"],
        "email": actor["email"],
        "role": actor["role_type"],
        "issued_at": now_iso,
    }
    _write_auth_session(token, session_payload)

    return (
        jsonify(
            {
                "token": token,
                "token_type": "Bearer",
                "expires_in": AUTH_TOKEN_TTL_SECONDS,
                "user": {
                    "actor_id": int(actor["actor_id"]),
                    "username": actor["username"],
                    "email": actor["email"],
                    "role": actor["role_type"],
                },
            }
        ),
        200,
    )


def _write_auth_session(token: str, payload: dict) -> None:
    redis_client.setex(_auth_cache_key(token), AUTH_TOKEN_TTL_SECONDS, json.dumps(payload))


def _read_auth_session(token: str) -> dict | None:
    raw = redis_client.get(_auth_cache_key(token))
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _extract_bearer_token() -> str | None:
    auth_header = request.headers.get("Authorization", "").strip()
    if not auth_header:
        return None

    parts = auth_header.split(" ", 1)
    if len(parts) != 2:
        return None

    scheme, token = parts
    if scheme.lower() != "bearer":
        return None

    token = token.strip()
    return token or None


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
    conn = None
    cur = None
    try:
        redis_client.ping()
        conn = _get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
    except Exception as exc:  # pragma: no cover
        return jsonify({"status": "unhealthy", "error": str(exc)}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return jsonify({"status": "ok"}), 200


@app.post("/api/auth/login")
def auth_login() -> tuple:
    payload = request.get_json(silent=True) or {}
    login_id = (payload.get("username") or payload.get("email") or "").strip()
    password = payload.get("password") or ""

    if not login_id or not password:
        return jsonify({"error": "Fields 'username/email' and 'password' are required"}), 400

    conn = None
    cur = None
    try:
        conn = _get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            """
            SELECT actor_id, username, email, role_type, password_hash
            FROM ACTOR
            WHERE username = %s OR email = %s
            LIMIT 1
            """,
            (login_id, login_id),
        )
        actor = cur.fetchone()
    except Error as exc:
        return jsonify({"error": f"Database error during login: {exc}"}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if not actor:
        return jsonify({"error": "Invalid username or password"}), 401

    if actor["password_hash"] != _hash_password(password):
        return jsonify({"error": "Invalid username or password"}), 401

    return _build_auth_response(actor)


@app.post("/api/auth/register")
def auth_register() -> tuple:
    payload = request.get_json(silent=True) or {}
    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""
    role_input = (payload.get("role") or "").strip()

    if not name or not email or not password or not role_input:
        return jsonify({"error": "Fields 'name', 'email', 'password', and 'role' are required"}), 400
    if "@" not in email:
        return jsonify({"error": "Invalid email format"}), 400
    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400

    role_type = _normalize_role(role_input)
    if not role_type:
        return jsonify({"error": "Invalid role. Use Admin, Manufacturer, Pharmacy, or Customer"}), 400

    conn = None
    cur = None
    actor_row = None
    try:
        conn = _get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("SELECT 1 FROM ACTOR WHERE email = %s LIMIT 1", (email,))
        if cur.fetchone():
            conn.rollback()
            return jsonify({"error": "Email already registered"}), 409

        username_seed = payload.get("username") or email.split("@")[0] or name
        username = _generate_unique_username(cur, username_seed)
        password_hash = _hash_password(password)

        cur.execute(
            """
            INSERT INTO ACTOR (username, password_hash, email, role_type)
            VALUES (%s, %s, %s, %s)
            RETURNING actor_id
            """,
            (username, password_hash, email, role_type),
        )
        actor_id = int(cur.fetchone()["actor_id"])

        if role_type == "Admin":
            clearance = int(payload.get("security_clearance_level") or 1)
            cur.execute(
                """
                INSERT INTO ADMIN (actor_id, security_clearance_level)
                VALUES (%s, %s)
                """,
                (actor_id, max(clearance, 1)),
            )
        elif role_type == "Manufacturer":
            license_no = _generate_unique_code(cur, "MANUFACTURER", "license_no", "MFG-LIC")
            production_capacity = int(payload.get("production_capacity") or 50000)
            cur.execute(
                """
                INSERT INTO MANUFACTURER (actor_id, license_no, production_capacity)
                VALUES (%s, %s, %s)
                """,
                (actor_id, license_no, production_capacity),
            )
        elif role_type == "Pharmacy":
            pharmacy_license = _generate_unique_code(cur, "PHARMACY", "pharmacy_license", "PHR")
            if payload.get("gps_lat") is not None and payload.get("gps_long") is not None:
                gps_lat = float(payload["gps_lat"])
                gps_long = float(payload["gps_long"])
            else:
                gps_lat, gps_long = _default_pharmacy_coords()

            cur.execute(
                """
                INSERT INTO PHARMACY (actor_id, pharmacy_license, gps_lat, gps_long)
                VALUES (%s, %s, %s, %s)
                """,
                (actor_id, pharmacy_license, gps_lat, gps_long),
            )
        elif role_type == "Customer":
            cur.execute(
                """
                INSERT INTO CUSTOMER (actor_id, phone_number, device_id)
                VALUES (%s, %s, %s)
                """,
                (
                    actor_id,
                    (payload.get("phone_number") or None),
                    (payload.get("device_id") or None),
                ),
            )

        cur.execute(
            """
            SELECT actor_id, username, email, role_type
            FROM ACTOR
            WHERE actor_id = %s
            LIMIT 1
            """,
            (actor_id,),
        )
        actor_row = cur.fetchone()
        conn.commit()

    except ValueError as exc:
        if conn:
            conn.rollback()
        return jsonify({"error": str(exc)}), 400
    except Error as exc:
        if conn:
            conn.rollback()
        if getattr(exc, "pgcode", None) == "23505":
            return jsonify({"error": "User already exists with duplicate unique field"}), 409
        return jsonify({"error": f"Database error during registration: {exc}"}), 500
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if not actor_row:
        return jsonify({"error": "Failed to create user"}), 500

    return _build_auth_response(actor_row)


@app.get("/api/auth/me")
def auth_me() -> tuple:
    token = _extract_bearer_token()
    if not token:
        return jsonify({"error": "Missing bearer token"}), 401

    session = _read_auth_session(token)
    if not session:
        return jsonify({"error": "Invalid or expired token"}), 401

    return (
        jsonify(
            {
                "user": {
                    "actor_id": session.get("actor_id"),
                    "username": session.get("username"),
                    "email": session.get("email"),
                    "role": session.get("role"),
                }
            }
        ),
        200,
    )


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
        conn = _get_db_connection()

        if not batch_id:
            meta_cursor = conn.cursor(cursor_factory=RealDictCursor)
            batch_meta = _lookup_batch_by_hash(meta_cursor, qr_hash)

            if not batch_meta:
                return jsonify({"error": "Batch not found for provided qr_hash"}), 404

            batch_id = int(batch_meta["batch_id"])

        proc_cursor = conn.cursor()
        proc_cursor.execute(
            "SELECT process_sale(%s, %s, %s, %s, %s)",
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
                    "source": "postgres",
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


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
