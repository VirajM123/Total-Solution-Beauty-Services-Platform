# Hii Beauty Customer App

## Windows Chrome launch workaround

If `flutter run -d chrome` reports "Failed to launch browser after 3 tries",
run this from the customer app directory:

```cmd
run-web.cmd
```

When Flutter prints the serving URL, open **http://localhost:58408** in Chrome.
This serves the app without requiring Chrome's remote debugging connection.
Stop with Ctrl+C and restart after code changes; browser debugging and hot reload
are limited in web-server mode.

For the centralized backend, start the backend first, then use:

```cmd
run-web.cmd -t lib/main_prod.dart --dart-define=API_BASE_URL=http://localhost:5001/api
```

## Run against the centralized backend

Set `API_BASE_URL` to the backend origin plus `/api`. The same compile-time
setting is used in development and production; do not add a trailing route such
as `/catalog`.

The local final-test backend is `admin web panel/backend` on port `5001`, shared
with the Admin app. Run the Flutter web app on the allowed development origin:

```powershell
flutter run -d chrome --web-port=58408 -t lib/main_prod.dart --dart-define=API_BASE_URL=http://localhost:5001/api
```

For an Android emulator:

```powershell
flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=http://10.0.2.2:5001/api
```

OTP and booking requests require the backend to be running with its development
database, operations API, and MSG91 configuration ready. The Android debug
manifest permits cleartext traffic for this local development URL only.
Release/profile builds require HTTPS:

```powershell
flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=https://your-backend.example/api
```

The public catalog can be browsed without signing in. Categories, services,
packages and currently published offers are read from the backend; refresh the
catalog or resume the app to pick up Admin edits. Network errors are shown
instead of substituting sample catalog records.

The separate development preview remains sample-only and does not create real
sessions, bookings or payments. Use the `main_prod.dart` entry point above for
requests against the shared backend.

See [mobile integration report](MOBILE_BACKEND_INTEGRATION_REPORT.md) for route
mapping, backend prerequisites, validation and live verification status, and
[payment policy](docs/checkout_payment_contract.md) for the after-service
Cash/UPI policy.
