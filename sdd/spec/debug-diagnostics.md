# Debug Diagnostics

Opt-in, in-app log capture with categories, levels, JSON export, and a viewer screen for triaging issues without a USB cable.

## REQ-LOG-001: Categorized ring buffer

**Status:** Implemented
**Intent:** When the user enables debug logs, every notable event in the app is captured into a ring buffer they can later inspect or export. The buffer is bounded so a long-running app cannot exhaust memory.
**Acceptance Criteria:**
- `DebugService._maxLogs` is set to `5000`. <!-- @impl: lib/services/debug_service.dart::DebugService -->
- When the buffer is full, the oldest log is removed before a new one is appended. <!-- @impl: lib/services/debug_service.dart::DebugService -->
- Each log entry carries timestamp, category (`AUTH`, `UPLOAD`, `FILES`, `URLs`, `INTENT`, `OAUTH`, `LOGIN`, `ACTIVITY`, `DEBUG`), level (`INFO`, `WARNING`, `ERROR`), message, and optional `data` map. <!-- @impl: lib/services/debug_service.dart::log -->
- Convenience methods `logAuth`, `logUpload`, `logIntent`, `logError` wrap `log()` with the right category. <!-- @impl: lib/services/debug_service.dart::logError -->

**Constraints:** [CON-OBS-001](constraints.md#con-obs-001-debug-logs-are-local-and-opt-in).
**Dependencies:** None.

## REQ-LOG-002: Opt-in toggle persists across sessions

**Status:** Implemented
**Intent:** Debug logging is off by default to avoid storing uninteresting events on healthy installs. The user toggles it on from settings when they are troubleshooting.
**Acceptance Criteria:**
- `_debugLogsEnabled` is loaded from `SharedPreferences` key `debug_logs_enabled` at `initialize()`. <!-- @impl: lib/services/debug_service.dart::initialize -->
- `setDebugLogsEnabled(bool)` writes the new value to the same key. <!-- @impl: lib/services/debug_service.dart::setDebugLogsEnabled -->
- `log()` returns immediately when the flag is `false`. <!-- @impl: lib/services/debug_service.dart::log -->

**Constraints:** None.
**Dependencies:** None.

## REQ-LOG-003: Filterable log viewer

**Status:** Implemented
**Intent:** The debug screen renders the captured logs and lets the user filter by category and level so the relevant events surface quickly.
**Acceptance Criteria:**
- `DebugScreen` renders the result of `DebugService.getLogs(category, level)` as cards. <!-- @impl: lib/screens/debug_screen.dart::build -->
- Category and level chip filters update local state and re-fetch. <!-- @impl: lib/screens/debug_screen.dart::_DebugScreenState -->
- A "clear logs" action calls `DebugService.clearLogs()`. <!-- @impl: lib/screens/debug_screen.dart::_clearLogs -->

**Constraints:** None.
**Dependencies:** None.

## REQ-LOG-004: JSON export to documents directory

**Status:** Implemented
**Intent:** When the user shares a bug report, they need a portable file. The debug screen writes the filtered logs to the app's documents directory as `zipline_debug_logs_<timestamp>.json`.
**Acceptance Criteria:**
- `DebugService.exportLogsToFile(category, level)` writes JSON to `<getApplicationDocumentsDirectory>/zipline_debug_logs_<timestampMs>.json`. <!-- @impl: lib/services/debug_service.dart::exportLogsToFile -->
- The JSON envelope carries `exportTimestamp`, `totalLogs`, applied `filters`, and a `logs` array. <!-- @impl: lib/services/debug_service.dart::getLogsAsJson -->
- The debug screen's "export" action surfaces the resulting file via the system share sheet. <!-- @impl: lib/screens/debug_screen.dart::_DebugScreenState -->

**Constraints:** None.
**Dependencies:** None.

_Verification: code-only (no automated coverage)._
