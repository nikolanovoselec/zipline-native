# Connectivity

Network state monitoring drives offline-queue activation and recovery.

**Actors:** User

---

### REQ-CONN-001: Network state monitor

**Status:** Implemented
**Actor:** User
**Intent:** The app continuously monitors network reachability and surfaces connectivity status to other services.

**Acceptance criteria:**
- `connectivity_plus` plugin's connectivity stream feeds a global `ConnectivityService`.
- State transitions (connected → disconnected → connected) emit events the upload queue subscribes to.
- A `ConnectivityService.isConnected` getter is available synchronously for blocking checks.
- The current state is exposed via `ChangeNotifier` for UI consumers.

**Constraints:** None.
**Dependencies:** None.

---

### REQ-CONN-002: Offline banner

**Status:** Implemented
**Actor:** User
**Intent:** When the device is offline, the user sees a persistent banner indicating the offline state and the queue's pending count.

**Acceptance criteria:**
- A red/amber banner overlays the top of the home screen when `isConnected` is false.
- The banner displays "Offline" and the count of pending uploads if any.
- The banner disappears on connectivity recovery within 1 second.
- The banner does not block input on the underlying screen.

**Constraints:** None.
**Dependencies:** [REQ-CONN-001](#req-conn-001-network-state-monitor)

---

### REQ-CONN-003: Pre-upload connectivity check

**Status:** Implemented
**Actor:** User
**Intent:** An upload attempted while offline enters the queue immediately rather than failing on network call.

**Acceptance criteria:**
- Before initiating an HTTP request, the upload service checks `ConnectivityService.isConnected`.
- If false, the upload skips the HTTP attempt and enqueues directly.
- If true and the HTTP request subsequently fails on network error, the upload also enqueues.
- The Upload Files card row reflects "queued (offline)" vs. "queued (retry)" distinctly.

**Constraints:** None.
**Dependencies:** [REQ-CONN-001](#req-conn-001-network-state-monitor), [REQ-UPLOAD-003](upload.md#req-upload-003-persistent-upload-queue)

---

_Verification: code-only (no automated coverage)._
