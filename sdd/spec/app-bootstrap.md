# App Bootstrap

Splash screen, dependency-injection setup, auth check, optional biometric prompt, and home/login routing on app launch.

## REQ-BOOT-001: Wire dependency injection on app start

**Status:** Implemented
**Intent:** Every service that downstream code resolves via `get_it` must be registered before the first widget builds, so that screen `initState` calls can fetch services without race conditions.
**Acceptance Criteria:**
- `main()` calls `setupServiceLocator()` before `runApp`. <!-- @impl: lib/main.dart::main -->
- `setupServiceLocator()` registers `DebugService`, `ActivityService`, `ConnectivityService`, `UploadQueueService` as singletons; `AuthService`, `OAuthService`, `BiometricService`, `IntentService` as lazy singletons; `FileUploadService` and `SharingService` as factories. <!-- @impl: lib/core/service_locator.dart::setupServiceLocator -->
- After registration, `main()` calls `locator.sharing.initialize()` to wire the sharing service callbacks. <!-- @impl: lib/main.dart::main -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest) (services holding secrets must use secure storage).
**Dependencies:** None.

## REQ-BOOT-002: Wrap the widget tree in `AppState` and `ThemeProvider`

**Status:** Implemented
**Intent:** The root widget exposes `AppState` and `ThemeProvider` through `MultiProvider` so any descendant can read auth state or theme mode without prop drilling.
**Acceptance Criteria:**
- The widget tree root is a `MultiProvider` with `AppState`, `ThemeProvider`, and the singleton `ConnectivityService` value as providers. <!-- @impl: lib/main.dart::main -->
- The root widget consumes `ThemeProvider` to select between `AppTheme.darkTheme`, `AppTheme.lightTheme`, and `ThemeMode.system`. <!-- @impl: lib/main.dart::ZiplineNativeApp -->

**Constraints:** None.
**Dependencies:** [REQ-THEME-001](theme-and-state.md#req-theme-001-theme-mode-persistence), [REQ-STATE-001](theme-and-state.md#req-state-001-global-appstate).

## REQ-BOOT-003: Splash routes to home or login based on auth state

**Status:** Implemented
**Intent:** On cold launch the user sees a brief branded splash and then lands on the home screen (if authenticated) or the login screen (if not), without ever seeing an unauthenticated home.
**Acceptance Criteria:**
- The home widget is `SplashScreen`, displayed during a 400ms decorative delay before any routing decision. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- `SplashScreen` calls `AuthService.isAuthenticated()`; on `true` it navigates to `HomeScreen` (or to biometric prompt first, see REQ-BOOT-004); on `false` it navigates to `SimpleLoginScreen`. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- Navigation uses `pushReplacement`, so the splash cannot be reached by pressing Back from the destination screen. <!-- @impl: lib/main.dart::_checkAuthStatus -->

**Constraints:** None.
**Dependencies:** [REQ-AUTH-002](authentication.md#req-auth-002-session-presence-check), [REQ-BIO-002](biometric.md#req-bio-002-prompt-on-resume-when-enabled).

## REQ-BOOT-004: Biometric gate before home

**Status:** Implemented
**Intent:** Users who have enabled biometric auth must satisfy the biometric prompt between "session is valid" and "home screen renders". A failed or cancelled biometric returns to login, not home.
**Acceptance Criteria:**
- After `isAuthenticated()` returns `true`, the splash checks `BiometricService.isBiometricEnabled()`. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- If enabled, the splash calls `BiometricService.authenticate(reason: 'Authenticate to access Zipline')` and only proceeds to `HomeScreen` on success. <!-- @impl: lib/main.dart::_checkAuthStatus -->
- A failed biometric pushes `SimpleLoginScreen` instead, not the home screen. <!-- @impl: lib/main.dart::_checkAuthStatus -->

**Constraints:** None.
**Dependencies:** [REQ-BIO-001](biometric.md#req-bio-001-enable-disable-biometric-from-settings), [REQ-BIO-002](biometric.md#req-bio-002-prompt-on-resume-when-enabled).

_Verification: code-only (no automated coverage)._
