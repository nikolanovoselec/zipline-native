# Spec Changes

Semantic changes to the specification. Git history captures diffs; this file captures intent.

Each entry is dated, ≤2 sentences, user-facing only. No commit SHAs. No "verification pass" entries. No spec cleanup or format fixes (those live in git history).

## 2026-06-01

- Initial import scaffold added source-anchored requirements for the existing mobile sharing client and browser sign-in bridge.
- Import Mode is intentionally strict: technical names stay in documentation while requirement bodies describe observable behavior only.
- Triage remains open for legacy code, compatibility fallbacks, remote protection behavior, package naming, README drift, and prior closed scaffold history.

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
