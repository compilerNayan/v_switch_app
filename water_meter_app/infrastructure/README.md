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

Pass deploy outputs as dart-defines (password auth — no Cognito domain needed):

```bash
flutter run \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=USE_MOCK_API=false \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r \
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1 \
  --dart-define=COGNITO_REGION=ap-south-1 \
  --dart-define=API_BASE_URL=https://udil78wxzb.execute-api.ap-south-1.amazonaws.com/Prod
```

Or use `./scripts/run_with_cognito.sh` from the app root.

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
