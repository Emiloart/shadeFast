#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy-functions-remote.sh [--project-ref <ref>] [function ...]

Description:
  Deploy Supabase Edge Functions using the repo-standard flags:
    --import-map supabase/functions/deno.json
    --no-verify-jwt
    --use-api

Behavior:
  - If function names are provided, only those functions are deployed.
  - If no function names are provided, all functions in supabase/functions
    with an index.ts entrypoint are deployed (excluding _shared).
  - Project ref is optional when the repo is already linked. You can pass
    --project-ref or set SUPABASE_PROJECT_REF.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

require_cmd npx

project_ref="${SUPABASE_PROJECT_REF:-}"
declare -a selected_functions=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-ref)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --project-ref"
        exit 1
      fi
      project_ref="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      selected_functions+=("$1")
      shift
      ;;
  esac
done

if [[ ${#selected_functions[@]} -eq 0 ]]; then
  for dir in supabase/functions/*; do
    [[ -d "$dir" ]] || continue
    function_name="$(basename "$dir")"
    [[ "$function_name" == "_shared" ]] && continue
    [[ -f "$dir/index.ts" ]] || continue
    selected_functions+=("$function_name")
  done
fi

if [[ ${#selected_functions[@]} -eq 0 ]]; then
  echo "No functions found to deploy."
  exit 1
fi

mapfile -t selected_functions < <(printf '%s\n' "${selected_functions[@]}" | sort -u)

for function_name in "${selected_functions[@]}"; do
  entrypoint="supabase/functions/${function_name}/index.ts"
  if [[ ! -f "$entrypoint" ]]; then
    echo "Skipping ${function_name}: missing ${entrypoint}"
    continue
  fi

  echo "Deploying ${function_name}..."
  deploy_cmd=(
    npx supabase functions deploy "${function_name}"
    --import-map supabase/functions/deno.json
    --no-verify-jwt
    --use-api
  )
  if [[ -n "$project_ref" ]]; then
    deploy_cmd+=(--project-ref "$project_ref")
  fi

  "${deploy_cmd[@]}"
done

echo "Function deployment complete."
