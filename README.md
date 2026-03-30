# MedTrack – Pharmaceutical Supply Chain Monitoring

End-to-end system for tracking medicine batches from manufacturer to pharmacy.
Includes a Flask REST API (Dockerised) and a Flutter mobile app.

---

## Repository layout

```
.
├── flask-api/          # Flask REST API (auth + role endpoints)
├── db_init/            # MySQL schema + seed SQL (auto-run by Docker Compose)
├── ai-worker/          # Background fraud-detection worker
├── mobile-app/         # Flutter mobile app (Android + iOS)
├── docker-compose.yml
└── .env.example
```

---

## Quick start – Backend (Docker Compose)

### 1. Copy environment file
```bash
cp .env.example .env
# Edit .env and set a strong JWT_SECRET for production
```

### 2. Start all services
```bash
docker compose up --build -d
```

This starts:
- **MySQL 8.4** on port `3307` (host) / `3306` (container)
- **Redis 7** (internal)
- **Flask API** on port `5000`
- **AI worker** (background fraud detector)

### 3. Seed the database (first run)
```bash
docker compose exec flask-api python seed.py
```

This creates:
- 1 **Admin** account: `admin@medtrack.local` / password: `admin_medtrack@MedTrack#2026`
- 3 **Manufacturers** (`mfg_1_*@medtrack.local`)
- 10 **Pharmacies** (`pharmacy_<city>_*@medtrack.local`)
- 500 batches, inventory, transfer history

### 4. Verify health
```bash
curl http://localhost:5000/health
# {"status": "ok"}
```

---

## API reference

### Auth (public)

| Method | Endpoint | Body |
|--------|----------|------|
| `POST` | `/api/auth/login` | `{ email, password, role }` |
| `POST` | `/api/auth/register/manufacturer` | `{ username, email, password, license_no, production_capacity? }` |
| `POST` | `/api/auth/register/pharmacy` | `{ username, email, password, pharmacy_license, address, city, state, pincode, gps_lat, gps_long }` |

**Login response:**
```json
{
  "token": "<JWT>",
  "role": "Pharmacy",
  "actor_id": 5,
  "pharmacy_id": 5,
  "username": "pharmacy_mumbai_1"
}
```

All protected routes require:
```
Authorization: Bearer <token>
```

### Manufacturer (role: `Manufacturer`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/api/manufacturer/batches` | List own batches |
| `POST` | `/api/manufacturer/batches` | Create batch (auto-generates SHA-256 QR hash) |
| `POST` | `/api/manufacturer/transfers` | Initiate transfer to pharmacy |

### Pharmacy (role: `Pharmacy`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/api/pharmacy/transfers/incoming` | List pending transfers |
| `POST` | `/api/pharmacy/transfers/<id>/accept` | Accept transfer + add to inventory |
| `POST` | `/api/pharmacy/transfers/<id>/reject` | Reject transfer |
| `GET`  | `/api/pharmacy/inventory` | List inventory |
| `POST` | `/api/scan_batch` | Scan QR & process sale |

### Admin (role: `Admin`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/api/admin/alerts` | List security alerts |
| `GET`  | `/api/admin/traceback?batch_id=<id>` | Full batch history |
| `POST` | `/api/admin/batches/<id>/status` | Set batch status (Active/WARNING/BLOCKED) |

---

## Flutter mobile app

### Prerequisites
- Flutter SDK ≥ 3.2.0 (`flutter --version`)
- Android Studio / Xcode (for device/emulator)

### Install dependencies
```bash
cd mobile-app
flutter pub get
```

### Configure API URL

The app auto-selects:
- Android emulator → `http://10.0.2.2:5000`
- iOS simulator  → `http://localhost:5000`

For a **physical device** or custom host, pass at build time:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:5000
```

### Run on emulator / device
```bash
cd mobile-app
flutter run
```

### App screens

**Public**
- Role selection screen
- Login screen per role (Manufacturer / Pharmacy / Admin)
- Registration screens (Manufacturer, Pharmacy with GPS capture)

**Manufacturer portal**
- Batch list
- Create batch (auto-generates QR hash)
- Initiate transfer to pharmacy

**Pharmacy portal**
- Incoming transfers (accept / reject)
- Inventory list
- QR scanner → process sale (calls `/api/scan_batch`)

**Admin portal**
- Security alerts feed
- Batch traceback (full chain of custody)
- Update batch status (Active / WARNING / BLOCKED)

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | `dev-secret-change-me` | **Change in production!** |
| `JWT_EXPIRES_HOURS` | `24` | Token lifetime |
| `CORS_ORIGINS` | `*` | Allowed CORS origins |
| `MYSQL_*` | see docker-compose | MySQL connection |
| `REDIS_*` | see docker-compose | Redis connection |
| `CACHE_TTL_SECONDS` | `900` | Scan result cache TTL |

---

## Security notes

- Admin accounts are **seed-only** – there is no public `/api/auth/register/admin` endpoint.
- Passwords are hashed with **Werkzeug** (PBKDF2-SHA256).
- JWTs are signed with HS256. Set a strong `JWT_SECRET` in production.
- Pharmacy GPS coordinates are stored permanently at registration and used for velocity anomaly detection.
