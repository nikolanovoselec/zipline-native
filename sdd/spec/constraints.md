# Constraints

Cross-cutting architectural and technology decisions that apply to every domain.

## Technology Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Mobile runtime | Flutter (Dart) | Single codebase targets Android first, leaves the door open for iOS without a rewrite. |
| Dependency injection | `get_it` + `provider` | Singleton + lazy + factory registrations for services; `ChangeNotifier` providers for UI-bound state. |
| Secure storage | `flutter_secure_storage` with `EncryptedSharedPreferences` | Every secret (session cookie, password, OAuth token, Cloudflare Access client id/secret) is held encrypted at rest. |
| HTTP for uploads | `dio` | Progress callbacks and `CancelToken` support that the stdlib `http` package does not provide. |
| HTTP for non-upload | `http` | Lightweight calls (`/api/auth/login`, `/api/auth/oauth`, etc) where progress is irrelevant. |
| Deep links | `app_links` + Android `<intent-filter>` for `zipline://` | `app_links` exposes both initial-link (cold start) and stream (warm-launch) APIs. |
| OAuth bridge | Cloudflare Worker | Bridges OAuth providers' HTTPS-only redirect URIs to the app's `zipline://` deep link. |
| Native bridge | Kotlin `FlutterFragmentActivity` + `MethodChannel` | Receives `ACTION_SEND` / `ACTION_SEND_MULTIPLE` intents and exposes shared files/text to Flutter. |

## Non-Functional Requirements

### CON-PLATFORM-001: Android-only target

The app is built and shipped for Android only. `android/app/build.gradle` declares `minSdk = 26` (Android 8.0) and `compileSdk = 36`. No iOS sources, no iOS keystore wiring, no `ios/` directory beyond Flutter's default scaffold.

**Applies To:** Build, deploy, runtime.

### CON-SEC-001: All secrets encrypted at rest

Session cookies, passwords, OAuth tokens, and Cloudflare Access client secrets are stored with `FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true))`. Plain `SharedPreferences` is used only for non-sensitive preferences (theme mode, debug-logs toggle, activity log, last-used Zipline URL, last-used username). A migration path silently moves legacy plaintext secrets from `SharedPreferences` to secure storage on first run.

**Applies To:** `AuthService`, `OAuthService`, `BiometricService`.

### CON-SEC-002: OAuth Worker masks raw session cookies in HTML

The Cloudflare Worker bridge never renders the raw `zipline_session` cookie value into the HTML it returns to the device. The cookie is base64-encoded and embedded in a redirect payload; the app decodes it from the deep-link callback. This is regression-tested in `cloudflare-oauth-redirect/tests/worker.test.mjs`.

**Applies To:** `cloudflare-oauth-redirect/src/worker.js`.

### CON-NET-001: Upload concurrency capped at 3

The upload queue maintains at most 3 in-flight uploads at any time. New tasks beyond the limit queue as `pending` and start when a slot frees up. The limit is a single constant in `UploadQueueService` and is not user-tunable from the UI.

**Applies To:** `UploadQueueService`.

### CON-NET-002: Upload retry bounded by exponential backoff

A failed upload retries up to 3 times with delays of 2s, 4s, then 8s. After the 3rd failure the task transitions to `failed` and stops consuming a queue slot. Cancellation via `CancelToken` skips retry entirely.

**Applies To:** `UploadQueueService._uploadFile`.

### CON-API-001: Tolerate Zipline server version drift

For shortener and file-management endpoints the client tries Zipline v4 shapes first, then v3, then legacy `/api/upload` with `format=RANDOM`. The cascade is hard-coded; the client does not negotiate server version.

**Applies To:** `FileUploadService.shortenUrl`, `FileUploadService.deleteFile`.

### CON-OBS-001: Debug logs are local and opt-in

The in-app debug log ring buffer holds at most 5000 entries in memory and is empty until the user toggles "Debug logs enabled" in settings. Logs never leave the device unless the user manually exports them to a JSON file via the debug screen.

**Applies To:** `DebugService`.

## Boundaries

Things the system intentionally does NOT do:

- **Cross-device sync** — the activity log, debug logs, and credentials are device-local; reinstalling the app loses all of them.
- **Background upload** — uploads run only while the app is in the foreground; backgrounded uploads pause and resume when the app returns.
- **Server-side credential rotation** — the app does not rotate Cloudflare Access tokens or Zipline passwords; the operator does that out-of-band.
- **Anti-tamper / root detection** — the app does not inspect the device for root, custom ROMs, or hooking frameworks. Threat model assumes a normally-secured device with a sane lock screen.
