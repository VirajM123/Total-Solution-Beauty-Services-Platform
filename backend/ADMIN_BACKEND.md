# Hi Beauty admin backend

This implementation extends the existing Express backend with final admin-owned assignment, private product evidence, evidence-gated OTP start, and a server-timed extension decision flow. Existing worker-offer endpoints remain available behind `LEGACY_WORKER_OFFERS_ENABLED`; the default is disabled.

## Local configuration

The ignored `backend/.env` contains the supplied development database connection and a generated session secret. Never copy this file into the frontend or commit it. Money uses integer paise; report dates use Asia/Kolkata boundaries.

1. Run `npm.cmd test` in backend. Its preload explicitly removes the live MongoDB URI and disables feature flags for every test process.
2. Create the first administrator through `npm.cmd run admin:bootstrap` in a local terminal. Supply a real name, email, international mobile number and a unique password. Keep catalog activation false during this existing bootstrap procedure.
3. After bootstrap, set `ADMIN_CATALOG_API_ENABLED=true` and `ADMIN_OPERATIONS_API_ENABLED=true` in backend/.env and restart `npm.cmd start`.
4. Run `npm.cmd run dev` in the admin frontend. Its ignored `.env.local` selects backend mode and `http://localhost:5000/api/v1`.
5. Sign in. Cookie sessions, CSRF and server permissions protect mutations. Demo records are not used in backend mode.

No default administrator or default password is shipped. All 37 existing database collections were inspected without modifying business records. No schema validators or indexes were changed.

## Implemented admin workflows

- Existing authentication/session/logout and permission enforcement.
- Existing category/service CRUD and publication validation.
- Service-area editor backed by structured area records.
- Packages, banners, coupons, settings, support and roles through existing resource APIs.
- Customer creation with unverified contact identity, profile updates, suspension/session revocation and structured addresses.
- Worker creation with private identity-document references, approval/rejection, document access, skills/areas and compensation rules.
- Server-priced service/package quotes and bookings with immutable snapshots.
- Assignment eligibility, availability windows, compensation snapshots, cancellation and price-preserving rescheduling.
- Direct worker assignment by an admin with reason, actor, timestamp, assignment history and notifications.
- Restart-safe legacy offer expiry with conditional state updates; stale offers cannot be accepted after direct assignment.
- Booking-scoped private product photos, uploaded by the assigned worker before service start. Photos accept JPEG/PNG/WebP, up to 5 MB each and three per booking; retention is 90 days.
- Worker OTP start verifies the assigned worker, arrived state, linked product evidence and one-time OTP, then persists server start/end timestamps.
- Idempotent 15-minute extension requests at booked service expiry, with a five-minute customer decision window. Approval extends server end time; decline/timeout adds no duration charge. Catalog extra services remain a separate flow.
- Collection reconciliation and receipt APIs. Completion and collection remain separate states.
- Refund requests with reserved balances; approval/rejection; external completed-refund reconciliation. No transfer is initiated by these actions.
- Worker cash handover and compensation reconciliation with independent outstanding-balance limits.
- Dashboard/report APIs, CSV escaping, audit reads and admin notification reads.
- Admin data refresh polling and expired-session handling.

Customer IDs in existing bookings may refer to user records. The admin adapter handles either a profile ID or linked user ID. New admin bookings preserve both customer ID and customer profile ID.

## Financial and booking policies

- An admin booking is confirmed, searching for assignment, and unpaid. Admin assignment is final and does not wait for worker acceptance.
- Appointment validation checks lead time, slot alignment and opening/closing hours.
- Legacy offers remain available only when explicitly enabled. They cannot act on a booking assigned directly by an admin.
- Extension duration pricing is currently zero, so the booked total remains unchanged unless a separately approved catalog extra service is added. Repeated duration extensions are disabled.
- Administrative cancellation/rescheduling require reasons; they preserve financial snapshots and produce server history.
- Coupon usage is consumed at confirmed booking creation. Cancellation currently does not restore coupon usage; this is an explicit policy, not a refund of money.
- Recorded refunds require evidence of an external completed refund. They are distinguished from provider-verified transfers.
- Settlement records reconcile external handovers/payments. The backend never claims to have initiated a transfer.

## External configuration still required

The storage service accepts an adapter implementing `put`, `remove` and `signedRead`. The parallel `admin web panel/backend` supports S3; this backend provides a MongoDB-backed private adapter in development when a valid session secret is configured. Product evidence is private and opened only through authorized 60-second signed links. Configure `DEVELOPMENT_MEDIA_BASE_URL` to a device-reachable API base when verifying uploads from a phone. Production requires persistent private storage; uploads fail closed when no adapter is configured.

Razorpay single-use QR creation and signed webhook verification are implemented, but require backend credentials and have not been verified against a live Razorpay account. Provider-initiated refunds, SMS/OTP delivery and app push delivery are not configured. Do not treat manual reconciliation as payment-provider verification.

Availability windows can be recorded through the admin API. A worker who explicitly sets their profile online is also eligible for matching during that period; offline workers still need a covering availability window. Admin assignment continues to use the backend eligibility and conflict checks. The legacy sequential offer workflow is preserved but disabled by default. An effective compensation rule is required for assignment. Administrative status edits are not proof of OTP verification.

## Tests and evidence

Backend unit/API tests use deterministic transaction doubles, not the development database. These verify application rollback/replay behavior, extension idempotency, and evidence-gated start behavior but do not establish real MongoDB concurrency correctness. Both backend suites, both admin builds/tests, and targeted worker/customer Flutter analysis/tests passed after the workflow changes.

The live checks are read-only: database ping, collection validator inspection, backend health/readiness and unauthenticated-session rejection. Browser verification could not run because the session exposed no browser surface. Authenticated browser and live-provider workflows require the initial admin account and storage configuration.

Production rollout still requires verifying configured storage and notification delivery. Successful builds and deterministic tests are not proof that every production workflow is complete.

## Rollback

Original backend source files are preserved under the admin workspace's `audit-artifacts/backend-changes/original-backend`, `phase2-originals` and `phase3-originals`. Restore only the specific intended files after reviewing later edits; these backups are not database backups. No automatic destructive rollback or database deletion is performed.

For database backup/restore, use an approved MongoDB backup procedure and a dedicated restore database, then review collection validators and indexes before activation. No backup or restore of live business records was executed by this task.
