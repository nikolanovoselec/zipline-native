# Connectivity

This domain covers network-state tracking and user-visible offline feedback.

### REQ-CONN-001: Track network availability

**Intent:** The app maintains a reactive connection state so screens can respond when the device is offline.

**Applies To:** User

**Acceptance Criteria:**

1. The connectivity service checks current connectivity during initialization. <!-- @impl: lib/services/connectivity_service.dart::_initConnectivity -->
2. The connectivity service subscribes to connectivity changes. <!-- @impl: lib/services/connectivity_service.dart::onConnectivityChanged -->
3. Connectivity updates set the connected flag based on the latest result. <!-- @impl: lib/services/connectivity_service.dart::_updateConnectionStatus -->
4. Connectivity updates notify listeners after state changes. <!-- @impl: lib/services/connectivity_service.dart::notifyListeners -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-BOOT-003](app-bootstrap.md#req-boot-003-render-global-shell-overlays)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-CONN-002: Surface offline state in the app shell

**Intent:** The user can see when network actions may fail because the device is currently offline.

**Applies To:** User

**Acceptance Criteria:**

1. The app shell consumes the connectivity service from provider state. <!-- @impl: lib/main.dart::Consumer -->
2. The app shell renders an offline banner when connectivity reports disconnected state. <!-- @impl: lib/main.dart::isConnected -->
3. The connectivity service cancels its subscription when disposed. <!-- @impl: lib/services/connectivity_service.dart::dispose -->

**Constraints:** [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P2

**Dependencies:** [REQ-CONN-001](#req-conn-001-track-network-availability)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
