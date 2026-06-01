# Link Shortening

This domain covers converting user-provided or shared text into shorter server-managed links.

### REQ-LINK-001: Create short links from user input

**Intent:** The user can enter or share a link and receive a shorter shareable link from the configured server.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface trims and normalizes link input before submission. <!-- @impl: lib/screens/home_screen.dart::_normalizeUrl -->
2. Empty link input shows a retryable error instead of sending a request. <!-- @impl: lib/screens/home_screen.dart::_shortenUrl -->
3. The link service rejects invalid link formats before sending a request. <!-- @impl: lib/services/file_upload_service.dart::isValidUrl -->
4. The link service includes request credentials with the shortening request. <!-- @impl: lib/services/file_upload_service.dart::getAuthHeaders -->
5. The link service normalizes supported response shapes into one short-link result. <!-- @impl: lib/services/file_upload_service.dart::shortenUrl -->

**Notes:** Support-policy intent was lost during SDD transition; see [TRIAGE-002](../../sdd/spec/.init-triage.md#triage-002-short-link-compatibility-cascade-needs-a-support-policy-decision).

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P1

**Dependencies:** [REQ-SESS-003](server-session.md#req-sess-003-provide-request-credentials-for-server-actions)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-LINK-002: Support optional custom labels

**Intent:** The user can request a custom label for a shortened link when the server accepts one.

**Applies To:** User

**Acceptance Criteria:**

1. The home surface passes a non-empty custom label to the link service. <!-- @impl: lib/screens/home_screen.dart::_customSlugController -->
2. The link service includes the custom label only when one was provided. <!-- @impl: lib/services/file_upload_service.dart::customSlug -->
3. Batch shortening can derive per-link labels from a shared prefix. <!-- @impl: lib/services/file_upload_service.dart::shortenMultipleUrls -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow)

**Priority:** P2

**Dependencies:** [REQ-LINK-001](#req-link-001-create-short-links-from-user-input)

**Verification:** Source anchor

**Status:** Implemented

---

### REQ-LINK-003: Store and share successful short links

**Intent:** Successful shortened links are remembered and handed back to the user for immediate sharing.

**Applies To:** User

**Acceptance Criteria:**

1. A successful shortened link is saved to recent activity. <!-- @impl: lib/screens/home_screen.dart::url_shortening -->
2. The link form clears after a successful shortening action. <!-- @impl: lib/screens/home_screen.dart::_urlController -->
3. The resulting short link is copied and shared through the common result path. <!-- @impl: lib/screens/home_screen.dart::_copyShareAndNotify -->
4. Link-shortening failures show a retryable error path. <!-- @impl: lib/screens/home_screen.dart::cleanError -->

**Constraints:** [CON-UX-001](constraints.md#con-ux-001-preserve-share-first-flow), [CON-REL-001](constraints.md#con-rel-001-keep-user-visible-work-recoverable)

**Priority:** P1

**Dependencies:** [REQ-ACT-001](activity-log.md#req-act-001-persist-recent-activity), [REQ-LINK-001](#req-link-001-create-short-links-from-user-input)

**Verification:** Source anchor

**Status:** Implemented

---

_Verification: code-only (no automated coverage)._
