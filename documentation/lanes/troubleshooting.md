# Troubleshooting

**Audience:** Users, Developers, Operators

Symptom → cause → fix recipes sourced from README guidance, issue history, and current source.

---

## Contents

- [Sign-in settings button does not open configuration](#sign-in-settings-button-does-not-open-configuration)
- [Shared file has no original filename](#shared-file-has-no-original-filename)
- [Browser sign-in returns to browser but not app](#browser-sign-in-returns-to-browser-but-not-app)
- [Short-link creation fails on one server version](#short-link-creation-fails-on-one-server-version)
- [Remote protection action appears to succeed but item is unchanged](#remote-protection-action-appears-to-succeed-but-item-is-unchanged)
- [Upload queue appears stuck](#upload-queue-appears-stuck)
- [Related Documentation](#related-documentation)

## Sign-in settings button does not open configuration

**Symptom:** User cannot configure the server from the sign-in surface.

**Cause:** Historical issue #1 reported a dead settings button on the login screen. Current source uses `SimpleLoginScreen` with an explicit settings navigation path. <!-- @impl: lib/screens/simple_login_screen.dart::SettingsScreen -->

**Fix:** Confirm the app is running the current sign-in surface. If the legacy `LoginScreen` appears, resolve TRIAGE-001 and remove or archive the old file.

**Implements:** [REQ-SET-001](../../sdd/spec/settings.md#req-set-001-save-server-and-access-settings)

---

## Shared file has no original filename

**Symptom:** A shared content URI uploads with a generated filename.

**Cause:** Some platform providers do not expose a display name through the content resolver. <!-- @impl: android/app/src/main/kotlin/com/example/zipline_native_app/MainActivity.kt::getContentUriFileName -->

**Fix:** The app falls back to extension inference and generated names. Improve provider-specific naming only after adding source-anchored tests.

**Implements:** [REQ-SHARE-003](../../sdd/spec/share-intake.md#req-share-003-copy-shared-content-into-app-storage)

---

## Browser sign-in returns to browser but not app

**Symptom:** External sign-in finishes but the app does not receive the session.

**Cause:** The worker route, app callback scheme, package identifier, or fallback intent URL may be out of sync. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::intentUrl -->

**Fix:** Verify the worker route config, app build-time redirect URL, Android intent filter, and package identifier together. If the package identifier changes, follow TRIAGE-005.

**Implements:** [REQ-BRIDGE-002](../../sdd/spec/browser-sign-in.md#req-bridge-002-complete-sign-in-from-an-app-callback)

---

## Short-link creation fails on one server version

**Symptom:** Link shortening returns an error even though the user is signed in.

**Cause:** The service contains multiple compatibility request shapes because server responses may differ. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

**Fix:** Use diagnostics to inspect the error response, then resolve TRIAGE-002 with a minimum supported server version and remove or document the unused fallback paths.

**Implements:** [REQ-LINK-001](../../sdd/spec/link-shortening.md#req-link-001-create-short-links-from-user-input)

---

## Remote protection action appears to succeed but item is unchanged

**Symptom:** User requests protection on a recent item and the server item remains unchanged.

**Cause:** File and link protection endpoints are best-effort and not fully confirmed for every target server. <!-- @impl: lib/services/file_upload_service.dart::setFilePassword -->

**Fix:** Resolve TRIAGE-003 by confirming supported endpoints and surfacing failures to the user, or remove the unsupported affordance.

**Implements:** [REQ-REMOTE-003](../../sdd/spec/remote-item-actions.md#req-remote-003-attempt-protection-updates-for-recent-items)

---

## Upload queue appears stuck

**Symptom:** The queue shows pending or uploading tasks for longer than expected.

**Cause:** Queue processing waits for active tasks to finish, retries recoverable failures, and may hold paused tasks. <!-- @impl: lib/services/upload_queue_service.dart::_processQueue -->

**Fix:** Use the queue details controls to pause, resume, cancel, or retry. Enable diagnostics before reproducing if source-level debugging is needed.

**Implements:** [REQ-QUEUE-002](../../sdd/spec/upload-queue.md#req-queue-002-process-queued-uploads-with-user-controls)

---

## Related Documentation

- [Observability](observability.md) — Diagnostic export flow
- [Configuration](configuration.md) — Runtime configuration
- [API Reference](api-reference.md) — Worker and upstream route contracts
