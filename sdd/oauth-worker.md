# OAuth Worker

The Cloudflare Worker brokering OAuth/OIDC callbacks between Zipline and the app.

**Actors:** Worker, User, Zipline Server

---

### REQ-OAUTH-001: Callback exchange

**Status:** Implemented
**Actor:** Worker, Zipline Server
**Intent:** The Worker receives the OAuth callback from Zipline, exchanges the authorization code for a session cookie, and forwards the session to the app via deep-link.

**Acceptance criteria:**
- Worker `fetch` handler accepts GET requests with `code` and `state` query parameters.
- Worker calls `<ZIPLINE_URL>/api/auth/oauth/oidc?code=...&state=...` with `redirect: manual` to capture the Set-Cookie header.
- Worker extracts the session cookie from the Zipline response headers.
- Worker responds with HTTP 302 redirecting to `zipline://oauth-callback?session=<cookie>`.

**Constraints:** [CON-TECH-003](constraints.md#con-tech-003-cloudflare-workers-runtime), [CON-SEC-002](constraints.md#con-sec-002-worker-validates-state-parameter)
**Dependencies:** None.

---

### REQ-OAUTH-002: State parameter validation

**Status:** Implemented
**Actor:** Worker
**Intent:** The Worker rejects OAuth callbacks missing the `state` parameter to mitigate CSRF in the callback exchange.

**Acceptance criteria:**
- Missing or empty `state` query parameter returns HTTP 400 with body `{"error":"missing_state"}`.
- The Worker does NOT contact Zipline when state is missing.
- The Worker does NOT log the `code` parameter when state is missing (the code is unusable without state).

**Constraints:** [CON-SEC-002](constraints.md#con-sec-002-worker-validates-state-parameter)
**Dependencies:** [REQ-OAUTH-001](#req-oauth-001-callback-exchange)

---

### REQ-OAUTH-003: Cookie redaction in logs

**Status:** Implemented
**Actor:** Worker
**Intent:** Session cookies are redacted from Worker logs to avoid leaking credentials in observability tooling.

**Acceptance criteria:**
- When logging the Zipline response headers, `set-cookie` values are replaced with `[redacted for security]`.
- The redaction happens before `console.log` is called, not after.
- Other headers are logged verbatim for debugging.

**Constraints:** None.
**Dependencies:** [REQ-OAUTH-001](#req-oauth-001-callback-exchange)

---

### REQ-OAUTH-004: Configurable Zipline URL

**Status:** Implemented
**Actor:** Worker
**Intent:** The Worker reads its target Zipline instance URL from configuration so a single Worker deployment can serve one instance per deploy.

**Acceptance criteria:**
- The Worker reads `env.ZIPLINE_URL` at request time.
- If `env.ZIPLINE_URL` is unset, the Worker falls back to a configured default and logs a warning.
- The URL is used as the prefix for the `/api/auth/oauth/oidc` exchange URL.

**Constraints:** None.
**Dependencies:** [REQ-OAUTH-001](#req-oauth-001-callback-exchange)

---

_Verification: code-only (no automated coverage)._
