<!-- doc-discipline: never delete entries; one ADR per architectural decision; each ADR Context block carries an inline @impl source-anchor -->

# Architecture Decision Records

Decisions made during implementation, with rationale.

**Audience:** Developers

Each ADR documents a non-obvious design choice and the trade-offs considered. The decision log is load-bearing: a future contributor about to revert a change should find the prior reasoning here.

## What is NOT an ADR

ADRs document choices between **real alternatives** where the chosen path has consequences a future reader needs to understand to avoid undoing it.

| Shape | Belongs in |
|---|---|
| Static-analyzer false positive accepted with context | Inline source-code comment + one-line note in `documentation/lanes/troubleshooting.md` |
| Naming/spelling preserved for backward compatibility | One-line note in `documentation/lanes/configuration.md` |
| Risk acceptance with no alternative considered | Inline comment OR `documentation/lanes/security.md` "trust model" |
| Implementation note framed as a decision | Delete or move to `pending.md` |

---

## Decision Index

| ID | Decision | Category | Date |
|----|----------|----------|------|
| AD1 | Flutter (Dart) for the mobile app | Framework | 2026-05-22 |
| AD2 | `get_it` + `provider` for DI and state | Architecture | 2026-05-22 |
| AD3 | `FlutterSecureStorage` + `EncryptedSharedPreferences` for all secrets | Security | 2026-05-22 |
| AD4 | Cloudflare Worker bridge for OAuth | Architecture | 2026-05-22 |
| AD5 | Server-side OAuth code exchange in the Worker (not client-side) | Security | 2026-05-22 |
| AD6 | `intent://` URL fallback with explicit package name | UX / Compatibility | 2026-05-22 |
| AD7 | `dio` for uploads, `http` for non-upload requests | Architecture | 2026-05-22 |
| AD8 | Exponential backoff (2s/4s/8s, max 3 retries) on upload failure | Reliability | 2026-05-22 |

---

### AD1: Flutter (Dart) for the mobile app

**Status:** Accepted (2026-05-22)

**Decision:** The app is built in Flutter (Dart), shipping for Android first with the iOS option preserved for a future maintainer.

**Context:** The project needs a native-feeling Android share-sheet handler with secure storage and Material UI. <!-- @impl: pubspec.yaml::name: zipline_native_app -->

**Alternatives considered:** Native Android (Kotlin + Jetpack Compose), React Native, KMP + Compose Multiplatform.

**Rationale:** Single-codebase pragma for a one-developer project; Material is first-class in Flutter; Dart's type system was preferred over JS for this codebase.

**Consequences:** Every plugin needed (secure storage, local auth, deep links, connectivity, dio) is a separate pub.dev package and a separate Android-native bridge to keep an eye on. iOS support requires non-trivial work despite the cross-platform framework.

**Related requirements:** [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-wire-dependency-injection-on-app-start)

---

### AD2: `get_it` + `provider` for DI and state

**Status:** Accepted (2026-05-22)

**Decision:** Services are registered in `get_it` (singleton / lazy singleton / factory); UI-bound state uses `provider` (`ChangeNotifierProvider`).

**Context:** The app has ~10 services with mixed lifecycles (eager DebugService, lazy AuthService, per-call FileUploadService) plus global UI state (auth, uploads, theme) shared across screens. <!-- @impl: lib/core/service_locator.dart::setupServiceLocator -->

**Alternatives considered:** Riverpod (single mechanism for both), BLoC, manual constructor injection.

**Rationale:** `get_it` makes service lifecycle explicit and decouples consumers from constructors; `provider` is the official Flutter team recommendation and pairs naturally with `ChangeNotifier`. Riverpod was rejected as overkill for the current scope.

**Consequences:** Two mechanisms instead of one; new contributors need to learn when to use which (the rule: services in `get_it`, UI-bound state in `provider`).

