# Zipline Native — Product Specification

## Vision

Zipline Native is a mobile-first sharing client for people who run their own file-sharing server and want the daily sharing flow to start from the device share sheet instead of from a browser form. The app receives files or links from other apps, authenticates the user against their server, uploads or shortens the content, and hands the resulting share link back through clipboard and the platform share surface.

## Actors

| Actor | Description |
|-------|-------------|
| **User** | Device owner who wants to share files and links from the apps they already use. |
| **Operator** | Person who configures the server, release build, browser sign-in bridge, and access credentials. |
| **Contributor** | Developer maintaining the app, worker, tests, and release process. |

## Design Principles

1. **Share-first** — intake from the platform share surface is the primary product path, and the launcher surface supports setup, history, and diagnostics.
2. **Local secret isolation** — sensitive tokens and passwords stay in local secure storage; regular preferences only hold non-secret settings.
3. **Best-effort interoperability** — the client tolerates server response-shape drift where the source already contains fallback handling, while unclear fallbacks stay visible in triage.
4. **Visible recovery** — upload state, connectivity state, and debug logs surface enough information for the user or operator to recover without source-code archaeology.
5. **Transition honesty** — imported requirements describe behavior that has source evidence; ambiguous legacy areas remain in the triage queue until the user decides.

## Domains

| # | Domain | File | Priority | Description |
|---|--------|------|----------|-------------|
| 1 | App Bootstrap | [spec/app-bootstrap.md](spec/app-bootstrap.md) | P0 | Startup, dependency setup, shell overlays, and splash routing. |
| 2 | Server Session | [spec/server-session.md](spec/server-session.md) | P0 | Saved server address, credentials, sessions, profile lookup, and logout. |
| 3 | Browser Sign-In Bridge | [spec/browser-sign-in.md](spec/browser-sign-in.md) | P0 | External browser handoff, callback handling, and worker-assisted return flow. |
| 4 | Biometric Gate | [spec/biometric-gate.md](spec/biometric-gate.md) | P1 | Optional local unlock after a session exists. |
| 5 | Share Intake | [spec/share-intake.md](spec/share-intake.md) | P0 | Platform share data ingestion and conversion into files or links. |
| 6 | File Upload | [spec/file-upload.md](spec/file-upload.md) | P0 | Manual and shared file upload, progress, and share-link handoff. |
| 7 | Upload Queue | [spec/upload-queue.md](spec/upload-queue.md) | P0 | Queued upload state, controls, retries, and overlay presentation. |
| 8 | Link Shortening | [spec/link-shortening.md](spec/link-shortening.md) | P1 | Link normalization, short-link creation, custom labels, and result sharing. |
| 9 | Remote Item Actions | [spec/remote-item-actions.md](spec/remote-item-actions.md) | P1 | Recent-item sharing, deletion, and protection actions. |
| 10 | Activity Log | [spec/activity-log.md](spec/activity-log.md) | P1 | Local recent activity cache and clearing behavior. |
| 11 | Diagnostics | [spec/diagnostics.md](spec/diagnostics.md) | P2 | Opt-in local logs, filters, export, and share fallback. |
| 12 | Connectivity | [spec/connectivity.md](spec/connectivity.md) | P2 | Network-state tracking and offline banner presentation. |
| 13 | Theme And State | [spec/theme-and-state.md](spec/theme-and-state.md) | P1 | Theme persistence and global app state. |
| 14 | Settings | [spec/settings.md](spec/settings.md) | P0 | Server configuration, optional access credentials, appearance, local unlock, diagnostics, and logout. |

## Out of Scope

The following were considered and intentionally excluded from the product:

- **Multiple active accounts** — the app stores one server address and one active user context at a time.
- **Anonymous sharing** — all upload and link actions require a stored authenticated session.
- **Post-upload expiration editing** — source currently records this as unsupported instead of pretending it succeeds.
- **Generic hosting for the sign-in bridge** — the bundled bridge is written for the deployed worker runtime already present in the repository.
- **Treating prior closed scaffold PRs as source of truth** — closed PRs are historical context only; current source anchors drive this import.

## Constraints

See [spec/constraints.md](spec/constraints.md) for cross-cutting guardrails.

## Glossary

See [spec/glossary.md](spec/glossary.md) for canonical term definitions.

## Documentation

Implementation documentation lives in [`documentation/`](../documentation/README.md). Lane files emit only when source evidence justifies them; `documentation/lanes/architecture.md` is always present.

## Changelog

See [spec/changes.md](spec/changes.md) for specification history.

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
