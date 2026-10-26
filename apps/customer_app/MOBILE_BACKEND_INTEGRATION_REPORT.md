# Customer mobile backend integration report

Audit: 26 October 2026. This session owns mobile app directories only. Backend, Admin, schemas, OpenAPI, environment files and shared packages were inspected read-only. No database operations, branch changes, commits or pushes were performed.

## Readiness

**NOT PRODUCTION READY for authenticated bookings.** Public catalog is implemented against mounted backend source and verified with deterministic API tests. No live development URL/data was supplied, so no deployed endpoint or shared database integration was exercised. Do not interpret source-contract verification as a successful live server test.

The requested classification `LIVE API INTEGRATED AND VERIFIED` is deliberately not assigned: transport and catalog tests verify the implementation with fake HTTP responses, not a running backend. Catalog is implemented; live verification is pending. Pending interfaces below are domain boundaries, not finished wire clients.

## Module inventory

| Module | Classification / evidence |
| --- | --- |
| Splash/onboarding | Existing approved UI preserved. |
| Customer registration/login/OTP | Backend mobile routes are mounted, but SMS/provider configuration is still required. Customer sign-in remains fail-closed in production; this phase adds no fake login or token handling. |
| Categories/service listings/search/details | Implemented against verified source contracts; live verification pending. Public browse works independently of authentication. Stable server IDs and server displayOrder; prices are parsed as BigInt paise. |
| Home catalog | Production catalog screen loads published categories/services and includes API-backed package and offer sections. Manual refresh and app resume reload the active section; inactive section caches are invalidated. Existing full home remains a development preview. |
| Popular/featured ranking | NOT IMPLEMENTED: backend provides displayOrder, not a popular/featured contract. |
| Packages/offers | Public GET routes are present in backend source and mapped to typed catalog models/screens. Packages/offers load on first view and are refreshed on pull-to-refresh, toolbar refresh or app resume. Runtime availability still depends on platform API configuration; live verification is pending. |
| Banners | PENDING: no public banner integration in this phase. Existing preview banners remain development-only. |
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
| GET /api/catalog/packages | CatalogRepository.packages; page/limit; only published and eligible records are returned by the backend. |
| GET /api/catalog/offers | CatalogRepository.offers; page/limit; only published offers within their validity window and passing backend relationship checks are returned. |

Envelope: success/data/requestId. Categories/services return items + pagination(page,limit,total,pages); packages/offers return items + pagination(page,limit,hasMore). Service/package/offer prices use backend paise values; service/package duration is displayed from the API. Public category image is image.url; service images, package thumbnails and offer thumbnails use backend media URLs. The UI rejects invalid/non-HTTPS image URLs and shows a neutral placeholder, never a catalog fixture image.

The backend OpenAPI currently documents Admin management endpoints but does not declare these public `/catalog/*` routes. The mobile mapping uses the existing Express route definitions and does not invent or modify backend paths. The platform public-resource router is mounted conditionally with the platform APIs, so package/offer calls also require the backend's operations API and authentication configuration to be enabled. No live backend URL was supplied to verify runtime flags or data. Admin session/cookie/CSRF endpoints cannot be reused as customer identity.

## Environment and architecture

Use the same Node origin used by Admin and Worker; database selection belongs to backend configuration (`hii_beauty_dev`). Mobile never connects to MongoDB.

    flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=https://your-backend.example/api

For Android emulator debug development, explicitly use `http://10.0.2.2:5000/api` when that is the approved local backend. Release/profile transport requires HTTPS. No default production URL, embedded credential or silent fixture fallback exists. Android INTERNET permission is enabled. Local HTTP cleartext is not enabled for release/profile; use HTTPS for profile builds.

The Customer app's `src/debug/AndroidManifest.xml` enables cleartext only for Android debug builds so the emulator can reach a local development server; release/profile manifests are unchanged.

MobileApi validates configuration and relative paths, unwraps the standard envelope, maps network/timeouts/401/403/server errors and retries only safe GETs once for network/timeout/502/503/504. It logs no request body, OTP, token, phone or server-private error. API/client disposal cancels ownership; generation checks ignore obsolete search responses. Obsolete in-flight requests may finish at transport level and are not claimed as per-request cancellation. No authenticated headers/storage were invented.

CustomerBackend defines future customer domain operations. PendingCustomerBackend always throws IntegrationPending. Models: CustomerIdentity, CustomerAddress, CartLine, CheckoutQuote, BookingRequest, CustomerBooking; session/collection enums. CustomerContentBackend adds PublishedPackage, EligibleOffer, PublishedBanner, CustomerNotice and BookingReview domain models. These are mobile domain models, not asserted backend schemas. Financial fields are integer paise; public prices use BigInt to retain decimal-string precision.

## Performance and offline findings

