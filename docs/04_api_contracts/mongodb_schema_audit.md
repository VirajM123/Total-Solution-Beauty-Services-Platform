# MongoDB Schema Audit — Phase 2

## Scope and safety

Connected to the explicitly selected `hii_beauty_dev` database and performed read-only `listCollections` and `listIndexes` operations. The script did not query documents or perform writes, and disconnected after collecting metadata. The connection string and credentials were not written to a file or included in output.

**Credential hygiene:** the credential was pasted into chat. Rotate it after the audit and replace it with a least-privilege application credential. Use ignored `backend/.env` or a secret manager; do not commit credentials. The environment is identified here by the requested database name; confirm the Atlas cluster itself is designated for development.

## Connection configuration

- `backend/.env.example` sets `MONGODB_DB_NAME=hii_beauty_dev`.
- `backend/src/config/database.js` passes `dbName` explicitly, overriding any database path in the URI.
- Mongoose global and connection options disable `autoCreate` and `autoIndex`.
- `.gitignore` ignores `.env` and `.env.local`; `apps/admin_web/.gitignore` ignores local frontend env files.
- The supplied URI path selected `hii_beauty_dev`; the live connection reported the same database.

## Collection inventory

**37 collections found; all 37 names match the planned inventory. No missing or extra collections.**

`app_settings`, `audit_logs`, `auth_sessions`, `booking_assignments`, `booking_events`, `booking_slots`, `bookings`, `carts`, `coupon_redemptions`, `customer_addresses`, `customer_favorites`, `customers`, `media_assets`, `notifications`, `offers`, `otp_challenges`, `payment_events`, `payments`, `promotional_banners`, `reviews`, `roles`, `service_areas`, `service_categories`, `service_events`, `service_otp_challenges`, `service_packages`, `services`, `support_tickets`, `users`, `worker_availability`, `worker_documents`, `worker_leaves`, `worker_locations`, `worker_settlement_items`, `worker_settlements`, `worker_skills`, `workers`.

## Validators and indexes

- All 37 collections have a `$jsonSchema` validator with `validationLevel: strict` and `validationAction: error`.
- None of the inspected validators declares a `required` list. Their schema properties declare BSON types, while `additionalProperties: true`; these validators do not require the listed fields or prohibit other fields.
- Found 92 indexes total (including the 37 `_id` indexes), 22 unique indexes, and four TTL indexes.
- TTL indexes with `expireAfterSeconds: 0`: `auth_sessions.expiresAt`, `otp_challenges.expiresAt`, `service_otp_challenges.expiresAt`, and `worker_locations.expiresAt`. Expiration is existing database behavior; this audit did not alter it.
- The unique indexes on categories (`categoryCode`, `slug`) and services (`serviceCode`) enforce uniqueness at the database level. Category/service listing indexes are shown below.

| Collection | Validator | Non-`_id` indexes observed |
|---|---|---|
| `service_categories` | strict/error | unique `categoryCode`; unique `slug` |
| `services` | strict/error | unique `serviceCode`; `{ categoryId: 1, status: 1, displayOrder: 1 }` |
| `media_assets` | strict/error | `{ storageProvider: 1, storageKey: 1 }` |
| `service_areas` | strict/error | unique `areaCode` |
| `users` | strict/error | unique `mobileNumber`; `{ roleId: 1, status: 1 }` |
| `roles` | strict/error | unique `roleCode` |
| `auth_sessions` | strict/error | `{ userId: 1 }`; TTL `{ expiresAt: 1 }` |
| `audit_logs` | strict/error | `{ entityType: 1, entityId: 1, createdAt: -1 }` |

No representative documents were read. This avoided accessing personal or authentication data; field value semantics beyond validators/indexes remain unverified.

## Verified validator field definitions

All the following field definitions are optional according to the validators (no `required` list). Common metadata on each includes `_id: objectId`, `createdAt`/`updatedAt: date`, `createdBy`/`updatedBy: objectId`, `isActive: bool`, and `schemaVersion: int|long|double|decimal`.

