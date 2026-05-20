# Authentication

User login to a Zipline instance. Three paths: username/password, OAuth/OIDC (via Worker), biometric unlock for an already-paired instance.

**Actors:** User, Worker, Zipline Server

---

### REQ-AUTH-001: Username/password login

**Status:** Implemented
**Actor:** User
**Intent:** A user with valid Zipline credentials authenticates by entering URL, username, and password into the simple-login screen and receives a usable session.

**Acceptance criteria:**
- App accepts a Zipline instance URL, validating it parses as a URL with HTTPS scheme.
- App POSTs username + password to `<URL>/api/auth/login` and persists the returned session cookie.
- On HTTP 200 the home screen loads with the active session.
- On HTTP 401 the login screen displays an "Invalid credentials" message without clearing the URL field.
- On network error the login screen displays a "Connection failed" message with retry affordance.

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-hardware-backed-secrets)
**Dependencies:** None.

---

### REQ-AUTH-002: OAuth/OIDC login via Worker

**Status:** Implemented
**Actor:** User, Worker
**Intent:** A user with an OIDC-enabled Zipline instance authenticates by tapping "Sign in with OAuth", completing the browser flow, and returning to the app with an active session.

**Acceptance criteria:**
- App opens the Zipline OIDC start URL in the system browser via `flutter_web_auth_2`.
- The Worker receives the OAuth callback at its configured URL with `code` and `state` query parameters.
- The Worker exchanges the code with Zipline and extracts the session cookie from the response.
- The Worker redirects to the app's deep-link `zipline://oauth-callback` carrying the session token.
- App captures the deep-link via `app_links` and persists the session cookie via Flutter Secure Storage.
- The Worker validates `state` is non-empty; missing state returns HTTP 400 without contacting Zipline.

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-hardware-backed-secrets), [CON-SEC-002](constraints.md#con-sec-002-worker-validates-state-parameter), [CON-TECH-003](constraints.md#con-tech-003-cloudflare-workers-runtime)
**Dependencies:** [REQ-OAUTH-001](oauth-worker.md#req-oauth-001-callback-exchange)

---

### REQ-AUTH-003: Biometric unlock

**Status:** Implemented
**Actor:** User
**Intent:** A user with biometric hardware re-enters the app and unlocks an existing session using face/fingerprint instead of re-entering credentials.

**Acceptance criteria:**
- Biometric unlock is offered only when `local_auth.canCheckBiometrics` returns true AND the device has at least one enrolled biometric.
- Tapping "Unlock with biometrics" invokes `local_auth.authenticate` with `biometricOnly: true`.
- Successful biometric authentication retrieves the stored session from Flutter Secure Storage and lands the user on the home screen.
- Failed biometric authentication falls back to the password screen, never silently fails.
- A device without biometric hardware does not display the biometric unlock option.

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-hardware-backed-secrets)
**Dependencies:** [REQ-AUTH-001](#req-auth-001-usernamepassword-login)

---

### REQ-AUTH-004: Secure credential storage

**Status:** Implemented
**Actor:** User
**Intent:** Credentials and session tokens persist across app restarts using hardware-backed encrypted storage; a device-storage dump does not yield plain credentials.

**Acceptance criteria:**
- Session cookie stored via `FlutterSecureStorage` with `encryptedSharedPreferences: true` on Android.
- OAuth client ID and secret stored via `FlutterSecureStorage`, never in plain `SharedPreferences`.
- Zipline URL stored via plain `SharedPreferences` (URL is not a secret).
- Logout deletes all secure-storage entries and clears the session.

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-hardware-backed-secrets)
**Dependencies:** None.

---

### REQ-AUTH-005: Logout flushes state

**Status:** Implemented
**Actor:** User
**Intent:** A user signs out of the app, all session state is cleared, and the next launch lands on the login screen.

**Acceptance criteria:**
- Tapping logout in settings clears all `FlutterSecureStorage` entries for the active instance.
- Plain `SharedPreferences` entries holding the Zipline URL and theme preference persist (not credentials).
- Active upload queue is preserved across logout (uploads belong to the queue, not the session).
- App navigates back to the login screen and disables back-navigation to the home screen.

**Constraints:** None.
**Dependencies:** [REQ-AUTH-004](#req-auth-004-secure-credential-storage)

---

_Verification: code-only (no automated coverage)._
