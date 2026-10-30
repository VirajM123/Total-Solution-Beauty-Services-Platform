import 'package:flutter/material.dart';

import '../../core/constants/pinkora_brand.dart';

class _ServiceCategory {
  const _ServiceCategory({
    required this.name,
    required this.description,
    required this.image,
    required this.icon,
    required this.homeCategory,
  });

  final String name;
  final String description;
  final String image;
  final IconData icon;
  final String homeCategory;
}

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({
    super.key,
    required this.onBack,
    required this.onCategorySelected,
    required this.onServiceSelected,
    required this.subservicesByCategory,
    this.categoryNames = const [],
  });

  final VoidCallback onBack;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onServiceSelected;
  final Map<String, List<String>> subservicesByCategory;
  final List<String> categoryNames;

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final _search = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final name
          in widget.categoryNames.isEmpty
              ? widget.subservicesByCategory.keys
              : widget.categoryNames)
        _ServiceCategory(
          name: name,
          description: '',
          image: '',
          icon: Icons.spa_outlined,
          homeCategory: name,
        ),
    ];
    final query = _search.text.trim().toLowerCase();
    final visibleCategories = categories
        .where((category) => category.name.toLowerCase().contains(query))
        .toList();
    final matchingServices = query.isEmpty
        ? <({String category, String name})>[]
        : [
            for (final category in categories)
              for (final name
                  in widget.subservicesByCategory[category.homeCategory] ??
                      const <String>[])
                if (name.toLowerCase().contains(query))
                  (category: category.name, name: name),
          ];

    return ColoredBox(
      color: const Color(0xFFFFF7F8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _HeaderButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onPressed: widget.onBack,
                        ),
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'All Services',
                            maxLines: 1,
                            style: TextStyle(
                              color: PinkoraBrand.charcoal,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Browse available services',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PinkoraBrand.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _HeaderButton(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          tooltip: _searchOpen ? 'Close search' : 'Search',
                          onPressed: () {
                            setState(() {
                              _searchOpen = !_searchOpen;
                              if (!_searchOpen) _search.clear();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchOpen) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      key: const ValueKey('services-search'),
                      controller: _search,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search categories and treatments',
                        prefixIcon: const Icon(Icons.search, size: 19),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: visibleCategories.isEmpty && matchingServices.isEmpty
                ? const Center(
                    child: Text(
                      'No services found. Try another search.',
                      style: TextStyle(color: PinkoraBrand.muted),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('service-categories'),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    itemCount:
                        visibleCategories.length + matchingServices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index >= visibleCategories.length) {
                        final service =
                            matchingServices[index - visibleCategories.length];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            key: ValueKey('search-service-${service.name}'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: const Icon(
                              Icons.spa_outlined,
                              color: PinkoraBrand.berry,
                            ),
                            title: Text(service.name),
                            subtitle: Text(service.category),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: PinkoraBrand.rose,
                            ),
                            onTap: () => widget.onServiceSelected(service.name),
                          ),
                        );
                      }
                      final category = visibleCategories[index];
                      return _CategoryCard(
                        category: category,
                        count:
                            widget
                                .subservicesByCategory[category.homeCategory]
                                ?.length ??
                            0,
                        onTap: () =>
                            widget.onCategorySelected(category.homeCategory),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFFFFE8EE),
      foregroundColor: PinkoraBrand.berry,
      fixedSize: const Size(42, 42),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon, size: 20),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final _ServiceCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final imageWidth = constraints.maxWidth * 0.36;
      final cardHeight = (constraints.maxWidth * 0.25).clamp(92.0, 108.0);
      final badgeSize = (constraints.maxWidth * 0.12).clamp(44.0, 58.0);
      return SizedBox(
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: imageWidth * 0.92,
              child: Material(
                key: ValueKey('service-category-${category.name}'),
                color: const Color(0xFFFFFBFC),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFF6E5E9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D8D214D),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.only(
                      left: imageWidth * 0.30,
                      right: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PinkoraBrand.charcoal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                category.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PinkoraBrand.muted,
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE8EE),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '$count ${count == 1 ? 'service' : 'services'}',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: PinkoraBrand.berry,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 21,
                          color: PinkoraBrand.rose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: imageWidth,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: category.image.trim().isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFFFE8EE),
                          child: Icon(Icons.spa_outlined, color: PinkoraBrand.rose),
                        )
                      : Image.asset(
                    category.image,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (imageWidth * MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFFFE8EE),
                      child: Icon(Icons.spa_outlined, color: PinkoraBrand.rose),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: imageWidth - badgeSize / 2,
              top: (cardHeight - badgeSize) / 2,
              child: IgnorePointer(
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8FA),
                    borderRadius: BorderRadius.circular(badgeSize * 0.30),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x148D214D),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    category.icon,
                    color: PinkoraBrand.rose,
                    size: badgeSize * 0.44,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
