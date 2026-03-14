#!/usr/bin/env bash
# Generate a dev JWT, POST to login, and save the access token.
# Usage: ./scripts/dev-auth.sh [base_url]
set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"
CONDA_ENV="wealth-manager"

# Generate a minimal JWT with sub=dev-local-user (no signature verification in sandbox)
IDENTITY_TOKEN=$(conda run -n "$CONDA_ENV" python -c "
import jwt
token = jwt.encode({'sub': 'dev-local-user', 'email': 'dev@localhost'}, 'not-verified', algorithm='HS256')
print(token)
")

echo "Identity token: ${IDENTITY_TOKEN:0:40}..."

# POST to login endpoint
RESPONSE=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"identity_token\": \"${IDENTITY_TOKEN}\"}")

echo "Login response: ${RESPONSE}"

# Extract access_token
ACCESS_TOKEN=$(echo "$RESPONSE" | conda run -n "$CONDA_ENV" python -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to extract access_token from response"
  exit 1
fi

# Save token
echo -n "$ACCESS_TOKEN" > /tmp/wm-dev-token.txt
chmod 600 /tmp/wm-dev-token.txt
echo "Access token saved to /tmp/wm-dev-token.txt"
echo "Token: ${ACCESS_TOKEN:0:40}..."
