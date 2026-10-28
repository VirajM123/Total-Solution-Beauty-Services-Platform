import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_notification_repository.dart';
import 'package:worker_app/features/home/worker_notifications_screen.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';

class FakeWorkerNotificationStorage implements WorkerNotificationStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

class FakeWorkerTokenStorage implements WorkerTokenStorage {
  FakeWorkerTokenStorage([this.token = 'test-token']);
  final String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  testWidgets('shows derived preview alerts and filters unread items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkerNotificationsScreen(orders: previewWorkerOrders)),
    );
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Service completed'), findsOneWidget);
    expect(find.text('3 unread'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(find.text('0 unread'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('handles empty booking data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkerNotificationsScreen(orders: [])),
    );
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('notification layout fits supported phone widths', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerNotificationsScreen(
            orders: previewWorkerOrders,
            demoMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('3 unread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  test('WorkerNotificationRepository loads from live API, caches, and syncs read state', () async {
    final storage = FakeWorkerNotificationStorage();
    final requestedPaths = <String>[];

    final client = MockClient((request) async {
      requestedPaths.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/mobile/worker/notifications') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {
                  '_id': 'notif-101',
                  'type': 'worker.approved',
                  'isRead': false,
                  'createdAt': DateTime.now().toIso8601String(),
                },
                {
                  '_id': 'notif-102',
                  'type': 'settlement.completed',
                  'isRead': true,
                  'createdAt': DateTime.now().toIso8601String(),
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/notifications/notif-101/read') && request.method == 'PATCH') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'_id': 'notif-101', 'isRead': true}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/notifications/read-all') && request.method == 'POST') {
        return http.Response(
          jsonEncode({'success': true, 'data': {'success': true}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'success': false, 'error': {'code': 'NOT_FOUND'}}), 404);
    });

    final api = WorkerMobileOperationsApi(
      client: client,
      tokenStorage: FakeWorkerTokenStorage(),
      apiBaseUrl: 'http://localhost:5001/api',
    );

    final repo = WorkerNotificationRepository(
      storage: storage,
      operationsApi: api,
    );

    await repo.load();
    expect(repo.notifications.length, 2);
    expect(repo.unreadCount, 1);
    expect(repo.notifications.first.title, 'Profile Approved! 🎉');
    expect(repo.isOffline, isFalse);

    // Verify markAllAsRead sends request when there are unread items
    await repo.markAllAsRead();
    expect(requestedPaths, contains('POST /api/mobile/worker/notifications/read-all'));
    expect(repo.unreadCount, 0);

    // Verify markAsRead on item
    await repo.markAsRead('notif-101');
    expect(repo.notifications.first.isRead, isTrue);

    // Verify offline resilience with cached data
    final offlineClient = MockClient((request) async {
      throw http.ClientException('Network down');
    });
    final offlineApi = WorkerMobileOperationsApi(
      client: offlineClient,
      tokenStorage: FakeWorkerTokenStorage(),
      apiBaseUrl: 'http://localhost:5001/api',
    );
    final offlineRepo = WorkerNotificationRepository(
      storage: storage,
      operationsApi: offlineApi,
    );
    await offlineRepo.load();
    expect(offlineRepo.isOffline, isTrue);
    expect(offlineRepo.notifications.length, 2);
  });

  testWidgets('Hide seen filter hides seen notifications and unread items appear properly', (
    tester,
  ) async {
    final storage = FakeWorkerNotificationStorage();
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': [
              {
                '_id': 'notif-201',
                'type': 'assignment.offered',
                'isRead': false,
                'createdAt': DateTime.now().toIso8601String(),
              },
              {
                '_id': 'notif-202',
                'type': 'booking.completed',
                'isRead': true,
                'createdAt': DateTime.now().toIso8601String(),
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = WorkerMobileOperationsApi(
      client: client,
      tokenStorage: FakeWorkerTokenStorage(),
      apiBaseUrl: 'http://localhost:5001/api',
    );

    final repo = WorkerNotificationRepository(
      storage: storage,
      operationsApi: api,
    );
    await repo.load();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerNotificationsScreen(
          orders: const [],
          demoMode: false,
          repository: repo,
          operationsApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Service Request'), findsOneWidget);
    expect(find.text('Service Completed ✅'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);

    // Tap "Hide seen" chip
    await tester.ensureVisible(find.text('Hide seen'));
    await tester.tap(find.text('Hide seen'));
    await tester.pumpAndSettle();

    // Now the seen notification should NOT appear!
    expect(find.text('Service Completed ✅'), findsNothing);
    expect(find.text('New Service Request'), findsOneWidget);

    // Tap the remaining notification to mark it read
    await tester.tap(find.text('New Service Request'));
    await tester.pumpAndSettle();

    // Since it was read and "Hide seen" is enabled, it should disappear!
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('Shows offline banner when network fails without crash', (
    tester,
  ) async {
    final storage = FakeWorkerNotificationStorage();
    // Pre-populate storage cache with 1 notification
    await storage.write(
      'hii_beauty.worker.notifications.v1',
      jsonEncode([
        {
          'id': 'offline-1',
          'title': 'Offline Notice',
          'message': 'You have 1 saved update',
          'group': 'Updates',
          'type': 'general',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        }
      ]),
    );

    final failingClient = MockClient((request) async {
      throw http.ClientException('Simulated offline state');
    });

    final api = WorkerMobileOperationsApi(
      client: failingClient,
      tokenStorage: FakeWorkerTokenStorage(),
      apiBaseUrl: 'http://localhost:5001/api',
    );

    final repo = WorkerNotificationRepository(
      storage: storage,
      operationsApi: api,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerNotificationsScreen(
          orders: const [],
          demoMode: false,
          repository: repo,
          operationsApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Offline banner should be visible and cached notification displayed
    expect(find.textContaining('Offline mode'), findsOneWidget);
    expect(find.text('Offline Notice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
