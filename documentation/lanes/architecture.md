<!-- doc-discipline: one-line table cells (≤50 words), no implementation prose, no API endpoint contracts (those go in api-reference.md). -->

# Architecture

System overview, component map, and data flow.

**Audience:** Developers

---

## Contents

- [Overview](#overview)
- [Components](#components)
- [Source Modules](#source-modules)
- [Request Lifecycle](#request-lifecycle)
- [Data Flow](#data-flow)
- [Related Documentation](#related-documentation)
- [Pi runtime compatibility](#pi-runtime-compatibility)

## Overview

Zipline Native is a Flutter mobile app with an Android host layer and a small Cloudflare Worker companion. The app shell registers services, decides whether the user enters the home screen or sign-in screen, accepts platform share payloads, uploads files or shortens links against the user's configured server, stores recent activity locally, and keeps diagnostics local unless the user exports them.

## Components

| Component | Role |
|---|---|
| App shell | Starts service registration, providers, splash routing, connectivity banner, and upload overlay. <!-- @impl: lib/main.dart::ZiplineNativeApp --> |
| Service locator | Registers singleton and factory services used across screens. <!-- @impl: lib/core/service_locator.dart::setupServiceLocator --> |
| Session service | Stores server settings, sessions, headers, profile lookup, and logout behavior. <!-- @impl: lib/services/auth_service.dart::AuthService --> |
| Browser sign-in service | Opens the browser, waits for callbacks, validates state, and stores the returned session. <!-- @impl: lib/services/oauth_service.dart::OAuthService --> |
| Android host bridge | Receives share intents and copies content URIs into app storage. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::MainActivity --> |
| Upload service | Uploads files, shortens links, fetches remote lists, and performs remote item actions. <!-- @impl: lib/services/file_upload_service.dart::FileUploadService --> |
| Upload queue service | Tracks queued upload tasks and broadcasts queue state. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService --> |
| Activity service | Persists recent local upload and link activity. <!-- @impl: lib/services/activity_service.dart::ActivityService --> |
| Diagnostics service | Stores opt-in local logs and exports them as JSON. <!-- @impl: lib/services/debug_service.dart::DebugService --> |
| Redirect worker | Exchanges browser callback parameters and returns an app-opening HTML page. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp --> |

## Source Modules

Exhaustive listing of load-bearing source files. The `Implements` column lists the REQs each file participates in. Source-anchor comments carry the symbol reference used by doc source-anchor verification.

| Path | Responsibility | Implements |
|---|---|---|
| `lib/main.dart` | App entrypoint, providers, splash routing, connectivity banner, upload overlay. <!-- @impl: lib/main.dart::main --> | [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-register-app-services-before-ui-startup), [REQ-BOOT-002](../../sdd/spec/app-bootstrap.md#req-boot-002-route-users-after-a-local-access-check), [REQ-CONN-002](../../sdd/spec/connectivity.md#req-conn-002-surface-offline-state-in-the-app-shell) |
| `lib/core/build_config.dart` | Build-time browser sign-in bridge override. <!-- @impl: lib/core/build_config.dart::BuildConfig --> | [REQ-BRIDGE-001](../../sdd/spec/browser-sign-in.md#req-bridge-001-start-external-browser-sign-in-from-the-app) |
| `lib/core/constants.dart` | Shared visual constants and theme data. <!-- @impl: lib/core/constants.dart::AppConstants --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-persist-appearance-choice) |
| `lib/core/service_locator.dart` | Service registration and typed locator accessors. <!-- @impl: lib/core/service_locator.dart::ServiceLocatorExtension --> | [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-register-app-services-before-ui-startup) |
| `lib/providers/app_state.dart` | Shared user, queue, loading, and error state. <!-- @impl: lib/providers/app_state.dart::AppState --> | [REQ-THEME-002](../../sdd/spec/theme-and-state.md#req-theme-002-maintain-shared-app-state) |
| `lib/providers/theme_provider.dart` | Theme mode loading, saving, and toggling. <!-- @impl: lib/providers/theme_provider.dart::ThemeProvider --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-persist-appearance-choice) |
| `lib/screens/simple_login_screen.dart` | Current sign-in surface, settings entry, direct sign-in, browser sign-in, local unlock prompt. <!-- @impl: lib/screens/simple_login_screen.dart::SimpleLoginScreen --> | [REQ-SESS-002](../../sdd/spec/server-session.md#req-sess-002-authenticate-with-direct-credentials), [REQ-BRIDGE-001](../../sdd/spec/browser-sign-in.md#req-bridge-001-start-external-browser-sign-in-from-the-app), [REQ-SET-001](../../sdd/spec/settings.md#req-set-001-save-server-and-access-settings) |
| `lib/screens/home_screen.dart` | File picker, shared payload processing, uploads, link shortening, recent activity, share handoff, remote item actions. <!-- @impl: lib/screens/home_screen.dart::HomeScreen --> | [REQ-SHARE-004](../../sdd/spec/share-intake.md#req-share-004-process-shared-payloads-on-the-home-surface), [REQ-FILE-001](../../sdd/spec/file-upload.md#req-file-001-let-users-choose-files-manually), [REQ-LINK-001](../../sdd/spec/link-shortening.md#req-link-001-create-short-links-from-user-input), [REQ-REMOTE-001](../../sdd/spec/remote-item-actions.md#req-remote-001-share-recent-items-again) |
| `lib/screens/settings_screen.dart` | Server settings, access credentials, diagnostics toggle, theme toggle, local unlock toggle, logout. <!-- @impl: lib/screens/settings_screen.dart::SettingsScreen --> | [REQ-SET-001](../../sdd/spec/settings.md#req-set-001-save-server-and-access-settings), [REQ-SET-003](../../sdd/spec/settings.md#req-set-003-manage-diagnostics-appearance-local-unlock-and-logout) |
| `lib/screens/debug_screen.dart` | Diagnostic log display, filtering, export, share fallback, clear action. <!-- @impl: lib/screens/debug_screen.dart::DebugScreen --> | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally), [REQ-DIAG-003](../../sdd/spec/diagnostics.md#req-diag-003-export-and-share-diagnostics) |
| `lib/services/auth_service.dart` | Credential storage, session headers, direct sign-in, profile lookup, logout, credential clearing. <!-- @impl: lib/services/auth_service.dart::AuthService --> | [REQ-SESS-001](../../sdd/spec/server-session.md#req-sess-001-save-server-and-credential-settings), [REQ-SESS-003](../../sdd/spec/server-session.md#req-sess-003-provide-request-credentials-for-server-actions) |
| `lib/services/oauth_service.dart` | Browser sign-in flow, callback parsing, state validation, session storage. <!-- @impl: lib/services/oauth_service.dart::OAuthService --> | [REQ-BRIDGE-001](../../sdd/spec/browser-sign-in.md#req-bridge-001-start-external-browser-sign-in-from-the-app), [REQ-BRIDGE-002](../../sdd/spec/browser-sign-in.md#req-bridge-002-complete-sign-in-from-an-app-callback) |
| `lib/services/biometric_service.dart` | Local unlock availability, enable/disable, verification, token retrieval. <!-- @impl: lib/services/biometric_service.dart::BiometricService --> | [REQ-BIO-001](../../sdd/spec/biometric-gate.md#req-bio-001-detect-local-unlock-availability), [REQ-BIO-003](../../sdd/spec/biometric-gate.md#req-bio-003-manage-local-unlock-preference) |
| `lib/services/connectivity_service.dart` | Connectivity subscription and notifier-backed online state. <!-- @impl: lib/services/connectivity_service.dart::ConnectivityService --> | [REQ-CONN-001](../../sdd/spec/connectivity.md#req-conn-001-track-network-availability) |
| `lib/services/file_upload_service.dart` | File upload, link shortening, remote history fetch, delete, and protection operations. <!-- @impl: lib/services/file_upload_service.dart::FileUploadService --> | [REQ-FILE-002](../../sdd/spec/file-upload.md#req-file-002-upload-selected-files-with-progress), [REQ-LINK-001](../../sdd/spec/link-shortening.md#req-link-001-create-short-links-from-user-input), [REQ-REMOTE-004](../../sdd/spec/remote-item-actions.md#req-remote-004-fetch-remote-history-lists) |
| `lib/services/intent_service.dart` | Flutter-side method-channel access for shared files and text. <!-- @impl: lib/services/intent_service.dart::IntentService --> | [REQ-SHARE-002](../../sdd/spec/share-intake.md#req-share-002-expose-pending-shared-content-to-flutter), [REQ-SHARE-003](../../sdd/spec/share-intake.md#req-share-003-copy-shared-content-into-app-storage) |
| `lib/services/sharing_service.dart` | Shared-file upload callback bridge. <!-- @impl: lib/services/sharing_service.dart::SharingService --> | [REQ-SHARE-004](../../sdd/spec/share-intake.md#req-share-004-process-shared-payloads-on-the-home-surface) |
| `lib/services/upload_queue_service.dart` | Upload task queue, processing loop, controls, retry, queue stream. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService --> | [REQ-QUEUE-001](../../sdd/spec/upload-queue.md#req-queue-001-create-upload-tasks-for-queued-files), [REQ-QUEUE-003](../../sdd/spec/upload-queue.md#req-queue-003-retry-and-finish-upload-tasks) |
| `lib/services/activity_service.dart` | Recent activity persistence and clearing. <!-- @impl: lib/services/activity_service.dart::ActivityService --> | [REQ-ACT-001](../../sdd/spec/activity-log.md#req-act-001-persist-recent-activity), [REQ-ACT-002](../../sdd/spec/activity-log.md#req-act-002-load-and-clear-recent-activity) |
| `lib/services/debug_service.dart` | Opt-in diagnostic log storage, filters, export, clear. <!-- @impl: lib/services/debug_service.dart::DebugService --> | [REQ-DIAG-001](../../sdd/spec/diagnostics.md#req-diag-001-keep-diagnostic-logging-opt-in), [REQ-DIAG-003](../../sdd/spec/diagnostics.md#req-diag-003-export-and-share-diagnostics) |
| `lib/widgets/upload_queue_overlay.dart` | Global upload queue overlay and floating button. <!-- @impl: lib/widgets/upload_queue_overlay.dart::UploadQueueOverlay --> | [REQ-QUEUE-004](../../sdd/spec/upload-queue.md#req-queue-004-present-queue-state-globally) |
| `lib/widgets/upload_queue_widget.dart` | Queue card, task rows, details modal, controls. <!-- @impl: lib/widgets/upload_queue_widget.dart::UploadQueueWidget --> | [REQ-QUEUE-004](../../sdd/spec/upload-queue.md#req-queue-004-present-queue-state-globally) |
| `lib/widgets/common/minimal_text_field.dart` | Minimal glass-style text field used by login, settings, and home forms. <!-- @impl: lib/widgets/common/minimal_text_field.dart::MinimalTextField --> | [REQ-SET-001](../../sdd/spec/settings.md#req-set-001-save-server-and-access-settings) |
| `lib/widgets/common/app_text_field.dart` | Reusable app text field with validation and optional obscure behavior. <!-- @impl: lib/widgets/common/app_text_field.dart::AppTextField --> | [REQ-SET-001](../../sdd/spec/settings.md#req-set-001-save-server-and-access-settings) |
| `lib/widgets/common/app_button.dart` | Reusable app button with loading and disabled states. <!-- @impl: lib/widgets/common/app_button.dart::AppButton --> | [REQ-FILE-001](../../sdd/spec/file-upload.md#req-file-001-let-users-choose-files-manually) |
| `lib/widgets/common/glassmorphic_card.dart` | Shared translucent card container. <!-- @impl: lib/widgets/common/glassmorphic_card.dart::GlassmorphicCard --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-persist-appearance-choice) |
| `lib/widgets/skeleton_loader.dart` | Skeleton loading visuals for waiting states. <!-- @impl: lib/widgets/skeleton_loader.dart::SkeletonLoader --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-persist-appearance-choice) |
| `lib/utils/responsive_layout.dart` | Responsive layout helpers for width-dependent composition. <!-- @impl: lib/utils/responsive_layout.dart::ResponsiveLayout --> | [REQ-THEME-001](../../sdd/spec/theme-and-state.md#req-theme-001-persist-appearance-choice) |
| `android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt` | Android host share-intent and content-URI bridge. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::MainActivity --> | [REQ-SHARE-001](../../sdd/spec/share-intake.md#req-share-001-capture-platform-share-intents), [REQ-SHARE-003](../../sdd/spec/share-intake.md#req-share-003-copy-shared-content-into-app-storage) |
| `cloudflare-oauth-redirect/src/worker.js` | Browser callback exchange and app-opening response generation. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp --> | [REQ-BRIDGE-003](../../sdd/spec/browser-sign-in.md#req-bridge-003-return-sessions-through-the-bridge-page), [REQ-BRIDGE-004](../../sdd/spec/browser-sign-in.md#req-bridge-004-avoid-raw-session-exposure-in-bridge-markup) |

`lib/screens/login_screen.dart` is intentionally absent from the source module map because it is an open triage item, not accepted current architecture.

## Request Lifecycle

```text
Share-sheet file flow:
1. Host receives a share intent and stores pending file references.
2. Flutter intent service reads and clears pending file references.
3. Content URI references are copied into app storage when needed.
4. Home screen uploads files and saves successful results to activity.
5. Successful single-result links are copied and opened in the share surface.
```

```text
Browser sign-in flow:
1. Sign-in screen starts external browser sign-in through the sign-in service.
2. Browser returns to the bridge worker.
3. Worker exchanges callback parameters with the configured server.
4. Worker returns an app-opening page carrying success or error.
5. App callback parser stores the session or reports failure.
```

```text
Queue flow:
1. A file is added as an upload task.
2. Queue processing starts tasks while capacity exists.
3. Task progress broadcasts to queue listeners.
4. Success moves a task into completed history; retryable failure requeues it.
5. UI controls can pause, resume, cancel, or retry tasks.
```

## Data Flow

Server address and username flow through SharedPreferences, while password, sessions, and access secrets flow through Flutter Secure Storage. Shared content flows from Android intent extras into `MainActivity`, then through `IntentService`, then into upload or link-shortening services. Upload and link results flow into `ActivityService` for local persistence and into the clipboard/share surface for immediate user handoff.

---

## Related Documentation

- [Configuration](configuration.md) — Env vars and secrets
- [API Reference](api-reference.md) — Endpoint contracts
- [Decisions](../decisions/README.md) — Architectural decisions and rationale

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
