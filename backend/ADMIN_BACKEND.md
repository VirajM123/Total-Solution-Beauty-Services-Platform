# Hi Beauty admin backend

This implementation extends the existing Express backend. No new customer/worker app endpoints were implemented. Existing app routers were preserved to avoid changing unrelated behavior.

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
- Restart-safe assignment offer expiry with conditional state updates.
- Collection reconciliation and receipt APIs. Completion and collection remain separate states.
- Refund requests with reserved balances; approval/rejection; external completed-refund reconciliation. No transfer is initiated by these actions.
- Worker cash handover and compensation reconciliation with independent outstanding-balance limits.
- Dashboard/report APIs, CSV escaping, audit reads and admin notification reads.
- Admin data refresh polling and expired-session handling.

Customer IDs in existing bookings may refer to user records. The admin adapter handles either a profile ID or linked user ID. New admin bookings preserve both customer ID and customer profile ID.

## Financial and booking policies

- An admin booking is confirmed, searching for assignment, and unpaid.
- Appointment validation checks lead time, slot alignment and opening/closing hours.
- A booking does not promise that a worker has accepted. Acceptance and verified service execution remain future app integration boundaries.
- Administrative cancellation/rescheduling require reasons; they preserve financial snapshots and produce server history.
- Coupon usage is consumed at confirmed booking creation. Cancellation currently does not restore coupon usage; this is an explicit policy, not a refund of money.
- Recorded refunds require evidence of an external completed refund. They are distinguished from provider-verified transfers.
- Settlement records reconcile external handovers/payments. The backend never claims to have initiated a transfer.

## External configuration still required

The storage service accepts an adapter implementing `put`, `remove` and `signedRead`. Public images must have persistent HTTPS URLs. Identity documents remain private and use authorized expiring links. No adapter is configured at server startup until the existing provider and credential-file path are supplied.

Razorpay order creation, live webhook processing, provider-initiated refunds, SMS/OTP delivery and app push delivery are not configured or verified. Do not treat manual reconciliation as payment-provider verification. Customer/worker authentication and service-start OTP are future app backend work.

Availability windows can be recorded through the admin API. Existing workers without explicit availability or effective compensation rules cannot be assigned. Administrative status edits are not worker consent or proof of OTP verification.

## Tests and evidence

Backend unit/API tests use deterministic transaction doubles, not the development database. These verify application rollback/replay behavior but do not establish real MongoDB concurrency correctness.

The live checks are read-only: database ping, collection validator inspection, backend health/readiness and unauthenticated-session rejection. Browser verification could not run because the session exposed no browser surface. Authenticated browser and live-provider workflows require the initial admin account and storage configuration.

The frontend build and tests must be rerun after integration changes. Existing lint warnings are recorded separately; successful build output is not proof that every production workflow is complete.

## Rollback

Original backend source files are preserved under the admin workspace's `audit-artifacts/backend-changes/original-backend`, `phase2-originals` and `phase3-originals`. Restore only the specific intended files after reviewing later edits; these backups are not database backups. No automatic destructive rollback or database deletion is performed.

For database backup/restore, use an approved MongoDB backup procedure and a dedicated restore database, then review collection validators and indexes before activation. No backup or restore of live business records was executed by this task.
