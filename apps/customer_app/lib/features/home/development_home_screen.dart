import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../booking/checkout_models.dart';
import 'all_services_screen.dart';
import 'promotional_banner_carousel.dart';

const _berry = PinkoraBrand.berry;
const _ink = PinkoraBrand.charcoal;
const _muted = PinkoraBrand.muted;
const _bookingPink = Color(0xFFF31B78);
const _bookingBerry = Color(0xFF930738);
const _bookingBlush = Color(0xFFFFF0F5);
const _bookingLine = Color(0xFFF5D9E3);

class _Service {
  const _Service(
    this.name,
    this.category,
    this.price,
    this.minutes,
    this.image, {
    this.originalPrice,
    this.discount,
    this.description =
        'Enjoy a beauty service in the comfort of your home with a verified professional.',
    this.benefits = const [],
  });
  final String name;
  final String category;
  final int price;
  final int minutes;
  final String image;
  final int? originalPrice;
  final String? discount;
  final String description;
  final List<String> benefits;

  String get id => '${category.toLowerCase()}::${name.toLowerCase()}';
}

class _SavedAddress {
  const _SavedAddress({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.postalCode,
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String postalCode;

  String get details => '$street, $city $postalCode';
}

class _ProfileMenuEntry {
  const _ProfileMenuEntry(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog({required this.initialCity});

  final String initialCity;

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cityController.text = widget.initialCity;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SavedAddress(
        id: 'address-${DateTime.now().microsecondsSinceEpoch}',
        label: _labelController.text.trim(),
        street: _streetController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add new address'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('address-label-input'),
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Address label'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a label'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('address-street-input'),
              controller: _streetController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Flat, street or landmark',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your address'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('address-city-input'),
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City, state'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your city'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('address-postal-code-input'),
              controller: _postalCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN code',
                counterText: '',
              ),
              validator: (value) =>
                  value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())
                  ? 'Enter a valid 6-digit PIN code'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save-new-address'),
        onPressed: _save,
        child: const Text('Save address'),
      ),
    ],
  );
}

