<!-- doc-discipline: threat model, auth flow, cookie/header policies. Per-endpoint auth lives in api-reference.md — link instead. -->

# Security

**Audience:** Developers, Operators

Threat model, secret-handling rules, deep-link hardening, and the cookie-masking invariant on the OAuth Worker.

---

## Trust Model

| Principal | Trusted to | Not trusted to |
|---|---|---|
| **User device** | Hold one Zipline session at a time; surface biometric prompt accurately | Resist root or hooking; the app does no root detection |
| **Zipline server** | Issue session cookies, enforce auth on its own API | Validate `state` parameter for the OAuth flow (the app does that on-device) |
| **OAuth provider** | Authenticate the user; redirect back via `redirect_uri` with `code`+`state` | Maintain a session beyond the device |
| **Cloudflare Worker** | Exchange OAuth code with Zipline, never log the session cookie raw, redirect via `zipline://` | Persist any user state — the Worker is stateless |

## Secret Handling

**Implements:** [REQ-AUTH-001](../../sdd/spec/authentication.md#req-auth-001-usernamepassword-login-captures-and-stores-session-cookie), [REQ-AUTH-003](../../sdd/spec/authentication.md#req-auth-003-cloudflare-access-service-token-forwarding), [REQ-OAUTH-002](../../sdd/spec/oauth.md#req-oauth-002-session-cookie-storage-after-callback)

- Session cookies, passwords, OAuth tokens, and Cloudflare Access secrets are stored exclusively in `FlutterSecureStorage` backed by `EncryptedSharedPreferences`. <!-- @impl: lib/services/auth_service.dart::_secureStorage -->
- A migration runs on first read of each sensitive key to move any legacy plaintext value from `SharedPreferences` into secure storage; the plaintext copy is then deleted. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded -->
- The biometric "shortcut token" is similarly stored secured under `biometric_token`. <!-- @impl: lib/services/biometric_service.dart::enableBiometric -->
- The Worker uses `wrangler secret put` for `CF_ACCESS_CLIENT_ID` / `CF_ACCESS_CLIENT_SECRET`; these never appear in `wrangler.toml` (and that file is gitignored regardless).

## OAuth Worker Cookie Masking Invariant

**Implements:** [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange)

The Cloudflare Worker MUST NOT render the raw `zipline_session` cookie value into the HTML page it returns. The cookie is base64-encoded and embedded in a `zipline://oauth-callback?cookie=<base64>` URL that the device's deep-link handler decodes. The Worker's structured logs also redact the raw value (`'[redacted for security]'`). <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->

This invariant is asserted in CI via `cloudflare-oauth-redirect/tests/worker.test.mjs`: the test produces an HTML response from `redirectToApp(true, cookie, null)` and asserts both that the raw cookie is absent AND that the base64 form is present. <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::redirectToApp masks session cookie in HTML output -->

## Deep-Link Hardening

**Implements:** [REQ-OAUTH-002](../../sdd/spec/oauth.md#req-oauth-002-session-cookie-storage-after-callback), [REQ-OAUTH-006](../../sdd/spec/oauth.md#req-oauth-006-intent-url-fallback-for-unreliable-schemes)

- `OAuthService` validates the `state` query parameter against the value stored before the browser was launched; mismatches abort the flow. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
- The Worker emits both a `zipline://` redirect AND an Android `intent://` URL with an explicit `package=com.example.zipline_native_app` so a competing app cannot claim the scheme silently. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->
- A manual "Open in app" button gives the user a recovery path if both auto-redirects fail.

## Cloudflare Access

The app forwards `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers on every request when the user has configured them in settings, so the Zipline server (which may sit behind Access) does not return a `403`. The same secrets can be configured on the Worker so it can traverse Access during code exchange. <!-- @impl: lib/services/auth_service.dart::getAuthHeaders -->

## Out of Scope

- Anti-tamper or root detection
- Certificate pinning (relies on platform trust store)
- Encrypted-on-device file cache for in-flight uploads (uploads go through the OS cache directory in plaintext)

---

## Related Documentation

- [API Reference](api-reference.md) — Per-endpoint auth on the Worker
- [Architecture](architecture.md) — OAuth lifecycle in full
- [Configuration](configuration.md) — Where each secret lives
- [Decisions](../decisions/README.md) — AD-005 (server-side code exchange), AD-006 (Intent URL fallback)
