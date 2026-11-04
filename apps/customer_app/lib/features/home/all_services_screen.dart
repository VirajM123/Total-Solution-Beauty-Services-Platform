import '../shared/customer_image.dart';
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
    this.categoryImages = const {},
    this.categoryStartingPrices = const {},
  });

  final VoidCallback onBack;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onServiceSelected;
  final Map<String, List<String>> subservicesByCategory;
  final List<String> categoryNames;
  final Map<String, String> categoryImages;
  final Map<String, int> categoryStartingPrices;

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final _search = TextEditingController();
  String? _selectedCategory;
  bool _filtersOpen = false;

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
          description: _categoryDescription(name),
          image: widget.categoryImages[name] ?? '',
          icon: Icons.spa_outlined,
          homeCategory: name,
        ),
    ];
    final query = _search.text.trim().toLowerCase();
    final visibleCategories = categories
        .where(
          (category) =>
              (_selectedCategory == null ||
                  category.name == _selectedCategory) &&
              category.name.toLowerCase().contains(query),
        )
        .toList();
    final matchingServices = query.isEmpty
        ? <({String category, String name})>[]
        : [
            for (final category in categories.where(
              (category) =>
                  _selectedCategory == null ||
                  category.name == _selectedCategory,
            ))
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
                      const Text(
                        'All Services',
                        style: TextStyle(
                          color: PinkoraBrand.charcoal,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      key: const ValueKey('services-search'),
                      controller: _search,
                      autofocus: false,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search services (eg. facial, makeup)',
                        hintStyle: const TextStyle(fontSize: 11),
                        suffixIcon: IconButton(
                          key: const ValueKey('services-filter'),
                          tooltip: 'Filter categories',
                          onPressed: () =>
                              setState(() => _filtersOpen = !_filtersOpen),
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: _filtersOpen || _selectedCategory != null
                                ? PinkoraBrand.berry
                                : PinkoraBrand.muted,
                          ),
                        ),
                        prefixIcon: const Tooltip(
                          message: 'Search',
                          child: Icon(Icons.search, size: 19),
                        ),
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
          if (_filtersOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final name in <String?>[
                    null,
                    ...categories.map((c) => c.name),
                  ])
                    SizedBox(
                      height: 30,
                      child: ChoiceChip(
                        label: Text(name ?? 'All'),
                        selected: _selectedCategory == name,
                        showCheckmark: false,
                        selectedColor: PinkoraBrand.berry,
                        backgroundColor: const Color(0xFFFFE8EE),
                        side: const BorderSide(color: Color(0xFFFFDCE6)),
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          fontSize: 10,
                          color: _selectedCategory == name
                              ? Colors.white
                              : PinkoraBrand.berry,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = name),
                      ),
                    ),
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
                : GridView.builder(
                    key: const ValueKey('service-categories'),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    itemCount:
                        visibleCategories.length + matchingServices.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 600
                          ? 3
                          : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent:
                          218 +
                          (MediaQuery.textScalerOf(context).scale(12) - 12) * 5,
                    ),
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
                        startingPrice:
                            widget.categoryStartingPrices[category.name],
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
    this.startingPrice,
    required this.onTap,
  });

  final _ServiceCategory category;
  final int count;
  final int? startingPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('service-category-${category.name}'),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFF3DAE3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: category.image.trim().isEmpty
                ? const ColoredBox(
                    color: Color(0xFFFFE8EE),
                    child: Icon(Icons.spa_outlined, color: PinkoraBrand.rose),
                  )
                : Image(
                    image: Uri.tryParse(category.image)?.hasAuthority == true
                        ? customerImageProvider(category.image)
                        : AssetImage(category.image) as ImageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFFFE8EE),
                      child: Icon(Icons.spa_outlined, color: PinkoraBrand.rose),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PinkoraBrand.charcoal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    startingPrice == null
                        ? '$count ${count == 1 ? "service" : "services"}'
                        : 'Starting at ₹$startingPrice',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PinkoraBrand.muted,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 27,
                    decoration: BoxDecoration(
                      color: PinkoraBrand.berry,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'View Services',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
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

String _categoryDescription(String name) {
  final label = name.toLowerCase();
  if (label.contains('facial')) {
    return 'Cleansing, brightening and rejuvenation';
  }
  if (label.contains('spa') || label.contains('hair care')) {
    return 'Nourishment for healthier, shinier hair';
  }
  if (label.contains('makeup')) {
    return 'Party, bridal and special occasion makeup';
  }
  if (label.contains('wax')) return 'Smooth and long-lasting results';
  if (label.contains('manicure') || label.contains('pedicure')) {
    return 'Beautiful nails and relaxing care';
  }
  if (label.contains('bridal')) return 'Beauty care for your special day';
  if (label.contains('thread')) return 'Precise shaping and a smooth finish';
  return 'Professional beauty care at home';
}
