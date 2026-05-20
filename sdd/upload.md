# Upload

File selection, upload, queue, retry. The core user flow.

**Actors:** User, Zipline Server

---

### REQ-UPLOAD-001: File picker upload

**Status:** Implemented
**Actor:** User
**Intent:** A user taps the upload button, selects one or more files, and each file uploads to the configured Zipline instance with inline progress.

**Acceptance criteria:**
- File picker invoked via `file_picker.pickFiles(allowMultiple: true)`.
- Each selected file POSTs to `<URL>/api/upload` as multipart/form-data with the session cookie.
- Per-file progress fires at minimum 500ms intervals and updates the Upload Files card 0-100%.
- On HTTP 200 the response link is appended to the Upload Files card with a "Copy" affordance.
- On HTTP 401 the upload aborts and the user is redirected to login.
- On network error the file enters the upload queue for offline retry.

**Constraints:** [CON-PERF-001](constraints.md#con-perf-001-upload-progress-every-500ms)
**Dependencies:** [REQ-AUTH-001](auth.md#req-auth-001-usernamepassword-login)

---

### REQ-UPLOAD-002: Inline progress UI

**Status:** Implemented
**Actor:** User
**Intent:** A user watching an upload sees per-file progress entirely inside the Upload Files card; no toast or notification replaces or hides the progress.

**Acceptance criteria:**
- Active uploads render as rows in the Upload Files card with per-file progress bars.
- Completed uploads remain in the card as result rows until the user dismisses them.
- Failed uploads display a retry button inline; tapping it re-enqueues.
- Multi-file selection appears as a vertical list within the same card, never as separate cards.

**Constraints:** None.
**Dependencies:** [REQ-UPLOAD-001](#req-upload-001-file-picker-upload)

---

### REQ-UPLOAD-003: Persistent upload queue

**Status:** Implemented
**Actor:** User
**Intent:** Uploads queued while offline survive an app restart and resume on the next connectivity recovery.

**Acceptance criteria:**
- Queue persists to `shared_preferences` keyed by stable UUID (one entry per pending upload).
- App startup rehydrates the queue and surfaces pending uploads in the Upload Files card.
- A pending upload retains its source file path, target filename, MIME type, and retry count.
- Removing a queue entry from the UI deletes the corresponding `shared_preferences` key.

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-offline-queue-persistence)
**Dependencies:** [REQ-CONN-001](connectivity.md#req-conn-001-network-state-monitor)

---

### REQ-UPLOAD-004: Auto-retry on connectivity recovery

**Status:** Implemented
**Actor:** User
**Intent:** A queued upload retries automatically when the device reconnects, up to a bounded retry count.

**Acceptance criteria:**
- On connectivity recovery, the queue iterates pending uploads in FIFO order.
- Each retry attempt increments the retry count.
- After 3 failed retries the upload moves to a "manual retry" state requiring user action.
- A manual-retry upload can be retried by tapping its retry button or removed by swiping.

**Constraints:** [CON-REL-002](constraints.md#con-rel-002-retry-policy)
**Dependencies:** [REQ-UPLOAD-003](#req-upload-003-persistent-upload-queue), [REQ-CONN-001](connectivity.md#req-conn-001-network-state-monitor)

---

### REQ-UPLOAD-005: URL shortening

**Status:** Implemented
**Actor:** User
**Intent:** A user with a long Zipline URL can request a shortened form for the link displayed after upload.

**Acceptance criteria:**
- A "Shorten URL" toggle in settings enables shortening for subsequent uploads.
- When enabled, after each successful upload the app POSTs to `<URL>/api/user/urls` to mint a short URL.
- The shortened URL replaces the long URL in the Upload Files card.
- The "Copy" affordance copies whichever URL is currently displayed.

**Constraints:** None.
**Dependencies:** [REQ-UPLOAD-001](#req-upload-001-file-picker-upload)

---

### REQ-UPLOAD-006: Concurrent upload limit

**Status:** Implemented
**Actor:** User
**Intent:** Concurrent uploads are bounded to prevent saturating mobile network bandwidth.

**Acceptance criteria:**
- At most 3 uploads run concurrently; additional pending uploads wait in the queue.
- The limit is fixed; not user-configurable.
- A completed or failed upload releases its slot; the next queued upload starts immediately.
- The Upload Files card visually distinguishes active vs. pending rows.

**Constraints:** None.
**Dependencies:** [REQ-UPLOAD-003](#req-upload-003-persistent-upload-queue)

---

_Verification: code-only (no automated coverage)._
