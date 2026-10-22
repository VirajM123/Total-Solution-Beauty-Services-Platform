# Customer mobile backend integration report

Audit: 21 October 2026. This session owns mobile app directories only. Backend, Admin, schemas, OpenAPI, environment files and shared packages were inspected read-only. No database operations, branch changes, commits or pushes were performed.

## Readiness

**NOT PRODUCTION READY for authenticated bookings.** Public catalog is implemented against mounted backend source and verified with deterministic API tests. No live development URL/data was supplied, so no deployed endpoint or shared database integration was exercised. Do not interpret source-contract verification as a successful live server test.

The requested classification `LIVE API INTEGRATED AND VERIFIED` is deliberately not assigned: transport and catalog tests verify the implementation with fake HTTP responses, not a running backend. Catalog is implemented; live verification is pending. Pending interfaces below are domain boundaries, not finished wire clients.

## Module inventory

| Module | Classification / evidence |
| --- | --- |
| Splash/onboarding | Existing approved UI preserved. |
| Customer registration/login/OTP | DEVELOPMENT PREVIEW ONLY in development + debug. Production remains fail-closed. No customer OTP/session routes mounted; no token stored or generated. |
| Categories/service listings/search/details | Implemented against verified source contracts; live verification pending. Public browse works independently of authentication. Stable server IDs and server displayOrder; service amounts parsed as BigInt paise from decimal strings. |
| Home catalog | API browsing added using existing brand colors/font/cards. Existing full home is retained as development preview. Published services can refresh without a new APK. |
| Popular/featured ranking | NOT IMPLEMENTED: backend provides displayOrder, not a popular/featured contract. |
| Packages/offers/banners | API CLIENT READY, BACKEND PENDING: typed CustomerContentBackend/PendingCustomerContentBackend boundaries; resource router source exists but is not mounted. No production routes or wire parsers guessed. Existing fixture presentations remain DEVELOPMENT PREVIEW ONLY. |
| Profile/edit/addresses/default selection | API CLIENT READY, BACKEND PENDING: CustomerBackend interface and fail-closed PendingCustomerBackend. Preview uses app-memory sample addresses/profile. |
| Cart/quantities/coupon/quote | API CLIENT READY, BACKEND PENDING: typed cart/expiring server quote boundaries. Preview prices/discounts/fees never feed the public catalog or a real booking. |
| Instant/scheduled availability/area/capacity | API CLIENT READY, BACKEND PENDING: availability boundary. Production submission absent; local slots are DEVELOPMENT PREVIEW ONLY. |
| Booking creation/summary/confirmation | API CLIENT READY, BACKEND PENDING: BookingRequest includes quote/address/slot IDs, Cash/UPI and idempotency key. No pending adapter can return success. Preview confirmation stays explicitly sample; cart preserved. |
| History/details/tracking | API CLIENT READY, BACKEND PENDING: scoped read interfaces. Timers, worker identity and route illustration in existing home are DEVELOPMENT PREVIEW ONLY; no real location claimed. |
| Payments | API CLIENT READY, BACKEND PENDING: collection status model; Cash/UPI after service. Card removed from preview selection, payment timing always after service. No gateway, QR transaction, collection or Paid mutation implemented. |
| Notifications/reviews | API CLIENT READY, BACKEND PENDING: notifications/review domain interfaces fail closed. Existing UI remains DEVELOPMENT PREVIEW ONLY. |
| Realtime/push | NOT IMPLEMENTED: socketServer/socketAuth are placeholders. Catalog refreshes manually and on app resume; no global subscriptions, background ringing or fake socket events. |

## Verified source endpoint mapping

Inspected backend/src/app.js and backend/src/modules/services/catalog.routes.js. Mounted prefix `/api/catalog`:

