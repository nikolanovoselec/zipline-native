# Share Intake

This domain covers receiving shared files and text from the host platform and converting them into app-owned inputs.

### REQ-SHARE-001: Capture platform share intents

**Intent:** The host platform can launch or wake the app with shared files or text, and the app preserves that payload until the app layer reads it.

**Applies To:** User

**Acceptance Criteria:**

1. The host activity handles single shared file intents. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::ACTION_SEND -->
2. The host activity handles multiple shared file intents. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::ACTION_SEND_MULTIPLE -->
3. The host activity handles shared text separately from file streams. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::pendingSharedText -->
4. New intents are processed without recreating the app process. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::onNewIntent -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow), [CON-PLATFORM-001](constraints.md#con-platform-001-keep-bridge-identifiers-synchronized)

**Priority:** P0

**Dependencies:** [REQ-BOOT-001](app-bootstrap.md#req-boot-001-register-app-services-before-ui-startup)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SHARE-002: Expose pending shared content to the app

**Intent:** App code can retrieve pending shared files or text exactly once so the same payload is not processed repeatedly.

**Applies To:** User

**Acceptance Criteria:**

1. The host returns pending shared file references and clears them after retrieval. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::getSharedFiles -->
2. The host returns pending shared text and clears it after retrieval. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::getSharedText -->
3. The app intent service requests pending shared files from the host bridge. <!-- @impl: lib/services/intent_service.dart::getSharedFiles -->
4. The app intent service requests pending shared text from the host bridge. <!-- @impl: lib/services/intent_service.dart::getSharedText -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-SHARE-001](#req-share-001-capture-platform-share-intents)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SHARE-003: Copy shared content into app storage

**Intent:** Shared content references that cannot be read directly are copied into app-owned storage before upload.

**Applies To:** User

**Acceptance Criteria:**

1. The app intent service detects content references that require copying. <!-- @impl: lib/services/intent_service.dart::startsWith -->
2. The app intent service asks the host for the original display name when available. <!-- @impl: lib/services/intent_service.dart::getContentUriFileName -->
3. The app intent service creates a generated filename when the original name is unavailable. <!-- @impl: lib/services/intent_service.dart::_getFileExtensionFromUri -->
4. The host copies the content stream into the target app-owned file path. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::copyContentUriFile -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-SHARE-002](#req-share-002-expose-pending-shared-content-to-the-app)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-SHARE-004: Process shared payloads on the home surface

**Intent:** Shared files and links are acted on automatically after the main surface opens.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface checks for shared content during initialization. <!-- @impl: lib/screens/home_screen.dart::_checkForSharedContent -->
2. Shared files start the file upload path. <!-- @impl: lib/screens/home_screen.dart::_uploadFiles -->
3. Shared text that looks like a link is normalized before link shortening. <!-- @impl: lib/screens/home_screen.dart::_normalizeUrl -->
4. Shared text that normalizes to a link starts the link-shortening path. <!-- @impl: lib/screens/home_screen.dart::_shortenUrl -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P0

**Dependencies:** [REQ-FILE-002](file-upload.md#req-file-002-upload-selected-files-with-progress), [REQ-LINK-001](link-shortening.md#req-link-001-create-short-links-from-user-input)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
