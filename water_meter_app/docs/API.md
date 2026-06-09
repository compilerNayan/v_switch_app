# Water Monitor App — REST API Contract (Single-Tenant)

This document defines the backend API for the Water Monitor app. The deployment model is **one tenant per installation** — users belong to at most one tenant.

**Base URL:** `https://api.example.com/v1` (`API_BASE_URL` dart-define)

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

Poll cloud enrollment completion (placeholder until AWS IoT Core integration).

**Response 200:**

```json
{
  "enrolled": true,
  "status": "enrolled"
}
```

Currently always returns `enrolled: true`. The app polls every 3s after LAN enroll + unit create.

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

## 5. Device water API

All paths tenant-scoped: `/tenants/{tenantId}/devices/{deviceId}/water/...`

Server verifies unit belongs to tenant and user is admin.

### GET `.../current`

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

Same shapes as prior API doc (`QuotaResponse`, `QuotaUpdateRequest` with `steps`).

---

## 6. Building overview

### GET `/tenants/{tenantId}/building/summary`

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

---

## Related Dart code

| Area | Files |
|------|-------|
| Models | `lib/core/models/tenant_config.dart`, `user_profile.dart`, `water_unit.dart`, `bulk_valve_snapshot.dart` |
| Tenant API | `lib/core/api/tenant_api_client.dart` |
| Water API | `lib/core/api/dio_water_api_client.dart` |
| Onboarding | `lib/features/auth/sign_in_screen.dart`, `confirm_sign_up_screen.dart`, `admin_invite_screen.dart` |
| Policies | `lib/core/services/policy_engine.dart` |
