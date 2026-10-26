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
    pricePaise: _parsePaise(json['pricePaise']),
    compareAtPricePaise: json['compareAtPricePaise'] == null
        ? null
        : _parsePaise(json['compareAtPricePaise']),
    durationMinutes: json['durationMinutes'] as int,
    homeService: json['isHomeServiceAvailable'] == true,
    thumbnail: json['thumbnail'] as String?,
    images: (json['images'] as List? ?? [])
        .map((item) => (item as Map<String, dynamic>)['url'] as String)
        .toList(),
    benefits: (json['benefits'] as List? ?? []).cast<String>(),
  );
}

BigInt _parsePaise(Object value) => switch (value) {
  String amount => BigInt.parse(amount),
  int amount => BigInt.from(amount),
  _ => throw FormatException('Invalid paise amount: $value'),
};

class CatalogResourcePage<T> {
  const CatalogResourcePage(this.items, this.page, this.hasMore);
  final List<T> items;
  final int page;
  final bool hasMore;

  factory CatalogResourcePage.parse(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) parse,
  ) {
    final pagination = data['pagination'] as Map<String, dynamic>;
    return CatalogResourcePage(
      (data['items'] as List)
          .map((item) => parse(item as Map<String, dynamic>))
          .toList(),
      pagination['page'] as int,
      pagination['hasMore'] as bool,
    );
  }
}

class CatalogPackage {
  const CatalogPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.serviceIds,
    required this.pricePaise,
    required this.durationMinutes,
    this.thumbnail,
  });
  final String id, name, description;
  final List<String> serviceIds;
  final BigInt pricePaise;
  final int durationMinutes;
  final String? thumbnail;
  String get priceLabel => CatalogService.formatPaise(pricePaise);

  factory CatalogPackage.fromJson(Map<String, dynamic> json) => CatalogPackage(
    id: (json['id'] ?? json['_id']) as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    serviceIds: (json['components'] as List? ?? [])
        .map(
          (component) =>
              (component as Map<String, dynamic>)['serviceId'] as String,
        )
        .toList(),
    pricePaise: _parsePaise(json['pricePaise']),
    durationMinutes: json['durationMinutes'] as int,
    thumbnail: json['thumbnail'] as String?,
  );
}

class CatalogOffer {
  const CatalogOffer({
    required this.id,
    required this.name,
    required this.description,
    required this.code,
    required this.discountType,
    required this.value,
    required this.endsAt,
    this.minimumOrderPaise,
    this.maximumDiscountPaise,
    this.thumbnail,
  });
  final String id, name, description, code, discountType;
  final int value;
  final DateTime endsAt;
  final BigInt? minimumOrderPaise, maximumDiscountPaise;
  final String? thumbnail;

  String get discountLabel => discountType == 'percentage'
      ? '$value% off'
      : '${CatalogService.formatPaise(BigInt.from(value))} off';

  factory CatalogOffer.fromJson(Map<String, dynamic> json) => CatalogOffer(
    id: (json['id'] ?? json['_id']) as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    code: json['code'] as String,
    discountType: json['discountType'] as String,
    value: json['value'] as int,
    endsAt: DateTime.parse(json['endsAt'] as String),
    minimumOrderPaise: json['minimumOrderPaise'] == null
        ? null
        : _parsePaise(json['minimumOrderPaise']),
    maximumDiscountPaise: json['maximumDiscountPaise'] == null
        ? null
        : _parsePaise(json['maximumDiscountPaise']),
    thumbnail: json['thumbnail'] as String?,
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

  Future<CatalogResourcePage<CatalogPackage>> packages({int page = 1}) async =>
      CatalogResourcePage.parse(
        await api.get(
          '/catalog/packages',
          query: {'page': '$page', 'limit': '20'},
        ),
        CatalogPackage.fromJson,
      );

  Future<CatalogResourcePage<CatalogOffer>> offers({int page = 1}) async =>
      CatalogResourcePage.parse(
        await api.get(
          '/catalog/offers',
          query: {'page': '$page', 'limit': '20'},
        ),
        CatalogOffer.fromJson,
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
