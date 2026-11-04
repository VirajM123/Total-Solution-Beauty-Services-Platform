import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final _publicImages = CacheManager(
  Config(
    'customer-public-images-v1',
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 150,
  ),
);

/// Shared public image loader. Cache sizing is separate from server thumbnails:
/// decode limits reduce memory; optimized URLs reduce network traffic.
class CustomerImage extends StatelessWidget {
  /// Widget tests have no native file/database plugins. They keep the same
  /// decoding/fallback path while substituting Flutter's test HTTP provider.
  @visibleForTesting
  static bool diskCacheEnabled = true;
  const CustomerImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
    this.loadingBuilder,
  });
  final String url;
  final double? width, height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final int? cacheWidth, cacheHeight;
  final Alignment alignment;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final logicalWidth = width != null && width!.isFinite
          ? width!
          : (size.hasBoundedWidth ? size.maxWidth : 400);
      final decodeWidth =
          cacheWidth ??
          (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
            1,
            1600,
          );
      Widget fallback(Object error) =>
          errorBuilder?.call(context, error, null) ??
          const ColoredBox(
            color: Color(0xFFFFE9ED),
            child: Center(child: Icon(Icons.spa_outlined)),
          );
      // Tests use Flutter's HTTP override and must not initialize native disk APIs.
      if (kIsWeb || !diskCacheEnabled) {
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          loadingBuilder: loadingBuilder,
          cacheWidth: decodeWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (c, e, s) => fallback(e),
        );
      }
      return CachedNetworkImage(
        cacheManager: _publicImages,
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        memCacheWidth: decodeWidth,
        memCacheHeight: cacheHeight,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (context, _) =>
            loadingBuilder?.call(
              context,
              const ColoredBox(color: Color(0xFFFFE9ED)),
              const ImageChunkEvent(
                cumulativeBytesLoaded: 0,
                expectedTotalBytes: null,
              ),
            ) ??
            const ColoredBox(color: Color(0xFFFFE9ED)),
        errorWidget: (_, _, error) => fallback(error),
      );
    },
  );
}

ImageProvider customerImageProvider(String url, {int width = 192}) =>
    ResizeImage.resizeIfNeeded(
      width,
      null,
      kIsWeb || !CustomerImage.diskCacheEnabled
          ? NetworkImage(url)
          : CachedNetworkImageProvider(url, cacheManager: _publicImages),
    );
