# Upload Queue

This domain covers queued upload tasks, bounded processing, user controls, retry behavior, and global queue presentation.

### REQ-QUEUE-001: Create upload tasks for queued files

**Intent:** Files can be added to a queue so uploads can be tracked independently from the UI event that created them.

**Applies To:** User

**Acceptance Criteria:**

1. Adding a file creates an upload task with a unique identifier. <!-- @impl: lib/services/upload_queue_service.dart::addToQueue -->
2. Adding a task notifies queue listeners immediately. <!-- @impl: lib/services/upload_queue_service.dart::_notifyQueueUpdate -->
3. Queue auto-processing starts when enabled and no processing loop is active. <!-- @impl: lib/services/upload_queue_service.dart::_autoProcessEnabled -->
4. The queue exposes pending, active, and completed tasks as one list. <!-- @impl: lib/services/upload_queue_service.dart::allTasks -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** [REQ-FILE-002](file-upload.md#req-file-002-upload-selected-files-with-progress)

**Verification:** Automated test

**Status:** Implemented

---

### REQ-QUEUE-002: Process queued uploads with user controls

**Intent:** The queue processes pending uploads while allowing the user to pause, resume, or cancel individual tasks.

**Applies To:** User

**Acceptance Criteria:**

1. The processing loop starts pending uploads while capacity is available. <!-- @impl: lib/services/upload_queue_service.dart::_processQueue -->
2. Pausing an active task cancels its in-flight request and returns it to the front of the queue. <!-- @impl: lib/services/upload_queue_service.dart::pauseTask -->
3. Resuming a paused task returns it to pending state and restarts processing when needed. <!-- @impl: lib/services/upload_queue_service.dart::resumeTask -->
4. Cancelling removes an active or pending task from queue state. <!-- @impl: lib/services/upload_queue_service.dart::cancelTask -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** [REQ-QUEUE-001](#req-queue-001-create-upload-tasks-for-queued-files)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-QUEUE-003: Retry and finish upload tasks

**Intent:** Each queued upload reports progress, records success, retries recoverable failures, and marks unrecoverable failures visibly.

**Applies To:** User

**Acceptance Criteria:**

1. Each task moves to uploading state before its request starts. <!-- @impl: lib/services/upload_queue_service.dart::_uploadFile -->
2. Upload progress updates the task and notifies listeners. <!-- @impl: lib/services/upload_queue_service.dart::onSendProgress -->
3. Successful completion records the result link and completion time. <!-- @impl: lib/services/upload_queue_service.dart::uploadedAt -->
4. Recoverable failures requeue the task until the retry limit is reached. <!-- @impl: lib/services/upload_queue_service.dart::retryCount -->
5. Exhausted failures mark the task as failed and retain the error. <!-- @impl: lib/services/upload_queue_service.dart::UploadStatus -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P0

**Dependencies:** [REQ-QUEUE-002](#req-queue-002-process-queued-uploads-with-user-controls)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-QUEUE-004: Present queue state globally

**Intent:** Queue status and controls remain available above the normal app screens so active uploads are not hidden.

**Applies To:** User

**Acceptance Criteria:**

1. The overlay subscribes to app state changes before rendering queue content. <!-- @impl: lib/widgets/upload_queue_overlay.dart::UploadQueueOverlay -->
2. The floating button reflects whether the upload queue is visible. <!-- @impl: lib/widgets/upload_queue_overlay.dart::UploadQueueFloatingButton -->
3. The queue widget renders task state from the queue service stream. <!-- @impl: lib/widgets/upload_queue_widget.dart::UploadQueueWidget -->
4. Detailed queue controls invoke pause, resume, cancel, and retry actions. <!-- @impl: lib/widgets/upload_queue_widget.dart::_showQueueDetails -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-BOOT-003](app-bootstrap.md#req-boot-003-render-global-shell-overlays), [REQ-QUEUE-003](#req-queue-003-retry-and-finish-upload-tasks)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
