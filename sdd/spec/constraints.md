# Constraints

Cross-cutting architectural and technology decisions that apply to every domain.

## Technology Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Mobile shell | Flutter | Existing source is a Flutter app with Material UI and provider-backed state. |
| Platform host | Android embedding | Share intents, content URI copying, and the callback scheme are implemented in the Android host. |
| Worker runtime | Cloudflare Workers | The browser sign-in bridge source and deployment files target Workers. |
| HTTP clients | http and Dio | Source uses lightweight requests for authentication and Dio for upload progress. |
| Local persistence | SharedPreferences plus Flutter Secure Storage | Source separates non-secret settings from sensitive session and credential values. |

## Non-Functional Requirements

### CON-SEC-001: Protect secrets at rest

Sensitive values must be stored in secure local storage and removed from regular preferences when discovered there.

**Applies To:** Server Session, Browser Sign-In Bridge, Biometric Gate, Settings

### CON-SEC-002: Do not expose raw sessions in generated pages

The bridge must not render the raw session value directly into returned markup.

**Applies To:** Browser Sign-In Bridge

### CON-REL-001: Keep user-visible work recoverable

Queued work, recent activity, connectivity state, and diagnostics should remain visible enough for a user to understand what happened after an interruption.

**Applies To:** File Upload, Upload Queue, Activity Log, Connectivity, Diagnostics

### CON-UX-001: Preserve share-first flow

Successful file and link actions should quickly produce a shareable result through clipboard and the platform share surface.

**Applies To:** Share Intake, File Upload, Link Shortening, Remote Item Actions

### CON-PLATFORM-001: Keep bridge identifiers synchronized

The package identifier, method-channel namespace, manifest callback handling, and bridge fallback URL must change together if the app identifier changes.

**Applies To:** App Bootstrap, Share Intake, Browser Sign-In Bridge, Build And Release

## Boundaries

Things the system intentionally does NOT do:

- **Multiple active accounts** — one stored server context is supported at a time.
- **Anonymous upload** — server actions require an authenticated session.
- **Guaranteed remote protection support** — protection actions are best-effort until upstream support is confirmed.
- **Post-upload expiration mutation** — current source records this as unsupported.

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
