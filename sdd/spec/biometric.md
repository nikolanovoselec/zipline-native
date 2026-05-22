# Biometric

Optional biometric (fingerprint, face) gating between session validity and home-screen access.

## REQ-BIO-001: Enable / disable biometric from settings

**Status:** Implemented
**Intent:** After login, the user can opt in to biometric gating from the settings screen. Enabling requires a successful biometric prompt as proof that biometric hardware works on this device.
**Acceptance Criteria:**
- `BiometricService.isBiometricAvailable()` returns true only when `LocalAuthentication.canCheckBiometrics`, `isDeviceSupported`, and `getAvailableBiometrics` all indicate a usable enrolment. <!-- @impl: lib/services/biometric_service.dart::isBiometricAvailable -->
- The settings screen's toggle calls `BiometricService.authenticate(reason: 'Verify your identity to enable biometric login')` before enabling; a failed prompt leaves the toggle off. <!-- @impl: lib/screens/settings_screen.dart::_toggleBiometric -->
- On enable, `BiometricService.enableBiometric(token)` stores the current auth token under the secure key `biometric_token` and sets the `SharedPreferences` flag `biometric_enabled = true`. <!-- @impl: lib/services/biometric_service.dart::enableBiometric -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest).
**Dependencies:** None.

## REQ-BIO-002: Prompt on resume when enabled

**Status:** Implemented
**Intent:** When the splash screen reaches the "session is valid" branch and biometric is enabled, the user must satisfy a biometric prompt before the home screen renders.
**Acceptance Criteria:**
- The splash checks `BiometricService.isBiometricEnabled()` after `isAuthenticated()` returns true. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- A failed biometric routes the user to `SimpleLoginScreen` rather than `HomeScreen`. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- The prompt reason string is the user-facing message `Authenticate to access Zipline`. <!-- @impl: lib/main.dart::_checkAuthStatus -->

**Constraints:** None.
**Dependencies:** [REQ-BOOT-004](app-bootstrap.md#req-boot-004-biometric-gate-before-home).

## REQ-BIO-003: Disable biometric from settings or on logout

**Status:** Implemented
**Intent:** Disabling biometric removes the stored token and the enabled flag, so the next launch goes straight from session check to home with no prompt.
**Acceptance Criteria:**
- `BiometricService.disableBiometric()` deletes the secure-storage key `biometric_token` and sets the `SharedPreferences` flag `biometric_enabled = false`. <!-- @impl: lib/services/biometric_service.dart::disableBiometric -->
- The method is called from the settings-screen toggle and from `AuthService.logout()`. <!-- @impl: lib/screens/settings_screen.dart::_toggleBiometric -->

**Constraints:** None.
**Dependencies:** [REQ-AUTH-004](authentication.md#req-auth-004-logout-clears-every-credential-surface).

_Verification: code-only (no automated coverage)._
