# Theme And State

Global `AppState` + `ThemeProvider` exposing user, auth, upload, and theme state to every widget.

## REQ-STATE-001: Global `AppState`

**Status:** Implemented
**Intent:** Widgets across multiple screens (home, settings, upload overlay) all need to know the current user, authentication state, and active uploads without each fetching independently. A single `ChangeNotifier` holds the data and broadcasts changes.
**Acceptance Criteria:**
- `AppState` extends `ChangeNotifier` and exposes `username`, `ziplineUrl`, `isAuthenticated`, `uploadTasks`, `uploadQueueVisible`, `uploadQueueUiEnabled`, `isLoading`, `errorMessage`. <!-- @impl: lib/providers/app_state.dart::AppState -->
- `_initializeState()` subscribes to `UploadQueueService.queueStream` and auto-shows the upload-queue overlay when the active-uploads count becomes non-zero. <!-- @impl: lib/providers/app_state.dart::_initializeState -->
- `setUser(username, ziplineUrl)` updates the trio and sets `isAuthenticated = (username != null)`. <!-- @impl: lib/providers/app_state.dart::setUser -->
- `logout()` clears all user-related fields and notifies listeners. <!-- @impl: lib/providers/app_state.dart::AppState -->
- `dispose()` cancels the queue subscription. <!-- @impl: lib/providers/app_state.dart::AppState -->

**Constraints:** None.
**Dependencies:** [REQ-QUEUE-004](upload-queue.md#req-queue-004-status-stream-broadcasts-queue-state).

## REQ-THEME-001: Theme mode persistence

**Status:** Implemented
**Intent:** The user picks dark, light, or system theme mode from settings; the choice survives restarts.
**Acceptance Criteria:**
- `ThemeProvider` extends `ChangeNotifier`, holds a `ThemeMode`, and persists the choice to `SharedPreferences`. <!-- @impl: lib/providers/theme_provider.dart::ThemeProvider -->
- `setThemeMode(mode)` updates the field and writes the persisted value. <!-- @impl: lib/providers/theme_provider.dart::ThemeProvider -->
- The root widget consumes `ThemeProvider` and passes the mode to `MaterialApp.themeMode`, with `AppTheme.darkTheme` and `AppTheme.lightTheme` registered as the dark/light themes. <!-- @impl: lib/main.dart::ZiplineNativeApp -->

**Constraints:** None.
**Dependencies:** None.
**Notes:** TRIAGE-007 resolved 2026-05-22 — light theme is implemented and selectable from settings; the README's "dark mode only" line is marketing voice, not a technical limitation. A README copy refresh is recommended as a follow-up.

_Verification: code-only (no automated coverage)._
