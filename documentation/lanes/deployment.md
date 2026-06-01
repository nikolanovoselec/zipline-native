<!-- doc-discipline: one-line table cells (≤50 words), deploy commands and rollback steps only — no env var documentation (link to configuration.md), no API contracts (link to api-reference.md). -->

# Deployment

**Audience:** Developers, Operators

Local development setup and production deployment steps.

---

## Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Tests](#tests)
- [Production Deployment](#production-deployment)
- [Cloudflare Resources](#cloudflare-resources)
- [Related Documentation](#related-documentation)
- [Pi runtime compatibility](#pi-runtime-compatibility)

## Prerequisites

- Flutter SDK compatible with the `pubspec.yaml` SDK constraint.
- Node.js compatible with the worker package requirements.
- Android signing key and `android/key.properties` for release builds.
- Cloudflare account and Worker credentials for bridge deployment.

## Local Development

```bash
flutter pub get
flutter doctor
cd cloudflare-oauth-redirect && npm install
```

The app runs through the Flutter toolchain, and the worker runs through Wrangler's local development command.

## Tests

```bash
flutter analyze --no-fatal-infos
flutter test
npm test --prefix cloudflare-oauth-redirect
```

Tests are organized so each test can reference a REQ ID; Import Mode currently has `enforce_tdd: false` until the transition queue drains and test names are backfilled.

## Production Deployment

```bash
flutter build apk --release --split-per-abi
cd cloudflare-oauth-redirect && npm run deploy
```

### Environment-specific configuration

| Environment | Branch | Notes |
|---|---|---|
| Development | feature branches | Use example config files and local secrets. |
| Production | `main` | Requires release signing config and worker route configuration. |

## Cloudflare Resources

| Resource | Type | Purpose |
|---|---|---|
| `zipline-oauth-redirect` | Worker | Receives browser callback traffic and returns app-opening HTML. <!-- @impl: cloudflare-oauth-redirect/wrangler.toml.example::name --> |
| Worker route | Route | Binds the callback path to the worker. <!-- @impl: cloudflare-oauth-redirect/wrangler.toml.example::routes --> |
| Worker secrets | Secret | Store access credentials when the upstream server is protected. <!-- @impl: README.md::wrangler --> |

---

## Related Documentation

- [Configuration](configuration.md) — Env vars and secrets
- [Architecture](architecture.md) — System overview

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
