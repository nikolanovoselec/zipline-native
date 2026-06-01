# Theme And State

This domain covers theme persistence and cross-screen state shared by providers.

### REQ-THEME-001: Persist appearance choice

**Intent:** The app remembers the user's appearance choice and applies it to the app shell on later launches.

**Applies To:** User

**Acceptance Criteria:**

1. Theme state loads the saved theme mode during provider initialization. <!-- @impl: lib/providers/theme_provider.dart::_loadTheme -->
2. Theme toggling switches between light and dark modes. <!-- @impl: lib/providers/theme_provider.dart::toggleTheme -->
3. Setting a theme mode persists the selected value. <!-- @impl: lib/providers/theme_provider.dart::setThemeMode -->
4. The app shell uses the current theme mode from provider state. <!-- @impl: lib/main.dart::ThemeProvider -->

**Constraints:** None.

**Priority:** P1

**Dependencies:** [REQ-SET-003](settings.md#req-set-003-manage-diagnostics-appearance-local-unlock-and-logout)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-THEME-002: Maintain shared app state

**Intent:** Cross-screen state for user identity, queue visibility, loading, and errors is centralized so screens can update consistently.

**Applies To:** Contributor

**Acceptance Criteria:**

1. App state subscribes to upload queue changes during initialization. <!-- @impl: lib/providers/app_state.dart::_initializeState -->
2. Active uploads automatically show the upload queue. <!-- @impl: lib/providers/app_state.dart::hasActiveUploads -->
3. User state can be set and cleared through explicit actions. <!-- @impl: lib/providers/app_state.dart::setUser -->
4. Queue visibility can be toggled, shown, hidden, and enabled from shared state. <!-- @impl: lib/providers/app_state.dart::setUploadQueueUiEnabled -->
5. App state cancels its queue subscription during disposal. <!-- @impl: lib/providers/app_state.dart::dispose -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-QUEUE-004](upload-queue.md#req-queue-004-present-queue-state-globally)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