**Related requirements:** [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-wire-dependency-injection-on-app-start), [REQ-STATE-001](../../sdd/spec/theme-and-state.md#req-state-001-global-appstate)

---

### AD3: `FlutterSecureStorage` + `EncryptedSharedPreferences` for all secrets

**Status:** Accepted (2026-05-22)

**Decision:** Every secret (session cookies, passwords, OAuth tokens, Cloudflare Access credentials, biometric token) is stored exclusively in `FlutterSecureStorage` configured with `AndroidOptions(encryptedSharedPreferences: true)`. Plain `SharedPreferences` is reserved for non-sensitive preferences.

**Context:** Earlier app versions stored some sensitive values in plain `SharedPreferences`. <!-- @impl: lib/services/auth_service.dart::_secureStorage -->

**Alternatives considered:** Plain `SharedPreferences` (rejected — not encrypted at rest); custom Keystore integration (rejected — `FlutterSecureStorage` already wraps it).

**Rationale:** Aligned with Android best practice; the migration path keeps users on existing installs from breaking.

**Consequences:** Every read of a sensitive key goes through `_migrateSensitiveDataIfNeeded` once per process, which is an extra await. The legacy migration code carries a long-term debt (see [TRIAGE-006](../../sdd/spec/.init-triage.md#triage-006-legacy-sensitive-data-migration)).

**Related requirements:** [REQ-AUTH-001](../../sdd/spec/authentication.md#req-auth-001-usernamepassword-login-captures-and-stores-session-cookie), [REQ-AUTH-005](../../sdd/spec/authentication.md#req-auth-005-legacy-sharedpreferences--secure-storage-migration)

---

### AD4: Cloudflare Worker bridge for OAuth

**Status:** Accepted (2026-05-22)

**Decision:** OAuth callbacks land on a dedicated Cloudflare Worker (`/app/oauth-redirect`) which then redirects the device to the app's `zipline://` deep link.

**Context:** OAuth providers (Authentik, Discord, Keycloak, etc.) require an HTTPS `redirect_uri`. Mobile apps with custom schemes (`zipline://`) cannot register their schemes directly with most providers. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->

**Alternatives considered:** Universal Links / App Links (rejected — they require domain ownership + Digital Asset Links wiring per Zipline server); in-app webview (rejected — providers increasingly block third-party browsers); embedded HTTP listener (rejected — Android does not love loopback redirects).

**Rationale:** A Worker is cheap, fast, and stateless; the same Worker can serve any number of Zipline instances by reading `ZIPLINE_URL` from env. The operator runs one Worker, not one per user.

**Consequences:** The Worker is a deployed artifact users must operate; the README has a Worker-deployment section. The Worker holds the only `ZIPLINE_URL` configuration that must match the app's choice exactly.

**Related requirements:** [REQ-OAUTH-001](../../sdd/spec/oauth.md#req-oauth-001-initiate-oauth-flow-with-worker-redirect-uri), [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange)

---

### AD5: Server-side OAuth code exchange in the Worker

**Status:** Accepted (2026-05-22)

**Decision:** The Cloudflare Worker exchanges the OAuth authorization code with Zipline server-side. The session cookie is base64-encoded and embedded in the deep link payload. The app never sees the raw code; it only receives the encoded session cookie.

**Context:** An earlier version of the Worker passed `code` + `state` back to the app via the deep link and let the app perform the exchange. That meant the OAuth `code` was visible in the device's browser history and in the deep-link callback URI. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->

**Alternatives considered:** Client-side exchange (rejected — see above); proof-key-only flow with no code on the device (rejected — provider does not support it).

**Rationale:** Eliminates a class of leakage where the OAuth code lives in browser history. Aligns with the spec's "session cookies are never in cleartext" invariant tested by `worker.test.mjs`.

**Consequences:** The Worker is more complex; a future change to Zipline's `/api/auth/oauth/callback` shape breaks the Worker but not the app, requiring a Worker deploy out of step with the app.

**Related requirements:** [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange)

---

### AD6: `intent://` URL fallback with explicit package name

**Status:** Accepted (2026-05-22)

**Decision:** The Worker's success HTML emits BOTH a `zipline://oauth-callback?cookie=…` redirect AND an Android `intent://oauth-callback#Intent;package=com.example.zipline_native_app;scheme=zipline;end` fallback, plus a manual "Open in app" button.

**Context:** Modern Android (8+) sometimes silently drops custom-scheme redirects when another app claims the same scheme or when the user's browser sanitises non-HTTP URLs. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->

**Alternatives considered:** App Links + Digital Asset Links (rejected — requires per-Zipline-instance domain proof); custom Activity intent without scheme (rejected — not bookmarkable from the Worker).

**Rationale:** The Intent URL with explicit `package` removes ambiguity about which app handles the redirect; the manual button gives the user agency when auto-redirects fail.

**Consequences:** The package name is hardcoded into the Worker source. Any `applicationId` rename must update both `build.gradle` and `worker.js` in lockstep — captured as [TRIAGE-005](../../sdd/spec/.init-triage.md#triage-005-package-name-is-the-flutter-template-default).

**Related requirements:** [REQ-OAUTH-006](../../sdd/spec/oauth.md#req-oauth-006-intent-url-fallback-for-unreliable-schemes)

---

### AD7: `dio` for uploads, `http` for non-upload requests

**Status:** Accepted (2026-05-22)

**Decision:** Multipart file uploads use the `dio` package because it exposes `onSendProgress` callbacks and `CancelToken` for in-flight cancellation. All other REST calls use the standard library `http` package.

**Context:** The upload UI must show per-task progress and let the user cancel mid-upload. The standard `http` package does not surface progress events or cancellation. <!-- @impl: lib/services/file_upload_service.dart::_dio -->

**Alternatives considered:** Use `dio` everywhere (rejected — extra dependency footprint for endpoints that don't need it); roll a custom `HttpClient` wrapper (rejected — reinvents what `dio` already does).

**Rationale:** Two HTTP clients is a small price for the progress + cancel surface; both packages are well-maintained.

**Consequences:** Auth-header construction is shared (`AuthService.getAuthHeaders`) but each client needs its own `Options` / header-map plumbing.

**Related requirements:** [REQ-UPLOAD-003](../../sdd/spec/upload.md#req-upload-003-progress-callbacks-at-upload-task-granularity), [REQ-QUEUE-003](../../sdd/spec/upload-queue.md#req-queue-003-cancellation-via-canceltoken)

---

### AD8: Exponential backoff (2s/4s/8s, max 3 retries) on upload failure

**Status:** Accepted (2026-05-22)

**Decision:** A failed upload retries up to 3 times with delays of 2s, 4s, then 8s. Cancellation interrupts retry; permanent failures (after 3 retries) transition the task to `failed` and stop consuming a queue slot.

**Context:** Mobile networks routinely drop in-flight requests (Wi-Fi handoff, captive portals, brief 4G→5G transitions). Without retry the user sees confusing failures for transient causes. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->

**Alternatives considered:** No retry (rejected — too brittle); unbounded retry (rejected — permanently broken uploads would block the queue); jittered backoff (rejected — added complexity without measurable benefit at N=3).

**Rationale:** 3 retries with doubling delay covers the common transient cases; the total worst-case wait (~14s) is acceptable; cancellation always wins.

**Consequences:** A truly broken server returns errors for ~14s of wall-clock before the user sees a final failure. Watchful operators read the debug log to distinguish "network" from "server".

**Related requirements:** [REQ-QUEUE-002](../../sdd/spec/upload-queue.md#req-queue-002-exponential-backoff-retry)

---
