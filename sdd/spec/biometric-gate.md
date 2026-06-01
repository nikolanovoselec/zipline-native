# Biometric Gate

This domain covers optional local unlock after the user has an authenticated session.

### REQ-BIO-001: Detect local unlock availability

**Intent:** The app checks whether the current device can support local verification before offering that setup path to the user.

**Applies To:** User

**Acceptance Criteria:**

1. The local unlock service checks whether the device can perform biometric checks. <!-- @impl: lib/services/biometric_service.dart::isBiometricAvailable -->
2. The local unlock service checks whether the device is supported before reporting availability. <!-- @impl: lib/services/biometric_service.dart::isDeviceSupported -->
3. The local unlock service returns available local verification types for display. <!-- @impl: lib/services/biometric_service.dart::getAvailableBiometricTypes -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P1

**Dependencies:** None.

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BIO-002: Gate app entry with local verification

**Intent:** When the user enables local unlock, app entry requires a successful local verification before the main surface opens.

**Applies To:** User

**Acceptance Criteria:**

1. Startup checks whether local unlock is enabled before entering the main surface. <!-- @impl: lib/main.dart::isBiometricEnabled -->
2. Startup prompts for local verification when the saved setting is enabled. <!-- @impl: lib/main.dart::authenticate -->
3. Failed verification sends the user back to the sign-in surface. <!-- @impl: lib/main.dart::SimpleLoginScreen -->
4. Successful verification preserves the normal route to the main surface. <!-- @impl: lib/main.dart::HomeScreen -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P1

**Dependencies:** [REQ-BOOT-002](app-bootstrap.md#req-boot-002-route-users-after-a-local-access-check)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-BIO-003: Manage local unlock preference

**Intent:** The user can enable or disable local unlock after sign-in without changing the server session itself.

**Applies To:** User

**Acceptance Criteria:**

1. Enabling local unlock stores an enabled preference and a secure token value. <!-- @impl: lib/services/biometric_service.dart::enableBiometric -->
2. Disabling local unlock clears the enabled preference and stored token value. <!-- @impl: lib/services/biometric_service.dart::disableBiometric -->
3. The settings surface verifies the user before enabling local unlock. <!-- @impl: lib/screens/settings_screen.dart::_toggleBiometric -->
4. Local unlock can authenticate and return the stored token in one flow. <!-- @impl: lib/services/biometric_service.dart::authenticateAndGetToken -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P1

**Dependencies:** [REQ-SESS-003](server-session.md#req-sess-003-provide-request-credentials-for-server-actions)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
