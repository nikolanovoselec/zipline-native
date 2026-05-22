<!-- doc-discipline: symptom → cause → fix recipes only. No architecture, no env vars, no deploy steps. -->

# Troubleshooting

**Audience:** Operators, Users

Symptom → cause → fix recipes for the failure modes most likely to bite a real install.

---

## Symptom: OAuth login completes in browser but app never returns

**Cause:** The `zipline://` deep link is being claimed by another app, or the OAuth Worker's `redirect_uri` does not match the OAuth provider's registered URI.

**Fix:**
1. Confirm the OAuth provider's registered `redirect_uri` matches the Worker's hostname + `/app/oauth-redirect` exactly.
2. In the Worker's browser fallback page, tap the "Open in app" button. If that opens the app correctly, the auto-redirect is being intercepted — the `intent://` URL fallback exists for this case. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->
3. If the manual button also fails, another app has claimed `zipline://` — disable or uninstall the conflicting app.

## Symptom: Worker logs show successful exchange but app shows "Login failed"

**Cause:** The `state` parameter the Worker forwards does not match what `OAuthService` stored before launching the browser. This usually means a stale OAuth attempt is lingering.

**Fix:**
1. Force-close the app, reopen, and retry the OAuth flow from scratch.
2. If the failure recurs, enable Debug Logs in Settings and inspect the `OAUTH` category for the `Invalid state parameter` warning. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->

## Symptom: Share-sheet upload "stuck" at 0%

**Cause:** Either no Zipline server is configured, the session cookie is stale, or connectivity is offline.

**Fix:**
1. Open Settings; confirm the Zipline URL is set and the user is logged in.
2. Try a normal upload from the home screen; if that also fails with `401`, log out and back in.
3. Check the Connectivity overlay (app reads `connectivity_plus`); ensure the device is online. <!-- @impl: lib/services/connectivity_service.dart::ConnectivityService -->

## Symptom: Biometric prompt does not appear after enabling

**Cause:** The device has no enrolled biometric (no fingerprint, no face), or `LocalAuthentication.isDeviceSupported` returns false.

**Fix:**
1. Enroll a fingerprint or face from Android Settings.
2. In the app, disable and re-enable the biometric toggle; the enable path calls `authenticate(...)` to verify capability. <!-- @impl: lib/services/biometric_service.dart::authenticate -->
3. If biometric continues to be unavailable, the toggle should refuse to enable; see the `AUTH` debug logs for the underlying reason.

## Symptom: "The app won't install" (per README)

**Cause:** Android blocks APK installs from unknown sources by default.

**Fix:**
1. Enable "Install unknown apps" for your file manager or browser in Android Settings.
2. Confirm the APK is signed with a real keystore and not the debug certificate (release builds require the release keystore — see [Deployment](deployment.md)).

## Symptom: Uploaded file URL shows the wrong file type

**Cause:** Android's share intent delivered a `content://` URI without an extension, and `IntentService._getFileExtensionFromUri` fell back to `.tmp` (or a wrong guess for an exotic format).

**Fix:**
1. Note which source app produced the share. Add a case to `IntentService._getFileExtensionFromUri` for the source's URI shape if it is consistent across that app. <!-- @impl: lib/services/intent_service.dart::_getFileExtensionFromUri -->
2. As a workaround, share the file via a file manager that includes the extension in the URI.

## Symptom: "Can you add feature X?" (per README)

**Cause:** This app is intentionally narrow — share-sheet upload, OAuth, biometric. Feature requests outside that scope are explicitly out of scope.

**Fix:** Open a GitHub issue describing the use case; if it fits the scope, it will be considered.

---

## Related Documentation

- [Observability](observability.md) — How to capture and export debug logs
- [Security](security.md) — Trust model that constrains the fixes above
