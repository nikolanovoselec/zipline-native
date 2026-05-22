# Activity Log

Local cache of the user's recent uploads — file URL, timestamp, and metadata — for review and deletion.

## REQ-ACTIVITY-001: Persist recent uploads in `SharedPreferences`

**Status:** Implemented
**Intent:** The user can review the last N uploads from any screen without needing to fetch them from the server. Storage is local-only so the list survives app restarts but never leaves the device.
**Acceptance Criteria:**
- `ActivityService` stores activities under the `SharedPreferences` key `recent_activities` as a JSON-encoded list. <!-- @impl: lib/services/activity_service.dart::ActivityService -->
- `addActivity(map)` inserts a new entry at the head of the list. <!-- @impl: lib/services/activity_service.dart::addActivity -->
- The list is bounded at `_maxActivities = 50` entries; older entries fall off the tail. <!-- @impl: lib/services/activity_service.dart::ActivityService -->
- `getActivities()` returns a `List<Map<String, dynamic>>` cast from the persisted JSON. <!-- @impl: lib/services/activity_service.dart::getActivities -->

**Constraints:** None.
**Dependencies:** None.

## REQ-ACTIVITY-002: Activity row is created after every successful upload

**Status:** Implemented
**Intent:** Every successful upload contributes one entry to the activity log so the user can find the URL again later. Failed uploads do not pollute the list.
**Acceptance Criteria:**
- `FileUploadService.uploadFile` invokes `ActivityService().addActivity(...)` on successful completion. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- The entry includes `type: 'file'`, `url`, `fileName`, `fileId`, `size`, `timestamp`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- Shortened URLs are also logged with `type: 'url'`. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

**Constraints:** None.
**Dependencies:** [REQ-UPLOAD-001](upload.md#req-upload-001-multipart-upload-to-zipline-apiupload), [REQ-URL-001](url-shortener.md#req-url-001-shorten-a-url-with-v4--v3--legacy-fallback).

_Verification: code-only (no automated coverage)._
