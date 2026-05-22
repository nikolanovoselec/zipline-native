# Share Intent

Receiving Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intents from other apps, surfacing the shared files or text to Flutter via a `MethodChannel`.

## REQ-SHARE-001: Declare share intent filters in the Android manifest

**Status:** Implemented
**Intent:** The launcher activity must appear in Android's share sheet for any MIME type (so it can accept arbitrary file shares) and for `text/plain` (so it can accept shared URLs).
**Acceptance Criteria:**
- The manifest declares `<intent-filter>` for `android.intent.action.SEND` with `<data android:mimeType="*/*"/>`. <!-- @impl: android/app/src/main/AndroidManifest.xml::activity -->
- It declares a parallel filter for `android.intent.action.SEND_MULTIPLE`. <!-- @impl: android/app/src/main/AndroidManifest.xml::activity -->
- A separate `SEND` filter with `<data android:mimeType="text/plain"/>` ensures the activity shows when the source app shares a URL. <!-- @impl: android/app/src/main/AndroidManifest.xml::activity -->
- The activity declares `android:exported="true"` and `android:launchMode="singleTop"` so an existing instance receives new share intents via `onNewIntent`. <!-- @impl: android/app/src/main/AndroidManifest.xml::activity -->

**Constraints:** [CON-PLATFORM-001](constraints.md#con-platform-001-android-only-target).
**Dependencies:** None.

## REQ-SHARE-002: Native side caches incoming share payload

**Status:** Implemented
**Intent:** When Android delivers a share intent — either at app launch or while the app is foregrounded — the native side stores the URIs or text in memory until the Dart side asks for them via `MethodChannel`.
**Acceptance Criteria:**
- `MainActivity.handleIntent(intent)` switches on `intent.action`; `ACTION_SEND` with a `text/*` MIME stores `EXTRA_TEXT` to `pendingSharedText`. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::handleIntent -->
- `ACTION_SEND` with a non-text MIME stores a single-element list `[EXTRA_STREAM.toString()]` to `pendingSharedFiles`. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::handleIntent -->
- `ACTION_SEND_MULTIPLE` stores the full `EXTRA_STREAM` list mapped to URI strings. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::handleIntent -->
- `onNewIntent` also calls `handleIntent` so warm-launch shares are captured. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::onNewIntent -->

**Constraints:** None.
**Dependencies:** None.

## REQ-SHARE-003: MethodChannel bridge exposes shares to Flutter

**Status:** Implemented
**Intent:** Flutter code calls `IntentService.getSharedFiles()` / `getSharedText()` after a screen mounts. The native side returns the cached payload and clears it so a single share is consumed once.
**Acceptance Criteria:**
- The MethodChannel name is `com.example.zipline_native_app/intent`, configured on both sides. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::configureFlutterEngine -->
- The Dart side declares the channel identically in `IntentService.platform`. <!-- @impl: lib/services/intent_service.dart::IntentService -->
- `getSharedFiles` returns `pendingSharedFiles` and sets it to null on success. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::configureFlutterEngine -->
- `copyContentUriFile` copies a `content://` URI into the app's cache directory and returns the file path, enabling later upload to Zipline. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::copyContentUriFile -->

**Constraints:** None.
**Dependencies:** None.
**Notes:** See [TRIAGE-005](.init-triage.md#triage-005-package-name-is-the-flutter-template-default) — the MethodChannel namespace is bound to the template-default package name.

## REQ-SHARE-004: File-extension inference for Android content URIs

**Status:** Implemented
**Intent:** Android share intents often deliver `content://` URIs without file extensions. Uploads need the extension for MIME detection and for the visible file name on Zipline. `IntentService` infers the extension by inspecting the URI for MIME hints (`image%2Fjpeg`), known segments (`.png`), and a fallback table.
**Acceptance Criteria:**
- `_getFileExtensionFromUri(uri)` decodes URL-encoding and lowercases before pattern matching. <!-- @impl: lib/services/intent_service.dart::_getFileExtensionFromUri -->
- It recognises JPEG, PNG, GIF, BMP, TIFF, SVG, WebP, MP4, MKV, MOV, PDF, and falls back to `.tmp` when no signal is found. <!-- @impl: lib/services/intent_service.dart::_getFileExtensionFromUri -->
- Each detection branch logs the inferred extension via `DebugService.logIntent`. <!-- @impl: lib/services/intent_service.dart::_getFileExtensionFromUri -->

**Constraints:** None.
**Dependencies:** [REQ-LOG-001](debug-diagnostics.md#req-log-001-categorized-ring-buffer).

_Verification: code-only (no automated coverage)._
