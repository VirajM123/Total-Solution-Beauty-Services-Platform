# Service-start OTP

The Node.js backend creates a six-digit service-start challenge in the same transaction as each customer booking. It stores only an Argon2id hash; service OTP generation and delivery do not depend on MSG91.

The authenticated customer can reveal a replacement code through `POST /api/mobile/customer/bookings/:id/service-otp/reveal`. The response is private and non-cacheable. Only the booking owner can reveal it. Booking details expose availability and expiry metadata, never a code or hash.

After arrival, the assigned approved worker uploads 1-3 JPEG, PNG, or WebP product photos (up to 5 MB each) through `POST /api/mobile/worker/bookings/:id/product-evidence`. Uploads are private, linked to the booking and worker, and retained for 90 days. The worker submits the customer-provided code through `POST /api/mobile/worker/bookings/:id/progress` with `{"action":"start","otp":"123456","evidenceIds":["<media-id>"]}`. The server requires at least one valid linked photo and a valid one-time OTP before it starts the service and records server start/end timestamps. Invalid attempts are recorded and limited. The customer app only displays the code; service start is performed from the worker app.
