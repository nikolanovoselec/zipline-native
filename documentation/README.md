# Documentation

How the system works. Companion to [`sdd/`](../sdd/) which carries what the system does and why.

**Audience:** Developers

## Files

| File | Contents |
|---|---|
| [architecture.md](architecture.md) | Component map, source module map, request lifecycles, data flow, cross-cutting concerns |
| [api-reference.md](api-reference.md) | Worker endpoint contract + upstream Zipline endpoints the app depends on |
| [configuration.md](configuration.md) | Env vars, build-time constants, signing config |
| [deployment.md](deployment.md) | App and Worker build + deploy steps |
| [security.md](security.md) | Threat model, auth flow, secret storage |
| [troubleshooting.md](troubleshooting.md) | Symptom → cause → fix recipes |
| [decisions/README.md](decisions/README.md) | Architecture decision records (ADRs) |

## Lane boundaries

- Implementation rationale lives in source comments, not here.
- Acceptance criteria (`must`, `shall`) live in `sdd/`, not here.
- Decisions and trade-offs live in `decisions/README.md`, not in other lane files.

## Related

- [Spec (`sdd/`)](../sdd/README.md) — Actors, REQs, domains