Existing development_home_screen.dart combines catalog models, checkout, profile, tracking and timers in one large stateful file. Local service IDs derive from names and must remain preview-only. Demo tracking timers already dispose on exit; no production tracking timer added. The new catalog uses bounded 20-service pages, 350ms search debounce, invalidation guards, image decode width bounds and Flutter's in-memory image cache. Categories are cached during search and service pagination, and invalidated on manual refresh/app resume to avoid publication staleness. No disk catalog cache or offline business record fallback exists. Network errors show retry, not fake empty success. No before/after device performance measurements were taken.

## Backend team dependency list

1. Customer OTP request/verify with provider, challenge/expiry/rate limiting; customer-scoped session validation/refresh/revocation and approved secure credential transport/storage.
2. Customer profile and owned saved-address CRUD/default; location consent and serviceable area validation.
3. Customer-owned cart, quantity/coupon validation, expiring authoritative quote in integer paise, instant/scheduled availability and conflicts.
4. Idempotent create booking with real number, service snapshots, agreed total, pending payment, history/detail/status/authorized worker data; cancellation and receipt contracts.
5. Confirm runtime mounting/configuration and live payloads for the existing public packages/offers routes; document public catalog routes and DTOs in OpenAPI. Published banners remain a separate integration.
6. Post-service Cash collection and company UPI reconciliation; no Paid status until server confirmation. Read-only payout data remains Worker-scoped.
7. Customer-scoped notifications/reviews and realtime invalidation with authorization/reconnect/event deduplication. Until then only manual/resume catalog refresh is connected.

## Validation instructions and results

Deterministic tests use http MockClient; no integration test touches shared records. Use `flutter pub get`, `flutter analyze`, `flutter test`. Android build: `flutter build apk --profile -t lib/main_prod.dart --dart-define=API_BASE_URL=https://approved-backend/api`. Physical-device/live database validation requires an explicitly approved endpoint and dedicated test identities/data.

The following Phase 1 catalog validation covers source DTO parsing and widget behavior. Live backend/device verification remains pending because no reachable backend URL or Android device/emulator was available in this run. See the Worker App report for Worker-specific audit, pending interfaces and results.

## Executed validation

- flutter pub get: PASSED. Added app-local http dependency; no shared packages changed.
- Full flutter test: PASSED, 73 tests. Includes catalog repository/navigation/widgets, transport/network failures and pending interfaces, production route guards, payment pending, existing responsive layouts and visual capture tests.
- Initial full suite had two stale expectations (home login destination and card choice); updated to current intended behavior and final suite passed.
- Earlier Android profile build attempt with lib/main_prod.dart was interrupted after prolonged Gradle processing/resource contention. The Phase 1 Android debug APK build later succeeded; no profile APK or device/live backend verification is claimed.
- Phase 1 added typed packages/offers parsing and production catalog tabs; focused tests and analyzer results are recorded in this section after execution.
- Static analysis final result is appended separately below.
- git diff --check for mobile directories: PASSED (only line-ending normalization notices).

## Phase 1 catalog integration update

- Full Customer Flutter suite: PASSED, 73 tests.
- Focused catalog repository/navigation suite: PASSED, including packages/offers DTOs, server-provided prices/durations, refresh showing an Admin-side offer change, empty/error/retry states, and HTTPS-only media handling.
- `flutter analyze`: PASSED, no issues.
- Android debug APK: PASSED with `main_prod.dart` and `API_BASE_URL=http://10.0.2.2:5000/api`. Gradle emitted an SDK XML tooling-version warning, but produced the debug APK. Debug-only cleartext access is enabled for a local emulator backend; release/profile still require HTTPS.
- Live backend/device verification: NOT PERFORMED. No Android device or emulator is connected/available, and `http://127.0.0.1:5000/health/ready` did not respond. The endpoint host/runtime configuration and real catalog records therefore remain unverified from this app session.
- Media: no runtime storage/media host configuration was provided for live validation. Backend publishing requires persistent public media; absent or unsupported image URLs render the catalog placeholder.
- Backend contract note: public `/catalog/*` paths are absent from the current OpenAPI document. The existing route source defines them; no backend changes were made.
- Next step: run the existing backend configured for `hii_beauty_dev` with its public platform routes and persistent media storage enabled, connect an Android emulator/device, then launch with its reachable HTTPS API base (or the emulator-only `http://10.0.2.2:5000/api` in debug) and smoke-test categories, category-filtered services, packages, offers and media.

## Modified file inventory

Customer files changed/created in the earlier integration phase:

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

Final static analysis: PASSED, no issues found (exit 0). The latest full suite result is 73 passed. Final readiness remains NOT PRODUCTION READY for authenticated booking workflows. Catalog source integration is complete and deterministically tested; live server verification is outstanding.

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
- Phase 1 catalog changes: apps/customer_app/README.md; apps/customer_app/android/app/src/debug/AndroidManifest.xml; apps/customer_app/lib/features/catalog/catalog_repository.dart; apps/customer_app/lib/features/catalog/catalog_screen.dart; apps/customer_app/test/catalog_repository_test.dart; apps/customer_app/test/catalog_navigation_test.dart.
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
