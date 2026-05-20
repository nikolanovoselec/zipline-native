# Spec change log

Reverse-chronological. Newest first.

## 2026-05-20

- **[sdd-init] Initial spec scaffold from existing codebase.** Import Mode bootstrap. 6 domains, 33 REQs, 5 founding ADRs, 9 constraints. `transition: true` until init-triage drains. `requested_mode_post_transition: unleashed` (deferred). Phase 5 enrichment fell back to in-memory inference (graphify-out/graph.json absent locally; unified global graph polluted with vault content). Phase 6 documentation extraction completed via filesystem fallback.
