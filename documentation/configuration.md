# Configuration

Environment variables, secrets, and runtime configuration for both the app and the OAuth Worker.

**Audience:** Operators and developers

## Worker environment variables

| Variable | Required | Source | Purpose |
|---|---|---|---|
| `ZIPLINE_URL` | yes | `wrangler.toml [vars]` | Base URL of the user's Zipline instance the Worker proxies OAuth exchanges to |

The Worker reads `env.ZIPLINE_URL` per [REQ-OAUTH-004](../sdd/oauth-worker.md#req-oauth-004-configurable-zipline-url). Falls back to a configured default if unset.

## Worker configuration file

`cloudflare-oauth-redirect/wrangler.toml` (copy from `wrangler.toml.example` and fill in):

| Key | Purpose |
|---|---|
| `name` | Worker name in CF account |
| `main` | Entry point (`src/worker.js`) |
| `compatibility_date` | Workers runtime compatibility |
| `[vars] ZIPLINE_URL` | The Zipline instance the Worker brokers OAuth for |

## App configuration

The app does not use environment variables. Configuration values are either:

1. **User-supplied at runtime** (Zipline URL, credentials, OAuth toggle) — persisted per [REQ-AUTH-004](../sdd/auth.md#req-auth-004-secure-credential-storage).
2. **Compile-time constants** in `lib/core/build_config.dart` and `lib/core/constants.dart`.

## Build-time constants

| Constant | File | Purpose |
|---|---|---|
| `kDefaultZiplineUrl` | `lib/core/build_config.dart` | Optional fallback Zipline URL baked into the build |
| `kStorageKeyZiplineUrl` | `lib/core/constants.dart` | SharedPreferences key for the user's Zipline URL |
| `kStorageKeySessionCookie` | `lib/core/constants.dart` | SecureStorage key for the session cookie |
| `kMaxConcurrentUploads` | `lib/core/constants.dart` | `3` per [REQ-UPLOAD-006](../sdd/upload.md#req-upload-006-concurrent-upload-limit) |
| `kMaxRetries` | `lib/core/constants.dart` | `3` per [CON-REL-002](../sdd/constraints.md#con-rel-002-retry-policy) |
| `kActivityLogCap` | `lib/core/constants.dart` | `500` per [CON-OBS-001](../sdd/constraints.md#con-obs-001-activity-log-size-cap) |

## Android signing config

`android/key.properties` (gitignored — never commit):

```
storeFile=<path to keystore>
storePassword=<password>
keyAlias=<alias>
keyPassword=<key password>
```

Required for `flutter build apk --release`. Debug builds use Flutter's default debug keystore.

## Related Documentation

- [Deployment](deployment.md) — Deploy steps for app and Worker
- [Security](security.md) — Secret handling, Worker CSRF mitigation
