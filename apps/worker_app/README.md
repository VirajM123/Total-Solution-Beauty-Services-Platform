# worker_app

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

## Backend service catalog

The worker registration and profile service lists, plus additional booking
services, load from the backend's published catalog. Configure `API_BASE_URL` as the shared Admin backend origin with `/api`.
For Flutter web, use the backend's allowed local origin:

```powershell
flutter run -d chrome --web-port=58408 --dart-define=API_BASE_URL=http://localhost:5001/api
```

For an Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001/api
```

Use the deployed HTTPS backend URL for physical devices and release builds.
Only published services and categories are returned by the public catalog;
draft and archived records are intentionally not displayed. Catalog failures
show an error and do not fall back to sample services.

Mobile backend integration: [status, configuration and backend dependencies](MOBILE_BACKEND_INTEGRATION_REPORT.md). Default builds fail closed; preview requires WORKER_DEVELOPMENT_PREVIEW=true in debug mode.
