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

1. **Sign in** (mock Google)
2. Choose role: **Admin**, **Resident**, or **Maintenance**
3. **Building** home — portfolio summary, searchable unit grid, alerts
4. Tap a unit → Dashboard / Usage / Insights / Control (admin only)

### Roles

| Role | Access |
|------|--------|
| Admin | Full building overview, controls, policies, reports, audit |
| Resident | Own unit only (usage + insights, read-only) |
| Maintenance | Building view, valve control on assigned units |

Invite codes: building `DEMO-1234`; per-unit codes generated on enroll (e.g. `D205-1234`).

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

## Future cloud API (mock-first today)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/tenants/{id}/building/summary` | Building totals |
| GET | `/tenants/{id}/building/rankings` | Usage rankings |
| GET | `/tenants/{id}/alerts` | Alert events |
| GET | `/tenants/{id}/audit` | Audit log |
| POST | `/users/me/push-token` | FCM registration |

Water device API unchanged: `/devices/{id}/water/*`

## Push notifications (production)

Add `google-services.json` (Android) and enable Firebase; mock mode uses `flutter_local_notifications` only.
