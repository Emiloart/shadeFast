#!/usr/bin/env bash
set -euo pipefail

echo "Checking local prerequisites..."

flutter_cmd="${FLUTTER_BIN:-}"
if [[ -z "$flutter_cmd" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    flutter_cmd="$(command -v flutter)"
  elif [[ -x ".tooling/flutter/bin/flutter" ]]; then
    flutter_cmd=".tooling/flutter/bin/flutter"
  fi
fi

if [[ -z "$flutter_cmd" ]]; then
  echo "Flutter SDK not found. Install Flutter or set FLUTTER_BIN."
  exit 1
fi

supabase_cmd=""
if command -v supabase >/dev/null 2>&1; then
  supabase_cmd="$(command -v supabase)"
elif [[ -x "node_modules/.bin/supabase" ]]; then
  supabase_cmd="node_modules/.bin/supabase"
fi

if [[ -z "$supabase_cmd" ]]; then
  echo "Supabase CLI not found. Install Supabase CLI or run npm install supabase."
  exit 1
fi

if [[ ! -f "apps/mobile/pubspec.yaml" ]]; then
  echo "Mobile pubspec missing."
  exit 1
fi

"$flutter_cmd" --version >/dev/null
"$supabase_cmd" --version >/dev/null

(
  cd apps/mobile
  "$flutter_cmd" pub get >/dev/null
)

echo "Phase 1 bootstrap checks passed."
