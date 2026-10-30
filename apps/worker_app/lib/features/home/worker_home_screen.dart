import '../../integration/mobile_push.dart';
import 'worker_booking_details_screen.dart';
import '../schedule/worker_leave_repository.dart';

import 'dart:async';
import 'package:flutter/material.dart';

import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_operations_api.dart';
import '../../integration/worker_mobile_auth_api.dart';
import '../../integration/worker_environment.dart';
import '../login/worker_login_screen.dart';
import 'worker_dashboard_screen.dart';
import 'worker_notification_repository.dart';
import 'worker_profile_data.dart';
import 'worker_payout_data.dart';
import 'worker_incoming_booking_screen.dart';

/// Worker home and operational dashboard screen.
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({
    super.key,
    this.phoneNumber = '',
    this.demoMode = false,
    this.profileRepository,
    this.payoutRepository,
    this.notificationRepository,
    this.operationsApi,
  });

  final String phoneNumber;
  final bool demoMode;
  final WorkerProfileRepository? profileRepository;
  final WorkerPayoutRepository? payoutRepository;
  final WorkerNotificationRepository? notificationRepository;
  final WorkerOperationsApi? operationsApi;

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with WidgetsBindingObserver {
  bool _appActive = true;
  WorkerProfile? _profile;
  late String _workerPhone;
  bool _isOnline = false;
  bool _isApproved = false;
  List<WorkerDashboardOrder>? _orders;
  Timer? _bookingsTimer;
  bool _refreshingBookings = false;
  Timer? _offerTimer;
  bool _showingOffer = false;
  final Set<String> _handledOfferIds = {};
  late final WorkerOperationsApi _operationsApi;
  late final WorkerPayoutRepository _payoutRepository;
  late final WorkerLeaveRepository _leaveRepository;
  late final WorkerNotificationRepository _notificationRepository;
  WorkerProfileRepository get _repository =>
      widget.profileRepository ?? WorkerProfileStore.repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MobilePush.pendingOpen.addListener(_handlePushOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePushOpen());
    _workerPhone = widget.phoneNumber;
    _operationsApi = widget.operationsApi ?? WorkerMobileOperationsApi();
    _payoutRepository =
        widget.payoutRepository ??
        WorkerBackendPayoutRepository(
          operationsApi: _operationsApi is WorkerMobileOperationsApi
              ? _operationsApi
              : null,
        );
    _leaveRepository = WorkerBackendLeaveRepository(
      operationsApi: _operationsApi is WorkerMobileOperationsApi
          ? _operationsApi
          : null,
    );
    _notificationRepository =
        widget.notificationRepository ??
        WorkerNotificationRepository(
          operationsApi: _operationsApi is WorkerMobileOperationsApi
              ? _operationsApi
              : null,
        );
    _notificationRepository.addListener(_onNotificationsChanged);
    _notificationRepository.load();
    if (widget.profileRepository == null) {
      _repository.setOperationsApi(_operationsApi);
    }
    _repository.addListener(_profileChanged);
    _loadProfile();
    _bookingsTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true))
        _refreshBookings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && mounted) _refreshBookings();
  }

  Future<void> _handlePushOpen() async {
    final target = MobilePush.pendingOpen.value;
    if (!mounted ||
        target == null ||
        _operationsApi is! WorkerMobileOperationsApi)
      return;
    MobilePush.pendingOpen.value = null;
    final type = target['type']!;
    if (!type.startsWith('booking.') && !type.startsWith('assignment.')) {
      await _refreshBookings();
      return;
    }
    try {
      final api = _operationsApi;
      final booking = await api.fetchBookingDetails(target['entityId']!);
      if (booking == null) throw StateError('Booking unavailable');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkerBookingDetailsScreen(
            order: booking,
            demoMode: false,
            operationsApi: api,
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This booking is unavailable. Refresh your tasks or sign in again.',
            ),
          ),
        );
    }
  }

  Future<void> _refreshBookings() async {
    if (_refreshingBookings || _operationsApi is! WorkerMobileOperationsApi)
      return;
    _refreshingBookings = true;
    try {
      final orders = await _operationsApi.fetchWorkerOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      _showAccountLoadError(error);
    } finally {
      _refreshingBookings = false;
    }
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _startOfferPolling() {
    _offerTimer?.cancel();
    if (!WorkerEnvironment.legacyWorkerOffersEnabled) return;
    _offerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkIncomingOffers();
    });
  }

  void _stopOfferPolling() {
    _offerTimer?.cancel();
    _offerTimer = null;
  }

  Future<void> _checkIncomingOffers() async {
    if (!_isOnline || _showingOffer || !mounted) return;
    if (_operationsApi is! WorkerMobileOperationsApi) return;
    try {
      final offers = await _operationsApi.fetchOffers();
      _lastOfferError = null;
      if (!mounted || offers.isEmpty || _showingOffer || !_isOnline) return;

      final offer = offers.first;
      final offerId = '${offer['_id'] ?? ''}';
      if (offerId.isEmpty || _handledOfferIds.contains(offerId)) return;

      final rawExpires = offer['expiresAt'];
      final expiresAt = rawExpires != null
          ? DateTime.tryParse('$rawExpires')
          : null;
      final now = DateTime.now();
      final secondsLeft = expiresAt != null
          ? expiresAt.difference(now).inSeconds
          : 60;
      if (secondsLeft <= 0) return;

      final items = offer['items'] as List?;
      final serviceName = items != null && items.isNotEmpty
          ? items.map((i) => i['name'] ?? 'Beauty Service').join(', ')
          : 'Beauty Service';
      final durationMinutes = items != null && items.isNotEmpty
          ? items.first['durationMinutes'] ?? 60
          : 60;

      String timeSlot = 'Upcoming Slot';
      final rawStartsAt = offer['startsAt'];
      if (rawStartsAt != null) {
        final dt = DateTime.tryParse('$rawStartsAt')?.toLocal();
        if (dt != null) {
          final nowLocal = DateTime.now();
          final isToday =
              dt.year == nowLocal.year &&
              dt.month == nowLocal.month &&
              dt.day == nowLocal.day;
          final isTomorrow =
              dt.year == nowLocal.year &&
              dt.month == nowLocal.month &&
              dt.day == (nowLocal.day + 1);
          final hour = dt.hour == 0
              ? 12
              : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          final minStr = dt.minute.toString().padLeft(2, '0');
          final timeStr = '$hour:$minStr $ampm';
          timeSlot = isToday
              ? 'Today at $timeStr'
              : isTomorrow
              ? 'Tomorrow at $timeStr'
              : '${dt.day}/${dt.month}/${dt.year} at $timeStr';
        }
      }

      final serviceAreaId = '${offer['serviceAreaId'] ?? ''}';
      final serviceAreaName = offer['serviceAreaName'];
      final areaName = serviceAreaName is String && serviceAreaName.isNotEmpty
          ? serviceAreaName
          : serviceAreaId.isEmpty
          ? 'Service Area'
          : 'Service area unavailable';
      final customerPayable = offer['customerPayable'];

      final order = WorkerDashboardOrder(
        id: '${offer['bookingId'] ?? offerId}',
        customer: '${offer['customerName'] ?? 'Customer'}',
        service: serviceName,
        time: timeSlot,
        location: areaName,
        customerPayable: customerPayable is num ? customerPayable.toInt() : 0,
        status: 'Offered',
        duration: '$durationMinutes min',
      );

      _showingOffer = true;
      final result = await Navigator.of(context).push<WorkerOfferDecision>(
        MaterialPageRoute(
          builder: (_) => WorkerIncomingBookingScreen(
            order: order,
            expiresAfter: Duration(seconds: secondsLeft.clamp(5, 60)),
            isLiveOffer: true,
            distanceKm: 'Distance unavailable',
          ),
        ),
      );
      _showingOffer = false;
      _handledOfferIds.add(offerId);
      if (!mounted || result == null) return;

      if (result.type == WorkerOfferDecisionType.accepted) {
        try {
          await _operationsApi.respondToOffer(
            assignmentId: offerId,
            decision: 'accept',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Booking accepted! Added to your schedule.'),
                backgroundColor: Color(0xFF00A95C),
              ),
            );
          }
          await _loadProfile();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to accept offer: $e')),
            );
          }
        }
      } else if (result.type == WorkerOfferDecisionType.rejected) {
        try {
          await _operationsApi.respondToOffer(
            assignmentId: offerId,
            decision: 'reject',
            reason:
                result.rejection?.reason ?? 'Worker is currently unavailable',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking offer declined.')),
            );
          }
          await _loadProfile();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to decline offer: $e')),
            );
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      if (_lastOfferError != message) {
        _lastOfferError = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to check booking requests: $message')),
        );
      }
    }
  }

  String? _lastOfferError;

  Future<void> _loadProfile() async {
    try {
      if (_workerPhone.trim().isEmpty &&
          _operationsApi is WorkerMobileOperationsApi) {
        final data = await _operationsApi.fetchWorkerProfile();
        final user = data['user'];
        final mobile = user is Map ? user['mobileNumber'] : null;
        if (mobile is! String || mobile.trim().isEmpty) {
          throw const WorkerAuthException(
            'WORKER_PROFILE_INCOMPLETE',
            'The signed-in worker profile does not include a mobile number.',
          );
        }
        _workerPhone = mobile;
      }
      await _repository.load(_workerPhone);
      if (mounted)
        setState(() => _profile = _repository.profileFor(_workerPhone));
      if (_operationsApi is WorkerMobileOperationsApi) {
        try {
          final data = await _operationsApi.fetchWorkerProfile();
          final profile = data['profile'];
          if (mounted)
            setState(
              () => _isApproved =
                  profile is Map &&
                  profile['status'] == 'approved' &&
                  profile['isActive'] != false,
            );
        } catch (error) {
          _showAccountLoadError(error);
        }
      }
    } catch (error) {
      _showAccountLoadError(error);
    }

    final bool online;
    try {
      online = await _operationsApi.availability();
    } catch (error) {
      _showAccountLoadError(error);
      return;
    }
    if (!mounted) return;
    setState(() => _isOnline = online);
    if (online && WorkerEnvironment.legacyWorkerOffersEnabled) {
      _startOfferPolling();
    } else {
      _stopOfferPolling();
    }

    try {
      List<WorkerDashboardOrder>? fetched;
      if (_operationsApi is WorkerMobileOperationsApi) {
        fetched = await _operationsApi.fetchWorkerOrders();
      }
      if (mounted) {
        setState(() {
          if (fetched != null) _orders = fetched;
          _profile = _repository.profileFor(_workerPhone);
        });
      }
    } catch (error) {
      _showAccountLoadError(error);
    }
  }

  void _showAccountLoadError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to load your worker account: $error')),
    );
  }

  void _profileChanged() {
    if (!mounted) return;
    setState(() => _profile = _repository.profileFor(_workerPhone));
  }

  void _exitPreview() {
    _stopOfferPolling();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const WorkerLoginScreen(demoEnabled: false),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    MobilePush.pendingOpen.removeListener(_handlePushOpen);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.operationsApi == null &&
        _operationsApi is WorkerMobileOperationsApi) {
      _operationsApi.close();
    }
    _bookingsTimer?.cancel();
    _stopOfferPolling();
    _repository.removeListener(_profileChanged);
    _notificationRepository.removeListener(_onNotificationsChanged);
    if (widget.payoutRepository == null) {
      _payoutRepository.dispose();
    }
    _leaveRepository.dispose();
    if (widget.notificationRepository == null) {
      _notificationRepository.dispose();
    }
    super.dispose();
  }

  bool get _hasActiveOrder {
    if (_orders == null || _orders!.isEmpty) return false;
    return _orders!.any((o) {
      final s = o.status.toLowerCase().trim();
      return s == 'assigned' ||
          s == 'accepted' ||
          s == 'travelling' ||
          s == 'arrived' ||
          s == 'in_progress' ||
          s == 'active';
    });
  }

  @override
  Widget build(BuildContext context) {
    return WorkerDashboardScreen(
      demoMode: widget.demoMode,
      isApproved: _isApproved,
      initialOnline: _isOnline,
      activeService: _hasActiveOrder,
      orders: _orders,
      onAvailabilityRequested: (desired) async {
        if (!desired && _hasActiveOrder) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ You cannot go offline with an active accepted booking. Please complete or cancel the service first.',
                ),
                backgroundColor: Color(0xFFC2185B),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return true; // Keep worker online
        }
        final ok = await _operationsApi.updateAvailability(desired);
        if (mounted) {
          setState(() => _isOnline = ok);
          if (ok && WorkerEnvironment.legacyWorkerOffersEnabled) {
            _startOfferPolling();
          } else {
            _stopOfferPolling();
          }
        }
        return ok;
      },
      workerPhone: _workerPhone,
      profileRepository: _repository,
      payoutRepository: _payoutRepository,
      leaveRepository: _leaveRepository,
      notificationRepository: _notificationRepository,
      workerName: _profile?.fullName.isNotEmpty == true
          ? _profile!.fullName
          : 'Hi Beauty Partner',
      location: _profile?.cityOrArea.isNotEmpty == true
          ? _profile!.cityOrArea
          : 'Service area unavailable',
      profilePhotoPath: _profile?.profilePhotoPath,
      operationsApi: _operationsApi,
      onLogoutTap: _exitPreview,
    );
  }
}
