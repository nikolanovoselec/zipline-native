# Browser Sign-In Bridge

This domain covers external browser sign-in, callback handling, bridge-page generation, and worker-assisted session return.

### REQ-BRIDGE-001: Start external browser sign-in from the app

**Intent:** A user can choose the external browser sign-in path when direct credentials are not the desired authentication method.

**Applies To:** User

**Acceptance Criteria:**

1. The sign-in surface refuses external sign-in until a server address has been configured. <!-- @impl: lib/screens/simple_login_screen.dart::_loginWithOIDC -->
2. The sign-in service asks the configured server for a browser sign-in location. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
3. The sign-in service chooses either a build-time bridge address or a server-derived bridge address before launching the browser. <!-- @impl: lib/services/oauth_service.dart::BuildConfig -->
4. The sign-in service launches the browser through the platform launcher. <!-- @impl: lib/services/oauth_service.dart::launchUrl -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest), [CON-PLATFORM-001](constraints.md#con-platform-001-keep-bridge-identifiers-synchronized)

**Priority:** P0

**Dependencies:** [REQ-SET-001](settings.md#req-set-001-save-server-and-access-settings)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BRIDGE-002: Complete sign-in from an app callback

**Intent:** When the external browser returns to the app, the callback is parsed and accepted only when it represents the expected sign-in attempt.

**Applies To:** User

**Acceptance Criteria:**

1. The service listens for a fresh callback while the current browser sign-in attempt is active. <!-- @impl: lib/services/oauth_service.dart::uriLinkStream -->
2. Callback parsing accepts a direct success response with a session value. <!-- @impl: lib/services/oauth_service.dart::success -->
3. Callback parsing rejects an error response and clears stored transient state. <!-- @impl: lib/services/oauth_service.dart::clearSession -->
4. Legacy callback parsing validates the returned state before accepting an authorization code. <!-- @impl: lib/services/oauth_service.dart::returnedState -->
5. Cold-start callback checking parses success, failure, and legacy callback shapes. <!-- @impl: lib/services/oauth_service.dart::checkInitialOAuthCallback -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** [REQ-BRIDGE-001](#req-bridge-001-start-external-browser-sign-in-from-the-app)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BRIDGE-003: Return sessions through the bridge page

**Intent:** The deployed bridge receives the browser return, exchanges it with the configured server, and sends the result back to the app.

**Applies To:** Operator

**Acceptance Criteria:**

1. The bridge reads the callback parameters from the incoming request. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::searchParams -->
2. The bridge exchanges the callback parameters with the configured server. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::exchangeResponse -->
3. The bridge extracts the session value from the exchange response when present. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::sessionMatch -->
4. The bridge returns an app-opening response on success and an error response when the session is missing. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->

**Constraints:** [CON-SEC-002](constraints.md#con-sec-002-do-not-expose-raw-sessions-in-generated-pages), [CON-PLATFORM-001](constraints.md#con-platform-001-keep-bridge-identifiers-synchronized)

**Priority:** P0

**Dependencies:** [REQ-BRIDGE-002](#req-bridge-002-complete-sign-in-from-an-app-callback)

**Verification:** Automated test

**Status:** Implemented

---

### REQ-BRIDGE-004: Avoid raw session exposure in bridge markup

**Intent:** The generated bridge page must not render the raw session value directly into markup, reducing accidental disclosure while still opening the app with the sign-in result.

**Applies To:** Operator

**Acceptance Criteria:**

1. The bridge page encodes the session before embedding it in generated markup. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::encodedSession -->
2. The bridge test asserts that the raw session value is absent from the generated markup. <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::raw -->
3. The bridge test asserts that the app callback remains embedded in the generated markup. <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::deep -->

**Constraints:** [CON-SEC-002](constraints.md#con-sec-002-do-not-expose-raw-sessions-in-generated-pages)

**Priority:** P0

**Dependencies:** [REQ-BRIDGE-003](#req-bridge-003-return-sessions-through-the-bridge-page)

**Verification:** Automated test

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
