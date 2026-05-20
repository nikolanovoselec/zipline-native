<!-- doc-discipline: 100 lines per ADR; never delete entries (replace with Status: Reclassified or Status: Merged into AD-X stubs); one ADR per architectural decision -->

# Architecture Decision Records

Decisions made during implementation, with rationale.

**Audience:** Developers

Each ADR documents a non-obvious design choice and the trade-offs considered.

## What is NOT an ADR

ADRs document choices between **real alternatives** where the chosen path has consequences a future reader needs to understand. Four shapes regularly drift INTO the ADR set but belong elsewhere:

| Shape | Belongs in |
|---|---|
| Static-analyzer false positive accepted with context | Inline source-code comment |
| Naming/spelling preserved for backward compatibility | One-line note in `configuration.md` |
| Risk acceptance with no alternative considered | Inline comment OR `security.md` "trust model" section |
| Implementation note framed as a decision | Delete or move to triage |

---

## Inline Markers

This project's ADR marker convention is **`ad`** (set in `sdd/config.yml` as `adr_marker_style`). Markers render as `// AD-N:` at the canonical implementation site.

Each ADR below SHOULD carry an inline source-code marker. Marker proposals for this initial scaffold are in [`.adr-marker-proposals.md`](.adr-marker-proposals.md) — apply them in a follow-up commit and delete each row as you do.

---

## Decision Index

| ID | Decision | Category | Date |
|----|----------|----------|------|
| AD1 | Cloudflare Worker brokers OAuth instead of in-app OIDC library | Architecture | 2026-05-20 |
| AD2 | `FlutterSecureStorage` for secrets, plain `SharedPreferences` for non-secrets | Security | 2026-05-20 |
| AD3 | `get_it` for DI instead of `Provider`-only or InheritedWidget | Architecture | 2026-05-20 |
| AD4 | Persisted upload queue via `shared_preferences` keyed by UUID | Architecture | 2026-05-20 |
| AD5 | Android-only target; iOS/desktop best-effort | Scope | 2026-05-20 |

---

### AD1: Cloudflare Worker brokers OAuth instead of in-app OIDC library

**Status:** Accepted (2026-05-20)

**Decision:** OAuth/OIDC callback handling lives in a Cloudflare Worker, not in the app via a Dart OIDC client library.

**Context:** Zipline's OIDC flow sets a session cookie on the redirect response. Mobile-side OIDC libraries typically expect a JSON-token-bearing response, not a cookie-bearing 302. A Worker can run `redirect: manual`, capture the cookie, and forward it via deep-link to the app — turning a cookie-shaped flow into a token-shaped flow.

**Alternatives considered:**
- Dart OIDC client library (e.g., `openid_client`): could not capture `Set-Cookie` from a manual-redirect response cleanly.
- Custom Dart implementation: doable but recreates Worker complexity inside the app; harder to test.

**Rationale:** The Worker is a 250-line stateless function; cheap to deploy, easy to test, decouples cookie-handling from the app entirely.

**Consequences:**
- App and Worker deployments are coupled (URLs must match Zipline OIDC `redirect_uri`).
- Self-hosters must deploy the Worker, not just the app — additional friction for OAuth users.
- Username/password auth remains the no-Worker default.

