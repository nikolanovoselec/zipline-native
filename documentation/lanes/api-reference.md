<!-- doc-discipline: one-line table cells (≤50 words), no architecture rationale (lives in architecture.md), no env var docs (lives in configuration.md). -->

# API Reference

All public and internal API endpoints used by the app and worker.

**Audience:** Developers

---

## Public API

### GET /app/oauth-redirect

Browser callback route handled by the worker; receives sign-in callback parameters, exchanges them with the configured server, and returns an app-opening HTML response.

**Implements:** [REQ-BRIDGE-003](../../sdd/spec/browser-sign-in.md#req-bridge-003-return-sessions-through-the-bridge-page), [REQ-BRIDGE-004](../../sdd/spec/browser-sign-in.md#req-bridge-004-avoid-raw-session-exposure-in-bridge-markup)

**Authentication:** No caller authentication on the worker route; callback integrity depends on the upstream state value and server exchange.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| none | n/a | The route uses query parameters. |

**Request:**

```json
{
  "query": {
    "code": "authorization-code",
    "state": "opaque-state"
  }
}
```

**Response 200:**

```json
{
  "contentType": "text/html",
  "body": "app-opening page with encoded session or error callback"
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| 200 | Missing callback parameters | HTML page that opens the app with a failure callback |
| 200 | Server exchange fails | HTML page that opens the app with a failure callback |

**Cache:** `Cache-Control: no-cache, no-store, must-revalidate`

**Implementation:** `cloudflare-oauth-redirect/src/worker.js` <!-- @impl: cloudflare-oauth-redirect/src/worker.js::fetch -->

---

### POST /api/auth/login

Upstream server call used by direct credential sign-in; the app sends credentials and expects a session-bearing response.

**Implements:** [REQ-SESS-002](../../sdd/spec/server-session.md#req-sess-002-authenticate-with-direct-credentials)

**Authentication:** Credentials are supplied in the request body; optional access headers may also be supplied.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| none | n/a | The route uses request body fields. |

**Request:**

```json
{
  "username": "user",
  "password": "secret",
  "code": "optional-second-factor"
}
```

**Response 200:**

```json
{
  "headers": {
    "set-cookie": "zipline_session=..."
  }
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| non-200 | Authentication fails | Server-specific error body logged locally when diagnostics are enabled |

**Cache:** No client-side caching.

**Implementation:** `lib/services/auth_service.dart` <!-- @impl: lib/services/auth_service.dart::authenticateWithZipline -->

---

### POST /api/upload

Upstream server call used for file upload; the app sends multipart form data and reads the returned file link.

**Implements:** [REQ-FILE-002](../../sdd/spec/file-upload.md#req-file-002-upload-selected-files-with-progress)

**Authentication:** Requires session headers from the session service.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| none | n/a | The route uses multipart body fields. |

**Request:**

```json
{
  "multipart": {
    "file": "selected-file"
  }
}
```

**Response 200:**

```json
{
  "files": [
    { "id": "file-id", "url": "share-link" }
  ]
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| non-200 | Upload rejected | Server-specific error body converted into a failure result |

**Cache:** No client-side caching.

**Implementation:** `lib/services/file_upload_service.dart` <!-- @impl: lib/services/file_upload_service.dart::uploadFile -->

---

### POST /api/user/urls

Upstream server call used for short-link creation; compatibility fallbacks are tracked in the import triage queue.

**Implements:** [REQ-LINK-001](../../sdd/spec/link-shortening.md#req-link-001-create-short-links-from-user-input)

**Authentication:** Requires session headers from the session service.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| none | n/a | The route uses request body fields. |

**Request:**

```json
{
  "destination": "original-link",
  "vanity": "optional-custom-label"
}
```

**Response 200:**

```json
{
  "id": "url-id",
  "url": "short-link"
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| 400 | Unsupported request shape | The service tries compatibility fallback handling |
| non-200 | Link rejected | Server-specific error body converted into a failure result |

**Cache:** No client-side caching.

**Implementation:** `lib/services/file_upload_service.dart` <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

---

### GET /api/user/files

Upstream server call used for remote file history normalization.

**Implements:** [REQ-REMOTE-004](../../sdd/spec/remote-item-actions.md#req-remote-004-fetch-remote-history-lists)

**Authentication:** Requires session headers from the session service.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| none | n/a | The route uses query parameters. |

**Request:**

```json
{
  "query": { "page": 1, "limit": 100 }
}
```

**Response 200:**

```json
{
  "files": [
    { "id": "file-id", "url": "share-link", "name": "file-name" }
  ]
}
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| non-200 | Fetch rejected | Empty list returned to caller |

**Cache:** No client-side caching.

**Implementation:** `lib/services/file_upload_service.dart` <!-- @impl: lib/services/file_upload_service.dart::fetchUserFiles -->

---

### DELETE /api/user/urls/{id}

Upstream server call used for remote short-link deletion.

**Implements:** [REQ-REMOTE-002](../../sdd/spec/remote-item-actions.md#req-remote-002-delete-recent-items-locally-and-remotely-when-possible)

**Authentication:** Requires session headers from the session service.

**Path Parameters:**

| Parameter | Format | Description |
|---|---|---|
| `id` | string | Remote link identifier stored in recent activity. |

**Request:**

```json
{}
```

**Response 200:**

```json
{ "deleted": true }
```

**Error responses:**

| Code | When | Body |
|---|---|---|
| non-200 | Deletion rejected | The service tries fallback endpoints and then returns false |

**Cache:** No client-side caching.

**Implementation:** `lib/services/file_upload_service.dart` <!-- @impl: lib/services/file_upload_service.dart::deleteUrl -->

---

## Admin API

No admin-only endpoint is implemented in this repository. Administrative setup is handled by external dashboards and command-line deployment tools; see [Configuration](configuration.md) and [Deployment](deployment.md).

---

## Related Documentation

- [Architecture](architecture.md) — Component overview
- [Configuration](configuration.md) — Required env vars and secrets

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
