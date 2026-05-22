<!-- doc-discipline: one-line table cells, no implementation prose -->

# Zipline Native — Documentation

**Audience:** Developers, Operators

This is the implementation documentation. The product specification (what the system does and why) lives at [`sdd/README.md`](../sdd/README.md). This folder describes **how the system actually works** — components, contracts, env vars, deploy steps, decisions.

---

## Jump-TOC

| Document | One-line role |
|---|---|
| [Architecture](lanes/architecture.md) | System overview, components, request flow, file/folder map |
| [API Reference](lanes/api-reference.md) | Cloudflare Worker bridge — request shape, status codes, redirect payload |
| [Configuration](lanes/configuration.md) | Build-time defines, Worker env vars, secrets, signing config |
| [Deployment](lanes/deployment.md) | Local build, APK release, Worker `wrangler deploy` |
| [Security](lanes/security.md) | Auth flow, secure storage, deep-link hardening, cookie masking |
| [Observability](lanes/observability.md) | Debug-log shape, categories, levels, export |
| [Troubleshooting](lanes/troubleshooting.md) | OAuth, share-sheet, biometric, install failure recipes |
| [Decisions](decisions/README.md) | Architecture Decision Records (ADR ledger) |

---

## Lane ownership

| File | Owns | Never owns |
|---|---|---|
| `lanes/architecture.md` | Component layout, data flow, file/folder structure, technology choices | API contracts, env vars, deploy steps, troubleshooting |
| `lanes/api-reference.md` | Worker request/response shape and redirect payload | App-side internal calls, env values, deploy steps |
| `lanes/configuration.md` | `--dart-define` keys, Worker env vars, signing config, Android resource IDs | API contracts, architecture rationale, deploy commands |
| `lanes/deployment.md` | Build commands, deploy commands, signing setup, rollback | API contracts, env documentation (link to `lanes/configuration.md`) |
| `lanes/security.md` | Threat model, secure-storage rules, deep-link hardening, cookie masking | Per-endpoint auth (link to `lanes/api-reference.md`) |
| `lanes/observability.md` | Log categories, levels, export shape | Architecture, troubleshooting recipes |
| `lanes/troubleshooting.md` | Symptom → cause → fix recipes | Architecture, env vars, deploy steps |
| `decisions/README.md` | Architecture Decision Records ledger | Non-ADR content; runbook prose; spec REQs |

---

## REQ backlinks

Every documented feature references the spec REQ that defines it. Format: inline `[REQ-X-NNN](../sdd/spec/{domain}.md#req-x-nnn-title-slug)` immediately after the feature name in a heading or first sentence.

---

## Synonym glossary

| Canonical term | Synonyms / variants | Where defined |
|---|---|---|
| OAuth Worker | Cloudflare Worker, OAuth bridge, oauth-redirect Worker | [`cloudflare-oauth-redirect/src/worker.js`](../cloudflare-oauth-redirect/src/worker.js), [`sdd/spec/oauth.md`](../sdd/spec/oauth.md) |
| Session cookie | `zipline_session`, OAuth session, auth token | [`sdd/spec/authentication.md`](../sdd/spec/authentication.md), [`sdd/spec/oauth.md`](../sdd/spec/oauth.md) |
| Deep link | App link, intent URL, `zipline://` URI | [`sdd/spec/oauth.md`](../sdd/spec/oauth.md) |
| Activity log | Recent activities, upload history | [`sdd/spec/activity-log.md`](../sdd/spec/activity-log.md) |
| Debug logs | Diagnostic logs, in-app logs | [`sdd/spec/debug-diagnostics.md`](../sdd/spec/debug-diagnostics.md) |

For domain-specific definitions (single canonical name, one sentence of meaning) see [`sdd/spec/glossary.md`](../sdd/spec/glossary.md).

---

## Reading order for a new contributor

1. **Start here.** Read this index to understand which lane owns what.
2. **Architecture** (`lanes/architecture.md`) — what the system is and how requests move through it.
3. **API Reference** (`lanes/api-reference.md`) — the only HTTP surface the project owns (the OAuth Worker).
4. **Configuration** (`lanes/configuration.md`) — what knobs exist.
5. **Decisions** (`decisions/README.md`) — why the system looks the way it does.
6. **Security**, **Observability**, **Troubleshooting**, **Deployment** — on demand, when working in those areas.

---

## Related

- [Product Specification](../sdd/README.md) — Requirements and design intent
- [Glossary](../sdd/spec/glossary.md) — Canonical term definitions
- [Project README](../README.md) — Project overview and quickstart
- [Changelog](../sdd/spec/changes.md) — Specification history
