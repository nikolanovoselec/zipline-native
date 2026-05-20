# Glossary

Terms used in REQs, ADRs, and documentation. One-line definitions only.

- **Zipline** — Self-hosted file-sharing service (https://zipline.diced.sh); the backend this client targets.
- **Zipline instance** — A user-deployed Zipline server (URL + credentials).
- **OAuth/OIDC** — The OpenID Connect flow used by Zipline for browser-mediated login.
- **Worker** — The Cloudflare Worker at `cloudflare-oauth-redirect/src/worker.js` brokering OAuth callbacks.
- **Share-sheet** — Android system UI for sharing content from one app to another.
- **Intent** — Android system message that delivers shared content to the app.
- **Upload queue** — In-memory + persisted list of pending uploads awaiting network or retry.
- **Secure Storage** — Flutter Secure Storage (Android EncryptedSharedPreferences-backed).
- **Biometric unlock** — Face/fingerprint authentication via `local_auth` package, gated on hardware availability.
- **Inline progress** — Per-file 0-100% progress reported inside the Upload Files card, not via toast or notification.
- **OIDC callback URL** — The Worker URL Zipline redirects to after successful browser auth.
- **Session cookie** — The Zipline-issued cookie persisted post-authentication.
- **App link** — Android deep-link the Worker emits to hand control back to the app (`zipline://`).
- **Activity log** — Rolling in-memory event log surfaced via Debug screen.
- **OAuth Worker** — Same as Worker; the OAuth-handling Cloudflare Worker.
