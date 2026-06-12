# Water Monitor App — REST API Contract (Single-Tenant)

This document defines the backend API for the Water Monitor app. The deployment model is **one tenant per installation** — users belong to at most one tenant.

**Base URL:** `https://w31qj0une4.execute-api.ap-south-1.amazonaws.com/Prod` (`API_BASE_URL` dart-define; production default)

**Authentication:** All requests require:

```
Authorization: Bearer <Cognito ID token>
```

The backend validates the JWT against the Cognito user pool issuer. User profile and `tenantId` are stored in DynamoDB (`GET /users/me` is the source of truth). Every **tenant-scoped** route validates the caller's `tenantId` matches `path.tenantId`.

**Error response:**

```json
{
  "error": {
    "code": "INVALID_INVITE",
    "message": "Human-readable description"
  }
}
```

---

## Tenancy model

| Rule | Detail |
|------|--------|
| One tenant per owner | Each sign-up creates one tenant for that user (1 user = 1 tenant) |
| Users | All authenticated users are **admins** (no resident/maintenance roles) |
| Owner sign-up | `POST /users` creates user + tenant (`isTenantOwner: true`) |
| Additional admins | Join via `POST /tenants/join/admin` with owner-generated invite code |
| Meter invites | Per-unit codes generated only; resident onboarding is **future work** |
| Tenant in path | All building/device data under `/tenants/{tenantId}/...` |

### Route scoping

| Scope | Path pattern |
|-------|----------------|
| User-global | `/users/me`, `/users/me/*` |
| Tenant-global join | `/tenants/join/admin` (no tenantId yet) |
| User registration | `POST /users` (creates user + tenant after Cognito sign-up) |
| Tenant-scoped | `/tenants/{tenantId}/*` |
| Device (tenant-scoped) | `/tenants/{tenantId}/devices/{deviceId}/water/*` |

---

## 1. User

### POST `/users`

Called once after Cognito sign-up and first sign-in. Creates the user profile and assigns a new tenant (one owner per tenant today; multiple users per tenant later). The server generates a **7-character base36** `tenantId` (e.g. `a1b2c3d`). Building name is set later via `POST /tenants/{tenantId}/building`. **Idempotent:** returns `200` with the existing profile if the user is already registered.

**Request:**

```json
{
  "email": "admin@building.com",
  "phone": "+919876543210",
  "firstName": "Raj",
  "lastName": "Sharma"
}
```

**Response 201** (or `200` if already registered):

```json
{
  "userId": "<cognito-sub>",
  "email": "admin@building.com",
  "displayName": "Raj Sharma",
  "phone": "+919876543210",
  "firstName": "Raj",
  "lastName": "Sharma",
  "tenantId": "a1b2c3d",
  "onboardingComplete": false,
  "isTenantOwner": true
}
```

The app should cache `tenantId` and user fields locally after registration. Owner must call `POST /tenants/{tenantId}/building` before `onboardingComplete` becomes `true`.

### GET `/users/me`

```json
{
  "userId": "usr_abc123",
  "email": "admin@building.com",
  "displayName": "Building Admin",
  "tenantId": "k3m9x2a",
  "onboardingComplete": true,
  "isTenantOwner": false
}
```

| Field | Notes |
|-------|-------|
| `tenantId` | 7-character base36 id assigned at `POST /users` |
| `isTenantOwner` | true for the user who created the tenant |
| `onboardingComplete` | false until building setup (`POST /tenants/{tenantId}/building`) or admin invite join |

**Removed:** `role`, `inviteCode`, `assignedUnitIds`, `maintainableUnitIds`

### POST `/users/me/push-token`

```json
{ "token": "fcm-...", "platform": "android" }
```

**Response:** `204 No Content`

### PATCH `/users/me/preferences` (optional)

User UI prefs (theme, volume unit, top-consumers layout). May remain client-only.

---

## 2. Tenant lifecycle

### POST `/tenants/{tenantId}/building`

