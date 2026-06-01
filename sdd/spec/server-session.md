# Server Session

This domain covers server settings, credential persistence, session creation, request credentials, profile lookup, and logout.

### REQ-SESS-001: Save server and credential settings

**Intent:** The user can save the server address and optional access credentials, while sensitive values are kept out of regular preferences.

**Applies To:** User

**Acceptance Criteria:**

1. Saving credentials stores the server address and username in regular preferences. <!-- @impl: lib/services/auth_service.dart::saveCredentials -->
2. Saving credentials writes password and optional access secret values to secure storage. <!-- @impl: lib/services/auth_service.dart::_secureStorage -->
3. Empty optional access credential fields remove prior stored values. <!-- @impl: lib/services/auth_service.dart::delete -->
4. Existing sensitive values found in regular preferences are migrated into secure storage on first access. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** None.

**Verification:** Automated test

**Status:** Implemented

---

### REQ-SESS-002: Authenticate with direct credentials

**Intent:** A user with direct credentials can sign in to the configured server and receive a reusable session for later actions.

**Applies To:** User

**Acceptance Criteria:**

1. The sign-in form validates required username and password fields before attempting authentication. <!-- @impl: lib/screens/simple_login_screen.dart::_login -->
2. Direct authentication sends the entered credentials and optional second factor to the configured server. <!-- @impl: lib/services/auth_service.dart::authenticateWithZipline -->
3. A successful response is accepted only when a session value can be extracted. <!-- @impl: lib/services/auth_service.dart::_extractSessionCookie -->
4. Successful authentication saves the credentials and session for future app launches. <!-- @impl: lib/services/auth_service.dart::saveCredentials -->
5. Authentication failures keep the user on the sign-in surface with an error path. <!-- @impl: lib/screens/simple_login_screen.dart::_showErrorSnackBar -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** [REQ-SET-001](settings.md#req-set-001-save-server-and-access-settings)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SESS-003: Provide request credentials for server actions

**Intent:** Upload, link, and remote item operations can request complete authenticated request credentials without duplicating credential lookup logic.

**Applies To:** Contributor

**Acceptance Criteria:**

1. Request credential construction prefers the browser sign-in session when one exists. <!-- @impl: lib/services/auth_service.dart::getAuthHeaders -->
2. Request credential construction falls back to the direct-credential session when no browser sign-in session exists. <!-- @impl: lib/services/auth_service.dart::sessionCookie -->
3. Optional access credentials are included when both stored parts are present. <!-- @impl: lib/services/auth_service.dart::cfClientSecret -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** [REQ-SESS-001](#req-sess-001-save-server-and-credential-settings)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SESS-004: Load profile and clear sessions

**Intent:** After sign-in, the app can display a user identity and can clear local access state when the user logs out.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface loads stored user and server information during initialization. <!-- @impl: lib/screens/home_screen.dart::_loadUserInfo -->
2. Missing stored username is recovered by fetching profile data and selecting the first supported identity field. <!-- @impl: lib/services/auth_service.dart::fetchUserInfo -->
3. Logout clears browser sign-in session state and direct session state. <!-- @impl: lib/services/auth_service.dart::logout -->
4. Clearing all credentials removes only owned credential keys and preserves unrelated preferences. <!-- @impl: lib/services/auth_service.dart::clearAllCredentials -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P1

**Dependencies:** [REQ-SESS-003](#req-sess-003-provide-request-credentials-for-server-actions)

**Verification:** Automated test

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
