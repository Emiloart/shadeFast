#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

require_cmd curl
require_cmd node
require_cmd npx
require_cmd mktemp

project_ref="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$project_ref" ]]; then
  project_ref="$(
    npx supabase projects list --output json | node -e "
      const fs = require('node:fs');
      const raw = fs.readFileSync(0, 'utf8');
      const rows = JSON.parse(raw);
      const linked = rows.find((row) => row && row.linked === true);
      process.stdout.write(linked?.ref ?? linked?.id ?? '');
    "
  )"
fi

if [[ -z "$project_ref" ]]; then
  echo "Unable to resolve project ref. Set SUPABASE_PROJECT_REF or run supabase link first."
  exit 1
fi

supabase_url="https://${project_ref}.supabase.co"

api_keys_json="$(npx supabase projects api-keys --project-ref "$project_ref" --output json)"

anon_key="$(
  printf '%s' "$api_keys_json" | node -e "
    const fs = require('node:fs');
    const keys = JSON.parse(fs.readFileSync(0, 'utf8') || '[]');
    process.stdout.write(keys.find((row) => row?.name === 'anon')?.api_key ?? '');
  "
)"
service_role_key="$(
  printf '%s' "$api_keys_json" | node -e "
    const fs = require('node:fs');
    const keys = JSON.parse(fs.readFileSync(0, 'utf8') || '[]');
    process.stdout.write(keys.find((row) => row?.name === 'service_role')?.api_key ?? '');
  "
)"

if [[ -z "$anon_key" || -z "$service_role_key" ]]; then
  echo "Failed to resolve anon/service_role keys from Supabase API."
  exit 1
fi

echo "Resolved project: $project_ref"
echo "Starting remote smoke tests..."

api_call() {
  local expected_status="$1"
  local method="$2"
  local url="$3"
  local bearer_token="$4"
  local apikey="$5"
  local payload="${6:-}"
  local response_file
  response_file="$(mktemp)"

  local status
  if [[ -n "$payload" ]]; then
    status="$(
      curl --silent --show-error -o "$response_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Authorization: Bearer ${bearer_token}" \
        -H "apikey: ${apikey}" \
        -H "Content-Type: application/json" \
        --data "$payload"
    )"
  else
    status="$(
      curl --silent --show-error -o "$response_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Authorization: Bearer ${bearer_token}" \
        -H "apikey: ${apikey}" \
        -H "Content-Type: application/json"
    )"
  fi

  local body
  body="$(cat "$response_file")"
  rm -f "$response_file"

  if [[ "$status" != "$expected_status" ]]; then
    echo "Request failed: ${method} ${url}" >&2
    echo "Expected status: ${expected_status}, got: ${status}" >&2
    echo "Response: ${body}" >&2
    return 1
  fi

  printf '%s' "$body"
}

admin_create_user() {
  local email="$1"
  local password="$2"
  api_call \
    "200" \
    "POST" \
    "${supabase_url}/auth/v1/admin/users" \
    "$service_role_key" \
    "$service_role_key" \
    "{\"email\":\"${email}\",\"password\":\"${password}\",\"email_confirm\":true}"
}

admin_delete_user() {
  local user_id="$1"
  if [[ -z "$user_id" ]]; then
    return 0
  fi

  local response_file
  response_file="$(mktemp)"
  local status
  status="$(
    curl --silent --show-error -o "$response_file" -w "%{http_code}" \
      -X DELETE "${supabase_url}/auth/v1/admin/users/${user_id}" \
      -H "Authorization: Bearer ${service_role_key}" \
      -H "apikey: ${service_role_key}" \
      -H "Content-Type: application/json"
  )"

  rm -f "$response_file"
  if [[ "$status" != "200" && "$status" != "404" ]]; then
    echo "Warning: failed to delete temp user ${user_id} (status ${status})"
  fi
}