**Tenant owner only.** Called after sign-up to save building name and optional layout. Sets `onboardingComplete: true` on the user.

**Request:**

```json
{
  "name": "Sunrise Apartments",
  "structure": {
    "blocks": [
      {
        "id": "A",
        "label": "Tower A",
        "wings": [
          { "name": "East", "floorCount": 10 },
          { "name": "West", "floorCount": 8 }
        ]
      }
    ]
  }
}
```

- `structure.blocks` may be `[]` (building name only)
- Blocks, wings, and `floorCount` are all optional
**Response 201:** Same shape as `GET /tenants/{tenantId}`.

**Sign-up flow:** `POST /users` creates tenant with empty name/structure and `onboardingComplete: false`. Owner must complete this endpoint before accessing the app home.

### GET `/tenants/{tenantId}`

```json
{
  "tenantId": "k3m9x2a",
  "name": "Sunrise Apartments",
  "structure": {
    "blocks": [
      {
        "id": "A",
        "label": "Tower A",
        "wings": [
          { "name": "East", "floorCount": 10 },
          { "name": "West", "floorCount": 8 }
        ]
      }
    ]
  }
}
```

**Derived flags (client or server):**

| Flag | Rule |
|------|------|
| `hasBlocks` | `structure.blocks.length > 0` |
| `hasWings` | any block has `wings.length > 0` |
| `hasFloors` | any wing has `floorCount > 0` |

### PUT `/tenants/{tenantId}/structure`

Admin updates building layout. Validates unique block ids.

**Request:** same `structure` object as tenant creation.

**Response 200:** Updated tenant config.

---

## 3. Admin invites (co-admin)

### POST `/tenants/{tenantId}/admin-invites`

**Tenant owner only.** Generates a one-time or reusable admin invite code.

**Response 200:**

```json
{
  "inviteCode": "ADMIN-7X2K",
  "expiresAt": "2026-07-01T00:00:00Z"
}
```

### POST `/tenants/join/admin`

User has signed in but has no `tenantId`. Validates invite against the single tenant.

**Request:**

```json
{ "inviteCode": "ADMIN-7X2K" }
```

**Response 200:**

```json
{
  "tenantId": "k3m9x2a",
  "onboardingComplete": true,
  "isTenantOwner": false
}
```

**Removed:** `POST /tenants/join` (building-wide resident join), `POST /users/role`

---

## 4. Water units

### GET `/tenants/{tenantId}/units`

