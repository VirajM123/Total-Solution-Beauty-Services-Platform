# Checkout integration boundary

Customer checkout confirms the service, schedule and address only. It does not collect a payment method or payment. Booking creation collects no money; payment remains pending until the server verifies collection.
If a booking request times out, retry the same booking payload with its original idempotency key so the server can replay the booking instead of creating a duplicate. A `409 SLOT_UNAVAILABLE` means the selected time cannot be reserved; the customer must choose another time.

During an active service, the worker may request extra services. The customer must explicitly approve or decline each request in the Customer App. Only approved extras increase the booking total, and the worker cannot complete the service while an extra-service request is pending.

After service completion, the worker can request a fixed-amount, single-use Razorpay UPI QR for the server-calculated final amount. Razorpay credentials and webhook secret belong only in `backend/.env`; never add the key secret to either Flutter app or a client-side environment file. Configure the Razorpay webhook endpoint at `/api/mobile/payments/razorpay/webhook` and subscribe to `qr_code.credited`.

Development checkout remains a visual preview: no database records, booking IDs or transactions are created by its local preview flow. Demo amounts, slots and addresses cannot become authoritative production data. The historical payment-method enum remains for old snapshot compatibility but is not selectable. A QR display, screenshot or client callback never proves payment; only a verified webhook can mark the booking paid.
