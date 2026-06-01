<!-- doc-discipline: one-line table cells (≤50 words), env var entries only — no API contracts, no deploy commands. -->

# Configuration

**Audience:** Operators, Developers

Environment variables, secrets, and platform bindings required to run the system.

---

## Contents

- [Environment Variables](#environment-variables)
- [Secrets](#secrets)
- [Platform Bindings](#platform-bindings)
- [Configuration Files](#configuration-files)
- [Related Documentation](#related-documentation)
- [Pi runtime compatibility](#pi-runtime-compatibility)

## Environment Variables

| Variable | Default | Required | Consumed by | Implements | Description |
|---|---|---|---|---|---|
| `OAUTH_REDIRECT_URL` | empty | no | `BuildConfig.oauthRedirectUrl` <!-- @impl: lib/core/build_config.dart::oauthRedirectUrl --> | [REQ-BRIDGE-001](../../sdd/spec/browser-sign-in.md#req-bridge-001-start-external-browser-sign-in-from-the-app) | Build-time override for the app's browser sign-in bridge URL. |
| `ZIPLINE_URL` | placeholder URL | yes for worker | `env.ZIPLINE_URL` <!-- @impl: cloudflare-oauth-redirect/src/worker.js::ZIPLINE_URL --> | [REQ-BRIDGE-003](../../sdd/spec/browser-sign-in.md#req-bridge-003-return-sessions-through-the-bridge-page) | Worker-side upstream server URL used during callback exchange. |
| `CLOUDFLARE_API_TOKEN` | none | yes for deploy tooling | package deploy script <!-- @impl: cloudflare-oauth-redirect/package.json::deploy --> | [REQ-BRIDGE-003](../../sdd/spec/browser-sign-in.md#req-bridge-003-return-sessions-through-the-bridge-page) | Wrangler credential used by deployment tooling, not read by app code. |

## Secrets

| Secret | Storage | Description |
|---|---|---|
| `CF_ACCESS_CLIENT_ID` | device secure storage / worker secret when needed | Optional access client id passed as a request header. <!-- @impl: lib/services/auth_service.dart::_cfClientIdKey --> |
| `CF_ACCESS_CLIENT_SECRET` | device secure storage / worker secret when needed | Optional access client secret passed as a request header. <!-- @impl: lib/services/auth_service.dart::_cfClientSecretKey --> |
| Android keystore passwords | `android/key.properties` outside git | Release signing credentials consumed by the Android Gradle config. <!-- @impl: android/app/build.gradle::keystoreProperties --> |

## Platform Bindings

| Binding | Type | Purpose |
|---|---|---|
| App callback scheme | Android intent filter | Routes browser sign-in return URLs back into the app. <!-- @impl: android/app/src/main/AndroidManifest.xml::BROWSABLE --> |
| Method channel | Flutter platform channel | Moves share-intent data and content URI copy requests between Dart and Kotlin. <!-- @impl: lib/services/intent_service.dart::MethodChannel --> |
| Worker route | Cloudflare Worker route | Receives browser callback traffic for the bridge. <!-- @impl: cloudflare-oauth-redirect/wrangler.toml.example::routes --> |

## Configuration Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | Flutter dependencies, app version, assets, and package metadata. |
| `android/app/build.gradle` | Android namespace, application id, signing config, and build settings. |
| `android/key.properties.example` | Example release signing config shape. |
| `cloudflare-oauth-redirect/wrangler.toml.example` | Example worker route and environment configuration. |
| `.env.example` | Example root environment variable file. |
| `analysis_options.yaml` | Dart analyzer/lint configuration. |

---

## Related Documentation

- [Deployment](deployment.md) — How to set these up in dev and prod
- [Architecture](architecture.md) — Where these bindings are used

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
