# Water Meter App

Cross-platform Flutter app (Android + iOS) for viewing water consumption statistics from a cloud REST API.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+
- Xcode (iOS) and/or Android Studio (Android)

## First-time setup

If platform folders are missing, generate them without overwriting `lib/`:

```bash
cd v_switch_app/water_meter_app
flutter create . --project-name water_meter_app --org com.vswitch
flutter pub get
```

## Run (mock API — default)

Uses realistic demo data; no backend required:

```bash
flutter run
```

## Run against a real API

```bash
flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=https://api.example.com/v1
```

Enter your device ID and API key on the onboarding screen.

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

Settings (gear icon): volume unit, timezone, sign out.

## API contract

See the development plan for endpoint details:

- `GET /devices/{id}/water/current`
- `GET /devices/{id}/water/usage?from&to&granularity&timezone`
- `GET /devices/{id}/water/daily?from&to&timezone`
- `GET /devices/{id}/water/hourly-pattern?from&to&timezone`

Auth headers: `Authorization: Bearer <api_key>`, `X-Device-Id: <device_id>`
