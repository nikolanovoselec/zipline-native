<!-- doc-discipline: one-line table cells, no implementation prose -->

# Zipline Native — Documentation

**Audience:** Developers, Operators

This is the implementation documentation. The product specification lives at [`sdd/README.md`](../sdd/README.md). This folder describes how the system actually works — components, contracts, configuration, deploy steps, decisions, and runbooks.

A future contributor reading this folder should be able to navigate the implementation without re-reading every source file.

---

## Jump-TOC

| Document | One-line role |
|---|---|
| [Architecture](lanes/architecture.md) | System overview, components, request flow, file/folder map |
| [API Reference](lanes/api-reference.md) | Worker route and upstream server calls |
| [Configuration](lanes/configuration.md) | Environment variables, secrets, runtime configuration |
| [Deployment](lanes/deployment.md) | Local setup, app build, worker deploy, rollback |
| [Security](lanes/security.md) | Secret storage, session handling, callback trust boundaries |
| [Observability](lanes/observability.md) | Local diagnostic log shape and export flow |
| [Troubleshooting](lanes/troubleshooting.md) | Symptom → cause → fix recipes |
| [Decisions](decisions/README.md) | Architecture Decision Records (ADR ledger) |

Lane files emit only when the project has source evidence to back them. `lanes/architecture.md` and `decisions/README.md` are universal; the rest emit conditionally. Empty-stub files are not created — the absence of a lane file is correct when the project has no content for it.

---

## Lane ownership

Each file owns one lane. When something falls in multiple lanes, the canonical owner is the row in this table; other docs link instead of duplicating.

| File | Owns | Never owns |
|---|---|---|
| `lanes/architecture.md` | Component layout, data flow, file/folder structure, technology choices, source module map | Endpoint contracts, env vars, deploy steps, troubleshooting |
| `lanes/api-reference.md` | Worker route and upstream server calls | Architecture rationale, env values, deploy steps |
| `lanes/configuration.md` | Env var names, defaults, valid values, config files | Endpoint contracts, architecture rationale, deploy commands |
| `lanes/deployment.md` | Build commands, deploy commands, rollback, secret rotation | API contracts, env documentation |
| `lanes/security.md` | Threat model, auth flow, cookie/header policies, secret storage | Per-endpoint request/response detail |
| `lanes/observability.md` | Local log shape, categories, export path | Architecture, troubleshooting recipes |
| `lanes/troubleshooting.md` | Symptom → cause → fix recipes, build-tool quirks, runtime gotchas | Architecture, env vars, deploy steps |
| `decisions/README.md` | ADR index and per-decision rationale | Runbook prose, spec REQs |

---

## REQ backlinks

Every documented feature should reference the spec REQ that defines it. Format: inline `(REQ-X-NNN)` immediately after the feature name in a heading or first sentence.

The link form is preferred: `[(REQ-X-NNN)](../sdd/spec/{domain}.md#req-x-nnn-title-slug)` — `doc-updater` can rewrite plain-text refs to anchored links on the next PR.

---

## Synonym glossary

Vocabulary that appears in multiple forms across the codebase + spec. Single canonical name on the left, common synonyms on the right. This anchor stops drift across REQs, source comments, and docs.

| Canonical term | Synonyms / variants | Where defined |
|---|---|---|
| Browser sign-in bridge | OAuth worker, redirect worker, callback worker | [browser-sign-in.md](../sdd/spec/browser-sign-in.md) |
| Local unlock | Biometric login, biometric gate | [biometric-gate.md](../sdd/spec/biometric-gate.md) |
| Platform share surface | Android share sheet, share intent | [share-intake.md](../sdd/spec/share-intake.md) |
| Remote item | Uploaded file, shortened link, server item | [remote-item-actions.md](../sdd/spec/remote-item-actions.md) |

For domain-specific definitions see [`sdd/spec/glossary.md`](../sdd/spec/glossary.md). This table is for the messier real-world case where two or more names point at the same concept.

---

## Reading order for a new contributor

1. **Start here.** Read this index to understand which lane owns what.
2. **Architecture** (`lanes/architecture.md`) — what the system is and how requests move through it.
3. **API Reference** (`lanes/api-reference.md`) — what callers and upstream services exchange.
4. **Configuration** (`lanes/configuration.md`) — what knobs exist.
5. **Decisions** (`decisions/README.md`) — why the system looks the way it does.
6. **Security**, **Observability**, **Troubleshooting**, **Deployment** — on demand, when working in those areas.

---

## Related

- [Product Specification](../sdd/README.md) — Requirements and design intent
- [Glossary](../sdd/spec/glossary.md) — Canonical term definitions
- [Project README](../README.md) — Project overview and quickstart
- [Changelog](../sdd/spec/changes.md) — Specification history

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
