# Worker mobile backend integration report

Audited 21 October 2026. Worker app only; backend/Admin/shared files and database unchanged.

## Readiness and verified contracts

Production is NOT READY. backend/src/app.js mounts Admin auth, catalog and media only. No authenticated worker self-service endpoints exist. Admin cookies require active Admin identity; generic Admin workers/assignments/settlements resources must not be used as worker APIs. No worker endpoint is LIVE API INTEGRATED AND VERIFIED. No guessed route, server response, OTP verification, approval or payment success is introduced.

## Module inventory

| Modules | Audit / status |
| --- | --- |
| Splash, login, OTP | DEVELOPMENT PREVIEW ONLY. Fixed code debug flow. Now requires explicit WORKER_DEVELOPMENT_PREVIEW=true plus debug mode. Default production login calls PendingWorkerApi and shows the integration error. Indian mobile validation retained. |
| Registration, personal/professional details, skills/areas | DEVELOPMENT PREVIEW ONLY: secure local drafts/profile, static skills, local photo. Production registration navigation blocked. WorkerApplicationApi typed seam is API CLIENT READY, BACKEND PENDING. |
| Documents, review, submission | DEVELOPMENT PREVIEW ONLY: picker and review, no upload/submission. Application seam requires private server upload handle and stable service/area IDs; no public identity URLs or guessed serialization. |
| Approval pending/rejected/approved/suspended | Existing status screen receives local enum, default preview. WorkerIdentity typed approval model is API CLIENT READY, BACKEND PENDING; only approved identity mayWork. No local profile grants production access. |
| Dashboard, upcoming/active bookings, booking details, service history | DEVELOPMENT PREVIEW ONLY: previewWorkerOrders and secure local demo booking sessions. Home fails closed and skips local profile load without explicit preview. |
| Online/offline | API CLIENT READY, BACKEND PENDING: typed availability read/update returning actual server state; UI remains preview. |
| Booking offers, assigned jobs, accept/reject/expiry | API CLIENT READY, BACKEND PENDING: paginated assignment records and typed transition actions with idempotency key. Existing UI is preview. Server ownership/expiry/concurrency/rejection validation pending. |
| Travel, arrival, OTP, service execution/completion | API CLIENT READY, BACKEND PENDING: typed actions; no real transition or OTP verification claimed. |
| Payment after service | API CLIENT READY, BACKEND PENDING: pending/verified collection and integer amountDuePaise. Cash command seam only; no client UPI paid method. Existing demo marker remains separate from payment status. |
| Daily payouts | API CLIENT READY, BACKEND PENDING: read-only settlement page with date/count/earnings/adjustments/net/status/reference in integer paise. No settle command. Existing payout data remains preview. |
| Schedule/leave | DEVELOPMENT PREVIEW ONLY: local secure leave repository. Typed wire DTOs NOT IMPLEMENTED pending backend contract. |
| Notifications/job alerts | DEVELOPMENT PREVIEW ONLY: local records. Push/repeated background alerts NOT IMPLEMENTED; no provider configured. |
| Profile/settings/security/support | DEVELOPMENT PREVIEW ONLY: secure local profile/UI settings. Permitted edits/preferences/support contracts NOT IMPLEMENTED. |

## Architecture and configuration

lib/integration defines WorkerAuthApi, WorkerOperationsApi, WorkerApplicationApi and pending implementations; WorkerIdentity, WorkerPage, WorkerAssignmentRecord, WorkerCollectionRecord, WorkerSettlementRecord and WorkerApplicationInput. These are domain interfaces, not verified wire DTOs or completed HTTP integrations. Missing operations always fail with WorkerIntegrationPending; never substitute fixtures. Login uses the pending auth implementation. No client-held authenticated session exists; existing secure storage is local preview data only.

