# Troubleshooting

Symptom → Cause → Fix recipes.

**Audience:** Developers and users debugging a broken install

## Upload appears stuck at 0%

**Cause:** Pre-upload connectivity check ([REQ-CONN-003](../sdd/connectivity.md#req-conn-003-pre-upload-connectivity-check)) detected offline and enqueued without attempting HTTP. The progress bar shows 0% because no transfer started.

**Fix:** Check the offline banner. If present, wait for connectivity recovery — the queue will auto-retry. If banner absent and progress still 0%, open the Debug screen and check the activity log for the upload event; report a bug with the log.

## "Invalid credentials" on a known-good password

**Cause:** Wrong Zipline instance URL — login is hitting the wrong server.

**Fix:** Verify the URL in Settings matches the user's Zipline deployment. The URL must include the scheme (`https://`) and no trailing slash.

## OAuth login lands on an error page

**Cause 1:** Worker received the callback but `state` was missing — returns 400 per [REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation).

**Cause 2:** Worker exchange with Zipline returned non-2xx — currently produces an undefined session per [TRIAGE-002](../sdd/init-triage.md#triage-002-worker-handles-zipline-non-2xx-exchange-response).

**Fix (Cause 1):** Verify the OIDC client config at Zipline sets a `state` parameter in the auth request. If the IdP strips state, the app's OAuth flow is broken for that IdP.

**Fix (Cause 2):** Check Worker logs (`wrangler tail`) for the exchange status. A 401/403 from Zipline usually means the OAuth client ID/secret in Zipline's config doesn't match what the IdP sent.

## Biometric unlock option missing on a device with fingerprint

**Cause:** `local_auth.canCheckBiometrics` is checked only at app start (TRIAGE-003). If the user enrolled the fingerprint mid-session, the check is stale.

**Fix:** Restart the app. The next launch will re-check biometric availability.

## Shared file from another app doesn't appear in upload queue

**Cause 1:** `AndroidManifest.xml` `<intent-filter>` mismatch — the source app's MIME type isn't covered.

**Cause 2:** Pre-share auth gate ([REQ-SHARE-003](../sdd/sharing.md#req-share-003-pre-share-authentication-gate)) held the file pending login; user abandoned the login screen.

**Fix (Cause 1):** Check `android/app/src/main/AndroidManifest.xml` covers both `ACTION_SEND` (single) and `ACTION_SEND_MULTIPLE` (batch) with MIME `*/*`.

**Fix (Cause 2):** Log in. The next share-sheet flow will work.

## Upload queue not persisting across restart

**Cause:** `shared_preferences` not flushed — uncommon but possible on force-kill.

**Fix:** Avoid force-killing the app; tap upload progress to await flush. If reproducible, file a bug — this would violate [REQ-UPLOAD-003](../sdd/upload.md#req-upload-003-persistent-upload-queue).

## App link `zipline://` not opening the app

**Cause:** Another app has claimed the `zipline://` scheme on the device.

**Fix:** Uninstall the conflicting app, OR re-register the scheme via Android's intent settings.

## URL shortening produces a server error

**Cause:** Zipline instance does not have the URL-shortener feature enabled, OR the user lacks permission.

**Fix:** Disable URL shortening in Settings, OR check Zipline instance admin config to enable the feature.

## Related Documentation

- [Architecture](architecture.md) — Where each subsystem lives
- [Security](security.md) — Auth flow and known security gaps
