import '../../integration/mobile_push.dart';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../booking/checkout_models.dart';
import '../catalog/catalog_repository.dart';
import 'all_services_screen.dart';
import 'promotional_banner_carousel.dart';
import '../../integration/customer_mobile_operations_api.dart';

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
    this.backendId,
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
  final String? backendId;
  String get serviceAreaId => '';
  String get id => '${category.toLowerCase()}::${name.toLowerCase()}';
}

class _SavedAddress {
  const _SavedAddress({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.postalCode,
    this.serviceAreaId = '',
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String postalCode;
  final String serviceAreaId;

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

/// Customer catalog and account screens backed by the mobile API.
class DevelopmentHomeScreen extends StatefulWidget {
  const DevelopmentHomeScreen({
    super.key,
    this.operationsApi,
    this.ownsOperationsApi = false,
  });

  final CustomerMobileOperationsApi? operationsApi;
  final bool ownsOperationsApi;

  @override
  State<DevelopmentHomeScreen> createState() => _DevelopmentHomeScreenState();
}

class _DevelopmentHomeScreenState extends State<DevelopmentHomeScreen>
    with WidgetsBindingObserver {
  bool _appActive = true;
  bool _savingPreferences = false;
  bool _catalogSyncing = false;
  late final _operationsApi =
      widget.operationsApi ?? CustomerMobileOperationsApi();
  String? _liveBookingId;
  Map<String, dynamic>? _serverBooking;
  String? _liveBookingStatus;
  bool _awaitingBookingPayment = false;
  int? _finalBillPaise;
  String? _liveWorkerName;
  int? _liveBookingTotal;
  List<Map<String, dynamic>> _pendingExtraServices = const [];
  bool _respondingToExtraService = false;
  Map<String, dynamic>? _durationExtension;
  DateTime? _serviceEndsAt;
  bool _respondingToDurationExtension = false;
  Timer? _bookingSyncTimer;
  final _search = TextEditingController();
  final _reviewController = TextEditingController();
  String _serviceOtp = '';
  final Map<String, String> _catalogServiceIds = {};
  List<_Service> _services = [];
  List<(String, IconData, String?)> _categories = [
    ('All Services', Icons.grid_view, null),
  ];
  List<PromotionalBanner> _banners = [];
  Map<String, String> _categoryImages = {};
  List<Map<String, dynamic>> _offersData = [],
      _packagesData = [],
      _bookingsData = [];
  Map<String, dynamic> _account = {};
  bool _catalogLoading = true;
  String? _catalogError;
  Timer? _catalogRefreshTimer;
  List<_Service> get _serviceDetails => _services;
  int _serviceElapsedSeconds = 0;
  final _plan = <_Service>[];
  final _cartQuantities = <String, int>{};
  final _savedAddresses = <_SavedAddress>[];

  int _tab = 0;
  int _checkoutStep = 0;
  String _category = 'All Services';
  String _location = 'Select an address';
  DateTime _bookingDate = DateTime.now().add(const Duration(days: 1));
  DateTime _calendarWeekStart = _mondayOf(
    DateTime.now().add(const Duration(days: 1)),
  );
  String _bookingTime = '10:00 AM';
  String _selectedPeriod = 'Morning';
  String _bookingPreference = 'Book Instantly';
  String _selectedAddressId = '';

  CheckoutPreview? _checkoutPreview;
  Timer? _confirmationTimer;
  Timer? _serviceClockTimer;
  String? _pendingBookingIdempotencyKey;
  String? _pendingBookingFingerprint;
  bool _submittingPreview = false;
  bool _serviceStarted = false;
  bool _serviceCompleted = false;

  int _reviewRating = 0;
  String _customerName = '';

  bool _underThousand = false;
  bool _offerApplied = false;
  String _offersTab = 'Offers';
  String _offersCategory = 'All';
  String _offerSearchQuery = '';
  bool _offerSearchVisible = false;
  bool _notificationsEnabled = true;
  bool _profilePromotionsEnabled = true;
  final bool _favoriteProfessional = false;

  bool _showServiceCategories = false;
  String? _selectedServiceCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MobilePush.pendingOpen.addListener(_handlePushOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePushOpen());
    _loadNotificationPreferences();
    _syncCustomerBackendData();
    _syncBookingCatalog();
    _loadAccount();
    _catalogRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true))
        _syncBookingCatalog();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && mounted) {
      _syncCustomerBackendData();
      _syncBookingCatalog();
    }
  }

  Future<void> _handlePushOpen() async {
    final target = MobilePush.pendingOpen.value;
    if (!mounted || target == null) return;
    MobilePush.pendingOpen.value = null;
    final type = target['type']!;
    if (type.startsWith('offer.') ||
        type.startsWith('banner.') ||
        type.startsWith('package.')) {
      setState(() => _tab = 2);
      await _syncBookingCatalog();
      return;
    }
    if (!type.startsWith('booking.') && !type.startsWith('assignment.')) return;
    try {
      // The scoped server read authorizes access before any booking is opened.
      final booking = await _operationsApi.getBooking(target['entityId']!);
      if (!mounted) return;
      setState(() {
        _liveBookingId = target['entityId'];
        _serverBooking = booking;
        _checkoutPreview = _previewFromBooking(booking);
        _checkoutStep = 6;
        _tab = 1;
      });
      _startLiveBookingSync(target['entityId']!);
    } catch (_) {
      if (mounted)
        _message(
          'This booking is unavailable. Refresh your bookings or sign in again.',
        );
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final saved = await _operationsApi.getNotificationPreferences();
      if (mounted)
        setState(() {
          _notificationsEnabled = saved['notificationsEnabled'] != false;
          _profilePromotionsEnabled =
              saved['marketingNotificationsEnabled'] != false;
        });
    } catch (_) {
      if (mounted)
        _message('Unable to load notification settings. Please retry.');
    }
  }

  Future<void> _saveNotificationPreferences(
    bool notifications,
    bool marketing,
    StateSetter refreshDialog,
  ) async {
    if (_savingPreferences) return;
    _savingPreferences = true;
    refreshDialog(() {});
    try {
      await _operationsApi.updateNotificationPreferences(
        notificationsEnabled: notifications,
        marketingNotificationsEnabled: marketing,
      );
      if (mounted)
        setState(() {
          _notificationsEnabled = notifications;
          _profilePromotionsEnabled = marketing;
        });
    } catch (_) {
      if (mounted)
        _message('Notification settings were not saved. Please retry.');
    } finally {
      _savingPreferences = false;
      if (mounted) refreshDialog(() {});
    }
  }

  Future<void> _loadAccount() async {
    try {
      final result = await _operationsApi.getProfile();
      if (!mounted) return;
      setState(() {
        _account = Map<String, dynamic>.from(result['user'] as Map? ?? {});
        _customerName = '${_account['fullName'] ?? ''}';
      });
    } catch (error) {
      if (mounted) _message('Unable to load your profile. Please retry.');
    }
  }

  Future<void> _syncCustomerBackendData() async {
    try {
      final addrs = await _operationsApi.getAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses.clear();
          for (final a in addrs) {
            _savedAddresses.add(
              _SavedAddress(
                id: '${a['_id'] ?? a['id'] ?? ''}',
                label: '${a['label'] ?? ''}',
                street: '${a['line1'] ?? ''}',
                city: '${a['city'] ?? ''}',
                postalCode: '${a['postalCode'] ?? ''}',
                serviceAreaId: '${a['serviceAreaId'] ?? ''}',
              ),
            );
          }
          if (!_savedAddresses.any((a) => a.id == _selectedAddressId)) {
            _selectedAddressId = _savedAddresses.isEmpty
                ? ''
                : _savedAddresses.first.id;
          }
          _location = _savedAddresses.isEmpty
              ? 'Select an address'
              : _selectedAddress.city;
        });
      }

      final bookings = await _operationsApi.getBookings();
      if (mounted) setState(() => _bookingsData = bookings);
      if (mounted && bookings.isNotEmpty) {
        final active = bookings.firstWhere(
          (b) => ![
            'completed',
            'cancelled',
          ].contains('${b['status']}'.toLowerCase()),
          orElse: () => <String, dynamic>{},
        );
        if (active.isNotEmpty) {
          final bid = '${active['_id'] ?? active['id']}';

          final totalPaise = int.tryParse('${active['totalPaise']}') ?? 0;
          final totalRupees = totalPaise ~/ 100;
          setState(() {
            _liveBookingId = bid;
            _liveBookingStatus = '${active['status'] ?? 'confirmed'}';
            _finalBillPaise = int.tryParse('${active['totalPaise']}');
            _awaitingBookingPayment =
                active['serviceFinishedAt'] != null &&
                active['paymentStatus'] != 'paid';
            _pendingExtraServices = const [];
            _durationExtension = active['durationExtension'] is Map
                ? Map<String, dynamic>.from(active['durationExtension'] as Map)
                : null;
            _serviceEndsAt = active['serviceEndsAt'] == null
                ? null
                : DateTime.tryParse('${active['serviceEndsAt']}');
            _liveWorkerName = null;
            _liveBookingTotal = totalRupees;
            _serverBooking = active;
            _checkoutPreview = _previewFromBooking(active);
          });
          _startLiveBookingSync(bid);
        }
      }
    } catch (error) {
      if (mounted) _message('Unable to load your account data. Please retry.');
    }
  }

  Future<void> _syncBookingCatalog() async {
    if (_catalogSyncing || !mounted) return;
    _catalogSyncing = true;
    try {
      final results = await Future.wait([
        _operationsApi.getCatalogServices(),
        _operationsApi.getRecords('/api/catalog/categories'),
        _operationsApi.getRecords('/api/catalog/offers'),
        _operationsApi.getRecords('/api/catalog/packages'),
        _operationsApi.getRecords('/api/catalog/banners'),
      ]);
      final catalogServices = results[0],
          categories = results[1],
          offers = results[2],
          packages = results[3],
          banners = results[4];

      if (mounted) {
        setState(() {
          final available = <_Service>[];
          _catalogServiceIds.clear();
          for (final service in catalogServices) {
            final id = '${service['_id'] ?? service['id'] ?? ''}';
            final name = '${service['name'] ?? ''}'.trim().toLowerCase();
            if (RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(id) &&
                name.isNotEmpty) {
              _catalogServiceIds[name] = id;
              final categoryData = service['category'];
              final categoryName = categoryData is Map
                  ? '${categoryData['name'] ?? ''}'.trim()
                  : '';
              final category = categoryName;
              final pricePaise = num.tryParse('${service['pricePaise']}');
              final originalPricePaise = num.tryParse(
                '${service['compareAtPricePaise']}',
              );
              final discountPercent =
                  pricePaise != null &&
                      originalPricePaise != null &&
                      originalPricePaise > pricePaise
                  ? ((originalPricePaise - pricePaise) *
                            100 /
                            originalPricePaise)
                        .round()
                  : null;

              available.add(
                _Service(
                  '${service['name']}'.trim(),
                  category,
                  ((pricePaise ?? 0) / 100).round(),
                  int.tryParse('${service['durationMinutes']}') ?? 60,
                  '${service['thumbnail'] ?? ((service['images'] as List? ?? []).isEmpty ? '' : service['images'][0]['url'] ?? '')}',
                  backendId: id,
                  originalPrice: originalPricePaise == null
                      ? null
                      : (originalPricePaise / 100).round(),
                  discount: discountPercent == null
                      ? null
                      : '$discountPercent% OFF',
                  description: '${service['description'] ?? ''}',
                  benefits: (service['benefits'] as List? ?? const [])
                      .cast<String>(),
                ),
              );
            }
          }
          _services = available;
          _categories = [
            ('All Services', Icons.grid_view, null),
            for (final category in categories)
              (
                '${category['name']}',
                Icons.spa_outlined,
                '${category['image'] is Map ? category['image']['url'] ?? '' : category['thumbnail'] ?? ''}',
              ),
          ];
          _categoryImages = {
            for (final category in categories)
              '${category['name']}':
                  '${category['image'] is Map ? category['image']['url'] ?? '' : category['thumbnail'] ?? ''}',
          };
          _offersData = offers;
          _packagesData = packages;
          _banners = [
            for (final banner in banners)
              if ((banner['audiences'] as List? ?? []).contains('customer'))
                PromotionalBanner(
                  id: '${banner['_id'] ?? banner['id']}',
                  title: '${banner['name'] ?? ''}',
                  subtitle: '${banner['subtitle'] ?? ''}',
                  imageAsset: '${banner['thumbnail'] ?? ''}',
                  action: banner['targetType'] == 'service'
                      ? PromotionalBannerAction.service
                      : PromotionalBannerAction.offer,
                  targetId: '${banner['targetId'] ?? ''}',
                ),
          ];
          _catalogLoading = false;
          _catalogError = null;
        });
      }
    } catch (e) {
      debugPrint('[CustomerApp] Catalog refresh failed: $e');
      if (mounted)
        setState(() {
          _catalogLoading = false;
          _catalogError = 'Unable to load services. Please retry.';
        });
    } finally {
      _catalogSyncing = false;
    }
  }

  @override
  void dispose() {
    MobilePush.pendingOpen.removeListener(_handlePushOpen);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.operationsApi == null || widget.ownsOperationsApi)
      _operationsApi.close();
    _catalogRefreshTimer?.cancel();
    _bookingSyncTimer?.cancel();
    _confirmationTimer?.cancel();
    _serviceClockTimer?.cancel();
    _search.dispose();
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

  List<(String, IconData, String?)> get _homeCategories {
    final catalogCategories = _categories.skip(1).toList();
    const preferred = ['facial', 'hair spa', 'makeup', 'waxing', 'manicure'];
    final selected = <(String, IconData, String?)>[];
    for (final keyword in preferred) {
      for (final category in catalogCategories) {
        if (category.$1.toLowerCase().contains(keyword) &&
            !selected.contains(category)) {
          selected.add(category);
          break;
        }
      }
    }
    for (final category in catalogCategories) {
      if (selected.length >= 5) break;
      if (!selected.contains(category)) selected.add(category);
    }
    return [...selected, _categories.first];
  }

  String _homeCategoryLabel(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('facial')) return 'Facial';
    if (normalized.contains('hair spa')) return 'Hair Spa';
    if (normalized.contains('manicure')) return 'Manicure';
    return name;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showNotifications() async {
    try {
      final records = await _operationsApi.getRecords(
        '/api/mobile/customer/notifications',
      );
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Notifications')),
              if (records.isEmpty)
                const ListTile(title: Text('No notifications yet.')),
              for (final record in records)
                ListTile(
                  title: Text('${record['title'] ?? record['type'] ?? ''}'),
                  subtitle: Text(
                    '${record['message'] ?? record['body'] ?? ''}',
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) _message('Unable to load notifications. Please retry.');
    }
  }

  void _setOffer(bool enabled) {
    setState(() => _tab = 2);
  }

  void _add(_Service service) {
    final matches = _services.where((item) => item.id == service.id);
    if (matches.isEmpty) {
      _message('${service.name} is currently unavailable.');
      return;
    }
    service = matches.first;
    if (_checkoutPreview != null || _liveBookingId != null) {
      _startNewBooking(showCategories: false);
    }
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

  int get _cartDiscount => 0;

  int get _cartTotal => _cartSubtotal - _cartDiscount;

  int get _checkoutTotal => _cartTotal;

  void _openAddServices() {
    setState(() {
      _checkoutStep = 0;
      _showServiceCategories = true;
      _selectedServiceCategory = null;
    });
  }

  void _startNewBooking({bool showCategories = true, bool openHome = false}) {
    _bookingSyncTimer?.cancel();
    _confirmationTimer?.cancel();
    _stopServiceTimer();
    _reviewController.clear();
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    setState(() {
      _plan.clear();
      _cartQuantities.clear();
      _checkoutPreview = null;
      _liveBookingId = null;
      _liveBookingStatus = null;
      _awaitingBookingPayment = false;
      _liveWorkerName = null;
      _checkoutStep = 0;
      _tab = openHome ? 0 : 1;
      _showServiceCategories = showCategories;
      _selectedServiceCategory = null;
      _serviceOtp = '';
      _serviceElapsedSeconds = 0;
      _serviceStarted = false;
      _serviceCompleted = false;
      _submittingPreview = false;
      _reviewRating = 0;

      _offerApplied = false;
      _bookingDate = tomorrow;
      _calendarWeekStart = _mondayOf(tomorrow);
      _bookingTime = '10:00 AM';
      _selectedPeriod = 'Morning';
      _bookingPreference = 'Book Instantly';

      _pendingExtraServices = const [];
      _durationExtension = null;
      _serviceEndsAt = null;
      _liveBookingTotal = null;
    });
  }

  bool get _hasValidCheckoutSelection =>
      _plan.isNotEmpty &&
      !_bookingDate.isBefore(DateUtils.dateOnly(DateTime.now())) &&
      _bookingTime.isNotEmpty &&
      _savedAddresses.any((address) => address.id == _selectedAddressId);

  void _openBookingConfirmation() {
    if (!_hasValidCheckoutSelection) {
      _message(
        'Review your service, date, time and address before continuing.',
      );
      return;
    }
    setState(() => _checkoutStep = 4);
  }

  Future<void> _confirmPreviewBooking() async {
    if (_submittingPreview || _checkoutPreview != null) return;
    if (!_hasValidCheckoutSelection) {
      _message('Your booking details changed. Please review them again.');
      return;
    }
    setState(() => _submittingPreview = true);
    _serviceStarted = false;
    _serviceCompleted = false;
    _stopServiceTimer();
    _serviceOtp = '';
    _reviewController.clear();
    _reviewRating = 0;

    final address = _selectedAddress;

    final created = await _createBackendBooking(address);
    if (!mounted) return;
    setState(() {
      _submittingPreview = false;
      if (created) {
        _checkoutPreview = _previewFromBooking(_serverBooking!);
        _checkoutStep = 6;
      }
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

  void _returnToProfessionalSearch() {
    setState(() => _checkoutStep = 6);
  }

  String get _serviceElapsedTime {
    final elapsed = Duration(seconds: _serviceElapsedSeconds);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  _SavedAddress get _selectedAddress => _savedAddresses.firstWhere(
    (address) => address.id == _selectedAddressId,
    orElse: () => const _SavedAddress(
      id: '',
      label: 'Select a saved address',
      street: '',
      city: '',
      postalCode: '',
    ),
  );

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
      builder: (_) => _AddAddressDialog(
        initialCity: _savedAddresses.isEmpty ? '' : _selectedAddress.city,
      ),
    );
    if (address == null || !mounted) return;
    try {
      final areas = await _operationsApi.getServiceAreas(address.postalCode);
      final matches = areas
          .where(
            (area) =>
                '${area['city']}'.toLowerCase() == address.city.toLowerCase(),
          )
          .toList();
      if (matches.isEmpty) {
        if (mounted)
          _message('This address is outside the available service areas.');
        return;
      }
      final saved = await _operationsApi.saveAddress(
        label: address.label,
        line1: address.street,
        city: address.city,
        postalCode: address.postalCode,
        serviceAreaId: '${matches.first['_id'] ?? matches.first['id']}',
      );
      if (!mounted) return;
      final result = _SavedAddress(
        id: '${saved['_id'] ?? saved['id']}',
        label: '${saved['label']}',
        street: '${saved['line1']}',
        city: '${saved['city']}',
        postalCode: '${saved['postalCode']}',
        serviceAreaId: '${saved['serviceAreaId']}',
      );
      setState(() {
        _savedAddresses.add(result);
        _selectedAddressId = result.id;
        _location = result.city;
      });
    } catch (error) {
      if (mounted) _message('Unable to save address: $error');
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
    final matches = _services.where((item) => item.id == service.id);
    if (matches.isEmpty) {
      _message('${service.name} is currently unavailable.');
      return;
    }
    service = matches.first;
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
          for (final place in _savedAddresses.map((a) => a.city).toSet())
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
          if (service.backendId == banner.targetId) {
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
        final available = _offersData.any(
          (offer) => '${offer['_id'] ?? offer['id']}' == banner.targetId,
        );
        if (available) {
          setState(() => _tab = 2);
        } else {
          _message('This promotion is no longer available.');
        }
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
                      heroImage: _categoryImages[_selectedServiceCategory],
                      onBack: _backFromServiceCategory,
                      onServiceSelected: _details,
                      onAddToCart: _addToCart,
                    )
                  : AllServicesScreen(
                      categoryNames: _categories
                          .skip(1)
                          .map((category) => category.$1)
                          .toList(),
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

    final featured = _visibleServices.take(4).toList();
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
              onPressed: _showNotifications,
              icon: const Icon(Icons.notifications_none_outlined),
            ),
            InkWell(
              onTap: () => setState(() => _tab = 3),
              child: const CircleAvatar(
                radius: 19,
                child: Icon(Icons.person_outline),
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
        Wrap(
          spacing: 4,
          runSpacing: 8,
          children: [
            for (final entry in _homeCategories)
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
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _category == entry.$1
                              ? const Color(0xFFFFD5E0)
                              : const Color(0xFFFFE9ED),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: entry.$3 == null || entry.$3!.isEmpty
                            ? Icon(entry.$2, color: _berry, size: 21)
                            : Image.network(
                                entry.$3!,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(entry.$2, color: _berry, size: 21),
                              ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _homeCategoryLabel(entry.$1),
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
            height: 108,
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
        if (_catalogLoading) const Center(child: CircularProgressIndicator()),
        if (_catalogError != null) ...[
          Text(_catalogError!),
          TextButton(
            onPressed: _syncBookingCatalog,
            child: const Text('Retry'),
          ),
        ],
        if (_offersData.isNotEmpty) ...[
          const SizedBox(height: 10),
          _discount(_offersData.first),
          const SizedBox(height: 8),
          _heading('Offers for You', () => setState(() => _tab = 2)),
          const SizedBox(height: 4),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < _offersData.length.clamp(0, 2);
                  index++
                )
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == 0 && _offersData.length > 1 ? 10 : 0,
                      ),
                      child: _offerCard(_offersData[index]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _discount(Map<String, dynamic> offer) => InkWell(
    key: const ValueKey('discount-banner'),
    onTap: () => setState(() => _tab = 2),
    borderRadius: BorderRadius.circular(17),
    child: Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 10, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE6),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _berry,
            child: Text(
              offer['discountType'] == 'percentage' ? '%' : '₹',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _offerDiscountLabel(offer).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: _berry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${offer['code'] ?? offer['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 13, color: _berry),
        ],
      ),
    ),
  );

  Widget _offerCard(Map<String, dynamic> offer) => InkWell(
    key: ValueKey('home-offer-${offer['_id'] ?? offer['id'] ?? offer['name']}'),
    onTap: () => setState(() => _tab = 2),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _catalogCover(offer['thumbnail']),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x55FCE3E9), Color(0x00FCE3E9)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${offer['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _offerDiscountLabel(offer).toUpperCase(),
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

  Widget _hero(double width) => PromotionalBannerCarousel(
    banners: _banners,
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
    height: 108,
    clipBehavior: Clip.antiAlias,
    decoration: _softBox(15),
    child: InkWell(
      onTap: () => _details(service),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServicePhoto(service: service, width: width, height: 43),

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
              if (_liveBookingId != null && _liveBookingStatus != 'completed')
                Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0F5), Color(0xFFFFE4EC)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF9B8CE)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1AEE7A9D),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFE91E63),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ACTIVE BOOKING · ${_liveBookingStatus?.toUpperCase() ?? "IN PROGRESS"}',
                              style: const TextStyle(
                                color: Color(0xFF260711),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assigned Professional: ${_liveWorkerName ?? "Awaiting admin allocation"}',
                        style: const TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _checkoutStep = 6),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.location_on, size: 18),
                          label: const Text(
                            'Track Professional & View OTP',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                title: 'Offers & Packages',
                subtitle: 'View available offers',

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
        _summaryRow('Convenience Fee', 0),
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
                  if (_checkoutStep == 4) _checkoutPreview = null;
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
              if (redesignedStep || step == 2) ...[
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
                  if (step == 3) _bookingConfirmationStep(),
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
          _checkoutPreview == null
              ? _confirmBookingAction()
              : const Padding(
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
              if (_liveBookingId != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    'Live Order #${_liveBookingId!.substring(_liveBookingId!.length - 6).toUpperCase()} · ${_liveBookingStatus ?? "active"}',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _liveBookingId != null
                      ? 'Live Booking · Real dispatch to nearby partner'
                      : 'Development preview · No real booking was created',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _liveBookingId != null
                        ? const Color(0xFF15803D)
                        : _muted,
                    fontSize: 10,
                    fontWeight: _liveBookingId != null
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
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
    String? actionKey,
    String? actionLabel,
    VoidCallback? onAction,
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
      if (onAction != null)
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
                actionLabel!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
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
        const _InfoCard(
          Icons.location_on_outlined,
          'Travel status',
          'Live map tracking is unavailable. Booking progress is updated from the server.',
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
        : 'view-service-start-code',
    actionLabel: _serviceCompleted
        ? 'View Completed Service'
        : _serviceStarted
        ? 'Return to Service'
        : 'View Service Start Code',
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
    title: 'Your Service Start Code',
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
          'Your professional will verify this code in their app',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share the code with your assigned professional at the appointment. Only the professional can start the service.',
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
                'SERVICE START CODE',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              if (_serviceOtp.isNotEmpty)
                Text(
                  _serviceOtp,
                  key: const ValueKey('service-start-code'),
                  style: const TextStyle(
                    color: _bookingBerry,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                  ),
                )
              else
                Text(
                  _liveBookingId == null
                      ? 'A start code is available only for live bookings.'
                      : 'The start code will appear here when the professional arrives.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    ),
    actionKey: _serviceOtp.isEmpty && _liveBookingId != null
        ? 'request-service-start-code'
        : 'service-start-code-done',
    actionLabel: _serviceOtp.isEmpty && _liveBookingId != null
        ? 'Request Start Code'
        : 'Back to Tracking',
    onAction: () {
      final bookingId = _liveBookingId;
      if (_serviceOtp.isEmpty && bookingId != null) {
        _revealLiveServiceOtp(bookingId);
      } else {
        setState(() => _checkoutStep = 8);
      }
    },
    onBack: () => setState(() => _checkoutStep = 8),
  );

  Widget _extraServiceApprovalCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _bookingLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extra service approval',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your worker has requested these additions. Approve only if you agree to the added price.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        for (final extra in _pendingExtraServices) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${extra['name'] ?? 'Extra service'}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '₹${_formatServicePrice((int.tryParse('${extra['amountPaise']}') ?? 0) ~/ 100)}',
                style: const TextStyle(
                  color: _bookingBerry,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _respondingToExtraService
                      ? null
                      : () => _respondToExtraService(extra, approve: false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: _respondingToExtraService
                      ? null
                      : () => _respondToExtraService(extra, approve: true),
                  style: FilledButton.styleFrom(backgroundColor: _bookingPink),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
          if (!identical(extra, _pendingExtraServices.last))
            const Divider(height: 22, color: _bookingLine),
        ],
      ],
    ),
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
        if (_liveBookingId != null && _pendingExtraServices.isNotEmpty)
          _extraServiceApprovalCard(),
        if (_liveBookingId != null && _awaitingBookingPayment)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Service finished - Awaiting payment. Final bill INR ${((_finalBillPaise ?? 0) / 100).toStringAsFixed(2)}. Scan the Razorpay QR shown by your worker to pay the final bill, including approved extras. Completion updates after payment is verified.',
              ),
            ),
          ),
        if (_liveBookingId != null && _durationExtension != null) ...[
          const SizedBox(height: 14),
          _durationExtensionDecisionCard(),
        ],
        _bookingPreviewDetailCard(),
      ],
    ),
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
        Text(
          _liveWorkerName ?? 'Awaiting admin allocation',
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
    onAction: () async {
      if (_reviewRating == 0) {
        _message('Select a star rating before submitting your review.');
        return;
      }
      final bookingId = _liveBookingId;
      if (bookingId == null) return;
      try {
        await _operationsApi.submitReview(
          bookingId,
          _reviewRating,
          _reviewController.text.trim(),
        );
        if (mounted) {
          _syncCustomerHistory();
          setState(() => _checkoutStep = 13);
        }
      } catch (error) {
        if (mounted) _message('Unable to submit review: $error');
      }
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
            '₹${_formatServicePrice(_liveBookingTotal ?? preview.total)}',
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
        title: Text(
          _liveBookingId == null ? 'Service Bill · Preview' : 'Service Bill',
        ),
        content: Text(
          'Total: ₹${_formatServicePrice(_liveBookingTotal ?? preview.total)}\n'
          'Payment: due after service completion. The worker will present the payment QR.',
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

  Widget _bookingHistoryScreen() => RefreshIndicator(
    onRefresh: () async {
      final records = await _operationsApi.getBookings();
      if (mounted) setState(() => _bookingsData = records);
    },
    child: ListView(
      key: const ValueKey('booking-history-list'),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'My Bookings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        if (_bookingsData.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No bookings yet.'),
          ),
        for (final booking in _bookingsData)
          Card(
            child: ListTile(
              title: Text(
                (booking['items'] as List? ?? [])
                    .map((item) => '${item['name'] ?? 'Service'}')
                    .join(', '),
              ),
              subtitle: Text(
                '${booking['status'] ?? ''}\n${DateTime.tryParse('${booking['startsAt']}')?.toLocal() ?? 'Schedule unavailable'}',
              ),
              trailing: Text(
                CatalogService.formatPaise(
                  BigInt.tryParse('${booking['totalPaise']}') ?? BigInt.zero,
                ),
              ),
              onTap: '${booking['_id'] ?? booking['id']}' == _liveBookingId
                  ? () => setState(() {
                      _checkoutStep = 6;
                      _tab = 1;
                    })
                  : null,
            ),
          ),
      ],
    ),
  );

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

  Widget _assignedProfessionalCard() => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(_liveWorkerName ?? 'Awaiting admin allocation'),
      subtitle: Text(_liveBookingStatus ?? 'Booking status unavailable'),
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
            _bookingTotalLine('Convenience Fee', 0),
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
                  '₹${_formatServicePrice(_checkoutTotal)}',
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
      const SizedBox(height: 14),
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
    key: const ValueKey('continue-to-booking-confirmation'),
    label: 'Review Booking',
    onPressed: _openBookingConfirmation,
  );

  Widget _confirmBookingAction() => _checkoutAction(
    key: const ValueKey('confirm-booking'),
    label: _submittingPreview ? 'Creating Booking...' : 'Confirm Booking',
    onPressed: _submittingPreview || _checkoutPreview != null
        ? null
        : _confirmPreviewBooking,
  );

  Future<bool> _createBackendBooking(_SavedAddress address) async {
    try {
      if (_plan.any(
        (service) =>
            !_catalogServiceIds.containsKey(
              service.name.trim().toLowerCase(),
            ) &&
            service.backendId == null,
      )) {
        await _syncBookingCatalog();
      }
      final items = <Map<String, dynamic>>[];
      for (final service in _plan) {
        final serviceId =
            _catalogServiceIds[service.name.trim().toLowerCase()] ??
            service.backendId;
        if (serviceId == null ||
            !RegExp(
              r'^[a-f0-9]{24}$',
              caseSensitive: false,
            ).hasMatch(serviceId)) {
          throw StateError(
            '${service.name} is currently unavailable. Please choose another service or try again later.',
          );
        }
        items.add({
          'serviceId': serviceId,
          'quantity': _cartQuantities[service.id] ?? 1,
        });
      }
      final saId = address.serviceAreaId;
      final aId = address.id;
      final objectId = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);
      if (!objectId.hasMatch(saId) || !objectId.hasMatch(aId)) {
        throw StateError('Please select a saved, serviceable address.');
      }

      int hour = 18;
      int minute = 0;
      try {
        final raw = _bookingTime.trim().toUpperCase();
        final isPm = raw.contains('PM');
        final isAm = raw.contains('AM');
        final parts = raw.replaceAll(RegExp(r'[^\d:]'), '').split(':');
        if (parts.isNotEmpty) {
          var h = int.parse(parts[0]);
          final m = parts.length > 1 ? int.parse(parts[1]) : 0;
          if (isPm && h < 12) h += 12;
          if (isAm && h == 12) h = 0;
          hour = h;
          minute = m;
        }
      } catch (_) {}

      final now = DateTime.now();
      var scheduled = DateTime(
        _bookingDate.year,
        _bookingDate.month,
        _bookingDate.day,
        hour,
        minute,
      );
      if (scheduled.isBefore(now.add(const Duration(minutes: 60)))) {
        scheduled = DateTime(now.year, now.month, now.day + 1, hour, minute);
      }

      final startsAt = scheduled.toUtc();
      final fingerprint = jsonEncode({
        'serviceAreaId': saId,
        'items': items,
        'addressId': aId,
        'startsAt': startsAt.toIso8601String(),
        'method': 'cash',
      });
      if (_pendingBookingFingerprint != fingerprint ||
          _pendingBookingIdempotencyKey == null) {
        _pendingBookingFingerprint = fingerprint;
        _pendingBookingIdempotencyKey =
            'booking_${DateTime.now().microsecondsSinceEpoch}';
      }

      final booking = await _operationsApi.createBooking(
        serviceAreaId: saId,
        items: items,
        addressId: aId,
        startsAt: startsAt,
        method: 'cash',
        idempotencyKey: _pendingBookingIdempotencyKey,
      );
      if (!mounted) return false;
      final bid = '${booking['_id'] ?? booking['id'] ?? ''}';
      if (bid.isEmpty) {
        throw StateError('The server did not confirm the booking.');
      }
      _confirmationTimer?.cancel();
      setState(() {
        _liveBookingId = bid;
        _serverBooking = booking;
        _pendingBookingIdempotencyKey = null;
        _pendingBookingFingerprint = null;
        _liveBookingTotal =
            (int.tryParse('${booking['totalPaise']}') ?? 0) ~/ 100;
        _checkoutStep = 6;
      });
      _liveBookingStatus = '${booking['status'] ?? 'confirmed'}';
      _liveWorkerName = null;
      _startLiveBookingSync(bid);
      return true;
    } catch (e) {
      debugPrint('[CustomerApp] Booking creation failed: $e');
      if (mounted) {
        if (e is CustomerMobileApiException) {
          if (e.code == 'IDEMPOTENCY_CONFLICT') {
            _pendingBookingIdempotencyKey = null;
            _pendingBookingFingerprint = null;
            _message('Your booking details changed. Please confirm again.');
          } else if (e.code == 'SLOT_UNAVAILABLE') {
            _message(
              'This appointment time is no longer available. Choose another time and try again.',
            );
          } else {
            _message(e.message);
          }
        } else {
          _message(
            e is StateError
                ? e.message
                : 'Booking could not be created. Please try again.',
          );
        }
      }
      return false;
    }
  }

  CheckoutPreview _previewFromBooking(Map<String, dynamic> booking) {
    final scheduled = DateTime.parse('${booking['startsAt']}').toLocal();
    final address = booking['addressSnapshot'] as Map? ?? {};
    int rupees(dynamic paise) => (int.tryParse('$paise') ?? 0) ~/ 100;
    return CheckoutPreview(
      services: [
        for (final item in (booking['items'] as List? ?? []))
          PreviewService(
            name: '${item['name'] ?? 'Service'}',
            quantity: int.tryParse('${item['quantity']}') ?? 1,
            unitPrice: rupees(item['pricePaise']),
          ),
      ],
      date: scheduled,
      time: TimeOfDay.fromDateTime(scheduled).format(context),
      bookingPreference: _bookingPreference,
      addressLabel: '${address['label'] ?? ''}',
      addressDetails: [
        address['line1'],
        address['line2'],
        address['city'],
        address['postalCode'],
      ].where((v) => v != null && '$v'.isNotEmpty).join(', '),
      subtotal: rupees(booking['subtotalPaise']),
      discount: rupees(booking['discountPaise']),
      convenienceFee: 0,
      tip: 0,
      total: rupees(booking['totalPaise']),
      paymentMethod: CheckoutPaymentMethod.cashOnService,
    );
  }

  void _startLiveBookingSync(String bookingId) {
    _bookingSyncTimer?.cancel();
    var syncing = false;
    Future<void> sync() async {
      if (!mounted || syncing) return;
      syncing = true;
      try {
        final data = await _operationsApi.getBooking(bookingId);
        if (!mounted) return;
        final status = '${data['status'] ?? ''}';
        final assignmentStatus = '${data['assignmentStatus'] ?? ''}';
        final worker = data['worker'] is Map ? data['worker'] : null;
        final workerName = worker != null
            ? '${worker['fullName'] ?? 'Assigned beauty expert'}'
            : 'Awaiting admin allocation';
        final pendingExtras =
            (data['pendingExtraServices'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        final totalPaise = int.tryParse('${data['totalPaise']}');

        setState(() {
          _liveBookingStatus = status;
          _serverBooking = data;
          _checkoutPreview = _previewFromBooking(data);
          _finalBillPaise = totalPaise;
          _awaitingBookingPayment =
              data['serviceFinishedAt'] != null &&
              data['paymentStatus'] != 'paid';
          _liveWorkerName = workerName;
          _pendingExtraServices = pendingExtras;
          _durationExtension = data['durationExtension'] is Map
              ? Map<String, dynamic>.from(data['durationExtension'] as Map)
              : null;
          _serviceEndsAt = data['serviceEndsAt'] == null
              ? null
              : DateTime.tryParse('${data['serviceEndsAt']}');
          if (totalPaise != null) _liveBookingTotal = totalPaise ~/ 100;
        });

        if ((assignmentStatus == 'accepted' ||
                status == 'assigned' ||
                status == 'travelling' ||
                status == 'arrived' ||
                status == 'in_progress') &&
            _checkoutStep < 7) {
          _confirmationTimer?.cancel();
          setState(() => _checkoutStep = 7);
        }
        if ((status == 'travelling' || status == 'arrived') &&
            _checkoutStep < 8) {
          setState(() => _checkoutStep = 8);
        }
        if (status == 'arrived' && _checkoutStep < 9) {
          _revealLiveServiceOtp(bookingId);
          setState(() => _checkoutStep = 9);
        }
        if (status == 'in_progress' && _checkoutStep < 10) {
          if (!_serviceStarted) _startServiceTimer();
          setState(() => _checkoutStep = 10);
        }
        if (status == 'completed' && _checkoutStep < 11) {
          _stopServiceTimer();
          setState(() {
            _serviceCompleted = true;
            _checkoutStep = 11;
          });
          _bookingSyncTimer?.cancel();
        }
      } catch (e) {
        debugPrint('[CustomerApp] booking sync error: $e');
      } finally {
        syncing = false;
      }
    }

    sync();
    _bookingSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true)) sync();
    });
  }

  Future<void> _revealLiveServiceOtp(String bookingId) async {
    try {
      final otp = await _operationsApi.revealServiceOtp(bookingId);
      if (mounted && otp.isNotEmpty) {
        setState(() {
          _serviceOtp = otp;
        });
      }
    } catch (e) {
      debugPrint('[CustomerApp] revealServiceOtp error: $e');
      if (mounted) _message('Could not load the service code. Please retry.');
    }
  }

  Future<void> _respondToExtraService(
    Map<String, dynamic> extra, {
    required bool approve,
  }) async {
    final bookingId = _liveBookingId;
    final extraId = '${extra['_id'] ?? ''}';
    if (_respondingToExtraService || bookingId == null || extraId.isEmpty) {
      return;
    }
    if (approve) {
      final amountPaise = int.tryParse('${extra['amountPaise']}') ?? 0;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Approve extra service?'),
          content: Text(
            'Add ${extra['name'] ?? 'this service'} for '
            '₹${_formatServicePrice(amountPaise ~/ 100)} to your booking?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
    }
    setState(() => _respondingToExtraService = true);
    try {
      await _operationsApi.respondToExtraService(
        bookingId: bookingId,
        extraServiceId: extraId,
        approve: approve,
      );
      if (!mounted) return;
      setState(() {
        _pendingExtraServices = _pendingExtraServices
            .where((item) => '${item['_id']}' != extraId)
            .toList(growable: false);
      });
      _message(
        approve
            ? 'Extra service approved. The updated amount will be used for payment.'
            : 'Extra service declined.',
      );
    } catch (error) {
      if (mounted) _message('Could not update the extra service: $error');
    } finally {
      if (mounted) setState(() => _respondingToExtraService = false);
    }
  }

  Future<void> _respondToDurationExtension({required bool approve}) async {
    final bookingId = _liveBookingId;
    final extension = _durationExtension;
    final extensionId = '${extension?['id'] ?? extension?['_id'] ?? ''}';
    if (_respondingToDurationExtension ||
        bookingId == null ||
        extensionId.isEmpty) {
      return;
    }
    if (approve) {
      final minutes =
          int.tryParse(
            '${extension?['minutes'] ?? extension?['durationMinutes']}',
          ) ??
          15;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Approve extra time?'),
          content: Text(
            'Approve $minutes additional minutes? The extension adds ₹0. '
            'Your booking total remains ₹${_formatServicePrice(_liveBookingTotal ?? 0)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
    }
    setState(() => _respondingToDurationExtension = true);
    try {
      final response = await _operationsApi.respondToDurationExtension(
        bookingId: bookingId,
        extensionId: extensionId,
        approve: approve,
      );
      if (!mounted) return;
      final updatedExtension = response['durationExtension'];
      setState(() {
        if (updatedExtension is Map) {
          _durationExtension = Map<String, dynamic>.from(updatedExtension);
        } else {
          _durationExtension = {
            ...?extension,
            'status': approve ? 'approved' : 'declined',
          };
        }
        if (response['serviceEndsAt'] != null) {
          _serviceEndsAt = DateTime.tryParse('${response['serviceEndsAt']}');
        }
      });
      _message(
        approve
            ? 'Extra time approved. Your booking total is unchanged.'
            : 'Extra time declined. Your booking total is unchanged.',
      );
    } catch (error) {
      if (mounted) _message('Could not update the extension decision: $error');
    } finally {
      if (mounted) setState(() => _respondingToDurationExtension = false);
    }
  }

  Widget _durationExtensionDecisionCard() {
    final extension = _durationExtension!;
    final status = '${extension['status'] ?? 'pending'}';
    final minutes =
        int.tryParse(
          '${extension['minutes'] ?? extension['durationMinutes']}',
        ) ??
        15;
    final total = _liveBookingTotal ?? 0;
    final serviceEnd = _serviceEndsAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D6AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service-time extension',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            status == 'pending'
                ? 'The worker requested $minutes additional minutes. Decide within 5 minutes. The extension adds ₹0; your booking total remains ₹${_formatServicePrice(total)}.'
                : status == 'approved'
                ? '$minutes additional minutes approved. The extension adds ₹0; your booking total remains ₹${_formatServicePrice(total)}.'
                : status == 'expired'
                ? 'No response was received in time. The extension expired; no extra-time charge was added.'
                : 'The extension was declined; no extra-time charge was added.',
            style: const TextStyle(color: _muted, height: 1.4),
          ),
          if (serviceEnd != null) ...[
            const SizedBox(height: 5),
            Text(
              'Current service end: ${TimeOfDay.fromDateTime(serviceEnd.toLocal()).format(context)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _respondingToDurationExtension
                        ? null
                        : () => _respondToDurationExtension(approve: false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _respondingToDurationExtension
                        ? null
                        : () => _respondToDurationExtension(approve: true),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
    if (preview == null) {
      return Container(
        key: const ValueKey('booking-confirmation-review'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bookingLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review your booking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your booking is confirmed only after it is saved successfully.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const Divider(height: 28, color: _bookingLine),
            for (final service in _plan) ...[
              _paymentDetailRow(
                '${service.name} × ${_cartQuantities[service.id] ?? 1}',
                '₹${_formatServicePrice(service.price * (_cartQuantities[service.id] ?? 1))}',
              ),
              const SizedBox(height: 10),
            ],
            const Divider(height: 24, color: _bookingLine),
            _paymentDetailRow(
              'Date',
              '${_formatWeekday(_bookingDate)}, ${_formatShortDate(_bookingDate)}',
            ),
            const SizedBox(height: 10),
            _paymentDetailRow('Time', _bookingTime),
            const SizedBox(height: 10),
            Text(
              _selectedAddress.label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            Text(
              _selectedAddress.details,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const Divider(height: 24, color: _bookingLine),
            _paymentDetailRow(
              'Total',
              '₹${_formatServicePrice(_checkoutTotal)}',
              emphasize: true,
            ),
            const SizedBox(height: 10),
            const Text(
              'Pay after service completion.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking ${_liveBookingId ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(_liveBookingStatus ?? 'Status unavailable'),
        _bookingPreviewDetailCard(),
      ],
    );
  }

  Widget _offers() {
    final discountedServices = _serviceDetails
        .where((service) => service.originalPrice != null)
        .where(_offerMatchesCategory)
        .where((service) {
          final query = _offerSearchQuery.trim().toLowerCase();
          return query.isEmpty ||
              service.name.toLowerCase().contains(query) ||
              service.category.toLowerCase().contains(query) ||
              service.description.toLowerCase().contains(query);
        })
        .toList();
    final visibleOffers = _offersData.where((offer) {
      final query = _offerSearchQuery.trim().toLowerCase();
      return query.isEmpty ||
          '${offer['name'] ?? ''}'.toLowerCase().contains(query) ||
          '${offer['description'] ?? ''}'.toLowerCase().contains(query) ||
          '${offer['code'] ?? ''}'.toLowerCase().contains(query);
    }).toList();
    final showPackages = _offersTab == 'Packages';

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.onboardingBackground,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.58)),
        RefreshIndicator(
          onRefresh: _syncBookingCatalog,
          child: ListView(
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
                                borderSide: const BorderSide(
                                  color: _bookingLine,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: _bookingLine,
                                ),
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
                child: Image.asset(
                  AppAssets.offersBanner,
                  width: double.infinity,
                  height: 126,
                  fit: BoxFit.cover,
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
                                  color: _offersTab == tab
                                      ? Colors.white
                                      : _ink,
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
                      _offerCategoryChip(
                        'Facial',
                        Icons.face_retouching_natural,
                      ),
                      _offerCategoryChip('Hair Care', Icons.face_3_outlined),
                      _offerCategoryChip('Makeup', Icons.brush_outlined),
                      _offerCategoryChip(
                        'Waxing',
                        Icons.auto_fix_high_outlined,
                      ),
                      _offerCategoryChip('Manicure', Icons.back_hand_outlined),
                      _offerCategoryChip('Spa', Icons.spa_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final offer in visibleOffers) _offerPromotionTile(offer),
                for (final service in discountedServices)
                  _offerServiceTile(service),
                if (visibleOffers.isEmpty && discountedServices.isEmpty)
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
                if (_packagesData.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No packages are available right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                for (final package in _packagesData) _offerPackageTile(package),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _offerMatchesCategory(_Service service) {
    if (_offersCategory == 'All') return true;
    final category = service.category.toLowerCase();
    return switch (_offersCategory) {
      'Hair Care' => category.contains('hair') || category.contains('mehendi'),
      'Spa' =>
        category.contains('spa') ||
            category.contains('polish') ||
            category.contains('clean'),
      'Manicure' => category.contains('manicure') || category.contains('nail'),
      _ => category.contains(_offersCategory.toLowerCase()),
    };
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

  Widget _offerPromotionTile(Map<String, dynamic> offer) => Container(
    key: ValueKey('offer-promotion-${offer['code'] ?? offer['name']}'),
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
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 108,
            height: 126,
            child: _catalogCover(
              offer['thumbnail'] ??
                  ((offer['images'] as List?)?.firstOrNull is Map
                      ? ((offer['images'] as List).first as Map)['url']
                      : null),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${offer['name'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${offer['description'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_offerDiscountLabel(offer)} · Code ${offer['code'] ?? ''}',
                style: const TextStyle(
                  color: _bookingBerry,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (offer['minimumOrderPaise'] != null)
                Text(
                  'Minimum spend ${CatalogService.formatPaise(BigInt.parse('${offer['minimumOrderPaise']}'))}',
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: ValueKey(
                    'offer-promotion-details-${offer['code'] ?? offer['name']}',
                  ),
                  onPressed: () => _showOfferDetails(offer),
                  style: TextButton.styleFrom(
                    foregroundColor: _bookingPink,
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showOfferDetails(Map<String, dynamic> offer) {
    final minimumOrderPaise = num.tryParse(
      '${offer['minimumOrderPaise'] ?? ''}',
    );
    final endsAt = DateTime.tryParse('${offer['endsAt'] ?? ''}');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${offer['name'] ?? 'Offer details'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${offer['description'] ?? ''}'),
              const SizedBox(height: 12),
              Text('Discount: ${_offerDiscountLabel(offer)}'),
              Text('Code: ${offer['code'] ?? 'Not provided'}'),
              if (minimumOrderPaise != null)
                Text(
                  'Minimum spend: ${CatalogService.formatPaise(BigInt.from(minimumOrderPaise.toInt()))}',
                ),
              if (endsAt != null)
                Text(
                  'Valid until: ${MaterialLocalizations.of(context).formatMediumDate(endsAt.toLocal())}',
                ),
              if ('${offer['terms'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${offer['terms']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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

  Widget _offerPackageTile(Map<String, dynamic> package) {
    final components = package['components'] is List
        ? (package['components'] as List)
        : package['items'] is List
        ? (package['items'] as List)
        : const [];
    final serviceNames = [
      for (final component in components)
        if (component is Map)
          for (final service in _serviceDetails)
            if (service.backendId != null &&
                '${component['serviceId'] ?? component['service'] ?? ''}' ==
                    service.backendId)
              service.name,
    ];
    final image =
        package['thumbnail'] ??
        ((package['images'] as List?)?.firstOrNull is Map
            ? ((package['images'] as List).first as Map)['url']
            : null);
    final price = num.tryParse('${package['pricePaise'] ?? ''}') ?? 0;
    final duration = package['durationMinutes'];
    return Container(
      key: ValueKey(
        'offer-package-${package['_id'] ?? package['id'] ?? package['name']}',
      ),
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
                child: _catalogThumbnail(image),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${package['name'] ?? ''}',
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
                      serviceNames.isEmpty
                          ? '${package['description'] ?? ''}'
                          : '${serviceNames.join(' · ')} · ${package['description'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CatalogService.formatPaise(BigInt.from(price.toInt()))}'
                      '${duration == null ? '' : ' · $duration mins'}',
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
              key: ValueKey(
                'add-package-${'${package['name'] ?? ''}'.toLowerCase()}',
              ),
              onPressed: () => _addCatalogPackage(package),
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

  void _addCatalogPackage(Map<String, dynamic> package) {
    final components = package['components'] is List
        ? (package['components'] as List)
        : package['items'] is List
        ? (package['items'] as List)
        : const [];
    final services = <_Service>[];
    for (final component in components) {
      if (component is! Map) continue;
      final id = '${component['serviceId'] ?? component['service'] ?? ''}';
      for (final service in _serviceDetails) {
        if (service.backendId == id && !services.contains(service)) {
          services.add(service);
        }
      }
    }
    if (services.isEmpty) {
      _message('Package services are unavailable right now.');
      return;
    }
    if (_checkoutPreview != null || _liveBookingId != null) {
      _startNewBooking(showCategories: false);
    }
    setState(() {
      for (final service in services) {
        if (_plan.any((item) => item.id == service.id)) continue;
        _plan.add(service);
        _cartQuantities[service.id] = 1;
      }
      _tab = 1;
    });
    _message('${package['name']} services added to your cart.');
  }

  String _offerDiscountLabel(Map<String, dynamic> offer) {
    final value = int.parse('${offer['value']}');
    return offer['discountType'] == 'percentage'
        ? '$value% off'
        : '${CatalogService.formatPaise(BigInt.from(value))} off';
  }

  Widget _catalogThumbnail(dynamic value) {
    final url = value is String ? Uri.tryParse(value) : null;
    if (url == null || !url.hasAuthority) {
      return const SizedBox(
        width: 52,
        height: 52,
        child: Icon(Icons.spa_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        value as String,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.spa_outlined),
        ),
      ),
    );
  }

  Widget _catalogCover(dynamic value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || !uri.hasAuthority) {
      return const ColoredBox(
        color: Color(0xFFFFE9ED),
        child: Center(child: Icon(Icons.local_offer_outlined, color: _berry)),
      );
    }
    return Image.network(
      value as String,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFFFE9ED),
        child: Center(child: Icon(Icons.local_offer_outlined, color: _berry)),
      ),
    );
  }

  Widget _profile() => RefreshIndicator(
    onRefresh: _loadAccount,
    child: ListView(
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
              _customerAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerName.isEmpty
                          ? 'Customer account'
                          : _customerName,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_account['mobileNumber'] ?? _account['email'] ?? 'Customer account'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
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
            _bookingsData.isEmpty
                ? 'View your booking history'
                : '${_bookingsData.length} bookings',
            _openBookingHistory,
          ),
          _ProfileMenuEntry(
            Icons.local_offer_outlined,
            'Offers & Wallet',
            'View current offers and packages',
            () => setState(() => _tab = 2),
          ),
          _ProfileMenuEntry(
            Icons.card_giftcard_outlined,
            'Refer & Earn',
            'Invite friends to Hi Beauty',
            () => _showProfileInfo(
              'Refer & Earn',
              'Referral rewards are not connected in this preview.',
            ),
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
    ),
  );

  Widget _profileMenuGroup(List<_ProfileMenuEntry> entries) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: _bookingLine),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          ListTile(
            key: ValueKey('profile-menu-${entries[index].title}'),
            dense: true,
            leading: Icon(
              entries[index].icon,
              color: entries[index].color ?? _bookingBerry,
              size: 21,
            ),
            title: Text(
              entries[index].title,
              style: TextStyle(
                color: entries[index].color ?? _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              entries[index].subtitle,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 19),
            onTap: entries[index].onTap,
          ),
          if (index < entries.length - 1)
            const Divider(height: 1, indent: 48, endIndent: 12),
        ],
      ],
    ),
  );

  Widget _customerAvatar() {
    final image =
        [
          _account['profileImageUrl'],
          _account['avatarUrl'],
          _account['profileImage'],
        ].whereType<String>().firstWhere(
          (value) => Uri.tryParse(value)?.hasAuthority == true,
          orElse: () => '',
        );
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFFFFE8EF),
      backgroundImage: image.isEmpty ? null : NetworkImage(image),
      child: image.isEmpty
          ? const Icon(Icons.person_outline_rounded, color: _bookingBerry)
          : null,
    );
  }

  void _showSavedProfessionals() => _showProfileInfo(
    'Saved Professionals',
    _favoriteProfessional
        ? 'Your saved professional is available from the Professionals screen.'
        : 'You have not saved any professionals yet.',
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
              onChanged: _savingPreferences
                  ? null
                  : (value) => _saveNotificationPreferences(
                      value,
                      _profilePromotionsEnabled,
                      (fn) {
                        if (dialogContext.mounted) setDialogState(fn);
                      },
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offer updates'),
              value: _profilePromotionsEnabled,
              onChanged: _savingPreferences
                  ? null
                  : (value) => _saveNotificationPreferences(
                      _notificationsEnabled,
                      value,
                      (fn) {
                        if (dialogContext.mounted) setDialogState(fn);
                      },
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _savingPreferences
                ? null
                : () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );

  void _showProfileInfo(String title, String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
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
      await _addAddress();
    } else if (selection is _SavedAddress && mounted) {
      final address = selection;
      setState(() {
        _selectedAddressId = address.id;
        _location = address.city;
      });
      _message('${address.label} selected as your address.');
    }
  }

  void _openBookingHistory() {
    _syncCustomerHistory();
    setState(() {
      _tab = 1;
      _checkoutStep = 13;
    });
  }

  Future<void> _syncCustomerHistory() async {
    final records = await _operationsApi.getBookings();
    if (mounted) setState(() => _bookingsData = records);
  }

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
              onPressed: () async {
                final updatedName = name.trim();
                if (updatedName.isEmpty) {
                  _message('Enter your name to save your profile.');
                  return;
                }
                try {
                  await _operationsApi.updateProfile(updatedName);
                  if (!mounted || !dialogContext.mounted) return;
                  setState(() => _customerName = updatedName);
                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (mounted) _message('Unable to save profile: $error');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
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
                Image.network(
                  (heroImage?.isNotEmpty == true
                      ? heroImage!
                      : services.first.image),
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
              if ((width == null || width! >= 80) &&
                  (height == null || height! >= 80)) ...[
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
    if (Uri.tryParse(service.image)?.hasAuthority == true) {
      return Image.network(
        service.image,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
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
