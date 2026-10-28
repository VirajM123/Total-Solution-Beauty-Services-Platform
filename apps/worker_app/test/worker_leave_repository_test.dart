import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worker_app/features/schedule/worker_leave_repository.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';

class _MemoryTokenStorage implements WorkerTokenStorage {
  String? token = 'valid-test-token-12345';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}

void main() {
  test('WorkerBackendLeaveRepository fetches and maps leaves from server', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/mobile/worker/leaves');
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer valid-test-token-12345');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': [
              {
                '_id': 'leave-101',
                'reason': 'Family emergency',
                'startsAt': '2026-11-01T09:00:00.000Z',
                'endsAt': '2026-11-03T18:00:00.000Z',
                'status': 'approved',
                'createdAt': '2026-10-25T10:00:00.000Z',
              },
              {
                '_id': 'leave-102',
                'reason': 'Health checkup',
                'startsAt': '2026-11-10T09:00:00.000Z',
                'endsAt': '2026-11-10T18:00:00.000Z',
                'status': 'pending',
                'createdAt': '2026-10-26T10:00:00.000Z',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final opsApi = WorkerMobileOperationsApi(
      apiBaseUrl: 'http://localhost:5001/api',
      tokenStorage: _MemoryTokenStorage(),
      client: client,
    );

    final repo = WorkerBackendLeaveRepository(operationsApi: opsApi);
    expect(repo.isInitialized, isFalse);

    await repo.initialize();
    expect(repo.isInitialized, isTrue);
    expect(repo.requests.length, 2);

    expect(repo.requests[0].id, 'leave-101');
    expect(repo.requests[0].reason, 'Family emergency');
    expect(repo.requests[0].status, WorkerLeaveStatus.approved);

    expect(repo.requests[1].id, 'leave-102');
    expect(repo.requests[1].reason, 'Health checkup');
    expect(repo.requests[1].status, WorkerLeaveStatus.pending);
  });

  test('WorkerBackendLeaveRepository submits leave with idempotency and updates list', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': []},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/api/mobile/worker/leaves');
      expect(request.method, 'POST');
      expect(request.headers['x-idempotency-key'], isNotNull);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['reason'], 'Vacation');
      expect(body['startsAt'], isNotEmpty);
      expect(body['endsAt'], isNotEmpty);

      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            '_id': 'leave-new-202',
            'status': 'pending',
            'reason': 'Vacation',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final opsApi = WorkerMobileOperationsApi(
      apiBaseUrl: 'http://localhost:5001/api',
      tokenStorage: _MemoryTokenStorage(),
      client: client,
    );

    final repo = WorkerBackendLeaveRepository(operationsApi: opsApi);
    await repo.initialize();
    expect(repo.requests.isEmpty, isTrue);

    final created = await repo.saveDraft(
      from: DateTime(2026, 12, 1),
      to: DateTime(2026, 12, 5),
      reason: 'Vacation',
    );

    expect(created.id, 'leave-new-202');
    expect(created.reason, 'Vacation');
    expect(created.status, WorkerLeaveStatus.pending);
    expect(repo.requests.length, 1);
    expect(repo.requests.first.id, 'leave-new-202');
  });
}
