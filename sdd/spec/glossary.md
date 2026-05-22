# Glossary

Canonical definitions for domain-specific terms used across the spec, code, and documentation.

| Term | Definition |
|------|-----------|
| **Zipline** | The upstream open-source file-hosting and URL-shortening service ([github.com/diced/zipline](https://github.com/diced/zipline)) that this app is a client for. |
| **Zipline server** | The user's self-hosted Zipline instance. The app stores a single server URL at a time in `SharedPreferences` under the key `zipline_url`. |
| **Session cookie** | The `zipline_session` cookie that Zipline issues on successful login. Stored encrypted via `flutter_secure_storage` under the key `session_cookie`. |
| **OAuth / OIDC** | The third-party authentication flow that the Zipline server delegates to (Authentik, Discord, Keycloak, etc). The app initiates the flow but never sees the user's credentials directly. |
| **PKCE** | Proof Key for Code Exchange, an OAuth 2.0 extension that binds the authorization-code redemption to the original request, defeating intercepted-code replay attacks. |
| **Cloudflare Access** | Cloudflare's Zero Trust gateway. The user's Zipline server may sit behind Access; the app sends `CF-Access-Client-Id` + `CF-Access-Client-Secret` headers when configured. |
| **Service token** | A non-human credential pair (Client ID + Client Secret) issued by Cloudflare Access that lets the app bypass Access's browser-based auth. |
| **Cloudflare Worker** | The serverless function deployed under `cloudflare-oauth-redirect/` that bridges OAuth provider HTTPS callbacks to the app's `zipline://` deep link. |
| **OAuth Worker** | Shorthand for the Cloudflare Worker; the two terms refer to the same artifact. |
| **Deep link** | An Android URI with a custom scheme (`zipline://`) that the app's `<intent-filter>` claims. Used by the OAuth Worker to hand the session cookie back to the app. |
| **Intent URL fallback** | An `intent://...#Intent;package=...;scheme=zipline;end` form the Worker uses as a secondary redirect when the `zipline://` direct scheme fails on Android 8+. |
| **Intent filter** | An Android-manifest declaration that tells the OS which URIs or actions an activity claims. The app declares filters for `ACTION_SEND`, `ACTION_SEND_MULTIPLE`, `text/plain`, and `zipline://`. |
| **MethodChannel** | The Flutter ↔ Kotlin bridge over which `getSharedFiles` / `getSharedText` / `copyContentUriFile` flow. Channel name: `com.example.zipline_native_app/intent`. |
| **FlutterSecureStorage** | The Flutter wrapper around platform keystores. The app configures it with `EncryptedSharedPreferences` backing on Android. |
| **EncryptedSharedPreferences** | The AndroidX-provided encrypted key-value store backing `FlutterSecureStorage` on Android. |
| **AppState** | The global `ChangeNotifier` (in `lib/providers/app_state.dart`) that holds user/auth/upload state and notifies the widget tree. |
| **ThemeProvider** | The `ChangeNotifier` (in `lib/providers/theme_provider.dart`) that holds the current `ThemeMode` and persists it to `SharedPreferences`. |
| **Dio** | The third-party HTTP client used for uploads. Provides progress callbacks and `CancelToken` support that the standard library `http` package lacks. |
| **Upload task** | A queued upload represented as `UploadTask` (in `upload_queue_service.dart`) with id, file, status, retry count, and optional `CancelToken`. |
| **Activity log** | The local cache of recent uploads stored in `SharedPreferences` under `recent_activities` (max 50 entries). |
