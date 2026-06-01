<!-- doc-discipline: never delete entries (replace with Status: Reclassified or Status: Merged into AD-X stubs); one ADR per architectural decision; each ADR Context block carries an inline @impl source-anchor -->

# Architecture Decision Records

Decisions made during implementation, with rationale.

**Audience:** Developers

Each ADR documents a non-obvious design choice and the trade-offs considered. The decision log is load-bearing: a future contributor about to revert a change should find the prior reasoning here.

## What is NOT an ADR

ADRs document choices between real alternatives where the chosen path has consequences a future reader needs to understand to avoid undoing it. Four shapes regularly drift INTO the ADR set but belong elsewhere:

| Shape | Belongs in |
|---|---|
| Static-analyzer false positive accepted with context | Inline source-code comment plus one-line note in troubleshooting if the pattern recurs |
| Naming/spelling preserved for backward compatibility | One-line note in configuration next to the variable |
| Risk acceptance with no alternative considered | Inline source-code comment OR security trust model section |
| Implementation note framed as a decision | Delete or move to `pending.md` |

The single test: did we choose between real alternatives, and would a future reader need to understand the choice to avoid undoing it? If either half is no, it is not an ADR.

When an existing ADR is reclassified to a canonical home, preserve its heading as a reclassified stub so inbound references keep resolving. Never delete entries outright — content is moved, anchors stay.

---

## Decision Index

| ID | Decision | Category | Date |
|----|----------|----------|------|
| AD1 | Flutter app with Android host bridge | Architecture | 2026-06-01 |
| AD2 | Service locator plus Provider state | Architecture | 2026-06-01 |
| AD3 | Secure storage split for sensitive values | Security | 2026-06-01 |
| AD4 | Dedicated worker bridge for browser sign-in | Security / Architecture | 2026-06-01 |
| AD5 | Dio for upload progress and http for lightweight requests | Architecture | 2026-06-01 |
| AD6 | Local opt-in diagnostics instead of remote analytics | Observability | 2026-06-01 |

---

### AD1: Flutter app with Android host bridge

**Status:** Accepted (2026-06-01)

**Decision:** Keep the Flutter UI shell and use the Android host layer only for share-intent and content URI bridging.

**Context:** The app's core screens and services are implemented in Dart, while the host layer captures platform share intents and performs content URI copying. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::MainActivity -->

**Alternatives considered:** Fully native Android UI; Flutter plugins only without Kotlin host code; web-only upload form.

**Rationale:** Flutter keeps most UI and business logic in one codebase, while Kotlin handles platform behaviors that require direct host APIs.

**Consequences:** Changes to share intent handling must keep `MainActivity`, `IntentService`, and Android manifest filters in lockstep.