**Related requirements:** [REQ-AUTH-002](../../sdd/auth.md#req-auth-002-oauthoidc-login-via-worker), [REQ-OAUTH-001](../../sdd/oauth-worker.md#req-oauth-001-callback-exchange)

---

### AD2: `FlutterSecureStorage` for secrets, plain `SharedPreferences` for non-secrets

**Status:** Accepted (2026-05-20)

**Decision:** Hardware-backed encrypted storage for credentials (session cookie, OAuth client ID/secret); plain `SharedPreferences` for non-secret config (Zipline URL, theme).

**Context:** Storing the session cookie in plain `SharedPreferences` would expose it to any app with file-system access on a rooted device or via a backup extraction attack. The hardware Keystore on Android API 23+ provides isolation against these threats.

**Alternatives considered:**
- All-in-one `FlutterSecureStorage`: encrypts non-secrets too. Slower (Keystore RPC); no security benefit for the Zipline URL.
- All-in-one `SharedPreferences`: insecure for the session cookie.

**Rationale:** Split by sensitivity. Encrypted storage's overhead is paid only where it matters.

**Consequences:**
- Two storage backends to think about; mistakes (storing a secret in the wrong one) are a security bug.
- [CON-SEC-001](../../sdd/constraints.md#con-sec-001-hardware-backed-secrets) enforces the split.

**Related requirements:** [REQ-AUTH-004](../../sdd/auth.md#req-auth-004-secure-credential-storage)

---

### AD3: `get_it` for DI instead of `Provider`-only or InheritedWidget

**Status:** Accepted (2026-05-20)

**Decision:** `get_it` as the service locator for non-UI services; `Provider` (`ChangeNotifier`) for UI-reactive state.

**Context:** Services like `AuthService`, `UploadQueueService`, `ConnectivityService` are accessed from many widgets and from non-widget code (intent receivers, background isolates). Threading these through `BuildContext` everywhere is noisy.

**Alternatives considered:**
- `Provider` for everything: requires `BuildContext` to access services, awkward outside the widget tree.
- Riverpod: more capable but heavier; team is small, didn't justify learning curve.

**Rationale:** Service-locator pattern handles non-UI access cleanly; `Provider` handles UI rebuild signalling. Two patterns, each in its lane.

**Consequences:**
- Tests must register mock services via `locator.registerSingleton<T>(...)` before exercising code that pulls from the locator.
- Service-locator pattern is criticised for hidden dependencies; mitigated by registering only at app start.

**Related requirements:** None (architectural-only)

---

### AD4: Persisted upload queue via `shared_preferences` keyed by UUID

**Status:** Accepted (2026-05-20)

**Decision:** Pending uploads persist to `shared_preferences` with one entry per upload, keyed by a stable UUID.

**Context:** Uploads can fail (offline, server error, timeout). Without persistence, an app restart loses the queue and the user must re-select the files. With persistence, the queue resumes on the next launch.

**Alternatives considered:**
- SQLite (via `sqflite`): heavier dependency; the queue is small (<100 entries typically); KV storage suffices.
- In-memory only: loses queue on restart, fails [CON-REL-001](../../sdd/constraints.md#con-rel-001-offline-queue-persistence).
- Single JSON blob in `shared_preferences`: rewrites the entire queue on each update; UUID-per-entry allows incremental updates.

**Rationale:** UUID-per-entry minimises I/O on queue updates and gives each entry a stable identity for retry tracking.

**Consequences:**
- Cleanup on completion: each entry must be explicitly removed to avoid `shared_preferences` bloat over time.
- Schema migrations are painful with KV storage; a future move to SQLite is plausible if the queue grows complex.

**Related requirements:** [REQ-UPLOAD-003](../../sdd/upload.md#req-upload-003-persistent-upload-queue), [CON-REL-001](../../sdd/constraints.md#con-rel-001-offline-queue-persistence)

---

### AD5: Android-only target; iOS/desktop best-effort

**Status:** Accepted (2026-05-20)

**Decision:** The project promises only Android. iOS, Linux, macOS, Windows builds compile but are not tested.

**Context:** Single-developer project. Targeting multiple platforms multiplies test surface and bug volume. The share-sheet intent flow that motivates the app is Android-specific in its share-from-anywhere model; iOS's share extension has a different model that would require platform-specific code.

**Alternatives considered:**
- True cross-platform with platform-specific implementations: more work than the original problem warranted.
- Web target: defeats the purpose ("native mobile share-sheet").

**Rationale:** Scope the contract to what is exercised. Other platforms compile so a contributor can pick up the work; nothing is promised.

**Consequences:**
- README claims "iOS: Should work, but I don't own an iPhone" — flagged in [TRIAGE-004](../../sdd/init-triage.md#triage-004-ios-support-claim-in-readme-vs-actual) for removal or formalisation as CON-PLATFORM-001.
- A PR adding iOS support is welcome but does not block Android releases.

**Related requirements:** None (scope decision)

---
