# MedTrack Backend (Supabase + Redis)

This repository now runs with:

- `Supabase Postgres` (primary database)
- `redis` (scan + auth session cache)
- `flask-api` (REST API)
- `ai-worker` (background anomaly detector)

## 1) Bootstrap Supabase Schema

Run the SQL in [`supabase/01_schema.sql`](supabase/01_schema.sql) inside your Supabase SQL Editor.

## 2) Configure Environment

```bash
cp .env.example .env
```

Set at least:

- `PGPASSWORD` (your Supabase DB password)
- `GEMINI_API_KEY` (required for `/api/medicine/*` routes)

If you prefer a single connection string, set `DATABASE_URL` and you can leave `PG*` vars empty.
If direct `db.<project-ref>.supabase.co` is unreachable from your network (IPv6-only routing issue), use the Supabase pooler host and pooled username format (`postgres.<project_ref>`) on port `6543`.

## 3) Run Locally

```bash
docker compose down
docker compose up -d --build
docker compose ps
```

Health check:

```bash
curl -i http://localhost:5000/health
```

## 4) Seed Test Data

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

## Notes

- `db_init/` still contains legacy MySQL scripts for reference.
- Active Supabase bootstrap SQL is under `supabase/`.
