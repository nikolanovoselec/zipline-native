# Settings

This domain covers configuration screens for server address, optional access credentials, diagnostics, appearance, local unlock, and logout.

### REQ-SET-001: Save server and access settings

**Intent:** The user can configure the server address and optional access credentials before signing in or after entering the app.

**Applies To:** User

**Acceptance Criteria:**

1. The settings surface loads the current server and optional access values into editable fields. <!-- @impl: lib/screens/settings_screen.dart::_loadCurrentSettings -->
2. The server address field validates that a usable authority is present. <!-- @impl: lib/screens/settings_screen.dart::_buildServerUrlTextField -->
3. Saving settings preserves existing username and password values while updating server and optional access values. <!-- @impl: lib/screens/settings_screen.dart::_saveSettings -->
4. The sign-in surface settings button opens the settings surface and reloads credentials on return. <!-- @impl: lib/screens/simple_login_screen.dart::SettingsScreen -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest)

**Priority:** P0

**Dependencies:** [REQ-SESS-001](server-session.md#req-sess-001-save-server-and-credential-settings)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SET-002: Protect unsaved settings changes

**Intent:** The settings surface warns the user before leaving with unsaved changes so configuration edits are not lost accidentally.

**Applies To:** User

**Acceptance Criteria:**

1. Field changes mark the settings form as changed. <!-- @impl: lib/screens/settings_screen.dart::_onFieldChanged -->
2. Back navigation is blocked while changes are unsaved. <!-- @impl: lib/screens/settings_screen.dart::PopScope -->
3. The user can discard unsaved changes after confirming. <!-- @impl: lib/screens/settings_screen.dart::shouldDiscard -->
4. Successful save clears the changed state. <!-- @impl: lib/screens/settings_screen.dart::_hasChanges -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-SET-001](#req-set-001-save-server-and-access-settings)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SET-003: Manage diagnostics, appearance, local unlock, and logout

**Intent:** The settings surface groups user-manageable app controls in one place so operational changes do not require code or rebuilds.

**Applies To:** User

**Acceptance Criteria:**

1. The settings surface toggles diagnostic logging through the diagnostics service. <!-- @impl: lib/screens/settings_screen.dart::_toggleDebugLogs -->
2. The settings surface opens the diagnostics viewer. <!-- @impl: lib/screens/settings_screen.dart::DebugScreen -->
3. The settings surface toggles the appearance provider. <!-- @impl: lib/screens/settings_screen.dart::ThemeProvider -->
4. The settings surface toggles local unlock when available. <!-- @impl: lib/screens/settings_screen.dart::_toggleBiometric -->
5. Logout clears session state and returns the user to the sign-in surface. <!-- @impl: lib/screens/settings_screen.dart::_logout -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-protect-secrets-at-rest), [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** [REQ-DIAG-001](diagnostics.md#req-diag-001-keep-diagnostic-logging-opt-in), [REQ-THEME-001](theme-and-state.md#req-theme-001-persist-appearance-choice), [REQ-BIO-003](biometric-gate.md#req-bio-003-manage-local-unlock-preference)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