DateTime _mondayOf(DateTime date) {
  final day = DateUtils.dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

const _services = [
  _Service('Gold Facial', 'Facial', 1200, 60, AppAssets.goldFacial),
  _Service('Hair Spa', 'Hair Spa', 899, 60, AppAssets.hairSpa),
  _Service('Bridal Makeup', 'Makeup', 2500, 120, AppAssets.bridalMakeup),
  _Service('Manicure', 'Manicure', 500, 45, AppAssets.manicure),
  _Service('Waxing', 'Waxing', 699, 45, AppAssets.goldFacial),
];

String _serviceImage(String name) => 'assets/images/services/$name.jpg';

String _formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _formatWeekday(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}

const _categoryHeroImages = <String, String>{
  'Body Polish': AppAssets.bodyPolishMain,
  'Clean Up': AppAssets.cleanUpMain,
  'Hair Color': AppAssets.hairColorMain,
  'Hair Mehendi': AppAssets.hairMehendiMain,
  'Hair Cut': AppAssets.hairCutMain,
};

final _serviceDetails = <_Service>[
  _Service(
    'Gold Facial',
    'Facial',
    1200,
    60,
    _serviceImage('gold_facial'),
    originalPrice: 1500,
    discount: '20% OFF',
    description:
        'Deep cleansing facial with gold extracts for glowing, youthful skin. Includes cleansing, exfoliation, massage, mask and moisturization.',
    benefits: const [
      'Instant glow & brightness',
      'Improves skin texture',
      'Deep cleansing & hydration',
      'Suitable for all skin types',
    ],
  ),
  _Service(
    'Gold Prime Facial',
    'Facial',
    1800,
    75,
    _serviceImage('gold_prime_facial'),
    originalPrice: 2400,
    discount: '25% OFF',
    description:
        'An advanced facial with pure gold extracts and premium botanicals for a refreshed, radiant complexion.',
    benefits: const [
      'Enhanced glow & anti-aging care',
      'Improves skin elasticity',
      'Deep nourishment & hydration',
      'Reduces dullness and fine lines',
    ],
  ),
  _Service(
    'Normal Facial',
    'Facial',
    699,
    45,
    _serviceImage('normal_facial'),
    originalPrice: 900,
    discount: '22% OFF',
    description:
        'A refreshing facial for clean, healthy and radiant skin with cleansing, exfoliation, massage, mask and moisturization.',
    benefits: const [
      'Cleanses and removes impurities',
      'Refreshes and revitalizes skin',
      'Improves skin tone and texture',
      'Suitable for all skin types',
    ],
  ),
  _Service(
    'Full Body Polish',
    'Body Polish',
    2499,
    120,
    AppAssets.bodyPolishFullBody,
    description:
        'A full-body exfoliation and nourishment treatment for smoother, softer-looking skin.',
  ),
  _Service(
    'Back Polish',
    'Body Polish',
    999,
    45,
    AppAssets.bodyPolishBack,
    description:
        'A refreshing polish treatment to exfoliate and moisturize the back.',
  ),
  _Service(
    'Arms Polish',
    'Body Polish',
    799,
    40,
    AppAssets.bodyPolishArms,
    description:
        'Gentle exfoliation and hydration to leave arms feeling soft and smooth.',
  ),
  _Service(
    'Legs Polish',
    'Body Polish',
    1199,
    60,
    AppAssets.bodyPolishLegs,
    description:
        'A nourishing polish treatment for smoother, refreshed-looking legs.',
  ),
  _Service(
    'Fruit Clean Up',
    'Clean Up',
    499,
    30,
    AppAssets.cleanUpFruit,
    description:
        'A quick fruit-based cleanse and exfoliation to refresh dull-looking skin.',
  ),
  _Service(
    'Herbal Clean Up',
    'Clean Up',
    599,
    35,
    AppAssets.cleanUpHerbal,
    description:
        'A gentle herbal cleanse with exfoliation and hydration for a fresh feel.',
  ),
  _Service(
    'De-Tan Clean Up',
    'Clean Up',
    699,
    40,
    AppAssets.cleanUpDetan,
    description:
        'A cleansing treatment focused on removing surface tan and restoring freshness.',
  ),
  _Service(
    'Anti-Acne Clean Up',
    'Clean Up',
    799,
    45,
    AppAssets.cleanUpAntiAcne,
    description:
        'A gentle, clarifying clean up for skin that needs extra attention.',
  ),
  _Service(
    'Global Hair Color',
    'Hair Color',
    1999,
    120,
    AppAssets.hairColorGlobal,
    description:
        'All-over professional hair color, selected to complement your style.',
  ),
  _Service(
    'Root Touch-Up',
    'Hair Color',
    899,
    60,
    AppAssets.hairColorRootTouchUp,
    description:
        'A focused color application to refresh visible roots and even out your look.',
  ),
  _Service(
    'Hair Highlights',
    'Hair Color',
    2499,
    150,
    AppAssets.hairColorHighlights,
    description:
        'Dimension-adding highlights applied by a beauty professional at home.',
  ),
  _Service(
    'Balayage',
    'Hair Color',
    3999,
    180,
    AppAssets.hairColorBalayage,
    description:
        'A blended, hand-painted color look customized to your hair and style.',
  ),
  _Service(
    'Global Color with Highlights',
    'Hair Color',
    4499,
    180,
    AppAssets.hairColorHighlights,
    description:
        'A complete color refresh combining all-over color with dimensional highlights.',
  ),
  _Service(
    'Full Hair Mehendi',
    'Hair Mehendi',
    799,
    90,
    AppAssets.hairMehendiFull,
    description:
        'Traditional mehendi applied throughout the hair for natural-looking color.',
  ),
  _Service(
    'Root Touch-Up with Mehendi',
    'Hair Mehendi',
    499,
    60,
    AppAssets.hairMehendiRootTouchUp,
    description:
        'A targeted mehendi application to refresh color at the roots.',
  ),
  _Service(
    'Hair Mehendi Application',
    'Hair Mehendi',
    699,
    75,
    AppAssets.hairMehendiApplication,
    description:
        'Professional application of your preferred mehendi for even coverage.',
  ),
  _Service(
    'Women’s Haircut',
    'Hair Cut',
    499,
    45,
    AppAssets.hairCutStep,
    description:
        'A personalized haircut shaped around your preferred style and hair length.',
  ),
  _Service(
    'Hair Trim',
    'Hair Cut',
    299,
    30,
    AppAssets.hairCutTrim,
    description:
        'A neat trim to refresh your ends and maintain your current cut.',
  ),
  _Service(
    'Layer Cut',
    'Hair Cut',
    799,
    60,
    AppAssets.hairCutLayer,
    description:
        'A layered haircut designed to add shape and movement to your hair.',
  ),
  _Service(
    'Fringe Trim',
    'Hair Cut',
    199,
    20,
    AppAssets.hairCutBob,
    description: 'A quick fringe refresh tailored to your preferred length.',
  ),
  _Service(
    'Kids Haircut',
    'Hair Cut',
    299,
    30,
    AppAssets.hairCutTrim,
    description: 'A comfortable haircut appointment for children at home.',
  ),
  _Service(
    'Hair Spa',
    'Hair Spa',
    899,
    60,
    _serviceImage('hair_care_spa'),
    originalPrice: 1200,
    discount: '25% OFF',
    description:
        'A nourishing hair spa treatment designed to condition your hair and leave it feeling soft and refreshed.',
    benefits: const [
      'Nourishes dry hair',
      'Conditions and softens strands',
      'Relaxing scalp massage',
      'At-home professional care',
    ],
  ),
  _Service(
    'Bridal Makeup',
    'Makeup',
    2500,
    120,
    _serviceImage('bridal_makeup'),
    originalPrice: 3500,
    discount: '29% OFF',
    description:
        'A camera-ready bridal makeup look, created with professional products and tailored to your special day.',
    benefits: const [
      'Look tailored to your occasion',
      'Professional makeup products',
      'Long-lasting finish',
      'Consultation with your artist',
    ],
  ),
  _Service(
    'Party Makeup',
    'Makeup',
    1800,
    90,
    _serviceImage('party_makeup'),
    originalPrice: 2400,
    discount: '25% OFF',
    description:
        'A polished makeup look for parties and celebrations, finished by a beauty professional at home.',
    benefits: const [
      'Makeup suited to your occasion',
      'Professional products',
      'Personalized look',
      'Convenient at-home service',
    ],
  ),
  _Service(
    'Engagement Makeup',
    'Makeup',
    2200,
    105,
    _serviceImage('engagement_makeup'),
    originalPrice: 3000,
    discount: '27% OFF',
    description:
        'A beautifully finished engagement look planned around your style and celebration.',
    benefits: const [
      'Look customized for your event',
      'Professional products',
      'Long-wearing finish',
      'At-home beauty service',
    ],
  ),
  _Service(
    'Waxing',
    'Waxing',
    699,
    45,
    _serviceImage('waxing'),
    originalPrice: 900,
    discount: '22% OFF',
    description:
        'Professional waxing with a careful, hygienic approach for smooth, comfortable skin.',
    benefits: const [
      'Professional hygienic care',
      'Smooth-looking skin',
      'Comfort-focused technique',
      'Convenient at-home service',
    ],
  ),
  _Service(
    'Half Leg Waxing',
    'Waxing',
    499,
    30,
    _serviceImage('half_leg_waxing'),
    originalPrice: 650,
    discount: '23% OFF',
  ),
  _Service(
    'Full Leg Waxing',
    'Waxing',
    899,
    45,
    _serviceImage('full_leg_waxing'),
    originalPrice: 1200,
    discount: '25% OFF',
  ),
  _Service(
    'Full Body Waxing',
    'Waxing',
    1800,
    90,
    _serviceImage('full_body_waxing'),
    originalPrice: 2400,
    discount: '25% OFF',
  ),
  _Service(
    'Manicure',
    'Manicure',
    500,
    45,
    _serviceImage('manicure'),
    originalPrice: 700,
    discount: '29% OFF',
  ),
  _Service(
    'Pedicure',
    'Manicure',
    550,
    45,
    _serviceImage('pedicure'),
    originalPrice: 750,
    discount: '27% OFF',
  ),
  _Service(
    'Manicure & Pedicure',
    'Manicure',
    950,
    75,
    _serviceImage('manicure_pedicure'),
    originalPrice: 1300,
    discount: '27% OFF',
  ),
  _Service(
    'Gel Polish',
    'Manicure',
    650,
    45,
    _serviceImage('gel_polish'),
    originalPrice: 850,
    discount: '24% OFF',
  ),
  _Service(
    'Threading',
    'Threading',
    199,
    20,
    _serviceImage('threading'),
    originalPrice: 250,
    discount: '20% OFF',
  ),
  _Service(
    'Eyebrow Threading',
    'Threading',
    99,
    15,
    _serviceImage('eyebrow_threading'),
    originalPrice: 150,
    discount: '34% OFF',
  ),
  _Service(
    'Upper Lip Threading',
    'Threading',
    79,
    10,
    _serviceImage('upper_lip_threading'),
    originalPrice: 120,
    discount: '34% OFF',
  ),
  _Service(
    'Full Face Threading',
    'Threading',
    299,
    30,
    _serviceImage('full_face_threading'),
    originalPrice: 400,
    discount: '25% OFF',
  ),
  _Service(
    'Bridal Services',
    'Bridal Services',
    4500,
    150,
    _serviceImage('bridal_services'),
    originalPrice: 6000,
    discount: '25% OFF',
  ),
  _Service(
    'Bridal Package',
    'Bridal Services',
    6500,
    180,
    _serviceImage('bridal_package'),
    originalPrice: 8500,
    discount: '24% OFF',
  ),
  _Service(
    'Engagement Package',
    'Bridal Services',
    5500,
    150,
    _serviceImage('engagement_package'),
    originalPrice: 7200,
    discount: '24% OFF',
  ),
  _Service(
    'Pre-Bridal Care',
    'Bridal Services',
    3500,
    120,
    _serviceImage('pre_bridal_care'),
    originalPrice: 4500,
    discount: '22% OFF',
  ),
  _Service(
    'Beauty Packages',
    'Beauty Packages',
    2500,
    120,
    _serviceImage('beauty_packages'),
    originalPrice: 3500,
    discount: '29% OFF',
  ),
  _Service(
    'Glow Package',
    'Beauty Packages',
    1800,
    90,
    _serviceImage('glow_package'),
    originalPrice: 2400,
    discount: '25% OFF',
  ),
  _Service(
    'Relaxation Package',
    'Beauty Packages',
    2200,
    120,
    _serviceImage('relaxation_package'),
    originalPrice: 3000,
    discount: '27% OFF',
  ),
  _Service(
    'Complete Beauty Package',
    'Beauty Packages',
    3200,
    150,
    _serviceImage('complete_beauty_package'),
    originalPrice: 4200,
    discount: '24% OFF',
  ),
];

const _developmentBanners = [
  PromotionalBanner(
    id: 'home-facial',
    title: 'Glow Beautiful\nat Home',
    subtitle: 'Professional beauty services\nby verified experts.',
    imageAsset: AppAssets.homeHero,
    callToAction: 'Book Now',
    action: PromotionalBannerAction.service,
    targetId: 'Gold Facial',
  ),
  PromotionalBanner(
    id: 'facial-care',
    title: 'A little time for you',
    subtitle: 'Explore care that fits your day.',
    imageAsset: AppAssets.goldFacial,
    callToAction: 'Browse Facial',
    action: PromotionalBannerAction.category,
    targetId: 'Facial',
  ),
  PromotionalBanner(
    id: 'makeup-services',
    title: 'Care for every occasion',
    subtitle: 'Discover thoughtful beauty services.',
    imageAsset: AppAssets.bridalMakeup,
    callToAction: 'Explore makeup',
    action: PromotionalBannerAction.service,
    targetId: 'Bridal Makeup',
  ),
];

const _categories = <(String, IconData, String?)>[
  ('Facial', Icons.face_retouching_natural_outlined, AppAssets.categoryFacial),
  ('Hair Spa', Icons.face_3_outlined, AppAssets.categoryHairSpa),
  ('Makeup', Icons.brush_outlined, AppAssets.categoryMakeup),
  ('Waxing', Icons.auto_fix_high_outlined, AppAssets.categoryWaxing),
  ('Manicure', Icons.back_hand_outlined, AppAssets.categoryManicure),
  ('All Services', Icons.grid_view_rounded, null),
];

/// Local preview; booking selections are interactive and held in memory.
class DevelopmentHomeScreen extends StatefulWidget {
  const DevelopmentHomeScreen({super.key});

  @override
  State<DevelopmentHomeScreen> createState() => _DevelopmentHomeScreenState();
}

class _DevelopmentHomeScreenState extends State<DevelopmentHomeScreen> {
  final _search = TextEditingController();
  final _serviceOtpController = TextEditingController();
  final _reviewController = TextEditingController();
  String _serviceOtp = '';
  String? _serviceOtpError;
  int _serviceElapsedSeconds = 0;
  final _plan = <_Service>[];
  final _cartQuantities = <String, int>{};
  final _savedAddresses = <_SavedAddress>[
    const _SavedAddress(
      id: 'home',
      label: 'Home',
      street: 'Sane Wadi',
      city: 'Latur, Maharashtra',
      postalCode: '413512',
    ),
    const _SavedAddress(
      id: 'work',
      label: 'Work',
      street: 'MIDC',
      city: 'Latur, Maharashtra',
      postalCode: '413531',
    ),
    const _SavedAddress(
      id: 'parents',
      label: 'Parents House',
      street: 'Ring Road',
      city: 'Latur, Maharashtra',
      postalCode: '413512',
    ),
  ];
  int _tab = 0;
  int _checkoutStep = 0;
  String _category = 'All Services';
  String _location = 'Latur, Maharashtra';
  DateTime _bookingDate = DateTime.now().add(const Duration(days: 1));
  DateTime _calendarWeekStart = _mondayOf(
    DateTime.now().add(const Duration(days: 1)),
  );
  String _bookingTime = '10:00 AM';
  String _selectedPeriod = 'Morning';
  String _bookingPreference = 'Book Instantly';
  String _selectedAddressId = 'home';
  CheckoutPaymentMethod _paymentMethod = CheckoutPaymentMethod.upi;
  CheckoutPreview? _checkoutPreview;
  Timer? _confirmationTimer;
  Timer? _serviceClockTimer;
  bool _submittingPreview = false;
  bool _serviceStarted = false;
  bool _serviceCompleted = false;
  bool _bookingDetailsExpanded = false;
  bool _reviewSubmitted = false;
  int _reviewRating = 0;
  String _customerName = 'Sneha Patil';
  bool _notificationsEnabled = true;
  bool _profilePromotionsEnabled = true;
  bool _underThousand = false;
  bool _offerApplied = false;
  bool _favoriteProfessional = false;
  String _bookingHistoryFilter = 'All';
  String _offersTab = 'Offers';
  String _offersCategory = 'All';
  String _offerSearchQuery = '';
  bool _offerSearchVisible = false;
  bool _showServiceCategories = false;
  String? _selectedServiceCategory;

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    _serviceClockTimer?.cancel();
    _search.dispose();
    _serviceOtpController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  List<_Service> get _visibleServices => _services.where((service) {
    final query = _search.text.trim().toLowerCase();
    return (_category == 'All Services' || service.category == _category) &&
        (!_underThousand || service.price < 1000) &&
        (query.isEmpty ||
            service.name.toLowerCase().contains(query) ||
            service.category.toLowerCase().contains(query));
  }).toList();

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showContactPreviewNotice(String action) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$action Unavailable'),
      content: Text('$action is unavailable in this development preview.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _setOffer(bool enabled) {
    setState(() => _offerApplied = enabled);
    _message(
      enabled
          ? 'BEAUTY20 applied to your cart.'
          : 'BEAUTY20 removed from your cart.',
    );
  }

  void _add(_Service service) {
    if (_checkoutPreview != null) _startNewBooking(showCategories: false);
    if (_plan.any((item) => item.id == service.id)) {
      _message('${service.name} is already in your cart.');
      return;
    }
    final cartService = _serviceDetails.firstWhere(
      (item) => item.id == service.id,
      orElse: () => service,
    );
    setState(() {
      _plan.add(cartService);
      _cartQuantities[cartService.id] = 1;
    });
    _message('${service.name} added to your cart.');
  }

  void _changeQuantity(_Service service, int change) {
    final current = _cartQuantities[service.id] ?? 1;
    final updated = current + change;
    if (updated < 1) return;
    setState(() => _cartQuantities[service.id] = updated);
  }

  void _removeFromCart(_Service service) {
    setState(() {
      _plan.remove(service);
      _cartQuantities.remove(service.id);
    });
  }

  int get _cartSubtotal => _plan.fold<int>(
    0,
    (sum, item) => sum + item.price * (_cartQuantities[item.id] ?? 1),
  );

  int get _cartDiscount => _offerApplied ? (_cartSubtotal * 0.2).round() : 0;

  int get _cartTotal => _cartSubtotal - _cartDiscount + 50;

  void _openAddServices() {
    setState(() {
      _checkoutStep = 0;
      _showServiceCategories = true;
      _selectedServiceCategory = null;
    });
  }

  void _startNewBooking({bool showCategories = true, bool openHome = false}) {
    _confirmationTimer?.cancel();
    _stopServiceTimer();
    _serviceOtpController.clear();
    _reviewController.clear();
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    setState(() {
      _plan.clear();
      _cartQuantities.clear();
      _checkoutPreview = null;
      _checkoutStep = 0;
      _tab = openHome ? 0 : 1;
      _showServiceCategories = showCategories;
      _selectedServiceCategory = null;
      _serviceOtp = '';
      _serviceOtpError = null;
      _serviceElapsedSeconds = 0;
      _serviceStarted = false;
      _serviceCompleted = false;
      _submittingPreview = false;
      _reviewRating = 0;
      _reviewSubmitted = false;
      _bookingDetailsExpanded = false;
      _bookingHistoryFilter = 'All';
      _offerApplied = false;
      _bookingDate = tomorrow;
      _calendarWeekStart = _mondayOf(tomorrow);
      _bookingTime = '10:00 AM';
      _selectedPeriod = 'Morning';
      _bookingPreference = 'Book Instantly';
      _paymentMethod = CheckoutPaymentMethod.upi;
    });
  }

  bool get _hasValidCheckoutSelection =>
      _plan.isNotEmpty &&
      !_bookingDate.isBefore(DateUtils.dateOnly(DateTime.now())) &&
      _bookingTime.isNotEmpty &&
      _savedAddresses.any((address) => address.id == _selectedAddressId);

  void _openPaymentMethod() {
    if (!_hasValidCheckoutSelection) {
      _message(
        'Review your service, date, time and address before continuing.',
      );
      return;
    }
    setState(() => _checkoutStep = 4);
  }

  void _confirmPreviewBooking() {
    if (_submittingPreview || _checkoutPreview != null) return;
    if (!_hasValidCheckoutSelection) {
      _message('Your booking details changed. Please review them again.');
      return;
    }
    _submittingPreview = true;
    _serviceOtpController.clear();
    _serviceOtpError = null;
    _serviceStarted = false;
    _serviceCompleted = false;
    _stopServiceTimer();
    _serviceOtp = (DateTime.now().microsecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    _reviewController.clear();
    _reviewRating = 0;
    _reviewSubmitted = false;
    final address = _selectedAddress;
    final preview = CheckoutPreview(
      services: List.unmodifiable([
        for (final service in _plan)
          PreviewService(
            name: service.name,
            quantity: _cartQuantities[service.id] ?? 1,
            unitPrice: service.price,
          ),
      ]),
      date: _bookingDate,
      time: _bookingTime,
      bookingPreference: _bookingPreference,
      addressLabel: address.label,
      addressDetails: address.details,
      subtotal: _cartSubtotal,
      discount: _cartDiscount,
      convenienceFee: 50,
      total: _cartTotal,
      paymentMethod: _paymentMethod,
    );
    setState(() {
      _checkoutPreview = preview;
      _checkoutStep = 5;
      _submittingPreview = false;
    });
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _checkoutStep != 5) return;
      setState(() => _checkoutStep = 6);
      _scheduleProfessionalAssignment();
    });
  }

  void _scheduleProfessionalAssignment() {
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _checkoutStep != 6) return;
      setState(() => _checkoutStep = 7);
    });
  }

  void _startServiceTimer() {
    _serviceClockTimer?.cancel();
    _serviceElapsedSeconds = 0;
    _serviceStarted = true;
    setState(() => _checkoutStep = 10);
    _serviceClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_serviceStarted) return;
      setState(() => _serviceElapsedSeconds++);
    });
  }

  void _stopServiceTimer() {
    _serviceClockTimer?.cancel();
    _serviceClockTimer = null;
    _serviceStarted = false;
  }

  void _completeService() {
    _stopServiceTimer();
    _serviceCompleted = true;
    setState(() => _checkoutStep = 11);
  }

  void _returnToProfessionalSearch() {
    setState(() => _checkoutStep = 6);
    _scheduleProfessionalAssignment();
  }

  String get _serviceElapsedTime {
    final elapsed = Duration(seconds: _serviceElapsedSeconds);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  _SavedAddress get _selectedAddress =>
      _savedAddresses.firstWhere((address) => address.id == _selectedAddressId);

  void _selectBookingDate(DateTime date) {
    setState(() {
      _bookingDate = DateUtils.dateOnly(date);
      _calendarWeekStart = _mondayOf(date);
    });
  }

  Future<void> _pickBookingDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _bookingDate.isBefore(today) ? today : _bookingDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Select appointment date',
    );
    if (selected != null && mounted) _selectBookingDate(selected);
  }

  void _changeBookingWeek(int amount) {
    final nextWeek = _calendarWeekStart.add(Duration(days: amount * 7));
    final today = DateUtils.dateOnly(DateTime.now());
    if (nextWeek.add(const Duration(days: 6)).isBefore(today)) return;
    setState(() => _calendarWeekStart = nextWeek);
  }

  Future<void> _addAddress() async {
    final address = await showDialog<_SavedAddress>(
      context: context,
      builder: (_) => _AddAddressDialog(initialCity: _location),
    );
    if (address != null && mounted) {
      setState(() {
        _savedAddresses.add(address);
        _selectedAddressId = address.id;
      });
    }
  }

  void _addToCart(_Service service) {
    _add(service);
    setState(() {
      _showServiceCategories = false;
      _selectedServiceCategory = null;
      _tab = 1;
    });
  }

  void _details(_Service service) {
    final categoryServices = _serviceDetails
        .where((item) => item.category == service.category)
        .toList();
    final services = categoryServices.isEmpty ? [service] : categoryServices;
    final initialIndex = services.indexWhere((item) => item.id == service.id);
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB30F0D16),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: _ServiceDetailsScreen(
          services: services,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          onAdd: (selected) {
            Navigator.of(context).pop();
            _addToCart(selected);
          },
        ),
      ),
    );
  }

  void _chooseLocation() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Choose your location',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final place in [
            'Latur, Maharashtra',
            'Pune, Maharashtra',
            'Mumbai, Maharashtra',
          ])
            ListTile(
              title: Text(place),
              trailing: _location == place
                  ? const Icon(Icons.check, color: _berry)
                  : null,
              onTap: () {
                setState(() => _location = place);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  );

  void _filters() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, updateSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter services',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                children: _categories
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.$1),
                        selected: _category == entry.$1,
                        onSelected: (_) {
                          setState(() => _category = entry.$1);
                          updateSheet(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Under ₹1,000'),
                value: _underThousand,
                onChanged: (value) {
                  setState(() => _underThousand = value);
                  updateSheet(() {});
                },
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Show services'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _professional() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 46,
              backgroundImage: AssetImage(AppAssets.professional),
            ),
            const SizedBox(height: 12),
            const Text(
              'Top rated professional',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Text(
              '★ 4.8 · Beauty specialist',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Professional availability will be shown during a real booking.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showAll();
                },
                child: const Text('Explore services'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showAll() => setState(() {
    _category = 'All Services';
    _underThousand = false;
    _search.clear();
    _tab = 0;
  });

  void _openServiceCategories() => setState(() {
    _showServiceCategories = true;
    _selectedServiceCategory = null;
  });

  void _selectServiceCategory(String category) => setState(() {
    _category = category;
    _underThousand = false;
    _search.clear();
    _selectedServiceCategory = category;
  });

  void _backFromServiceCategory() {
    setState(() {
      if (_selectedServiceCategory != null) {
        _selectedServiceCategory = null;
      } else {
        _showServiceCategories = false;
      }
    });
  }

  void _openBanner(PromotionalBanner banner) {
    switch (banner.action) {
      case PromotionalBannerAction.service:
        for (final service in _services) {
          if (service.name == banner.targetId) {
            _details(service);
            return;
          }
        }
        _message('This promotion is no longer available.');
        return;
      case PromotionalBannerAction.category:
        for (final category in _categories) {
          if (category.$1 == banner.targetId) {
            setState(() {
              _category = category.$1;
              _tab = 0;
            });
            return;
          }
        }
        _message('This promotion is no longer available.');
        return;
      case PromotionalBannerAction.offer:
        _message('This promotion is no longer available.');
        return;
      case PromotionalBannerAction.none:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(
      context,
    ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _berry)),
    child: Scaffold(
      backgroundColor: _tab == 1 && _checkoutStep >= 3
          ? Colors.white
          : const Color(0xFFFFF9F8),
      body: SafeArea(
        child: _showServiceCategories
            ? _selectedServiceCategory != null
                  ? _CategoryServicesScreen(
                      category: _selectedServiceCategory!,
                      services: _serviceDetails
                          .where(
                            (service) =>
                                service.category == _selectedServiceCategory,
                          )
                          .toList(),
                      heroImage: _categoryHeroImages[_selectedServiceCategory],
                      onBack: _backFromServiceCategory,
                      onServiceSelected: _details,
                      onAddToCart: _addToCart,
                    )
                  : AllServicesScreen(
                      onBack: _backFromServiceCategory,
                      onCategorySelected: _selectServiceCategory,
                      onServiceSelected: (name) {
                        for (final service in _serviceDetails) {
                          if (service.name == name) {
                            _details(service);
                            return;
                          }
                        }
                      },
                      subservicesByCategory: {
                        for (final category
                            in _serviceDetails
                                .map((service) => service.category)
                                .toSet())
                          category: [
                            for (final service in _serviceDetails)
                              if (service.category == category) service.name,
                          ],
                      },
                    )
            : IndexedStack(
                index: _tab,
                children: [_home(), _bookings(), _offers(), _profile()],
              ),
      ),
      bottomNavigationBar:
          _showServiceCategories ||
              (_tab == 1 && _checkoutStep >= 3 && _checkoutStep != 13)
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFFFE2EB),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  label: 'My Cart',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_offer_outlined),
                  label: 'Offers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
    ),
  );

  Widget _home() {
    final width = MediaQuery.sizeOf(context).width - 32;
    final categoryWidth = (width - 20) / 6;
    final cardWidth = (width - 24) / 4;
    final offerWidth = (width - 10) / 2;
    final featured = _visibleServices;
    return ListView(
      key: const ValueKey('home-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: _berry, size: 26),
            Expanded(
              child: TextButton(
                onPressed: _chooseLocation,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: _ink),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _message('You are all caught up!'),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
            InkWell(
              onTap: () => setState(() => _tab = 3),
              child: const CircleAvatar(
                radius: 19,
                backgroundImage: AssetImage(AppAssets.professional),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: _softBox(24),
          child: TextField(
            key: const ValueKey('home-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: const Icon(Icons.search, color: _ink),
              hintText: 'Search services (e.g. facial, waxing)',
              hintStyle: const TextStyle(fontSize: 12),
              suffixIcon: IconButton(
                tooltip: 'Filter services',
                onPressed: _filters,
                icon: const Icon(Icons.tune, color: _berry),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        _hero(width),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final entry in _categories)
              InkWell(
                key: ValueKey('category-${entry.$1}'),
                onTap: () => entry.$1 == 'All Services'
                    ? _openServiceCategories()
                    : setState(() => _category = entry.$1),
                child: SizedBox(
                  width: categoryWidth,
                  child: Column(
                    children: [
                      Container(
                        width: categoryWidth.clamp(34.0, 41.0),
                        height: categoryWidth.clamp(34.0, 41.0),
                        decoration: BoxDecoration(
                          color: _category == entry.$1
                              ? const Color(0xFFFFD5E0)
                              : const Color(0xFFFFE9ED),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: entry.$3 == null
                            ? Icon(entry.$2, color: _berry, size: 21)
                            : Image.asset(
                                entry.$3!,
                                width: 25,
                                height: 25,
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          entry.$1,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _heading('Popular Services', _openServiceCategories),
        const SizedBox(height: 4),
        if (featured.isEmpty)
          const Padding(
            padding: EdgeInsets.all(22),
            child: Text('No services match your search. Try another category.'),
          )
        else
          SizedBox(
            height: 103,
            child: SingleChildScrollView(
              key: const ValueKey('popular-services-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < featured.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: index == featured.length - 1 ? 0 : 8,
                      ),
                      child: _serviceCard(featured[index], cardWidth),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        _discount(),
        const SizedBox(height: 8),
        _heading('Offers for You', () => setState(() => _tab = 2)),
        const SizedBox(height: 4),
        SizedBox(
          height: 72,
          child: Row(
            children: [
              _offerCard(
                'Bridal Packages',
                'Up to 30% OFF',
                AppAssets.bridalMakeup,
                _services[2],
                offerWidth,
              ),
              const SizedBox(width: 10),
              _offerCard(
                'Hair Spa & Care',
                'Flat 25% OFF',
                AppAssets.goldFacial,
                _services[1],
                offerWidth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _heading('Top Rated Professionals', _professional),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var index = 0; index < 4; index++)
              Expanded(
                child: InkWell(
                  onTap: _professional,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          const CircleAvatar(
                            radius: 21,
                            backgroundImage: AssetImage(AppAssets.professional),
                          ),
                          Positioned(
                            right: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFF24BD56),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 10,
                            color: Color(0xFFFF7B27),
                          ),
                          Text(
                            index == 1 ? '4.9' : '4.8',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Save professional',
              onPressed: () => setState(
                () => _favoriteProfessional = !_favoriteProfessional,
              ),
              icon: Icon(
                _favoriteProfessional ? Icons.favorite : Icons.favorite_border,
                color: _berry,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hero(double width) => PromotionalBannerCarousel(
    banners: _developmentBanners,
    width: width,
    isActive: _tab == 0,
    onBannerTap: _openBanner,
  );

  Widget _heading(String title, VoidCallback action) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      TextButton.icon(
        onPressed: action,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 25),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.arrow_forward, size: 13),
        label: const Text('View All', style: TextStyle(fontSize: 11)),
      ),
    ],
  );

  Widget _serviceCard(_Service service, double width) => Container(
    width: width,
    height: 103,
    clipBehavior: Clip.antiAlias,
    decoration: _softBox(15),
    child: InkWell(
      onTap: () => _details(service),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            service.image,
            width: width,
            height: 43,
            fit: BoxFit.cover,
            alignment: service.name == 'Bridal Makeup'
                ? Alignment.centerRight
                : Alignment.center,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFFFE9ED),
              child: SizedBox(
                height: 43,
                child: Icon(Icons.spa, color: _berry),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 19,
                  child: Text(
                    service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  '₹${service.price}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 9, color: _muted),
                            Text(
                              ' ${service.minutes} mins',
                              style: const TextStyle(
                                fontSize: 7,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      key: ValueKey('add-${service.name}'),
                      onTap: () => _add(service),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: const BoxDecoration(
                          color: _berry,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _discount() => InkWell(
    key: const ValueKey('discount-banner'),
    onTap: () => _setOffer(!_offerApplied),
    child: Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE6),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: _berry,
            child: Text(
              '%',
              style: TextStyle(color: Colors.white, fontSize: 21),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flat 20% OFF',
                  style: TextStyle(
                    fontSize: 14,
                    color: _berry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _offerApplied
                      ? 'BEAUTY20 applied'
                      : 'Use BEAUTY20 on your first booking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 43,
            height: 32,
            child: FittedBox(
              child: Switch.adaptive(
                key: const ValueKey('promo-switch'),
                value: _offerApplied,
                onChanged: _setOffer,
                activeTrackColor: _berry,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _offerCard(
    String title,
    String subtitle,
    String image,
    _Service service,
    double width,
  ) => InkWell(
    onTap: () => _details(service),
    child: Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFCE3E9), Color(0x00FCE3E9)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Explore',
                      style: TextStyle(
                        color: _berry,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 10, color: _berry),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bookings() => switch (_checkoutStep) {
    0 => _cartScreen(),
    13 => _bookingHistoryScreen(),
    _ => _bookingFlowScreen(),
  };

  Widget _cartScreen() => Column(
    children: [
      _cartHeader(),
      Expanded(
        child: ListView(
          key: const ValueKey('cart-content'),
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
          children: [
            if (_plan.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: _InfoCard(
                  Icons.shopping_bag_outlined,
                  'Your cart is empty',
                  'Browse services and add treatments you would like to book.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _cartActionTile(
                  key: const ValueKey('add-more-services'),
                  icon: Icons.add_rounded,
                  title: 'Browse Services',
                  subtitle: 'Find a treatment to add to your cart',
                  onTap: _openAddServices,
                  highlighted: true,
                ),
              ),
            ] else ...[
              for (final service in _plan) _cartItem(service),
              const SizedBox(height: 9),
              _cartActionTile(
                key: const ValueKey('add-more-services'),
                icon: Icons.add_rounded,
                title: 'Add More Services',
                subtitle: 'Explore treatments and packages',
                onTap: _openAddServices,
                highlighted: true,
              ),
              const SizedBox(height: 9),
              _cartActionTile(
                key: const ValueKey('cart-offer'),
                icon: Icons.local_offer_outlined,
                title: _offerApplied ? 'BEAUTY20 applied' : 'Apply Coupon',
                subtitle: _offerApplied
                    ? '20% discount added to your order'
                    : 'Get 20% off with BEAUTY20',
                onTap: () => _setOffer(!_offerApplied),
              ),
              const SizedBox(height: 9),
              _orderSummary(compact: true),
            ],
          ],
        ),
      ),
      if (_plan.isNotEmpty) _cartFooter(),
    ],
  );

  Widget _cartHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('cart-back'),
          tooltip: 'Back to home',
          onPressed: () => setState(() => _tab = 0),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFFE8EE),
            foregroundColor: _berry,
            fixedSize: const Size(38, 38),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'My Cart (${_plan.length})',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Review your selected services',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        if (_plan.isNotEmpty)
          IconButton(
            key: const ValueKey('clear-cart'),
            tooltip: 'Clear cart',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFE8EE),
              fixedSize: const Size(38, 38),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => setState(() {
              _plan.clear();
              _cartQuantities.clear();
              _offerApplied = false;
            }),
            color: _berry,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    ),
  );

  Widget _cartItem(_Service service) {
    final quantity = _cartQuantities[service.id] ?? 1;
    final originalPrice = service.originalPrice;
    return Container(
      key: ValueKey('cart-item-${service.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF5DDE5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _ServicePhoto(service: service, width: 68, height: 68),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: _muted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${service.minutes} mins',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '₹${_formatServicePrice(service.price * quantity)}',
                      style: const TextStyle(
                        color: _berry,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (originalPrice != null)
                      Text(
                        '₹${_formatServicePrice(originalPrice * quantity)}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8FA),
              border: Border.all(color: const Color(0xFFF5E4E9)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _quantityButton(
                  tooltip: 'Decrease ${service.name} quantity',
                  icon: Icons.remove_rounded,
                  onPressed: quantity > 1
                      ? () => _changeQuantity(service, -1)
                      : null,
                ),
                SizedBox(
                  width: 18,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _quantityButton(
                  tooltip: 'Increase ${service.name} quantity',
                  icon: Icons.add_rounded,
                  onPressed: () => _changeQuantity(service, 1),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${service.name}',
            constraints: const BoxConstraints.tightFor(width: 34, height: 38),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _removeFromCart(service),
            icon: const Icon(
              Icons.close_rounded,
              color: PinkoraBrand.muted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: Icon(icon, size: 16, color: onPressed == null ? _muted : _berry),
  );

  Widget _cartActionTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
  }) => Material(
    key: key,
    color: highlighted ? const Color(0xFFFFF3F6) : Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFF5C7D5)
                : const Color(0xFFF4E5E9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE8EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _berry, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: highlighted ? _berry : _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: PinkoraBrand.rose,
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _orderSummary({bool compact = false}) => Container(
    padding: EdgeInsets.all(compact ? 13 : 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFF5E2E8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE8EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _berry,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'Order Summary',
              style: TextStyle(
                color: _ink,
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _summaryRow('Subtotal', _cartSubtotal),
        if (_offerApplied) _summaryRow('Discount · BEAUTY20', -_cartDiscount),
        _summaryRow('Convenience Fee', 50),
        const Divider(height: 14, color: Color(0xFFF4E5E9)),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '₹${_formatServicePrice(_cartTotal)}',
              style: const TextStyle(
                color: _berry,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Text(
          '${amount < 0 ? '- ' : ''}₹${_formatServicePrice(amount.abs())}',
          style: TextStyle(
            color: amount < 0 ? const Color(0xFF12A66A) : _ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _cartFooter() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFF4E5E9))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${_formatServicePrice(_cartTotal)}',
                style: const TextStyle(
                  color: _berry,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('proceed-to-booking'),
          onPressed: () => setState(() => _checkoutStep = 1),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF32378),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: const Text(
            'Proceed to Book',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _bookingFlowScreen() {
    if (_checkoutStep >= 6) return _bookingLifecycleScreen();

    const steps = [
      'Select Date & Time',
      'Select Address',
      'Booking Summary',
      'Payment Method',
      'Booking Confirmation',
    ];
    final step = _checkoutStep - 1;
    final redesignedStep = step < 2;
    final stepCount = redesignedStep ? 3 : steps.length;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, redesignedStep ? 12 : 5, 16, 12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('checkout-back'),
                tooltip: 'Back',
                onPressed: () => setState(() {
                  if (_checkoutStep == 5) _checkoutPreview = null;
                  _checkoutStep--;
                }),
                style: IconButton.styleFrom(
                  backgroundColor: redesignedStep
                      ? Colors.white
                      : const Color(0xFFFFE8EE),
                  foregroundColor: redesignedStep ? _bookingBerry : _berry,
                  fixedSize: Size(
                    redesignedStep ? 44 : 38,
                    redesignedStep ? 44 : 38,
                  ),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[step],
                      textAlign: redesignedStep
                          ? TextAlign.start
                          : TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (redesignedStep)
                      Text(
                        'Step ${step + 1} of $stepCount',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (!redesignedStep) const SizedBox(width: 48),
            ],
          ),
        ),
        if (redesignedStep)
          _bookingProgress(step, count: stepCount)
        else
          const SizedBox(height: 4),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (redesignedStep || step == 2 || step == 3) ...[
                Image.asset(
                  AppAssets.onboardingBackground,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
                ColoredBox(color: Colors.white.withValues(alpha: 0.4)),
              ],
              ListView(
                key: ValueKey('checkout-step-$step'),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                children: [
                  if (step == 0) _dateTimeStep(),
                  if (step == 1) _addressStep(),
                  if (step == 2) _bookingSummaryStep(),
                  if (step == 3) _paymentMethodStep(),
                  if (step == 4) _bookingConfirmationStep(),
                ],
              ),
            ],
          ),
        ),
        if (step < 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('checkout-continue'),
                onPressed: () => setState(() => _checkoutStep++),
                style: FilledButton.styleFrom(
                  backgroundColor: _bookingPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          )
        else if (step == 2)
          _summaryContinueAction()
        else if (step == 3)
          _confirmBookingAction()
        else if (step == 4)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Text(
              'Finding your professional next…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _professionalAssignmentScreen() {
    final assigned = _checkoutStep == 7;
    final preview = _checkoutPreview;
    if (preview == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No preview booking is available.'),
            TextButton(
              onPressed: () => setState(() => _checkoutStep = 0),
              child: const Text('Return to cart'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('professional-assignment-back'),
                tooltip: 'Back',
                onPressed: assigned
                    ? _returnToProfessionalSearch
                    : () => setState(() => _checkoutStep = 5),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _bookingBerry,
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assigned ? 'Professional Assigned' : 'Finding Professional',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey(
              assigned
                  ? 'professional-assigned-content'
                  : 'professional-search-content',
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            children: [
              if (assigned) ...[
                _assignedProfessionalCard(),
                const SizedBox(height: 14),
                _bookingTimeline(preview),
              ] else ...[
                _professionalSearchCard(),
                const SizedBox(height: 16),
                _professionalSearchTimeline(),
              ],
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Development preview · No real booking was created',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: assigned
                ? FilledButton(
                    key: const ValueKey('track-professional'),
                    onPressed: () => setState(() => _checkoutStep = 8),
                    style: FilledButton.styleFrom(
                      backgroundColor: _bookingPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Track Professional',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _bookingPink,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Finding available professionals…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _bookingBerry,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _bookingLifecycleScreen() => switch (_checkoutStep) {
    6 || 7 => _professionalAssignmentScreen(),
    8 => _professionalTrackingScreen(),
    9 => _serviceOtpScreen(),
    10 => _serviceInProgressScreen(),
    11 => _serviceCompletedScreen(),
    12 => _experienceReviewScreen(),
    _ => const Center(child: Text('No preview booking is available.')),
  };

  Widget _lifecyclePage({
    required String title,
    required String contentKey,
    required Widget body,
    required String actionKey,
    required String actionLabel,
    required VoidCallback onAction,
    required VoidCallback onBack,
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _bookingBerry,
                fixedSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          key: ValueKey(contentKey),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          children: [
            body,
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Development preview · No real booking or service activity',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            key: ValueKey(actionKey),
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: _bookingPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _professionalTrackingScreen() => _lifecyclePage(
    title: 'Professional On The Way',
    contentKey: 'professional-tracking-content',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Image.asset(
                AppAssets.professionalRouteMap,
                width: double.infinity,
                height: 210,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 132,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 8),
                    ],
                  ),
                  child: const Text(
                    'En route',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _assignedProfessionalCard(),
        const SizedBox(height: 12),
        _assignmentTimelineCard(
          title: 'Your appointment',
          children: [
            _AssignmentTimelineItem(
              title: 'Professional is on the way',
              subtitle: _checkoutPreview?.addressLabel ?? 'Your address',
              state: _AssignmentTimelineState.active,
              isLast: true,
            ),
          ],
        ),
      ],
    ),
    actionKey: _serviceCompleted
        ? 'view-completed-service'
        : _serviceStarted
        ? 'return-to-service'
        : 'verify-service-otp-open',
    actionLabel: _serviceCompleted
        ? 'View Completed Service'
        : _serviceStarted
        ? 'Return to Service'
        : 'Verify OTP to Start Service',
    onAction: () => setState(
      () => _checkoutStep = _serviceCompleted
          ? 11
          : _serviceStarted
          ? 10
          : 9,
    ),
    onBack: () => setState(() => _checkoutStep = 7),
  );

  Widget _serviceOtpScreen() => _lifecyclePage(
    title: 'Verify OTP to Start Service',
    contentKey: 'service-otp-content',
    body: Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _bookingBlush,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: _bookingPink,
            size: 58,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Confirm your professional is at your location',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share this one-time code with your assigned professional only when you are ready to begin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bookingLine),
          ),
          child: Column(
            children: [
              const Text(
                'DEMO SERVICE OTP',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _serviceOtp,
                key: const ValueKey('demo-service-otp'),
                style: const TextStyle(
                  color: _bookingBerry,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('service-start-otp'),
                controller: _serviceOtpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                onChanged: (_) {
                  if (_serviceOtpError != null) {
                    setState(() => _serviceOtpError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Enter 4-digit OTP',
                  counterText: '',
                  errorText: _serviceOtpError,
                  filled: true,
                  fillColor: const Color(0xFFFFF9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _bookingLine),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actionKey: 'verify-service-otp',
    actionLabel: 'Verify & Start Service',
    onAction: () {
      if (_serviceOtpController.text.trim() != _serviceOtp) {
        setState(
          () => _serviceOtpError = 'Enter the 4-digit code shown above.',
        );
        return;
      }
      _serviceOtpError = null;
      _startServiceTimer();
    },
    onBack: () => setState(() => _checkoutStep = 8),
  );

  Widget _serviceInProgressScreen() => _lifecyclePage(
    title: 'Service In Progress',
    contentKey: 'service-in-progress-content',
    body: Column(
      children: [
        Container(
          width: 184,
          height: 184,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBCEFD8), width: 8),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFF18A96A),
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                _serviceElapsedTime,
                key: const ValueKey('service-elapsed-time'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Elapsed service time',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _assignmentTimelineCard(
          title: 'Service status',
          children: const [
            _AssignmentTimelineItem(
              title: 'Professional Arrived',
              subtitle: 'Arrival confirmed',
              state: _AssignmentTimelineState.complete,
            ),
            _AssignmentTimelineItem(
              title: 'Service In Progress',
              subtitle: 'Timer started after OTP verification',
              state: _AssignmentTimelineState.active,
            ),
            _AssignmentTimelineItem(
              title: 'Service Completed',
              state: _AssignmentTimelineState.pending,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _bookingPreviewDetailCard(),
      ],
    ),
    actionKey: _serviceCompleted ? 'continue-to-review' : 'complete-service',
    actionLabel: _serviceCompleted
        ? 'View Completion'
        : 'Mark Service Complete',
    onAction: _serviceCompleted
        ? () => setState(() => _checkoutStep = 11)
        : _completeService,
    onBack: () => setState(() => _checkoutStep = 8),
  );

  Widget _serviceCompletedScreen() => _lifecyclePage(
    title: 'Service Completed',
    contentKey: 'service-completed-content',
    body: Column(
      children: [
        Container(
          width: 116,
          height: 116,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF36C77B), Color(0xFF11864A)],
            ),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 70),
        ),
        const SizedBox(height: 20),
        const Text(
          'Service Completed!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thank you for choosing Hi Beauty. We hope you loved your service.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 20),
        _bookingPreviewDetailCard(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('view-service-bill'),
          onPressed: _showPreviewBill,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View Bill'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _bookingPink,
            side: const BorderSide(color: _bookingLine),
          ),
        ),
      ],
    ),
    actionKey: 'rate-service',
    actionLabel: 'Rate Your Experience',
    onAction: () => setState(() => _checkoutStep = 12),
    onBack: () => setState(() => _checkoutStep = 10),
  );

  Widget _experienceReviewScreen() => _lifecyclePage(
    title: 'Rate Your Experience',
    contentKey: 'experience-review-content',
    body: Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: _bookingBlush,
          backgroundImage: const AssetImage(AppAssets.professional),
        ),
        const SizedBox(height: 10),
        const Text(
          'Priya Shinde',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var rating = 1; rating <= 5; rating++)
              IconButton(
                key: ValueKey('experience-rating-$rating'),
                tooltip: '$rating star${rating == 1 ? '' : 's'}',
                onPressed: () => setState(() => _reviewRating = rating),
                icon: Icon(
                  rating <= _reviewRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFFAA22),
                  size: 36,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Share your experience (optional)',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('experience-review-text'),
          controller: _reviewController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Tell us what you loved about your service…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _bookingLine),
            ),
          ),
        ),
      ],
    ),
    actionKey: 'submit-experience-review',
    actionLabel: 'Submit Review',
    onAction: () {
      if (_reviewRating == 0) {
        _message('Select a star rating before submitting your review.');
        return;
      }
      setState(() {
        _reviewSubmitted = true;
        _checkoutStep = 13;
      });
    },
    onBack: () => setState(() => _checkoutStep = 11),
  );

  Widget _bookingPreviewDetailCard() {
    final preview = _checkoutPreview;
    if (preview == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bookingLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking details',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final service in preview.services) ...[
            _paymentDetailRow(
              '${service.name} × ${service.quantity}',
              '₹${_formatServicePrice(service.lineTotal)}',
            ),
            const SizedBox(height: 6),
          ],
          const Divider(color: _bookingLine),
          _paymentDetailRow(
            'Total',
            '₹${_formatServicePrice(preview.total)}',
            emphasize: true,
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatWeekday(preview.date)}, ${_formatShortDate(preview.date)} · ${preview.time}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          Text(
            '${preview.addressLabel} · ${preview.addressDetails}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showPreviewBill() {
    final preview = _checkoutPreview;
    if (preview == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Bill · Preview'),
        content: Text(
          'Total: ₹${_formatServicePrice(preview.total)}\n'
          'Payment: ${preview.paymentMethod == CheckoutPaymentMethod.cashOnService ? 'Pending · Cash on Service' : 'Not charged · Development preview'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _bookingHistoryScreen() {
    final preview = _checkoutPreview;
    if (preview == null) {
      return Center(
        child: OutlinedButton(
          onPressed: _startNewBooking,
          child: const Text('Start a new booking'),
        ),
      );
    }
    final isCompleted = _serviceCompleted;
    final upcomingCount = isCompleted ? 0 : 1;
    final completedCount = isCompleted ? 1 : 0;
    final filterShowsBooking =
        _bookingHistoryFilter == 'All' ||
        (_bookingHistoryFilter == 'Upcoming' && !isCompleted) ||
        (_bookingHistoryFilter == 'Completed' && isCompleted);
    final filters = <(String, int)>[
      ('All', 1),
      ('Upcoming', upcomingCount),
      ('Completed', completedCount),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.onboardingBackground,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        ColoredBox(color: Colors.white.withValues(alpha: .38)),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Bookings',
                          style: TextStyle(
                            color: Color(0xFF260711),
                            fontFamily: 'serif',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.7,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View and manage your beauty service bookings',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: .82),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Back to home',
                      onPressed: () => setState(() => _tab = 0),
                      color: _bookingPink,
                      icon: const Icon(Icons.home_outlined, size: 25),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 9, 8),
              child: Row(
                children: [
                  for (final (filter, count) in filters)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _bookingHistoryFilterButton(filter, count),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('booking-history-list'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                children: [
                  if (filterShowsBooking)
                    _bookingHistoryCard(preview)
                  else
                    _InfoCard(
                      _bookingHistoryFilter == 'Upcoming'
                          ? Icons.event_available_outlined
                          : Icons.check_circle_outline,
                      'No ${_bookingHistoryFilter.toLowerCase()} bookings',
                      _bookingHistoryFilter == 'Upcoming'
                          ? 'Your completed booking is available in Completed.'
                          : 'Your future beauty service bookings will appear here.',
                    ),
                  if (filterShowsBooking && _bookingDetailsExpanded) ...[
                    const SizedBox(height: 12),
                    _bookingHistoryDetailsCard(preview),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton.icon(
                  key: const ValueKey('booking-again'),
                  onPressed: _startNewBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _bookingPink,
                    side: const BorderSide(color: _bookingPink, width: 1.8),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.autorenew_rounded, size: 24),
                  label: const Text('Book Again'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bookingHistoryFilterButton(String filter, int count) {
    final selected = _bookingHistoryFilter == filter;
    return SizedBox(
      height: 48,
      child: Material(
        color: selected ? _bookingPink : Colors.white.withValues(alpha: .82),
        shape: const StadiumBorder(),
        child: InkWell(
          key: ValueKey('booking-history-filter-$filter'),
          onTap: () => setState(() => _bookingHistoryFilter = filter),
          customBorder: const StadiumBorder(),
          child: Center(
            child: Text(
              '$filter ($count)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingHistoryCard(CheckoutPreview preview) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF9DDE6)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1AEE7A9D),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                preview.services.isEmpty ||
                        _imageForService(preview.services.first.name).isEmpty
                    ? AppAssets.professional
                    : _imageForService(preview.services.first.name),
                width: 82,
                height: 82,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  AppAssets.professional,
                  width: 82,
                  height: 82,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.services.map((service) => service.name).join(' + '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: _bookingPink,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_formatShortDate(preview.date)} · ${preview.time}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatServicePrice(preview.total)}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F8ED),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _serviceCompleted
                        ? Icons.check_circle
                        : Icons.schedule_rounded,
                    color: const Color(0xFF16894D),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _serviceCompleted ? 'Completed' : 'Upcoming',
                    style: const TextStyle(
                      color: Color(0xFF16894D),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _bookingLine),
        InkWell(
          key: const ValueKey('booking-view-details'),
          onTap: () => setState(
            () => _bookingDetailsExpanded = !_bookingDetailsExpanded,
          ),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: _bookingPink,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _bookingDetailsExpanded ? 'Hide Details' : 'View Details',
                  style: const TextStyle(
                    color: _bookingPink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _bookingDetailsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: _bookingPink,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _bookingHistoryDetailsCard(CheckoutPreview preview) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _bookingLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Booking details',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _paymentDetailRow('Professional', 'Priya Shinde · Verified'),
        const SizedBox(height: 7),
        _paymentDetailRow(
          'Review',
          _reviewSubmitted
              ? '$_reviewRating stars · Submitted'
              : 'Not submitted',
        ),
        const SizedBox(height: 7),
        _paymentDetailRow(
          'Payment status',
          preview.paymentMethod == CheckoutPaymentMethod.cashOnService
              ? 'Pending · Cash on Service'
              : 'Not charged · Preview',
        ),
        const SizedBox(height: 7),
        _paymentDetailRow(
          'Total',
          '₹${_formatServicePrice(preview.total)}',
          emphasize: true,
        ),
        const SizedBox(height: 10),
        Text(
          '${preview.addressLabel} · ${preview.addressDetails}',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );

  String _imageForService(String name) {
    for (final service in _serviceDetails) {
      if (service.name == name) return service.image;
    }
    return AppAssets.professional;
  }

  Widget _professionalSearchCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _bookingLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D8D214D),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        SizedBox(
          height: 156,
          child: Image.asset(
            AppAssets.professionalSearching,
            width: 210,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Finding the Best Professional for You',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We are matching you with an available, verified beauty expert in your area. This may take a few moments.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
      ],
    ),
  );

  Widget _professionalSearchTimeline() => _assignmentTimelineCard(
    title: 'Matching your booking',
    children: const [
      _AssignmentTimelineItem(
        title: 'Searching nearby professionals',
        state: _AssignmentTimelineState.active,
      ),
      _AssignmentTimelineItem(
        title: 'Checking availability',
        state: _AssignmentTimelineState.active,
      ),
      _AssignmentTimelineItem(
        title: 'Confirming assignment',
        state: _AssignmentTimelineState.pending,
      ),
      _AssignmentTimelineItem(
        title: 'Almost there…',
        state: _AssignmentTimelineState.pending,
        isLast: true,
      ),
    ],
  );

  Widget _assignedProfessionalCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _bookingLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D8D214D),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: _bookingBlush,
              backgroundImage: const AssetImage(AppAssets.professional),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priya Shinde',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB52E),
                        size: 16,
                      ),
                      SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '4.8 (120 reviews)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  _AssignmentBadge(
                    icon: Icons.verified_rounded,
                    label: 'Verified Professional',
                  ),
                  SizedBox(height: 4),
                  _AssignmentBadge(
                    icon: Icons.workspace_premium_outlined,
                    label: '5+ Years Experience',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _professionalContactButton(
                key: const ValueKey('professional-call'),
                icon: Icons.call_rounded,
                label: 'Call',
                onPressed: () => _showContactPreviewNotice('Calling'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _professionalContactButton(
                key: const ValueKey('professional-chat'),
                icon: Icons.chat_bubble_rounded,
                label: 'Message',
                onPressed: () => _showContactPreviewNotice('Messaging'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _professionalContactButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    key: key,
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: _bookingPink,
      backgroundColor: _bookingBlush,
      side: BorderSide.none,
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  Widget _bookingTimeline(CheckoutPreview preview) => _assignmentTimelineCard(
    title: 'Booking Timeline',
    children: [
      _AssignmentTimelineItem(
        title: 'Booking Confirmed',
        subtitle:
            '${_formatWeekday(preview.date)}, ${_formatShortDate(preview.date)}',
        state: _AssignmentTimelineState.complete,
      ),
      const _AssignmentTimelineItem(
        title: 'Professional Assigned',
        subtitle: 'Matched for your booking',
        state: _AssignmentTimelineState.complete,
      ),
      const _AssignmentTimelineItem(
        title: 'On the Way',
        subtitle: 'Before your appointment',
        state: _AssignmentTimelineState.pending,
      ),
      _AssignmentTimelineItem(
        title: 'Service Start',
        subtitle: preview.time,
        state: _AssignmentTimelineState.pending,
        isLast: true,
      ),
    ],
  );

  Widget _assignmentTimelineCard({
    required String title,
    required List<_AssignmentTimelineItem> children,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _bookingLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in children) item,
      ],
    ),
  );

  Widget _bookingProgress(int step, {required int count}) => Padding(
    padding: const EdgeInsets.fromLTRB(42, 8, 42, 4),
    child: Row(
      children: [
        for (var index = 0; index < count; index++) ...[
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == step ? _bookingPink : const Color(0xFFFFF8FA),
              shape: BoxShape.circle,
              border: Border.all(
                color: index == step ? _bookingPink : _bookingLine,
                width: 1.5,
              ),
              boxShadow: index == step
                  ? const [
                      BoxShadow(
                        color: Color(0x33F31B78),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: index == step ? Colors.white : _muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (index < count - 1)
            Expanded(
              child: Container(
                height: 2,
                color: index < step ? _bookingPink : _bookingLine,
              ),
            ),
        ],
      ],
    ),
  );

  Widget _dateTimeStep() {
    final dates = List.generate(
      7,
      (index) => _calendarWeekStart.add(Duration(days: index)),
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final visibleMonth = dates[3];
    final month = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][visibleMonth.month - 1];
    const slotsByPeriod = <String, List<String>>{
      'Morning': ['9:00 AM', '10:00 AM', '11:00 AM'],
      'Afternoon': ['12:00 PM', '1:00 PM', '2:00 PM'],
      'Evening': ['4:00 PM', '5:00 PM', '6:00 PM'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('booking-calendar'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _bookingLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0AF31B78),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('booking-week-previous'),
                    tooltip: 'Previous week',
                    onPressed:
                        dates.last.isBefore(today) ||
                            DateUtils.isSameDay(dates.last, today)
                        ? null
                        : () => _changeBookingWeek(-1),
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 24,
                      color: _bookingBerry,
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('booking-month-picker'),
                      onPressed: _pickBookingDate,
                      style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      child: Text(
                        '$month ${visibleMonth.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('booking-week-next'),
                    tooltip: 'Next week',
                    onPressed: () => _changeBookingWeek(1),
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: _bookingBerry,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final date in dates)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          children: [
                            Text(
                              _formatWeekday(date),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 70,
                              width: double.infinity,
                              child: Material(
                                color: DateUtils.isSameDay(date, _bookingDate)
                                    ? _bookingPink
                                    : const Color(0xFFFFF8FA),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  key: ValueKey(
                                    'booking-date-${date.year}-${date.month}-${date.day}',
                                  ),
                                  onTap: date.isBefore(today)
                                      ? null
                                      : () => _selectBookingDate(date),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color:
                                            DateUtils.isSameDay(
                                              date,
                                              _bookingDate,
                                            )
                                            ? Colors.white
                                            : _ink,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Choose time slot',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final period in slotsByPeriod.keys)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: period == 'Evening' ? 0 : 8),
                  child: InkWell(
                    key: ValueKey('booking-period-$period'),
                    onTap: () => setState(() {
                      _selectedPeriod = period;
                      final slots = slotsByPeriod[period]!;
                      if (!slots.contains(_bookingTime)) {
                        _bookingTime = slots.first;
                      }
                    }),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _selectedPeriod == period
                            ? _bookingPink
                            : const Color(0xFFFFF4F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              period == 'Evening'
                                  ? Icons.nightlight_outlined
                                  : Icons.wb_sunny_outlined,
                              size: 15,
                              color: _selectedPeriod == period
                                  ? Colors.white
                                  : _bookingBerry,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                period,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _selectedPeriod == period
                                      ? Colors.white
                                      : _ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final slots = slotsByPeriod[_selectedPeriod]!;
            final itemWidth = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in slots)
                  SizedBox(
                    width: itemWidth,
                    height: 46,
                    child: OutlinedButton(
                      key: ValueKey('booking-time-$time'),
                      onPressed: () => setState(() => _bookingTime = time),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _bookingTime == time
                            ? Colors.white
                            : _bookingBerry,
                        backgroundColor: _bookingTime == time
                            ? _bookingPink
                            : Colors.white,
                        side: BorderSide(
                          color: _bookingTime == time
                              ? _bookingPink
                              : _bookingLine,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'Booking preference',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _bookingPreferenceCard(
          title: 'Book Instantly',
          description: 'Confirm your appointment right away and get started.',
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 10),
        _bookingPreferenceCard(
          title: 'Schedule Later',
          description: 'Choose a convenient date and time that works for you.',
          icon: Icons.calendar_month_outlined,
        ),
      ],
    );
  }

  Widget _bookingPreferenceCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _bookingPreference == title;
    return InkWell(
      key: ValueKey('booking-preference-$title'),
      onTap: () => setState(() => _bookingPreference = title),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _bookingBlush : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _bookingPink : _bookingLine,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09F31B78),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _bookingPink : _muted,
              size: 23,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFE2EC),
              child: Icon(icon, color: _bookingBerry, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressStep() => Column(
    key: const ValueKey('checkout-address-list'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose where your service will take place.',
        style: TextStyle(
          color: _muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bookingBlush,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bookingLine),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFFFDFE9),
              child: Icon(
                Icons.location_on_rounded,
                color: _bookingPink,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Service area · $_location',
                style: const TextStyle(
                  color: _bookingBerry,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('change-service-area'),
              tooltip: 'Change service area',
              onPressed: _chooseLocation,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
                color: _bookingPink,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Saved addresses',
        style: TextStyle(
          color: _ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      for (final address in _savedAddresses) ...[
        _savedAddressCard(address),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('add-new-address'),
          onPressed: _addAddress,
          style: OutlinedButton.styleFrom(
            foregroundColor: _bookingPink,
            backgroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: _bookingPink),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Add New Address',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );

  Widget _savedAddressCard(_SavedAddress address) {
    final selected = _selectedAddressId == address.id;
    final icon = switch (address.id) {
      'home' => Icons.home_outlined,
      'work' => Icons.work_outline_rounded,
      'parents' => Icons.place_outlined,
      _ => Icons.location_on_outlined,
    };
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? _bookingBlush : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('saved-address-${address.id}'),
          onTap: () => setState(() => _selectedAddressId = address.id),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _bookingPink : _bookingLine,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0AF31B78),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _bookingPink : _muted,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE2EC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _bookingPink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        address.label,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        address.details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingSummaryStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your services',
        style: TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      for (final service in _plan)
        Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _bookingLine),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: service.name == 'Gold Facial'
                    ? Image.asset(
                        AppAssets.bookingGoldFacial,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : service.name == 'Manicure'
                    ? Image.asset(
                        AppAssets.bookingManicure,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : _ServicePhoto(service: service, width: 50, height: 50),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${service.minutes} mins · ${_cartQuantities[service.id] ?? 1} item(s)',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${_formatServicePrice(service.price * (_cartQuantities[service.id] ?? 1))}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bookingLine),
        ),
        child: Column(
          children: [
            _bookingDetailLine(
              Icons.calendar_month_outlined,
              '${_formatWeekday(_bookingDate)}, ${_formatShortDate(_bookingDate)}',
              '$_bookingTime · $_bookingPreference',
              () => setState(() => _checkoutStep = 1),
            ),
            const Divider(height: 1, color: _bookingLine),
            _bookingDetailLine(
              Icons.location_on_outlined,
              _selectedAddress.label,
              _selectedAddress.details,
              () => setState(() => _checkoutStep = 2),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bookingLine),
        ),
        child: Column(
          children: [
            _bookingTotalLine('Service Total', _cartSubtotal),
            const SizedBox(height: 7),
            if (_offerApplied) ...[
              _bookingTotalLine('Discount', -_cartDiscount),
              const SizedBox(height: 7),
            ],
            _bookingTotalLine('Convenience Fee', 50),
            const Divider(height: 20, color: _bookingLine),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '₹${_formatServicePrice(_cartTotal)}',
                  style: const TextStyle(
                    color: _bookingBerry,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _bookingDetailLine(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _bookingBerry, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ],
      ),
    ),
  );

  Widget _bookingTotalLine(String label, int amount) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      Text(
        '${amount < 0 ? '- ' : ''}₹${_formatServicePrice(amount.abs())}',
        style: TextStyle(
          color: amount < 0 ? const Color(0xFF15854D) : _ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _summaryContinueAction() => _checkoutAction(
    key: const ValueKey('continue-to-payment-method'),
    label: 'Proceed to Payment',
    onPressed: _openPaymentMethod,
  );

  Widget _confirmBookingAction() => _checkoutAction(
    key: const ValueKey('confirm-booking'),
    label: _paymentMethod == CheckoutPaymentMethod.cashOnService
        ? 'Confirm Booking'
        : 'Pay Securely · Preview',
    onPressed: _submittingPreview || _checkoutPreview != null
        ? null
        : _confirmPreviewBooking,
  );

  Widget _checkoutAction({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _bookingPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );

  Widget _paymentMethodStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose how you would like to pay.',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
      const SizedBox(height: 14),
      _paymentMethodCard(
        method: CheckoutPaymentMethod.upi,
        icon: Icons.account_balance_wallet_outlined,
        title: 'UPI (Recommended)',
        description: 'Google Pay  ·  PhonePe  ·  Paytm',
      ),
      const SizedBox(height: 8),
      _paymentMethodCard(
        method: CheckoutPaymentMethod.card,
        icon: Icons.credit_card_rounded,
        title: 'Credit / Debit Card',
        description: 'Visa, Mastercard, RuPay',
      ),
      const SizedBox(height: 8),
      _paymentMethodCard(
        method: CheckoutPaymentMethod.cashOnService,
        icon: Icons.payments_outlined,
        title: 'Cash on Service',
        description: 'Pay after service completion',
      ),
      const SizedBox(height: 18),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: _bookingBlush,
          borderRadius: BorderRadius.circular(15),
        ),
        child: _paymentDetailRow(
          'Payable Amount',
          '₹${_formatServicePrice(_cartTotal)}',
          emphasize: true,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _paymentMethod == CheckoutPaymentMethod.cashOnService
            ? 'You will pay after the service is completed.'
            : 'Online payment is not connected in this development preview. No charge will be made.',
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );

  Widget _paymentMethodCard({
    required CheckoutPaymentMethod method,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _paymentMethod == method;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? _bookingBlush : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('payment-method-${method.name}'),
          onTap: () => setState(() => _paymentMethod = method),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _bookingPink : _bookingLine,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _bookingPink : _muted,
                  size: 23,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: _bookingBerry, size: 17),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (method == CheckoutPaymentMethod.upi)
                        Row(
                          children: [
                            _paymentBrandIcon(
                              asset: AppAssets.googlePay,
                              label: 'Google Pay',
                            ),
                            const SizedBox(width: 8),
                            _paymentBrandIcon(
                              asset: AppAssets.phonePe,
                              label: 'PhonePe',
                            ),
                            const SizedBox(width: 8),
                            _paymentBrandIcon(
                              asset: AppAssets.paytm,
                              label: 'Paytm',
                            ),
                          ],
                        )
                      else
                        Text(
                          description,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentBrandIcon({required String asset, required String label}) =>
      Semantics(
        image: true,
        label: label,
        child: Image.asset(asset, width: 32, height: 22, fit: BoxFit.contain),
      );

  Widget _paymentDetailRow(
    String label,
    String value, {
    bool emphasize = false,
  }) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: emphasize ? _bookingBerry : _ink,
            fontSize: emphasize ? 17 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _bookingConfirmationStep() {
    final preview = _checkoutPreview;
    if (preview == null) return const Text('No preview booking is available.');
    final method = switch (preview.paymentMethod) {
      CheckoutPaymentMethod.upi => 'UPI',
      CheckoutPaymentMethod.card => 'Credit / Debit Card',
      CheckoutPaymentMethod.cashOnService => 'Cash on Service',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 30,
                      top: 18,
                      child: Icon(Icons.diamond, color: _bookingPink, size: 9),
                    ),
                    const Positioned(
                      right: 35,
                      top: 26,
                      child: Icon(
                        Icons.diamond,
                        color: Color(0xFF23B66C),
                        size: 9,
                      ),
                    ),
                    const Positioned(
                      left: 66,
                      bottom: 17,
                      child: Icon(
                        Icons.circle,
                        color: Color(0xFFFFB136),
                        size: 7,
                      ),
                    ),
                    const Positioned(
                      right: 72,
                      bottom: 18,
                      child: Icon(
                        Icons.circle,
                        color: Color(0xFF83B9F6),
                        size: 7,
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF33C778), Color(0xFF11864A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3321B76D),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Booking Confirmed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF16894D),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Sample booking · Development preview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _bookingBerry,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                preview.paymentMethod == CheckoutPaymentMethod.cashOnService
                    ? 'Pay after service completion. We will assign a professional shortly.'
                    : 'Online payment was not processed in this preview.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              const Text(
                'No real booking was created. No payment was collected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bookingLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking details',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _paymentDetailRow('Booking ID', 'Not issued in preview'),
              const SizedBox(height: 8),
              _paymentDetailRow('Booking status', 'Sample confirmed'),
              const SizedBox(height: 8),
              _paymentDetailRow('Payment status', 'Pending'),
              const SizedBox(height: 8),
              _paymentDetailRow('Payment method', method),
              const Divider(height: 24, color: _bookingLine),
              for (final service in preview.services) ...[
                _paymentDetailRow(
                  '${service.name} × ${service.quantity}',
                  '₹${_formatServicePrice(service.lineTotal)}',
                ),
                const SizedBox(height: 7),
              ],
              const Divider(height: 20, color: _bookingLine),
              Text(
                '${_formatWeekday(preview.date)}, ${_formatShortDate(preview.date)} · ${preview.time}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preview.bookingPreference,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Text(
                preview.addressLabel,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                preview.addressDetails,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const Divider(height: 24, color: _bookingLine),
              _paymentDetailRow(
                preview.paymentMethod == CheckoutPaymentMethod.cashOnService
                    ? 'Due after service'
                    : 'Grand Total',
                '₹${_formatServicePrice(preview.total)}',
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const ValueKey('booking-back-home'),
            onPressed: () =>
                _startNewBooking(showCategories: false, openHome: true),
            style: FilledButton.styleFrom(
              backgroundColor: _bookingPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'Go to Home',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _offers() {
    final discountedServices = _serviceDetails
        .where((service) => service.discount != null)
        .where((service) => _offerMatchesCategory(service))
        .where((service) {
          final query = _offerSearchQuery.trim().toLowerCase();
          return query.isEmpty ||
              service.name.toLowerCase().contains(query) ||
              service.category.toLowerCase().contains(query) ||
              service.description.toLowerCase().contains(query);
        })
        .toList();
    const featuredOfferOrder = [
      'Gold Facial',
      'Hair Spa',
      'Bridal Makeup',
      'Manicure & Pedicure',
      'Full Body Waxing',
    ];
    discountedServices.sort((left, right) {
      final leftIndex = featuredOfferOrder.indexOf(left.name);
      final rightIndex = featuredOfferOrder.indexOf(right.name);
      final leftPriority = leftIndex < 0
          ? featuredOfferOrder.length
          : leftIndex;
      final rightPriority = rightIndex < 0
          ? featuredOfferOrder.length
          : rightIndex;
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }
      return left.name.compareTo(right.name);
    });
    final showPackages = _offersTab == 'Packages';
    final packagesByCategory = <String, List<_Service>>{};
    for (final service in _serviceDetails) {
      packagesByCategory.putIfAbsent(service.category, () => []).add(service);
    }
    final packages = packagesByCategory.entries
        .where((entry) => entry.value.length > 1)
        .toList();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.onboardingBackground,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.58)),
        ListView(
          key: const ValueKey('offers-packages-screen'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('offers-back'),
                  tooltip: 'Back to Home',
                  onPressed: () => setState(() => _tab = 0),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE8EF),
                    foregroundColor: _bookingPink,
                    fixedSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 21),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _offerSearchVisible
                      ? TextField(
                          key: const ValueKey('offers-search'),
                          autofocus: true,
                          onChanged: (value) =>
                              setState(() => _offerSearchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search offers',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: _bookingLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: _bookingLine),
                            ),
                          ),
                        )
                      : const Text(
                          'Offers & Packages',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('toggle-offers-search'),
                  tooltip: _offerSearchVisible
                      ? 'Close search'
                      : 'Search offers',
                  onPressed: () => setState(() {
                    _offerSearchVisible = !_offerSearchVisible;
                    if (!_offerSearchVisible) _offerSearchQuery = '';
                  }),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE8EF),
                    foregroundColor: _bookingPink,
                    fixedSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    _offerSearchVisible
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    size: 23,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('offers-apply-beauty20'),
                  onTap: () => _setOffer(!_offerApplied),
                  child: Semantics(
                    button: true,
                    label: _offerApplied
                        ? 'Remove BEAUTY20 coupon'
                        : 'Apply BEAUTY20 coupon',
                    child: Image.asset(
                      AppAssets.offersBanner,
                      width: double.infinity,
                      height: 126,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8EF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  for (final tab in const ['Offers', 'Packages'])
                    Expanded(
                      child: InkWell(
                        key: ValueKey('offers-tab-$tab'),
                        onTap: () => setState(() => _offersTab = tab),
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 44,
                          decoration: BoxDecoration(
                            color: _offersTab == tab
                                ? _bookingPink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: _offersTab == tab ? Colors.white : _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!showPackages) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 84,
                child: ListView(
                  key: const ValueKey('offers-category-list'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _offerCategoryChip('All', Icons.auto_awesome_rounded),
                    _offerCategoryChip('Facial', Icons.face_retouching_natural),
                    _offerCategoryChip('Hair Care', Icons.face_3_outlined),
                    _offerCategoryChip('Makeup', Icons.brush_outlined),
                    _offerCategoryChip('Waxing', Icons.auto_fix_high_outlined),
                    _offerCategoryChip('Manicure', Icons.back_hand_outlined),
                    _offerCategoryChip('Spa', Icons.spa_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final service in discountedServices)
                _offerServiceTile(service),
              if (discountedServices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    _offerSearchQuery.isEmpty
                        ? 'No offers in this category yet.'
                        : 'No offers match “$_offerSearchQuery”.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 14),
              for (final package in packages)
                _offerPackageTile(package.key, package.value),
            ],
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Preview deals · Prices and availability are examples',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _offerMatchesCategory(_Service service) {
    if (_offersCategory == 'All') return true;
    final matchingCategories = switch (_offersCategory) {
      'Hair Care' => const {
        'Hair Spa',
        'Hair Color',
        'Hair Cut',
        'Hair Mehendi',
      },
      'Spa' => const {'Body Polish', 'Clean Up'},
      _ => {_offersCategory},
    };
    return matchingCategories.contains(service.category);
  }

  Widget _offerCategoryChip(String label, IconData icon) {
    final selected = _offersCategory == label;
    return SizedBox(
      width: 72,
      child: InkWell(
        key: ValueKey('offers-category-$label'),
        onTap: () => setState(() => _offersCategory = label),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? _bookingPink : const Color(0xFFFFE8EF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : _bookingPink,
                size: 23,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _bookingPink : _muted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerServiceTile(_Service service) {
    final imageWidth = MediaQuery.sizeOf(context).width < 390 ? 96.0 : 108.0;
    return Container(
      key: ValueKey('offer-service-deal-${service.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border.all(color: const Color(0xFFFFE2EA)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AF31B78),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 126,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  _ServicePhoto(
                    service: service,
                    width: imageWidth,
                    height: 126,
                  ),
                  Positioned(
                    top: 7,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _bookingPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service.discount!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${_formatServicePrice(service.price)}',
                            style: const TextStyle(
                              color: _bookingPink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (service.originalPrice != null)
                            Text(
                              '₹${_formatServicePrice(service.originalPrice!)}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 9,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 9,
                    runSpacing: 3,
                    children: [
                      _offerFact(
                        Icons.access_time_rounded,
                        '${service.minutes} mins',
                      ),
                      _offerFact(Icons.home_outlined, 'At Home'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      key: ValueKey('offer-details-${service.id}'),
                      onPressed: () => _details(service),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _bookingPink,
                        backgroundColor: const Color(0xFFFFF0F4),
                        side: const BorderSide(color: Color(0xFFFFD7E2)),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerFact(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: _ink),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _offerPackageTile(String category, List<_Service> services) {
    final packageServices = services.take(3).toList();
    final subtotal = packageServices.fold<int>(
      0,
      (total, service) => total + service.price,
    );
    return Container(
      key: ValueKey('offer-package-${category.toLowerCase()}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _bookingLine),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _ServicePhoto(
                  service: packageServices.first,
                  width: 62,
                  height: 62,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category Beauty Package',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packageServices
                          .map((service) => service.name)
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_formatServicePrice(subtotal)} · BEAUTY20 for 20% off',
                      style: const TextStyle(
                        color: _bookingBerry,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              key: ValueKey('add-package-${category.toLowerCase()}'),
              onPressed: () => _addOfferPackage(packageServices),
              style: OutlinedButton.styleFrom(
                foregroundColor: _bookingPink,
                side: const BorderSide(color: _bookingPink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                'Add Package to Cart',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addOfferPackage(List<_Service> services) {
    if (_checkoutPreview != null) _startNewBooking(showCategories: false);
    final newServices = services
        .where((service) => !_plan.any((item) => item.id == service.id))
        .toList();
    if (newServices.isEmpty) {
      _message('All services in this package are already in your cart.');
      return;
    }
    setState(() {
      for (final service in newServices) {
        _plan.add(service);
        _cartQuantities[service.id] = 1;
      }
      _offerApplied = true;
      _tab = 1;
    });
    _message('Package added to your cart. BEAUTY20 has been applied.');
  }

  Widget _profile() => ListView(
    key: const ValueKey('profile-settings-screen'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      const Text(
        'My Profile',
        style: TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bookingLine),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage(AppAssets.onboardingPortrait),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customerName,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Customer account · Preview',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('edit-customer-profile'),
              tooltip: 'Edit profile',
              onPressed: _editCustomerProfile,
              icon: const Icon(Icons.edit_outlined, color: _bookingPink),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _profileMenuGroup([
        _ProfileMenuEntry(
          Icons.location_on_outlined,
          'My Addresses',
          _location,
          _showSavedAddresses,
        ),
        _ProfileMenuEntry(
          Icons.favorite_border_rounded,
          'Saved Professionals',
          _favoriteProfessional ? '1 saved' : 'None yet',
          _showSavedProfessionals,
        ),
        _ProfileMenuEntry(
          Icons.shopping_bag_outlined,
          'My Bookings',
          _checkoutPreview == null ? 'View your booking history' : '1 booking',
          _openBookingHistory,
        ),
        _ProfileMenuEntry(
          Icons.local_offer_outlined,
          'Offers & Wallet',
          _offerApplied ? 'BEAUTY20 applied' : 'View offers and packages',
          () => setState(() => _tab = 2),
        ),
        _ProfileMenuEntry(
          Icons.card_giftcard_outlined,
          'Refer & Earn',
          'Invite friends to Hi Beauty',
          _showReferralCode,
        ),
      ]),
      const SizedBox(height: 10),
      _profileMenuGroup([
        _ProfileMenuEntry(
          Icons.support_agent_outlined,
          'Help & Support',
          'Get help with your account',
          () => _showProfileInfo(
            'Help & Support',
            'Support contact is not connected in this development preview.',
          ),
        ),
        _ProfileMenuEntry(
          Icons.settings_outlined,
          'Settings',
          'Notifications and preferences',
          _showProfileSettings,
        ),
        _ProfileMenuEntry(
          Icons.privacy_tip_outlined,
          'Terms & Privacy',
          'Review app terms and privacy information',
          () => _showProfileInfo(
            'Terms & Privacy',
            'Terms and privacy documents are not connected in this preview.',
          ),
        ),
      ]),
      const SizedBox(height: 10),
      _profileMenuGroup([
        _ProfileMenuEntry(
          Icons.logout_rounded,
          'Logout',
          'Return to the development home',
          () => setState(() => _tab = 0),
          color: _bookingPink,
        ),
      ]),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Hi Beauty · Development preview',
          style: TextStyle(color: _muted, fontSize: 10),
        ),
      ),
    ],
  );

  Widget _profileMenuGroup(List<_ProfileMenuEntry> entries) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _bookingLine),
    ),
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _profileMenuTile(entries[index]),
          if (index < entries.length - 1)
            const Divider(height: 1, indent: 48, endIndent: 12),
        ],
      ],
    ),
  );

  Widget _profileMenuTile(_ProfileMenuEntry entry) => ListTile(
    key: ValueKey('profile-menu-${entry.title}'),
    dense: true,
    leading: Icon(entry.icon, color: entry.color ?? _bookingBerry, size: 21),
    title: Text(
      entry.title,
      style: TextStyle(
        color: entry.color ?? _ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text(
      entry.subtitle,
      style: const TextStyle(color: _muted, fontSize: 10),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, size: 19),
    onTap: entry.onTap,
  );

  Future<void> _showSavedAddresses() async {
    final selection = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            const Text(
              'My Addresses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final saved in _savedAddresses)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(saved.label),
                subtitle: Text(saved.details),
                trailing: saved.id == _selectedAddressId
                    ? const Icon(Icons.check_circle, color: _bookingPink)
                    : null,
                onTap: () => Navigator.pop(context, saved),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add new address'),
              onTap: () => Navigator.pop(context, 'add-address'),
            ),
          ],
        ),
      ),
    );
    if (selection == 'add-address' && mounted) {
      final address = await showDialog<_SavedAddress>(
        context: context,
        builder: (context) => _AddAddressDialog(initialCity: _location),
      );
      if (address == null || !mounted) return;
      setState(() {
        _savedAddresses.add(address);
        _selectedAddressId = address.id;
        _location = address.city;
      });
      _message('${address.label} added and selected.');
    } else if (selection is _SavedAddress && mounted) {
      final address = selection;
      setState(() {
        _selectedAddressId = address.id;
        _location = address.city;
      });
      _message('${address.label} selected as your address.');
    }
  }

  void _showSavedProfessionals() {
    _showProfileInfo(
      'Saved Professionals',
      _favoriteProfessional
          ? 'Priya Shinde is saved to your favourites.'
          : 'Save a professional from the home screen to find them here.',
    );
  }

  void _openBookingHistory() => setState(() {
    _tab = 1;
    _checkoutStep = _checkoutPreview == null ? 0 : 13;
  });

  void _editCustomerProfile() {
    var name = _customerName;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: TextFormField(
            key: const ValueKey('profile-name-input'),
            initialValue: name,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setDialogState(() => name = value),
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('save-profile-name'),
              onPressed: () {
                final updatedName = name.trim();
                if (updatedName.isEmpty) {
                  _message('Enter your name to save your profile.');
                  return;
                }
                setState(() => _customerName = updatedName);
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReferralCode() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Refer & Earn'),
      content: const SelectableText('Your preview referral code: HIBEAUTY20'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  void _showProfileInfo(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _showProfileSettings() => showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                setDialogState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offer updates'),
              value: _profilePromotionsEnabled,
              onChanged: (value) {
                setState(() => _profilePromotionsEnabled = value);
                setDialogState(() {});
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

class _CategoryServicesScreen extends StatelessWidget {
  const _CategoryServicesScreen({
    required this.category,
    required this.services,
    required this.heroImage,
    required this.onBack,
    required this.onServiceSelected,
    required this.onAddToCart,
  });

  final String category;
  final List<_Service> services;
  final String? heroImage;
  final VoidCallback onBack;
  final ValueChanged<_Service> onServiceSelected;
  final ValueChanged<_Service> onAddToCart;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFF8F7),
    child: Column(
      children: [
        SizedBox(
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const ValueKey('back-to-service-categories'),
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: _berry,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (services.isNotEmpty) ...[
          Container(
            height: 132,
            margin: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  heroImage ?? services.first.image,
                  key: ValueKey('category-hero-$category'),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFFFE9ED),
                    child: Center(
                      child: Icon(Icons.spa_outlined, color: _berry, size: 42),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFF8DAE4),
                        Color(0xD9F8DAE4),
                        Color(0x00F8DAE4),
                      ],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HI BEAUTY COLLECTION',
                        style: TextStyle(
                          color: _berry,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        category == 'Facial'
                            ? 'Find your\nkind of glow'
                            : 'Care made\nfor you',
                        style: const TextStyle(
                          color: Color(0xFF751536),
                          fontSize: 21,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${services.length} treatments  ·  At your home',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose your treatment',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${services.length} options',
                  style: const TextStyle(color: _berry, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: services.isEmpty
              ? const Center(
                  child: Text('No services are available in this category.'),
                )
              : ListView.separated(
                  key: const ValueKey('category-services'),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  itemCount: services.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('subservice-${service.name}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onServiceSelected(service),
                        child: Container(
                          height: 146,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF6E5E9)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D8D214D),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _ServicePhoto(
                                      service: service,
                                      width: 106,
                                      height: 128,
                                      key: ValueKey(
                                        'category-service-image-${service.id}',
                                      ),
                                    ),
                                  ),
                                  if (service.discount case final discount?)
                                    Positioned(
                                      left: 5,
                                      bottom: 5,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            discount,
                                            style: const TextStyle(
                                              color: _berry,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      service.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 9.5,
                                        height: 1.25,
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${_formatServicePrice(service.price)}',
                                          style: const TextStyle(
                                            color: _berry,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: _muted,
                                        ),
                                        Text(
                                          ' ${service.minutes}m',
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 30,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilledButton.icon(
                                          key: ValueKey(
                                            'add-to-cart-${service.name}',
                                          ),
                                          onPressed: () => onAddToCart(service),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _berry,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 30),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 13,
                                          ),
                                          label: const Text(
                                            'Add to Cart',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color: PinkoraBrand.rose,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _ServiceDetailsScreen extends StatefulWidget {
  const _ServiceDetailsScreen({
    required this.services,
    required this.initialIndex,
    required this.onAdd,
  });

  final List<_Service> services;
  final int initialIndex;
  final ValueChanged<_Service> onAdd;

  @override
  State<_ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<_ServiceDetailsScreen> {
  late final PageController _pageController;
  late int _index;

  _Service get _service => widget.services[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showPage(int page) {
    if (page < 0 || page >= widget.services.length) return;
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFF7F8),
    child: Column(
      children: [
        Expanded(
          flex: 34,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                key: const ValueKey('service-details-pages'),
                controller: _pageController,
                itemCount: widget.services.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _ServicePhoto(
                  service: widget.services[index],
                  fit: BoxFit.cover,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Colors.transparent],
                    stops: [0, 0.32],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  key: const ValueKey('close-service-details'),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xF5FFFFFF),
                    foregroundColor: _ink,
                    fixedSize: const Size(40, 40),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                ),
              ),
              Positioned(
                top: 16,
                left: 58,
                right: 58,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF5FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.spa_outlined,
                            size: 15,
                            color: PinkoraBrand.rose,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _service.category,
                            style: const TextStyle(
                              color: PinkoraBrand.berry,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_index > 0)
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ImagePageButton(
                      tooltip: 'Previous service',
                      icon: Icons.chevron_left_rounded,
                      onPressed: () => _showPage(_index - 1),
                    ),
                  ),
                ),
              if (_index < widget.services.length - 1)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ImagePageButton(
                      tooltip: 'Next service',
                      icon: Icons.chevron_right_rounded,
                      onPressed: () => _showPage(_index + 1),
                      primary: true,
                    ),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < widget.services.length; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _index == index ? 9 : 6,
                        height: _index == index ? 9 : 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: _index == index ? 1 : 0.72,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 91,
          color: const Color(0xFFFFF7F8),
          padding: const EdgeInsets.fromLTRB(16, 9, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore more treatments',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${_index + 1} of ${widget.services.length}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.services.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) => InkWell(
                    key: ValueKey(
                      'service-option-${widget.services[index].name}',
                    ),
                    onTap: () => _showPage(index),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _index == index ? _berry : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEBCAD4)),
                      ),
                      child: Text(
                        widget.services[index].name,
                        style: TextStyle(
                          color: _index == index ? Colors.white : _berry,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 66,
          child: ColoredBox(
            color: const Color(0xFFFFFDFC),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PREVIEW CATALOG · SAMPLE PRICES AND DURATIONS',
                          style: TextStyle(
                            color: _berry,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _service.name,
                          key: const ValueKey('service-details-title'),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 5,
                          children: [
                            Text(
                              '₹${_formatServicePrice(_service.price)}',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_service.originalPrice case final original?)
                              Text(
                                '₹${_formatServicePrice(original)}',
                                style: const TextStyle(
                                  color: PinkoraBrand.muted,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            if (_service.discount case final discount?)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7EF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    discount,
                                    style: const TextStyle(
                                      color: PinkoraBrand.berry,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _ServiceFact(
                              Icons.schedule_rounded,
                              '${_service.minutes} mins',
                            ),
                            const _ServiceFact(Icons.home_outlined, 'At Home'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _service.description,
                          style: const TextStyle(
                            color: PinkoraBrand.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        if (_service.benefits.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F3),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Key Benefits',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                for (final benefit in _service.benefits)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF00B98A),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            benefit,
                                            style: const TextStyle(
                                              color: PinkoraBrand.muted,
                                              fontSize: 11,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Text(
                          'Beauty care, at your place',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _VisitHighlight(
                                icon: Icons.verified_user_outlined,
                                label: 'Verified expert',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _VisitHighlight(
                                icon: Icons.home_outlined,
                                label: 'At your home',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      key: const ValueKey('add-to-cart'),
                      onPressed: () => widget.onAdd(_service),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF32378),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ImagePageButton extends StatelessWidget {
  const _ImagePageButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: primary ? const Color(0xFFF32378) : Colors.white,
      foregroundColor: primary ? Colors.white : _ink,
      fixedSize: const Size(40, 40),
    ),
    icon: Icon(icon, size: 24),
  );
}

class _VisitHighlight extends StatelessWidget {
  const _VisitHighlight({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F6),
      border: Border.all(color: const Color(0xFFF4DEE4)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: PinkoraBrand.berry),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ServicePhoto extends StatelessWidget {
  const _ServicePhoto({
    super.key,
    required this.service,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final _Service service;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: const Color(0xFFFFE9ED),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.spa_outlined,
                color: _berry,
                size: width != null && width! < 80 ? 22 : 26,
              ),
              if (width == null || width! >= 80) ...[
                const SizedBox(height: 3),
                const Text(
                  'Photo coming soon',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _berry, fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (service.image.isEmpty) return fallback();
    return Image.asset(
      service.image,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width == null
          ? 900
          : (width! * MediaQuery.devicePixelRatioOf(context)).ceil(),
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

class _ServiceFact extends StatelessWidget {
  const _ServiceFact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: _ink),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.icon, this.title, this.message);
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _softBox(18),
    child: Column(
      children: [
        Icon(icon, size: 40, color: _berry),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
}

enum _AssignmentTimelineState { active, complete, pending }

class _AssignmentTimelineItem extends StatelessWidget {
  const _AssignmentTimelineItem({
    required this.title,
    this.subtitle,
    required this.state,
    this.isLast = false,
  });

  final String title;
  final String? subtitle;
  final _AssignmentTimelineState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _AssignmentTimelineState.active => _bookingPink,
      _AssignmentTimelineState.complete => const Color(0xFF19A765),
      _AssignmentTimelineState.pending => const Color(0xFFD1D1D1),
    };
    final height = subtitle == null ? 46.0 : 58.0;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: height,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: state == _AssignmentTimelineState.complete
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 11,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: state == _AssignmentTimelineState.pending
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFFF4B5CB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: state == _AssignmentTimelineState.pending
                        ? _muted
                        : _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentBadge extends StatelessWidget {
  const _AssignmentBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFF15985A), size: 13),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF27845A),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

BoxDecoration _softBox(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFF4DFE5)),
  boxShadow: const [
    BoxShadow(color: Color(0x10A3395F), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

String _formatServicePrice(int price) {
  final digits = price.toString();
  if (digits.length <= 3) return digits;

  final groups = <String>[];
  var remaining = digits.substring(0, digits.length - 3);
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  groups.insert(0, remaining);
  groups.add(digits.substring(digits.length - 3));
  return groups.join(',');
}
