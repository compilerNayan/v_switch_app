# Water Monitor App — REST API Contract

This document lists every REST API the app expects from the backend. It is derived from the current Flutter client (`lib/core/api/`, models, and providers).

**Base URL:** `https://api.example.com/v1` (configurable via `API_BASE_URL` dart-define)

**Authentication:** All cloud endpoints require:

```
Authorization: Bearer <Cognito ID token>
```

**Error response** (4xx/5xx):

```json
{
  "error": {
    "code": "QUOTA_NOT_FOUND",
    "message": "Human-readable description"
  }
}
```

Alternate top-level shape also accepted: `{ "code": "...", "message": "..." }`.

**Roles:** `admin` | `readonly` (resident) | `maintenance`

| Role | Scope |
|------|-------|
| `admin` | Full tenant: all units, controls, policies, reports, audit |
| `readonly` | Assigned unit(s) only — read usage/insights |
| `maintenance` | Building view; valve control on `maintainableUnitIds` |

---

## Implementation status

| Area | Status in app today | HTTP client |
|------|---------------------|-------------|
| Auth / user / tenant onboarding | Partial — `TenantApiClient` (mock auth shortcuts) | `tenant_api_client.dart` |
| Device water telemetry & control | Implemented — `DioWaterApiClient` | `dio_water_api_client.dart` |
| Water units (inventory) | **Local only** (`PreferencesStorage`) | Needed |
| Building summary & rankings | **Computed client-side** | Needed |
| Alerts | **Local only** (client-generated) | Needed |
| Audit log | **Local only** | Needed |
| Quota templates & schedules | **Local only** | Needed |
| Tariff / billing | **Local only** | Needed |
| Push token registration | Stub | Needed |
| Device provisioning (WiFi/enroll) | Device LAN HTTP | Not cloud |

---

## 1. User & tenant

### GET `/users/me`

Returns the authenticated user's profile.

**Response 200:**