List all units. Optional query: `block`, `wing`, `search`.

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
      "block": "A",
      "wing": "East",
      "residentName": "Ravi Kumar",
      "phoneNumber": "+919876543210",
      "notes": "Corner flat",
      "enrollmentStatus": "pending",
      "maintenanceMode": false,
      "maintenanceStartedAt": null,
      "unitInviteCode": "D205-1234"
    }
  ]
}
```

| Field | Notes |
|-------|-------|
| `block` / `wing` | Required when tenant `hasBlocks` / `hasWings`; must match structure |
| `maintenanceMode` | When true: valve off, valve-on rejected, excluded from bulk ops |
| `maintenanceStartedAt` | ISO8601 when maintenance enabled |
| `unitInviteCode` | For future resident onboarding; generate only in this phase |
| `enrollmentStatus` | `pending` until cloud enrollment completes; `enrolled` when active |

### POST `/tenants/{tenantId}/units`

Register meter after device enrollment.

**Request:**

```json
{
  "deviceId": "WM000001",
  "name": "D205",
  "flatNumber": "D205",
  "floor": "2",
  "block": "A",
  "wing": "East",
  "residentName": "Ravi Kumar",
  "phoneNumber": "+919876543210",
  "notes": "Corner flat"
}
```

**Response 201:** Full unit object with server-assigned `id`, `unitInviteCode`, and `enrollmentStatus: "pending"`.

Idempotent on `deviceId`: re-posting the same serial returns the existing unit.

### GET `/tenants/{tenantId}/devices/{deviceId}/enrollment-status`

Poll cloud enrollment completion after the device publishes `lifecycle/enrolled` to AWS IoT Core.

**Response 200:**

```json
{
  "enrolled": true,
  "status": "enrolled"
}
```

`POST /units` sets `enrollmentStatus: "pending"`. The device completes fleet provisioning and publishes `{tenantId}/water_meter/{deviceId}/lifecycle/enrolled`; the backend IoT rule forwards that message to the ingestion Lambda, which marks the unit enrolled and initializes device state/config. The app polls every **1 minute** after LAN enroll + unit create until `enrolled: true`.

When `MOCK_TELEMETRY_ENABLED=true` (local dev only), a mock scheduler can still simulate telemetry and immediate enrollment; production sets `MOCK_TELEMETRY_ENABLED=false` and relies on real MQTT ingestion.

### GET `/tenants/{tenantId}/units/{unitId}`

**Response 200:** Single unit.

### PATCH `/tenants/{tenantId}/units/{unitId}`

Partial update. When `maintenanceMode` set to `true`:

1. Server snapshots valve state
2. Sets valve off (`pressurePercent: 0`)
3. Rejects valve-on until `maintenanceMode: false`

```json
{
  "name": "D205",
  "residentName": "Ravi Kumar",
  "phoneNumber": "+919876543210",
  "maintenanceMode": true
}
```

### DELETE `/tenants/{tenantId}/units/{unitId}`

**Response:** `204`

### POST `/tenants/{tenantId}/units/{unitId}/invite-codes`

Regenerate per-meter invite code (display/copy in app; no join flow yet).

**Response 200:**

```json
{ "unitInviteCode": "D205-5678" }
```

---

## 4b. IoT MQTT topic contract (device → backend)

Devices publish telemetry to AWS IoT Core. IoT topic rules forward matching messages to the backend ingestion Lambda (`DeviceMqttIngestionFunction`). When `MOCK_TELEMETRY_ENABLED=true`, a mock scheduler simulates the same payloads for local development; production uses real device MQTT only.

| Topic | Purpose |
|-------|---------|
| `{tenantId}/water_meter/{deviceId}/water/1s` | Optional 1s pulse when water flows |
| `{tenantId}/water_meter/{deviceId}/water/30m` | 30 × 1-min buckets + cumulative reading |
| `{tenantId}/water_meter/{deviceId}/status` | HTTP response to a cloud command (valve state, etc.) |
| `{tenantId}/water_meter/{deviceId}/lifecycle/enrolled` | Post-enrollment confirmation |
| `{tenantId}/water_meter/{deviceId}/command` | Cloud → device HTTP request (one in-flight at a time) |

**1-second pulse** (omit when idle):

```json
{ "ts": "2026-06-09T10:30:05Z", "ml": 45 }
```

**30-minute bucket:**

```json
{
  "tenantId": "k3m9x2a",
  "deviceId": "WM000001",
  "periodStart": "2026-06-09T10:00:00Z",
  "minutes": [{ "t": "2026-06-09T10:00:00Z", "ml": 120 }],
  "cumulativeLiters": 15420.5,
  "valveTargetPercent": 100
}
```

**Enrollment complete:**

```json
{
  "tenantId": "k3m9x2a",
  "deviceId": "WM000001",
  "serialNumber": "WM000001",
  "enrolledAt": "2026-06-09T10:00:00Z"
}
```

**Cloud command / status:** The backend publishes an HTTP request string to `{tenantId}/water_meter/{deviceId}/command`. The device executes it and publishes the HTTP response on `{tenantId}/water_meter/{deviceId}/status`. Only one command is in flight per device at a time, so any `/status` message is treated as the response to the last command. Valve responses use `targetPressurePercent` / `actualPressurePercent` in the JSON body.

**Development:** EventBridge triggers `TelemetryIngestionFunction` every minute. It scans enrolled `WaterMeterUnits` and calls `MockDeviceFacade` ingest methods (synthetic per-device MQTT payloads: second pulse when flowing, live tick every minute, 30-minute bucket on `:00` and `:30`). The facade writes `WaterMeterTodaySlots`, `WaterMeterDeviceState`, and reads valve/quota desired state from `WaterMeterDeviceConfig`. Completed days roll into `WaterMeterDayHistory` via `DayRollupFunction`.

**Internal architecture:** `DeviceFacade` is the device ingest + live-read + write boundary. REST historical queries (`/usage`, `/daily`, `/building/*`) read DynamoDB directly; live per-device reads (`/current`, `/valve`, quota rules) and all writes (`PUT /valve`, `PUT /quota`) go through the facade.

---

## 5. Device water API

All paths tenant-scoped: `/tenants/{tenantId}/devices/{deviceId}/water/...`

Server verifies unit belongs to tenant and user is admin.

### GET `.../current`

Reads live snapshot from `WaterMeterDeviceState` (updated by telemetry ingestion).

```json
{
  "deviceId": "WM000001",
  "timestamp": "2026-06-08T10:30:00Z",
  "flowRateLpm": 2.3,
  "cumulativeLiters": 15420.5,
  "status": "flowing"
}
```

`status`: `flowing` | `idle` | `offline` | `leak_suspected` (offline when `lastSeenAt` > 15 min ago)

### GET `.../usage`

Query: `from`, `to` (ISO8601 UTC), `granularity` (`1m`|`5m`|`15m`|`30m`|`1h`|`1d`), `timezone`

### GET `.../daily`

Query: `from`, `to` (YYYY-MM-DD), `timezone`

### GET `.../hourly-pattern`

Query: `from`, `to` (YYYY-MM-DD), `timezone`

### GET `.../valve`

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

### PUT `.../valve`

```json
{ "pressurePercent": 75 }
```

```json
{ "action": "restore" }
```

**Rejected with `423 Locked`** when unit `maintenanceMode` is true and request would turn water on.

### GET / PUT `.../quota`

Quota **rules** (`enabled`, `dailyLimitLiters`, `steps`) are stored in `WaterMeterDeviceConfig` via the internal DeviceFacade. **Status** (`usedLiters`, `activeStepIndex`, `quotaCapPercent`, etc.) is computed from today's `WaterMeterTodaySlots` sum.

**GET** response:

```json
{
  "deviceId": "WM000001",
  "enabled": true,
  "dailyLimitLiters": 500,
  "timezone": "UTC",
  "steps": [
    { "atLitersUsed": 300, "action": "reduce_pressure", "value": 20 },
    { "atLitersUsed": 500, "action": "turn_off" }
  ],
  "status": {
    "date": "2026-06-09",
    "usedLiters": 120,
    "activeStepIndex": -1,
    "quotaCapPercent": null,
    "remainingLiters": 380,
    "nextStepAtLiters": 300
  }
}
```

**PUT** body (`QuotaUpdateRequest`):

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

Step `action` values: `reduce_pressure` | `turn_off`. `reduce_pressure` requires a positive `value` (percentage points subtracted from a 100% baseline, cumulative).

Default config is created on unit enroll (`quotaEnabled: false`, `dailyLimitLiters: 500`, empty `steps`). GET lazily initializes config if missing.

When quota is enabled and a step is active, `GET .../valve` may return `controlMode: "quota"` and `quotaCapPercent`; `effectivePressurePercent` reflects the lower of actual pressure and the quota cap.

---

## 6. Building overview

### GET `/tenants/{tenantId}/building/summary`

Aggregates `WaterMeterDayHistory` / today's slots + `WaterMeterDeviceState` for all units in the tenant.

```json
{
  "totalTodayLiters": 12450.5,
  "totalMonthLiters": 312000.0,
  "unitsOnline": 42,
  "unitsOffline": 3,
  "unitsTotal": 45,
  "activeAlerts": 7
}
```

`activeAlerts`: count of devices with `leak_suspected` status or offline (>15 min since last telemetry).

### GET `/tenants/{tenantId}/building/rankings`

| Query | Values |
|-------|--------|
| `period` | `today` \| `week` \| `month` |
| `groupBy` | `overall` \| `block` \| `wing` |
| `blockId` | Required when `groupBy=wing` |
| `limit` | Top N per group (default 5) |

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

`block`/`wing` omitted when tenant has no such dimensions.

---

## 7. Bulk policies

All exclude units with `maintenanceMode: true`.

### POST `/tenants/{tenantId}/policies/apply-template`

```json
{
  "templateId": "standard",
  "unitIds": null
}
```

`unitIds: null` = all non-maintenance units.

**Response 200:** `{ "appliedCount": 42, "failedUnitIds": [] }`

### POST `/tenants/{tenantId}/policies/emergency-shutoff`

```json
{ "unitIds": null }
```

Before shutoff, server snapshots valve state per unit:

```json
{ "deviceId": "WM001", "wasOn": true, "pressurePercent": 85 }
```

**Response 200:**

```json
{
  "shutoffCount": 40,
  "snapshotId": "snap_abc123"
}
```

### POST `/tenants/{tenantId}/policies/emergency-restore`

```json
{ "snapshotId": "snap_abc123" }
```

Restores **only units where `wasOn` was true** at snapshot time, at saved `pressurePercent`. Skips maintenance units. Clears snapshot on success.

**Response 200:** `{ "restoredCount": 35 }`

---

## 8. Alerts

### GET `/tenants/{tenantId}/alerts`

Query: `unresolved`, `unitId`, `since`, `limit`

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

### PATCH `/tenants/{tenantId}/alerts/{alertId}`

```json
{ "isRead": true, "isResolved": true }
```

Production: server-side alert engine; client polls or receives push.

---

## 9. Audit log

### GET `/tenants/{tenantId}/audit`

Query: `from`, `to`, `unitId`, `action`, `limit`

```json
{
  "events": [
    {
      "id": "audit-1",
      "timestamp": "2026-06-08T09:15:00Z",
      "actorEmail": "admin@building.com",
      "action": "emergencyShutoff",
      "unitId": "wm-1",
      "unitName": "D205",
      "details": "snapshot snap_abc123"
    }
  ]
}
```

`action`: `valveOff` | `valveOn` | `quotaUpdate` | `templateApply` | `emergencyShutoff` | `emergencyRestore` | `unitEdit` | `maintenanceMode` | `scheduleUpdate`

Audit events are **server-written** on mutations (not client-posted).

---

## 10. Tenant policies & billing

### GET/PUT `/tenants/{tenantId}/quota-templates`

### GET/PUT `/tenants/{tenantId}/schedule-rules`

### GET/PUT `/tenants/{tenantId}/tariff`

```json
{ "currencySymbol": "₹", "costPerLiter": 0.05 }
```

### GET `/tenants/{tenantId}/reports/monthly` (optional)

Query: `from`, `to`, `timezone` — pre-aggregated billing rows.

---

## 11. Device provisioning

### Cloud pre-enrollment (before LAN enroll)

**`POST /tenants/{tenantId}/devices/pre-enroll`** (authenticated)

Called in parallel with device WiFi configuration while the phone is on the `IoT_<serial>` hotspot. Reserves the serial for the tenant (pending AWS IoT enrollment).

**Request:**
```json
{ "serialNumber": "WM000123" }
```

**Response 201:**
```json
{
  "tenantId": "k3m9x2a",
  "serialNumber": "WM000123",
  "status": "pending",
  "expiresAt": "2026-06-08T15:00:00Z"
}
```

Idempotent: re-calling for the same serial refreshes the pending record.

### LAN device APIs (not cloud)

| Method | URL | Body |
|--------|-----|------|
| POST | `http://192.168.4.1:8080/wifi-credentials` | `{ "ssid", "password" }` |
| POST | `http://{serial}.local:8080/enrollment/enroll` | empty |

**App flow (current):** WiFi credentials are sent while the phone is on the `IoT_<serial>` hotspot. Pre-enroll runs on the Enroll step after the phone reconnects to home WiFi. Enroll runs LAN `POST /enrollment/enroll` and `POST /tenants/{tenantId}/units` in parallel, then polls `GET .../enrollment-status` until `enrolled: true`.

---

## 12. Client caching

| Data | Source of truth | Client cache |
|------|-----------------|--------------|
| Tenant structure | Server | Refresh on settings change |
| Unit inventory | Server | Short TTL; pull-to-refresh |
| Valve/quota/current | Server | Per-device ~15s |
| Bulk snapshot | Server (or local mock) | Until restore or clear |
| UI theme / layout prefs | Device | Optional server sync |

---

## 13. Endpoint summary

| Method | Path |
|--------|------|
| GET | `/users/me` |
| POST | `/users` |
| POST | `/users/me/push-token` |
| GET | `/tenants/{tenantId}` |
| PUT | `/tenants/{tenantId}/structure` |
| POST | `/tenants/{tenantId}/building` |
| POST | `/tenants/{tenantId}/devices/pre-enroll` |
| GET | `/tenants/{tenantId}/devices/{deviceId}/enrollment-status` |
| POST | `/tenants/{tenantId}/admin-invites` |
| POST | `/tenants/join/admin` |
| GET/POST | `/tenants/{tenantId}/units` |
| GET/PATCH/DELETE | `/tenants/{tenantId}/units/{unitId}` |
| POST | `/tenants/{tenantId}/units/{unitId}/invite-codes` |
| GET | `/tenants/{tenantId}/building/summary` |
| GET | `/tenants/{tenantId}/building/rankings` |
| GET/PUT | `/tenants/{tenantId}/devices/{id}/water/*` |
| POST | `/tenants/{tenantId}/policies/apply-template` |
| POST | `/tenants/{tenantId}/policies/emergency-shutoff` |
| POST | `/tenants/{tenantId}/policies/emergency-restore` |
| GET/PATCH | `/tenants/{tenantId}/alerts` |
| GET | `/tenants/{tenantId}/audit` |
| GET/PUT | `/tenants/{tenantId}/quota-templates` |
| GET/PUT | `/tenants/{tenantId}/schedule-rules` |
| GET/PUT | `/tenants/{tenantId}/tariff` |
| POST | `/v2/users` |
| GET | `/v2/users/me` |
| GET | `/v2/tenants/{tenantId}` |
| POST | `/v2/tenants/{tenantId}/building` |
| POST | `/v2/tenants/{tenantId}/devices/pre-enroll` |
| GET | `/v2/tenants/{tenantId}/units` |
| POST | `/v2/tenants/{tenantId}/units` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/enrollment-status` |
| POST | `/v2/tenants/{tenantId}/admin-invites` |
| POST | `/v2/tenants/join/admin` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/valve` |
| PUT | `/v2/tenants/{tenantId}/devices/{deviceId}/water/valve` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/current` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/quota` |
| PUT | `/v2/tenants/{tenantId}/devices/{deviceId}/water/quota` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/minutes/today` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/minutes/history` |
| GET | `/v2/tenants/{tenantId}/building/daily` |
| GET | `/v2/tenants/{tenantId}/metadata/hash` |
| GET | `/v2/tenants/{tenantId}/metadata` |
| GET | `/v2/tenants/{tenantId}/dashboard` |

---

## V2 — Onboarding (replicas of v1 user/tenant routes)

Same request/response bodies and status codes as v1; paths are under `/v2`. Used by the app from sign-up through building setup until the home dashboard loads.

| Method | Path | v1 equivalent |
|--------|------|---------------|
| POST | `/v2/users` | `POST /users` |
| GET | `/v2/users/me` | `GET /users/me` |
| GET | `/v2/tenants/{tenantId}` | `GET /tenants/{tenantId}` |
| POST | `/v2/tenants/{tenantId}/building` | `POST /tenants/{tenantId}/building` |
| POST | `/v2/tenants/{tenantId}/devices/pre-enroll` | `POST /tenants/{tenantId}/devices/pre-enroll` |
| GET | `/v2/tenants/{tenantId}/units` | `GET /tenants/{tenantId}/units` |
| POST | `/v2/tenants/{tenantId}/units` | `POST /tenants/{tenantId}/units` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/enrollment-status` | `GET /tenants/{tenantId}/devices/{deviceId}/enrollment-status` |
| POST | `/v2/tenants/{tenantId}/admin-invites` | `POST /tenants/{tenantId}/admin-invites` |
| POST | `/v2/tenants/join/admin` | `POST /tenants/join/admin` |
| GET | `/v2/tenants/{tenantId}/devices/{deviceId}/water/valve` | `GET /tenants/.../water/valve` |
| PUT | `/v2/tenants/{tenantId}/devices/{deviceId}/water/valve` | `PUT /tenants/.../water/valve` |

All require Cognito JWT. User routes use the authenticated subject. Tenant routes enforce membership or owner as in v1.

The home dashboard tile on/off switch uses `PUT /v2/.../water/valve` with `pressurePercent: 0` to turn off or `action: restore` to turn back on (same body as v1).

---

## V2 — Device water (minute arrays + client-side charts)

Production app uses these for the device detail screens. Charts are built on the client from per-minute arrays.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/v2/.../water/current` | Live flow snapshot (`WaterMeterDeviceState`) |
| GET | `/v2/.../water/quota` | Quota rules + today's `usedLiters` from today's slots |
| PUT | `/v2/.../water/quota` | Update quota rules |
| GET | `/v2/.../water/minutes/today` | Today's per-minute liters (query `timezone`) |
| GET | `/v2/.../water/minutes/history` | Last N days × up to 1440 points/day (`days`, `timezone`) |
| GET | `/v2/tenants/{tenantId}/building/daily` | Building aggregate liters per day (`days`, `timezone`) |

### `GET .../water/minutes/today`

```json
{
  "deviceId": "WM000001",
  "date": "2026-06-06",
  "timezone": "UTC",
  "slotMinutes": 1,
  "startAt": "2026-06-06T00:00:00Z",
  "v": [0, 0, 1.2, 0.5]
}
```

`v` — liters per minute from local midnight through now (length ≤ 1440).

### `GET .../water/minutes/history?days=30`

```json
{
  "deviceId": "WM000001",
  "timezone": "UTC",
  "slotMinutes": 1,
  "days": [
    { "date": "2026-06-05", "startAt": "2026-06-05T00:00:00Z", "v": [0, 1.2, ...] }
  ]
}
```

### Storage (DynamoDB)

| Table | Content |
|-------|---------|
| `WaterMeterTodaySlots` | One row per 30-min ingest window (`slot#` + CSV of 30 ml values) |
| `WaterMeterDayHistory` | One row per completed day (`day#` + CSV of 1440 ml values) |
| `WaterMeterDeviceState` | Live flow; 1s pulses update here only (not stored as history) |

EOD Lambda (`DayRollupFunction`, `cron(5 0 * * ? *)`) merges yesterday's slots into `WaterMeterDayHistory`.

---

## V2 — Metadata cache + dynamic dashboard

Home screen data is split into **slow-changing metadata** (cached by the app) and **dynamic telemetry** (refreshed often). All v2 routes require Cognito JWT and tenant membership.

### Hash semantics

- `metadataHash` is SHA-256 hex over canonical JSON of tenant + owner + units (sorted by `unitId`).
- Stored on `WaterMeterTenants.metadataHash` and recomputed on building/structure/unit writes.
- Client compares hash from cache vs hash on dashboard (or lightweight hash poll) to detect stale metadata.

### Client flow

1. Poll `GET /v2/tenants/{tenantId}/metadata/hash` (optional; dashboard also includes hash).
2. If hash unchanged → use cached metadata + fetch dashboard only.
3. If hash changed → show cached metadata immediately, fetch dashboard, then refresh metadata in background via `GET /v2/tenants/{tenantId}/metadata`.

### 1. `GET /v2/tenants/{tenantId}/metadata/hash`

```json
{ "metadataHash": "sha256hex..." }
```

Single DynamoDB read on tenant row when hash is stored.

### 2. `GET /v2/tenants/{tenantId}/metadata`

```json
{
  "metadataHash": "sha256hex...",
  "tenantId": "k3m9x2a",
  "buildingName": "Sunrise Apartments",
  "structure": { "blocks": [ { "id": "A", "label": "Tower A", "wings": [ { "name": "East", "floorCount": 10 } ] } ] },
  "owner": {
    "userId": "usr_abc",
    "displayName": "Raj Sharma",
    "email": "admin@building.com",
    "phone": "+919876543210",
    "firstName": "Raj",
    "lastName": "Sharma"
  },
  "devices": [
    {
      "unitId": "wm-WM000001",
      "name": "D205",
      "deviceId": "WM000001",
      "flatNumber": "D205",
      "floor": "2",
      "block": "A",
      "wing": "East",
      "residentName": "Ravi Kumar",
      "phoneNumber": "+919876543210",
      "notes": null,
      "enrollmentStatus": "enrolled",
      "maintenanceMode": false,
      "maintenanceStartedAt": null,
      "unitInviteCode": "D205-AB12"
    }
  ]
}
```

| Field source | Table |
|--------------|-------|
| Building name, structure | `WaterMeterTenants` |
| Owner profile | `WaterMeterUsers` via `ownerUserId` |
| Device static fields | `WaterMeterUnits` |
| `maintenanceMode` / `maintenanceStartedAt` | Placeholder (`false` / `null`) until schema adds them |

### 3. `GET /v2/tenants/{tenantId}/dashboard`

Query: `timezone` (optional, default `UTC`) — IANA zone id or offset such as `+05:30`. Used to align `todayLiters` with the device usage screen (minute buckets from local midnight). `monthLiters` sums completed daily rows for the month plus live `todayLiters`.

Dynamic telemetry only:

```json
{
  "metadataHash": "sha256hex...",
  "generatedAt": "2026-06-10T12:00:00Z",
  "devices": [
    {
      "unitId": "wm-WM000001",
      "deviceId": "WM000001",
      "todayLiters": 45.2,
      "monthLiters": 1200.0,
      "isOnline": true,
      "lastSeenAt": "2026-06-10T11:58:00Z",
      "status": "idle",
      "flowRateLpm": 0.0,
      "quotaEnabled": true,
      "dailyLimitLiters": 500,
      "quotaUsedLiters": 45.2,
      "quotaPercent": 0.0904,
      "valveOpenPercent": 100,
      "valveIsOff": false,
      "hasAlert": false
    }
  ]
}
```

Client derives locally from cached metadata + dashboard devices: overview totals, top consumers, block/wing filters, near/over-quota filters.

V1 routes (`/building/summary`, `/tenants/{tenantId}/units`, per-device `/water/*`) remain for backward compatibility and device detail screens.

---

## Related Dart code

| Area | Files |
|------|-------|
| Models | `lib/core/models/tenant_config.dart`, `user_profile.dart`, `water_unit.dart`, `bulk_valve_snapshot.dart` |
| Tenant API | `lib/core/api/tenant_api_client.dart` |
| Water API | `lib/core/api/dio_water_api_client.dart` |
| Onboarding | `lib/features/auth/sign_in_screen.dart`, `confirm_sign_up_screen.dart`, `admin_invite_screen.dart` |
| Policies | `lib/core/services/policy_engine.dart` |