| HTTP route | Mobile mapping |
| --- | --- |
| GET /api/catalog/categories | CatalogRepository.categories; page/limit, every category page fetched. |
| GET /api/catalog/services | CatalogRepository.services; page/limit/search/categoryId; backend default displayOrder ascending. |
| GET /api/catalog/services/:serviceId | CatalogRepository.service; refetches authoritative record, handles unpublished/archived errors. |

Envelope: success/data/requestId. List data: items + pagination(page,limit,total,pages). Public category image is image.url; service thumbnail is a URL and images contain URL objects. Media must be persistent public HTTPS according to the backend. Mobile rejects invalid/non-HTTPS image URLs and shows a neutral placeholder, never a hardcoded service photograph.

Source files under backend/src/platform are not proof that a route is callable: no public packages/offers/banners mount was present at audit. Admin session/cookie/CSRF endpoints cannot be reused as customer identity.

## Environment and architecture

Use the same Node origin used by Admin and Worker; database selection belongs to backend configuration (`hii_beauty_dev`). Mobile never connects to MongoDB.

    flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=https://your-backend.example/api

For Android emulator debug development, explicitly use `http://10.0.2.2:5000/api` when that is the approved local backend. Release/profile transport requires HTTPS. No default production URL, embedded credential or silent fixture fallback exists. Android INTERNET permission is enabled. Local HTTP cleartext is not enabled for release/profile; use HTTPS for profile builds.

MobileApi validates configuration and relative paths, unwraps the standard envelope, maps network/timeouts/401/403/server errors and retries only safe GETs once for network/timeout/502/503/504. It logs no request body, OTP, token, phone or server-private error. API/client disposal cancels ownership; generation checks ignore obsolete search responses. Obsolete in-flight requests may finish at transport level and are not claimed as per-request cancellation. No authenticated headers/storage were invented.

CustomerBackend defines future customer domain operations. PendingCustomerBackend always throws IntegrationPending. Models: CustomerIdentity, CustomerAddress, CartLine, CheckoutQuote, BookingRequest, CustomerBooking; session/collection enums. CustomerContentBackend adds PublishedPackage, EligibleOffer, PublishedBanner, CustomerNotice and BookingReview domain models. These are mobile domain models, not asserted backend schemas. Financial fields are integer paise; public prices use BigInt to retain decimal-string precision.

## Performance and offline findings

Existing development_home_screen.dart combines catalog models, checkout, profile, tracking and timers in one large stateful file. Local service IDs derive from names and must remain preview-only. Demo tracking timers already dispose on exit; no production tracking timer added. The new catalog uses bounded 20-service pages, 350ms search debounce, invalidation guards, image decode width bounds and Flutter's in-memory image cache. Categories are cached during search and service pagination, and invalidated on manual refresh/app resume to avoid publication staleness. No disk catalog cache or offline business record fallback exists. Network errors show retry, not fake empty success. No before/after device performance measurements were taken.

## Backend team dependency list

1. Customer OTP request/verify with provider, challenge/expiry/rate limiting; customer-scoped session validation/refresh/revocation and approved secure credential transport/storage.
2. Customer profile and owned saved-address CRUD/default; location consent and serviceable area validation.
3. Customer-owned cart, quantity/coupon validation, expiring authoritative quote in integer paise, instant/scheduled availability and conflicts.
4. Idempotent create booking with real number, service snapshots, agreed total, pending payment, history/detail/status/authorized worker data; cancellation and receipt contracts.
5. Mounted published packages/offers/banners DTOs and public persistent media URLs, eligibility and ordering rules.
6. Post-service Cash collection and company UPI reconciliation; no Paid status until server confirmation. Read-only payout data remains Worker-scoped.
7. Customer-scoped notifications/reviews and realtime invalidation with authorization/reconnect/event deduplication. Until then only manual/resume catalog refresh is connected.

## Validation instructions and results

Deterministic tests use http MockClient; no integration test touches shared records. Use `flutter pub get`, `flutter analyze`, `flutter test`. Android build: `flutter build apk --profile -t lib/main_prod.dart --dart-define=API_BASE_URL=https://approved-backend/api`. Physical-device/live database validation requires an explicitly approved endpoint and dedicated test identities/data.

