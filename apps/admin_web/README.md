# Hi Beauty Admin

The Admin frontend includes operational screens for bookings, customers, beauty experts, services and packages, payments and worker settlements, offers and coupons, support, reports, and settings.

## Run locally

From this directory:

```sh
npm run dev
npm run build
npm run lint
npm test
```

## Integration status

This is a local design/behavior preview, not a production-connected admin system. Records are stored in browser `localStorage`; no MongoDB access or Admin API integration is implemented. Sign-in controls are intentionally disabled: the preview is not protected by authentication or role authorization.

Before production, connect the UI to the Node.js backend, enforce Admin roles and sensitive operations on the server, and replace local persistence with typed API requests. Upload catalog images and private worker documents through backend-managed object storage; do not place database credentials in frontend environment variables. Payment verification, refunds/transfers, notifications, and worker responses must be confirmed by backend services rather than this local preview.

The payment and offer unit tests cover local business rules only; they do not verify backend behavior or database schemas.
