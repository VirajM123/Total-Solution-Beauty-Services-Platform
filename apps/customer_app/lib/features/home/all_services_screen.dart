import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
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

const _categories = [
  _ServiceCategory(
    name: 'Facial',
    description: 'Glow with healthy, radiant skin',
    image: AppAssets.serviceFacial,
    icon: Icons.spa_outlined,
    homeCategory: 'Facial',
  ),
  _ServiceCategory(
    name: 'Hair Care & Spa',
    description: 'Nourish, strengthen and shine',
    image: AppAssets.serviceHairCareSpa,
    icon: Icons.face_3_outlined,
    homeCategory: 'Hair Spa',
  ),
  _ServiceCategory(
    name: 'Makeup',
    description: 'Look beautiful for every occasion',
    image: AppAssets.serviceMakeup,
    icon: Icons.brush_outlined,
    homeCategory: 'Makeup',
  ),
  _ServiceCategory(
    name: 'Waxing',
    description: 'Smooth and confident skin',
    image: AppAssets.serviceWaxing,
    icon: Icons.auto_fix_high_outlined,
    homeCategory: 'Waxing',
  ),
  _ServiceCategory(
    name: 'Manicure & Pedicure',
    description: 'Perfect care for your hands & feet',
    image: AppAssets.serviceManicurePedicure,
    icon: Icons.back_hand_outlined,
    homeCategory: 'Manicure',
  ),
  _ServiceCategory(
    name: 'Threading',
    description: 'Clean, precise and well-shaped',
    image: AppAssets.serviceThreading,
    icon: Icons.remove_red_eye_outlined,
    homeCategory: 'Threading',
  ),
  _ServiceCategory(
    name: 'Bridal Services',
    description: 'Make your special day more special',
    image: AppAssets.serviceBridal,
    icon: Icons.face_retouching_natural_outlined,
    homeCategory: 'Bridal Services',
  ),
  _ServiceCategory(
    name: 'Beauty Packages',
    description: 'Complete care for total beauty',
    image: AppAssets.serviceBeautyPackages,
    icon: Icons.spa_outlined,
    homeCategory: 'Beauty Packages',
  ),
  _ServiceCategory(
    name: 'Body Polish',
    description: 'Smooth, nourish and brighten your skin',
    image: AppAssets.bodyPolishMain,
    icon: Icons.spa_outlined,
    homeCategory: 'Body Polish',
  ),
  _ServiceCategory(
    name: 'Clean Up',
    description: 'A quick refresh for clear, healthy-looking skin',
    image: AppAssets.cleanUpMain,
    icon: Icons.face_retouching_natural_outlined,
    homeCategory: 'Clean Up',
  ),
  _ServiceCategory(
    name: 'Hair Color',
    description: 'Refresh your look with professional color',
    image: AppAssets.hairColorMain,
    icon: Icons.palette_outlined,
    homeCategory: 'Hair Color',
  ),
  _ServiceCategory(
    name: 'Hair Mehendi',
    description: 'Natural color and care for your hair',
    image: AppAssets.hairMehendiMain,
    icon: Icons.brush_outlined,
    homeCategory: 'Hair Mehendi',
  ),
  _ServiceCategory(
    name: 'Hair Cut',
    description: 'Find a cut that suits your style',
    image: AppAssets.hairCutMain,
    icon: Icons.content_cut_outlined,
    homeCategory: 'Hair Cut',
  ),
];

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({
    super.key,
    required this.onBack,
    required this.onCategorySelected,
    required this.onServiceSelected,
    required this.subservicesByCategory,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onServiceSelected;
  final Map<String, List<String>> subservicesByCategory;

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
    final query = _search.text.trim().toLowerCase();
    final visibleCategories = _categories
        .where((category) => category.name.toLowerCase().contains(query))
        .toList();
    final matchingServices = query.isEmpty
        ? <({String category, String name})>[]
        : [
            for (final category in _categories)
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
                            'Preview catalog · sample prices and durations',
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
                        return ListTile(
                          key: ValueKey('search-service-${service.name}'),
                          tileColor: Colors.white,
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
                  child: Image.asset(
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
