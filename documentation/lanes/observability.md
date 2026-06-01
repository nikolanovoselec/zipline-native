# Observability

**Audience:** Developers, Operators

The project uses local, opt-in diagnostic logging inside the app rather than remote analytics or telemetry.

---

## Diagnostic log shape

| Field | Meaning | Source |
|---|---|---|
| `timestamp` | Local ISO timestamp for the event | `DebugLog.timestamp` <!-- @impl: lib/services/debug_service.dart::timestamp --> |
| `category` | Feature area such as auth, upload, intent, HTTP, or debug | `DebugLog.category` <!-- @impl: lib/services/debug_service.dart::category --> |
| `level` | Severity label | `DebugLog.level` <!-- @impl: lib/services/debug_service.dart::level --> |
| `message` | Human-readable event summary | `DebugLog.message` <!-- @impl: lib/services/debug_service.dart::message --> |
| `data` | Optional structured payload | `DebugLog.data` <!-- @impl: lib/services/debug_service.dart::data --> |

## Diagnostic signals

| Signal | Producer | Consumer | Implements |
|---|---|---|---|
| Auth events | `logAuth` helper <!-- @impl: lib/services/debug_service.dart::logAuth --> | Sign-in and session debugging | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally) |
| Upload events | `logUpload` helper <!-- @impl: lib/services/debug_service.dart::logUpload --> | Upload progress and failure debugging | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally) |
| Intent events | `logIntent` helper <!-- @impl: lib/services/debug_service.dart::logIntent --> | Share-intent and content URI debugging | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally) |
| HTTP events | `logHttp` helper <!-- @impl: lib/services/debug_service.dart::logHttp --> | Server request debugging | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally) |
| Error events | `logError` helper <!-- @impl: lib/services/debug_service.dart::logError --> | Exception and stack trace capture | [REQ-DIAG-002](../../sdd/spec/diagnostics.md#req-diag-002-store-and-filter-logs-locally) |

## Export path

1. User opens the debug screen.
2. The screen refreshes the selected category and severity filters. <!-- @impl: lib/screens/debug_screen.dart::_refreshLogs -->
3. Export writes the filtered log payload to an app document file. <!-- @impl: lib/services/debug_service.dart::exportLogsToFile -->
4. The file is shared through the platform share surface. <!-- @impl: lib/screens/debug_screen.dart::_shareLogFile -->
5. If sharing fails, the file content is copied to clipboard as fallback. <!-- @impl: lib/screens/debug_screen.dart::Clipboard -->

## Related Documentation

- [Diagnostics requirements](../../sdd/spec/diagnostics.md)
- [Troubleshooting](troubleshooting.md)
