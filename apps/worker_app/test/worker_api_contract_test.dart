import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/integration/worker_api.dart';
import 'package:worker_app/integration/worker_environment.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const api = PendingWorkerApi();
  test('local preview is opt-in', () {
    expect(
      WorkerEnvironment.developmentPreview,
      const bool.fromEnvironment('WORKER_DEVELOPMENT_PREVIEW'),
    );
  });
  test('only approved server identity may work', () {
    for (final status in WorkerApproval.values) {
      expect(
        WorkerIdentity(workerId: 'server-id', approval: status).mayWork,
        status == WorkerApproval.approved,
      );
    }
  });
  test('auth pending never fabricates identity or OTP delivery', () async {
    for (final operation in [
      () => api.requestOtp('9876543210'),
      () => api.verifyOtp('9876543210', '123456'),
      () => api.currentIdentity(),
      () => api.logout(),
    ]) {
      await expectLater(operation(), throwsA(isA<WorkerIntegrationPending>()));
    }
  });
  test('operations fail closed without local fixture fallback', () async {
    await expectLater(
      api.assignments(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.updateAvailability(true),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.availability(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    for (final action in WorkerJobAction.values) {
      await expectLater(
        api.transition(
          assignmentId: 'server-id',
          action: action,
          idempotencyKey: 'retry-key',
          arrivalOtp: '123456',
          rejectionReason: 'Busy',
        ),
        throwsA(isA<WorkerIntegrationPending>()),
      );
    }
    await expectLater(
      api.collection('server-booking'),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.recordCash(bookingId: 'server-booking', idempotencyKey: 'cash-key'),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.settlements(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
  });
  test('settlement money remains integer paise and pages immutable', () {
    final row = WorkerSettlementRecord(
      id: 's1',
      settlementDate: DateTime.utc(2026),
      bookingCount: 2,
      earningsPaise: 10001,
      adjustmentsPaise: -1,
      netPaise: 10000,
      status: 'pending',
    );
    final page = WorkerPage(items: [row], page: 1, hasMore: false);
    expect(page.items.single.netPaise, 10000);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test(
    'worker OTP login persists a scoped session and reads approval status',
    () async {
      final storage = _MemoryWorkerTokenStorage();
      final api = WorkerMobileAuthApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/otp/request')) {
            expect(request.body, contains('"appType":"worker"'));
            expect(request.body, contains('"mobileNumber":"+919876543210"'));
            expect(request.body, contains('"flow":"login"'));
            return http.Response(
              '{"success":true,"data":{"challengeId":"aaaaaaaaaaaaaaaaaaaaaaaa"}}',
              201,
            );
          }
          if (request.url.path.endsWith('/otp/verify')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['fullName'], isNotNull);
            return http.Response(
              '{"success":true,"data":{"accessToken":"${'s' * 43}","appType":"worker","workerStatus":"pending","user":{"id":"worker-user","fullName":"Worker","mobileNumber":"+919876543210"}}}',
              200,
            );
          }
          if (request.url.path.endsWith('/profile')) {
            expect(request.headers['authorization'], 'Bearer ${'s' * 43}');
            return http.Response(
              '{"success":true,"data":{"user":{"_id":"worker-user"},"profile":{"_id":"worker-profile","status":"pending"}}}',
              200,
            );
          }
          expect(request.url.path, endsWith('/logout'));
          return http.Response(
            '{"success":true,"data":{"loggedOut":true}}',
            200,
          );
        }),
      );
      await api.requestOtp('9876543210');
      final loggedIn = await api.verifyOtp('9876543210', '654321');
      expect(loggedIn.approval, WorkerApproval.pending);
      expect(storage.token, '${'s' * 43}');
      final current = await api.currentIdentity();
      expect(current.workerId, 'worker-profile');
      expect(current.approval, WorkerApproval.pending);
      await api.logout();
      expect(storage.token, isNull);
      api.close();
    },
  );

  test(
    'new worker registration requires verified proof and receives scoped token',
    () async {
      final storage = _MemoryWorkerTokenStorage();
      final api = WorkerMobileAuthApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: storage,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/otp/request')) {
            expect(request.body, contains('"flow":"registration"'));
            return http.Response(
              '{"success":true,"data":{"challengeId":"bbbbbbbbbbbbbbbbbbbbbbbb"}}',
              201,
            );
          }
          if (request.url.path.endsWith('/otp/verify')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['fullName'], isNotNull);
            return http.Response(
              '{"success":true,"data":{"registrationRequired":true,"registrationToken":"${'r' * 43}","appType":"worker"}}',
              200,
            );
          }
          expect(request.url.path, endsWith('/register/worker'));
          expect(request.body, contains('"registrationToken":"${'r' * 43}"'));
          return http.Response(
            '{"success":true,"data":{"accessToken":"${'w' * 43}","appType":"worker","user":{"id":"worker-user","fullName":"Worker","mobileNumber":"+919876543210"}}}',
            201,
          );
        }),
      );
      await api.requestOtp('9876543210', forRegistration: true);
      final proof = await api.verifyOtp('9876543210', '654321');
      expect(proof.registrationToken, '${'r' * 43}');
      final identity = await api.completeRegistration(
        registrationToken: proof.registrationToken!,
        fullName: 'Worker',
      );
      expect(identity.workerId, 'worker-user');
      expect(identity.approval, WorkerApproval.notRegistered);
      expect(storage.token, '${'w' * 43}');
      api.close();
    },
  );

  test(
    'unregistered worker login stops before OTP and requests registration',
    () async {
      final api = WorkerMobileAuthApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _MemoryWorkerTokenStorage(),
        client: MockClient((request) async {
          expect(request.body, contains('"flow":"login"'));
          return http.Response(
            '{"success":true,"data":{"registrationRequired":true,"appType":"worker","mobileNumber":"+919876543210"}}',
            200,
          );
        }),
      );
      await expectLater(
        api.requestOtp('9876543210'),
        throwsA(
          isA<WorkerAuthException>().having(
            (error) => error.code,
            'code',
            'REGISTRATION_REQUIRED',
          ),
        ),
      );
      api.close();
    },
  );
}

class _MemoryWorkerTokenStorage implements WorkerTokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}
