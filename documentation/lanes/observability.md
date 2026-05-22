<!-- doc-discipline: log shape, categories, levels, dashboards. No architecture, no troubleshooting recipes. -->

# Observability

**Audience:** Developers

In-app diagnostic log capture, categories, levels, and the export format.

---

## DebugService Log Shape

**Implements:** [REQ-LOG-001](../../sdd/spec/debug-diagnostics.md#req-log-001-categorized-ring-buffer)

Each log entry is a `DebugLog` with the following fields: <!-- @impl: lib/services/debug_service.dart::DebugLog -->

| Field | Type | Description |
|---|---|---|
| `timestamp` | ISO-8601 string | Captured at write time via `DateTime.now().toIso8601String()` |
| `category` | string | Subsystem (see table below) |
| `level` | string | `INFO`, `WARNING`, or `ERROR` |
| `message` | string | Human-readable line |
| `data` | `Map<String, dynamic>?` | Structured metadata; may include `error.toString()` and `stackTrace.toString()` when the entry came from `logError` |

## Categories

| Category | Used by |
|---|---|
| `AUTH` | `AuthService` login/logout/migration paths <!-- @impl: lib/services/debug_service.dart::logAuth --> |
| `OAUTH` | `OAuthService` URL build, callback, state validation <!-- @impl: lib/services/oauth_service.dart::OAuthService -->|
| `LOGIN` | `SimpleLoginScreen` lifecycle <!-- @impl: lib/screens/simple_login_screen.dart::_SimpleLoginScreenState --> |
| `INTENT` | `IntentService` MethodChannel calls + URI inference <!-- @impl: lib/services/intent_service.dart::IntentService --> |
| `UPLOAD` | `FileUploadService` + `UploadQueueService` <!-- @impl: lib/services/debug_service.dart::logUpload --> |
| `FILES` | File delete + password attempts <!-- @impl: lib/services/file_upload_service.dart::deleteFile --> |
| `URLs` | Short-URL delete and shortener fallbacks <!-- @impl: lib/services/file_upload_service.dart::deleteUrl --> |
| `ACTIVITY` | `ActivityService` add/load/clear <!-- @impl: lib/services/activity_service.dart::ActivityService --> |
| `DEBUG` | `DebugService` itself (initialize, clearLogs) <!-- @impl: lib/services/debug_service.dart::initialize --> |

## Capture Toggle

**Implements:** [REQ-LOG-002](../../sdd/spec/debug-diagnostics.md#req-log-002-opt-in-toggle-persists-across-sessions)

`DebugService._debugLogsEnabled` is loaded from `SharedPreferences` key `debug_logs_enabled` at `initialize()` and defaults to `false`. When `false`, `log()` returns immediately and no event enters the ring buffer. The user flips it from the Settings screen. <!-- @impl: lib/services/debug_service.dart::log -->

## Ring-Buffer Bound

The buffer holds at most `_maxLogs = 5000` entries. When full, the oldest entry is removed before a new one is appended. <!-- @impl: lib/services/debug_service.dart::_maxLogs = 5000 -->

## JSON Export

**Implements:** [REQ-LOG-004](../../sdd/spec/debug-diagnostics.md#req-log-004-json-export-to-documents-directory)

`exportLogsToFile(category, level)` writes the filtered logs to `<appDocumentsDir>/zipline_debug_logs_<timestampMs>.json`. <!-- @impl: lib/services/debug_service.dart::exportLogsToFile -->

Envelope:

```json
{
  "exportTimestamp": "2026-05-22T09:17:01.123Z",
  "totalLogs": 42,
  "filters": { "category": "UPLOAD", "level": null },
  "logs": [
    { "timestamp": "...", "category": "UPLOAD", "level": "ERROR", "message": "...", "data": { "error": "...", "stackTrace": "..." } }
  ]
}
```

The debug screen surfaces the resulting file via the system share sheet so the user can attach it to a bug report.

## What is NOT captured

- Remote telemetry: nothing leaves the device unless the user manually exports
- Crash reports: no Firebase Crashlytics or Sentry wiring
- Performance traces: no `dart:developer` Timeline integration
- Network request bodies: only summarised metadata makes it into logs

---

## Related Documentation

- [Troubleshooting](troubleshooting.md) — Recipes that reference debug logs
- [Architecture](architecture.md) — Where DebugService is wired into the service locator
