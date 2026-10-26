# MSG91 Flutter Integration Report

## Classification summary
- IMPLEMENTED: Backend contract alignment for mobile OTP requests and verification field mapping.
- UNIT TESTED: Partial regression coverage added for customer and worker OTP contract checks.
- BACKEND CONNECTED: Central backend contract is present and matches the app calls for /mobile/auth/otp/request and /mobile/auth/otp/verify.
- REAL SMS VERIFIED: BLOCKED — no live SDK/device execution available in this environment.
- REAL DEVICE VERIFIED: BLOCKED — no Android device or Flutter toolchain available here.
- BLOCKED: End-to-end live SMS and Android emulator validation remained unexecuted because the Flutter SDK and device runtime are unavailable in this workspace environment.

## 1) Customer App files modified
- apps/customer_app/lib/integration/customer_auth_api.dart
- apps/customer_app/lib/features/otp/development_otp_screen.dart
- apps/customer_app/test/customer_flow_test.dart

## 2) Worker App files modified
- apps/worker_app/lib/integration/worker_api.dart
- apps/worker_app/lib/integration/worker_mobile_auth_api.dart
- apps/worker_app/lib/features/otp/worker_otp_screen.dart
- apps/worker_app/test/worker_api_contract_test.dart

## 3) Packages installed
- No new package installs were required for the OTP wiring because the apps already include http and flutter_secure_storage.

## 4) Exact backend API paths and methods used
- POST /mobile/auth/otp/request
- POST /mobile/auth/otp/verify
- POST /mobile/auth/otp/resend
- POST /mobile/customer/logout
- POST /mobile/worker/logout
- GET /mobile/customer/profile
- GET /mobile/worker/profile

## 5) Request/response field mappings
### Request OTP
Request body:
- mobileNumber: +91XXXXXXXXXX
- appType: customer | worker

Response data:
- challengeId: backend-issued challenge identifier
- expiresInSeconds: challenge lifetime in seconds

### Verify OTP
Request body:
- challengeId: string
- code: 6-digit SMS OTP
- fullName: string (required by the backend contract)

Successful response data:
- accessToken: bearer token
- appType: customer | worker
- user: { id, fullName, mobileNumber }
- registrationRequired: optional boolean for first-time registration
- registrationToken: optional registration proof

## 6) OTP send behavior
The client sends the normalized Indian mobile number to the central backend and waits for confirmed success. The app does not generate or validate any OTP locally.

## 7) OTP verification behavior
The client submits the challengeId, 6-digit code, and required fullName to the backend verification route. The backend performs the actual provider verification and issues a mobile session.

## 8) OTP resend behavior
The UI cooldown is preserved and the resend action uses the backend challenge-based endpoint. The current app-level timer is still a client-side display and must be treated as advisory; the backend remains the source of truth.

## 9) Customer registration/login behavior
- Valid mobile number is normalized to +91 format.
- OTP challenge is created through the backend.
- Existing customer accounts are reused if already present.
- New customers can continue through the registration flow only when the backend returns registrationRequired and a registrationToken.

## 10) Worker registration/login behavior
- Valid mobile number is normalized and submitted with appType=worker.
- The backend verifies the OTP and returns either a session or a registration proof.
- Approval state comes from the backend profile / status values, not local UI assumptions.

## 11) Worker approval handling
- Approved: allowed to operate.
- Pending: kept in review.
- Rejected: restricted.
- Suspended: restricted.
- Not registered: continue registration flow.

## 12) Session storage mechanism
- Customer: flutter_secure_storage under the key hii_beauty.customer.mobile_session
- Worker: flutter_secure_storage under the key hii_beauty.worker.mobile_session
- Tokens are stored securely and bearer headers are added to authenticated requests.

## 13) Error handling
The client now preserves the backend-driven error messages for invalid OTP, expired OTP, configuration issues, and connectivity failures. The app still does not leak stack traces or secret values to users.

## 14) Backend URL configuration
The project uses API_BASE_URL and rejects invalid or non-HTTPS production values. This is configured at build time and is not hard-coded to a server secret.

## 15) Flutter analyze results
Status: BLOCKED
Reason: the Flutter SDK is not available in this environment, so flutter analyze could not be executed here.

## 16) Flutter test totals
Status: BLOCKED
Reason: the Flutter SDK is not available in this environment, so flutter test could not be executed here.

## 17) Android build status
Status: BLOCKED
Reason: Android build tooling could not be run here because Flutter is not installed in the environment.

## 18) Real SMS delivery status
Status: BLOCKED
Reason: no live SMS smoke test was executed in this environment.

## 19) Real Android device testing status
Status: BLOCKED
Reason: no physical Android device or emulator connection was available to execute the required test flow.

## 20) Remaining backend/provider blockers
- Live MSG91 SMS delivery must be confirmed on a device with the backend running and a valid provider configuration.
- Android app build and run validation is blocked until Flutter and Android tooling are installed.
- Real SMS smoke tests require explicit approval before any chargeable provider request is sent.

## Final implementation note
The code is aligned to the actual backend contract in backend/src/platform/mobileAuth.js, and the required fullName field is now included in OTP verification requests. The remaining live verification steps are blocked by missing local Flutter and Android execution tooling.