```json
{
  "userId": "usr_abc123",
  "email": "admin@building.com",
  "displayName": "Building Admin",
  "role": "admin",
  "tenantId": "tenant_xyz",
  "inviteCode": "DEMO-1234",
  "onboardingComplete": true,
  "assignedUnitIds": [],
  "maintainableUnitIds": ["unit-1", "unit-2"]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `role` | string? | `admin` \| `readonly` \| `maintenance`; null before role selection |
| `tenantId` | string? | Building/apartment complex ID |
| `inviteCode` | string? | Building invite code (admin only) |
| `assignedUnitIds` | string[] | Resident: units they can view |
| `maintainableUnitIds` | string[] | Maintenance: units they can control |

---

### POST `/users/role`

Set role during onboarding.

**Request:**

```json
{ "role": "admin" }
```

**Response 200:**

```json
{
  "tenantId": "tenant_xyz",
  "inviteCode": "DEMO-1234",
  "role": "admin",
  "requiresInviteCode": false
}
```

For `readonly`, server may return `requiresInviteCode: true` until join completes.

---

### POST `/tenants`

Create a new building/tenant (admin onboarding).

**Request:** `{}`

**Response 201:**

```json
{
  "tenantId": "tenant_xyz",
  "inviteCode": "DEMO-1234"
}
```

---

### POST `/tenants/join`

Join an existing building via invite code.

**Request:**

```json
{ "inviteCode": "DEMO-1234" }
```

**Response 200:**

```json
{
  "tenantId": "tenant_xyz",
  "role": "readonly"
}
```

Optional: accept unit-scoped invite and return `assignedUnitIds`.

---

### POST `/tenants/join/unit` *(recommended — not yet in client)*

Join a specific unit via per-unit invite code (generated at enrollment).

**Request:**

```json
{ "unitInviteCode": "D205-1234" }
```

**Response 200:**

```json
{
  "tenantId": "tenant_xyz",
  "role": "readonly",
  "assignedUnitIds": ["wm-WM000001"]
}
```

---

### GET `/users/me/preferences` *(optional)*

User-scoped UI settings. Can remain on-device; include if multi-device sync is needed.

**Response 200:**

```json
{
  "volumeUnit": "liters",
  "timezone": "Asia/Kolkata",
  "appTheme": "ocean",
  "alertPreferences": {
    "enabledTypes": ["quotaWarning", "quotaExceeded", "possibleLeak"],
    "quietHoursEnabled": false,
    "quietStartHour": 22,
    "quietEndHour": 7,
    "pushEnabled": true
  },
  "topConsumersConfig": {
    "showOverall": true,
    "showByBlock": true,
    "showByWing": true,
    "topCount": 5,
    "wingViewBlock": "A"
  }
}
```

### PATCH `/users/me/preferences`

Partial update of the above object.

---

### POST `/users/me/push-token`

Register FCM device token for remote push.

**Request:**

```json
{
  "token": "fcm-device-token",
  "platform": "android"
}
```

**Response 204:** No content.

---

## 2. Water units (inventory)

Currently stored locally in `PreferencesStorage`. **Backend should be source of truth** in production.

### GET `/tenants/{tenantId}/units`

List all units in the building. Filtered by role server-side (resident sees assigned only).

**Query (optional):**

| Param | Description |
|-------|-------------|
| `block` | Filter by block |
| `wing` | Filter by wing |
| `search` | Name, flat, device ID |

**Response 200:**

```json
{
  "units": [
    {
      "id": "wm-WM000001",
      "name": "D205",
      "deviceId": "WM000001",
      "flatNumber": "D205",
      "floor": "2",
      "wing": "East",
      "block": "A",
      "residentName": "Ravi Kumar",
      "phoneNumber": "+919876543210",
      "notes": null,
      "maintenanceMode": false,
      "assignedUserIds": ["usr_resident1"],
      "unitInviteCode": "D205-1234"
    }
  ]
}
```

---

### POST `/tenants/{tenantId}/units`

Register a new water meter after device enrollment.

**Request:**

```json
{
  "deviceId": "WM000001",
  "name": "D205",
  "flatNumber": "D205",
  "block": "A",
  "wing": "East",
  "floor": "2"
}
```

**Response 201:** Full `WaterUnit` object (server assigns `id`, `unitInviteCode`).

---

### GET `/tenants/{tenantId}/units/{unitId}`

**Response 200:** Single `WaterUnit` object.

---

### PATCH `/tenants/{tenantId}/units/{unitId}`

Update unit metadata (admin).

**Request** (partial):

```json
{
  "name": "D205",
  "flatNumber": "D205",
  "floor": "2",
  "wing": "East",
  "block": "A",
  "residentName": "Ravi Kumar",
  "phoneNumber": "+919876543210",
  "notes": "Corner flat",
  "maintenanceMode": false
}
```

**Response 200:** Updated `WaterUnit`.

Server should append an audit event for metadata changes.

---

### DELETE `/tenants/{tenantId}/units/{unitId}`

Decommission a unit. **Response 204.**

---

### POST `/tenants/{tenantId}/units/{unitId}/invite-codes`

Regenerate per-unit resident invite code.

**Response 200:**

```json
{ "unitInviteCode": "D205-5678" }
```

---

## 3. Building overview

Currently aggregated client-side by `MockBuildingApiClient`. Recommended for performance at scale.

### GET `/tenants/{tenantId}/building/summary`

**Response 200:**

```json
{
  "totalTodayLiters": 12450.5,
  "totalMonthLiters": 312000.0,
  "unitsOnline": 42,
  "unitsOffline": 3,
  "unitsTotal": 45,
  "activeAlerts": 7,
  "topConsumers": [
    { "unitId": "wm-1", "name": "D205", "liters": 180.5 }
  ]
}
```

---

### GET `/tenants/{tenantId}/building/rankings`

**Query:**

| Param | Values | Default |
|-------|--------|---------|
| `period` | `today` \| `week` \| `month` | `today` |
| `block` | Block filter (optional) | — |
| `wing` | Wing filter (optional) | — |
| `limit` | Max results per group | 10 |

**Response 200:**

```json
{
  "rankings": [
    {
      "unitId": "wm-1",
      "name": "D205",
      "liters": 180.5,
      "quotaPercent": 0.36,
      "block": "A",
      "wing": "East"
    }
  ]
}
```

The app's top-consumers dashboard can use this endpoint instead of N per-device usage calls.

---

## 4. Device water API

Implemented in `DioWaterApiClient`. All paths under `/devices/{deviceId}/water/`.

The server must verify the caller has access to `deviceId` (tenant membership + role).

### GET `/devices/{deviceId}/water/current`

Live reading for unit tile and dashboard.

**Response 200:**

```json
{
  "deviceId": "WM000001",
  "timestamp": "2026-06-08T10:30:00Z",
  "flowRateLpm": 2.3,
  "cumulativeLiters": 15420.5,
  "status": "flowing"
}
```

`status`: `flowing` | `idle` | `offline` | `leak_suspected`

---

### GET `/devices/{deviceId}/water/usage`

Time-series usage for charts.

**Query:**

| Param | Format | Example |
|-------|--------|---------|
| `from` | ISO8601 UTC | `2026-06-01T00:00:00Z` |
| `to` | ISO8601 UTC | `2026-06-08T23:59:59Z` |
| `granularity` | `1m` \| `5m` \| `15m` \| `30m` \| `1h` \| `1d` | `1h` |
| `timezone` | IANA | `Asia/Kolkata` |

**Response 200:**

```json
{
  "deviceId": "WM000001",
  "from": "2026-06-01T00:00:00Z",
  "to": "2026-06-08T23:59:59Z",
  "granularity": "1h",
  "unit": "liters",
  "dataPoints": [
    {
      "timestamp": "2026-06-08T09:00:00Z",
      "volumeLiters": 12.5,
      "avgFlowRateLpm": 0.8
    }
  ],
  "summary": {
    "totalVolumeLiters": 450.0,
    "averagePerBucketLiters": 18.75,
    "peakBucket": { "timestamp": "2026-06-08T07:00:00Z", "volumeLiters": 45.0 },
    "previousPeriodTotalLiters": 420.0,
    "deltaPercent": 7.1
  }
}
```

---

### GET `/devices/{deviceId}/water/daily`

Daily totals for reports and insights.

**Query:** `from`, `to` (YYYY-MM-DD), `timezone`

**Response 200:**

```json
{
  "unit": "liters",
  "days": [
    {
      "date": "2026-06-08",
      "totalLiters": 85.0,
      "peakHour": 7,
      "peakHourLiters": 22.0
    }
  ]
}
```

---

### GET `/devices/{deviceId}/water/hourly-pattern`

Average consumption by hour-of-day (insights).

**Query:** `from`, `to` (YYYY-MM-DD), `timezone`

**Response 200:**

```json
{
  "unit": "liters",
  "hours": [
    { "hour": 0, "avgLiters": 0.5 },
    { "hour": 7, "avgLiters": 18.2 }
  ]
}
```

---

### GET `/devices/{deviceId}/water/valve`

**Response 200:**

```json
{
  "deviceId": "WM000001",
  "timestamp": "2026-06-08T10:30:00Z",
  "targetPressurePercent": 100,
  "actualPressurePercent": 98,
  "lastUserPressurePercent": 100,
  "isOff": false,
  "controlMode": "manual",
  "quotaCapPercent": null,
  "effectivePressurePercent": 98
}
```

`controlMode`: `manual` | `quota`

---

### PUT `/devices/{deviceId}/water/valve`

Admin/maintenance valve control. Server writes audit event.

**Request** (one or both fields):

```json
{ "pressurePercent": 75 }
```

```json
{ "action": "restore" }
```

`pressurePercent: 0` = shut off. **Response 200:** Updated `ValveState`.

---

### GET `/devices/{deviceId}/water/quota`

**Response 200:**

```json
{
  "deviceId": "WM000001",
  "enabled": true,
  "dailyLimitLiters": 500,
  "timezone": "Asia/Kolkata",
  "steps": [
    { "atLitersUsed": 300, "action": "reduce_pressure", "value": 20 },
    { "atLitersUsed": 500, "action": "turn_off" }
  ],
  "status": {
    "date": "2026-06-08",
    "usedLiters": 180,
    "activeStepIndex": 0,
    "quotaCapPercent": 80,
    "remainingLiters": 320,
    "nextStepAtLiters": 300
  }
}
```

Step `action`: `reduce_pressure` (requires `value` = percent points to subtract) | `turn_off`

---

### PUT `/devices/{deviceId}/water/quota`

**Request:**

```json
{
  "enabled": true,
  "dailyLimitLiters": 500,
  "steps": [
    { "atLitersUsed": 300, "action": "reduce_pressure", "value": 20 },
    { "atLitersUsed": 500, "action": "turn_off" }
  ]
}
```

**Response 200:** Updated `QuotaResponse`.

---

## 5. Bulk device operations *(recommended)*

Today the app loops per unit for template apply and emergency shutoff. Bulk endpoints reduce latency.

### POST `/tenants/{tenantId}/policies/apply-template`

**Request:**

```json
{
  "templateId": "standard",
  "unitIds": ["wm-1", "wm-2"]
}
```

Or inline template body matching `QuotaTemplate`. **Response 200:**

```json
{ "appliedCount": 42, "failedUnitIds": [] }
```

---

### POST `/tenants/{tenantId}/policies/emergency-shutoff`

**Request:**

```json
{ "unitIds": ["wm-1", "wm-2"] }
```

Shuts off all valves. **Response 200:** `{ "shutoffCount": 42 }`

---

## 6. Alerts

Today generated client-side by `AlertEvaluator`. Production: server-side rules engine + push.

### GET `/tenants/{tenantId}/alerts`

**Query:**

| Param | Description |
|-------|-------------|
| `unresolved` | `true` — only open alerts |
| `unitId` | Filter by unit |
| `since` | ISO8601 — pagination cursor |
| `limit` | Default 50 |

**Response 200:**

```json
{
  "alerts": [
    {
      "id": "alert-1",
      "unitId": "wm-1",
      "unitName": "D205",
      "type": "quotaWarning",
      "message": "Used 85% of daily quota",
      "timestamp": "2026-06-08T10:00:00Z",
      "isRead": false,
      "isResolved": false
    }
  ]
}
```

`type`: `quotaWarning` | `quotaExceeded` | `possibleLeak` | `unusualSpike` | `deviceOffline` | `valveMismatch`

---

### PATCH `/tenants/{tenantId}/alerts/{alertId}`

Mark read or resolved.

**Request:**

```json
{ "isRead": true, "isResolved": true }
```

**Response 200:** Updated `AlertEvent`.

---

## 7. Audit log

Today stored locally. Production: server records all mutations.

### GET `/tenants/{tenantId}/audit`

**Query:** `from`, `to` (ISO8601), `unitId`, `action`, `limit` (default 100, max 500)

**Response 200:**

```json
{
  "events": [
    {
      "id": "audit-1",
      "timestamp": "2026-06-08T09:15:00Z",
      "actorEmail": "admin@building.com",
      "action": "valveOff",
      "unitId": "wm-1",
      "unitName": "D205",
      "details": "Emergency shutoff"
    }
  ]
}
```

`action`: `valveOff` | `valveOn` | `quotaUpdate` | `templateApply` | `emergencyShutoff` | `unitEdit` | `maintenanceMode` | `scheduleUpdate`

Audit events should be created server-side on valve/quota/unit/policy mutations (not posted by the client).

---

## 8. Policies & billing (tenant-scoped)

### GET `/tenants/{tenantId}/quota-templates`

**Response 200:**

```json
{
  "templates": [
    {
      "id": "standard",
      "name": "Standard 500L",
      "dailyLimitLiters": 500,
      "steps": [
        { "atLitersUsed": 300, "action": "reduce_pressure", "value": 20 },
        { "atLitersUsed": 500, "action": "turn_off" }
      ]
    }
  ]
}
```

### PUT `/tenants/{tenantId}/quota-templates`

Replace full template list.

---

### GET `/tenants/{tenantId}/schedule-rules`

**Response 200:**

```json
{
  "rules": [
    {
      "id": "night_reduction",
      "name": "Night reduction (11pm–6am)",
      "startHour": 23,
      "endHour": 6,
      "pressureCapPercent": 50,
      "enabled": true
    }
  ]
}
```

### PUT `/tenants/{tenantId}/schedule-rules`

Replace schedule rules. Backend should enforce pressure cap on devices during active windows.

---

### GET `/tenants/{tenantId}/tariff`

**Response 200:**

```json
{
  "currencySymbol": "₹",
  "costPerLiter": 0.05
}
```

### PUT `/tenants/{tenantId}/tariff`

Update billing rate used for cost estimates in reports.

---

### GET `/tenants/{tenantId}/reports/monthly` *(optional optimization)*

Pre-aggregated monthly billing report. App can alternatively call per-device `/water/daily` + local tariff.

**Query:** `from`, `to` (YYYY-MM-DD), `timezone`

**Response 200:**

```json
{
  "currencySymbol": "₹",
  "costPerLiter": 0.05,
  "rows": [
    {
      "unitId": "wm-1",
      "name": "D205",
      "flatNumber": "D205",
      "floor": "2",
      "totalLiters": 1250.0,
      "estimatedCost": 62.5,
      "dailyBreakdown": { "2026-06-01": 42.0, "2026-06-02": 38.5 }
    }
  ]
}
```

---

## 9. Device provisioning (LAN — not cloud API)

Used during real provisioning (`USE_MOCK_PROVISIONING=false`). HTTP to the meter's hotspot, not the backend.

| Method | URL | Body | Notes |
|--------|-----|------|-------|
| POST | `http://192.168.4.1:8080/wifi-credentials` | `{ "ssid", "password" }` | Primary gateway |
| POST | `http://{serial}.local:8080/wifi-credentials` | same | mDNS fallback |
| POST | `http://{serial}.local:8080/enrollment/enroll` | empty body | Device registers with cloud |

