import 'dart:async';

import 'package:flutter/material.dart';

enum PromotionalBannerAction { service, category, offer, none }

@immutable
class PromotionalBanner {
  const PromotionalBanner({
    required this.id,
    required this.title,
    required this.imageAsset,
    this.subtitle,
    this.callToAction,
    this.action = PromotionalBannerAction.none,
    this.targetId,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String imageAsset;
  final String? callToAction;
  final PromotionalBannerAction action;
  final String? targetId;
}

class PromotionalBannerCarousel extends StatefulWidget {
  const PromotionalBannerCarousel({
    required this.banners,
    required this.width,
    required this.isActive,
    this.onBannerTap,
    this.onPageChanged,
    super.key,
  });

  final List<PromotionalBanner> banners;
  final double width;
  final bool isActive;
  final ValueChanged<PromotionalBanner>? onBannerTap;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PromotionalBannerCarousel> createState() =>
      _PromotionalBannerCarouselState();
}

class _PromotionalBannerCarouselState extends State<PromotionalBannerCarousel>
    with WidgetsBindingObserver {
  static const _slideInterval = Duration(milliseconds: 4500);
  static const _transitionDuration = Duration(milliseconds: 380);

  final PageController _pageController = PageController();
  Timer? _autoplayTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _isDragging = false;
  bool _disableAnimations = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.of(context).disableAnimations;
    _syncAutoplay();
  }

  @override
  void didUpdateWidget(covariant PromotionalBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banners.isEmpty) {
      _currentPage = 0;
    } else if (_currentPage >= widget.banners.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.banners.length != widget.banners.length) {
      _syncAutoplay();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncAutoplay();
  }

  bool get _canAutoplay =>
      widget.banners.length > 1 &&
      widget.isActive &&
      _lifecycleState == AppLifecycleState.resumed &&
      !_disableAnimations &&
      !_isDragging;

  void _syncAutoplay() {
    if (!_canAutoplay) {
      _autoplayTimer?.cancel();
      _autoplayTimer = null;
      return;
    }
    if (_autoplayTimer != null) return;

    _autoplayTimer = Timer(_slideInterval, () {
      _autoplayTimer = null;
      if (!mounted || !_canAutoplay || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.banners.length;
      _pageController
          .animateToPage(
            nextPage,
            duration: _transitionDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted) _syncAutoplay();
          });
    });
  }

  void _handleScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _isDragging = true;
      _syncAutoplay();
    } else if (notification is ScrollEndNotification && _isDragging) {
      _isDragging = false;
      _syncAutoplay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoplayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final height = (widget.width * 0.48).clamp(139.0, 170.0);
    final animationDuration = _disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return SizedBox(
      width: widget.width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _handleScroll(notification);
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.banners.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  widget.onPageChanged?.call(index);
                },
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return Semantics(
                    button: widget.onBannerTap != null,
                    label: banner.title,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onBannerTap == null
                          ? null
                          : () => widget.onBannerTap!(banner),
                      child: _BannerImage(banner: banner),
                    ),
                  );
                },
              ),
            ),
            if (widget.banners.length > 1)
              Positioned(
                right: 10,
                bottom: 10,
                child: Semantics(
                  label:
                      'Banner ${_currentPage + 1} of ${widget.banners.length}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < widget.banners.length;
                        index++
                      )
                        AnimatedContainer(
                          duration: animationDuration,
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(left: 4),
                          width: index == _currentPage ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? const Color(0xFF8D214D)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.banner});

  final PromotionalBanner banner;

  @override
  Widget build(BuildContext context) {
    if (banner.imageAsset.trim().isEmpty) return const _BannerFallback();
    if (Uri.tryParse(banner.imageAsset)?.hasAuthority == true) {
      return Image.network(
        banner.imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _BannerFallback(),
      );
    }
    return Image.asset(
      banner.imageAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _BannerFallback(),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFE9ED),
    child: Center(
      child: Icon(Icons.spa_outlined, color: Color(0xFF8D214D), size: 36),
    ),
  );
}
