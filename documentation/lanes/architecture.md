<!-- doc-discipline: one-line table cells (≤50 words), no implementation prose, no API endpoint contracts (those go in api-reference.md). -->

# Architecture

System overview, component map, and data flow.

**Audience:** Developers

---

## Overview

Zipline Native is an Android Flutter app plus a small Cloudflare Worker. The app handles Android `ACTION_SEND` intents and forwards files/URLs to a configured [Zipline](https://github.com/diced/zipline) server. The Worker brokers OAuth/OIDC flows by converting HTTPS callbacks to `zipline://` deep links. Product intent: [`sdd/README.md`](../../sdd/README.md).

## Components

| Component | Role |
|---|---|
| Flutter app (Dart) | UI, business logic, network client, secure storage. <!-- @impl: lib/main.dart::main --> |
| `MainActivity` (Kotlin) | Captures share intents, exposes them to Flutter over MethodChannel. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::MainActivity --> |
| OAuth Worker (JS) | Server-side OAuth code exchange + base64 cookie passthrough. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> |
| `AuthService` | Username/password login, CF Access headers, session cookie storage. <!-- @impl: lib/services/auth_service.dart::AuthService --> |
| `OAuthService` | OAuth URL request, deep-link callback handling, state validation. <!-- @impl: lib/services/oauth_service.dart::OAuthService --> |
| `BiometricService` | local_auth integration, enable/disable, prompt-on-resume. <!-- @impl: lib/services/biometric_service.dart::BiometricService --> |
| `IntentService` | Dart-side wrapper over the share-intent MethodChannel + URI extension inference. <!-- @impl: lib/services/intent_service.dart::IntentService --> |
| `FileUploadService` | Multipart upload via Dio, shorten cascade, file delete. <!-- @impl: lib/services/file_upload_service.dart::FileUploadService --> |
| `UploadQueueService` | Concurrent-bounded pipeline with exponential-backoff retry. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService --> |
| `DebugService` | 5000-entry log ring buffer with category/level filters, JSON export. <!-- @impl: lib/services/debug_service.dart::DebugService --> |
| `ActivityService` | SharedPreferences-backed list of recent uploads (max 50). <!-- @impl: lib/services/activity_service.dart::ActivityService --> |
| `ConnectivityService` | connectivity_plus stream surfaced as ChangeNotifier. <!-- @impl: lib/services/connectivity_service.dart::ConnectivityService --> |
| `AppState` / `ThemeProvider` | Global ChangeNotifier providers for user state + theme. <!-- @impl: lib/providers/app_state.dart::AppState --> |

## Source Modules

| Path | Responsibility | Implements |
|---|---|---|
| `lib/main.dart` | Entry point: DI setup, splash, auth/biometric routing. <!-- @impl: lib/main.dart::main --> | [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-wire-dependency-injection-on-app-start), [REQ-BOOT-002](../../sdd/spec/app-bootstrap.md#req-boot-002-wrap-the-widget-tree-in-appstate-and-themeprovider), [REQ-BOOT-003](../../sdd/spec/app-bootstrap.md#req-boot-003-splash-routes-to-home-or-login-based-on-auth-state), [REQ-BOOT-004](../../sdd/spec/app-bootstrap.md#req-boot-004-biometric-gate-before-home) |
| `lib/core/service_locator.dart` | get_it registrations: singletons, lazy singletons, factories. <!-- @impl: lib/core/service_locator.dart::setupServiceLocator --> | [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-wire-dependency-injection-on-app-start) |
| `lib/core/constants.dart` | AppConstants (animation, layout, color) + AppTheme.dark/lightTheme. <!-- @impl: lib/core/constants.dart::AppTheme --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-theme-mode-persistence) |
| `lib/core/build_config.dart` | --dart-define-driven OAUTH_REDIRECT_URL override. <!-- @impl: lib/core/build_config.dart::BuildConfig --> | [REQ-OAUTH-001](../../sdd/spec/oauth.md#req-oauth-001-initiate-oauth-flow-with-worker-redirect-uri) |
| `lib/services/auth_service.dart` | Credentials, session cookie, CF Access headers, sensitive-data migration. <!-- @impl: lib/services/auth_service.dart::AuthService --> | [REQ-AUTH-001](../../sdd/spec/authentication.md#req-auth-001-usernamepassword-login-captures-and-stores-session-cookie), [REQ-AUTH-002](../../sdd/spec/authentication.md#req-auth-002-session-presence-check), [REQ-AUTH-003](../../sdd/spec/authentication.md#req-auth-003-cloudflare-access-service-token-forwarding), [REQ-AUTH-004](../../sdd/spec/authentication.md#req-auth-004-logout-clears-every-credential-surface), [REQ-AUTH-005](../../sdd/spec/authentication.md#req-auth-005-legacy-sharedpreferences--secure-storage-migration) |
| `lib/services/oauth_service.dart` | OAuth flow orchestration + callback handler + cold-start recovery. <!-- @impl: lib/services/oauth_service.dart::OAuthService --> | [REQ-OAUTH-001](../../sdd/spec/oauth.md#req-oauth-001-initiate-oauth-flow-with-worker-redirect-uri), [REQ-OAUTH-002](../../sdd/spec/oauth.md#req-oauth-002-session-cookie-storage-after-callback), [REQ-OAUTH-003](../../sdd/spec/oauth.md#req-oauth-003-clear-oauth-session-on-logout), [REQ-OAUTH-004](../../sdd/spec/oauth.md#req-oauth-004-cold-start-callback-recovery) |
| `lib/services/biometric_service.dart` | local_auth wrappers, enable/disable, prompt. <!-- @impl: lib/services/biometric_service.dart::BiometricService --> | [REQ-BIO-001](../../sdd/spec/biometric.md#req-bio-001-enable--disable-biometric-from-settings), [REQ-BIO-002](../../sdd/spec/biometric.md#req-bio-002-prompt-on-resume-when-enabled), [REQ-BIO-003](../../sdd/spec/biometric.md#req-bio-003-disable-biometric-from-settings-or-on-logout) |
| `lib/services/intent_service.dart` | MethodChannel wrappers + URI extension inference. <!-- @impl: lib/services/intent_service.dart::IntentService --> | [REQ-SHARE-003](../../sdd/spec/share-intent.md#req-share-003-methodchannel-bridge-exposes-shares-to-flutter), [REQ-SHARE-004](../../sdd/spec/share-intent.md#req-share-004-file-extension-inference-for-android-content-uris) |
| `lib/services/sharing_service.dart` | Callback wiring between share intake and upload pipeline. <!-- @impl: lib/services/sharing_service.dart::SharingService --> | [REQ-SHARE-003](../../sdd/spec/share-intent.md#req-share-003-methodchannel-bridge-exposes-shares-to-flutter) |
| `lib/services/file_upload_service.dart` | Multipart upload, shorten cascade, file/url delete, password attempt. <!-- @impl: lib/services/file_upload_service.dart::FileUploadService --> | [REQ-UPLOAD-001](../../sdd/spec/upload.md#req-upload-001-multipart-upload-to-zipline-apiupload), [REQ-UPLOAD-002](../../sdd/spec/upload.md#req-upload-002-mime-type-detection-by-extension), [REQ-UPLOAD-003](../../sdd/spec/upload.md#req-upload-003-progress-callbacks-at-upload-task-granularity), [REQ-UPLOAD-004](../../sdd/spec/upload.md#req-upload-004-structured-error-result-on-failure), [REQ-URL-001](../../sdd/spec/url-shortener.md#req-url-001-shorten-a-url-with-v4--v3--legacy-fallback), [REQ-URL-002](../../sdd/spec/url-shortener.md#req-url-002-custom-slug-vanity-support), [REQ-FILES-001](../../sdd/spec/file-management.md#req-files-001-delete-an-uploaded-file), [REQ-FILES-002](../../sdd/spec/file-management.md#req-files-002-delete-a-short-url), [REQ-FILES-003](../../sdd/spec/file-management.md#req-files-003-best-effort-file-password-under-triage) |
| `lib/services/upload_queue_service.dart` | Bounded-concurrency queue + retry + cancel + stream. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService --> | [REQ-QUEUE-001](../../sdd/spec/upload-queue.md#req-queue-001-concurrent-bounded-pipeline), [REQ-QUEUE-002](../../sdd/spec/upload-queue.md#req-queue-002-exponential-backoff-retry), [REQ-QUEUE-003](../../sdd/spec/upload-queue.md#req-queue-003-cancellation-via-canceltoken), [REQ-QUEUE-004](../../sdd/spec/upload-queue.md#req-queue-004-status-stream-broadcasts-queue-state) |
| `lib/services/activity_service.dart` | SharedPreferences-backed recent-uploads cache. <!-- @impl: lib/services/activity_service.dart::ActivityService --> | [REQ-ACTIVITY-001](../../sdd/spec/activity-log.md#req-activity-001-persist-recent-uploads-in-sharedpreferences), [REQ-ACTIVITY-002](../../sdd/spec/activity-log.md#req-activity-002-activity-row-is-created-after-every-successful-upload) |
| `lib/services/debug_service.dart` | Categorized ring buffer + JSON export. <!-- @impl: lib/services/debug_service.dart::DebugService --> | [REQ-LOG-001](../../sdd/spec/debug-diagnostics.md#req-log-001-categorized-ring-buffer), [REQ-LOG-002](../../sdd/spec/debug-diagnostics.md#req-log-002-opt-in-toggle-persists-across-sessions), [REQ-LOG-004](../../sdd/spec/debug-diagnostics.md#req-log-004-json-export-to-documents-directory) |
| `lib/services/connectivity_service.dart` | connectivity_plus stream + ChangeNotifier surface. <!-- @impl: lib/services/connectivity_service.dart::ConnectivityService --> | [REQ-CONN-001](../../sdd/spec/connectivity.md#req-conn-001-network-state-stream-broadcast-to-widget-tree) |
| `lib/providers/app_state.dart` | Global ChangeNotifier: user, auth, uploads, errors. <!-- @impl: lib/providers/app_state.dart::AppState --> | [REQ-STATE-001](../../sdd/spec/theme-and-state.md#req-state-001-global-appstate) |
| `lib/providers/theme_provider.dart` | Theme mode + SharedPreferences persistence. <!-- @impl: lib/providers/theme_provider.dart::ThemeProvider --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-theme-mode-persistence) |
| `lib/screens/simple_login_screen.dart` | Active login form (server URL, username, password). <!-- @impl: lib/screens/simple_login_screen.dart::SimpleLoginScreen --> | [REQ-AUTH-001](../../sdd/spec/authentication.md#req-auth-001-usernamepassword-login-captures-and-stores-session-cookie), [REQ-OAUTH-001](../../sdd/spec/oauth.md#req-oauth-001-initiate-oauth-flow-with-worker-redirect-uri) |
| `lib/screens/home_screen.dart` | Main UI: upload, shorten, activity, settings entry. <!-- @impl: lib/screens/home_screen.dart::HomeScreen --> | [REQ-UPLOAD-001](../../sdd/spec/upload.md#req-upload-001-multipart-upload-to-zipline-apiupload), [REQ-URL-001](../../sdd/spec/url-shortener.md#req-url-001-shorten-a-url-with-v4--v3--legacy-fallback) |
| `lib/screens/settings_screen.dart` | Server URL, CF Access, biometric, debug, OAuth, theme, logout. <!-- @impl: lib/screens/settings_screen.dart::SettingsScreen --> | [REQ-AUTH-003](../../sdd/spec/authentication.md#req-auth-003-cloudflare-access-service-token-forwarding), [REQ-BIO-001](../../sdd/spec/biometric.md#req-bio-001-enable--disable-biometric-from-settings), [REQ-LOG-002](../../sdd/spec/debug-diagnostics.md#req-log-002-opt-in-toggle-persists-across-sessions) |
| `lib/screens/debug_screen.dart` | Log viewer with filter + clear + export. <!-- @impl: lib/screens/debug_screen.dart::DebugScreen --> | [REQ-LOG-003](../../sdd/spec/debug-diagnostics.md#req-log-003-filterable-log-viewer), [REQ-LOG-004](../../sdd/spec/debug-diagnostics.md#req-log-004-json-export-to-documents-directory) |
| `lib/widgets/upload_queue_widget.dart` | Per-task progress card with cancel. <!-- @impl: lib/widgets/upload_queue_widget.dart::UploadQueueWidget --> | [REQ-UPLOAD-003](../../sdd/spec/upload.md#req-upload-003-progress-callbacks-at-upload-task-granularity), [REQ-QUEUE-003](../../sdd/spec/upload-queue.md#req-queue-003-cancellation-via-canceltoken) |
| `lib/widgets/upload_queue_overlay.dart` | App-wide overlay surfacing queue progress. <!-- @impl: lib/widgets/upload_queue_overlay.dart::UploadQueueOverlay --> | [REQ-QUEUE-004](../../sdd/spec/upload-queue.md#req-queue-004-status-stream-broadcasts-queue-state) |
| `android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt` | Native share intake + MethodChannel handler. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::MainActivity --> | [REQ-SHARE-002](../../sdd/spec/share-intent.md#req-share-002-native-side-caches-incoming-share-payload), [REQ-SHARE-003](../../sdd/spec/share-intent.md#req-share-003-methodchannel-bridge-exposes-shares-to-flutter) |
| `android/app/src/main/AndroidManifest.xml` | Permissions + intent-filters + deep-link scheme declaration. <!-- @impl: android/app/src/main/AndroidManifest.xml::activity --> | [REQ-SHARE-001](../../sdd/spec/share-intent.md#req-share-001-declare-share-intent-filters-in-the-android-manifest) |
| `cloudflare-oauth-redirect/src/worker.js` | OAuth code exchange + base64 cookie passthrough + Intent URL fallback. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> | [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange), [REQ-OAUTH-006](../../sdd/spec/oauth.md#req-oauth-006-intent-url-fallback-for-unreliable-schemes) |
| `cloudflare-oauth-redirect/tests/worker.test.mjs` | Regression test asserting raw cookie never appears in HTML. <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::redirectToApp masks session cookie in HTML output --> | [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange) |

## Request Lifecycle

### Share-sheet upload (cold start)

```
Android share sheet
  → MainActivity.onCreate
    → handleIntent → caches pendingSharedFiles
  → Flutter engine init
    → main() → setupServiceLocator
    → SplashScreen → isAuthenticated → HomeScreen
  → HomeScreen.initState
    → IntentService.getSharedFiles (MethodChannel)
    → UploadQueueService.enqueue
      → FileUploadService.uploadFile (Dio multipart)
        → ActivityService.addActivity (success path)
```

### OAuth login (warm)

```
SimpleLoginScreen "Sign in with OAuth" tap
  → OAuthService.loginWithOAuth
    → http.get <ziplineUrl>/api/auth/oauth
    → Replace redirect_uri with Worker URL
    → url_launcher → external browser
  → User authenticates with provider
  → Provider redirects to <worker>/app/oauth-redirect?code=&state=
    → Worker exchanges code with Zipline → captures Set-Cookie
    → redirectToApp() → HTML with base64-encoded cookie
      → zipline://oauth-callback?cookie=<base64>
  → AppLinks stream picks up callback
    → OAuthService._handleCallback validates state
    → Stores session cookie in FlutterSecureStorage
  → SimpleLoginScreen advances to HomeScreen
```

## Data Flow

Persistent state lives on the device only:

- `FlutterSecureStorage` (`EncryptedSharedPreferences`): `session_cookie`, `password`, `cf_client_id`, `cf_client_secret`, `biometric_token`, OAuth session keys. <!-- @impl: lib/services/auth_service.dart::_secureStorage -->
- `SharedPreferences`: `zipline_url`, `zipline_username`, `theme_mode`, `debug_logs_enabled`, `biometric_enabled`, `recent_activities`. <!-- @impl: lib/services/auth_service.dart::_ziplineUrlKey = 'zipline_url' -->
- In-memory ring buffer (DebugService): up to 5000 log entries. <!-- @impl: lib/services/debug_service.dart::_maxLogs = 5000 -->

External calls leave the device for:

- The configured Zipline server (`/api/auth/login`, `/api/auth/oauth`, `/api/upload`, `/api/shorten`, `/api/user/files/*`, `/api/user/urls/*`).
- The Cloudflare Worker (`/app/oauth-redirect`) during OAuth flows.
- The OAuth provider (Authentik/Discord/Keycloak/etc) via the user's browser.

---

## Related Documentation

- [Configuration](configuration.md) — Env vars and build-time defines
- [API Reference](api-reference.md) — Cloudflare Worker contract
- [Decisions](../decisions/README.md) — Architectural decisions and rationale
