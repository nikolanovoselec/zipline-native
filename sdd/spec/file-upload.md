# File Upload

This domain covers selecting files, uploading them, tracking progress, and handing the resulting link back to the user.

### REQ-FILE-001: Let users choose files manually

**Intent:** The user can start an upload from inside the app when they are not arriving from the platform share surface.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface opens a file picker that allows multiple selections. <!-- @impl: lib/screens/home_screen.dart::_pickAndUploadFiles -->
2. Picker cancellation leaves the upload path without showing a failure state. <!-- @impl: lib/screens/home_screen.dart::FilePickerResult -->
3. Picked file references are converted into file objects before upload starts. <!-- @impl: lib/screens/home_screen.dart::File -->
4. File-picker errors surface through the retryable error path. <!-- @impl: lib/screens/home_screen.dart::_showErrorSnackBar -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-SESS-003](server-session.md#req-sess-003-provide-request-credentials-for-server-actions)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-FILE-002: Upload selected files with progress

**Intent:** Selected files are sent to the configured server with progress feedback and normalized success or failure results.

**Applies To:** User

**Acceptance Criteria:**

1. A single file upload refuses to continue when no server address is configured. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
2. A single file upload obtains authentication headers before sending the request. <!-- @impl: lib/services/file_upload_service.dart::getAuthHeaders -->
3. A single file upload detects the file type before building upload data. <!-- @impl: lib/services/file_upload_service.dart::lookupMimeType -->
4. Upload progress callbacks receive a clamped progress value. <!-- @impl: lib/services/file_upload_service.dart::onSendProgress -->
5. Upload failures return a structured failure result instead of throwing through the UI. <!-- @impl: lib/services/file_upload_service.dart::DioException -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable), [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-FILE-001](#req-file-001-let-users-choose-files-manually)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-FILE-003: Upload batches and store successful results

**Intent:** The app handles multiple selected files as one user action while preserving each successful result in recent activity.

**Applies To:** User

**Acceptance Criteria:**

1. Batch upload calculates overall progress from each file's progress. <!-- @impl: lib/services/file_upload_service.dart::uploadMultipleFiles -->
2. The home surface saves each successful upload result to activity history. <!-- @impl: lib/screens/home_screen.dart::addActivity -->
3. The home surface reloads activity after saving successful upload results. <!-- @impl: lib/screens/home_screen.dart::_loadActivities -->
4. If every upload fails, the home surface shows an upload failure path. <!-- @impl: lib/screens/home_screen.dart::successCount -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** [REQ-ACT-001](activity-log.md#req-act-001-persist-recent-activity), [REQ-FILE-002](#req-file-002-upload-selected-files-with-progress)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-FILE-004: Hand successful links back to the user

**Intent:** A successful upload gives the user a shareable result without forcing them to manually find the link.

**Applies To:** User

**Acceptance Criteria:**

1. A single successful upload is copied to clipboard. <!-- @impl: lib/screens/home_screen.dart::_copyToClipboard -->
2. A single successful upload schedules the platform share surface unless sharing is suppressed. <!-- @impl: lib/screens/home_screen.dart::_copyShareAndNotify -->
3. Multiple successful uploads show a ready notification without choosing one link silently. <!-- @impl: lib/screens/home_screen.dart::_processUploadResults -->
4. Share-surface failures produce a visible notification instead of ending silently. <!-- @impl: lib/screens/home_screen.dart::_openShareSheet -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-FILE-003](#req-file-003-upload-batches-and-store-successful-results)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
