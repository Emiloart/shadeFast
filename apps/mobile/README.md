# Mobile App (Flutter)

This directory will contain the Flutter client application.

Current baseline:
- Riverpod for state management
- GoRouter for navigation
- Supabase Flutter SDK for auth/data/realtime
- feature-first folder structure
- anonymous auth bootstrap provider
- onboarding actions for create/join community via edge functions
- create-community flow supports sponsored brand-safe template presets
- text/image/video post composer with storage upload and video compression
- media upload policy checks via `moderate-upload` before post submission
- trending polls/challenges discovery routes with create/vote and challenge-entry flows
- in-app deep-link route for community join (`/join/:code`)
- private chat deep-link route (`/chat/:token`) + link creation flow
- read-once private chat polling flow
- reply thread bottom sheet on posts
- report/block controls on feed cards
- legal + community guidelines route (`/legal`)
- notifications center route (`/notifications`) with delivery feed + push token tools
- premium route (`/premium`) with trial activation + entitlement status
- experiment framework baseline (feature-flag fetch + onboarding event tracking)
- global and community feeds wired to Supabase queries with pagination + refresh
- heart reaction toggle wired through `react-to-post` edge function
- Android/iOS projects generated and ready for build
- Android App Links + iOS URL scheme configured for invite links
- mobile release identifiers standardized:
  - Android package/application id: `io.shadefast.mobile`
  - iOS bundle id: `io.shadefast.mobile`

Run with env:

```
flutter run \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Release signing (Android)

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Replace values with your release keystore settings.
3. Place keystore file at the referenced `storeFile` path.

When `android/key.properties` is present, release builds use release signing.
Without it, release builds fall back to debug signing for local smoke usage only.
