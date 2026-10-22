import '../../core/api/mobile_api.dart';

class CatalogPage<T> {
  const CatalogPage(this.items, this.page, this.pages, this.total);
  final List<T> items;
  final int page, pages, total;
  factory CatalogPage.parse(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) parse,
  ) {
    final pagination = data['pagination'] as Map<String, dynamic>;
    return CatalogPage(
      (data['items'] as List)
          .map((item) => parse(item as Map<String, dynamic>))
          .toList(),
      pagination['page'] as int,
      pagination['pages'] as int,
      pagination['total'] as int,
    );
  }
}

class CatalogCategory {
  const CatalogCategory(this.id, this.name, this.image);
  final String id, name;
  final String? image;
  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      CatalogCategory(
        json['id'] as String,
        json['name'] as String,
        (json['image'] as Map<String, dynamic>?)?['url'] as String?,
      );
}

class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryId,
    required this.summary,
    required this.description,
    required this.pricePaise,
    required this.durationMinutes,
    required this.homeService,
    required this.images,
    required this.benefits,
    this.thumbnail,
    this.compareAtPricePaise,
  });
  final String id, name, category, categoryId, summary, description;
  final BigInt pricePaise;
  final BigInt? compareAtPricePaise;
  final int durationMinutes;
  final bool homeService;
  final List<String> images, benefits;
  final String? thumbnail;
  String get priceLabel => formatPaise(pricePaise);
  static String formatPaise(BigInt value) {
    final fraction = (value % BigInt.from(100)).toString().padLeft(2, '0');
    return '₹${value ~/ BigInt.from(100)}${fraction == '00' ? '' : '.$fraction'}';
  }

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
    id: json['id'] as String,
    name: json['name'] as String,
    category: (json['category'] as Map<String, dynamic>)['name'] as String,
    categoryId: (json['category'] as Map<String, dynamic>)['id'] as String,
    summary: json['shortDescription'] as String? ?? '',
    description: json['description'] as String? ?? '',
    pricePaise: BigInt.parse(json['pricePaise'] as String),
    compareAtPricePaise: json['compareAtPricePaise'] == null
        ? null
        : BigInt.parse(json['compareAtPricePaise'] as String),
    durationMinutes: json['durationMinutes'] as int,
    homeService: json['isHomeServiceAvailable'] == true,
    thumbnail: json['thumbnail'] as String?,
    images: (json['images'] as List? ?? [])
        .map((item) => (item as Map<String, dynamic>)['url'] as String)
        .toList(),
    benefits: (json['benefits'] as List? ?? []).cast<String>(),
  );
}

class CatalogRepository {
  CatalogRepository(this.api);
  final MobileApi api;
  Future<CatalogPage<CatalogCategory>> categories({int page = 1}) async =>
      CatalogPage.parse(
        await api.get(
          '/catalog/categories',
          query: {'page': '$page', 'limit': '100'},
        ),
        CatalogCategory.fromJson,
      );
  Future<CatalogPage<CatalogService>> services({
    int page = 1,
    String search = '',
    String? categoryId,
  }) async => CatalogPage.parse(
    await api.get(
      '/catalog/services',
      query: {
        'page': '$page',
        'limit': '20',
        if (search.isNotEmpty) 'search': search,
        'categoryId': ?categoryId,
      },
    ),
    CatalogService.fromJson,
  );
  Future<CatalogService> service(String id) async => CatalogService.fromJson(
    await api.get('/catalog/services/${Uri.encodeComponent(id)}'),
  );

  /// Traverses backend displayOrder + id order, including page boundaries.
  Future<CatalogNeighbors> neighbors(CatalogService current) async {
    CatalogService? previous;
    var found = false;
    var page = 1;
    while (true) {
      final result = await services(page: page, categoryId: current.categoryId);
      for (final item in result.items) {
        if (item.categoryId != current.categoryId) continue;
        if (found) return CatalogNeighbors(previous, item);
        if (item.id == current.id) {
          found = true;
        } else {
          previous = item;
        }
      }
      if (page >= result.pages) {
        return CatalogNeighbors(found ? previous : null, null);
      }
      page++;
    }
  }
}

class CatalogNeighbors {
  const CatalogNeighbors(this.previous, this.next);
  final CatalogService? previous, next;
}
