<!-- doc-discipline: one-line table cells (≤50 words), deploy commands and rollback steps only — no env var documentation (link to configuration.md). -->

# Deployment

**Audience:** Developers, Operators

Local build, APK release, and Cloudflare Worker deployment.

---

## Prerequisites

- Flutter SDK (channel `stable`)
- Android SDK + cmdline-tools (set `ANDROID_HOME`)
- Node.js 18+ (for the Worker)
- A Cloudflare account with Workers enabled (if shipping the OAuth bridge)
- A release-signing keystore (`*.jks`) for Play Store builds

## Local Development (App)

```bash
flutter pub get
flutter run -d <android-device-id>
```

The dev build talks to whatever Zipline server the user has configured in Settings. Set a non-default OAuth Worker hostname by passing `--dart-define`:

```bash
flutter run --dart-define=OAUTH_REDIRECT_URL=https://your-worker.example.com/app/oauth-redirect
```

## Local Development (Worker)

```bash
cd cloudflare-oauth-redirect
npm install
cp wrangler.toml.example wrangler.toml   # then edit account_id, route, ZIPLINE_URL
npm run dev
```

`npm run dev` runs `wrangler dev`; requests hit `http://localhost:8787/app/oauth-redirect` against the staging Worker bindings declared in `wrangler.toml`.

## Tests

```bash
# App-side widget/service tests
flutter test

# Worker regression tests (asserts cookie masking)
cd cloudflare-oauth-redirect && npm test
```

Tests are organized so each test references a REQ ID — `spec-reviewer` reads test files to verify which Implemented REQs have automated coverage. `enforce_tdd` is currently `false`; coverage gaps surface as informational findings rather than Status demotions.

## Production Deployment (Worker)

```bash
cd cloudflare-oauth-redirect
wrangler secret put CF_ACCESS_CLIENT_ID
wrangler secret put CF_ACCESS_CLIENT_SECRET
npm run deploy
```

After deploy, run `curl -I https://<your-worker>/app/oauth-redirect` and confirm a `200` response with the "Missing OAuth parameters" page (the success case requires real `code`+`state` query params).

## Production Deployment (App)

```bash
flutter build apk --release --split-per-abi \
  --dart-define=OAUTH_REDIRECT_URL=https://your-worker.example.com/app/oauth-redirect
```

The signed APK lands under `build/app/outputs/flutter-apk/`. Upload to GitHub Releases or sideload directly.

## Rollback

| Surface | Rollback path |
|---|---|
| Worker | `wrangler rollback` reverts to the previous deployment in the dashboard's deployment history. |
| App | Re-install the previous APK from GitHub Releases; the app preserves user state across reinstalls (SharedPreferences + EncryptedSharedPreferences survive). |

## Environment-specific Configuration

| Environment | Branch | Notes |
|---|---|---|
| Development | `develop` | OAuth bridge points at staging Worker; OAuth provider's redirect URI must match. |
| Production | `main` | OAuth bridge points at production Worker on the Operator-chosen hostname. |

## Cloudflare Resources

| Resource | Type | Purpose |
|---|---|---|
| `zipline-oauth-redirect` (operator-chosen name) | Worker | OAuth code-exchange bridge + base64 cookie passthrough. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> |

---

## Related Documentation

- [Configuration](configuration.md) — Env vars and signing config consumed here
- [API Reference](api-reference.md) — Worker contract
- [Architecture](architecture.md) — System overview
