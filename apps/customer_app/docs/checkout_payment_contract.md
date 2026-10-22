# Checkout integration boundary

Current approved policy: customers pay after service completion by Cash or UPI. Booking creation collects no money and payment remains Pending until the server verifies collection. No card or gateway integration is approved.

Production checkout is disabled because customer authentication, cart, authoritative quotes, availability, address ownership and idempotent booking routes are not mounted in the inspected backend. integration/customer_backend.dart defines typed pending interfaces without guessed routes. Implementations must reuse an idempotency key for retries of the same intended booking and preserve the cart until server confirmation.

Development checkout is a visual preview only: no database records, booking IDs or transactions. Sample confirmation is labelled and payment remains Pending. Demo amounts, slots and addresses cannot become authoritative production data. The historical card enum remains for old snapshot compatibility but is not selectable.

Backend requirements: customer-owned cart/address operations, expiring quotes with integer paise totals, serviceable availability, booking DTOs and service snapshots, real booking numbers, scoped history/status and cash/UPI reconciliation. The company UPI destination requires server configuration. A QR display, screenshot or client callback never proves payment.