| Collection | Other verified fields and BSON types |
|---|---|
| `service_categories` | `categoryCode`, `name`, `slug`, `description`, `iconKey`, `status`: string; `thumbnailMediaId`, `bannerMediaId`: objectId; `displayOrder`: int/long/double/decimal; `publishedAt`: date |
| `services` | `serviceCode`, `name`, `slug`, `shortDescription`, `fullDescription`, `status`: string; `categoryId`, `thumbnailMediaId`: objectId; `benefits`: array of strings; `durationMinutes`, `displayOrder`: int/long/double/decimal; `pricePaise`, `compareAtPricePaise`: int/long; `imageMediaIds`, `skillRequirements`, `serviceAreaIds`: arrays of objectIds; `isHomeServiceAvailable`: bool; `publishedAt`: date |
| `media_assets` | `storageProvider`, `storageKey`, `publicUrl`, `mimeType`, `fileName`, `altText`, `visibility`, `uploadStatus`: string; `fileSizeBytes`, `width`, `height`: int/long/double/decimal; `uploadedBy`: objectId |
| `service_areas` | `areaCode`, `name`, `city`, `state`: string; `postalCodes`: array of strings; `boundary`, `operatingHours`: object; `isServiceable`: bool; `displayOrder`: int/long/double/decimal |
| `users` | `userType`, `fullName`, `mobileNumber`, `countryCode`, `email`, `status`, `authProvider`, `passwordHash`: string; `roleId`, `profileImageId`: objectId; `emailVerifiedAt`, `mobileVerifiedAt`, `lastLoginAt`: date |
| `roles` | `roleCode`, `roleName`, `description`: string; `permissions`: array of strings; `isSystemRole`: bool |
| `auth_sessions` | `userId`: objectId; `refreshTokenHash`, `deviceId`, `devicePlatform`, `appType`, `ipAddress`, `userAgent`: string; `issuedAt`, `expiresAt`, `revokedAt`, `lastSeenAt`: date |
| `audit_logs` | `actorUserId`, `entityId`: objectId; `actorRole`, `action`, `entityType`, `requestId`, `ipAddress`, `userAgent`, `result`: string; `changes`: object |

## Mongoose models

Read-only-verified models are in `backend/src/models/index.js` for `users`, `roles`, `auth_sessions`, `audit_logs`, `service_categories`, `services`, `media_assets`, and `service_areas`. They specify exact collection names, include no required fields, disable automatic collection/index creation, and use `strict: false` to preserve validator-allowed additional fields.

The two paise fields use Mongoose `BigInt` to encode BSON-compatible integer values (the database validator allows only BSON `int`/`long`). Decimal-price conversion is not implemented here; API input must be converted with explicit bounds and tests before writes are enabled. Models are definitions only; no model query/write or index creation occurred during the audit.

## Admin field mapping

Source: `apps/admin_web/src/servicesData.ts` and `apps/admin_web/src/ServicesPage.tsx`.

| Admin concept | Current UI | Verified DB mapping / gap |
|---|---|---|
| Category identifier | Browser-generated string `id` | Convert to MongoDB ObjectId at API boundary; UI currently has no code/slug field. |
| Category name | `name` | `service_categories.name` string |
| Category code / slug | Not collected | `categoryCode` and `slug` are validated string properties and have unique indexes; backend must generate or request them after agreed rules. |
| Category description | Not collected | Optional `description` string exists in validator; adding UI is a product change, not silently inferred. |
| Category thumbnail | nullable `ServiceImage` with path/data URL and optional crop | DB stores `thumbnailMediaId` ObjectId; requires persistent media upload/reference. Current browser data URLs/design path cannot be persisted as this field. |
| Category publication | optional `published` bool (default UI treats absent as published) | Validator exposes string `status`, optional `publishedAt` date, and `isActive`; map lifecycle explicitly before API writes. |
| Category display order | Not collected | Optional numeric `displayOrder` exists; no current UI value. |
| Service name | `name` | `services.name` string |
| Category relationship | string `parentId` | `services.categoryId` ObjectId; resolve and validate against `service_categories`. |
| Price | number in whole rupees | `pricePaise` is BSON int/long only. For a rupee amount `r`, convert exactly to `r * 100` integer paise; reject fractions beyond two decimal places and values outside safe integer/range bounds. Existing UI amounts remain unchanged. |
| Duration | integer minutes | `durationMinutes`, BSON numeric; existing UI uses minutes. |
| Description | one `description` string | DB has `shortDescription` and `fullDescription`; current UI has one optional text. A mapping/truncation policy needs approval. |
| Service image | one nullable image/path/data URL | DB has `imageMediaIds` array and `thumbnailMediaId`; needs uploaded media asset IDs. |
| Service areas | string array of city names | DB expects ObjectId array `serviceAreaIds`; resolve names to `service_areas` IDs. |
| Skill requirements | Not collected | DB exposes ObjectId array `skillRequirements`; currently no UI mapping. |
| Availability/status/publication | `available`, `status: Active/Inactive`, `published` | DB has `isActive`, string `status`, `publishedAt`, and `isHomeServiceAvailable`; these must remain distinct until lifecycle semantics are agreed. |

## Remaining verification

- No documents were read, so required-by-business rules, enum values, existing ID relationships, and real stored field usage are not confirmed.
- The Admin form lacks category code, description, display order, service skill selectors, and persistent media references. This is a contract gap, not a validator blocker because the fields are optional.
- Authentication decisions remain: login provider/password approval, cookie/session design, CSRF policy, role-permission mapping, and secure bootstrap. The schema alone does not establish those policies.
