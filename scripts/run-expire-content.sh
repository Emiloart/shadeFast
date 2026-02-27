#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required."
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running."
  exit 1
fi

limit="${EXPIRE_LIMIT:-200}"
dry_run="${EXPIRE_DRY_RUN:-false}"

if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
  echo "EXPIRE_LIMIT must be an integer."
  exit 1
fi

if [[ "$dry_run" != "true" && "$dry_run" != "false" ]]; then
  echo "EXPIRE_DRY_RUN must be true or false."
  exit 1
fi

url="${SUPABASE_URL%/}/functions/v1/expire-content"
payload="{\"limit\":${limit},\"dryRun\":${dry_run}}"

curl --fail-with-body --silent --show-error \
  -X POST "$url" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  --data "$payload"

echo
