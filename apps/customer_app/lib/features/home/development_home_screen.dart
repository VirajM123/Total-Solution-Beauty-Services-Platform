import 'customer_account_screen.dart';
import '../../app/route_names.dart';
import '../shared/customer_image.dart';
import '../shared/customer_refinements.dart';
import '../booking/service_start_code.dart';
import '../booking/professional_portrait.dart';
import '../booking/assigned_professional_details.dart';
import '../../integration/mobile_push.dart';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../booking/checkout_models.dart';
import '../booking/compact_booking_widgets.dart';
import '../booking/compact_checkout_calendar.dart';
import '../booking/date_selection_screen.dart';
import '../booking/address_location_preview.dart';
import 'package:flutter/services.dart';
import '../catalog/catalog_repository.dart';
import 'all_services_screen.dart';
import 'offer_catalog_card.dart';
import 'promotional_banner_carousel.dart';
import '../shared/customer_visuals.dart';
import '../../integration/customer_mobile_operations_api.dart';

const _berry = PinkoraBrand.berry;
const _ink = PinkoraBrand.charcoal;
const _muted = PinkoraBrand.muted;
const _bookingPink = CustomerVisuals.pink;
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
    this.landmark = '',
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String postalCode;
  final String landmark;
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
  const _AddAddressDialog({required this.initialCity, this.initialAddress});
  final String initialCity;
  final _SavedAddress? initialAddress;
  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  @override
  void initState() {
    super.initState();
    final address = widget.initialAddress;
    _labelController.text = address?.label ?? 'Home';
    _streetController.text = address?.street ?? '';
    _landmarkController.text = address?.landmark ?? '';
    _cityController.text = address?.city ?? widget.initialCity;
    _postalCodeController.text = address?.postalCode ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _labelController,
      _streetController,
      _landmarkController,
      _cityController,
      _postalCodeController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SavedAddress(
        id:
            widget.initialAddress?.id ??
            'address-${DateTime.now().microsecondsSinceEpoch}',
        label: _labelController.text.trim(),
        street: _streetController.text.trim(),
        landmark: _landmarkController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        serviceAreaId: widget.initialAddress?.serviceAreaId ?? '',
      ),
    );
  }

  Widget _field(
    String label,
    String keyName,
    TextEditingController controller, {
    bool optional = false,
    bool postal = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 4),
        TextFormField(
          key: ValueKey(keyName),
          controller: controller,
          minLines: lines,
          maxLines: lines,
          maxLength: postal ? 6 : null,
          keyboardType: postal
              ? TextInputType.number
              : TextInputType.streetAddress,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          ),
          validator: (value) {
            if (optional) return null;
            if (postal)
              return RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid 6-digit PIN code';
            if (value == null || value.trim().isEmpty) return 'Enter $label';
            if (keyName == 'address-street-input' && value.trim().length < 5)
              return 'Enter a complete address';
            return null;
          },
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: CustomerVisuals.theme(Theme.of(context)).copyWith(
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: _bookingBlush,
        side: const BorderSide(color: _bookingLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(
          fontFamily: CustomerRefinements.fontFamily,
          color: _bookingPink,
          fontSize: 11,
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFFFFAFC),
      body: SafeArea(
        child: CompactBookingFrame(
          title: widget.initialAddress == null ? 'Add Address' : 'Edit Address',
          contentKey: 'address-form-content',
          decorated: true,
          onBack: () => Navigator.pop(context),
          body: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AddressLocationPreview(city: _cityController.text),
                const SizedBox(height: 10),
                const Text(
                  'Address Type',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    for (final label in ['Home', 'Work', 'Other'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: const TextStyle(fontSize: 10),
                            ),
                            selected: label == 'Other'
                                ? ![
                                    'Home',
                                    'Work',
                                  ].contains(_labelController.text)
                                : _labelController.text == label,
                            showCheckmark: false,
                            onSelected: (_) => setState(
                              () => _labelController.text = label == 'Other'
                                  ? ''
                                  : label,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!['Home', 'Work'].contains(_labelController.text))
                  _field(
                    'Address label',
                    'address-label-input',
                    _labelController,
                  ),
                _field(
                  'Full Address',
                  'address-street-input',
                  _streetController,
                  lines: 2,
                ),
                _field(
                  'Landmark (Optional)',
                  'address-landmark-input',
                  _landmarkController,
                  optional: true,
                ),
                _field('City', 'address-city-input', _cityController),
                const SizedBox(height: 8),
                const Text(
                  'State',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
                const SizedBox(height: 4),
                const InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                  ),
                  child: Text('Maharashtra', style: TextStyle(fontSize: 11)),
                ),
                _field(
                  'Pincode',
                  'address-postal-code-input',
                  _postalCodeController,
                  postal: true,
                ),
              ],
            ),
          ),
          action: FilledButton(
            key: const ValueKey('save-new-address'),
            onPressed: _save,
            child: const Text(
              'Save Address',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ),
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
  final Map<int, List<Map<String, dynamic>>> _catalogSnapshots = {};
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
  bool _loadingServiceOtp = false;
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
  DateTime? _catalogLoadedAt;
  Timer? _cartSaveTimer;
  bool _cartEdited = false;
  Future<void> _cartWrites = Future<void>.value();
  List<_Service> get _serviceDetails => _services;
  int _serviceElapsedSeconds = 0;
  final _plan = <_Service>[];
  final _cartQuantities = <String, int>{};
  final _savedAddresses = <_SavedAddress>[];

  int _tab = 0;
  final Set<int> _visitedTabs = {0};
  int _checkoutStep = 0;
  String _category = 'All Services';
  String _location = 'Select an address';
  DateTime _bookingDate = DateTime.now().add(const Duration(days: 1));
  DateTime _calendarWeekStart = DateTime(
    DateTime.now().add(const Duration(days: 1)).year,
    DateTime.now().add(const Duration(days: 1)).month,
    15,
  );
  String _bookingTime = '10:00 AM';
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
  String _bookingHistoryFilter = 'Upcoming';
  String _customerName = '';

  bool _underThousand = false;
  bool _offerApplied = false;
  String? _couponCode;
  String? _quotedOfferFingerprint;
  int _quotedDiscountPaise = 0;
  bool _applyingOffer = false;
  String _offersTab = 'Offers';
  String _offersCategory = 'All';
  String _offerSearchQuery = '';
  bool _offerSearchVisible = false;
  bool _notificationsEnabled = true;
  bool _profilePromotionsEnabled = true;
  bool _loggingOut = false;

  bool _showServiceCategories = false;
  String? _selectedServiceCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MobilePush.pendingOpen.addListener(_handlePushOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePushOpen());
    _loadNotificationPreferences();
    _initializeCustomerData();
    _loadAccount();
    _catalogRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true))
        _refreshCatalogIfStale();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive && (_cartSaveTimer?.isActive ?? false)) {
      _cartSaveTimer?.cancel();
      unawaited(_saveCartDraft());
    }
    if (_appActive && mounted) {
      _syncCustomerBackendData();
      _refreshCatalogIfStale();
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
        _showServiceCategories = false;
        _selectedServiceCategory = null;
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

  Future<void> _refreshCatalogIfStale() async {
    if (_catalogLoadedAt == null ||
        DateTime.now().difference(_catalogLoadedAt!) >=
            const Duration(minutes: 5))
      await _syncBookingCatalog();
  }

  Future<void> _initializeCustomerData() async {
    await Future.wait([_syncCustomerBackendData(), _syncBookingCatalog()]);
    if (!mounted) return;
    try {
      final preferences = await _operationsApi.getAccountData(
        'account-preferences',
      );
      if (!mounted) return;
      final selected = _savedAddresses.where(
        (a) => a.id == preferences['defaultAddressId'],
      );
      if (selected.isNotEmpty)
        setState(() {
          _selectedAddressId = selected.first.id;
          _location = selected.first.city;
        });
    } catch (_) {
      /* Existing address fallback remains usable. */
    }
    try {
      final draft = await _operationsApi.getAccountData('cart-draft');
      if (!mounted || _cartEdited || _plan.isNotEmpty) return;
      setState(() {
        for (final line in (draft['items'] as List? ?? []).whereType<Map>()) {
          final services = _services.where(
            (s) => s.backendId == line['serviceId'],
          );
          if (services.isEmpty) continue;
          final service = services.first;
          if (_plan.contains(service)) continue;
          _plan.add(service);
          _cartQuantities[service.id] =
              (int.tryParse(line['quantity'].toString()) ?? 1).clamp(1, 10);
        }
      });
    } catch (_) {
      if (mounted)
        _message(
          'Unable to restore your cart. Please retry after reconnecting.',
        );
    }
  }

  void _scheduleCartSave() {
    _cartEdited = true;
    _cartSaveTimer?.cancel();
    _cartSaveTimer = Timer(const Duration(milliseconds: 350), _saveCartDraft);
  }

  Future<void> _saveCartDraft() async {
    final lines = [
      for (final service in _plan)
        <String, dynamic>{
          'serviceId': service.backendId,
          'quantity': _cartQuantities[service.id] ?? 1,
        },
    ];
    _cartWrites = _cartWrites
        .then((_) => _operationsApi.saveCartDraft(lines))
        .catchError((Object _) {
          if (mounted)
            _message(
              'Your cart could not be saved. Please retry after reconnecting.',
            );
        });
    await _cartWrites;
  }

  Future<void> _selectDefaultAddress(_SavedAddress address) async {
    try {
      await _operationsApi.setDefaultAddress(address.id);
      if (!mounted) return;
      setState(() {
        _selectedAddressId = address.id;
        _location = address.city;
      });
    } catch (_) {
      if (mounted)
        _message('Unable to save your selected address. Please retry.');
    }
  }

  Future<void> _deleteSavedAddress(_SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(address.details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _operationsApi.deleteAddress(address.id);
      await _syncCustomerBackendData();
    } catch (_) {
      if (mounted) _message('Unable to delete address. Please retry.');
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
                landmark: '${a['line2'] ?? ''}',
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
      final failed = <int>[];
      Future<List<Map<String, dynamic>>> load(
        int index,
        Future<List<Map<String, dynamic>>> request,
      ) async {
        try {
          final records = await request;
          _catalogSnapshots[index] = records;
          return records;
        } catch (_) {
          failed.add(index);
          return _catalogSnapshots[index] ?? [];
        }
      }

      final results = await Future.wait([
        load(0, _operationsApi.getCatalogServices()),
        load(1, _operationsApi.getRecords('/api/catalog/categories')),
        load(2, _operationsApi.getRecords('/api/catalog/offers')),
        load(3, _operationsApi.getRecords('/api/catalog/packages')),
        load(4, _operationsApi.getRecords('/api/catalog/banners')),
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
          _catalogError = failed.isEmpty
              ? null
              : 'Some content could not be refreshed. Please retry.';
          if (failed.isEmpty) _catalogLoadedAt = DateTime.now();
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
    _cartSaveTimer?.cancel();
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
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            14,
            0,
            14,
            _tab == 1 && _checkoutStep != 13 ? 76 : 14,
          ),
          content: Text(message),
        ),
      );
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
              const ListTile(
                title: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (records.isEmpty)
                const ListTile(title: Text('No notifications yet.')),
              for (final record in records)
                ListTile(
                  onTap: () async {
                    try {
                      await _operationsApi.markNotificationRead(
                        (record['_id'] ?? record['id']).toString(),
                      );
                      if (mounted) _message('Notification marked as read.');
                    } catch (_) {
                      if (mounted)
                        _message(
                          'Unable to update notification. Please retry.',
                        );
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: _bookingBlush,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: _bookingPink,
                    ),
                  ),
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

  Future<void> _applyOffer(Map<String, dynamic> offer) async {
    if (_applyingOffer || _submittingPreview) return;
    if (_liveBookingId != null || _checkoutPreview != null) {
      _message('Start a new booking to use this offer.');
      return;
    }
    final code = '${offer['code'] ?? ''}'.trim();
    if (code.isEmpty) {
      _message('This promotion has no available coupon.');
      return;
    }
    setState(() {
      _couponCode = code;
      _offerApplied = false;
      _quotedOfferFingerprint = null;
      _tab = 1;
    });
    if (_plan.isEmpty || _savedAddresses.isEmpty) {
      _message(
        '$code selected. Add services and select an address to validate it.',
      );
      return;
    }
    if (await _validateSelectedOffer() && mounted) {
      _message('$code applied successfully.');
    }
  }

  Future<bool> _validateSelectedOffer() async {
    if (_applyingOffer) return false;
    final code = _couponCode;
    if (code == null) return true;
    final fingerprint = _offerFingerprint;
    setState(() => _applyingOffer = true);
    try {
      final quote = await _operationsApi.quoteCart(
        serviceAreaId: _selectedAddress.serviceAreaId,
        items: _couponItems,
        couponCode: code,
      );
      if (!mounted || fingerprint != _offerFingerprint) return false;
      setState(() {
        _quotedDiscountPaise = int.tryParse('${quote['discountPaise']}') ?? 0;
        _quotedOfferFingerprint = fingerprint;
        _offerApplied = true;
      });
      return true;
    } catch (error) {
      if (mounted && fingerprint == _offerFingerprint) {
        setState(() {
          _couponCode = null;
          _offerApplied = false;
          _quotedDiscountPaise = 0;
          _quotedOfferFingerprint = null;
        });
        _message(
          error is CustomerMobileApiException
              ? error.message
              : 'Unable to apply offer. Please try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _applyingOffer = false);
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
    _scheduleCartSave();
    _message('${service.name} added to your cart.');
  }

  void _changeQuantity(_Service service, int change) {
    final current = _cartQuantities[service.id] ?? 1;
    final updated = current + change;
    if (updated < 1) return;
    if (updated > 10) return;
    setState(() => _cartQuantities[service.id] = updated);
    _scheduleCartSave();
  }

  void _removeFromCart(_Service service) {
    setState(() {
      _plan.remove(service);
      _cartQuantities.remove(service.id);
    });
    _scheduleCartSave();
  }

  int get _cartSubtotal => _plan.fold<int>(
    0,
    (sum, item) => sum + item.price * (_cartQuantities[item.id] ?? 1),
  );

  String get _offerFingerprint => jsonEncode({
    'coupon': _couponCode,
    'address': _selectedAddressId,
    'subtotal': _cartSubtotal,
    'items': _couponItems,
  });

  List<Map<String, dynamic>> get _couponItems => [
    for (final service in _plan)
      {
        'serviceId':
            service.backendId ??
            _catalogServiceIds[service.name.trim().toLowerCase()],
        'quantity': _cartQuantities[service.id] ?? 1,
      },
  ];

  int get _cartDiscount => _quotedOfferFingerprint == _offerFingerprint
      ? (_quotedDiscountPaise / 100).round()
      : 0;

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
      _couponCode = null;
      _quotedOfferFingerprint = null;
      _quotedDiscountPaise = 0;
      _bookingDate = tomorrow;
      _calendarWeekStart = DateTime(tomorrow.year, tomorrow.month, 15);
      _bookingTime = '10:00 AM';
      _bookingPreference = 'Book Instantly';

      _pendingExtraServices = const [];
      _durationExtension = null;
      _serviceEndsAt = null;
      _liveBookingTotal = null;
    });
    _scheduleCartSave();
  }

  bool get _hasValidCheckoutSelection =>
      _plan.isNotEmpty &&
      !_bookingDate.isBefore(DateUtils.dateOnly(DateTime.now())) &&
      _bookingTime.isNotEmpty &&
      _savedAddresses.any((address) => address.id == _selectedAddressId);

  Future<void> _openBookingConfirmation() async {
    if (!_hasValidCheckoutSelection) {
      _message(
        'Review your service, date, time and address before continuing.',
      );
      return;
    }
    if (_couponCode != null && !await _validateSelectedOffer()) return;
    if (!mounted) return;
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
        _showServiceCategories = false;
        _selectedServiceCategory = null;
        _tab = 1;
        if (_checkoutStep < 6) _checkoutStep = 6;
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
      landmark: '',
      city: '',
      postalCode: '',
    ),
  );

  void _selectBookingDate(DateTime date) {
    setState(() {
      _bookingDate = DateUtils.dateOnly(date);
      _calendarWeekStart = DateTime(date.year, date.month, 15);
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

  Future<void> _addAddress([_SavedAddress? existing]) async {
    final address = await Navigator.of(context).push<_SavedAddress>(
      MaterialPageRoute(
        builder: (_) => _AddAddressDialog(
          initialCity: _savedAddresses.isEmpty
              ? 'Latur'
              : _selectedAddress.city,
          initialAddress: existing,
        ),
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
        id: existing?.id,
        label: address.label,
        line1: address.street,
        line2: address.landmark,
        city: address.city,
        postalCode: address.postalCode,
        serviceAreaId: '${matches.first['_id'] ?? matches.first['id']}',
      );
      if (!mounted) return;
      final result = _SavedAddress(
        id: '${saved['_id'] ?? saved['id']}',
        label: '${saved['label']}',
        street: '${saved['line1']}',
        landmark: '${saved['line2'] ?? ''}',
        city: '${saved['city']}',
        postalCode: '${saved['postalCode']}',
        serviceAreaId: '${saved['serviceAreaId']}',
      );
      setState(() {
        final index = _savedAddresses.indexWhere(
          (item) => item.id == result.id,
        );
        if (index < 0) {
          _savedAddresses.add(result);
        } else {
          _savedAddresses[index] = result;
        }
        _selectedAddressId = result.id;
        _location = result.city;
      });
      await _selectDefaultAddress(result);
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
          operationsApi: _operationsApi,
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
          _applyOffer(
            _offersData.firstWhere(
              (offer) => '${offer['_id'] ?? offer['id']}' == banner.targetId,
            ),
          );
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
    data: CustomerVisuals.theme(Theme.of(context)).copyWith(
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: _bookingBlush,
        side: const BorderSide(color: _bookingLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(color: _bookingPink, fontSize: 11),
      ),
    ),
    child: Scaffold(
      backgroundColor: _tab == 1 && _checkoutStep >= 3
          ? Colors.white
          : const Color(0xFFFFF9F8),
      body: CustomerCanvas(
        compact:
            !_showServiceCategories && (_tab == 1 || _tab == 2 || _tab == 3),
        child: SafeArea(
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
                        categoryImages: _categoryImages,
                        categoryStartingPrices: {
                          for (final category
                              in _serviceDetails.map((s) => s.category).toSet())
                            category: _serviceDetails
                                .where((s) => s.category == category)
                                .map((s) => s.price)
                                .reduce((a, b) => a < b ? a : b),
                        },
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
              : IndexedStack(index: _tab, children: _tabChildren()),
        ),
      ),
      bottomNavigationBar:
          _showServiceCategories || (_tab == 1 && _checkoutStep != 13)
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

  List<Widget> _tabChildren() {
    _visitedTabs.add(_tab);
    final builders = <Widget Function()>[_home, _bookings, _offers, _profile];
    return [
      for (var i = 0; i < builders.length; i++)
        _visitedTabs.contains(i) ? builders[i]() : const SizedBox.shrink(),
    ];
  }

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
                            : CustomerImage(
                                url: entry.$3!,
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
          _heading('Offers for You', () => setState(() => _tab = 2)),
          const SizedBox(height: 4),
          _offerCarousel(width),
        ],
      ],
    );
  }

  Widget _offerCarousel(double width) => PromotionalBannerCarousel(
    key: const ValueKey('footer-offer-carousel'),
    width: width,
    height: (width * 2 / 3).clamp(180.0, 240.0),
    isActive: _tab == 0 && !_showServiceCategories,
    banners: [
      for (final offer in _offersData)
        PromotionalBanner(
          id: '${offer['_id'] ?? offer['id'] ?? offer['code']}',
          title: '${offer['name'] ?? ''}',
          imageAsset: '',
        ),
    ],
    itemBuilder: (_, index) => _offerCard(_offersData[index]),
  );

  Widget _offerCard(Map<String, dynamic> offer) => InkWell(
    key: ValueKey('home-offer-${offer['_id'] ?? offer['id'] ?? offer['name']}'),
    onTap: () => _applyOffer(offer),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: _catalogCover(offer['thumbnail'], fit: BoxFit.contain),
      ),
    ),
  );

  Widget _hero(double width) => PromotionalBannerCarousel(
    key: const ValueKey('home-header-carousel'),
    banners: _banners,
    width: width,
    isActive: _tab == 0 && !_showServiceCategories,
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
                title: 'Apply Coupon Code',
                subtitle: _couponCode == null
                    ? 'View available offers'
                    : 'Selected: $_couponCode',

                onTap: () => _setOffer(!_offerApplied),
              ),
              const SizedBox(height: 9),
              _orderSummary(compact: true),
              const SizedBox(height: 10),
              _payAfterServiceNotice(),
            ],
          ],
        ),
      ),
      if (_plan.isNotEmpty) _cartFooter(),
    ],
  );

  Widget _cartHeader() => SizedBox(
    height: 48,
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('cart-back'),
          tooltip: 'Back to home',
          onPressed: () => setState(() => _tab = 0),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _bookingPink,
          ),
        ),
        const Expanded(
          child: Text(
            'Your Cart',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Clear cart',
          onPressed: _plan.isEmpty
              ? null
              : () {
                  for (final service in List<_Service>.of(_plan)) {
                    _removeFromCart(service);
                  }
                },
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: _bookingPink,
            size: 20,
          ),
        ),
      ],
    ),
  );

  Widget _cartItem(_Service service) {
    final quantity = _cartQuantities[service.id] ?? 1;
    return Container(
      key: ValueKey('cart-item-${service.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bookingLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _ServicePhoto(service: service, width: 82, height: 94),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatServicePrice(service.price * quantity)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  children: [
                    _ServiceFact(
                      Icons.schedule_outlined,
                      '${service.minutes} mins',
                    ),
                    const _ServiceFact(Icons.home_outlined, 'At Home'),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _quantityButton(
                      tooltip: 'Decrease ${service.name} quantity',
                      icon: Icons.remove_circle_outline,
                      onPressed: quantity > 1
                          ? () => _changeQuantity(service, -1)
                          : null,
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _quantityButton(
                      tooltip: 'Increase ${service.name} quantity',
                      icon: Icons.add_circle,
                      onPressed: () => _changeQuantity(service, 1),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove ${service.name}',
                      onPressed: () => _removeFromCart(service),
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: _bookingPink,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
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
        constraints: const BoxConstraints(minHeight: 44),
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
              width: 26,
              height: 26,
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
                      fontSize: 10,
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

  Widget _orderSummary({bool compact = false}) => CompactBookingPanel(
    tinted: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _summaryRow(
          'Subtotal (${_plan.fold<int>(0, (sum, s) => sum + (_cartQuantities[s.id] ?? 1))} items)',
          _cartSubtotal,
        ),
        if (_offerApplied && _quotedOfferFingerprint == _offerFingerprint)
          _summaryRow('Coupon Discount (${_couponCode ?? ''})', -_cartDiscount),
        const Divider(height: 18, color: _bookingLine),
        _paymentDetailRow(
          'Total Amount',
          '₹${_formatServicePrice(_cartTotal)}',
          emphasize: true,
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

  Widget _cartFooter() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: FilledButton(
          key: const ValueKey('proceed-to-booking'),
          onPressed: () => setState(() => _checkoutStep = 1),
          child: Text(
            'Continue  |  ₹${_formatServicePrice(_cartTotal)}  →',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
  Widget _bookingFlowScreen() {
    if (_checkoutStep >= 6) return _bookingLifecycleScreen();
    if (_checkoutStep == 5) return _bookingConfirmedScreen();
    final step = _checkoutStep - 1;
    if (step == 0) return _dateTimeStep();
    const titles = [
      'Select Date & Time',
      'Select Address',
      'Booking Summary',
      'Confirm Booking',
    ];
    return CompactBookingFrame(
      title: titles[step],
      decorated: step < 2,
      backKey: const ValueKey('checkout-back'),
      contentKey: 'checkout-step-$step',
      onBack: () => setState(() {
        if (_checkoutStep == 4) _checkoutPreview = null;
        _checkoutStep--;
      }),
      body: switch (step) {
        0 => _dateTimeStep(),
        1 => _addressStep(),
        2 => _bookingSummaryStep(),
        _ => _bookingConfirmationStep(),
      },
      action: step < 2
          ? FilledButton(
              key: const ValueKey('checkout-continue'),
              onPressed: () => setState(() => _checkoutStep++),
              child: Text(
                step == 0
                    ? 'Continue  |  ${_formatShortDate(_bookingDate)}, $_bookingTime  →'
                    : 'Continue  →',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : step == 2
          ? FilledButton(
              key: const ValueKey('continue-to-booking-confirmation'),
              onPressed: _openBookingConfirmation,
              child: Text(
                'Continue  |  ₹${_formatServicePrice(_checkoutTotal)}  →',
              ),
            )
          : FilledButton(
              key: const ValueKey('confirm-booking'),
              onPressed: _submittingPreview || _checkoutPreview != null
                  ? null
                  : _confirmPreviewBooking,
              child: Text(
                _submittingPreview
                    ? 'Creating Booking…'
                    : 'Confirm Booking  |  ₹${_formatServicePrice(_checkoutTotal)}  →',
              ),
            ),
    );
  }

  Widget _bookingConfirmedScreen() => CompactBookingFrame(
    title: 'Booking Confirmed',
    contentKey: 'booking-confirmed-content',
    onBack: _openBookingHistory,
    body: Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFFF4588), _bookingPink]),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
        ),
        const SizedBox(height: 12),
        const Text(
          'Booking Confirmed!',
          style: TextStyle(
            fontSize: 23,
            color: _bookingBerry,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your beauty session is all set.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 12),
        CompactBookingPanel(
          tinted: true,
          child: Column(
            children: [
              const Text('Booking ID', style: TextStyle(fontSize: 11)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _liveBookingId ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _bookingBerry,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy booking ID',
                    onPressed: _liveBookingId == null
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: _liveBookingId!),
                          ),
                    icon: const Icon(
                      Icons.copy_outlined,
                      color: _bookingPink,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _bookingPreviewDetailCard(),
        const SizedBox(height: 10),
        _assignedProfessionalCard(),
        const SizedBox(height: 10),
        _payAfterServiceNotice(),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _openBookingHistory,
            child: const Text('View My Bookings'),
          ),
        ),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('view-booking-progress'),
      onPressed: () => setState(() => _checkoutStep = 6),
      child: const Text('View Booking Progress  →'),
    ),
  );

  Widget _payAfterServiceNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFE5F9ED),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          color: Color(0xFF16A35E),
          size: 23,
        ),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay after service completion.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'No advance payment required.',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _compactBookingTimeline({bool flat = false}) {
    final status = _liveBookingStatus;
    final stage = _serviceCompleted
        ? 4
        : _serviceStarted
        ? 3
        : status == 'arrived'
        ? 2
        : status == 'travelling' || status == 'on_the_way'
        ? 2
        : 1;
    const labels = [
      'Booking Confirmed',
      'Professional Assigned',
      'On the Way',
      'Service in Progress',
      'Completed',
    ];
    return CompactBookingPanel(
      flat: flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < labels.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Icon(
                          i < stage
                              ? Icons.check_circle
                              : i == stage
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 15,
                          color: i <= stage
                              ? _bookingPink
                              : const Color(0xFFD7D0D6),
                        ),
                        if (i < labels.length - 1)
                          Expanded(
                            child: Container(width: 1, color: _bookingLine),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == stage
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == stage
                              ? _bookingPink
                              : i < stage
                              ? _muted
                              : const Color(0xFF8C8188),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _professionalAssignmentScreen() {
    final assigned = _checkoutStep == 7;
    if (_checkoutPreview == null)
      return const Center(child: Text('No preview booking is available.'));
    return CompactBookingFrame(
      title: assigned ? 'Professional Assigned' : 'Finding Your Expert',
      backKey: const ValueKey('professional-assignment-back'),
      contentKey: assigned
          ? 'professional-assigned-content'
          : 'professional-search-content',
      onBack: assigned
          ? _returnToProfessionalSearch
          : () => setState(() => _checkoutStep = 5),
      body: Column(
        children: [
          if (assigned) ...[
            const CompactBookingPanel(
              tinted: true,
              child: CompactBookingFact(
                icon: Icons.check_circle,
                text: 'Your professional is assigned!',
              ),
            ),
            const SizedBox(height: 8),
            _referenceProfessionalCard(),
            const SizedBox(height: 10),
            _compactBookingTimeline(flat: true),
            const SizedBox(height: 8),
            _bookingPreviewDetailCard(),
          ] else ...[
            const Text(
              'We are looking for the best beauty professional near you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 12),
            Container(
              width: MediaQuery.sizeOf(context).height < 740 ? 112 : 140,
              height: MediaQuery.sizeOf(context).height < 740 ? 112 : 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFC4D9), width: 6),
              ),
              child: ClipOval(
                child: Image.asset(
                  AppAssets.professionalSearching,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const CompactSearchProgress(),
            const SizedBox(height: 10),
            _bookingPreviewDetailCard(),
            const SizedBox(height: 10),
            const CompactBookingPanel(
              tinted: true,
              child: CompactBookingFact(
                icon: Icons.schedule,
                text:
                    'This usually takes a few minutes. We’ll notify you once an expert is assigned.',
              ),
            ),
          ],
        ],
      ),
      action: assigned
          ? FilledButton(
              key: const ValueKey('track-professional'),
              onPressed: () => setState(() => _checkoutStep = 8),
              child: const Text('Track Professional'),
            )
          : null,
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
  }) => CompactBookingFrame(
    title: title,
    onBack: onBack,
    contentKey: contentKey,
    body: Column(
      children: [
        body,
        if (_liveBookingId == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Development preview · No real booking or service activity',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ],
    ),
    action: onAction == null
        ? null
        : FilledButton(
            key: ValueKey(actionKey ?? title),
            onPressed: onAction,
            child: Text(
              actionLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
  );
  Widget _professionalTrackingScreen() => _lifecyclePage(
    title: 'On the Way',
    contentKey: 'professional-tracking-content',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height < 740 ? 104 : 124,
                width: double.infinity,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const RadialGradient(
                    radius: .72,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, .65, 1],
                  ).createShader(bounds),
                  child: Image.asset(
                    'assets/images/illustrations/customer_compact_journey.png',
                    fit: BoxFit.contain,
                    cacheWidth: 720,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                _liveBookingStatus == 'assigned'
                    ? 'Your professional is assigned'
                    : 'Your expert is on the way',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                "We'll update your booking status here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _assignedProfessionalCard(),
        const SizedBox(height: 8),
        _compactBookingTimeline(),
        const SizedBox(height: 8),
        _bookingPreviewDetailCard(),
        const SizedBox(height: 8),

        if (!_serviceStarted &&
            !_serviceCompleted &&
            _liveBookingStatus != 'arrived')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: CompactBookingFact(
              icon: Icons.lock_clock_outlined,
              text:
                  'Your start code will appear automatically when the professional marks Arrived.',
            ),
          ),
        const SizedBox(height: 8),
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
    onAction:
        !(_serviceCompleted ||
            _serviceStarted ||
            _liveBookingStatus == 'arrived')
        ? null
        : () => setState(
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
          width: MediaQuery.sizeOf(context).height < 740 ? 96 : 132,
          height: MediaQuery.sizeOf(context).height < 740 ? 96 : 132,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _bookingBlush,
          ),
          child: const Center(
            child: Icon(
              Icons.phonelink_lock_rounded,
              color: _bookingPink,
              size: 72,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Share this code when your expert arrives',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Only your assigned professional can start the service.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.3),
        ),
        const SizedBox(height: 10),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              if (_serviceOtp.isNotEmpty)
                ServiceStartCode(
                  key: const ValueKey('service-start-code'),
                  code: _serviceOtp,
                )
              else
                Text(
                  _liveBookingId == null
                      ? 'A start code is available only for live bookings.'
                      : 'The start code will appear here when the professional arrives.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _bookingPreviewDetailCard(),
      ],
    ),
    actionKey: _serviceOtp.isEmpty && _liveBookingId != null
        ? 'request-service-start-code'
        : 'service-start-code-done',
    actionLabel: _serviceOtp.isEmpty && _liveBookingId != null
        ? 'Retry Start Code'
        : 'Back to Tracking',
    onAction: _loadingServiceOtp
        ? null
        : () {
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _bookingLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extra service approval',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your worker requested additions. Approve only if you agree to the added price.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 8),
        _paymentDetailRow(
          'Existing total',
          '₹${_formatServicePrice(_liveBookingTotal ?? _checkoutPreview?.total ?? 0)}',
        ),
        const SizedBox(height: 6),
        for (final extra in _pendingExtraServices) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${extra['name'] ?? 'Extra service'}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '₹${_formatServicePrice((int.tryParse('${extra['amountPaise']}') ?? 0) ~/ 100)}',
                style: const TextStyle(
                  color: _bookingBerry,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _paymentDetailRow(
            'Total if approved',
            '₹${_formatServicePrice((_liveBookingTotal ?? _checkoutPreview?.total ?? 0) + ((int.tryParse('${extra['amountPaise']}') ?? 0) ~/ 100))}',
            emphasize: true,
          ),
          const SizedBox(height: 6),
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
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFC9DE), width: 7),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      child: Text(
                        _serviceElapsedTime,
                        key: const ValueKey('service-elapsed-time'),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elapsed time',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your beauty session',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _awaitingBookingPayment
                        ? 'Service finished'
                        : 'Service in progress',
                    style: const TextStyle(fontSize: 12, color: _bookingPink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Total: \u20b9${_formatServicePrice(_liveBookingTotal ?? _checkoutPreview?.total ?? 0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _compactBookingTimeline(),
        const SizedBox(height: 10),
        if (_liveBookingId != null && _pendingExtraServices.isNotEmpty)
          _extraServiceApprovalCard(),
        if (_liveBookingId != null && _awaitingBookingPayment)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _bookingBlush,
                        child: Icon(
                          Icons.payments_outlined,
                          color: _bookingPink,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Awaiting payment',
                          style: TextStyle(
                            color: _bookingBerry,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Final bill',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'INR ${((_finalBillPaise ?? 0) / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _bookingBerry,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Divider(height: 14, color: _bookingLine),
                  const Text(
                    'Scan the Razorpay QR shown by your worker to pay the final bill, including approved extras. Completion updates after payment is verified.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        if (_liveBookingId != null && _durationExtension != null) ...[
          const SizedBox(height: 8),
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
          width: 82,
          height: 82,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_bookingPink, _bookingBerry]),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 10),
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
          style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 10),
        _bookingPreviewDetailCard(),
        const SizedBox(height: 8),
        CompactBookingPanel(
          tinted: true,
          child: CompactBookingFact(
            icon: Icons.payments_outlined,
            text:
                'Payment: ${_serverBooking?['paymentStatus'] ?? 'pending'} · '
                '${_serverBooking?['paymentStatus'] == 'paid' ? 'Payment verified' : 'Pay using the QR shown by your professional'}',
          ),
        ),
        const SizedBox(height: 8),
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
        _assignedProfessionalCard(),
        const SizedBox(height: 8),
        _bookingPreviewDetailCard(),
        const SizedBox(height: 12),
        const Text(
          'Overall Experience',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
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
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('experience-review-text'),
          controller: _reviewController,
          minLines: 2,
          maxLines: 4,
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
          setState(() {
            _checkoutStep = 13;
            _bookingHistoryFilter = 'Completed';
          });
        }
      } catch (error) {
        if (mounted) _message('Unable to submit review: $error');
      }
    },
    onBack: () => setState(() => _checkoutStep = 11),
  );

  String? _bookingServiceImage(String name) {
    for (final service in _serviceDetails) {
      if (service.name == name) return service.image;
    }
    return null;
  }

  Widget _bookingPreviewDetailCard() {
    final preview = _checkoutPreview;
    if (preview == null) return const SizedBox.shrink();
    return CompactBookingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking details',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final service in preview.services)
            CompactBookingService(
              name: service.name,
              subtitle: 'Quantity: ${service.quantity}',
              image: _bookingServiceImage(service.name),
              amount: '₹${_formatServicePrice(service.lineTotal)}',
            ),
          const Divider(height: 12, color: _bookingLine),
          _paymentDetailRow(
            'Total',
            '₹${_formatServicePrice(_liveBookingTotal ?? preview.total)}',
            emphasize: true,
          ),
          const SizedBox(height: 4),
          CompactBookingFact(
            icon: Icons.calendar_month_outlined,
            text:
                '${_formatWeekday(preview.date)}, ${_formatShortDate(preview.date)} · ${preview.time}',
          ),
          CompactBookingFact(
            icon: Icons.location_on_outlined,
            text: '${preview.addressLabel} · ${preview.addressDetails}',
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

  String _historyGroup(Map<String, dynamic> booking) {
    final status = '${booking['status'] ?? ''}'.toLowerCase();
    if (status == 'completed') return 'Completed';
    if (status == 'cancelled' || status == 'canceled') return 'Cancelled';
    return 'Upcoming';
  }

  Widget _bookingHistoryScreen() => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'My Bookings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            for (final label in ['Upcoming', 'Completed', 'Cancelled'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    key: ValueKey('bookings-filter-$label'),
                    label: Text(
                      '$label (${_bookingsData.where((b) => _historyGroup(b) == label).length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: CustomerRefinements.fontFamily,
                      fontSize: 12,
                      color: _bookingHistoryFilter == label
                          ? Colors.white
                          : _bookingBerry,
                    ),
                    padding: EdgeInsets.zero,
                    showCheckmark: false,
                    selectedColor: _bookingPink,
                    backgroundColor: _bookingBlush,
                    selected: _bookingHistoryFilter == label,
                    onSelected: (_) =>
                        setState(() => _bookingHistoryFilter = label),
                  ),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            final records = await _operationsApi.getBookings();
            if (mounted) setState(() => _bookingsData = records);
          },
          child: ListView(
            key: const ValueKey('booking-history-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              if (_bookingsData
                  .where((b) => _historyGroup(b) == _bookingHistoryFilter)
                  .isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _bookingsData.isEmpty
                        ? 'No bookings yet.'
                        : 'No ${_bookingHistoryFilter.toLowerCase()} bookings.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final booking in _bookingsData.where(
                (b) => _historyGroup(b) == _bookingHistoryFilter,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _compactHistoryCard(booking),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _compactHistoryCard(Map<String, dynamic> booking) {
    final items = (booking['items'] as List? ?? []).whereType<Map>().toList();
    final address = booking['addressSnapshot'];
    final worker = booking['worker'];
    final workerName = worker is Map ? worker['fullName'] : null;
    final isLive = '${booking['_id'] ?? booking['id']}' == _liveBookingId;
    return CompactBookingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isNotEmpty)
                SizedBox(
                  width: 66,
                  height: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: CompactBookingThumbnail(
                      image: _bookingServiceImage('${items.first['name']}'),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items
                          .map((item) => '${item['name'] ?? 'Service'}')
                          .join(' + '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CompactBookingFact(
                      icon: Icons.calendar_month_outlined,
                      text: _bookingScheduleLabel(booking['startsAt']),
                    ),
                    if (address is Map)
                      CompactBookingFact(
                        icon: Icons.location_on_outlined,
                        text: [
                          address['label'],
                          address['city'],
                        ].where((v) => v != null && '$v'.isNotEmpty).join(', '),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  CatalogService.formatPaise(
                    BigInt.tryParse('${booking['totalPaise']}') ?? BigInt.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: _bookingPink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _bookingBlush,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${booking['status'] ?? 'Upcoming'}'.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _bookingBerry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (workerName != null)
            CompactBookingFact(
              icon: Icons.person_outline_rounded,
              text: '$workerName',
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showHistoryBookingDetails(booking),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _checkoutStep = 6;
                      _tab = 1;
                    }),
                    child: const Text(
                      'Track Now',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showHistoryBookingDetails(Map<String, dynamic> booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Booking details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final item
                    in (booking['items'] as List? ?? []).whereType<Map>())
                  CompactBookingService(
                    name: '${item['name'] ?? 'Service'}',
                    image: _bookingServiceImage('${item['name']}'),
                    subtitle: 'Quantity: ${item['quantity'] ?? 1}',
                    amount: CatalogService.formatPaise(
                      BigInt.tryParse('${item['pricePaise']}') ?? BigInt.zero,
                    ),
                  ),
                CompactBookingFact(
                  icon: Icons.calendar_month_outlined,
                  text: _bookingScheduleLabel(booking['startsAt']),
                ),
                CompactBookingFact(
                  icon: Icons.info_outline,
                  text: '${booking['status'] ?? ''}'.replaceAll('_', ' '),
                ),
                _paymentDetailRow(
                  'Total',
                  CatalogService.formatPaise(
                    BigInt.tryParse('${booking['totalPaise']}') ?? BigInt.zero,
                  ),
                  emphasize: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _bookingScheduleLabel(dynamic startsAt) {
    final date = DateTime.tryParse('$startsAt')?.toLocal();
    if (date == null) return 'Schedule unavailable';
    return '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  Widget _referenceProfessionalCard({bool compact = false}) {
    final worker = _serverBooking?['worker'];
    return AssignedProfessionalDetails(
      name: _liveWorkerName ?? 'Awaiting admin allocation',
      worker: worker is Map ? worker : const {},
      compact: compact,
      onTap: compact ? () => setState(() => _checkoutStep = 7) : null,
      onContact: () {
        final phone = worker is Map
            ? worker['mobileNumber'] ?? worker['phoneNumber'] ?? worker['phone']
            : null;
        _showProfileInfo(
          'Professional contact',
          phone == null
              ? 'Contact details are not available for this booking yet.'
              : 'Contact ${_liveWorkerName ?? 'your professional'} at $phone.',
        );
      },
    );
  }

  Widget _assignedProfessionalCard() {
    final worker = _serverBooking?['worker'];
    return CompactBookingPanel(
      tinted: true,
      child: Row(
        children: [
          ProfessionalPortrait(
            worker: worker is Map ? worker : const {},
            size: 48,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _liveWorkerName ?? 'Awaiting admin allocation',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (_liveBookingStatus ?? 'Booking status unavailable')
                      .replaceAll('_', ' '),
                  style: const TextStyle(color: _bookingBerry, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTimeStep() => DateSelectionScreen(
    address: '${_selectedAddress.label} \u00b7 ${_selectedAddress.details}',
    onAddressTap: () => setState(() => _checkoutStep = 2),
    date: _bookingDate,
    time: _bookingTime,
    preference: _bookingPreference,
    onBack: () => setState(() => _checkoutStep--),
    onContinue: () => setState(() => _checkoutStep++),
    onTimeChanged: (time) => setState(() => _bookingTime = time),
    onPreferenceChanged: (value) => setState(() => _bookingPreference = value),
    calendar: CompactCheckoutCalendar(
      dense: MediaQuery.sizeOf(context).height < 740,
      month: _calendarWeekStart.add(const Duration(days: 3)),
      selectedDate: _bookingDate,
      onSelected: _selectBookingDate,
      onPickDate: _pickBookingDate,
      onMonthChanged: (delta) => setState(() {
        final month = _calendarWeekStart.add(const Duration(days: 3));
        _calendarWeekStart = _mondayOf(
          DateTime(month.year, month.month + delta, 15),
        );
      }),
    ),
  );
  Widget _addressStep() => Column(
    key: const ValueKey('checkout-address-list'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final address in _savedAddresses) ...[
        _savedAddressCard(address),
        const SizedBox(height: 12),
      ],
      if (_savedAddresses.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Add an address to book your at-home service.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ),
      OutlinedButton.icon(
        key: const ValueKey('add-new-address'),
        onPressed: _addAddress,
        icon: const Icon(Icons.add_circle_outline, size: 22),
        label: const Text('Add New Address', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('change-service-area'),
          onPressed: _chooseLocation,
          icon: const Icon(Icons.location_on_outlined, size: 15),
          label: Text(
            'Service area · $_location',
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    ],
  );

  Widget _savedAddressCard(_SavedAddress address) {
    final selected = _selectedAddressId == address.id;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? _bookingBlush : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('saved-address-${address.id}'),
          onTap: () => _selectDefaultAddress(address),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFFFB9D0) : _bookingLine,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? _bookingPink : _muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            address.label.toLowerCase() == 'work'
                                ? Icons.work_outline
                                : Icons.home_outlined,
                            color: _bookingPink,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              address.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 28,
                            child: TextButton(
                              key: ValueKey('edit-address-${address.id}'),
                              onPressed: () => _addAddress(address),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        address.details,
                        style: const TextStyle(fontSize: 11, height: 1.4),
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
      Row(
        children: [
          Expanded(
            child: Text(
              'Services (${_plan.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _checkoutStep = 0),
            child: const Text('Edit', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
      for (final service in _plan)
        CompactBookingService(
          name: service.name,
          image: service.image,
          subtitle:
              '${service.minutes} mins · ${_cartQuantities[service.id] ?? 1} item(s)',
          amount:
              '₹${_formatServicePrice(service.price * (_cartQuantities[service.id] ?? 1))}',
        ),
      const SizedBox(height: 6),
      _bookingDetailLine(
        Icons.calendar_month_outlined,
        'Date & Time',
        '${MaterialLocalizations.of(context).formatFullDate(_bookingDate)}\n$_bookingTime',
        () => setState(() => _checkoutStep = 1),
      ),
      _bookingDetailLine(
        Icons.location_on_outlined,
        'Service Address',
        '${_selectedAddress.details} (${_selectedAddress.label})',
        () => setState(() => _checkoutStep = 2),
      ),
      _bookingDetailLine(
        Icons.confirmation_number_outlined,
        _couponCode == null
            ? 'Apply Coupon Code'
            : _offerApplied && _quotedOfferFingerprint == _offerFingerprint
            ? 'Coupon Applied · $_couponCode'
            : 'Coupon Selected · $_couponCode',
        _offerApplied && _quotedOfferFingerprint == _offerFingerprint
            ? 'You save ₹${_formatServicePrice(_cartDiscount)}'
            : 'View available offers',
        () => _setOffer(!_offerApplied),
      ),
      const SizedBox(height: 6),
      _orderSummary(compact: true),
      const SizedBox(height: 10),
      _payAfterServiceNotice(),
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
        if (_couponCode != null) 'couponCode': _couponCode,
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
        couponCode: _couponCode,
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
      _cartSaveTimer?.cancel();
      _cartEdited = false;
      _cartWrites = _cartWrites
          .then((_) => _operationsApi.clearCart())
          .catchError((Object _) {
            if (mounted)
              _message(
                'Booking confirmed. Your saved cart could not be cleared.',
              );
          });
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
        if (status == 'arrived') {
          if (_serviceOtp.isEmpty) _revealLiveServiceOtp(bookingId);
          if (_checkoutStep < 9) setState(() => _checkoutStep = 9);
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
    if (_loadingServiceOtp || _liveBookingStatus != 'arrived') return;
    _loadingServiceOtp = true;
    try {
      final otp = await _operationsApi.revealServiceOtp(bookingId);
      if (mounted &&
          _liveBookingId == bookingId &&
          _liveBookingStatus == 'arrived' &&
          otp.isNotEmpty) {
        setState(() {
          _serviceOtp = otp;
        });
      }
    } catch (e) {
      debugPrint('[CustomerApp] revealServiceOtp error: $e');
      if (mounted) _message('Could not load the service code. Please retry.');
    } finally {
      if (mounted) {
        setState(() => _loadingServiceOtp = false);
      } else {
        _loadingServiceOtp = false;
      }
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
      return Column(
        key: const ValueKey('booking-confirmation-review'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bookingSummaryStep(),
          const SizedBox(height: 8),
          const Text(
            'Your booking is confirmed only after it is saved successfully.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
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
        // A comparison price can be zero or equal to the current price.
        // Only actual discounts have the label required by the deal tile.
        .where((service) => service.discount != null)
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

    return ColoredBox(
      color: const Color(0xFFFFF7F8),
      child: RefreshIndicator(
        onRefresh: _syncBookingCatalog,
        child: _offerScrollView([
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const ValueKey('offers-back'),
                    tooltip: 'Back to Home',
                    onPressed: () => setState(() => _tab = 0),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE8EE),
                      foregroundColor: _berry,
                      fixedSize: const Size(42, 42),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 46),
                  child: Text(
                    'Offers & Packages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('toggle-offers-search'),
                    tooltip: _offerSearchVisible
                        ? 'Close search'
                        : 'Search offers',
                    onPressed: () => setState(() {
                      _offerSearchVisible = !_offerSearchVisible;
                      if (!_offerSearchVisible) _offerSearchQuery = '';
                    }),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE8EE),
                      foregroundColor: _berry,
                      fixedSize: const Size(42, 42),
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      _offerSearchVisible
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_offerSearchVisible) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('offers-search'),
              autofocus: true,
              onChanged: (value) => setState(() => _offerSearchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search offers',
                hintStyle: const TextStyle(fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 19),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (final tab in const ['Offers', 'Packages'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: tab == 'Offers' ? 5 : 0,
                      left: tab == 'Packages' ? 5 : 0,
                    ),
                    child: ChoiceChip(
                      key: ValueKey('offers-tab-$tab'),
                      label: Center(child: Text(tab)),
                      selected: _offersTab == tab,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _offersTab = tab),
                      selectedColor: _berry,
                      backgroundColor: const Color(0xFFFFE8EE),
                      side: const BorderSide(color: Color(0xFFFFDCE6)),
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: _offersTab == tab ? Colors.white : _berry,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!showPackages) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
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
            const SizedBox(height: 10),
            _offerGrid([
              for (final offer in visibleOffers) _offerPromotionTile(offer),
              for (final service in discountedServices)
                _offerServiceTile(service),
            ]),
            if (visibleOffers.isEmpty && discountedServices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _offerSearchQuery.isEmpty
                      ? 'No offers in this category yet.'
                      : 'No offers match "$_offerSearchQuery".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
          ] else ...[
            const SizedBox(height: 10),
            if (_packagesData.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No packages are available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            _offerGrid([
              for (final package in _packagesData) _offerPackageTile(package),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _offerScrollView(List<Widget> sections) => CustomScrollView(
    key: const ValueKey('offers-packages-screen'),
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        sliver: SliverMainAxisGroup(
          slivers: [
            for (final section in sections)
              if (section is SliverLayoutBuilder)
                section
              else
                SliverToBoxAdapter(child: section),
          ],
        ),
      ),
    ],
  );

  Widget _offerGrid(List<Widget> cards) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
      return SliverList.builder(
        itemCount: (cards.length / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 10),
                Expanded(
                  child: row * columns + column < cards.length
                      ? cards[row * columns + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

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

  Widget _offerCategoryChip(String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      key: ValueKey('offers-category-$label'),
      avatar: Icon(
        icon,
        size: 14,
        color: _offersCategory == label ? Colors.white : _berry,
      ),
      label: Text(label),
      selected: _offersCategory == label,
      showCheckmark: false,
      onSelected: (_) => setState(() => _offersCategory = label),
      selectedColor: _berry,
      backgroundColor: const Color(0xFFFFE8EE),
      side: const BorderSide(color: Color(0xFFFFDCE6)),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 10,
        color: _offersCategory == label ? Colors.white : _berry,
      ),
    ),
  );

  Widget _offerPromotionTile(Map<String, dynamic> offer) => OfferCatalogCard(
    key: ValueKey('offer-promotion-${offer['code'] ?? offer['name']}'),
    image: _catalogCover(
      offer['thumbnail'] ??
          ((offer['images'] as List?)?.firstOrNull is Map
              ? ((offer['images'] as List).first as Map)['url']
              : null),
    ),
    title: '${offer['name'] ?? ''}',
    description: '${offer['description'] ?? ''}',
    price: 'Code ${offer['code'] ?? ''}',
    badge: _offerDiscountLabel(offer),
    caption: offer['minimumOrderPaise'] == null
        ? null
        : 'Minimum spend ${CatalogService.formatPaise(BigInt.parse('${offer['minimumOrderPaise']}'))}',
    action: 'View Details',
    actionKey: ValueKey(
      'offer-promotion-details-${offer['code'] ?? offer['name']}',
    ),
    onPressed: () => _showOfferDetails(offer),
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
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(0, 420).toDouble(),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (Uri.tryParse('${offer['thumbnail'] ?? ''}')?.hasAuthority ==
                    true) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 130,
                      child: _catalogCover(offer['thumbnail']),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('${offer['description'] ?? ''}'),
                const SizedBox(height: 12),
                Text('Discount: ${_offerDiscountLabel(offer)}'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bookingBlush,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _bookingLine),
                  ),
                  child: Text(
                    'Code: ${offer['code'] ?? 'Not provided'}',
                    style: const TextStyle(
                      color: _bookingBerry,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _applyOffer(offer);
            },
            child: const Text('Apply Offer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _offerServiceTile(_Service service) => OfferCatalogCard(
    key: ValueKey('offer-service-deal-${service.id}'),
    image: _ServicePhoto(service: service, width: double.infinity, height: 92),
    title: service.name,
    description: service.description,
    badge: service.discount,
    price: '₹${_formatServicePrice(service.price)}',
    originalPrice: service.originalPrice == null
        ? null
        : '₹${_formatServicePrice(service.originalPrice!)}',
    caption: '${service.minutes} mins · At Home',
    action: 'View Details',
    actionKey: ValueKey('offer-details-${service.id}'),
    onPressed: () => _details(service),
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
    return OfferCatalogCard(
      key: ValueKey(
        'offer-package-${package['_id'] ?? package['id'] ?? package['name']}',
      ),
      image: _catalogCover(image),
      title: '${package['name'] ?? ''}',
      description: serviceNames.isEmpty
          ? '${package['description'] ?? ''}'
          : '${serviceNames.join(' · ')} · ${package['description'] ?? ''}',
      price: CatalogService.formatPaise(BigInt.from(price.toInt())),
      caption: duration == null ? null : '$duration mins · At Home',
      action: 'Add Package to Cart',
      actionKey: ValueKey(
        'add-package-${'${package['name'] ?? ''}'.toLowerCase()}',
      ),
      onPressed: () => _addCatalogPackage(package),
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
    _scheduleCartSave();
    _message('${package['name']} services added to your cart.');
  }

  String _offerDiscountLabel(Map<String, dynamic> offer) {
    final value = int.parse('${offer['value']}');
    return offer['discountType'] == 'percentage'
        ? '$value% off'
        : '${CatalogService.formatPaise(BigInt.from(value))} off';
  }

  Widget _catalogCover(dynamic value, {BoxFit fit = BoxFit.cover}) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || !uri.hasAuthority) {
      return const ColoredBox(
        color: Color(0xFFFFE9ED),
        child: Center(child: Icon(Icons.local_offer_outlined, color: _berry)),
      );
    }
    return CustomerImage(
      url: value as String,
      fit: fit,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'My Profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _bookingLine),
          ),
          child: Row(
            children: [
              _customerAvatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerName.isEmpty
                          ? 'Customer account'
                          : _customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_account['mobileNumber'] ?? _account['email'] ?? 'Customer account'}',
                      style: const TextStyle(color: _muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                key: const ValueKey('edit-customer-profile'),
                onPressed: _editCustomerProfile,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
            'View your saved professionals',
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
            'View current offers and wallet availability',
            _showOffersAndWallet,
          ),
          _ProfileMenuEntry(
            Icons.card_giftcard_outlined,
            'Refer & Earn',
            'Invite friends to Hi Beauty',
            () => _openAccountSection('referrals', 'Refer & Earn'),
          ),
        ]),
        const SizedBox(height: 10),
        _profileMenuGroup([
          _ProfileMenuEntry(
            Icons.support_agent_outlined,
            'Help & Support',
            'Get help with your account',
            () => _openAccountSection('support', 'Help & Support'),
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
            () => _openAccountSection('legal', 'Terms & Privacy'),
          ),
        ]),
        const SizedBox(height: 10),
        _profileMenuGroup([
          _ProfileMenuEntry(
            Icons.delete_outline,
            'Request account deletion',
            'Ask support to review deletion of your account',
            () => _openAccountSection('deletion', 'Account deletion'),
          ),
          _ProfileMenuEntry(
            Icons.logout_rounded,
            'Logout',
            'Sign out of your account',
            _logout,
            color: _bookingPink,
          ),
        ]),
        const SizedBox(height: 12),
        if (CustomerRefinements.showDevelopmentControls)
          const Center(
            child: Text(
              'Hi Beauty · Development preview',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
      ],
    ),
  );

  Widget _profileMenuGroup(List<_ProfileMenuEntry> entries) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: _bookingLine),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          ListTile(
            key: ValueKey('profile-menu-${entries[index].title}'),
            dense: true,
            visualDensity: VisualDensity.standard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minLeadingWidth: 22,
            minTileHeight: 50,
            leading: Icon(
              entries[index].icon,
              color: entries[index].color ?? _bookingBerry,
              size: 19,
            ),
            title: Text(
              entries[index].title,
              style: TextStyle(
                color: entries[index].color ?? _ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
      radius: 24,
      backgroundColor: const Color(0xFFFFE8EF),
      child: image.isEmpty
          ? const Icon(Icons.person_outline_rounded, color: _bookingBerry)
          : ClipOval(
              child: CustomerImage(
                url: image,
                width: 48,
                height: 48,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_outline_rounded,
                  color: _bookingBerry,
                ),
              ),
            ),
    );
  }

  void _openAccountSection(String section, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerAccountScreen(
          api: _operationsApi,
          section: section,
          title: title,
        ),
      ),
    );
  }

  void _showSavedProfessionals() =>
      _openAccountSection('saved-professionals', 'Saved Professionals');

  Future<void> _showOffersAndWallet() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Offers & Packages'),
              leading: const Icon(Icons.local_offer_outlined),
              onTap: () => Navigator.pop(context, 'offers'),
            ),
            ListTile(
              title: const Text('Wallet'),
              leading: const Icon(Icons.account_balance_wallet_outlined),
              onTap: () => Navigator.pop(context, 'wallet'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selection == 'offers') setState(() => _tab = 2);
    if (selection == 'wallet') _openAccountSection('wallet', 'Wallet');
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    _cartSaveTimer?.cancel();
    if (_cartEdited) await _saveCartDraft();
    try {
      await _operationsApi.logout();
    } catch (_) {
      /* The local token is always removed, even if offline. */
    }
    await MobilePush.instance?.signedOut();
    if (mounted)
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.login, (_) => false);
  }

  void _showProfileSettings() => showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Theme(
        data: CustomerRefinements.theme(Theme.of(context)),
        child: AlertDialog(
          title: const Center(child: Text('Settings')),
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                secondary: const Icon(
                  Icons.notifications_outlined,
                  color: _bookingPink,
                ),
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
                dense: true,
                secondary: const Icon(
                  Icons.local_offer_outlined,
                  color: _bookingPink,
                ),
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
    ),
  );

  void _showProfileInfo(String title, String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.info_outline_rounded,
        color: _bookingPink,
        size: 32,
      ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: _bookingBlush,
                  child: Icon(Icons.location_on_outlined, color: _bookingPink),
                ),
                title: Text(saved.label),
                subtitle: Text(saved.details),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saved.id == _selectedAddressId)
                      const Icon(Icons.check_circle, color: _bookingPink),
                    PopupMenuButton<String>(
                      onSelected: (action) =>
                          Navigator.pop(context, action + ':' + saved.id),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
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
    } else if (selection is String &&
        selection.startsWith('edit:') &&
        mounted) {
      await _addAddress(
        _savedAddresses.firstWhere((a) => a.id == selection.substring(5)),
      );
    } else if (selection is String &&
        selection.startsWith('delete:') &&
        mounted) {
      await _deleteSavedAddress(
        _savedAddresses.firstWhere((a) => a.id == selection.substring(7)),
      );
    } else if (selection is _SavedAddress && mounted) {
      final address = selection;
      await _selectDefaultAddress(address);
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
    try {
      final records = await _operationsApi.getBookings();
      if (mounted) setState(() => _bookingsData = records);
    } catch (_) {
      if (mounted) _message('Unable to load booking history. Please retry.');
    }
  }

  void _editCustomerProfile() {
    var name = _customerName;
    Uint8List? photoBytes;
    var saving = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Theme(
          data: CustomerRefinements.theme(Theme.of(context)),
          child: AlertDialog(
            title: const Center(child: Text('Edit profile')),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: photoBytes == null
                        ? _customerAvatar()
                        : CircleAvatar(
                            radius: 30,
                            backgroundImage: MemoryImage(photoBytes!),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            try {
                              final photo = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1200,
                                maxHeight: 1200,
                                imageQuality: 85,
                                requestFullMetadata: false,
                              );
                              if (photo == null) return;
                              final bytes = await photo.readAsBytes();
                              if (bytes.isEmpty ||
                                  bytes.length > 5 * 1024 * 1024) {
                                throw const FormatException(
                                  'Choose a photo smaller than 5 MB.',
                                );
                              }
                              final decoded = await decodeImageFromList(bytes);
                              decoded.dispose();
                              if (dialogContext.mounted)
                                setDialogState(() => photoBytes = bytes);
                            } catch (error) {
                              if (mounted)
                                _message('Unable to select photo: $error');
                            }
                          },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Change photo'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your name',
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const ValueKey('profile-name-input'),
                    maxLength: 120,
                    style: const TextStyle(fontSize: 14),
                    initialValue: name,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => setDialogState(() => name = value),
                    decoration: const InputDecoration(hintText: 'Your name'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('save-profile-name'),
                onPressed: saving
                    ? null
                    : () async {
                        final updatedName = name.trim();
                        if (updatedName.length < 2) {
                          _message('Enter your name to save your profile.');
                          return;
                        }
                        try {
                          setDialogState(() => saving = true);
                          final imageId = photoBytes == null
                              ? null
                              : await _operationsApi.uploadProfilePhoto(
                                  photoBytes!,
                                );
                          final updated = await _operationsApi.updateProfile(
                            updatedName,
                            profileImageId: imageId,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          setState(() {
                            _customerName = updatedName;
                            _account.addAll(
                              updated['user'] is Map
                                  ? Map<String, dynamic>.from(
                                      updated['user'] as Map,
                                    )
                                  : updated,
                            );
                          });
                          Navigator.pop(dialogContext);
                        } catch (error) {
                          if (mounted)
                            _message('Unable to save profile: $error');
                          if (dialogContext.mounted)
                            setDialogState(() => saving = false);
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
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
            height: 190,
            margin: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomerImage(
                  url: (heroImage?.isNotEmpty == true
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
    required this.operationsApi,
  });

  final List<_Service> services;
  final int initialIndex;
  final ValueChanged<_Service> onAdd;
  final CustomerMobileOperationsApi operationsApi;

  @override
  State<_ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<_ServiceDetailsScreen> {
  late final PageController _pageController;
  late int _index;
  final _favorites = <String>{};
  bool _favoriteBusy = true;

  _Service get _service => widget.services[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    try {
      final records = await widget.operationsApi.getRecords(
        '/api/mobile/customer/favorites',
      );
      if (!mounted) return;
      setState(() {
        _favorites.addAll(records.map((item) => '${item['serviceId']}'));
        _favoriteBusy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final serviceId = _service.backendId;
    if (_favoriteBusy || serviceId == null) return;
    final saved = _favorites.contains(serviceId);
    setState(() => _favoriteBusy = true);
    try {
      await widget.operationsApi.setServiceFavorite(serviceId, !saved);
      if (mounted)
        setState(() {
          if (saved) {
            _favorites.remove(serviceId);
          } else {
            _favorites.add(serviceId);
          }
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update saved service. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Widget _fact(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: _bookingPink, size: 23),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFFAFC),
    child: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * .30).clamp(
              160.0,
              240.0,
            ),
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
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    key: const ValueKey('close-service-details'),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCCFFFFFF),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Save service',
                    onPressed: _favoriteBusy || _service.backendId == null
                        ? null
                        : _toggleFavorite,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCCFFFFFF),
                    ),
                    icon: Icon(
                      _favorites.contains(_service.backendId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _bookingPink,
                      size: 21,
                    ),
                  ),
                ),
                if (_index > 0)
                  Positioned(
                    left: 4,
                    bottom: 8,
                    child: _ImagePageButton(
                      tooltip: 'Previous service',
                      icon: Icons.chevron_left,
                      onPressed: () => _showPage(_index - 1),
                    ),
                  ),
                if (_index < widget.services.length - 1)
                  Positioned(
                    right: 4,
                    bottom: 8,
                    child: _ImagePageButton(
                      tooltip: 'Next service',
                      primary: true,
                      icon: Icons.chevron_right,
                      onPressed: () => _showPage(_index + 1),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.services.length > 1)
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_index + 1} of ${widget.services.length}',
                      style: const TextStyle(fontSize: 9, color: _muted),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (
                          var index = 0;
                          index < widget.services.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: TextButton(
                              key: ValueKey(
                                'service-option-${widget.services[index].name}',
                              ),
                              onPressed: () => _showPage(index),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                foregroundColor: index == _index
                                    ? _bookingPink
                                    : _muted,
                              ),
                              child: Text(
                                widget.services[index].name,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _service.name,
                    key: const ValueKey('service-details-title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _fact(
                        Icons.payments_outlined,
                        '₹${_formatServicePrice(_service.price)}',
                        'Price',
                      ),
                      _fact(
                        Icons.schedule_outlined,
                        '${_service.minutes} mins',
                        'Duration',
                      ),
                      _fact(Icons.home_outlined, 'At Home', 'Service'),
                    ],
                  ),
                  if (_service.originalPrice != null ||
                      _service.discount != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${_service.discount ?? ''} ${_service.originalPrice == null ? '' : ' · Was ₹${_formatServicePrice(_service.originalPrice!)}'}',
                      style: const TextStyle(fontSize: 10, color: _bookingPink),
                    ),
                  ],
                  if (_service.benefits.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Benefits',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final benefit in _service.benefits)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: _bookingPink,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (_service.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Service Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _service.description,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                key: const ValueKey('add-to-cart'),
                onPressed: () => widget.onAdd(_service),
                style: FilledButton.styleFrom(
                  backgroundColor: _bookingPink,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Add to Cart  |  ₹${_formatServicePrice(_service.price)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
      return CustomerImage(
        url: service.image,
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
