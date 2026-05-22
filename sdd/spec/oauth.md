# OAuth

OAuth/OIDC login through the user's Zipline server, brokered by a Cloudflare Worker that bridges HTTPS callbacks to the app's `zipline://` deep link.

## REQ-OAUTH-001: Initiate OAuth flow with Worker redirect URI

**Status:** Implemented
**Intent:** From the login screen, the user taps "Sign in with OAuth". The app asks Zipline for the OAuth provider's authorization URL, substitutes the Cloudflare Worker URL as the `redirect_uri`, and launches the system browser.
**Acceptance Criteria:**
- `OAuthService.loginWithOAuth(ziplineUrl, cfClientId, cfClientSecret)` requests the OAuth URL from `<ziplineUrl>/api/auth/oauth` (forwarding `CF-Access-Client-*` headers when configured). <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
- The returned URL's `redirect_uri` query parameter is overwritten with the Worker URL: `BuildConfig.oauthRedirectUrl` if set at build time, otherwise `<zipline-host>/app/oauth-redirect`. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
- The substituted URL is opened via `url_launcher`'s `launchUrl` with `LaunchMode.externalApplication` so the user sees their default browser, not an in-app webview. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->

**Constraints:** None.
**Dependencies:** [REQ-AUTH-003](authentication.md#req-auth-003-cloudflare-access-service-token-forwarding), [REQ-WORKER-001](worker-bridge-via-architecture-doc).

## REQ-OAUTH-002: Session cookie storage after callback

**Status:** Implemented
**Intent:** When the OAuth Worker redirects the device back to `zipline://oauth-callback?...`, the app extracts the base64-encoded session cookie, decodes it, and stores it for use on subsequent API calls.
**Acceptance Criteria:**
- `OAuthService` listens to `AppLinks().uriLinkStream` for incoming `zipline://oauth-callback` URIs. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
- When the callback URI contains `cookie` (base64-encoded), the value is decoded and stored in `FlutterSecureStorage` under the OAuth session key. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->
- The state parameter is verified against the value stored before the browser was launched; mismatches abort the flow and log a warning. <!-- @impl: lib/services/oauth_service.dart::oAuthLogin -->

**Constraints:** [CON-SEC-001](constraints.md#con-sec-001-all-secrets-encrypted-at-rest), [CON-SEC-002](constraints.md#con-sec-002-oauth-worker-masks-raw-session-cookies-in-html).
**Dependencies:** None.

## REQ-OAUTH-003: Clear OAuth session on logout

**Status:** Implemented
**Intent:** When the user logs out, the OAuth session cookie must be removed from secure storage so a subsequent `isAuthenticated()` check returns false.
**Acceptance Criteria:**
- `OAuthService.clearSession()` deletes the OAuth session cookie key from `FlutterSecureStorage`. <!-- @impl: lib/services/oauth_service.dart::clearSession -->
- The method is called from `AuthService.logout()` and `AuthService.clearAllCredentials()`. <!-- @impl: lib/services/auth_service.dart::logout -->

**Constraints:** None.
**Dependencies:** [REQ-AUTH-004](authentication.md#req-auth-004-logout-clears-every-credential-surface).

## REQ-OAUTH-004: Cold-start callback recovery

**Status:** Implemented
**Intent:** If the device kills the app between browser launch and OAuth-callback receipt, the app must still recognise the inbound deep link on next launch and complete the flow.
**Acceptance Criteria:**
- `OAuthService.checkInitialOAuthCallback()` calls `AppLinks().getInitialLink()` once at startup to retrieve any pending OAuth deep link delivered to a killed app. <!-- @impl: lib/services/oauth_service.dart::checkInitialOAuthCallback -->
- When the initial link contains `oauth-callback`, the standard callback handler runs. <!-- @impl: lib/services/oauth_service.dart::checkInitialOAuthCallback -->

**Constraints:** None.
**Dependencies:** [REQ-OAUTH-002](#req-oauth-002-session-cookie-storage-after-callback).

## REQ-OAUTH-005: Cloudflare Worker server-side code exchange

**Status:** Implemented
**Intent:** The Worker, not the app, exchanges the OAuth authorization code with the Zipline server. The Worker then base64-encodes the session cookie into the deep-link payload, so the cookie is never visible in cleartext HTML or in a browser address bar.
**Acceptance Criteria:**
- The Worker's `fetch` handler reads `code` and `state` from the inbound URL's query string and POSTs them to `<env.ZIPLINE_URL>/api/auth/oauth/callback`. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->
- The Worker extracts `zipline_session=…` from the exchange response's `Set-Cookie` header. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->
- The Worker delegates to `redirectToApp(success, sessionCookie, error)` which base64-encodes the cookie and embeds it in an HTML payload that auto-redirects to `zipline://oauth-callback?cookie=<base64>`. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->
- The raw cookie value never appears in the rendered HTML; a regression test asserts this property. <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::redirectToApp masks session cookie in HTML output -->

**Constraints:** [CON-SEC-002](constraints.md#con-sec-002-oauth-worker-masks-raw-session-cookies-in-html).
**Dependencies:** None.

## REQ-OAUTH-006: Intent URL fallback for unreliable schemes

**Status:** Implemented
**Intent:** On modern Android the `zipline://` scheme can be intercepted by other apps or silently dropped. The Worker provides an `intent://` URL with the explicit package name as a fallback, plus a manual "Open app" button if both auto-redirects fail.
**Acceptance Criteria:**
- The Worker's HTML payload embeds a primary `zipline://oauth-callback?cookie=…` link and a secondary `intent://oauth-callback#Intent;package=com.example.zipline_native_app;scheme=zipline;end` link. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->
- A visible "Open in app" button targets the deep link so the user can recover when the auto-redirect is silently dropped. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->

**Constraints:** None.
**Dependencies:** [REQ-OAUTH-005](#req-oauth-005-cloudflare-worker-server-side-code-exchange).
**Notes:** See [TRIAGE-005](.init-triage.md#triage-005-package-name-is-the-flutter-template-default) — the package name in the Intent URL is hardcoded and must update in lockstep with any `applicationId` rename.

_Verification: code-only (no automated coverage). Worker's `redirectToApp` masking property is covered by `cloudflare-oauth-redirect/tests/worker.test.mjs`._