password_login() {
  local email="$1"
  local password="$2"
  api_call \
    "200" \
    "POST" \
    "${supabase_url}/auth/v1/token?grant_type=password" \
    "$anon_key" \
    "$anon_key" \
    "{\"email\":\"${email}\",\"password\":\"${password}\"}"
}

read_json_field() {
  local json_payload="$1"
  local expression="$2"
  printf '%s' "$json_payload" | node -e "
    const fs = require('node:fs');
    const payload = JSON.parse(fs.readFileSync(0, 'utf8') || '{}');
    const expr = process.argv[1];
    let value = '';
    switch (expr) {
      case 'user_id':
        value = payload.id ?? '';
        break;
      case 'access_token':
        value = payload.access_token ?? '';
        break;
      case 'chat_id':
        value = payload.chat?.id ?? '';
        break;
      case 'chat_token':
        value = payload.chat?.token ?? '';
        break;
      case 'messages_length':
        value = Array.isArray(payload.messages) ? String(payload.messages.length) : '';
        break;
      case 'anonymous_user_id':
        value = payload.user?.id ?? '';
        break;
      default:
        value = '';
    }
    process.stdout.write(String(value));
  " "$expression"
}

append_chat_message() {
  local access_token="$1"
  local sender_uuid="$2"
  local private_chat_id="$3"
  local body="$4"
  local expires_at="$5"

  local response_file
  response_file="$(mktemp)"
  local status
  status="$(
    curl --silent --show-error -o "$response_file" -w "%{http_code}" \
      -X POST "${supabase_url}/rest/v1/chat_messages" \
      -H "Authorization: Bearer ${access_token}" \
      -H "apikey: ${anon_key}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      --data "[{\"private_chat_id\":\"${private_chat_id}\",\"sender_uuid\":\"${sender_uuid}\",\"body\":\"${body}\",\"expires_at\":\"${expires_at}\"}]"
  )"

  local body_payload
  body_payload="$(cat "$response_file")"
  rm -f "$response_file"

  if [[ "$status" != "201" ]]; then
    echo "Failed to append chat message. Status: ${status}" >&2
    echo "Response: ${body_payload}" >&2
    return 1
  fi
}

user_a_id=""
user_b_id=""
anon_probe_user_id=""

cleanup() {
  admin_delete_user "$user_a_id"
  admin_delete_user "$user_b_id"
  admin_delete_user "$anon_probe_user_id"
}
trap cleanup EXIT

seed_suffix="$(date +%s)-$RANDOM"
user_a_email="smoke-${seed_suffix}-a@shadefast.local"
user_b_email="smoke-${seed_suffix}-b@shadefast.local"
user_a_password="ShadeFast!${seed_suffix}Aa"
user_b_password="ShadeFast!${seed_suffix}Bb"

echo "Validating anonymous auth..."
anon_signup_json="$(
  api_call \
    "200" \
    "POST" \
    "${supabase_url}/auth/v1/signup" \
    "$anon_key" \
    "$anon_key" \
    "{\"data\":{\"source\":\"smoke_anon_check\"}}"
)"
anon_probe_user_id="$(read_json_field "$anon_signup_json" "anonymous_user_id")"
if [[ -z "$anon_probe_user_id" ]]; then
  echo "Failed to parse anonymous signup user id."
  echo "$anon_signup_json"
  exit 1
fi

echo "Creating temporary auth users..."

create_a_json="$(admin_create_user "$user_a_email" "$user_a_password")"
user_a_id="$(read_json_field "$create_a_json" "user_id")"
if [[ -z "$user_a_id" ]]; then
  echo "Failed to parse temp user A id."
  echo "$create_a_json"
  exit 1
fi

create_b_json="$(admin_create_user "$user_b_email" "$user_b_password")"
user_b_id="$(read_json_field "$create_b_json" "user_id")"
if [[ -z "$user_b_id" ]]; then
  echo "Failed to parse temp user B id."
  echo "$create_b_json"
  exit 1
