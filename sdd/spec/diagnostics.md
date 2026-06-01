# Diagnostics

This domain covers opt-in local logging, log filtering, export, sharing, and clearing.

### REQ-DIAG-001: Keep diagnostic logging opt-in

**Intent:** Diagnostic logging stays off unless the user enables it, reducing background storage and accidental data retention.

**Applies To:** User

**Acceptance Criteria:**

1. Diagnostic initialization loads the saved enabled flag before recording logs. <!-- @impl: lib/services/debug_service.dart::initialize -->
2. Log recording returns immediately when diagnostics are disabled. <!-- @impl: lib/services/debug_service.dart::_debugLogsEnabled -->
3. The settings surface toggles the saved diagnostic logging preference. <!-- @impl: lib/screens/settings_screen.dart::_toggleDebugLogs -->
4. Enabling diagnostics records the preference for later launches. <!-- @impl: lib/services/debug_service.dart::setDebugLogsEnabled -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-SET-003](settings.md#req-set-003-manage-diagnostics-appearance-local-unlock-and-logout)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-DIAG-002: Store and filter logs locally

**Intent:** When diagnostics are enabled, logs can be stored locally and filtered so troubleshooting can focus on a category or severity.

**Applies To:** User

**Acceptance Criteria:**

1. Log recording stores timestamp, category, severity, message, and optional data. <!-- @impl: lib/services/debug_service.dart::DebugLog -->
2. Log storage trims older entries when the cap is exceeded. <!-- @impl: lib/services/debug_service.dart::_maxLogs -->
3. Log retrieval can filter by category. <!-- @impl: lib/services/debug_service.dart::getLogs -->
4. Log retrieval can filter by severity. <!-- @impl: lib/services/debug_service.dart::level -->
5. The debug screen refreshes filtered logs into screen state. <!-- @impl: lib/screens/debug_screen.dart::_refreshLogs -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-DIAG-001](#req-diag-001-keep-diagnostic-logging-opt-in)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-DIAG-003: Export and share diagnostics

**Intent:** The user can export local logs for troubleshooting and share them through the platform share surface, with a fallback if sharing fails.

**Applies To:** User

**Acceptance Criteria:**

1. Log export writes the filtered log payload to a local file. <!-- @impl: lib/services/debug_service.dart::exportLogsToFile -->
2. The debug screen shows export success details before sharing. <!-- @impl: lib/screens/debug_screen.dart::_exportLogs -->
3. Sharing uses the platform share surface with the exported file. <!-- @impl: lib/screens/debug_screen.dart::_shareLogFile -->
4. If sharing fails, the debug screen copies the exported content to clipboard as a fallback. <!-- @impl: lib/screens/debug_screen.dart::Clipboard -->
5. Clearing diagnostics removes in-memory logs and persists the clear. <!-- @impl: lib/services/debug_service.dart::clearLogs -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-DIAG-002](#req-diag-002-store-and-filter-logs-locally)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