After enrollment, the app calls `POST /tenants/{tenantId}/units` to link the device serial to a unit.

---

## 10. Caching strategy (client)

| Data | Server source of truth | Client cache |
|------|------------------------|--------------|
| Unit inventory | Yes | Short TTL cache; refresh on pull-to-refresh |
| Current reading / valve / quota | Yes | Per-device, auto-dispose providers (~15s stale) |
| Usage / daily / hourly | Yes | Cached per query range |
| Building summary | Yes | 1–5 min cache |
| Alerts | Yes | Poll or WebSocket; local unread state OK |
| Audit | Yes | Paginated fetch; no local append |
| Templates / schedules / tariff | Yes | Cache until settings change |
| Theme / volume unit / top-consumers layout | Optional | Can stay on-device |

---

## 11. Endpoint summary

| Method | Path | Feature |
|--------|------|---------|
| GET | `/users/me` | Profile |
| POST | `/users/role` | Onboarding |
| POST | `/tenants` | Create building |
| POST | `/tenants/join` | Join building |
| POST | `/tenants/join/unit` | Join unit (recommended) |
| GET/PATCH | `/users/me/preferences` | User prefs (optional) |
| POST | `/users/me/push-token` | FCM |
| GET | `/tenants/{id}/units` | Unit list |
| POST | `/tenants/{id}/units` | Enroll unit |
| GET/PATCH/DELETE | `/tenants/{id}/units/{unitId}` | Unit CRUD |
| POST | `/tenants/{id}/units/{unitId}/invite-codes` | Resident invite |
| GET | `/tenants/{id}/building/summary` | Building home header |
| GET | `/tenants/{id}/building/rankings` | Top consumers |
| GET | `/devices/{id}/water/current` | Live flow |
| GET | `/devices/{id}/water/usage` | Usage charts |
| GET | `/devices/{id}/water/daily` | Daily / reports |
| GET | `/devices/{id}/water/hourly-pattern` | Insights |
| GET/PUT | `/devices/{id}/water/valve` | Valve control |
| GET/PUT | `/devices/{id}/water/quota` | Quota config |
| POST | `/tenants/{id}/policies/apply-template` | Bulk quota |
| POST | `/tenants/{id}/policies/emergency-shutoff` | Bulk shutoff |
| GET/PATCH | `/tenants/{id}/alerts` | Alert inbox |
| GET | `/tenants/{id}/audit` | Audit log |
| GET/PUT | `/tenants/{id}/quota-templates` | Policy templates |
| GET/PUT | `/tenants/{id}/schedule-rules` | Night schedules |
| GET/PUT | `/tenants/{id}/tariff` | Billing rate |
| GET | `/tenants/{id}/reports/monthly` | Reports (optional) |

---

## Related code

| Contract | Dart reference |
|----------|----------------|
| Water device API | `lib/core/api/water_api_client.dart`, `dio_water_api_client.dart` |
| Tenant API | `lib/core/api/tenant_api_client.dart` |
| Building API | `lib/core/api/building_api_client.dart` |
| Models | `lib/core/models/` |
| Local storage (to replace) | `lib/core/storage/preferences_storage.dart` |
