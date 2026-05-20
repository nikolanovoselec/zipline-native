<!-- doc-discipline: 500 lines soft cap (split to architecture-internals.md beyond that), one-line table cells (≤50 words), no implementation prose, no API endpoint contracts (those go in api-reference.md). -->

# Architecture

System overview, component map, and data flow for the Zipline Native client + OAuth Worker.

**Audience:** Developers

This document describes **what** the system is and **how requests flow through it**. Implementation rationale lives in source comments. Endpoint contracts live in [`api-reference.md`](api-reference.md). Environment and bindings live in [`configuration.md`](configuration.md). Architectural decisions live in [`decisions/README.md`](decisions/README.md). Product intent lives in [`sdd/`](../sdd/).

## Contents

- [1. Overview](#1-overview)
- [2. Components](#2-components)
- [3. Repository Layout](#3-repository-layout)
- [4. Source Module Map](#4-source-module-map)
- [5. Request Lifecycles](#5-request-lifecycles)
- [6. Data Flow](#6-data-flow)
- [7. Cross-cutting Concerns](#7-cross-cutting-concerns)
- [8. Build and Deploy](#8-build-and-deploy)
- [Related Documentation](#related-documentation)

---

## 1. Overview

Zipline Native is a Flutter Android app paired with a Cloudflare Worker. The app provides native share-sheet upload to a Zipline file-sharing instance; the Worker brokers OAuth/OIDC callbacks between Zipline and the app for users who prefer browser-based authentication over username/password.

```
+--------------------+        Android intent       +-----------------+
| Other Android app  | --share-sheet--→            | Zipline Native  |
+--------------------+                             |  (Flutter app)  |
                                                   +--------+--------+
                                                            |
                                                            | HTTPS multipart
                                                            ▼
+--------------------+   302 deep-link    +-----------------+
| OAuth Worker (CF)  | ←--OAuth callback--| Zipline Server  |
+--------------------+ ---exchange code-→ |  (user-hosted)  |
                                          +-----------------+
```

Implements [REQ-AUTH-002](../sdd/auth.md#req-auth-002-oauthoidc-login-via-worker), [REQ-UPLOAD-001](../sdd/upload.md#req-upload-001-file-picker-upload), [REQ-SHARE-001](../sdd/sharing.md#req-share-001-share-sheet-intent-receiver).

## 2. Components

| Component | Role |
|---|---|
| Flutter app | Android client; share-sheet intent receiver, file upload, OAuth initiator, biometric unlock |
| OAuth Worker | Cloudflare Worker; receives OAuth callback from Zipline, redirects to app deep-link with session |
| Zipline Server | External; the file-hosting backend the app uploads to |
| Service locator | `get_it`-based DI container wiring all services in `lib/core/service_locator.dart` |
| Upload queue | Persisted FIFO queue of pending uploads with retry policy |
| Activity log | In-memory rolling event log surfaced via Debug screen |

## 3. Repository Layout

| Path | Contents |
|---|---|
| `lib/` | Flutter app source |
| `lib/core/` | DI container, constants, build-time config |
| `lib/screens/` | Top-level UI screens (login, home, settings, debug) |
| `lib/services/` | Business-logic services (auth, upload, sharing, connectivity, debug) |
| `lib/providers/` | `ChangeNotifier` providers (app state, theme) |
| `lib/widgets/` | Reusable widgets (Upload Files card, banners) |
| `lib/utils/` | Small utilities |
| `cloudflare-oauth-redirect/src/` | OAuth Worker source (worker.js) |
| `cloudflare-oauth-redirect/tests/` | Worker tests |
| `android/` | Android-specific manifest, signing config, Gradle |
| `test/` | Flutter app tests |
| `assets/` | App icons, fonts |

## 4. Source Module Map

Exhaustive listing of every code file in the primary source tree. The `Implements` column lists the REQs each file participates in.

### 4.1 Core

| Path | Role | Implements |
|---|---|---|
| `lib/main.dart` | App entry point; service locator setup, MultiProvider tree, MaterialApp shell | [REQ-AUTH-001](../sdd/auth.md#req-auth-001-usernamepassword-login) |
| `lib/core/build_config.dart` | Build-time constants (Zipline URL default, version) | None |
| `lib/core/constants.dart` | App-wide constants (storage keys, defaults) | None |
| `lib/core/service_locator.dart` | `get_it` DI registration for all services | All |

### 4.2 Providers

| Path | Role | Implements |
|---|---|---|
| `lib/providers/app_state.dart` | Global app state via `ChangeNotifier` | None |
| `lib/providers/theme_provider.dart` | Light/dark theme persistence | None |

### 4.3 Screens

| Path | Role | Implements |
|---|---|---|
| `lib/screens/simple_login_screen.dart` | Username/password login | [REQ-AUTH-001](../sdd/auth.md#req-auth-001-usernamepassword-login) |
| `lib/screens/login_screen.dart` | OAuth login + biometric unlock entry | [REQ-AUTH-002](../sdd/auth.md#req-auth-002-oauthoidc-login-via-worker), [REQ-AUTH-003](../sdd/auth.md#req-auth-003-biometric-unlock) |
| `lib/screens/home_screen.dart` | Upload Files card, file picker entry, queue display | [REQ-UPLOAD-001](../sdd/upload.md#req-upload-001-file-picker-upload), [REQ-UPLOAD-002](../sdd/upload.md#req-upload-002-inline-progress-ui) |
| `lib/screens/settings_screen.dart` | URL shortening toggle, theme toggle, logout, Debug entry | [REQ-AUTH-005](../sdd/auth.md#req-auth-005-logout-flushes-state), [REQ-UPLOAD-005](../sdd/upload.md#req-upload-005-url-shortening) |
| `lib/screens/debug_screen.dart` | Activity log viewer + Copy to clipboard | [REQ-DEBUG-001](../sdd/debug.md#req-debug-001-rolling-activity-log), [REQ-DEBUG-002](../sdd/debug.md#req-debug-002-log-export-to-clipboard) |

### 4.4 Services

| Path | Role | Implements |
|---|---|---|
| `lib/services/auth_service.dart` | Username/password login, session persistence | [REQ-AUTH-001](../sdd/auth.md#req-auth-001-usernamepassword-login), [REQ-AUTH-004](../sdd/auth.md#req-auth-004-secure-credential-storage) |
| `lib/services/oauth_service.dart` | OIDC start URL construction, browser launch, deep-link capture | [REQ-AUTH-002](../sdd/auth.md#req-auth-002-oauthoidc-login-via-worker) |
| `lib/services/biometric_service.dart` | `local_auth` wrapper, availability check, prompt | [REQ-AUTH-003](../sdd/auth.md#req-auth-003-biometric-unlock) |
| `lib/services/file_upload_service.dart` | HTTP multipart upload with per-file progress | [REQ-UPLOAD-001](../sdd/upload.md#req-upload-001-file-picker-upload) |
| `lib/services/upload_queue_service.dart` | Persisted upload queue, retry policy, concurrency limit | [REQ-UPLOAD-003](../sdd/upload.md#req-upload-003-persistent-upload-queue), [REQ-UPLOAD-004](../sdd/upload.md#req-upload-004-auto-retry-on-connectivity-recovery), [REQ-UPLOAD-006](../sdd/upload.md#req-upload-006-concurrent-upload-limit) |
| `lib/services/sharing_service.dart` | `share_plus` initial-media + media-stream handling | [REQ-SHARE-001](../sdd/sharing.md#req-share-001-share-sheet-intent-receiver), [REQ-SHARE-002](../sdd/sharing.md#req-share-002-batch-share) |
| `lib/services/intent_service.dart` | Pending-shares holding-area pre-auth | [REQ-SHARE-003](../sdd/sharing.md#req-share-003-pre-share-authentication-gate) |
| `lib/services/connectivity_service.dart` | `connectivity_plus` stream + ChangeNotifier | [REQ-CONN-001](../sdd/connectivity.md#req-conn-001-network-state-monitor), [REQ-CONN-002](../sdd/connectivity.md#req-conn-002-offline-banner), [REQ-CONN-003](../sdd/connectivity.md#req-conn-003-pre-upload-connectivity-check) |
| `lib/services/activity_service.dart` | Rolling activity log (500-cap, FIFO) | [REQ-DEBUG-001](../sdd/debug.md#req-debug-001-rolling-activity-log) |
| `lib/services/debug_service.dart` | Convenience wrappers around activity log calls | None |

### 4.5 Widgets

| Path | Role | Implements |
|---|---|---|
| `lib/widgets/upload_queue_widget.dart` | Per-upload row rendering | [REQ-UPLOAD-002](../sdd/upload.md#req-upload-002-inline-progress-ui) |
| `lib/widgets/upload_queue_overlay.dart` | Top-level overlay enabling the Upload Files card globally | [REQ-UPLOAD-002](../sdd/upload.md#req-upload-002-inline-progress-ui) |
| `lib/widgets/skeleton_loader.dart` | Loading skeleton placeholder | None |
| `lib/widgets/common/` | Shared sub-widgets | None |

### 4.6 OAuth Worker

| Path | Role | Implements |
|---|---|---|
| `cloudflare-oauth-redirect/src/worker.js` | OAuth callback exchange, deep-link redirect, state validation | [REQ-OAUTH-001](../sdd/oauth-worker.md#req-oauth-001-callback-exchange), [REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation), [REQ-OAUTH-003](../sdd/oauth-worker.md#req-oauth-003-cookie-redaction-in-logs), [REQ-OAUTH-004](../sdd/oauth-worker.md#req-oauth-004-configurable-zipline-url) |

## 5. Request Lifecycles

### 5.1 Share-sheet cold-start upload

A user shares a file from another Android app while Zipline Native is not running. Android launches the app and delivers the intent.

```
Android share-sheet selection
  └─► MainActivity (Android side) launches Flutter
       │
       ▼
SharingService.initialize() in main.dart
  ├─ share_plus.getInitialMedia() returns the shared file(s)
  ├─ check ConnectivityService.isConnected
  │    ├─► true: enqueue via UploadQueueService and start upload immediately
  │    └─► false: enqueue with "offline" state
  │
  ▼
UploadQueueService.enqueue(file)
  ├─ persist to shared_preferences (UUID key)
  ├─ FileUploadService.upload(file) if a slot is free (< 3 concurrent)
  └─ on 401: redirect to login, hold file via IntentService
       │
       ▼
FileUploadService.upload streams progress 0→100%
  ├─ on 200: append result URL to Upload Files card
  └─ on network error: mark as queued (retry)
```

Implements [REQ-SHARE-001](../sdd/sharing.md#req-share-001-share-sheet-intent-receiver), [REQ-UPLOAD-001](../sdd/upload.md#req-upload-001-file-picker-upload), [REQ-CONN-003](../sdd/connectivity.md#req-conn-003-pre-upload-connectivity-check).

### 5.2 OAuth login

A user with an OIDC-enabled Zipline instance taps "Sign in with OAuth".

```
LoginScreen "Sign in with OAuth" tap
  └─► OAuthService.startLogin()
       ├─ construct Zipline OIDC URL with state param
       └─ flutter_web_auth_2.authenticate(url)
            │
            ▼
System browser opens Zipline OIDC page
  ├─ user authenticates against IdP
  └─ Zipline redirects to Worker callback URL with code + state
       │
       ▼
Worker fetch() handler
  ├─ validate state present (else 400)
  ├─ exchange code with Zipline (/api/auth/oauth/oidc)
  ├─ extract session cookie from response
  └─ 302 redirect to zipline://oauth-callback?session=<cookie>
       │
       ▼
app_links delivers deep-link to OAuthService
  ├─ persist session via FlutterSecureStorage
  └─ navigate to HomeScreen
       │
       │   failure transitions:
       └─► state missing at Worker: 400 to browser, user sees error page
       └─► Zipline returns non-2xx during exchange: TRIAGE-002 (currently undefined)
       └─► deep-link arrives with no app process: app cold-starts and resumes via getInitialUri
```

Implements [REQ-AUTH-002](../sdd/auth.md#req-auth-002-oauthoidc-login-via-worker), [REQ-OAUTH-001](../sdd/oauth-worker.md#req-oauth-001-callback-exchange), [REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation).

### 5.3 Connectivity-driven queue resume

The device transitions from offline to online while uploads sit in the queue.

```
connectivity_plus stream emits "connected"
  └─► ConnectivityService notifies listeners
       ├─ Offline banner removed from home screen
       └─ UploadQueueService onConnectivityRestored()
            │
            ▼
UploadQueueService walks pending uploads FIFO
  ├─ for each: check retry count
  │    ├─► < 3: increment, attempt upload
  │    └─► >= 3: mark as manual-retry, halt automatic processing
  │
  ▼
FileUploadService.upload(file)
  ├─ on 200: dequeue, append URL to Upload Files card
  └─ on failure: increment retry count, leave in queue
       │
       │   failure transitions:
       └─► persistent server error: every retry climbs the count; user must manually retry
       └─► auth failure (401) during retry: redirect to login, queue preserved
```

Implements [REQ-UPLOAD-004](../sdd/upload.md#req-upload-004-auto-retry-on-connectivity-recovery), [REQ-CONN-001](../sdd/connectivity.md#req-conn-001-network-state-monitor).

## 6. Data Flow

Persisted state lives in three places: encrypted secure storage (secrets), plain shared preferences (non-secrets and the upload queue), and ephemeral in-memory state (activity log).

| Datum | Lives in | Lifetime |
|---|---|---|
| Session cookie | FlutterSecureStorage | Until logout or replacement |
| OAuth client ID / secret | FlutterSecureStorage | Until logout |
| Zipline instance URL | SharedPreferences | Until manually changed |
| Theme preference | SharedPreferences | Until manually changed |
| Upload queue entries | SharedPreferences (UUID-keyed) | Until upload succeeds or user removes |
| URL-shortening toggle | SharedPreferences | Until manually changed |
| Activity log | In-memory only | Until app process exits or "Clear log" |

## 7. Cross-cutting Concerns

| Concern | Mechanism | Implements |
|---|---|---|
| Authentication | `lib/services/auth_service.dart` + `lib/services/oauth_service.dart` | [REQ-AUTH-001](../sdd/auth.md#req-auth-001-usernamepassword-login) |
| Hardware-backed secret storage | `lib/services/auth_service.dart:23` (FlutterSecureStorage init) | [REQ-AUTH-004](../sdd/auth.md#req-auth-004-secure-credential-storage) |
| CSRF defense (OAuth state) | `cloudflare-oauth-redirect/src/worker.js` state-validation branch | [REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation) |
| Observability | `lib/services/activity_service.dart` rolling log + `lib/services/debug_service.dart` wrappers | [REQ-DEBUG-001](../sdd/debug.md#req-debug-001-rolling-activity-log) |
| Error handling | Per-service try/catch surfacing to activity log; UI displays user-friendly messages | None |
| Retry policy | `lib/services/upload_queue_service.dart` retry-count + manual-retry state | [REQ-UPLOAD-004](../sdd/upload.md#req-upload-004-auto-retry-on-connectivity-recovery) |
| Network resilience | `lib/services/connectivity_service.dart` + queue-on-disconnect | [REQ-CONN-003](../sdd/connectivity.md#req-conn-003-pre-upload-connectivity-check) |
| Persistence | `shared_preferences` (queue, prefs) + `FlutterSecureStorage` (secrets) | [REQ-UPLOAD-003](../sdd/upload.md#req-upload-003-persistent-upload-queue) |

## 8. Build and Deploy

- **Flutter build:** `flutter build apk --release` produces the Android APK; signing keys live in `android/key.properties` (gitignored).
- **Worker deploy:** `wrangler deploy` from `cloudflare-oauth-redirect/`; `wrangler.toml` defines route + ZIPLINE_URL env var.
- **Coupling:** the Worker's deployment URL MUST match the `redirect_uri` registered in the Zipline OIDC client config. Changing the Worker route without updating Zipline breaks OAuth.
- **App-link verification:** the `zipline://` scheme is the app's intent-filter target; the Worker hard-codes this scheme. Renaming requires coordinated change.

---

## Related Documentation

- [Configuration](configuration.md) — Env vars and secrets
- [API Reference](api-reference.md) — Endpoint contracts (Worker + Zipline upload endpoints used)
- [Decisions](decisions/README.md) — Architectural decisions and rationale
- [Security](security.md) — Threat model, auth flow, secret storage
- [Troubleshooting](troubleshooting.md) — Symptom → cause → fix recipes
