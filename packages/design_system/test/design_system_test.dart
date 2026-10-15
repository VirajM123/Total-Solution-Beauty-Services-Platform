import 'package:flutter_test/flutter_test.dart';

import 'package:design_system/design_system.dart';

void main() {
  test('brand theme exposes the primary color', () {
    expect(BeautyTheme.data.colorScheme.primary, BeautyColors.pink);
  });
}
