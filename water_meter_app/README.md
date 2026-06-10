# Water Monitor App

Cross-platform Flutter app for apartment admins to monitor and control water consumption across many units.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+
- Xcode (iOS) and/or Android Studio (Android)

## First-time setup

```bash
cd v_switch_app/water_meter_app
flutter pub get
```

## Run (mock mode — default)

```bash
/tmp/flutter-sdk/bin/flutter run
```

1. **Sign up** or **Sign in** (mock email/password; confirmation code `123456`)
2. Sign-up creates your building tenant automatically
3. **Building** home — portfolio summary, searchable unit grid, alerts
4. Tap a unit → Dashboard / Usage / Insights / Control (admin only)

### Access model

- **One tenant per owner** — sign-up includes building name and creates your tenant
- All users are **admins**
- **Additional admins** join with an owner-generated admin invite code
- **Meter invite codes** are generated per unit (resident onboarding is future work)

## Add a water meter

**Mock provisioning (default):** Prepare → Name → Add device (mock). No WiFi/device required.

**Real provisioning:** `--dart-define=USE_MOCK_PROVISIONING=false` — full hotspot/WiFi/enroll flow.

## Features

### Building overview
- Total usage today / this month, online/offline counts
- Top consumers, search, filter (flowing, quota, offline, alerts), sort

### Per unit
- Live flow, quota bar, valve switch, health (last seen)
- Edit metadata: flat, floor, wing, resident, notes, maintenance mode

### Alerts (in-app + local push)
- Quota warning/exceeded, possible leak, unusual spike, offline, valve mismatch
- Inbox at `/alerts`; preferences in Settings

### Policies (admin)
- Quota templates (apply to all units)
- Emergency shutoff
- Night pressure schedule

### Billing reports
- Tariff (₹/L configurable in Settings)
- Monthly report + CSV export

### Audit log
- Valve, quota, template, shutoff, unit edit events
- Filter + CSV export

### Insights
- Unit vs building average, anomaly cards, month-over-month

## Settings

- Theme (5 palettes), volume unit, timezone
- Billing tariff, alert preferences
- Links to audit log and policies

## Build

```bash
/tmp/flutter-sdk/bin/flutter build apk --release
```

## Tests

```bash
/tmp/flutter-sdk/bin/flutter test
```

## Backend API contract

The app is mock-first today. Most tenant/building data lives in local storage; device telemetry uses `/devices/{id}/water/*` when `USE_MOCK_API=false`.

**Full REST API specification:** [docs/API.md](docs/API.md)

Covers:
- Auth, tenant onboarding, and user profile
- Water unit inventory (CRUD, invite codes, resident phone)
- Building summary and top-consumer rankings
- Device telemetry, valve, and quota (8 endpoints — already implemented in client)
- Alerts, audit log, policies, billing/tariff
- Bulk operations, push tokens, caching notes

## Run against real Cognito + Lambda API

```bash
chmod +x scripts/run_with_cognito.sh
./scripts/run_with_cognito.sh
```

Or manually:

```bash
flutter run \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=https://udil78wxzb.execute-api.ap-south-1.amazonaws.com/Prod \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r \
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1 \
  --dart-define=COGNITO_REGION=ap-south-1
```

## Push notifications (production)

Add `google-services.json` (Android) and enable Firebase; mock mode uses `flutter_local_notifications` only.
