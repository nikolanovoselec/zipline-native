# URL Shortener

Shorten a URL via the Zipline shortener API, with version-tolerant fallbacks for older server installs.

## REQ-URL-001: Shorten a URL with v4 → v3 → legacy fallback

**Status:** Implemented
**Intent:** A user pastes (or shares) a long URL into the home screen. The app sends it to the Zipline shortener and returns the resulting short URL. The shortener API surface differs across Zipline versions, so the client tries multiple shapes in order.
**Acceptance Criteria:**
- `FileUploadService.shortenUrl(url, customSlug, …)` first tries `POST <ziplineUrl>/api/shorten` with the v4 body `{destination, vanity}`. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->
- On failure it tries the same endpoint with the v3 body `{url, vanity}`. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->
- On further failure it tries the legacy endpoint `POST <ziplineUrl>/api/upload` with header `Format: RANDOM` and the URL in the body. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->
- The first endpoint that returns a successful response wins; the remaining endpoints are not tried. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

**Constraints:** [CON-API-001](constraints.md#con-api-001-tolerate-zipline-server-version-drift).
**Dependencies:** [REQ-AUTH-003](authentication.md#req-auth-003-cloudflare-access-service-token-forwarding).
**Notes:** See [TRIAGE-002](.init-triage.md#triage-002-shortener-endpoint-cascade) — confirm whether the v3 and legacy fallbacks are still load-bearing.

## REQ-URL-002: Custom slug (vanity) support

**Status:** Implemented
**Intent:** Power users want a memorable short URL, e.g. `https://l.example.com/launch-deck`. The client accepts an optional slug and passes it through to whichever Zipline endpoint accepts it.
**Acceptance Criteria:**
- `shortenUrl(url, customSlug)` includes the `vanity` field in v4/v3 requests when `customSlug` is non-empty. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->
- Slug conflicts (server rejects with 409 or 400) propagate to the caller as `{success: false, error: …}`. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

**Constraints:** None.
**Dependencies:** [REQ-URL-001](#req-url-001-shorten-a-url-with-v4--v3--legacy-fallback).

_Verification: code-only (no automated coverage)._
