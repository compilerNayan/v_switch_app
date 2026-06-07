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

## Run (mock auth + mock API — default)

No AWS or Google setup required:

```bash
flutter run
```

Flow:
1. Tap **Continue with Google** (mock sign-in)
2. Choose **Admin** (creates demo tenant) or **Read-only** (enter invite code `DEMO-1234`)
3. Land on **My Devices** (empty state if no devices yet)
4. Tap **Add your first device** or **Add another device** → pick device type
5. Tap a device card to view its stats (Dashboard / Usage / Insights tabs)

## Water meter device setup

From **My Devices**, tap **Add a device** → **Water Meter**:

| Step | Action |
|------|--------|
| 1 Prepare | Confirm green LED; reset instructions if needed |
| 2 Connect | Join device hotspot `IoT_<serial>`; app validates SSID on return |
| 3 Home WiFi | Enter home WiFi credentials; POST to device at `192.168.4.1` |
| 4 Enroll | Rejoin home WiFi; POST `/enrollment/enroll` to `{serial}.local` |
| 5 Done | Device appears in My Devices; tap to view stats |

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
| 5 | Device stats | Per-device Dashboard / Usage / Insights |

### Tenant API (JWT required)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/me` | Current profile |
| POST | `/users/role` | Set role; admin auto-creates tenant |
| POST | `/tenants` | Create tenant (admin) |
| POST | `/tenants/join` | Join by invite code (read-only) |

Water usage API uses `Authorization: Bearer <Cognito ID token>`.

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
| My Devices | Owned device list, add another device |
| Device Dashboard | Live flow, today's total, delta vs previous period, hourly sparkline |
| Device Usage | Date presets, granularity chips, bar / cumulative charts |
| Device Insights | 7-day daily comparison, 24-hour usage pattern |

Settings: account info, tenant ID, invite code (admin), sign out.
