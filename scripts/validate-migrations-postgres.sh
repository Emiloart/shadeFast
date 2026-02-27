#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for migration validation."
  exit 1
fi

container_name="shadefast_pg_validate_$(date +%s)"
image="postgres:15"

cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d \
  --name "$container_name" \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  "$image" >/dev/null

for _ in $(seq 1 60); do
  if docker exec "$container_name" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker exec "$container_name" pg_isready -U postgres >/dev/null

tmp_sql="$(mktemp)"
cat > "$tmp_sql" <<'SQL'
create schema if not exists auth;
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select null::uuid;
$$;
create or replace function auth.role()
returns text
language sql
stable
as $$
  select null::text;
$$;
SQL

mapfile -t migrations < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' | sort)
if [[ "${#migrations[@]}" -eq 0 ]]; then
  echo "No migration files found in supabase/migrations."
  rm -f "$tmp_sql"
  exit 1
fi

for migration in "${migrations[@]}"; do
  cat "$migration" >> "$tmp_sql"
  printf "\n" >> "$tmp_sql"
done

docker exec -i "$container_name" psql -v ON_ERROR_STOP=1 -U postgres -d postgres < "$tmp_sql" >/dev/null
rm -f "$tmp_sql"

echo "Migration validation passed on isolated Postgres container."
