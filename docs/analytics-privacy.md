# Analytics and Privacy Guardrails

## Principles

- No PII in telemetry payloads.
- Event names and properties are allowlisted and sanitized in-app.
- Telemetry failures are non-blocking and never break product flows.
- Error telemetry includes only coarse runtime type metadata.

## Mobile telemetry implementation

Source:
- `apps/mobile/lib/core/telemetry/app_telemetry.dart`

Behavior:
- sends events through `track-experiment-event`
- enforces safe key format: `[a-zA-Z0-9_]+`
- caps payload size:
  - max 20 properties
  - max 160 chars per string
  - max 10 strings in list values
- drops unsupported types and empty strings

## Current event coverage

- onboarding:
  - `onboarding_create_community_open`
  - `onboarding_join_community_submit`
  - `onboarding_join_community_success`
  - `onboarding_join_community_failure`
  - `onboarding_private_link_success`
  - `private_link_premium_required`
- posts:
  - `global_post_dialog_open`
  - `global_post_dialog_cancel`
  - `global_post_create_success`
  - `global_post_create_failure`
  - `community_post_dialog_open`
  - `community_post_dialog_cancel`
  - `community_post_create_success`
  - `community_post_create_failure`
- stability:
  - `app_unhandled_flutter_error`
  - `app_unhandled_platform_error`

## Operational checks

- Run `flutter test` to validate telemetry sanitization unit tests.
- Run `./scripts/smoke-remote.sh` to confirm experiment event endpoint remains healthy in integrated flows.
