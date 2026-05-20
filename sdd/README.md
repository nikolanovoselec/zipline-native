# Zipline Native — Specification

A Flutter Android client and Cloudflare Worker for the Zipline file-sharing service. Native share-sheet upload, OAuth/OIDC + username/password authentication, offline-resilient upload queue.

**Audience:** Developers and the agent enforcing this spec at PR boundary.

## Actors

- **User** — Android phone owner sharing files to a Zipline instance.
- **Worker** — Cloudflare Worker mediating OAuth callbacks between Zipline and the app.
- **Zipline Server** — External file-hosting backend the app uploads to.

## Design principles

1. **Inline progress, never silent uploads.** Every upload reports 0-100% inside the Upload Files card; share-sheet batches stay in the same surface.
2. **Hardware-backed secrets.** OAuth tokens and credentials use Flutter Secure Storage with Android EncryptedSharedPreferences; biometric unlock is gated on hardware availability.
3. **Offline-first queue.** Failed uploads enqueue and retry on connectivity recovery; user never loses an upload because of a dropped connection.
4. **OAuth opt-in.** Username/password is the default; OAuth/OIDC is a configuration toggle that requires the Worker.
5. **One platform polished.** Android-only; iOS/desktop builds are best-effort; the spec does not promise feature parity outside Android.

## Domains

| Domain | One-line | Priority |
|---|---|---|
| [auth](auth.md) | Username/password, OAuth/OIDC, biometric unlock | P0 |
| [upload](upload.md) | File picker, upload, queue, retry | P0 |
| [sharing](sharing.md) | Android intent receiver, share-sheet batch ingest | P0 |
| [connectivity](connectivity.md) | Network monitoring, offline-queue activation | P1 |
| [oauth-worker](oauth-worker.md) | Cloudflare Worker OAuth callback broker | P1 |
| [debug](debug.md) | Activity log, debug screen, log export | P2 |

## Related

- [Glossary](glossary.md)
- [Constraints](constraints.md)
- [Changes](changes.md)
- [Init triage](init-triage.md) — Status: 4 open
