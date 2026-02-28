# Deep-Link Release Checklist

## Required host files

Publish both files from `deploy/domain/.well-known/` at:

- `https://shadefast.io/.well-known/assetlinks.json`
- `https://shadefast.io/.well-known/apple-app-site-association`

Mirror them to `www.shadefast.io` if your web host serves association files per-host.

## Android App Links

1. Edit `deploy/domain/.well-known/assetlinks.json`.
2. Replace `REPLACE_WITH_RELEASE_CERT_SHA256_FINGERPRINT` with the release signing certificate SHA-256 fingerprint.
3. Keep package name as `io.shadefast.mobile`.

## iOS Universal Links

1. Edit `deploy/domain/.well-known/apple-app-site-association`.
2. Replace `REPLACE_WITH_APPLE_TEAM_ID` with your Apple Team ID.
3. Keep bundle id suffix as `.io.shadefast.mobile`.
4. Keep paths for `/join/*` and `/chat/*`.

## Validation

Run:

```bash
./scripts/validate-domain-association.sh
```

This validates JSON structure and required fields before deployment.
