import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_profile_data.dart';
import 'package:worker_app/features/home/worker_profile_settings_screen.dart';
import 'package:worker_app/features/home/worker_home_screen.dart';
import 'package:worker_app/features/registration/screens/worker_review_submit_screen.dart';

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
    final repository = WorkerProfileRepository(_MemoryProfileStorage());
    await repository.save(_profile());
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerProfileSettingsScreen(
          phoneNumber: '9876543210',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service Specialization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut'));
    await tester.tap(find.text('Save specializations'));
    await tester.pumpAndSettle();
    expect((await repository.load('9876543210'))?.services, [
      'Hair Spa',
      'Haircut',
    ]);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      (await repository.load('9876543210'))?.notificationsEnabled,
      isFalse,
    );
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
    expect(find.text('Maya Joshi'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Maya Updated',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Maya Updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
}
