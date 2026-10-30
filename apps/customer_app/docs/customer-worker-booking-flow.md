# Customer and Worker Booking Flow

This document describes the combined booking lifecycle in sequence, including the customer and worker actions and the backend work between them.

## Live booking flow

1. **Customer chooses services.** The customer adds one or more services to the cart, adjusts quantities, and reviews the selected items. The app maps the selected services to backend catalog IDs before creating a live booking.
2. **Customer selects appointment details.** The customer chooses a date, time, and saved address, then reviews and confirms the booking. Checkout does not collect payment.
3. **Customer app sends the booking request.** It sends all selected service IDs and quantities, service area, address, appointment time, and payment method to `POST /api/mobile/customer/bookings`, authenticated with the customer session.
4. **Backend validates and creates the booking.** Node.js checks the customer-owned address, service availability, prices, booking policy, lead time, and worker availability. It calculates the booking totals from backend data and reserves the slot. The initial booking state is `confirmed`; assignment starts as `searching`.
5. **Backend generates the start-service code.** In the same database transaction as booking creation, Node.js creates a random six-digit service-start code and stores only an Argon2id hash in the service OTP challenge collection. The code is not sent by MSG91, included in booking details, or returned to the worker in an assignment.
6. **Backend offers the booking to a worker.** The dispatch/assignment flow selects an eligible worker and creates an offer. The worker sees the booking in their app and accepts or rejects it. On acceptance, the booking is linked to that worker and the assignment becomes accepted. A rejected or expired offer must be handled through assignment again; the worker who did not accept cannot progress the booking.
7. **Worker starts travelling.** From the live booking details, the assigned worker taps the travel action. The worker app calls `POST /api/mobile/worker/bookings/:id/progress` with `{"action":"travel"}`. The backend checks the worker and booking assignment and changes the state from `assigned` to `travelling`.
8. **Worker marks arrival.** At the customer's address, the worker taps the arrival action. The same progress endpoint receives `{"action":"arrive"}` and the backend changes the state from `travelling` to `arrived`.
9. **Customer reveals the code.** When the customer app sees the booking reach `arrived`, it requests a replacement code from `POST /api/mobile/customer/bookings/:id/service-otp/reveal`. The backend verifies booking ownership, rotates the prior challenge, stores a hash for the new six-digit code, and returns the plaintext code only in that owner's private, non-cacheable response. The customer sees the code and shares it with the assigned worker in person. Booking details expose availability/expiry metadata only.
10. **Worker enters and submits the customer's code.** The worker taps “Start Service,” enters the six-digit code in the worker app, and submits it. The app calls the progress endpoint with `{"action":"start","otp":"123456"}`. Only the worker app has the start action; the customer app has no service-start verification or start control.
11. **Backend verifies and starts service.** Node.js confirms the worker is approved and is the accepted worker for this arrived booking, checks the code hash, expiry and attempt limit, and consumes the challenge on successful verification. In the same transaction it changes the booking to `in_progress` and records service events. Wrong, expired, used, or locked codes do not start the service.
12. **Worker performs the service.** The customer app observes booking status changes and shows the service in progress. During the service, the worker may propose an extra service from the worker app.
13. **Customer decides on any extra service.** The customer explicitly approves or declines each proposal in the customer app. Only an approved proposal changes the booking total. The worker cannot complete the booking while an extra-service proposal remains pending.
14. **Worker completes the service.** The worker taps “Complete Service.” The worker app submits `{"action":"complete"}` to the same progress endpoint. The backend checks the active worker, accepted assignment, current `in_progress` state, and absence of pending extra-service decisions, then records completion. Payment remains pending at this point.
15. **Payment is handled after completion.** If the configured Razorpay flow is enabled, the worker can request a fixed-amount, single-use UPI QR for the backend-calculated final amount. Payment is marked paid only after the backend validates the Razorpay webhook; displaying or scanning a QR alone is not proof of payment. Payment credentials stay on the backend.
16. **Customer reviews and can book again.** The customer sees the completed booking and can submit a review. To book another service, the app clears the previous booking selection and sync timer, then starts with a fresh cart.

## Important service-code rules

- The backend creates and verifies service-start codes; MSG91 is not used for this flow.
- Login OTP and service-start OTP are separate flows. This change does not replace the login OTP provider.
- Only the authenticated owner can reveal the service-start code. Workers must ask the customer for it; worker booking and offer responses do not include it.
- Only the assigned, approved worker can submit the code to start that booking.
- The code is six digits in the live flow. It expires, has a limited number of verification attempts, and can be consumed only once.
- If a customer needs a replacement, the customer app must explicitly reveal one when allowed by the backend cooldown and issue limits. Replacing a code invalidates its previous challenge.

## Development preview versus live flow

The customer checkout screen also contains a local development preview. When the backend request is unavailable or the service/address data cannot be mapped to valid backend records, the preview can display simulated booking progress. That local preview does not create a real booking or a server-verifiable service code; it must not be used to represent a real service start.

The worker app likewise has a debug-only preview OTP flow for demo bookings. It is not server verification. For a live booking, the worker app requires six digits and submits them to the backend before showing the booking as in progress.

## Main API calls

| App / actor | Endpoint | Purpose |
|---|---|---|
| Customer | `POST /api/mobile/customer/bookings` | Create booking from selected cart items and schedule |
| Customer | `GET /api/mobile/customer/bookings/:id` | Refresh status and extra-service requests; no plaintext code returned |
| Customer | `POST /api/mobile/customer/bookings/:id/service-otp/reveal` | Reveal a replacement code to the booking owner |
| Customer | `POST /api/mobile/customer/bookings/:id/extra-services/:extraId/respond` | Approve or decline a worker proposal |
| Worker | `POST /api/mobile/worker/assignments/:id/respond` | Accept or reject an offered booking |
| Worker | `POST /api/mobile/worker/bookings/:id/progress` | Travel, arrive, verify code/start, or complete |
| Worker | `POST /api/mobile/worker/bookings/:id/extra-services` | Propose an extra service during an active service |
| Worker | `POST /api/mobile/worker/bookings/:id/payment-qr` | Request a post-completion payment QR when configured |
| Backend webhook | `POST /api/mobile/payments/razorpay/webhook` | Confirm a payment from a verified provider event |
