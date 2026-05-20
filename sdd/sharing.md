# Sharing

Android intent receiver. Files from any app's share-sheet flow into the upload pipeline.

**Actors:** User

---

### REQ-SHARE-001: Share-sheet intent receiver

**Status:** Implemented
**Actor:** User
**Intent:** A user sharing a file from any Android app selects "Zipline" in the share-sheet and the app receives the file and enqueues it for upload.

**Acceptance criteria:**
- `AndroidManifest.xml` declares `<intent-filter>` for `ACTION_SEND` with MIME `*/*`.
- `AndroidManifest.xml` declares `<intent-filter>` for `ACTION_SEND_MULTIPLE` for batch shares.
- `share_plus` plugin's `getInitialMedia()` and `getMediaStream()` deliver the shared files to the Dart side.
- Each received file is enqueued via the upload queue with the same code path as in-app file-picker uploads.
- Cold-start vs. warm-start: both paths converge on the same enqueue function.

**Constraints:** None.
**Dependencies:** [REQ-UPLOAD-003](upload.md#req-upload-003-persistent-upload-queue)

---

### REQ-SHARE-002: Batch share

**Status:** Implemented
**Actor:** User
**Intent:** A user sharing multiple files at once sees all files appear in the Upload Files card as a single batch, not as separate cards.

**Acceptance criteria:**
- `ACTION_SEND_MULTIPLE` intents deliver the full file list before the first upload starts.
- All files appear as rows in the same Upload Files card.
- Each row reports its own per-file progress.
- A failed file in a batch does not block other files in the batch from completing.

**Constraints:** None.
**Dependencies:** [REQ-SHARE-001](#req-share-001-share-sheet-intent-receiver), [REQ-UPLOAD-002](upload.md#req-upload-002-inline-progress-ui)

---

### REQ-SHARE-003: Pre-share authentication gate

**Status:** Implemented
**Actor:** User
**Intent:** A user sharing to Zipline while logged out is shown the login screen first; on successful login the original shared files resume to the upload queue.

**Acceptance criteria:**
- An incoming share intent received while no session is active routes through the login screen.
- The pending shared files are held in memory until login succeeds.
- On successful login the held files are enqueued.
- On user abandonment (back-navigation from login) the held files are discarded.

**Constraints:** None.
**Dependencies:** [REQ-AUTH-001](auth.md#req-auth-001-usernamepassword-login), [REQ-SHARE-001](#req-share-001-share-sheet-intent-receiver)

---

_Verification: code-only (no automated coverage)._
