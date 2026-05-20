# Deployment

How to build and deploy the app and the OAuth Worker.

**Audience:** Developers shipping a release

## App release build (Android)

```bash
flutter pub get
flutter test
flutter build apk --release
```

Signed APK output: `build/app/outputs/flutter-apk/app-release.apk`. Signing config sourced from `android/key.properties` (see [configuration.md](configuration.md#android-signing-config)).

## App distribution

The app is distributed via GitHub Releases. There is no Play Store presence. CI workflow `release.yml` (when present) builds the APK, signs it, attaches it to a GitHub Release matching the tag.

## OAuth Worker deploy

```bash
cd cloudflare-oauth-redirect
npm install
npx wrangler deploy
```

Per-environment overrides (staging vs. production) live in `wrangler.toml` `[env.*]` sections.

## Worker / app version coupling

The Worker's deployed URL MUST match the `redirect_uri` registered in the Zipline OIDC client config AND the app's hard-coded `zipline://oauth-callback` scheme MUST match the Worker's redirect target. Changing any of the three requires a coordinated update.

## Rollback

- **App rollback:** previous APK from the GitHub Releases page; user reinstalls.
- **Worker rollback:** `npx wrangler rollback` to the previous deployment in CF.

## Pre-deploy checklist

- [ ] `flutter test` passes locally (manual; not enforced by CI)
- [ ] `npm test --prefix cloudflare-oauth-redirect` passes
- [ ] `wrangler.toml` `ZIPLINE_URL` matches the target instance
- [ ] Worker deploy URL matches Zipline OIDC client `redirect_uri` config
- [ ] No new local debug logs leak secrets ([REQ-OAUTH-003](../sdd/oauth-worker.md#req-oauth-003-cookie-redaction-in-logs))

## Related Documentation

- [Configuration](configuration.md) — Env vars and signing keys
- [Architecture § 8](architecture.md#8-build-and-deploy) — Build-time gotchas
