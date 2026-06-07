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
3. View dashboard, usage, and insights

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
| 4 | Main app | Dashboard / Usage / Insights |

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

| Tab | Features |
|-----|----------|
| Dashboard | Live flow, today's total, delta vs previous period, hourly sparkline |
| Usage | Date presets, granularity chips, bar / cumulative charts |
| Insights | 7-day daily comparison, 24-hour usage pattern |

Settings: account info, tenant ID, invite code (admin), sign out.
