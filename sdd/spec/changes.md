# Spec Changes

Semantic changes to the specification. Git history captures diffs; this file captures intent.

## 2026-05-22

- SDD initialized via Import Mode. 13 domains derived from existing source: app-bootstrap, authentication, oauth, biometric, share-intent, upload, upload-queue, url-shortener, file-management, activity-log, debug-diagnostics, connectivity, theme-and-state.
- 8 founding ADRs seeded from god-node analysis (Flutter, get_it+Provider, FlutterSecureStorage, Cloudflare Worker bridge, Worker server-side code exchange, Intent URL fallback, Dio for uploads, exponential backoff retry).
- 7 triage items filed for interactive resolution: alternate `login_screen.dart` (TRIAGE-001), shortener endpoint cascade (TRIAGE-002), best-effort `setFilePassword` (TRIAGE-003), `setFileExpiration` aspirational UI (TRIAGE-004), template-default package name (TRIAGE-005), legacy sensitive-data migration (TRIAGE-006), light-theme dead-code vs feature (TRIAGE-007).
- `transition: true` set; `enforce_tdd: false` set per Import Mode defaults. Per-domain `_Verification: code-only (no automated coverage)._` footnotes record that imported REQs default to `Implemented` based on resolved source anchors rather than automated coverage.
- TRIAGE-001 resolved (corrected): `lib/screens/login_screen.dart` moved to `lib/_archive/login_screen.dart` with a legacy header comment; the archive path is now Phase-7b-waivered.
