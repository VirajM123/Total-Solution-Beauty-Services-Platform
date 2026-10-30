import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_profile_data.dart';
import 'package:worker_app/features/home/worker_profile_settings_screen.dart';
import 'package:worker_app/features/home/worker_home_screen.dart';
import 'package:worker_app/features/registration/screens/worker_review_submit_screen.dart';

class _TestTokenStorage implements WorkerTokenStorage {
  String? token = 'valid-test-token-12345';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}

class _MemoryProfileStorage implements WorkerProfileStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

WorkerProfile _profile({
  String fullName = 'Maya Joshi',
  String mobile = '9876543210',
  List<String> services = const ['Hair Spa'],
  bool notifications = true,
}) => WorkerProfile(
  mobile: mobile,
  fullName: fullName,
  email: 'maya@example.com',
  dateOfBirth: DateTime(1994, 5, 12),
  cityOrArea: 'Latur',
  primaryCategory: 'Hair',
  services: services,
  yearsOfExperience: 5,
  workMode: 'Home visits',
  travelRadiusKm: 10,
  languages: const ['Marathi'],
  about: '',
  certificateDetails: '',
  notificationsEnabled: notifications,
);

void main() {
  test(
    'profile is isolated by mobile and reloads from secure storage',
    () async {
      final storage = _MemoryProfileStorage();
      final firstRepository = WorkerProfileRepository(storage);
      await firstRepository.save(_profile());

      final restoredRepository = WorkerProfileRepository(storage);
      final restored = await restoredRepository.load('+91 98765 43210');
      expect(restored?.fullName, 'Maya Joshi');
      expect(restored?.services, ['Hair Spa']);
      expect(await restoredRepository.load('9876543211'), isNull);
    },
  );

  test(
    'registration merge does not overwrite saved optional details',
    () async {
      final repository = WorkerProfileRepository(_MemoryProfileStorage());
      await repository.save(_profile());
      final merged = await repository.saveRegistration(
        _profile(
          fullName: 'Maya Joshi Updated',
          services: const [],
        ).copyWith(email: '', cityOrArea: '', languages: const []),
      );

      expect(merged.fullName, 'Maya Joshi Updated');
      expect(merged.email, 'maya@example.com');
      expect(merged.cityOrArea, 'Latur');
      expect(merged.services, ['Hair Spa']);
      expect(merged.languages, ['Marathi']);
    },
  );

  testWidgets('registration preview saves its supplied profile locally', (
    tester,
  ) async {
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerReviewSubmitScreen(
          fullName: 'Maya Joshi',
          mobile: '9876543210',
          email: 'maya@example.com',
          dateOfBirth: DateTime(1994, 5, 12),
          cityOrArea: 'Latur',
          primaryCategory: 'Hair',
          services: const ['Hair Spa'],
          yearsOfExperience: 5,
          workMode: 'Home visits',
          travelRadiusKm: 10,
          languages: const ['Marathi'],
          about: 'Stylist',
          certificateDetails: '',
          identityType: 'Aadhaar',
          identityFileFormat: 'jpg',
          profileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final accurate = find.text(
      'I confirm the entered information is accurate.',
    );
    await tester.dragUntilVisible(
      accurate,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(accurate);
    final demoAcknowledgement = find.text(
      'I understand this is a demo, not a real submission.',
    );
    await tester.dragUntilVisible(
      demoAcknowledgement,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(demoAcknowledgement);
    await tester.pumpAndSettle();
    await tester.tap(demoAcknowledgement);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview submission'));
    await tester.pumpAndSettle();

    final saved = await repository.load('9876543210');
    expect(saved?.fullName, 'Maya Joshi');
    expect(saved?.services, ['Hair Spa']);
  });

  testWidgets('profile actions use Material list tiles and save edits', (
    tester,
  ) async {
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await repository.save(_profile());
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerProfileSettingsScreen(
          workerName: 'Maya Joshi',
          phoneNumber: '9876543210',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Maya Joshi'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Service Specialization'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextFormField, 'Full name');
    await tester.enterText(nameField, 'Maya Joshi Updated');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Maya Joshi Updated'), findsOneWidget);
    expect(
      (await repository.load('9876543210'))?.fullName,
      'Maya Joshi Updated',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('specializations and notification preference persist', (
    tester,
  ) async {
    final api = WorkerMobileOperationsApi(
      apiBaseUrl: 'https://example.test/api',
      tokenStorage: _TestTokenStorage(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/catalog/services')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'hair-spa',
                    'name': 'Hair Spa',
                    'category': {'name': 'Hair'},
                  },
                  {
                    'id': 'haircut',
                    'name': 'Haircut',
                    'category': {'name': 'Hair'},
                  },
                ],
                'pagination': {'page': 1, 'pages': 1},
              },
            }),
            200,
          );
        }
        return http.Response('{"success":true,"data":{}}', 200);
      }),
    );
    addTearDown(api.close);
    final repository = WorkerProfileRepository(
      _MemoryProfileStorage(),
      operationsApi: api,
    );
    expect(await repository.serviceOptions(), {
      'Hair': ['Hair Spa', 'Haircut'],
    });
    await repository.save(_profile());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => WorkerServiceSpecializationScreen(
                    profile: _profile(),
                    repository: repository,
                  ),
                ),
              ),
              child: const Text('Open specializations'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open specializations'));
    await tester.pumpAndSettle();
    expect(find.text('Haircut'), findsOneWidget);
    await tester.tap(find.text('Haircut'));
    await tester.tap(find.text('Save specializations'));
    await tester.pumpAndSettle();
    expect(repository.profileFor('9876543210')?.services, [
      'Hair Spa',
      'Haircut',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerProfileSettingsScreen(
          phoneNumber: '9876543210',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.profileFor('9876543210')?.notificationsEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile name edit updates the dashboard through shared state', (
    tester,
  ) async {
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await repository.save(_profile());
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerHomeScreen(
          phoneNumber: '9876543210',
          demoMode: false,
          profileRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('Maya'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Nisha Updated',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('Nisha'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('online workers keep offer polling if booking history fails', (
    tester,
  ) async {
    final api = WorkerMobileOperationsApi(
      apiBaseUrl: 'https://example.test/api',
      tokenStorage: _TestTokenStorage(),
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/mobile/worker/profile':
            return http.Response(
              '{"success":true,"data":{"profile":{"isOnline":true}}}',
              200,
            );
          case '/api/mobile/worker/bookings':
            return http.Response(
              '{"success":false,"error":{"code":"TEMPORARY_ERROR","message":"Unavailable."}}',
              503,
            );
          case '/api/mobile/worker/offers':
            return http.Response(
              '{"success":true,"data":{"items":[{"_id":"offer-1","bookingId":"booking-1","status":"offered","expiresAt":"${DateTime.now().add(const Duration(minutes: 1)).toUtc().toIso8601String()}","startsAt":"${DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String()}","serviceAreaName":"Latur","items":[{"name":"Hair Spa","durationMinutes":60}],"customerPayable":100}]}}',
              200,
            );
          case '/api/mobile/worker/notifications':
            return http.Response('{"success":true,"data":{"items":[]}}', 200);
          default:
            return http.Response(
              '{"success":false,"error":{"code":"NOT_FOUND","message":"Not found."}}',
              404,
            );
        }
      }),
    );
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await repository.save(_profile());

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerHomeScreen(
          phoneNumber: '9876543210',
          demoMode: false,
          profileRepository: repository,
          operationsApi: api,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('New Booking Request'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.close();
  });

  testWidgets('help validates and does not claim draft was submitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerHelpSupportScreen(phoneNumber: '9876543210'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save local draft'));
    await tester.pumpAndSettle();
    expect(find.text('Describe your issue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terms page reports unavailable approved content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkerTermsPrivacyScreen()),
    );
    expect(
      find.text('Approved terms and privacy content is not configured.'),
      findsOneWidget,
    );
  });

  testWidgets('profile has no horizontal overflow on compact phone widths', (
    tester,
  ) async {
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await repository.save(_profile());
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerProfileSettingsScreen(
            phoneNumber: '9876543210',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('preview exit requires confirmation', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerAccountSecurityScreen(
          phoneNumber: '9876543210',
          onExitPreview: () => exited = true,
        ),
      ),
    );
    await tester.tap(find.text('Exit preview'));
    await tester.pumpAndSettle();
    expect(exited, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Exit preview'));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
  });

  test(
    'WorkerProfileRepository live loads and live patches profile to server with MockClient',
    () async {
      var patchCalled = false;
      Map<String, dynamic>? patchedBody;

      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/mobile/worker/profile') {
          expect(
            request.headers['authorization'],
            'Bearer valid-test-token-12345',
          );
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {
                  '_id': 'user-101',
                  'fullName': 'Rushi Mane',
                  'mobileNumber': '+919850905140',
                  'email': 'rushi@hiibeauty.test',
                },
                'profile': {
                  '_id': 'worker-101',
                  'userId': 'user-101',
                  'experienceYears': 3,
                  'status': 'approved',
                  'isOnline': true,
                  'cityOrArea': 'Latur Central',
                  'primaryCategory': 'Hair',
                  'services': ['Haircut', 'Hair Spa'],
                  'languages': ['English', 'Marathi'],
                  'about': 'Master Hair Stylist',
                  'certificateDetails': 'Certified Salon Pro',
                  'notificationsEnabled': true,
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/mobile/worker/profile') {
          patchCalled = true;
          patchedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {'fullName': patchedBody!['fullName']},
                'profile': patchedBody,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success":false}', 404);
      });

      final opsApi = WorkerMobileOperationsApi(
        apiBaseUrl: 'http://localhost:5001/api',
        tokenStorage: _TestTokenStorage(),
        client: client,
      );

      final storage = _MemoryProfileStorage();
      final repo = WorkerProfileRepository(storage, operationsApi: opsApi);

      // Initial load from server
      final profile = await repo.load('9850905140');
      expect(profile, isNotNull);
      expect(profile?.fullName, 'Rushi Mane');
      expect(profile?.cityOrArea, 'Latur Central');
      expect(profile?.primaryCategory, 'Hair');
      expect(profile?.services, ['Haircut', 'Hair Spa']);

      // Save changes
      final updated = profile!.copyWith(
        fullName: 'Rushi Mane Senior',
        about: 'Senior Master Stylist',
      );
      await repo.save(updated);

      expect(patchCalled, isTrue);
      expect(patchedBody?['fullName'], 'Rushi Mane Senior');
      expect(patchedBody?['about'], 'Senior Master Stylist');
      expect(patchedBody?['cityOrArea'], 'Latur Central');
    },
  );

  testWidgets(
    'WorkerProfileSettingsScreen shows verified partner badge and live production banner in live mode',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = _MemoryProfileStorage();
      final repo = WorkerProfileRepository(storage);
      await repo.save(_profile(fullName: 'Rushi Mane', mobile: '9850905140'));

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerProfileSettingsScreen(
            workerName: 'Rushi Mane',
            phoneNumber: '9850905140',
            demoMode: false,
            isVerified: true,
            onLogoutTap: () {},
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('VERIFIED PARTNER · Approved Salon Professional'),
        findsOneWidget,
      );
      expect(
        find.text('LIVE PRODUCTION · Profile synced with salon backend'),
        findsOneWidget,
      );
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Exit worker preview'), findsNothing);
    },
  );
}
