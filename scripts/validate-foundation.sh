#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "README.md"
  "docs/roadmap.md"
  "docs/execution-backlog.md"
  "docs/architecture.md"
  "docs/api-contracts.md"
  "docs/supabase-setup.md"
  "docs/incident-runbook.md"
  "supabase/migrations/202602250001_initial_schema.sql"
  "supabase/migrations/202602250002_expiry_worker.sql"
  "supabase/migrations/202602250003_media_retention_queue.sql"
  "supabase/migrations/202602250004_reports_triage.sql"
  "supabase/migrations/202602250005_rate_limits.sql"
  "supabase/migrations/202602250006_enforcement_actions.sql"
  "supabase/migrations/202602250007_upload_policy_checks.sql"
  "supabase/migrations/202602250008_challenge_entries.sql"
  "supabase/migrations/202602250009_push_notifications.sql"
  "supabase/migrations/202602250010_premium_entitlements.sql"
  "supabase/migrations/202602250011_sponsored_community_templates.sql"
  "supabase/migrations/202602250012_experiment_framework.sql"
  "supabase/functions/create-community/index.ts"
  "supabase/functions/list-sponsored-community-templates/index.ts"
  "supabase/functions/join-community/index.ts"
  "supabase/functions/create-post/index.ts"
  "supabase/functions/moderate-upload/index.ts"
  "supabase/functions/create-poll/index.ts"
  "supabase/functions/vote-poll/index.ts"
  "supabase/functions/list-trending-polls/index.ts"
  "supabase/functions/create-challenge/index.ts"
  "supabase/functions/list-trending-challenges/index.ts"
  "supabase/functions/submit-challenge-entry/index.ts"
  "supabase/functions/register-push-token/index.ts"
  "supabase/functions/unregister-push-token/index.ts"
  "supabase/functions/list-notification-events/index.ts"
  "supabase/functions/send-push-notifications/index.ts"
  "supabase/functions/list-subscription-products/index.ts"
  "supabase/functions/list-user-entitlements/index.ts"
  "supabase/functions/activate-premium-trial/index.ts"
  "supabase/functions/set-entitlement/index.ts"
  "supabase/functions/list-feature-flags/index.ts"
  "supabase/functions/track-experiment-event/index.ts"
  "supabase/functions/react-to-post/index.ts"
  "supabase/functions/report-content/index.ts"
  "supabase/functions/block-user/index.ts"
  "supabase/functions/create-private-chat-link/index.ts"
  "supabase/functions/join-private-chat/index.ts"
  "supabase/functions/read-private-message-once/index.ts"
  "supabase/functions/expire-content/index.ts"
  "supabase/functions/list-reports/index.ts"
  "supabase/functions/review-report/index.ts"
  "supabase/functions/enforce-user/index.ts"
  "supabase/functions/_shared/enforcement.ts"
  "supabase/functions/_shared/entitlements.ts"
  "supabase/functions/_shared/media.ts"
  "supabase/functions/_shared/push.ts"
  "supabase/functions/_shared/rate_limit.ts"
  "scripts/validate-migrations-postgres.sh"
  "apps/mobile/lib/features/feed/data/feed_repository.dart"
  "apps/mobile/lib/features/feed/application/feed_controllers.dart"
  "apps/mobile/lib/features/legal/presentation/legal_screen.dart"
  "apps/mobile/lib/features/engagement/data/engagement_edge_functions.dart"
  "apps/mobile/lib/features/engagement/presentation/polls_screen.dart"
  "apps/mobile/lib/features/engagement/presentation/challenges_screen.dart"
  "apps/mobile/lib/features/notifications/data/notification_edge_functions.dart"
  "apps/mobile/lib/features/notifications/presentation/notifications_screen.dart"
  "apps/mobile/lib/features/premium/domain/premium_models.dart"
  "apps/mobile/lib/features/premium/data/premium_edge_functions.dart"
  "apps/mobile/lib/features/premium/application/premium_providers.dart"
  "apps/mobile/lib/features/premium/presentation/premium_screen.dart"
  "apps/mobile/lib/features/experiments/domain/feature_flag.dart"
  "apps/mobile/lib/features/experiments/data/experiment_edge_functions.dart"
  "apps/mobile/lib/features/experiments/application/experiment_providers.dart"
  ".github/workflows/ci.yml"
  ".github/workflows/media-retention.yml"
  ".github/workflows/push-delivery.yml"
  "scripts/run-expire-content.sh"
  "scripts/run-send-push-notifications.sh"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file"
    exit 1
  fi
done

sql_file="supabase/migrations/202602250001_initial_schema.sql"
required_patterns=(
  "create table if not exists public.communities"
  "create table if not exists public.posts"
  "create table if not exists public.replies"
  "alter table public.communities enable row level security"
  "create policy"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -qi "$pattern" "$sql_file"; then
    echo "Missing SQL pattern: $pattern"
    exit 1
  fi
done

echo "Foundation validation passed."
