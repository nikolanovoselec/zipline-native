# Constraints

System-wide invariants. Referenced from REQs as `[CON-X-NNN](constraints.md#con-x-nnn-title-slug)`.

## CON-TECH-001: Flutter SDK 3.35+

The app targets Flutter SDK 3.35.0 or newer. CI fails the build on older SDKs.

## CON-TECH-002: Android API 26+

Minimum Android API level 26 (Android 8.0). Below this, `flutter_secure_storage` cannot use EncryptedSharedPreferences.

## CON-TECH-003: Cloudflare Workers runtime

The OAuth broker deploys as a Cloudflare Worker (V8 isolate). No Node.js APIs; only Workers runtime + Web APIs.

## CON-SEC-001: Hardware-backed secrets

OAuth tokens, refresh tokens, Zipline session cookies, and OIDC client secrets MUST persist via Flutter Secure Storage with `encryptedSharedPreferences: true`. Plain `SharedPreferences` storage is forbidden for these values.

## CON-SEC-002: Worker validates state parameter

The OAuth Worker MUST validate the `state` query parameter to mitigate CSRF in the callback exchange. Missing or empty state returns 400.

## CON-PERF-001: Upload progress every <=500ms

Per-file upload progress callbacks fire at minimum 500ms intervals during active transfer. Sub-500ms throttling is acceptable; longer silences are not.

## CON-REL-001: Offline-queue persistence

Uploads enqueued while offline persist across app restart. Queue state stored via `shared_preferences` keyed by stable UUID.

## CON-REL-002: Retry policy

A failed upload retries automatically on connectivity recovery up to 3 times before moving to a manual-retry state in the queue UI.

## CON-OBS-001: Activity log size cap

In-memory activity log is capped at 500 events. Oldest events drop FIFO. Cap is not configurable.