Execution results and complete modified-file inventory are recorded below after validation completes. See the Worker App report for Worker-specific audit, pending interfaces and results.

## Executed validation

- flutter pub get: PASSED. Added app-local http dependency; no shared packages changed.
- Full flutter test: PASSED, 71 tests. Includes catalog repository/navigation/widgets, transport/network failures and pending interfaces, production route guards, payment pending, existing responsive layouts and visual capture tests.
- Initial full suite had two stale expectations (home login destination and card choice); updated to current intended behavior and final suite passed.
- Android profile build attempted with lib/main_prod.dart: interrupted after prolonged Gradle processing/resource contention. SDK XML tooling-version warning was emitted. No completed APK is claimed. Device/live backend validation was not performed.
- Static analysis final result is appended separately below.
- git diff --check for mobile directories: PASSED (only line-ending normalization notices).

## Modified file inventory

Customer files changed/created:

- README.md; MOBILE_BACKEND_INTEGRATION_REPORT.md; docs/checkout_payment_contract.md.
- android/app/src/main/AndroidManifest.xml (Internet permission).
- pubspec.yaml and pubspec.lock (http dependency).
- lib/app/app_router.dart; lib/app/route_names.dart; lib/core/config/app_config.dart.
- lib/core/api/mobile_api.dart.
- lib/features/catalog/catalog_repository.dart and catalog_screen.dart.
- lib/features/login/login_screen.dart (public browse navigation).
- lib/features/booking/checkout_models.dart; lib/features/home/development_home_screen.dart (after-service Cash/UPI policy).
- lib/integration/customer_backend.dart and customer_content.dart (pending domain interfaces/models).
- test/customer_flow_test.dart; test/mobile_api_test.dart; test/catalog_repository_test.dart; test/catalog_navigation_test.dart.

Worker modified files are listed in ../worker_app/MOBILE_BACKEND_INTEGRATION_REPORT.md. No file outside the two authorized mobile app directories was edited by this mobile session.

Final static analysis: PASSED, no issues found (exit 0). The final brace-only lint correction changed no behavior; full suite result remains 71 passed. Final readiness remains NOT PRODUCTION READY for authenticated booking workflows. Catalog source integration is complete and deterministically tested; live server verification is outstanding.

Feature classifications use pending domain boundaries where contracts are missing; none is represented as a successful live API verification. No feature required a new business decision: the current after-service Cash/UPI policy is applied. Backend contract/provider/configuration dependencies are explicitly listed above.

## Final complete mobile file inventory

- apps/customer_app/MOBILE_BACKEND_INTEGRATION_REPORT.md
- apps/customer_app/lib/core/api/mobile_api.dart
- apps/customer_app/lib/features/catalog/catalog_repository.dart
- apps/customer_app/lib/features/catalog/catalog_screen.dart
- apps/customer_app/lib/integration/customer_backend.dart
- apps/customer_app/lib/integration/customer_content.dart
- apps/customer_app/test/catalog_navigation_test.dart
- apps/customer_app/test/catalog_repository_test.dart
- apps/customer_app/test/mobile_api_test.dart
- apps/customer_app/README.md
- apps/customer_app/android/app/src/main/AndroidManifest.xml
- apps/customer_app/docs/checkout_payment_contract.md
- apps/customer_app/lib/app/app_router.dart
- apps/customer_app/lib/app/route_names.dart
- apps/customer_app/lib/core/config/app_config.dart
- apps/customer_app/lib/features/booking/checkout_models.dart
- apps/customer_app/lib/features/home/development_home_screen.dart
- apps/customer_app/lib/features/login/login_screen.dart
- apps/customer_app/pubspec.lock
- apps/customer_app/pubspec.yaml
- apps/customer_app/test/customer_flow_test.dart
