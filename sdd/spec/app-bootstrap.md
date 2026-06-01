# App Bootstrap

This domain covers startup, service registration, splash routing, and app-shell overlays.

### REQ-BOOT-001: Register app services before UI startup

**Intent:** The app prepares its shared services before rendering user-facing screens so later surfaces can request authentication, upload, activity, diagnostics, and connectivity behavior from one known access point.

**Applies To:** Contributor

**Acceptance Criteria:**

1. Startup registers the service locator before launching the app shell. <!-- @impl: lib/main.dart::setupServiceLocator -->
2. Startup initializes the sharing service before rendering the app shell. <!-- @impl: lib/main.dart::initialize -->
3. The service locator exposes typed accessors for authentication, upload, queue, diagnostics, activity, sharing, local unlock, intent, browser sign-in, and connectivity services. <!-- @impl: lib/core/service_locator.dart::ServiceLocatorExtension -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** None.

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BOOT-002: Route users after a local access check

**Intent:** Startup decides whether the user can enter the main surface or must return to sign-in, using stored session state and optional local unlock state.

**Applies To:** User

**Acceptance Criteria:**

1. The splash screen checks whether a session exists before choosing the next screen. <!-- @impl: lib/main.dart::_checkAuthStatus -->
2. If local unlock is enabled, the splash screen prompts for local verification before entering the main surface. <!-- @impl: lib/main.dart::authenticate -->
3. Failed local verification routes the user to the sign-in surface. <!-- @impl: lib/main.dart::SimpleLoginScreen -->
4. Missing session state routes the user to the sign-in surface. <!-- @impl: lib/main.dart::isAuthenticated -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** [REQ-SESS-003](server-session.md#req-sess-003-provide-request-credentials-for-server-actions), [REQ-BIO-002](biometric-gate.md#req-bio-002-gate-app-entry-with-local-verification)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BOOT-003: Render global shell overlays

**Intent:** The app shell keeps cross-cutting upload and connectivity feedback visible regardless of which main screen is active.

**Applies To:** User

**Acceptance Criteria:**

1. The app shell wraps screen content in the upload queue overlay. <!-- @impl: lib/main.dart::UploadQueueOverlay -->
2. The app shell renders a floating queue control above normal screen content. <!-- @impl: lib/main.dart::UploadQueueFloatingButton -->
3. The app shell reacts to connectivity state and renders an offline banner when the connection service reports no network. <!-- @impl: lib/main.dart::ConnectivityService -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-QUEUE-003](upload-queue.md#req-queue-003-present-queue-state-globally), [REQ-CONN-001](connectivity.md#req-conn-001-track-network-availability)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
