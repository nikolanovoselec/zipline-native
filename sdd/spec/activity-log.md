# Activity Log

This domain covers local recent activity storage, loading, limiting, saving, and clearing.

### REQ-ACT-001: Persist recent activity

**Intent:** Successful uploads and shortened links are remembered locally so the user can find and reuse recent results.

**Applies To:** User

**Acceptance Criteria:**

1. Activity storage initializes preferences before reading or writing. <!-- @impl: lib/services/activity_service.dart::initialize -->
2. Adding an activity creates a timestamp when the caller did not provide one. <!-- @impl: lib/services/activity_service.dart::addActivity -->
3. New activity entries are inserted before older entries. <!-- @impl: lib/services/activity_service.dart::insert -->
4. Saved activity history is serialized into local preferences. <!-- @impl: lib/services/activity_service.dart::saveActivities -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** None.

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-ACT-002: Load and clear recent activity

**Intent:** The app restores recent activity on launch and gives the user a way to clear the local list.

**Applies To:** User

**Acceptance Criteria:**

1. Activity loading returns an empty list when no local history exists. <!-- @impl: lib/services/activity_service.dart::getActivities -->
2. Activity loading tolerates decode failures by returning an empty list. <!-- @impl: lib/services/activity_service.dart::json.decode -->
3. The home surface loads activities into screen state. <!-- @impl: lib/screens/home_screen.dart::_loadActivities -->
4. Clearing activities removes the local activity key. <!-- @impl: lib/services/activity_service.dart::clearActivities -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-ACT-001](#req-act-001-persist-recent-activity)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
