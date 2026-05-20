# Init triage

Items the Import Mode scaffold could not resolve with high confidence. Each entry carries Context + Recommendation. User reviews via Resume Mode (`/sdd init`).

---

## TRIAGE-001: Upload retry-backoff timing

**Status:** open
**Target REQ:** [REQ-UPLOAD-004](upload.md#req-upload-004-auto-retry-on-connectivity-recovery)

**Context:** `lib/services/upload_queue_service.dart` retries pending uploads on connectivity recovery but the backoff between retries is not consistently parameterised. The 3-retry cap [CON-REL-002] is hard-coded; the inter-retry delay reads as immediate (no `Future.delayed` between attempts). No git history explains whether immediate retry was deliberate (mobile connectivity recovers in bursts) or an oversight.

**Recommendation:** Add `inter_retry_delay_ms` constant defaulting to 2000ms (2s) between attempts within a recovery burst, capped at 3 total attempts before manual-retry state. **Rationale:** burst recovery is real but back-to-back failures on the same upload usually mean a deeper problem (file gone, server down); a brief delay separates transient burst-loss from sustained failure without harming UX.

---

## TRIAGE-002: Worker handles Zipline non-2xx exchange response

**Status:** open
**Target REQ:** [REQ-OAUTH-001](oauth-worker.md#req-oauth-001-callback-exchange)

**Context:** `cloudflare-oauth-redirect/src/worker.js` extracts the session cookie from the Zipline exchange response assuming success. The code logs the status but does not branch on it. A non-2xx response from Zipline (expired code, instance down) currently produces an undefined session cookie passed through to the redirect URL.

**Recommendation:** When Zipline returns non-2xx during the exchange, the Worker should respond HTTP 502 with body `{"error":"upstream_failed","status":<code>}` instead of redirecting with a malformed session. **Rationale:** the deep-link redirect is the app's contract trigger; redirecting with no session yields a confusing client-side null state. A 502 propagates the failure cleanly.

---

## TRIAGE-003: Biometric availability check timing

**Status:** open
**Target REQ:** [REQ-AUTH-003](auth.md#req-auth-003-biometric-unlock)

**Context:** `lib/services/biometric_service.dart` checks `canCheckBiometrics` once at app start. If the user enrols a biometric mid-session (background → Settings → return), the check is stale until next launch.

**Recommendation:** Re-check `canCheckBiometrics` every time the login screen mounts, not only at app start. **Rationale:** mid-session enrolment is uncommon but real (user pairs a phone fresh out of the box); the re-check is a single platform call and avoids confusing "biometric unavailable" messaging on a device that has biometrics.

---

## TRIAGE-004: iOS support claim in README vs. actual

**Status:** open
**Target REQ:** none (cross-cutting; potentially CON-* or a new domain)

**Context:** README claims "iOS: Should work, but I don't own an iPhone." Source has zero `ios/` directory content beyond the default Flutter scaffold. No CI run targets iOS. No tests run on iOS.

**Recommendation:** Drop the iOS claim from README OR add a CON-PLATFORM-001 constraint stating "Android-only; iOS/desktop builds compile but are not exercised in CI." Lean toward dropping the README claim — the constraint approach mid-codebases the platform claim and the spec already states "Android-only" in design principle 5. **Rationale:** the README claim is aspirational, not a contract; better to remove the false promise than encode it.

---
