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
- `GET /api/auth/me`

Login request:

```json
{
  "username": "admin_medtrack",
  "password": "admin_medtrack@MedTrack#2026"
}
```

Login response returns `token` + `user` role.  
Use it in subsequent requests:

`Authorization: Bearer <token>`

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

## Config

Copy env template and customize if needed:

```bash
cp .env.example .env
```

Important env vars:

- `CACHE_TTL_SECONDS` (default scan cache TTL)
- `AUTH_TOKEN_TTL_SECONDS` (auth token TTL, default `43200` seconds)
