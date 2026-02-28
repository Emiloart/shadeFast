# Mobile Release Checklist

## Identity

- [x] Android namespace and app id set to `io.shadefast.mobile`.
- [x] iOS bundle id set to `io.shadefast.mobile`.
- [x] URL scheme configured: `shadefast://`.

## Signing

- [x] Android release signing wired via `apps/mobile/android/key.properties`.
- [x] Android fallback to debug signing documented for local smoke use only.
- [x] iOS signing style remains automatic pending Apple Developer team/profiles on release machine.

## Deep links

- [x] Android intent filters configured for:
  - `https://shadefast.io/join/*`
  - `https://shadefast.io/chat/*`
  - `shadefast://app/join/*`
  - `shadefast://app/chat/*`
- [x] iOS associated domains configured for:
  - `applinks:shadefast.io`
  - `applinks:www.shadefast.io`
- [x] Domain association files prepared in `deploy/domain/.well-known/`.

## Release commands

Android:

```bash
cd apps/mobile
flutter build appbundle --release
```

iOS:

```bash
cd apps/mobile
flutter build ios --release
```