fi

login_a_json="$(password_login "$user_a_email" "$user_a_password")"
user_a_access_token="$(read_json_field "$login_a_json" "access_token")"
if [[ -z "$user_a_access_token" ]]; then
  echo "Failed to get access token for user A."
  echo "$login_a_json"
  exit 1
fi

login_b_json="$(password_login "$user_b_email" "$user_b_password")"
user_b_access_token="$(read_json_field "$login_b_json" "access_token")"
if [[ -z "$user_b_access_token" ]]; then
  echo "Failed to get access token for user B."
  echo "$login_b_json"
  exit 1
fi

echo "Probing feature and template functions..."
api_call \
  "200" \
  "POST" \
  "${supabase_url}/functions/v1/list-feature-flags" \
  "$user_a_access_token" \
  "$anon_key" \
  "{\"includeDisabled\":true}" \
  >/dev/null

api_call \
  "200" \
  "POST" \
  "${supabase_url}/functions/v1/list-sponsored-community-templates" \
  "$user_a_access_token" \
  "$anon_key" \
  "{\"limit\":5}" \
  >/dev/null

echo "Testing private link lifecycle and read-once consumption..."
create_chat_json="$(
  api_call \
    "201" \
    "POST" \
    "${supabase_url}/functions/v1/create-private-chat-link" \
    "$user_a_access_token" \
    "$anon_key" \
    "{\"readOnce\":true,\"ttlMinutes\":30}"
)"
chat_id="$(read_json_field "$create_chat_json" "chat_id")"
chat_token="$(read_json_field "$create_chat_json" "chat_token")"
if [[ -z "$chat_id" || -z "$chat_token" ]]; then
  echo "Failed to parse private chat response."
  echo "$create_chat_json"
  exit 1
fi

api_call \
  "200" \
  "POST" \
  "${supabase_url}/functions/v1/join-private-chat" \
  "$user_b_access_token" \
  "$anon_key" \
  "{\"token\":\"${chat_token}\"}" \
  >/dev/null

message_body="Smoke test message ${seed_suffix}"
message_expires_at="$(date -u -d '+30 minutes' '+%Y-%m-%dT%H:%M:%SZ')"
append_chat_message \
  "$user_b_access_token" \
  "$user_b_id" \
  "$chat_id" \
  "$message_body" \
  "$message_expires_at"

first_read_json="$(
  api_call \
    "200" \
    "POST" \
    "${supabase_url}/functions/v1/read-private-message-once" \
    "$user_a_access_token" \
    "$anon_key" \
    "{\"privateChatId\":\"${chat_id}\"}"
)"
first_count="$(read_json_field "$first_read_json" "messages_length")"
if [[ "$first_count" != "1" ]]; then
  echo "Expected first read to return exactly one message, got ${first_count}."
  echo "$first_read_json"
  exit 1
fi

second_read_json="$(
  api_call \
    "200" \
    "POST" \
    "${supabase_url}/functions/v1/read-private-message-once" \
    "$user_a_access_token" \
    "$anon_key" \
    "{\"privateChatId\":\"${chat_id}\"}"
)"
second_count="$(read_json_field "$second_read_json" "messages_length")"
if [[ "$second_count" != "0" ]]; then
  echo "Expected second read to return zero messages, got ${second_count}."
  echo "$second_read_json"
  exit 1
fi

echo "Running maintenance workers in dry-run mode..."
api_call \
  "200" \
  "POST" \
  "${supabase_url}/functions/v1/expire-content" \
  "$service_role_key" \
  "$service_role_key" \
  "{\"limit\":25,\"dryRun\":true}" \
  >/dev/null

api_call \
  "200" \
  "POST" \
  "${supabase_url}/functions/v1/send-push-notifications" \
  "$service_role_key" \
  "$service_role_key" \
  "{\"limit\":25,\"dryRun\":true}" \
  >/dev/null

echo "Remote smoke test passed."
