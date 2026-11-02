import 'dart:io';

import 'package:flutter/material.dart';

import '../../integration/worker_mobile_operations_api.dart';

/// Presentation-only catalog lookup. Never changes a booking or its price.
class WorkerServiceImage extends StatefulWidget {
  const WorkerServiceImage({
    super.key,
    required this.service,
    this.imageUrl,
    this.width = 44,
    this.height = 44,
    this.demoMode = false,
    this.serviceId,
  });

  final String service;
  final String? imageUrl;
  final double width;
  final double height;
  final bool demoMode;
  final String? serviceId;

  static Future<List<Map<String, dynamic>>>? _catalog;

  static Future<List<Map<String, dynamic>>> _loadCatalog() async {
    final api = WorkerMobileOperationsApi();
    try {
      return await api.fetchCatalogServices();
    } finally {
      api.close();
    }
  }

  @override
  State<WorkerServiceImage> createState() => _WorkerServiceImageState();
}

class _WorkerServiceImageState extends State<WorkerServiceImage> {
  late Future<List<Map<String, dynamic>>> _images;

  @override
  void initState() {
    super.initState();
    _images = _resolveImages();
  }

  @override
  void didUpdateWidget(covariant WorkerServiceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demoMode != widget.demoMode ||
        oldWidget.imageUrl != widget.imageUrl) {
      _images = _resolveImages();
    }
  }

  Future<List<Map<String, dynamic>>> _resolveImages() =>
      widget.demoMode || (widget.imageUrl?.isNotEmpty ?? false)
      ? Future.value(const [])
      : WorkerServiceImage._catalog ??= WorkerServiceImage._loadCatalog()
            .catchError((Object _) {
              WorkerServiceImage._catalog = null;
              return <Map<String, dynamic>>[];
            });

  String? _previewAsset() {
    final name = widget.service.toLowerCase();
    for (final entry in const {
      'facial': 'gold_facial.png',
      'hair spa': 'hair_spa.png',
      'makeup': 'bridal_makeup.png',
      'manicure': 'manicure.png',
      'wax': 'waxing.png',
    }.entries) {
      if (name.contains(entry.key)) {
        return 'assets/images/services/${entry.value}';
      }
    }
    return null;
  }

  Widget _fallback() {
    final asset = widget.demoMode ? _previewAsset() : null;
    return asset == null
        ? const ColoredBox(
            color: Color(0xFFFFEDF3),
            child: Center(
              child: Icon(
                Icons.spa_outlined,
                size: 20,
                color: Color(0xFFF52D7A),
              ),
            ),
          )
        : Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.spa_outlined, size: 20),
          );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _images,
        builder: (context, snapshot) {
          String? url = widget.imageUrl;
          if (url == null || url.isEmpty) {
            for (final item
                in snapshot.data ?? const <Map<String, dynamic>>[]) {
              final matches = widget.serviceId?.isNotEmpty == true
                  ? '${item['id'] ?? item['_id']}' == widget.serviceId
                  : '${item['name']}'.trim().toLowerCase() ==
                        widget.service.trim().toLowerCase();
              if (!matches) {
                continue;
              }
              url = item['thumbnail'] as String?;
              final images = item['images'];
              if ((url == null || url.isEmpty) &&
                  images is List &&
                  images.isNotEmpty &&
                  images.first is Map) {
                url = images.first['url'] as String?;
              }
              break;
            }
          }
          final uri = Uri.tryParse(url ?? '');
          if (uri == null ||
              !uri.hasAuthority ||
              !{'http', 'https'}.contains(uri.scheme)) {
            return _fallback();
          }
          return Image.network(
            uri.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          );
        },
      ),
    ),
  );
}

/// A worker's own uploaded photo; never substitutes a different person's photo.
class WorkerProfilePhoto extends StatelessWidget {
  const WorkerProfilePhoto({super.key, this.path, this.size = 42});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => ColoredBox(
      color: const Color(0xFFFFE8F0),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: const Color(0xFFF52D7A),
          size: size * .5,
        ),
      ),
    );
    final source = path?.trim() ?? '';
    final uri = Uri.tryParse(source);
    final remote =
        uri != null &&
        uri.hasAuthority &&
        {'http', 'https'}.contains(uri.scheme);
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: source.isEmpty
            ? fallback()
            : remote
            ? Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              )
            : Image.file(
                File(source),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}
