<!-- doc-discipline: 600 lines soft cap, one-line table cells (≤50 words), no architecture rationale, no env var docs. -->

# API Reference

Endpoint contracts exposed by the OAuth Worker, plus Zipline upstream endpoints the app depends on.

**Audience:** Developers

The Zipline Native app is an HTTP client; it does not expose endpoints itself. This reference documents the Worker (which the app's OAuth path depends on) and the Zipline upstream contract the app relies on.

---

## OAuth Worker API

### GET /oauth-callback (and any path; the Worker handles all paths)

Receives the OAuth callback from a Zipline OIDC redirect, exchanges the code for a session cookie, redirects to the app's deep-link.

**Implements:** [REQ-OAUTH-001](../sdd/oauth-worker.md#req-oauth-001-callback-exchange)

**Authentication:** None (relies on the OAuth `state` parameter for CSRF mitigation, not on a session)

**Rate limit:** None (Cloudflare Worker default; per-instance rate limiting handled at CF dashboard)

**Query Parameters:**

| Parameter | Required | Format | Description |
|---|---|---|---|
| `code` | yes | string | OAuth authorization code issued by Zipline |
| `state` | yes | string | Opaque state parameter; the Worker validates non-empty but does not validate value |

**Response 302 (success):**

`Location: zipline://oauth-callback?session=<cookie>`

The Worker extracts the `Set-Cookie` header from the Zipline exchange response and includes the cookie value as the `session` query parameter in the redirect.

**Error responses:**

| Code | When | Body |
|---|---|---|
| 400 | `state` query parameter missing or empty | `{"error":"missing_state"}` |
| 500 | Internal error contacting Zipline (network failure) | `{"error":"internal"}` |

Per [TRIAGE-002](../sdd/init-triage.md#triage-002-worker-handles-zipline-non-2xx-exchange-response), the Worker's behaviour on a non-2xx Zipline exchange response is currently undefined; the triage entry proposes adding a 502 row here.

**Cache:** `Cache-Control: no-store` (OAuth callbacks must never be cached).

**Implementation:** `cloudflare-oauth-redirect/src/worker.js:1`

---

## Upstream Zipline API (consumed by the app)

These endpoints belong to Zipline, not Zipline Native. They are documented here because the app's behaviour depends on their contract.

### POST /api/auth/login

Username/password authentication.

**Implements:** [REQ-AUTH-001](../sdd/auth.md#req-auth-001-usernamepassword-login)

**Request body:**

```json
{
  "username": "alice",
  "password": "<plaintext>"
}
```

**Response 200:**

Sets `Cookie: zipline_session=<token>` via `Set-Cookie` header. Response body is the user record.

**Error responses:**

| Code | When | Body |
|---|---|---|
| 401 | Invalid credentials | `{"error":"unauthorized"}` |

**Implementation (client):** `lib/services/auth_service.dart`

### POST /api/upload

Upload a file to the user's Zipline instance.

**Implements:** [REQ-UPLOAD-001](../sdd/upload.md#req-upload-001-file-picker-upload)

**Authentication:** Required (session cookie)

**Request body:** `multipart/form-data` with the file as a single field. Headers include `Content-Type: <mime>` for the file part.

**Response 200:**

```json
{
  "files": [
    { "url": "https://<instance>/u/<id>", "name": "<original>" }
  ]
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| 401 | Session expired or missing | `{"error":"unauthorized"}` |
| 413 | File exceeds instance upload limit | `{"error":"too_large"}` |

**Cache:** `Cache-Control: no-store`

**Implementation (client):** `lib/services/file_upload_service.dart`

### POST /api/user/urls

Mint a shortened URL for a previously-uploaded file.

**Implements:** [REQ-UPLOAD-005](../sdd/upload.md#req-upload-005-url-shortening)

**Authentication:** Required (session cookie)

**Request body:**

```json
{
  "destination": "https://<instance>/u/<id>",
  "vanity": null
}
```

**Response 200:**

```json
{
  "url": "https://<instance>/s/<short>"
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| 401 | Session expired | `{"error":"unauthorized"}` |
| 409 | Vanity slug taken | `{"error":"slug_taken"}` |

**Implementation (client):** `lib/services/file_upload_service.dart`

### GET /api/auth/oauth/oidc

Zipline's OAuth code exchange endpoint. Called by the Worker, not by the app.

**Implements:** [REQ-OAUTH-001](../sdd/oauth-worker.md#req-oauth-001-callback-exchange)

**Authentication:** None (the OAuth code IS the credential)

**Query Parameters:**

| Parameter | Required | Format | Description |
|---|---|---|---|
| `code` | yes | string | OAuth authorization code |
| `state` | yes | string | State parameter |

**Response 302:**

Sets `Cookie: zipline_session=<token>` via `Set-Cookie` header. The Worker calls this with `redirect: manual` to capture the header before following the redirect.

**Error responses:**

| Code | When | Body |
|---|---|---|
| 400 | Invalid code or state mismatch | `{"error":"invalid_grant"}` |

**Implementation (consumer):** `cloudflare-oauth-redirect/src/worker.js:1`

---

## Related Documentation

- [Architecture](architecture.md) — Component overview, request lifecycles
- [Configuration](configuration.md) — Required env vars and secrets
- [Security](security.md) — Auth flow, CSRF mitigation, secret storage
