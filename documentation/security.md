# Security

Threat model, authentication flow, secret storage, Worker hardening.

**Audience:** Developers and security reviewers

## Trust model

- **The user's device** is trusted to hold session tokens (encrypted, via hardware-backed Keystore).
- **The OAuth Worker** is trusted by the app as the OAuth callback broker; the app accepts a session cookie from the Worker's deep-link without further verification.
- **The Zipline server** is trusted to issue valid session cookies and uphold its `/api/upload` contract.
- **Other Android apps** are NOT trusted; share-sheet intents are accepted but pre-share auth gate ([REQ-SHARE-003](../sdd/sharing.md#req-share-003-pre-share-authentication-gate)) prevents unauthenticated uploads.

## Authentication flow (OAuth/OIDC)

1. App constructs the Zipline OIDC URL with a `state` parameter.
2. `flutter_web_auth_2` opens the system browser; user authenticates against the configured IdP.
3. Zipline redirects to the Worker URL with `code` and `state` query parameters.
4. Worker validates `state` is non-empty per [REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation) (missing state returns 400 without contacting Zipline).
5. Worker exchanges the code with Zipline (`/api/auth/oauth/oidc`) using `redirect: manual` to capture the `Set-Cookie` header.
6. Worker emits HTTP 302 redirecting to `zipline://oauth-callback?session=<cookie>`.
7. App's `app_links` captures the deep-link, persists the session cookie via `FlutterSecureStorage` per [CON-SEC-001](../sdd/constraints.md#con-sec-001-hardware-backed-secrets).

## Secret storage

| Secret | Storage | Backing |
|---|---|---|
| Zipline session cookie | `FlutterSecureStorage` | Android EncryptedSharedPreferences (Keystore-backed) |
| OAuth client ID / secret | `FlutterSecureStorage` | Android EncryptedSharedPreferences (Keystore-backed) |
| `wrangler.toml` `ZIPLINE_URL` | Worker env var | Not a secret (public URL) |
| Android keystore | `android/key.properties` | Gitignored; user-managed |

Plain `SharedPreferences` is forbidden for credentials per [CON-SEC-001](../sdd/constraints.md#con-sec-001-hardware-backed-secrets).

## Worker hardening

- **State validation:** missing `state` short-circuits the handler before any outbound call. Mitigates CSRF on the callback exchange ([REQ-OAUTH-002](../sdd/oauth-worker.md#req-oauth-002-state-parameter-validation)).
- **Cookie redaction in logs:** the Worker logs response headers for debug but redacts `set-cookie` values to `[redacted for security]` per [REQ-OAUTH-003](../sdd/oauth-worker.md#req-oauth-003-cookie-redaction-in-logs).
- **No PII retention:** the Worker stores no per-user data; it is a stateless proxy.

## Known gaps (open triage)

- [TRIAGE-002](../sdd/init-triage.md#triage-002-worker-handles-zipline-non-2xx-exchange-response): the Worker does not branch on a non-2xx Zipline response during code exchange. Currently produces an undefined session cookie in the redirect. Triage recommendation: return HTTP 502.

## Biometric unlock

`local_auth` with `biometricOnly: true`. Availability is checked via `canCheckBiometrics`; devices without hardware never see the unlock option per [REQ-AUTH-003](../sdd/auth.md#req-auth-003-biometric-unlock). The biometric prompt unlocks an existing session; it does NOT authenticate against Zipline directly.

## Related Documentation

- [Architecture § 5.2](architecture.md#52-oauth-login) — OAuth flow lifecycle
- [Configuration](configuration.md) — Where secrets live
- [API Reference](api-reference.md) — Worker endpoint contract
