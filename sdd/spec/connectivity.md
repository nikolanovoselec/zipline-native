# Connectivity

Reactive network-state stream so the UI can disable network actions when offline and resume them when connectivity returns.

## REQ-CONN-001: Network state stream broadcast to widget tree

**Status:** Implemented
**Intent:** The app must know in real time whether it has network connectivity so the upload UI can refuse to start work when offline and the user is not misled by spinners.
**Acceptance Criteria:**
- `ConnectivityService` is a `ChangeNotifier` that wraps `connectivity_plus`'s `Connectivity` and subscribes to `onConnectivityChanged`. <!-- @impl: lib/services/connectivity_service.dart::ConnectivityService -->
- `_updateConnectionStatus(results)` sets `_isConnected = (first != ConnectivityResult.none)` and notifies listeners. <!-- @impl: lib/services/connectivity_service.dart::_updateConnectionStatus -->
- The service is registered in `service_locator.dart` and provided to the widget tree via `ChangeNotifierProvider.value` from `main()`. <!-- @impl: lib/main.dart::main -->
- The service cancels its stream subscription in `dispose()`. <!-- @impl: lib/services/connectivity_service.dart::dispose -->

**Constraints:** None.
**Dependencies:** [REQ-BOOT-001](app-bootstrap.md#req-boot-001-wire-dependency-injection-on-app-start).

_Verification: code-only (no automated coverage)._
