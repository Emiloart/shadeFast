# Performance Validation Protocol

## Goal

Validate startup and feed performance before public beta using the telemetry added in the launch optimization sprint.

## Target Metrics

- `app_first_frame`: P95 under 1800 ms on mid-tier devices.
- `app_startup_ready`: P95 under 2500 ms on mid-tier devices.
- `feed_first_content_paint`: P95 under 2200 ms on Wi-Fi and under 3200 ms on standard cellular.
- `feed_fetch_completed`: initial global/community fetch under 1500 ms median in staging.

## Device Matrix

- Low-tier Android: 3-4 GB RAM, older midrange CPU.
- Mid-tier Android: 6-8 GB RAM, current mainstream device.
- iPhone baseline: recent non-Pro device.

## Test Modes

1. Run profile mode, not debug mode.
2. Use staging backend with production-like data volume.
3. Test on Wi-Fi and one normal cellular connection.

## Commands

```bash
flutter run --profile
flutter build appbundle --release
flutter build ios --release
```

## Test Flows

1. Cold launch to onboarding ready state.
2. Enter Global Hot and wait for first content paint.
3. Create or join a community and wait for community feed first content paint.
4. Pull to refresh both feeds once.
5. Scroll enough to trigger one `load_more` event in both feed types.

## Capture Checklist

- [ ] Save measured timing values for each device/network run.
- [ ] Note visible jank, dropped frames, or loading stalls.
- [ ] Record whether feeds were empty or content-filled during measurement.
- [ ] Record any failed telemetry events or repeated fetch errors.

## Exit Criteria

- All target metrics met on the baseline device matrix.
- No blocking UI jank during cold launch or initial feed render.
- Any regressions converted into explicit backlog items before store submission.
