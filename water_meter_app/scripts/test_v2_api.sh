#!/usr/bin/env bash
# Sign in with Cognito email/password and fetch v2 tenant metadata + dashboard.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"

REGION="${COGNITO_REGION:-ap-south-1}"
CLIENT_ID="${COGNITO_CLIENT_ID:-46865gj4jba5bp42cc04fo14k1}"
USER_POOL_ID="${COGNITO_USER_POOL_ID:-ap-south-1_vm19Xv95r}"
BASE="${API_BASE_URL:-https://2op3x3r025.execute-api.ap-south-1.amazonaws.com/Prod}"
TENANT="${TENANT_ID:-gyxomux}"
USERNAME="${COGNITO_USERNAME:-}"
PASSWORD="${COGNITO_PASSWORD:-}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/test_v2_api.sh --email you@example.com --password 'your-password'
  ./scripts/test_v2_api.sh --email you@example.com            # prompts for password
  TENANT_ID=gyxomux ./scripts/test_v2_api.sh --email you@example.com --password '...'

Options:
  --email, -e       Cognito username (usually your sign-in email)
  --password, -p    Cognito password (omit to be prompted securely)
  --tenant, -t      Tenant id (default: gyxomux)
  --base-url        API base URL (default: production Prod stage)
  -h, --help        Show this help

Environment overrides:
  COGNITO_USERNAME, COGNITO_PASSWORD, TENANT_ID, API_BASE_URL
  COGNITO_REGION, COGNITO_CLIENT_ID, COGNITO_USER_POOL_ID

If USER_PASSWORD_AUTH is disabled on the Cognito app client, install SRP support:
  pip install pycognito
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email|-e)
      USERNAME="$2"
      shift 2
      ;;
    --password|-p)
      PASSWORD="$2"
      shift 2
      ;;
    --tenant|-t)
      TENANT="$2"
      shift 2
      ;;
    --base-url)
      BASE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$USERNAME" ]]; then
  read -r -p "Cognito email: " USERNAME
fi

if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "Cognito password: " PASSWORD
  echo ""
fi

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "Email and password are required." >&2
  exit 1
fi

echo "Checking network access to Cognito ..."
if ! curl -sS --max-time 10 -o /dev/null "https://cognito-idp.${REGION}.amazonaws.com/"; then
  echo "Could not reach https://cognito-idp.${REGION}.amazonaws.com/" >&2
  echo "Check your internet connection and try again." >&2
  exit 1
fi

if ! "$PYTHON" -c "import pycognito" 2>/dev/null; then
  echo "Installing pycognito (required for Cognito SRP sign-in) ..."
  if ! "$PYTHON" -m pip install --user pycognito; then
    echo "Failed to install pycognito. Run manually:" >&2
    echo "  $PYTHON -m pip install --user pycognito" >&2
    exit 1
  fi
fi

echo "Signing in to Cognito as $USERNAME ..."
TOKEN="$("$PYTHON" "$ROOT/scripts/cognito_id_token.py" \
  --region "$REGION" \
  --client-id "$CLIENT_ID" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$USERNAME" \
  --password "$PASSWORD")"

echo "Fetching v2 metadata for tenant $TENANT ..."
echo "=== GET /v2/tenants/$TENANT/metadata ==="
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/v2/tenants/$TENANT/metadata" | "$PYTHON" -m json.tool

echo ""
echo "Fetching v2 dashboard for tenant $TENANT ..."
echo "=== GET /v2/tenants/$TENANT/dashboard ==="
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$BASE/v2/tenants/$TENANT/dashboard" | "$PYTHON" -m json.tool

echo ""
echo "Done."