WorkerEnvironment.apiOrigin validates API_BASE_URL, rejects credentials/query/fragment, and requires HTTPS for profile/release. Use the same API_BASE_URL convention as Customer: full backend API base including /api (for example https://host.example/api). The apiOrigin getter currently validates that base without making requests; worker transport remains pending. No MongoDB access exists. Networking serialization, timeout/retry, connectivity, cancellation and authenticated storage integration remain pending because no worker auth/wire contract exists.

Default debug and release builds fail closed. Explicit UI preview:

    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api --dart-define=WORKER_DEVELOPMENT_PREVIEW=true

Profile/release cannot activate this flag. Registration OTP/review/home guards use this policy. Existing main_dev/main_prod remain placeholders; use main.dart. No sensitive tokens/credentials are embedded.

## Backend team dependencies

1. Worker OTP request/verify provider, expiry/rate limits; session lookup/refresh/revoke, worker scope and documented secure session transport/storage.
2. Authenticated private document upload/finalization; idempotent registration with stable catalog/service-area IDs, real application reference and pending approval; approval/rejection/suspension read.
3. Worker-scoped dashboard, paginated offers/assignments/history/detail and notifications, exposing only assigned customer data.
4. Availability/schedule/leave with active-job restrictions.
5. Authoritative accept/reject/travel/arrival/OTP/start/complete state machine with ownership, expiry, concurrent assignment, idempotency and mandatory rejection reason checks.
6. Outstanding customer amount, authorized cash collection, approved company UPI destination and server reconciliation; pending until confirmed.
7. Read-only settlement list/detail including integer paise earnings/adjustments/net, booking count/date/status/reference.
8. Permitted profile/photo/preferences/support edits; Admin-controlled verification fields.
9. Worker-authenticated scoped realtime invalidation/event IDs or approved polling contracts. socketAuth/socketServer currently placeholders. No global subscriptions or fake tracking added.

## Errors, realtime and performance

Login shows pending integration errors directly. No worker production requests exist to retry/poll, and no failed API silently switches to mock data. Resume refetch, network reconnect, realtime, push and background ringing remain pending verified authorization/contracts. No promise of continuous background behavior.

Existing bookings/history use lazy ListView.separated. Timers/animation controllers have disposal handling. Existing approved image UI preserved. Disabled preview avoids local profile I/O at home. Device profiling unavailable; no numerical performance claim. Catalog-backed skills, remote image caching/decoding and long notifications pagination remain follow-up work.

## Testing

Added deterministic worker_api_contract_test: preview opt-in, pending/rejected/approved/suspended identities, all missing auth/availability/assignment actions, pending collection/payout failure, immutable settlement pages and integer paise. Existing UI tests require explicit preview flag when testing demo screens. No shared-record/network/destructive test performed.

Commands/results will be appended after execution.

## Executed validation and changed files

- pub get: passed; SDK-pinned resolution changed four transitive lockfile versions.
- Initial analyze: 24 info diagnostics, no errors/warnings; the one new environment brace diagnostic was fixed. Final analyze pending.
- Initial full preview test suite: 58 passed, one stale bookings-header expectation failed. Updated test expectation to actual existing UI header. Final full suite pending.
- Default configuration targeted tests: 6 passed, including fail-closed login even with demoEnabled=true. Five new API contract tests also passed in preview mode.
- Android profile build attempted; Kotlin incremental daemon reported cache failure involving cross-drive source/cache roots, fallback compiler still running at this update.

Changed app files: README.md, pubspec.lock, this report; lib/integration/worker_environment.dart, worker_api.dart, worker_application_api.dart; app/worker_app.dart; home/worker_home_screen.dart; login/worker_login_screen.dart; otp/worker_otp_screen.dart; registration personal/professional/mobile OTP/email OTP/review screens; test/worker_api_contract_test.dart, worker_production_auth_test.dart, worker_bookings_screen_test.dart.

Build outcome: Android profile command exited 1 after a graceful Ctrl+C request because concurrent Gradle builds exhausted responsiveness. Kotlin incremental daemon reported cache cross-drive root failure and fallback compilation before interruption; no verified APK produced. Source tests/analyze continued independently.

Final analyzer: completed with 23 existing info diagnostics (exit 1 due lint infos), no errors or warnings. New integration code has no analyzer diagnostics.

Final full preview suite: `flutter test --no-pub --dart-define=WORKER_DEVELOPMENT_PREVIEW=true` PASSED: 59 tests, 1 intentionally skipped default-mode auth test. That default-mode auth test passed separately with the API contract tests (6/6) without preview flag. Existing bookings test aligned with current header, rich-text aggregate customer payable and horizontal filter scrolling; implementation UI unchanged. Final `git diff --check -- apps/worker_app` passed. Generated Kotlin session marker removed.

## Final complete mobile file inventory

- apps/worker_app/MOBILE_BACKEND_INTEGRATION_REPORT.md
- apps/worker_app/lib/integration/worker_api.dart
- apps/worker_app/lib/integration/worker_application_api.dart
- apps/worker_app/lib/integration/worker_environment.dart
- apps/worker_app/test/worker_api_contract_test.dart
- apps/worker_app/test/worker_production_auth_test.dart
- apps/worker_app/README.md
- apps/worker_app/lib/app/worker_app.dart
- apps/worker_app/lib/features/home/worker_home_screen.dart
- apps/worker_app/lib/features/login/worker_login_screen.dart
- apps/worker_app/lib/features/otp/worker_otp_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_application_status_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_document_verification_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_personal_details_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_professional_details_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_registration_email_otp_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_registration_mobile_otp_screen.dart
- apps/worker_app/lib/features/registration/screens/worker_review_submit_screen.dart
- apps/worker_app/pubspec.lock
- apps/worker_app/test/worker_bookings_screen_test.dart
