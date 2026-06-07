# Water Meter AWS Infrastructure

CDK stack for Cognito (Google OAuth), DynamoDB tenant storage, and tenant onboarding API.

## Prerequisites

- Node.js 20+
- AWS CLI configured (`aws configure`)
- AWS CDK CLI: `npm install -g aws-cdk`

## Deploy

```bash
cd infrastructure
npm install

# Optional: pass Google OAuth credentials for Cognito federated IdP
export GOOGLE_CLIENT_ID="your-web-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-web-client-secret"

npm run deploy
```

Note the outputs: `UserPoolId`, `UserPoolClientId`, `CognitoDomain`, `ApiUrl`.

## Configure Flutter app

Pass deploy outputs as dart-defines:

```bash
flutter run \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=COGNITO_USER_POOL_ID=<UserPoolId> \
  --dart-define=COGNITO_CLIENT_ID=<UserPoolClientId> \
  --dart-define=COGNITO_DOMAIN=<CognitoDomain> \
  --dart-define=API_BASE_URL=<ApiUrl>
```

## Google Cloud Console setup

1. Create OAuth 2.0 credentials:
   - **Web application** — used by Cognito Google IdP (`GOOGLE_CLIENT_ID` / secret)
   - **Android** — package `com.vswitch.water_meter_app`, SHA-1 from debug keystore
   - **iOS** — bundle ID `com.vswitch.waterMeterApp`
2. Add authorized redirect URI in Google Console (Web client):
   - `https://<CognitoDomain>/oauth2/idpresponse`
3. In AWS Cognito → Federation → Google, enter Web client ID and secret (if not passed at deploy time).

## API routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/me` | Current user profile |
| POST | `/users/role` | Set role (`admin` or `readonly`); admin auto-creates tenant |
| POST | `/tenants` | Create tenant (admin, idempotent) |
| POST | `/tenants/join` | Join tenant by invite code (read-only) |

All routes require `Authorization: Bearer <Cognito ID token>`.