**Related requirements:** [REQ-SHARE-001](../../sdd/spec/share-intake.md#req-share-001-capture-platform-share-intents), [REQ-SHARE-003](../../sdd/spec/share-intake.md#req-share-003-copy-shared-content-into-app-storage)

---

### AD2: Service locator plus Provider state

**Status:** Accepted (2026-06-01)

**Decision:** Keep long-lived services in GetIt and reactive UI state in Provider-backed notifiers.

**Context:** `setupServiceLocator` registers services and factories, while `MultiProvider` supplies app state, theme state, and connectivity state to the widget tree. <!-- @impl: lib/core/service_locator.dart::setupServiceLocator -->

**Alternatives considered:** Constructor-only dependency injection; Provider-only service construction; global static singletons without a registry.

**Rationale:** The current split keeps service construction centralized while preserving reactive rebuilds for UI state.

**Consequences:** New services should be registered in the locator, while UI state that must trigger rebuilds belongs in a provider.

**Related requirements:** [REQ-BOOT-001](../../sdd/spec/app-bootstrap.md#req-boot-001-register-app-services-before-ui-startup), [REQ-THEME-002](../../sdd/spec/theme-and-state.md#req-theme-002-maintain-shared-app-state)

---

### AD3: Secure storage split for sensitive values

**Status:** Accepted (2026-06-01)

**Decision:** Store sensitive values in secure storage and non-secret preferences in regular local preferences.

**Context:** Authentication code writes passwords, sessions, and access secrets to `FlutterSecureStorage`, while server URL and username remain in `SharedPreferences`. <!-- @impl: lib/services/auth_service.dart::_secureStorage -->

**Alternatives considered:** Store all settings in regular preferences; store all settings in secure storage; keep credentials only in memory.

**Rationale:** The split minimizes exposure for secrets while keeping harmless settings easy to load and preserve.

**Consequences:** Any new credential-like value must be added to secure storage and, if legacy keys exist, to the migration path.

**Related requirements:** [REQ-SESS-001](../../sdd/spec/server-session.md#req-sess-001-save-server-and-credential-settings), [REQ-BIO-003](../../sdd/spec/biometric-gate.md#req-bio-003-manage-local-unlock-preference)

---

### AD4: Dedicated worker bridge for browser sign-in

**Status:** Accepted (2026-06-01)

**Decision:** Use a small worker to receive browser sign-in callbacks and return an app-opening page.

**Context:** The worker exchanges callback parameters with the configured server, extracts a session when present, and generates a callback page for the app. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->

**Alternatives considered:** Direct app scheme as provider callback; embedded web view; server-side custom callback page owned by every operator.

**Rationale:** The worker gives operators a deployable HTTPS callback surface while keeping the mobile app callback scheme private to the app return step.

**Consequences:** Worker route, app callback scheme, package identifier, and build-time redirect configuration must stay synchronized.

**Related requirements:** [REQ-BRIDGE-001](../../sdd/spec/browser-sign-in.md#req-bridge-001-start-external-browser-sign-in-from-the-app), [REQ-BRIDGE-003](../../sdd/spec/browser-sign-in.md#req-bridge-003-return-sessions-through-the-bridge-page)

---

### AD5: Dio for upload progress and http for lightweight requests

**Status:** Accepted (2026-06-01)

**Decision:** Keep Dio for upload and file/link operations that need richer request handling, while retaining the lighter HTTP client for simple authentication and profile requests.

**Context:** File upload uses Dio progress callbacks and multipart helpers; authentication uses the lighter client for direct requests. <!-- @impl: lib/services/file_upload_service.dart::Dio -->

**Alternatives considered:** Use only the lightweight HTTP client; use only Dio for all network calls; wrap both behind a custom transport layer.

**Rationale:** The current split matches the capabilities needed by each path without introducing a new abstraction layer during import.

**Consequences:** Future network changes should not mix duplicate request logic into screens; add service methods instead.

**Related requirements:** [REQ-FILE-002](../../sdd/spec/file-upload.md#req-file-002-upload-selected-files-with-progress), [REQ-SESS-002](../../sdd/spec/server-session.md#req-sess-002-authenticate-with-direct-credentials)

---

### AD6: Local opt-in diagnostics instead of remote analytics

**Status:** Accepted (2026-06-01)

**Decision:** Keep diagnostics local and disabled by default, with explicit user-controlled export when troubleshooting is needed.

**Context:** `DebugService` skips logging unless the saved enabled flag is true, stores logs locally, and supports export to a local JSON file. <!-- @impl: lib/services/debug_service.dart::_debugLogsEnabled -->

**Alternatives considered:** Always-on local logs; remote analytics; console-only logs.

**Rationale:** Local opt-in logs preserve privacy while still giving contributors enough context to debug user-reported failures.

**Consequences:** New diagnostic events must go through `DebugService`, and sensitive values should be redacted before being attached to log data.

**Related requirements:** [REQ-DIAG-001](../../sdd/spec/diagnostics.md#req-diag-001-keep-diagnostic-logging-opt-in), [REQ-DIAG-003](../../sdd/spec/diagnostics.md#req-diag-003-export-and-share-diagnostics)

---

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
