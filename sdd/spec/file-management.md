# File Management

Delete uploaded files and short URLs from the activity-log view; best-effort password protection.

## REQ-FILES-001: Delete an uploaded file

**Status:** Implemented
**Intent:** From the activity log, the user can delete an uploaded file. The deletion is propagated to the Zipline server and the activity-log row is removed locally.
**Acceptance Criteria:**
- `FileUploadService.deleteFile(fileId)` tries `DELETE <ziplineUrl>/api/user/files/<fileId>` first, falling back to legacy paths. <!-- @impl: lib/services/file_upload_service.dart::deleteFile -->
- Server returning 200 or 204 counts as success; the method returns `true`. <!-- @impl: lib/services/file_upload_service.dart::deleteFile -->
- Failures are logged via `DebugService.logError('FILES', …)` and surface as `false` to the caller. <!-- @impl: lib/services/file_upload_service.dart::deleteFile -->

**Constraints:** [CON-API-001](constraints.md#con-api-001-tolerate-zipline-server-version-drift).
**Dependencies:** [REQ-AUTH-003](authentication.md#req-auth-003-cloudflare-access-service-token-forwarding).

## REQ-FILES-002: Delete a short URL

**Status:** Implemented
**Intent:** Short URLs created via the shortener can be revoked. The activity log surfaces the delete control alongside file deletes.
**Acceptance Criteria:**
- `FileUploadService.deleteUrl(urlId)` issues `DELETE <ziplineUrl>/api/user/urls/<urlId>`. <!-- @impl: lib/services/file_upload_service.dart::deleteUrl -->
- 200 is treated as success; other responses log an error and return `false`. <!-- @impl: lib/services/file_upload_service.dart::deleteUrl -->

**Constraints:** None.
**Dependencies:** None.

## REQ-FILES-003: Best-effort file password (under triage)

**Status:** Partial
**Intent:** The activity-log row exposes a "set password" affordance that calls the server. The endpoint set is not known to be supported by any current Zipline release; the method tries three shapes and returns `false` on miss.
**Acceptance Criteria:**
- `setFilePassword(fileId, password)` tries `PATCH /api/user/files/<id>`, `PATCH /api/files/<id>`, `PATCH /api/user/files/<id>/password` in order. <!-- @impl: lib/services/file_upload_service.dart::setFilePassword -->
- On no endpoint accepting the payload, the method returns `false` silently. <!-- @impl: lib/services/file_upload_service.dart::setFilePassword -->

**Constraints:** None.
**Dependencies:** None.
**Notes:** TRIAGE-003 resolved 2026-05-22 — accepted as unverified-Partial. Status `Partial` reflects "implemented as written but the user-facing promise is unverified"; code stays in place, UI-side failure surfacing deferred until upstream Zipline support is confirmed or denied.

## REQ-FILES-004: File expiration cannot be modified after upload

**Status:** Partial
**Intent:** Document the server-side limitation surfaced by `setFileExpiration`: Zipline's `PATCH /api/user/files/:id` endpoint does not accept the `deletesAt` field, so the client cannot change a file's expiration after upload. Expiration must be set at upload time or not at all.
**Acceptance Criteria:**
- `FileUploadService.setFileExpiration(fileId, expiresAt)` logs an error and returns `false` unconditionally; no HTTP call is issued. <!-- @impl: lib/services/file_upload_service.dart::setFileExpiration -->
- The settings-screen file-detail UI exposes an expiration control that calls this method. The control is currently a no-op; surfacing the limitation in UI is a known gap (see Notes). <!-- @impl: lib/screens/settings_screen.dart::SettingsScreen -->

**Constraints:** None.
**Dependencies:** None.
**Notes:** TRIAGE-004 resolved 2026-05-22 — accepted as a documented limitation. Status `Partial` flags that the UI control survives in code despite being non-functional; hiding it is a separate future change.

_Verification: code-only (no automated coverage)._
