# Upload

Single-file multipart uploads to the configured Zipline server with progress callbacks and structured success/failure results.

## REQ-UPLOAD-001: Multipart upload to Zipline `/api/upload`

**Status:** Implemented
**Intent:** A configured user can upload a `File` to their Zipline server. The server returns one or more URLs which the app surfaces to the user.
**Acceptance Criteria:**
- `FileUploadService.uploadFile(file, onProgress)` resolves `ziplineUrl` and auth headers from `AuthService.getCredentials()` and `getAuthHeaders()`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- The request is a `multipart/form-data` POST to `<ziplineUrl>/api/upload` with the file under the field name `file`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- The request uses `dio` so progress is reported via the `onSendProgress` callback. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- On success the response JSON's `files[0].url` (or top-level `url` for legacy) is parsed and returned in a `{success: true, url, fileId, size, timestamp}` map. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->

**Constraints:** [CON-API-001](constraints.md#con-api-001-tolerate-zipline-server-version-drift).
**Dependencies:** [REQ-AUTH-001](authentication.md#req-auth-001-usernamepassword-login-captures-and-stores-session-cookie), [REQ-AUTH-003](authentication.md#req-auth-003-cloudflare-access-service-token-forwarding).

## REQ-UPLOAD-002: MIME-type detection by extension

**Status:** Implemented
**Intent:** The Zipline server treats files differently based on the `Content-Type` of each multipart part. The client detects MIME from the file extension via the `mime` package so the server sees the right type even for files renamed during share.
**Acceptance Criteria:**
- The multipart part is constructed with `MediaType` derived from `lookupMimeType(file.path)`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- Files whose extension is unknown to `lookupMimeType` fall back to `application/octet-stream`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->

**Constraints:** None.
**Dependencies:** [REQ-SHARE-004](share-intent.md#req-share-004-file-extension-inference-for-android-content-uris).

## REQ-UPLOAD-003: Progress callbacks at upload-task granularity

**Status:** Implemented
**Intent:** The UI shows per-task upload progress so the user knows how far through a large share-sheet batch they are. Progress is reported as a 0.0–1.0 double from the bytes-sent count.
**Acceptance Criteria:**
- `uploadFile` exposes an optional `onProgress(double)` callback wired to `dio`'s `onSendProgress`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- The `UploadQueueService` updates `task.progress` on every callback and notifies queue listeners. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->
- The `UploadQueueWidget` renders a `LinearProgressIndicator` bound to `task.progress`. <!-- @impl: lib/widgets/upload_queue_widget.dart::UploadQueueWidget -->

**Constraints:** None.
**Dependencies:** [REQ-QUEUE-001](upload-queue.md#req-queue-001-concurrent-bounded-pipeline).

## REQ-UPLOAD-004: Structured error result on failure

**Status:** Implemented
**Intent:** Any upload failure — network error, Dio exception, server 4xx/5xx — must return a structured result rather than throwing so the queue can decide whether to retry.
**Acceptance Criteria:**
- The `catch (e, stackTrace)` block returns `{success: false, error: e.toString()}`. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->
- `_debugService.logError('UPLOAD', …, error: e, stackTrace: stackTrace)` captures the trace for the in-app debug screen. <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->

**Constraints:** None.
**Dependencies:** [REQ-LOG-001](debug-diagnostics.md#req-log-001-categorized-ring-buffer).

_Verification: code-only (no automated coverage)._
