# Phase 4A: development authentication preparation

Catalog APIs remain disabled. No localStorage transition, database writes, or bootstrap execution was performed during implementation.

## Configure locally
From PowerShell:
1. Set-Location 'D:\Viraj Mohite Code All\beauty-services\backend'
2. If .env is absent, Copy-Item .env.example .env (do not overwrite an existing file).
3. Edit .env locally. Set MONGODB_URI to the rotated URI of the development cluster. Do not paste it into chat.
4. Keep MONGODB_DB_NAME=hii_beauty_dev, NODE_ENV=development, PORT=5000,
   ADMIN_CATALOG_API_ENABLED=false and ADMIN_SESSION_TTL_HOURS=8.
5. Set SESSION_COOKIE_SECRET to at least 32 cryptographically random characters through a local password manager;
   do not put it in shell command arguments or logs.
6. Set CORS_ORIGINS to the exact trusted Admin origins (defaults: http://localhost:5173,http://127.0.0.1:5173).
7. The loader reads backend/.env when launched from backend; ignored .env.local and .env.production are not loaded automatically.

Never reuse the credential exposed during Phase 2. The code cannot prove rotation or cluster designation.
Use a database principal scoped to hii_beauty_dev only; confirm grants in Atlas. No root,
readWriteAnyDatabase, dbOwner, or schema administration permissions are required.
The inspect command needs read access to users/roles. Bootstrap additionally needs insert privileges
for users/roles/audit_logs, listCollections on hii_beauty_dev, listIndexes on roles, and transactions. No collections/indexes are created.
The application needs its reviewed collection-scoped permissions, including auth session writes and audit inserts.
Protect the ignored file with local Windows user access. Never commit credentials.

## Read-only inspection, then separate approval
Run npm.cmd run admin:inspect only after rotation and cluster/user scopes are confirmed.
It pings the selected database and prints only role IDs/codes/permissions and Admin counts, not user identity or hashes.
Review existing accounts with the owner; a suitable Admin must have an active user/role and every listed catalog permission.

Only after explicit project-owner approval to create the named account, run npm.cmd run admin:bootstrap
in a local interactive terminal. Supply real name, email, international mobile, and a unique password (16?128 characters).
Passwords and confirmation are hidden; no password argument, default identity or generated MongoDB URI exists.
The confirmation phrase is CREATE DEVELOPMENT ADMIN.

The new role is HII_BEAUTY_SUPER_ADMIN. This is a newly defined role code, not a claim about existing database codes.
Its explicit permissions are catalog.categories.read/create/update/publish, catalog.services.read/create/update/publish,
and catalog.media.upload. No wildcard privileges are granted.
Existing identities are never promoted; existing suitable Admins or the bootstrap role cause refusal.
Existing unique roleCode index plus a transaction prevents concurrent duplicate bootstraps.
Role, user, and admin.bootstrap audit insert commit together, or all roll back.
A replica set/transaction-capable deployment is required. No fallback to non-atomic writes.
A failed CLI reports a sanitized failure and nonzero exit; inspect configuration rather than printing raw driver errors.

## Authentication and catalog activation
npm.cmd start provides /health/live (200) and /health/ready (200 only with connected MongoDB).
/api/admin/auth/login, /session and /logout are mounted independently of the catalog flag.
They still require a valid configured session secret, database readiness, active Admin and role.
Session tokens are hashed in MongoDB; cookies are HttpOnly and SameSite=Strict (Secure in production).
Login/logout require trusted Origin; logout and catalog writes require session-bound CSRF tokens.
No authentication control is bypassed when catalog is disabled.
Use the actual local browser to verify login, session lookup, CSRF rejection, logout, revoked session rejection,
unauthenticated requests and insufficient permissions before enabling catalog.

## Phase 4B prerequisites
- Confirm credential rotation, database-principal grants, existing Admin/roles and live auth results.
- Explicitly approve development test records; keep catalog flag false until auth verification passes.
- Export hi-beauty-services-v1 from the original Admin browser origin before changing persistence.
  In browser DevTools, copy localStorage.getItem('hi-beauty-services-v1') to a local JSON backup.
  Preserve the exact raw value; do not delete it, import samples, or silently fall back after API failures.
- Map category IDs, active service-area ObjectIds, status, descriptions, and exact rupee-to-paise conversion.
- Connect existing Category/Service layouts with loading/empty/error states and backend validation feedback.
- Wire persistent storage adapter into server startup before image upload or image-dependent publication.
  Existing data/blob URLs cannot become permanent media. Storage is currently unconfigured.
- Verify catalog audit writes, duplicate requests, public draft filtering and real refresh persistence.
- Account bootstrap and catalog actions have audit records; failed preflight attempts produce sanitized terminal failure only.

## Validation scope
Isolated tests use in-memory doubles, not live MongoDB. Transaction rollback tests verify application behavior;
actual deployment transaction support and persistence require credential-dependent verification.
