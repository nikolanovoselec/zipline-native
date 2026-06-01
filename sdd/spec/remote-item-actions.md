# Remote Item Actions

This domain covers actions on recent files and links that may also exist on the configured server.

### REQ-REMOTE-001: Share recent items again

**Intent:** The user can reuse a recent file or link entry without repeating the original upload or shortening action.

**Applies To:** User

**Acceptance Criteria:**

1. Recent file entries derive their display link and name from the stored file result. <!-- @impl: lib/screens/home_screen.dart::file_upload -->
2. Recent link entries derive their display link and name from the stored link result. <!-- @impl: lib/screens/home_screen.dart::url_shortening -->
3. Tapping a recent item invokes the common copy-and-share path. <!-- @impl: lib/screens/home_screen.dart::_handleRecentItemShare -->
4. The share action chip has an accessibility label. <!-- @impl: lib/screens/home_screen.dart::_shareChipLabel -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P1

**Dependencies:** [REQ-ACT-001](activity-log.md#req-act-001-persist-recent-activity)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-REMOTE-002: Delete recent items locally and remotely when possible

**Intent:** Removing a recent entry updates the local history immediately and attempts to remove the remote item when the entry contains a server id.

**Applies To:** User

**Acceptance Criteria:**

1. Deleting a recent item removes it from local activity state immediately. <!-- @impl: lib/screens/home_screen.dart::_deleteRecentItem -->
2. Deleting a recent item persists the updated local activity list. <!-- @impl: lib/screens/home_screen.dart::saveActivities -->
3. File entries call the file deletion path when an id is available. <!-- @impl: lib/services/file_upload_service.dart::deleteFile -->
4. Link entries call the link deletion path when an id is available. <!-- @impl: lib/services/file_upload_service.dart::deleteUrl -->
5. Missing remote ids skip remote deletion without blocking local removal. <!-- @impl: lib/screens/home_screen.dart::itemId -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-REMOTE-001](#req-remote-001-share-recent-items-again)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-REMOTE-003: Attempt protection updates for recent items

**Intent:** The user can request protection for a recent item, and the app attempts the appropriate remote update based on the item type.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface asks for and confirms the protection value before sending an update. <!-- @impl: lib/screens/home_screen.dart::_setRecentItemPassword -->
2. File entries call the file protection path when an id is available. <!-- @impl: lib/services/file_upload_service.dart::setFilePassword -->
3. Link entries call the link protection path when an id is available. <!-- @impl: lib/services/file_upload_service.dart::setUrlPassword -->
4. Successful protection updates mark the local item as protected. <!-- @impl: lib/screens/home_screen.dart::hasPassword -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-REMOTE-001](#req-remote-001-share-recent-items-again)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-REMOTE-004: Fetch remote history lists

**Intent:** The service can fetch server-side file and link lists and normalize supported response shapes for later display or operations.

**Applies To:** User

**Acceptance Criteria:**

1. File history fetching refuses to continue when no server address is configured. <!-- @impl: lib/services/file_upload_service.dart::fetchUserFiles -->
2. File history fetching accepts list-shaped and paginated response shapes. <!-- @impl: lib/services/file_upload_service.dart::files -->
3. Link history fetching accepts list-shaped and wrapped response shapes. <!-- @impl: lib/services/file_upload_service.dart::fetchUserUrls -->
4. Remote history entries are normalized with id, type, display link, timestamp, and remote marker fields. <!-- @impl: lib/services/file_upload_service.dart::remote -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-SESS-003](server-session.md#req-sess-003-provide-request-credentials-for-server-actions)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
