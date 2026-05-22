# Zipline Native — Product Specification

## Vision

Zipline Native is the Android-only client for [Zipline](https://github.com/diced/zipline). It collapses the workflow "open browser → log into Zipline → drag file → wait → copy link" into a single share-sheet action: share any file or URL from any Android app, and the link to your Zipline-hosted copy ends up on your clipboard within seconds. Authentication supports username/password, OAuth/OIDC via a Cloudflare Worker bridge, Cloudflare Access service tokens, and post-login biometric gating.

## Actors

| Actor | Description |
|-------|-------------|
| **User** | Android device owner with a Zipline account who wants to share files or shorten URLs without leaving the apps they are already in. |
| **Zipline Server** | The user's self-hosted Zipline instance — the HTTP API the app uploads to, fetches activity from, and authenticates against. |
| **Operator** | The person who configures the OAuth Worker, Cloudflare Access policies, and Zipline server. Often the same human as User but conceptually distinct. |

## Design Principles

1. **Share-first** — the Android share sheet is the primary entry point; the launcher icon is for configuration and reviewing activity, not the daily workflow.
2. **Native-feeling** — Flutter Material UI with a dark default theme and glassmorphic accents; haptic feedback and biometric prompts use platform-native widgets.
3. **Credential isolation** — every secret (session cookie, password, OAuth tokens, Cloudflare Access secrets) is held in `flutter_secure_storage` with `EncryptedSharedPreferences` backing on Android. SharedPreferences hold only non-sensitive preferences.
4. **Best-effort upload** — transient failures retry with exponential backoff; the upload queue is always cancellable, and a partially failed batch still surfaces the successful uploads to the user.
5. **Server-version tolerant** — the client targets a moving Zipline API; for shorten and file-management endpoints it falls back through v4 → v3 → legacy shapes so a stale server still works.

## Domains

| # | Domain | File | Priority | Description |
|---|--------|------|----------|-------------|
| 1 | App Bootstrap | [spec/app-bootstrap.md](spec/app-bootstrap.md) | P0 | Splash, auth check, biometric gate, home/login routing |
| 2 | Authentication | [spec/authentication.md](spec/authentication.md) | P0 | Username/password login, Cloudflare Access tokens, session cookie storage |
| 3 | OAuth | [spec/oauth.md](spec/oauth.md) | P0 | OAuth/OIDC flow via Cloudflare Worker bridge, deep-link callback, cold-start recovery |
| 4 | Biometric | [spec/biometric.md](spec/biometric.md) | P1 | Optional biometric gating on resume; enable/disable from settings |
| 5 | Share Intent | [spec/share-intent.md](spec/share-intent.md) | P0 | Android `ACTION_SEND` / `ACTION_SEND_MULTIPLE` ingestion via MethodChannel |
| 6 | Upload | [spec/upload.md](spec/upload.md) | P0 | Multipart file upload to Zipline `/api/upload` with progress callbacks |
| 7 | Upload Queue | [spec/upload-queue.md](spec/upload-queue.md) | P0 | Concurrent-bounded upload pipeline with retry, cancel, and status stream |
| 8 | URL Shortener | [spec/url-shortener.md](spec/url-shortener.md) | P1 | Shorten URLs via Zipline shortener API with custom slug |
| 9 | File Management | [spec/file-management.md](spec/file-management.md) | P1 | Delete uploaded files and short URLs from the activity log |
| 10 | Activity Log | [spec/activity-log.md](spec/activity-log.md) | P1 | Local cache of the user's recent uploads |
| 11 | Debug Diagnostics | [spec/debug-diagnostics.md](spec/debug-diagnostics.md) | P2 | In-app log viewer with category/level filtering and JSON export |
| 12 | Connectivity | [spec/connectivity.md](spec/connectivity.md) | P2 | Reactive network-state stream surfaced to the UI |
| 13 | Theme And State | [spec/theme-and-state.md](spec/theme-and-state.md) | P1 | Global `AppState` + `ThemeProvider`; dark-default theme with optional system/light |

## Out of Scope

The following were considered and intentionally excluded:

- **iOS support** — the manifest declares Android intents only, the keystore wiring is Android-specific, and the project has shipped no iOS deliverable.
- **Anonymous uploads** — every upload requires a configured Zipline server and a valid session; the app never uploads without credentials.
- **Multi-account support** — a single Zipline server URL plus a single set of credentials is stored at a time. Switching accounts means logging out and back in.
- **File-expiration modification after upload** — the Zipline server `PATCH /api/user/files/:id` endpoint does not accept the `deletesAt` field; expiration can only be set during upload.
- **Self-hosting the OAuth bridge anywhere except Cloudflare Workers** — the bridge code targets the Workers runtime; running it on a generic Node host would require deployment changes outside the project's scope.

## Constraints

See [spec/constraints.md](spec/constraints.md) for cross-cutting guardrails.

## Glossary

See [spec/glossary.md](spec/glossary.md) for canonical term definitions.

## Documentation

Implementation documentation lives in [`documentation/`](../documentation/README.md). Lane files emit only when source evidence justifies them; `documentation/lanes/architecture.md` is always present.

## Changelog

See [spec/changes.md](spec/changes.md) for specification history.
