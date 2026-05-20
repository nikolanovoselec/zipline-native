# Debug

In-app debugging surface: activity log, debug screen, log export.

**Actors:** User

---

### REQ-DEBUG-001: Rolling activity log

**Status:** Implemented
**Actor:** User
**Intent:** A user troubleshooting a broken upload can open a debug screen and see a chronological log of recent app events.

**Acceptance criteria:**
- An `ActivityService` records events with timestamp, level (info/warn/error), and message.
- The log is in-memory, capped at 500 events, FIFO eviction.
- The Debug screen displays the log with most-recent-first ordering.
- The Debug screen offers a "Clear log" action that resets the in-memory log.

**Constraints:** [CON-OBS-001](constraints.md#con-obs-001-activity-log-size-cap)
**Dependencies:** None.

---

### REQ-DEBUG-002: Log export to clipboard

**Status:** Implemented
**Actor:** User
**Intent:** A user can copy the activity log as plain text for sharing in a bug report.

**Acceptance criteria:**
- A "Copy log" button in the Debug screen copies the full log to the system clipboard.
- The copied format is `[timestamp] [level] message` per line.
- The clipboard copy emits a confirmation snackbar.

**Constraints:** None.
**Dependencies:** [REQ-DEBUG-001](#req-debug-001-rolling-activity-log)

---

### REQ-DEBUG-003: Debug screen access gate

**Status:** Implemented
**Actor:** User
**Intent:** The Debug screen is reachable from Settings but not surfaced on the home screen, keeping it out of the casual user's path.

**Acceptance criteria:**
- Settings screen contains a "Debug" entry that navigates to the Debug screen.
- The home screen contains no Debug entry-point.
- The Debug screen does not require a special unlock; the Settings location is the gating.

**Constraints:** None.
**Dependencies:** [REQ-DEBUG-001](#req-debug-001-rolling-activity-log)

---

_Verification: code-only (no automated coverage)._
