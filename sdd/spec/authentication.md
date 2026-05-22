# Authentication

Username/password login against a Zipline server, Cloudflare Access service-token forwarding, session-cookie storage in secure storage, and logout.

## REQ-AUTH-001: Username/password login captures and stores session cookie

**Status:** Implemented
**Intent:** A user enters Zipline server URL, username, and password into the login screen. On `200 OK` the server's `Set-Cookie: zipline_session=…` is captured, persisted to secure storage, and used for every subsequent authenticated request.
**Acceptance Criteria:**
- `AuthService.login(ziplineUrl, username, password, …)` posts JSON `{username, password}` (plus optional `code` for 2FA) to `<ziplineUrl>/api/auth/login`. <!-- @impl: lib/services/auth_service.dart::login -->
- On `200`, the `zipline_session` value is parsed from the response `set-cookie` header and stored via `FlutterSecureStorage` under the key `session_cookie`. <!-- @impl: lib/services/auth_service.dart::login -->
- The Zipline URL and username are persisted to `SharedPreferences` under the keys `zipline_url` and `zipline_username` so the login screen can pre-fill them next time. <!-- @impl: lib/services/auth_service.dart::saveCredentials -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest).
**Dependencies:** None.

## REQ-AUTH-002: Session presence check

**Status:** Implemented
**Intent:** Other parts of the app need a synchronous-feeling "is the user logged in" check that returns true if either credential-based session OR OAuth session is valid, without making a network call.
**Acceptance Criteria:**
- `AuthService.isAuthenticated()` returns `true` when `OAuthService.hasOAuthSession()` returns true. <!-- @impl: lib/services/auth_service.dart::isAuthenticated -->
- Otherwise, it returns `true` when `getCredentials()` yields a non-null `sessionCookie`. <!-- @impl: lib/services/auth_service.dart::isAuthenticated -->
- The method does not contact the Zipline server — staleness is detected at upload time, not at session-presence time. <!-- @impl: lib/services/auth_service.dart::isAuthenticated -->

**Constraints:** None.
**Dependencies:** [REQ-OAUTH-002](oauth.md#req-oauth-002-session-cookie-storage-after-callback).

## REQ-AUTH-003: Cloudflare Access service-token forwarding

**Status:** Implemented
**Intent:** When the user's Zipline server sits behind Cloudflare Access, the app must forward `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers on every request so Access lets the call through to Zipline.
**Acceptance Criteria:**
- The user enters Client ID + Client Secret in the settings screen; values are persisted to `FlutterSecureStorage` under keys `cf_client_id` and `cf_client_secret`. <!-- @impl: lib/services/auth_service.dart::saveCredentials -->
- `AuthService.getAuthHeaders()` includes both headers in the returned map when the values are non-null. <!-- @impl: lib/services/auth_service.dart::getAuthHeaders -->
- `OAuthService` forwards the same headers when it requests the OAuth URL from Zipline. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest).
**Dependencies:** None.

## REQ-AUTH-004: Logout clears every credential surface

**Status:** Implemented
**Intent:** Logout must leave no recoverable session state on the device. After logout the app behaves as if it were freshly installed for auth purposes, including disabling any biometric shortcut that depended on the now-gone session.
**Acceptance Criteria:**
- `AuthService.logout()` clears the OAuth session via `OAuthService.clearSession()`. <!-- @impl: lib/services/auth_service.dart::logout -->
- It deletes `session_cookie` from both `FlutterSecureStorage` and `SharedPreferences` (the second handles the legacy migration path). <!-- @impl: lib/services/auth_service.dart::logout -->
- It disables biometric authentication so the next launch falls back to credential entry. <!-- @impl: lib/services/auth_service.dart::logout -->

**Constraints:** None.
**Dependencies:** [REQ-BIO-003](biometric.md#req-bio-003-disable-biometric-from-settings-or-on-logout), [REQ-OAUTH-003](oauth.md#req-oauth-003-clear-oauth-session-on-logout).

## REQ-AUTH-005: Legacy SharedPreferences → secure storage migration

**Status:** Implemented
**Intent:** Earlier app versions stored sensitive values (password, session cookie, Cloudflare Access secrets) in plain `SharedPreferences`. The migration moves them to `FlutterSecureStorage` once and removes the plaintext copy.
**Acceptance Criteria:**
- `AuthService._migrateSensitiveDataIfNeeded()` runs on credential read and write paths. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded -->
- The migration iterates over `password`, `session_cookie`, `cf_client_id`, `cf_client_secret`; for each key, if the secure store is empty and a SharedPreferences value exists, it copies the value and deletes the SP entry. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded -->
- The migration is idempotent: a class-level `_sensitiveDataMigrated` flag prevents re-running within the same process. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest).
**Dependencies:** None.
**Notes:** TRIAGE-006 resolved 2026-05-22 — accepted as eventual-removal target. The migration is retained until the pre-migration release age can be confirmed older than the oldest in-use install; deletion will land in a dedicated change after that confirmation.

_Verification: code-only (no automated coverage)._
