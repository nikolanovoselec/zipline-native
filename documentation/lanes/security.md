# Security

**Audience:** Developers, Operators

Security controls and trust boundaries for the mobile app and browser sign-in bridge.

---

## Secret storage controls

| Control | Threat | Mitigation | Verification | Implements |
|---|---|---|---|---|
| Sensitive credential storage | Device backups or regular preference reads expose secrets | Passwords, sessions, and optional access secrets use Flutter Secure Storage. <!-- @impl: lib/services/auth_service.dart::_secureStorage --> | Source anchor + credential storage tests | [REQ-SESS-001](../../sdd/spec/server-session.md#req-sess-001-save-server-and-credential-settings) |
| Legacy migration | Older preference keys may contain sensitive values | First access migrates owned sensitive keys into secure storage and removes legacy entries. <!-- @impl: lib/services/auth_service.dart::_migrateSensitiveDataIfNeeded --> | Source anchor + triage review | [REQ-SESS-001](../../sdd/spec/server-session.md#req-sess-001-save-server-and-credential-settings) |
| Local unlock token | Local unlock should not store reusable session data in regular preferences | Local unlock token is stored in secure storage and cleared when disabled. <!-- @impl: lib/services/biometric_service.dart::enableBiometric --> | Source anchor | [REQ-BIO-003](../../sdd/spec/biometric-gate.md#req-bio-003-manage-local-unlock-preference) |

## Session and callback controls

| Control | Threat | Mitigation | Verification | Implements |
|---|---|---|---|---|
| Callback state validation | Browser return could be unrelated to the active sign-in attempt | Legacy callback handling compares returned state to stored state before accepting a code. <!-- @impl: lib/services/oauth_service.dart::returnedState --> | Source anchor | [REQ-BRIDGE-002](../../sdd/spec/browser-sign-in.md#req-bridge-002-complete-sign-in-from-an-app-callback) |
| Bridge session rendering | Generated bridge page could expose a raw session value | Worker encodes the session before embedding it in markup, and tests assert the raw value is absent. <!-- @impl: cloudflare-oauth-redirect/src/worker.js::encodedSession --> | Worker test | [REQ-BRIDGE-004](../../sdd/spec/browser-sign-in.md#req-bridge-004-avoid-raw-session-exposure-in-bridge-markup) |
| Optional access headers | Access credentials should only be added when configured | Header construction includes optional access headers only when stored values exist. <!-- @impl: lib/services/auth_service.dart::getAuthHeaders --> | Source anchor | [REQ-SESS-003](../../sdd/spec/server-session.md#req-sess-003-provide-request-credentials-for-server-actions) |

## Trust boundaries

| Boundary | Inputs | Trusted after | Notes |
|---|---|---|---|
| Platform share intent | Files, text, content URIs | Content is copied into app storage or ignored | Filename and extension inference are best effort. <!-- @impl: lib/services/intent_service.dart::copyContentUriFile --> |
| Browser sign-in callback | Query parameters from browser/worker | Session is stored only after success parsing or state validation | Worker logging policy remains in triage. <!-- @impl: lib/services/oauth_service.dart::checkInitialOAuthCallback --> |
| Remote server responses | Upload, link, file, and URL response bodies | Service normalization validates expected fields before UI use | Compatibility fallbacks remain in triage. <!-- @impl: lib/services/file_upload_service.dart::fetchUserFiles --> |

## Related Documentation

- [API Reference](api-reference.md) — Request and response shapes
- [Configuration](configuration.md) — Secrets and environment variables
- [Troubleshooting](troubleshooting.md) — Security-adjacent failure recipes
