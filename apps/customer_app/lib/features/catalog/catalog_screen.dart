import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/mobile_api.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/pinkora_brand.dart';
import 'catalog_repository.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.config, this.repository});
  final AppConfig config;
  final CatalogRepository? repository;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with WidgetsBindingObserver {
  MobileApi? _api;
  late final CatalogRepository _repository;
  final _search = TextEditingController();
  Timer? _debounce;
  List<CatalogCategory> _categories = [];
  CatalogPage<CatalogService>? _services;
  String? _category, _error;
  bool _loading = true;
  bool _categoriesLoaded = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository =
        widget.repository ??
        CatalogRepository(_api = MobileApi(baseUrl: widget.config.apiBaseUrl));
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(page: _services?.page ?? 1, refreshCategories: true);
    }
  }

  Future<void> _load({int page = 1, bool refreshCategories = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch every category page; service pages remain bounded for scrolling.
      final cachedCategories = _categoriesLoaded && !refreshCategories;
      final categories = cachedCategories
          ? List<CatalogCategory>.of(_categories)
          : <CatalogCategory>[];
      var categoryPage = 1;
      while (!cachedCategories) {
        final result = await _repository.categories(page: categoryPage);
        if (!mounted || generation != _generation) return;
        categories.addAll(result.items);
        if (categoryPage >= result.pages) break;
        categoryPage++;
      }
      if (_category != null &&
          !categories.any((item) => item.id == _category)) {
        _category = null;
      }
      final services = await _repository.services(
        page: page,
        search: _search.text.trim(),
        categoryId: _category,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _categories = categories;
        _categoriesLoaded = true;
        _services = services;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is MobileApiException
            ? error.message
            : 'The catalog could not be loaded. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PinkoraBrand.ivory,
    appBar: AppBar(
      title: const Text(PinkoraBrand.name),
      backgroundColor: PinkoraBrand.ivory,
      foregroundColor: PinkoraBrand.berry,
      actions: [
        IconButton(
          onPressed: _loading
              ? null
              : () =>
                    _load(page: _services?.page ?? 1, refreshCategories: true),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh catalog',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(refreshCategories: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Beauty, on your terms.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: PinkoraBrand.charcoal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore our beauty services',
            style: TextStyle(color: PinkoraBrand.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'Search services',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onChanged: (_) {
              _debounce?.cancel();
              // Invalidate responses immediately while the next search is debounced.
              _generation++;
              _debounce = Timer(
                const Duration(milliseconds: 350),
                () => _load(),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All services'),
                selected: _category == null,
                onSelected: _loading
                    ? null
                    : (_) {
                        _category = null;
                        _load();
                      },
              ),
              ..._categories.map(
                (item) => ChoiceChip(
                  label: Text(item.name),
                  selected: _category == item.id,
                  onSelected: _loading
                      ? null
                      : (_) {
                          _category = item.id;
                          _load();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            _CatalogError(
              message: _error!,
              retry: () => _load(page: _services?.page ?? 1),
            ),
          if (!_loading && _error == null) ...[
            if (_services?.items.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Text(
                  'No services found. Try another search or category.',
                  textAlign: TextAlign.center,
                ),
              ),
            ...?_services?.items.map(
              (service) => Card(
                margin: const EdgeInsets.only(bottom: 14),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ServiceDetail(
                        repository: _repository,
                        id: service.id,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CatalogImage(url: service.thumbnail, height: 160),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.category,
                              style: const TextStyle(color: PinkoraBrand.berry),
                            ),
                            Text(
                              service.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(service.summary),
                            const SizedBox(height: 12),
                            Text(
                              '${service.priceLabel} · ${service.durationMinutes} min',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: PinkoraBrand.berry,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if ((_services?.pages ?? 0) > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _services!.page > 1
                        ? () => _load(page: _services!.page - 1)
                        : null,
                    child: const Text('Previous'),
                  ),
                  Text('${_services!.page} / ${_services!.pages}'),
                  TextButton(
                    onPressed: _services!.page < _services!.pages
                        ? () => _load(page: _services!.page + 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}

class CatalogImage extends StatelessWidget {
  const CatalogImage({super.key, required this.url, required this.height});
  final String? url;
  final double height;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final placeholder = Container(
      height: height,
      color: PinkoraBrand.line.withValues(alpha: .35),
      child: const Center(
        child: Icon(Icons.spa_outlined, size: 44, color: PinkoraBrand.berry),
      ),
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      return placeholder;
    }
    return Image.network(
      uri.toString(),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 1000,
      errorBuilder: (_, error, stackTrace) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.cloud_off, color: PinkoraBrand.berry),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class _ServiceDetail extends StatefulWidget {
  const _ServiceDetail({required this.repository, required this.id});
  final CatalogRepository repository;
  final String id;
  @override
  State<_ServiceDetail> createState() => _ServiceDetailState();
}

class _ServiceDetailState extends State<_ServiceDetail> {
  late Future<CatalogService> _service;
  late String _currentId;
  @override
  void initState() {
    super.initState();
    _currentId = widget.id;
    _service = widget.repository.service(_currentId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PinkoraBrand.ivory,
    appBar: AppBar(title: const Text('Service details')),
    body: FutureBuilder<CatalogService>(
      future: _service,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CatalogError(
            message: snapshot.error is MobileApiException
                ? (snapshot.error! as MobileApiException).message
                : 'Service details could not be loaded.',
            retry: () => setState(
              () => _service = widget.repository.service(_currentId),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final service = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CatalogImage(
              url: service.images.isEmpty
                  ? service.thumbnail
                  : service.images.first,
              height: 240,
            ),
            const SizedBox(height: 20),
            Text(
              service.category,
              style: const TextStyle(color: PinkoraBrand.berry),
            ),
            Text(
              service.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${service.priceLabel} · ${service.durationMinutes} min',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: PinkoraBrand.berry,
              ),
            ),
            if (service.compareAtPricePaise != null)
              Text(
                CatalogService.formatPaise(service.compareAtPricePaise!),
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
            const SizedBox(height: 16),
            Text(service.description),
            ...service.benefits.map(
              (benefit) => ListTile(
                leading: const Icon(Icons.check, color: PinkoraBrand.berry),
                title: Text(benefit),
              ),
            ),
            if (service.homeService)
              const ListTile(
                leading: Icon(Icons.home_outlined),
                title: Text('Available as a home service'),
              ),
            const SizedBox(height: 20),
            _SiblingNavigation(
              key: ValueKey(service.id),
              repository: widget.repository,
              service: service,
              onSelected: (id) => setState(() {
                _currentId = id;
                _service = widget.repository.service(id);
              }),
            ),
            const Text(
              'Booking will be available when customer sign in and checkout are connected.',
              style: TextStyle(color: PinkoraBrand.muted),
            ),
          ],
        );
      },
    ),
  );
}

class _SiblingNavigation extends StatefulWidget {
  const _SiblingNavigation({
    super.key,
    required this.repository,
    required this.service,
    required this.onSelected,
  });
  final CatalogRepository repository;
  final CatalogService service;
  final ValueChanged<String> onSelected;
  @override
  State<_SiblingNavigation> createState() => _SiblingNavigationState();
}

class _SiblingNavigationState extends State<_SiblingNavigation> {
  late Future<CatalogNeighbors> _neighbors;
  @override
  void initState() {
    super.initState();
    _neighbors = widget.repository.neighbors(widget.service);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CatalogNeighbors>(
    future: _neighbors,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _CatalogError(
          message: 'Other services could not be loaded.',
          retry: () => setState(
            () => _neighbors = widget.repository.neighbors(widget.service),
          ),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final neighbors = snapshot.data!;
      return Column(
        children: [
          Text('More in ${widget.service.category}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: neighbors.previous == null
                    ? null
                    : () => widget.onSelected(neighbors.previous!.id),
                child: const Text('Previous service'),
              ),
              TextButton(
                onPressed: neighbors.next == null
                    ? null
                    : () => widget.onSelected(neighbors.next!.id),
                child: const Text('Next service'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
