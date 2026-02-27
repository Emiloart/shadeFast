# Edge Functions

## Implemented

- `create-community`
- `list-sponsored-community-templates`
- `join-community`
- `create-post`
- `moderate-upload`
- `create-poll`
- `vote-poll`
- `list-trending-polls`
- `create-challenge`
- `list-trending-challenges`
- `submit-challenge-entry`
- `register-push-token`
- `unregister-push-token`
- `list-notification-events`
- `send-push-notifications`
- `list-subscription-products`
- `list-user-entitlements`
- `activate-premium-trial`
- `set-entitlement`
- `list-feature-flags`
- `track-experiment-event`
- `react-to-post`
- `report-content`
- `block-user`
- `create-private-chat-link`
- `join-private-chat`
- `read-private-message-once`
- `expire-content`
- `list-reports`
- `review-report`
- `enforce-user`

## Planned (next)

- `send-private-message`

## Deploy notes

1. Reserved Supabase secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) are managed by the platform.
2. Optional provider secrets can still be set with `supabase secrets set ...` (push/webhook integrations).
3. Deploy all functions with repo-standard flags:
   - `./scripts/deploy-functions-remote.sh`
4. Deploy a subset:
   - `./scripts/deploy-functions-remote.sh create-post read-private-message-once`
5. Deploy to explicit project ref:
   - `./scripts/deploy-functions-remote.sh --project-ref <project_ref>`
