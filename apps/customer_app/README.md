# Hii Beauty Customer App

Public services can be browsed from **Browse services** on the login screen.
Configure the central backend explicitly:

```powershell
flutter run -t lib/main_prod.dart --dart-define=API_BASE_URL=https://your-backend.example/api
```

Customer authentication and checkout remain disabled in production until scoped
backend contracts exist. Development debug entrypoints preserve the local UI
preview; they do not create bookings, sessions or payments.

See [mobile integration report](MOBILE_BACKEND_INTEGRATION_REPORT.md) for endpoint
mapping, module status, validation and backend dependencies, and
[payment policy](docs/checkout_payment_contract.md) for Cash/UPI after service.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
