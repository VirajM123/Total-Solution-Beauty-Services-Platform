# Hii Beauty Customer App

## Run against the centralized backend

Set `API_BASE_URL` to the backend origin plus `/api`. The same compile-time
setting is used in development and production; do not add a trailing route such
as `/catalog`.

For an Android emulator and a backend running on the development host at port
5000:

```powershell
flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

The Android debug manifest permits cleartext traffic for this local development
URL only. Release/profile builds require HTTPS:

```powershell
flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=https://your-backend.example/api
```

The public catalog can be browsed without signing in. Categories, services,
packages and currently published offers are read from the backend; refresh the
catalog or resume the app to pick up Admin edits. Network errors are shown
instead of substituting sample catalog records.

Customer authentication and booking/checkout remain disabled until their
approved backend contracts and SMS/policy configuration are available. The
separate development preview remains sample-only and does not create real
sessions, bookings or payments.

See [mobile integration report](MOBILE_BACKEND_INTEGRATION_REPORT.md) for route
mapping, backend prerequisites, validation and live verification status, and
[payment policy](docs/checkout_payment_contract.md) for the after-service
Cash/UPI policy.
