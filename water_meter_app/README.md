# Water Meter App

Cross-platform Flutter app (Android + iOS) for viewing water consumption statistics from a cloud REST API.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+
- Xcode (iOS) and/or Android Studio (Android)

## First-time setup

**macOS 12 note:** Flutter stable (3.41+) requires macOS 14+. On macOS 12, use Flutter **3.38.10** (e.g. via [FVM](https://fvm.app): `fvm use 3.38.10`).

```bash
cd v_switch_app/water_meter_app
flutter create . --project-name water_meter_app --org com.vswitch --platforms=android,ios,web
flutter pub get
```

## Run (mock auth + mock API + mock provisioning — default)

No AWS, Google, or physical device required:

```bash
flutter run
```

Flow:
1. Tap **Continue with Google** (mock sign-in)
2. Choose **Admin** (creates demo tenant) or **Read-only** (enter invite code `DEMO-1234`)
3. Land on **My Devices** (empty state if no devices yet)
4. Tap **Add your first device** or the **Add device** tile → pick device type
5. Each device tile shows live flow, today's usage vs quota, and an on/off switch — tap the tile for full stats (Dashboard / Usage / Insights / Control tabs)

## Water meter device setup

From **My Devices**, tap **Add a device** → **Water Meter**:

**Mock provisioning (default, `USE_MOCK_PROVISIONING=true`):** no hotspot or WiFi steps — a random serial is assigned and enrollment is simulated.

| Step | Action |
|------|--------|
| 1 Prepare | Confirm device is ready |
| 2 Name | Choose a label (e.g. `D205`); tap **Add device (mock)** |
| 3 Done | Device appears on My Devices |

**Real device provisioning** (`--dart-define=USE_MOCK_PROVISIONING=false`):

| Step | Action |
|------|--------|
| 1 Prepare | Confirm green LED; reset instructions if needed |
| 2 Connect | Join device hotspot `IoT_<serial>`; app validates SSID on return |
| 3 Home WiFi | Enter home WiFi credentials; POST to device at `192.168.4.1` |
| 4 Name | Choose a short label shown on the home tile |
| 5 Enroll | Rejoin home WiFi; POST `/enrollment/enroll` to `{serial}.local` |
| 6 Done | Device appears in My Devices as a tile with inline controls |

### Platform requirements

**Android:** Location permission (SSID read), WiFi settings access, cleartext HTTP to `192.168.4.1` and `*.local` (configured in `network_security_config.xml`).

**iOS:** Enable **Access WiFi Information** capability in Xcode (`Runner.entitlements`). Location and local network usage strings are in `Info.plist`. iOS cannot deep-link to the WiFi panel — users join `IoT_*` manually in Settings.

Logic mirrors the native [`v_switch_app`](../app/) enrollment clients (`WifiCredentialsClient`, `EnrollmentClient`).

## Run against AWS (production auth)

### 1. Deploy AWS infrastructure

See [`infrastructure/README.md`](infrastructure/README.md).

```bash
cd infrastructure
npm install
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
npm run deploy
```

### 2. Configure Google Cloud OAuth

1. Create OAuth clients: **Web** (for Cognito IdP), **Android**, **iOS**
2. Add redirect URI: `https://<CognitoDomain>/oauth2/idpresponse`
3. Android: package `com.vswitch.water_meter_app` + SHA-1 fingerprint
4. iOS: bundle ID + URL scheme `com.vswitch.watermeter`

### 3. Run Flutter app

```bash
flutter run \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=USE_MOCK_API=true \
  --dart-define=COGNITO_USER_POOL_ID=<UserPoolId> \
  --dart-define=COGNITO_CLIENT_ID=<UserPoolClientId> \
  --dart-define=COGNITO_DOMAIN=<domain>.auth.<region>.amazoncognito.com \
  --dart-define=COGNITO_REGION=us-east-1 \
  --dart-define=API_BASE_URL=<ApiUrl>
```

## Auth flow

| Step | Screen | Action |
|------|--------|--------|
| 1 | Sign in | Google OAuth via Cognito |
| 2 | Role selection | Admin or Read-only |
| 3a | (Admin) | Tenant auto-created in DynamoDB |
| 3b | (Read-only) | Enter invite code from admin |
| 4 | My Devices | Device list home; add or open a device |
| 5 | Device stats | Per-device Dashboard / Usage / Insights / Control |

### Tenant API (JWT required)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/me` | Current profile |
| POST | `/users/role` | Set role; admin auto-creates tenant |
| POST | `/tenants` | Create tenant (admin) |
| POST | `/tenants/join` | Join by invite code (read-only) |

Water usage API uses `Authorization: Bearer <Cognito ID token>`.

### Water device API (JWT required)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/devices/{id}/water/current` | Live flow reading |
| GET | `/devices/{id}/water/usage` | Time-series usage |
| GET | `/devices/{id}/water/daily` | Daily totals |
| GET | `/devices/{id}/water/hourly-pattern` | 24h pattern |
| GET | `/devices/{id}/water/valve` | Tap pressure state (target, actual, quota cap) |
| PUT | `/devices/{id}/water/valve` | Set pressure 0–100% or `{ "action": "restore" }` |
| GET | `/devices/{id}/water/quota` | Daily quota config + today's status |
| PUT | `/devices/{id}/water/quota` | Update quota rules (admin only) |

**Valve PUT:** `0` turns off (stores last pressure); `1–100` sets pressure; `restore` returns to last non-zero setpoint.

**Quota steps:** Each `reduce_pressure` step subtracts its `value` from 100% (cumulative). `turn_off` sets cap to 0%. Device/cloud enforces rules; app configures and displays status.

## Build

```bash
flutter build apk --release
flutter build web --release
```

## Tests

```bash
flutter test
```

## App structure

| Screen | Features |
|--------|----------|
| My Devices | Device tiles with live flow, quota progress, inline on/off switch |
| Device Dashboard | Live flow, today's total, delta vs previous period, hourly sparkline |
| Device Usage | Date presets, granularity chips, bar / cumulative charts |
| Device Insights | 7-day daily comparison, 24-hour usage pattern |
| Device Control | Tap on/off, pressure slider (0–100%), live pressure, daily quota progress and admin step editor |

Settings: account info, tenant ID, invite code (admin), sign out.
