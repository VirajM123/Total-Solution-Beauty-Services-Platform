import 'package:customer_app/features/booking/professional_portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank URL falls through to the saved profile image', () {
    expect(
      professionalPhoto({
        'photoUrl': ' ',
        'profileImageUrl': ' https://example.com/worker.jpg ',
      }),
      'https://example.com/worker.jpg',
    );
    expect(
      professionalPhoto({'profilePhotoPath': 'https://example.com/saved.jpg'}),
      'https://example.com/saved.jpg',
    );
    expect(
      professionalPhoto({'photoUrl': 'file:///private/worker.jpg'}),
      isNull,
    );
  });

  testWidgets(
    'an unavailable portrait renders its fallback without an exception',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfessionalPortrait(
            worker: {'profileImageUrl': 'https://example.test/missing.jpg'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
