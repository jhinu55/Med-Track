# MedTrack Backend

This repository contains the MedTrack backend stack:

- `mysql` (schema + procedures + triggers from `db_init/`)
- `redis` (scan + auth session cache)
- `flask-api` (REST API)
- `ai-worker` (background anomaly detector)

## Run Locally

```bash
docker compose down
docker compose up -d --build
docker compose ps
```

Health check:

```bash
curl -i http://localhost:5000/health
```

## Seed Test Data

```bash
docker compose exec -T flask-api python seed.py
```

This prints deterministic test values:

- `test_pharmacy_id=5`
- `valid_qr_hash=aee0123f3d9add033107ec2d0aba9dff5c2020597aa00452589b89051ec34e18`
- `expired_qr_hash=de5ae70aea72411679de10f2d69044decf10edda05d4934127dcc17c85b18813`

## API Endpoints

### Auth

- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/auth/me`

Login request:

```json
{
  "email": "admin@medtrack.local",
  "password": "admin_medtrack@MedTrack#2026"
}
```

Login response returns `token` + `user` role.  
Use it in subsequent requests:

`Authorization: Bearer <token>`

Register request:

```json
{
  "name": "Priya Sharma",
  "email": "priya.sharma@example.com",
  "password": "SecurePass123",
  "role": "Pharmacy"
}
```

### Scan

- `POST /api/scan_batch`

Happy path:

```json
{
  "qr_hash": "aee0123f3d9add033107ec2d0aba9dff5c2020597aa00452589b89051ec34e18",
  "pharmacy_id": 5,
  "quantity": 1
}
```

Expired without override (should return `403`):

```json
{
  "qr_hash": "de5ae70aea72411679de10f2d69044decf10edda05d4934127dcc17c85b18813",
  "pharmacy_id": 5,
  "quantity": 1
}
```

Expired with override (should return `200`):

```json
{
  "qr_hash": "de5ae70aea72411679de10f2d69044decf10edda05d4934127dcc17c85b18813",
  "pharmacy_id": 5,
  "quantity": 1,
  "treatment_duration_days": 10,
  "override_reason": "Doctor approved completion of ongoing course"
}
```

## Database Security (RBAC + Secure Views)

Database-level hardening is defined in:

- `db_init/06_security.sql`

This script adds:

- `Secure views`
- `vw_manufacturer_production` (hides downstream ownership details)
- `vw_pharmacy_public_inventory` (exposes stock status, not exact quantity)
- `vw_global_threat_dashboard` (masks GPS to city-level precision)
- `Roles`
- `role_medtrack_admin`
- `role_medtrack_manufacturer`
- `role_medtrack_pharmacy`
- Least-privilege grants for each role (including procedure execute permissions)

If your MySQL volume was already initialized before adding this file, run it manually:

```bash
docker compose exec -T mysql mysql -uroot -proot PharmaGuard < db_init/06_security.sql
```

Quick verification:

```bash
docker compose exec -T mysql mysql -uroot -proot -D PharmaGuard -e "SHOW FULL TABLES WHERE Table_type='VIEW'; SHOW GRANTS FOR role_medtrack_admin; SHOW GRANTS FOR role_medtrack_manufacturer; SHOW GRANTS FOR role_medtrack_pharmacy;"
```

## Config

Copy env template and customize if needed:

```bash
cp .env.example .env
```

Important env vars:

- `CACHE_TTL_SECONDS` (default scan cache TTL)
- `AUTH_TOKEN_TTL_SECONDS` (auth token TTL, default `43200` seconds)
