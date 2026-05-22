<!-- doc-discipline: one-line table cells (≤50 words), env var entries only — no API contracts, no deploy commands. -->

# Configuration

**Audience:** Operators, Developers

Build-time defines, Worker environment variables, secrets, and signing artifacts.

---

## Flutter Build-time Defines

| Variable | Required | Default | Description |
|---|---|---|---|
| `OAUTH_REDIRECT_URL` | no | empty | Full URL of the Cloudflare Worker OAuth bridge. When empty the app derives `<ziplineHost>/app/oauth-redirect`. Set via `flutter build apk --dart-define=OAUTH_REDIRECT_URL=https://your-worker.example.com/app/oauth-redirect`. <!-- @impl: lib/core/build_config.dart::oauthRedirectUrl --> |

## Cloudflare Worker Environment

Configured in `cloudflare-oauth-redirect/wrangler.toml` (`[vars]` section for non-secret values, `wrangler secret put` for secrets).

| Variable | Required | Default | Description |
|---|---|---|---|
| `ZIPLINE_URL` | yes | none | The user's Zipline server URL — the Worker POSTs the OAuth code exchange to `<ZIPLINE_URL>/api/auth/oauth/callback`. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> |

## Cloudflare Worker Secrets

| Secret | Storage | Description |
|---|---|---|
| `CF_ACCESS_CLIENT_ID` | `wrangler secret put` | Cloudflare Access service-token client ID, if the Worker needs to traverse Access in front of Zipline. |
| `CF_ACCESS_CLIENT_SECRET` | `wrangler secret put` | Cloudflare Access service-token client secret, paired with `CF_ACCESS_CLIENT_ID`. |

## App-side Persisted Settings

The user configures these through the in-app Settings screen; they are not deploy-time inputs.

| Key | Storage | Description |
|---|---|---|
| `zipline_url` | SharedPreferences | The configured Zipline server URL. <!-- @impl: lib/services/auth_service.dart::_ziplineUrlKey = 'zipline_url' --> |
| `zipline_username` | SharedPreferences | Pre-fill for the login screen. <!-- @impl: lib/services/auth_service.dart::_usernameKey = 'zipline_username' --> |
| `session_cookie` | FlutterSecureStorage | The `zipline_session` value from the most recent login. <!-- @impl: lib/services/auth_service.dart::_sessionCookieKey = 'session_cookie' --> |
| `cf_client_id` | FlutterSecureStorage | Cloudflare Access client ID for app-side requests. <!-- @impl: lib/services/auth_service.dart::_cfClientIdKey = 'cf_client_id' --> |
| `cf_client_secret` | FlutterSecureStorage | Cloudflare Access client secret. <!-- @impl: lib/services/auth_service.dart::_cfClientSecretKey = 'cf_client_secret' --> |
| `biometric_enabled` | SharedPreferences | Whether the biometric gate is on. <!-- @impl: lib/services/biometric_service.dart::_biometricEnabledKey = 'biometric_enabled' --> |
| `biometric_token` | FlutterSecureStorage | The auth token captured at biometric-enable time. <!-- @impl: lib/services/biometric_service.dart::_biometricTokenKey = 'biometric_token' --> |
| `debug_logs_enabled` | SharedPreferences | Whether the in-app log capture is on. <!-- @impl: lib/services/debug_service.dart::initialize --> |
| `recent_activities` | SharedPreferences | JSON-encoded list of up to 50 recent uploads. <!-- @impl: lib/services/activity_service.dart::_activityKey = 'recent_activities' --> |

## Android Signing Configuration

| File | Purpose |
|---|---|
| `android/key.properties` | Operator-supplied keystore credentials (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`); gitignored. <!-- @impl: android/app/build.gradle::keystoreProperties --> |
| `<keystore>.jks` | The release keystore itself; operator-supplied, not in repo. |

## Android Build Configuration

| Setting | Value |
|---|---|
| `applicationId` | `com.example.zipline_native_app` (Flutter template default — see [TRIAGE-005](../../sdd/spec/.init-triage.md#triage-005-package-name-is-the-flutter-template-default)) <!-- @impl: android/app/build.gradle::applicationId = "com.example.zipline_native_app" --> |
| `minSdk` | 26 (Android 8.0) <!-- @impl: android/app/build.gradle::minSdk = 26 --> |
| `compileSdk` | 36 <!-- @impl: android/app/build.gradle::compileSdk = 36 --> |
| `ndkVersion` | `27.2.12479018` <!-- @impl: android/app/build.gradle::ndkVersion = "27.2.12479018" --> |
| Java/Kotlin target | 17 <!-- @impl: android/app/build.gradle::jvmTarget = '17' --> |

---

## Related Documentation

- [Deployment](deployment.md) — Build + deploy commands using these settings
- [Architecture](architecture.md) — Where each binding is consumed
