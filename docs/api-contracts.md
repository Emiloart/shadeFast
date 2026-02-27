# API Contracts (Edge Functions)

## `create-community`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "name": "Midtown High Tea",
  "description": "Optional description",
  "category": "school",
  "isPrivate": false,
  "templateId": "campus-club-safe"
}
```

Rules:
- `name` must be between `2` and `80` characters
- `description` max length is `500`
- `category` must be one of `school`, `workplace`, `faith`, `neighborhood`, `other`
- optional `templateId` must reference an active sponsored template
- when `templateId` is provided, omitted fields can inherit template defaults

Response `201`:

```json
{
  "community": {
    "id": "uuid",
    "name": "Midtown High Tea",
    "description": "Optional description",
    "category": "school",
    "is_private": false,
    "join_code": "AB12CD34",
    "created_at": "2026-02-25T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_name`
- `invalid_description`
- `invalid_category`
- `template_lookup_failed`
- `template_not_found`
- `community_create_failed`
- `community_membership_failed`

## `list-sponsored-community-templates`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "category": "school",
  "limit": 20
}
```

Rules:
- optional `category` must be one of `school`, `workplace`, `faith`, `neighborhood`, `other`
- `limit` must be between `1` and `50`

Response `200`:

```json
{
  "templates": [
    {
      "id": "campus-club-safe",
      "displayName": "Campus Club Safe Template",
      "description": "School-focused space with clear rules and low moderation risk prompts.",
      "category": "school",
      "defaultTitle": "Campus Tea Circle",
      "defaultDescription": "Keep it sharp but avoid naming private individuals or sharing personal info.",
      "defaultIsPrivate": false,
      "rules": [
        "No doxxing or personal contact info."
      ],
      "createdAt": "2026-02-25T00:00:00.000Z"
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_category`
- `invalid_limit`
- `templates_query_failed`

## `join-community`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "joinCode": "AB12CD34"
}
```

Alternative request body:

```json
{
  "communityId": "uuid"
}
```

Response `200`:

```json
{
  "community": {
    "id": "uuid",
    "name": "Midtown High Tea",
    "description": null,
    "category": "school",
    "is_private": false,
    "join_code": "AB12CD34",
    "created_at": "2026-02-25T00:00:00.000Z"
  },
  "membership": {
    "id": "uuid",
    "role": "member",
    "created_at": "2026-02-25T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `missing_locator`
- `community_not_found`
- `join_code_required`
- `membership_create_failed`

## `create-post`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "communityId": "uuid-or-null",
  "content": "Optional text body",
  "imageUrl": "https://cdn.example/image.jpg",
  "videoUrl": "https://cdn.example/video.mp4",
  "ttlHours": 24
}
```

Rules:
- at least one of `content`, `imageUrl`, or `videoUrl` is required
- `ttlHours` must be `24` or `48`
- private communities require active membership

Response `201`:

```json
{
  "post": {
    "id": "uuid",
    "community_id": null,
    "user_uuid": "uuid",
    "content": "Optional text body",
    "image_url": null,
    "video_url": null,
    "like_count": 0,
    "view_count": 0,
    "created_at": "2026-02-25T00:00:00.000Z",
    "expires_at": "2026-02-26T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `missing_content`
- `content_too_long`
- `invalid_image_url`
- `invalid_video_url`
- `invalid_media_url`
- `media_not_owned`
- `invalid_media_type`
- `media_policy_lookup_failed`
- `media_policy_missing`
- `media_policy_blocked`
- `media_policy_error`
- `media_policy_expired`
- `invalid_ttl`
- `community_not_found`
- `membership_required`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `post_create_failed`

## `moderate-upload`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "objectPath": "posts/<user_uuid>/1700000000000.jpg",
  "mediaType": "image"
}
```

Alternative request body:

```json
{
  "mediaUrl": "https://<project>.supabase.co/storage/v1/object/sign/media/posts/<user_uuid>/1700000000000.jpg?...",
  "mediaType": "image"
}
```

Rules:
- `objectPath` or `mediaUrl` is required
- media path must belong to the authenticated anonymous user
- `mediaType` must be `image` or `video` and match path prefix (`posts/` vs `videos/`)
- upload must pass built-in MIME/size checks (`image <= 8MB`, `video <= 10MB`)
- optional webhook moderation can be enabled with function secrets

Response `200`:

```json
{
  "verdict": {
    "status": "approved",
    "mediaType": "image",
    "objectPath": "posts/<user_uuid>/1700000000000.jpg",
    "mimeType": "image/jpeg",
    "byteSize": 412332,
    "provider": "builtin",
    "providerReference": null,
    "confidence": null,
    "labels": []
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `missing_media_target`
- `media_not_owned`
- `invalid_media_type`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `media_not_found`
- `media_read_failed`
- `media_blocked`
- `policy_provider_unavailable`

## `create-poll`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "communityId": "uuid-or-null",
  "content": "Optional post body",
  "question": "Who had the worst manager?",
  "options": ["Me", "My teammate", "Both"],
  "ttlHours": 24,
  "challengeId": "uuid-or-null"
}
```

Rules:
- `question` length must be between `3` and `280`
- `options` length must be between `2` and `6` and each option <= `80` chars
- options must be unique (case-insensitive)
- `ttlHours` must be `24` or `48`
- private communities require active membership
- optional `challengeId` must reference a non-expired challenge

Response `201`:

```json
{
  "poll": {
    "id": "uuid",
    "post_id": "uuid",
    "question": "Who had the worst manager?",
    "options": ["Me", "My teammate", "Both"],
    "created_at": "2026-02-25T00:00:00.000Z"
  },
  "post": {
    "id": "uuid",
    "community_id": null,
    "user_uuid": "uuid",
    "content": "Optional post body",
    "image_url": null,
    "video_url": null,
    "like_count": 0,
    "view_count": 0,
    "created_at": "2026-02-25T00:00:00.000Z",
    "expires_at": "2026-02-26T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_question`
- `invalid_options`
- `option_too_long`
- `duplicate_options`
- `content_too_long`
- `invalid_ttl`
- `invalid_community_id`
- `invalid_challenge_id`
- `community_not_found`
- `membership_required`
- `challenge_not_found`
- `challenge_expired`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `poll_post_create_failed`
- `poll_create_failed`

## `vote-poll`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "pollId": "uuid",
  "optionIndex": 1
}
```

Rules:
- `pollId` must be valid UUID
- `optionIndex` must be a valid integer index in poll options
- voter must have access to the poll's community context
- repeat votes overwrite the previous option for that poll/user

Response `200`:

```json
{
  "pollId": "uuid",
  "selectedOptionIndex": 1,
  "totalVotes": 24,
  "counts": [5, 12, 7]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_poll_id`
- `invalid_option_index`
- `option_index_out_of_bounds`
- `poll_not_found`
- `poll_expired`
- `membership_required`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `poll_vote_failed`
- `poll_tally_failed`

## `list-trending-polls`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "limit": 20,
  "communityId": "uuid-or-null"
}
```

Rules:
- `limit` must be between `1` and `50`
- optional `communityId` limits results to a single community
- private community results require active membership

Response `200`:

```json
{
  "polls": [
    {
      "id": "uuid",
      "question": "Who had the worst manager?",
      "options": ["Me", "My teammate", "Both"],
      "counts": [5, 12, 7],
      "totalVotes": 24,
      "trendScore": 51,
      "selectedOptionIndex": 1,
      "createdAt": "2026-02-25T00:00:00.000Z",
      "post": {
        "id": "uuid",
        "communityId": null,
        "content": "Optional context",
        "likeCount": 3,
        "createdAt": "2026-02-25T00:00:00.000Z",
        "expiresAt": "2026-02-26T00:00:00.000Z"
      }
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_limit`
- `invalid_community_id`
- `membership_required`
- `polls_query_failed`
- `poll_votes_query_failed`
- `poll_user_votes_query_failed`

## `create-challenge`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "title": "Post your worst boss story",
  "description": "Keep names out, details in.",
  "durationDays": 7
}
```

Rules:
- `title` must be between `3` and `120` chars
- `description` max length `1000`
- `durationDays` must be between `1` and `14`

Response `201`:

```json
{
  "challenge": {
    "id": "uuid",
    "title": "Post your worst boss story",
    "description": "Keep names out, details in.",
    "creator_uuid": "uuid",
    "created_at": "2026-02-25T00:00:00.000Z",
    "expires_at": "2026-03-04T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_title`
- `description_too_long`
- `invalid_duration_days`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `challenge_create_failed`

## `list-trending-challenges`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "limit": 20
}
```

Rules:
- `limit` must be between `1` and `50`

Response `200`:

```json
{
  "challenges": [
    {
      "id": "uuid",
      "title": "Post your worst boss story",
      "description": "Keep names out, details in.",
      "creatorUuid": "uuid",
      "createdAt": "2026-02-25T00:00:00.000Z",
      "expiresAt": "2026-03-04T00:00:00.000Z",
      "entryCount": 14,
      "recentEntryCount": 6,
      "participantCount": 12,
      "trendScore": 46
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_limit`
- `challenges_query_failed`
- `challenge_entries_query_failed`

## `submit-challenge-entry`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "challengeId": "uuid",
  "postId": "uuid"
}
```

Rules:
- `challengeId` and `postId` must be valid UUIDs
- challenge must be active (not expired)
- post must exist, be active, and be owned by the current user
- duplicate submissions for same challenge/post are idempotent

Response `201`:

```json
{
  "entry": {
    "id": "uuid",
    "challenge_id": "uuid",
    "post_id": "uuid",
    "user_uuid": "uuid",
    "created_at": "2026-02-25T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_challenge_id`
- `invalid_post_id`
- `challenge_not_found`
- `challenge_expired`
- `post_not_found`
- `not_post_owner`
- `post_expired`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `challenge_entry_submit_failed`

## `register-push-token`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "token": "push-provider-token",
  "platform": "android",
  "locale": "en-US",
  "appVersion": "0.1.0"
}
```

Rules:
- `token` length must be between `16` and `4096`
- `platform` must be one of `ios`, `android`, `web`
- token registration is upserted by token value and re-activates revoked tokens

Response `200`:

```json
{
  "registration": {
    "id": "uuid",
    "userUuid": "uuid",
    "token": "push-provider-token",
    "platform": "android",
    "locale": "en-US",
    "appVersion": "0.1.0",
    "lastSeenAt": "2026-02-25T00:00:00.000Z",
    "revokedAt": null
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_token`
- `invalid_platform`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `push_token_register_failed`

## `unregister-push-token`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "token": "optional-specific-token"
}
```

Rules:
- if `token` is omitted, all active tokens for current anonymous user are revoked

Response `200`:

```json
{
  "revoked": 1
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `push_token_unregister_failed`

## `list-notification-events`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "limit": 30,
  "beforeCreatedAt": "2026-02-25T00:00:00.000Z",
  "eventType": "reply"
}
```

Rules:
- `limit` must be between `1` and `100`
- optional `eventType` must be one of `reply`, `reaction`, `challenge_entry`, `system`
- optional `beforeCreatedAt` must be ISO datetime string

Response `200`:

```json
{
  "events": [
    {
      "id": "uuid",
      "recipientUuid": "uuid",
      "eventType": "reply",
      "actorUuid": "uuid",
      "postId": "uuid",
      "replyId": "uuid",
      "payload": {
        "preview": "someone replied"
      },
      "createdAt": "2026-02-25T00:00:00.000Z",
      "deliveredAt": "2026-02-25T00:00:10.000Z",
      "deliveryAttempts": 1,
      "lastError": null
    }
  ],
  "undeliveredCount": 0
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_limit`
- `invalid_event_type`
- `invalid_before_created_at`
- `notification_events_query_failed`
- `notification_events_count_failed`

## `send-push-notifications`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "limit": 200,
  "dryRun": false
}
```

Rules:
- `limit` must be between `1` and `500`
- `dryRun` must be boolean
- endpoint requires service-role authorization
- requires `PUSH_PROVIDER_WEBHOOK_URL` secret when `dryRun=false`

Response `200`:

```json
{
  "queued": 24,
  "processed": 24,
  "delivered": 24,
  "failed": 0,
  "dryRun": false
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_limit`
- `invalid_dry_run`
- `notification_queue_lookup_failed`
- `push_token_lookup_failed`
- `missing_push_provider`

## `list-subscription-products`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{}
```

Response `200`:

```json
{
  "products": [
    {
      "id": "premium_monthly",
      "name": "ShadeFast Premium Monthly",
      "description": "Ads off, higher limits, premium-only features.",
      "is_active": true,
      "created_at": "2026-02-25T00:00:00.000Z"
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `subscription_products_query_failed`

## `list-user-entitlements`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "includeExpired": false,
  "limit": 30
}
```

Rules:
- `includeExpired` must be boolean
- `limit` must be between `1` and `100`

Response `200`:

```json
{
  "entitlements": [
    {
      "id": "uuid",
      "userUuid": "uuid",
      "productId": "premium_monthly",
      "status": "active",
      "source": "trial",
      "startedAt": "2026-02-25T00:00:00.000Z",
      "expiresAt": "2026-02-28T00:00:00.000Z",
      "revokedAt": null,
      "metadata": {
        "trial": true
      },
      "createdAt": "2026-02-25T00:00:00.000Z",
      "updatedAt": "2026-02-25T00:00:00.000Z",
      "isActive": true
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_include_expired`
- `invalid_limit`
- `user_entitlements_query_failed`

## `activate-premium-trial`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "days": 3
}
```

Rules:
- `days` must be between `1` and `7`
- each anonymous user can activate trial once

Response `201`:

```json
{
  "entitlement": {
    "id": "uuid",
    "productId": "premium_monthly",
    "status": "active",
    "source": "trial",
    "startedAt": "2026-02-25T00:00:00.000Z",
    "expiresAt": "2026-02-28T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_trial_days`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `trial_lookup_failed`
- `trial_already_used`
- `trial_activation_failed`

## `set-entitlement`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "userUuid": "uuid",
  "productId": "premium_monthly",
  "action": "grant",
  "durationDays": 30,
  "source": "admin"
}
```

Rules:
- `action` must be `grant` or `revoke`
- `durationDays` required for `grant` and must be between `1` and `3650`
- endpoint requires service-role authorization

Response `200`:

```json
{
  "userUuid": "uuid",
  "productId": "premium_monthly",
  "actionApplied": "grant",
  "activeEntitlement": {
    "id": "uuid",
    "productId": "premium_monthly",
    "status": "active",
    "source": "admin",
    "startedAt": "2026-02-25T00:00:00.000Z",
    "expiresAt": "2026-03-27T00:00:00.000Z",
    "revokedAt": null
  }
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_user_uuid`
- `invalid_product_id`
- `invalid_action`
- `invalid_duration_days`
- `entitlement_revoke_failed`
- `entitlement_previous_revoke_failed`
- `entitlement_grant_failed`
- `entitlement_status_failed`

## `list-feature-flags`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "includeDisabled": true
}
```

Rules:
- `includeDisabled` must be boolean
- flags are resolved per-user based on rollout percentage

Response `200`:

```json
{
  "flags": [
    {
      "id": "sponsored_templates",
      "enabled": true,
      "rolloutPercentage": 100,
      "config": {}
    }
  ]
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_include_disabled`
- `feature_flags_lookup_failed`

## `track-experiment-event`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "eventName": "onboarding_create_community_open",
  "properties": {
    "sponsoredTemplatesEnabled": true
  },
  "appVersion": "0.1.0",
  "platform": "mobile"
}
```

Rules:
- `eventName` must match `[a-z0-9_.-]` and be 2-64 chars
- optional `properties` must be a JSON object
- optional `appVersion` max length is `40`
- `platform` must be one of `ios`, `android`, `web`, `unknown`, `mobile`

Response `201`:

```json
{
  "ok": true,
  "event": {
    "id": "uuid",
    "eventName": "onboarding_create_community_open",
    "createdAt": "2026-02-25T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_event_name`
- `invalid_properties`
- `invalid_app_version`
- `invalid_platform`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `event_insert_failed`

## `react-to-post`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "postId": "uuid",
  "action": "add"
}
```

`action` values:
- `add`
- `remove`

Response `200`:

```json
{
  "postId": "uuid",
  "likeCount": 14,
  "liked": true
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_post_id`
- `invalid_action`
- `post_not_found`
- `post_expired`
- `membership_required`
- `reaction_add_failed`
- `reaction_remove_failed`
- `reaction_count_failed`

## `report-content`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body (post report):

```json
{
  "postId": "uuid",
  "reason": "harassment",
  "details": "optional free text"
}
```

Alternative request body (reply report):

```json
{
  "replyId": "uuid",
  "reason": "spam"
}
```

Rules:
- exactly one of `postId` or `replyId` is required
- `reason` must be one of `spam`, `harassment`, `hate`, `violence`, `sexual`, `self_harm`, `misinformation`, `other`
- `details` max length is `1000`
- target content must still be active (not expired)

Response `201`:

```json
{
  "ok": true,
  "reportId": "uuid",
  "createdAt": "2026-02-25T00:00:00.000Z"
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `missing_target`
- `ambiguous_target`
- `invalid_post_id`
- `invalid_reply_id`
- `invalid_reason`
- `details_too_long`
- `target_not_found`
- `post_not_found`
- `content_expired`
- `community_access_denied`
- `banned_user`
- `enforcement_check_failed`
- `rate_limited`
- `rate_limit_check_failed`
- `report_insert_failed`

## `block-user`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "blockedUserId": "uuid",
  "action": "add"
}
```

`action` values:
- `add`
- `remove`

Response `200`:

```json
{
  "blocked": true,
  "blockedUserId": "uuid"
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_blocked_user`
- `cannot_block_self`
- `invalid_action`
- `block_insert_failed`
- `block_delete_failed`

## `replies` (client-side table contract)

Reply threads are currently handled through direct Supabase table operations
from the mobile client under RLS policies (no edge function yet).

Read replies:

```dart
supabase
  .from('replies')
  .select('id, post_id, parent_reply_id, user_uuid, body, created_at, expires_at')
  .eq('post_id', postId)
  .order('created_at', ascending: true)
```

Create reply payload:

```json
{
  "post_id": "uuid",
  "parent_reply_id": "uuid-or-null",
  "user_uuid": "auth.uid()",
  "body": "reply body"
}
```

Rules:
- `body` length must be between `1` and `1500`
- `user_uuid` must match authenticated anonymous user
- target post must be visible + not expired
- private community posts require access membership

## `create-private-chat-link`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "readOnce": false,
  "ttlMinutes": 60
}
```

Rules:
- `readOnce` must be boolean
- `ttlMinutes` must be between `5` and `60`

Response `201`:

```json
{
  "chat": {
    "id": "uuid",
    "token": "A1B2C3D4E5F6A7B8",
    "readOnce": false,
    "expiresAt": "2026-02-25T00:00:00.000Z"
  },
  "entitlement": {
    "isPremium": false
  },
  "links": {
    "app": "shadefast://app/chat/A1B2C3D4E5F6A7B8",
    "web": "https://shadefast.io/chat/A1B2C3D4E5F6A7B8"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_read_once`
- `invalid_ttl`
- `banned_user`
- `enforcement_check_failed`
- `entitlement_check_failed`
- `private_link_quota_check_failed`
- `premium_required`
- `rate_limited`
- `rate_limit_check_failed`
- `chat_create_failed`
- `participant_create_failed`

## `join-private-chat`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "token": "A1B2C3D4E5F6A7B8"
}
```

Response `200`:

```json
{
  "chat": {
    "id": "uuid",
    "token": "A1B2C3D4E5F6A7B8",
    "readOnce": false,
    "expiresAt": "2026-02-25T00:00:00.000Z"
  }
}
```

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_token`
- `banned_user`
- `enforcement_check_failed`
- `chat_not_found`
- `chat_expired`
- `chat_lookup_failed`
- `participant_create_failed`

## `read-private-message-once`

Method: `POST`

Auth: `Authorization: Bearer <access_token>`

Request body:

```json
{
  "privateChatId": "uuid"
}
```

Response `200`:

```json
{
  "messages": [
    {
      "id": "uuid",
      "private_chat_id": "uuid",
      "sender_uuid": "uuid",
      "body": "message text",
      "created_at": "2026-02-25T00:00:00.000Z",
      "expires_at": "2026-02-25T01:00:00.000Z"
    }
  ]
}
```

Behavior:
- only valid for chats where `read_once = true`
- returns inbound unread messages for the current user
- returned messages are deleted immediately after successful read

Error codes:
- `missing_auth`
- `invalid_auth`
- `invalid_json`
- `invalid_private_chat_id`
- `chat_lookup_failed`
- `chat_not_found`
- `chat_expired`
- `chat_not_read_once`
- `membership_lookup_failed`
- `participant_required`
- `message_lookup_failed`
- `message_delete_failed`

## `expire-content`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "limit": 200,
  "dryRun": false
}
```

Rules:
- `limit` must be between `1` and `500`
- `dryRun` must be boolean
- endpoint is maintenance-only (service role auth)

Response `200`:

```json
{
  "processed": 12,
  "failed": 0,
  "queued": 12
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_limit`
- `invalid_dry_run`
- `queue_lookup_failed`

## `list-reports`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "status": "open",
  "limit": 50,
  "beforeCreatedAt": "2026-02-25T00:00:00.000Z"
}
```

Rules:
- `status` must be one of `open`, `in_review`, `resolved`, `dismissed`
- `limit` must be between `1` and `200`
- `beforeCreatedAt` must be an ISO datetime when provided

Response `200`:

```json
{
  "reports": [
    {
      "id": "uuid",
      "post_id": "uuid",
      "reply_id": null,
      "reason": "harassment",
      "details": "optional text",
      "reporter_uuid": "uuid",
      "created_at": "2026-02-25T00:00:00.000Z",
      "status": "open",
      "priority": "normal",
      "reviewed_at": null,
      "reviewed_by_uuid": null,
      "resolution_note": null
    }
  ]
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_status`
- `invalid_limit`
- `invalid_before_created_at`
- `reports_query_failed`

## `review-report`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "reportId": "uuid",
  "action": "resolved",
  "priority": "high",
  "resolutionNote": "Removed post and warned actor",
  "reviewedByUuid": "uuid"
}
```

Rules:
- `action` must be one of `in_review`, `resolved`, `dismissed`
- `priority` must be one of `low`, `normal`, `high`, `critical`
- `resolutionNote` max length `2000`
- `reviewedByUuid` optional UUID

Response `200`:

```json
{
  "report": {
    "id": "uuid",
    "status": "resolved",
    "priority": "high",
    "reviewed_at": "2026-02-25T00:00:00.000Z",
    "reviewed_by_uuid": "uuid",
    "resolution_note": "Removed post and warned actor"
  }
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_report_id`
- `invalid_action`
- `invalid_priority`
- `invalid_reviewed_by_uuid`
- `resolution_note_too_long`
- `report_not_found`
- `report_update_failed`

## `enforce-user`

Method: `POST`

Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`

Request body:

```json
{
  "userUuid": "uuid",
  "action": "ban_temp",
  "reason": "Repeated abuse reports",
  "durationMinutes": 1440,
  "createdByUuid": "uuid"
}
```

`action` values:
- `warn`
- `ban_temp`
- `ban_permanent`
- `revoke`

Response `200`:

```json
{
  "userUuid": "uuid",
  "activeBan": {
    "id": "uuid",
    "action": "ban_temp",
    "reason": "Repeated abuse reports",
    "expires_at": "2026-02-26T00:00:00.000Z",
    "created_at": "2026-02-25T00:00:00.000Z"
  },
  "actionApplied": "ban_temp"
}
```

Error codes:
- `invalid_auth`
- `invalid_json`
- `invalid_user_uuid`
- `invalid_action`
- `invalid_created_by_uuid`
- `reason_too_long`
- `invalid_duration_minutes`
- `enforcement_insert_failed`
- `enforcement_revoke_failed`
- `enforcement_status_failed`

## `chat_messages` (client-side table contract)

Private chat messages currently use direct table operations from the mobile client
after `join-private-chat` adds membership.
For `readOnce=true` chats, inbound reads should use `read-private-message-once`.

Read messages:

```dart
supabase
  .from('chat_messages')
  .stream(primaryKey: ['id'])
  .eq('private_chat_id', privateChatId)
  .order('created_at', ascending: true)
```

Send message payload:

```json
{
  "private_chat_id": "uuid",
  "sender_uuid": "auth.uid()",
  "body": "message body"
}
```

Rules:
- `body` length must be between `1` and `2000`
- `sender_uuid` must match authenticated anonymous user
- sender must be a participant in `private_chat_id`
- message visibility is bounded by `expires_at` policy
