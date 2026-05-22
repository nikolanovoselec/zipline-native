<!-- doc-discipline: HTTP routes only; the only HTTP surface this project owns is the OAuth Worker. App-side calls to the Zipline server are consumed routes, not owned routes — they live in architecture.md as data-flow notes. -->

# API Reference

The only HTTP surface this project owns is the Cloudflare Worker bridge. The app consumes the Zipline server's API but does not define it; for the consumed shape see [`architecture.md`](architecture.md) data-flow.

**Audience:** Developers, Operators

---

## Conventions

| Concept | Value |
|---|---|
| Worker path | `/app/oauth-redirect` |
| Production host | Operator-chosen Cloudflare-fronted hostname |
| Auth | None at the Worker (the OAuth provider's `state` parameter is validated by `OAuthService` on the device, not by the Worker) |
| Cookie masking | Raw `zipline_session` is never rendered into HTML — always base64-encoded in the redirect payload <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp --> |

---

## `GET /app/oauth-redirect`

**Implements:** [REQ-OAUTH-005](../../sdd/spec/oauth.md#req-oauth-005-cloudflare-worker-server-side-code-exchange), [REQ-OAUTH-006](../../sdd/spec/oauth.md#req-oauth-006-intent-url-fallback-for-unreliable-schemes)

The browser lands here after the OAuth provider's `redirect_uri` redirect.

### Request

| Param | Source | Required | Description |
|---|---|---|---|
| `code` | query string | yes | Authorization code from the OAuth provider <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> |
| `state` | query string | yes | CSRF-style state token to be returned to the app for validation <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default --> |

### Behavior

1. Worker reads `code` + `state` from the query string. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->
2. Worker POSTs `{code, state}` to `<env.ZIPLINE_URL>/api/auth/oauth/callback`. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->
3. Worker extracts `zipline_session=<value>` from the response `Set-Cookie` header. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->
4. Worker invokes `redirectToApp(success, sessionCookie, error)` which base64-encodes the cookie and renders an HTML page with three redirect strategies. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::redirectToApp -->

### Response

| Case | Status | Body |
|---|---|---|
| Code+state both valid, Zipline exchange succeeded | `200` | HTML page that auto-redirects to `zipline://oauth-callback?cookie=<base64>` with `intent://...` fallback and a manual button |
| `code` or `state` missing | `200` | HTML error page (`Missing OAuth parameters`) |
| Zipline exchange returned non-2xx | `200` | HTML error page with provider-supplied reason if available |

The Worker always returns `200` and renders HTML so the browser stays on a friendly page; failures surface in the page body, not in the HTTP status.

### Redirect payload shape

```html
<!-- success -->
zipline://oauth-callback?cookie=<base64-encoded zipline_session value>

<!-- Android fallback -->
intent://oauth-callback?cookie=<base64-encoded zipline_session value>#Intent;package=com.example.zipline_native_app;scheme=zipline;end
```

The raw `zipline_session` cookie value never appears in the HTML or in `console.log` output; logs replace the cookie with `[redacted for security]`. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::default -->

### Regression coverage

The masking property is asserted in `cloudflare-oauth-redirect/tests/worker.test.mjs`: <!-- @impl: cloudflare-oauth-redirect/tests/worker.test.mjs::redirectToApp masks session cookie in HTML output -->

```js
const html = await response.text();
assert.ok(!html.includes(cookie));
assert.ok(html.includes(Buffer.from(cookie, 'utf8').toString('base64')));
```

---

## Related Documentation

- [Configuration](configuration.md) — Worker env vars (`ZIPLINE_URL`, secrets)
- [Architecture](../lanes/architecture.md) — Full OAuth lifecycle including app-side handling
- [Security](security.md) — Threat model for the OAuth bridge
