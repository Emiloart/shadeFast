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

1. Set secrets in Supabase project:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. Deploy:
   - `supabase functions deploy create-community`
   - `supabase functions deploy list-sponsored-community-templates`
   - `supabase functions deploy join-community`
   - `supabase functions deploy create-post`
   - `supabase functions deploy moderate-upload`
   - `supabase functions deploy create-poll`
   - `supabase functions deploy vote-poll`
   - `supabase functions deploy list-trending-polls`
   - `supabase functions deploy create-challenge`
   - `supabase functions deploy list-trending-challenges`
   - `supabase functions deploy submit-challenge-entry`
   - `supabase functions deploy register-push-token`
   - `supabase functions deploy unregister-push-token`
   - `supabase functions deploy list-notification-events`
   - `supabase functions deploy send-push-notifications`
   - `supabase functions deploy list-subscription-products`
   - `supabase functions deploy list-user-entitlements`
   - `supabase functions deploy activate-premium-trial`
   - `supabase functions deploy set-entitlement`
   - `supabase functions deploy list-feature-flags`
   - `supabase functions deploy track-experiment-event`
   - `supabase functions deploy react-to-post`
   - `supabase functions deploy report-content`
   - `supabase functions deploy block-user`
   - `supabase functions deploy create-private-chat-link`
   - `supabase functions deploy join-private-chat`
   - `supabase functions deploy read-private-message-once`
   - `supabase functions deploy expire-content`
   - `supabase functions deploy list-reports`
   - `supabase functions deploy review-report`
   - `supabase functions deploy enforce-user`
