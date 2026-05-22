# Upload Queue

Concurrency-bounded upload pipeline with exponential-backoff retry, cancellation, and a status stream the UI subscribes to.

## REQ-QUEUE-001: Concurrent bounded pipeline

**Status:** Implemented
**Intent:** Sharing a folder full of photos must not flood the network. The queue caps in-flight uploads so the device, the user's network, and the Zipline server all stay responsive.
**Acceptance Criteria:**
- `UploadQueueService.maxConcurrentUploads` is set to `3`. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService -->
- `_processQueue()` runs while either `_queue` or `_activeTasks` is non-empty; it starts new tasks until `_activeTasks.length` reaches `maxConcurrentUploads`. <!-- @impl: lib/services/upload_queue_service.dart::_processQueue -->
- Tasks beyond the limit remain in `_queue` with status `pending` until a slot opens. <!-- @impl: lib/services/upload_queue_service.dart::_processQueue -->

**Constraints:** [CON-NET-001](constraints.md#con-net-001-upload-concurrency-capped-at-3).
**Dependencies:** None.

## REQ-QUEUE-002: Exponential backoff retry

**Status:** Implemented
**Intent:** Transient network failures should not abandon an upload. Each task may retry up to 3 times with growing delays so a recoverable failure (DNS flap, Wi-Fi handoff) does not surface as a user-facing error.
**Acceptance Criteria:**
- `UploadQueueService.maxRetries` is set to `3`. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService -->
- On failure with `retryCount < maxRetries`, the task is re-queued at the front of `_queue` with incremented `retryCount`. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->
- Delay before retry follows the 2s → 4s → 8s schedule (calculated as `Duration(seconds: pow(2, retryCount + 1))`). <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->
- After `maxRetries` failures the task transitions to `failed` and stops consuming a slot. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->

**Constraints:** [CON-NET-002](constraints.md#con-net-002-upload-retry-bounded-by-exponential-backoff).
**Dependencies:** None.

## REQ-QUEUE-003: Cancellation via `CancelToken`

**Status:** Implemented
**Intent:** The user can cancel an in-flight upload at any time. Cancellation interrupts the current `dio` request and removes the task without further retry.
**Acceptance Criteria:**
- Each running task carries a `CancelToken` assigned at upload-start. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->
- `UploadQueueService.cancelTask(taskId)` calls `task.cancelToken?.cancel()` and removes the task from active set + queue. <!-- @impl: lib/services/upload_queue_service.dart::cancelTask -->
- A cancelled task does NOT enter the retry path. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->

**Constraints:** None.
**Dependencies:** None.

## REQ-QUEUE-004: Status stream broadcasts queue state

**Status:** Implemented
**Intent:** The UI needs to react to queue changes without polling. A single stream broadcasts every transition so widgets can rebuild and the overlay can show or hide itself.
**Acceptance Criteria:**
- `UploadQueueService` exposes a broadcast stream via `queueStream`. <!-- @impl: lib/services/upload_queue_service.dart::UploadQueueService -->
- `_notifyQueueUpdate()` adds the current task list to the stream on every status change. <!-- @impl: lib/services/upload_queue_service.dart::_notifyQueueUpdate -->
- `AppState._initializeState()` subscribes and shows the upload-queue overlay when `hasActiveUploads` becomes true. <!-- @impl: lib/providers/app_state.dart::_initializeState -->

**Constraints:** None.
**Dependencies:** [REQ-STATE-001](theme-and-state.md#req-state-001-global-appstate).

_Verification: code-only (no automated coverage)._
