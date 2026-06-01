# Glossary

Canonical definitions for domain-specific terms used across the spec, code, and documentation. Use these terms consistently everywhere.

| Term | Definition |
|------|-----------|
| **Activity** | A locally remembered upload or shortened link shown back to the user after a successful operation. |
| **Browser sign-in bridge** | The deployed helper that receives the external browser return and opens the app with the session result. |
| **Content URI** | A platform-provided reference to shared content that must be copied into app-owned storage before upload. |
| **Local unlock** | Device-level verification used after login so the app can gate access without asking for the password again. |
| **Platform share surface** | The operating-system UI that lets another app send files or text to this app. |
| **Remote item** | A file or shortened link that exists on the user's configured sharing server. |
| **Session** | The stored authenticated state used to authorize later user actions. |
| **Short link** | A server-created compact link that redirects to an original destination. |
| **Upload task** | A queued unit of work that tracks one file's pending, active, paused, completed, or failed state. |

## Pi runtime compatibility

This transformed Pi skill uses Pi-native tool names and workflows:

- Use Bash/Read/Grep/Find/Edit/Write directly; do not assume context-mode `ctx_*` tools exist.
- Use `graphify_query`, `graphify_path`, and `graphify_explain` directly. If a native graphify tool resolves the workspace root instead of the active repo, use the CLI fallback with `--graph <repo>/graphify-out/graph.json`.
- Use Pi's `Agent` tool for subagents. For Plan Mode, invoke the `Plan` agent or produce an explicit plan and wait for user approval before source edits.
