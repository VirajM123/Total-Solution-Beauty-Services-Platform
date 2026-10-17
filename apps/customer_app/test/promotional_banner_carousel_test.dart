import 'package:customer_app/features/home/promotional_banner_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _firstBanner = PromotionalBanner(
  id: 'first',
  title: 'First slide',
  subtitle: 'First subtitle',
  imageAsset: 'assets/images/home/home_hero.png',
  callToAction: 'Explore',
  action: PromotionalBannerAction.service,
  targetId: 'service-1',
);

const _banners = [
  _firstBanner,
  PromotionalBanner(
    id: 'second',
    title: 'Second slide',
    imageAsset: 'assets/images/home/gold_facial.png',
  ),
];

Widget _carousel({
  List<PromotionalBanner> banners = _banners,
  bool isActive = true,
  bool disableAnimations = false,
  ValueChanged<PromotionalBanner>? onBannerTap,
  ValueChanged<int>? onPageChanged,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: SizedBox(
          width: 320,
          child: PromotionalBannerCarousel(
            banners: banners,
            width: 320,
            isActive: isActive,
            onBannerTap: onBannerTap,
            onPageChanged: onPageChanged,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders no carousel when there are no banners', (tester) async {
    await tester.pumpWidget(_carousel(banners: const []));

    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single banner stays still and can invoke its action', (
    tester,
  ) async {
    PromotionalBanner? tappedBanner;
    await tester.pumpWidget(
      _carousel(
        banners: const [_firstBanner],
        onBannerTap: (banner) => tappedBanner = banner,
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.text('First slide'));

    expect(tappedBanner?.id, 'first');
    expect(find.bySemanticsLabel('Banner 1 of 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatically advances between multiple banners', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(_carousel(onPageChanged: changes.add));
    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pumpAndSettle();

    expect(changes, contains(1));
    expect(find.bySemanticsLabel('Banner 2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual swipes work and autoplay resumes after the swipe', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(_carousel(onPageChanged: changes.add));
    await tester.drag(find.byType(PageView), const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(changes, contains(1));
    await tester.pump(const Duration(milliseconds: 4400));
    expect(changes.last, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(changes.last, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses when inactive or reduced motion is requested', (
    tester,
  ) async {
    final inactiveChanges = <int>[];
    await tester.pumpWidget(
      _carousel(isActive: false, onPageChanged: inactiveChanges.add),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(inactiveChanges, isEmpty);

    final reducedMotionChanges = <int>[];
    await tester.pumpWidget(
      _carousel(
        disableAnimations: true,
        onPageChanged: reducedMotionChanges.add,
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(reducedMotionChanges, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pauses while the app is in the background', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_carousel(onPageChanged: changes.add));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(changes, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pumpAndSettle();

    expect(changes, contains(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a fallback when a banner image cannot load', (
    tester,
  ) async {
    const brokenImageBanner = PromotionalBanner(
      id: 'broken',
      title: 'Fallback banner',
      imageAsset: 'assets/images/home/missing-banner.png',
    );
    await tester.pumpWidget(_carousel(banners: const [brokenImageBanner]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels autoplay and disposes its page controller', (
    tester,
  ) async {
    await tester.pumpWidget(_carousel());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
  });
}
