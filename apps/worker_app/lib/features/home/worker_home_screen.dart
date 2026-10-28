
import 'dart:async';
import 'package:flutter/material.dart';

import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_operations_api.dart';
import '../login/worker_login_screen.dart';
import 'worker_booking_data.dart';
import 'worker_dashboard_screen.dart';
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
    this.operationsApi,
  });

  final String phoneNumber;
  final bool demoMode;
  final WorkerProfileRepository? profileRepository;
  final WorkerPayoutRepository? payoutRepository;
  final WorkerOperationsApi? operationsApi;

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  WorkerProfile? _profile;
  Object? _profileError;
  bool _isOnline = false;
  List<WorkerDashboardOrder>? _orders;
  Timer? _offerTimer;
  bool _showingOffer = false;
  final Set<String> _handledOfferIds = {};
  late final WorkerOperationsApi _operationsApi;
  late final WorkerPayoutRepository _payoutRepository;
  WorkerProfileRepository get _repository =>
      widget.profileRepository ?? WorkerProfileStore.repository;

  @override
  void initState() {
    super.initState();
    _operationsApi = widget.operationsApi ?? WorkerMobileOperationsApi();
    _payoutRepository = widget.payoutRepository ??
        WorkerBackendPayoutRepository(
          operationsApi: _operationsApi is WorkerMobileOperationsApi
              ? (_operationsApi as WorkerMobileOperationsApi)
              : null,
        );
    _repository.addListener(_profileChanged);
    _loadProfile();
  }

  void _startOfferPolling() {
    _offerTimer?.cancel();
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
      final offers =
          await (_operationsApi as WorkerMobileOperationsApi).fetchOffers();
      if (!mounted || offers.isEmpty || _showingOffer || !_isOnline) return;

      final offer = offers.first;
      final offerId = '${offer['_id'] ?? ''}';
      if (offerId.isEmpty || _handledOfferIds.contains(offerId)) return;

      final rawExpires = offer['expiresAt'];
      final expiresAt =
          rawExpires != null ? DateTime.tryParse('$rawExpires') : null;
      final now = DateTime.now();
      final secondsLeft =
          expiresAt != null ? expiresAt.difference(now).inSeconds : 60;
      if (secondsLeft <= 0) return;

      final items = offer['items'] as List?;
      final serviceName =
          items != null && items.isNotEmpty
              ? items.map((i) => i['name'] ?? 'Beauty Service').join(', ')
              : 'Beauty Service';
      final durationMinutes =
          items != null && items.isNotEmpty
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
          final hour =
              dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          final minStr = dt.minute.toString().padLeft(2, '0');
          final timeStr = '$hour:$minStr $ampm';
          timeSlot =
              isToday
                  ? 'Today at $timeStr'
                  : isTomorrow
                  ? 'Tomorrow at $timeStr'
                  : '${dt.day}/${dt.month}/${dt.year} at $timeStr';
        }
      }

      final serviceAreaId = '${offer['serviceAreaId'] ?? ''}';
      final areaName =
          serviceAreaId == 'be21549eeeaf01c30ca4ec6c'
              ? 'Latur Central'
              : 'Latur Service Area';

      final order = WorkerDashboardOrder(
        id: '${offer['bookingId'] ?? offerId}',
        customer: 'Verified Customer · Hii Beauty',
        service: serviceName,
        time: timeSlot,
        location: areaName,
        customerPayable: 15600,
        status: 'Offered',
        duration: '$durationMinutes min',
      );

      _showingOffer = true;
      final result = await Navigator.of(context).push<WorkerOfferDecision>(
        MaterialPageRoute(
          builder:
              (_) => WorkerIncomingBookingScreen(
                order: order,
                expiresAfter: Duration(seconds: secondsLeft.clamp(5, 60)),
                isLiveOffer: true,
                distanceKm: '2.8 km away',
              ),
        ),
      );
      _showingOffer = false;
      _handledOfferIds.add(offerId);
      if (!mounted || result == null) return;

      if (result.type == WorkerOfferDecisionType.accepted) {
        try {
          await (_operationsApi as WorkerMobileOperationsApi).respondToOffer(
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
          await (_operationsApi as WorkerMobileOperationsApi).respondToOffer(
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
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      await _repository.load(widget.phoneNumber);
      final online = await _operationsApi.availability();
      List<WorkerDashboardOrder>? fetched;
      if (_operationsApi is WorkerMobileOperationsApi) {
        final list =
            await (_operationsApi as WorkerMobileOperationsApi)
                .fetchWorkerOrders();
        fetched = list;
      }
      if (mounted) {
        setState(() {
          _isOnline = online;
          if (fetched != null) _orders = fetched;
          _profile = _repository.profileFor(widget.phoneNumber);
          _profileError = null;
        });
        if (online) {
          _startOfferPolling();
        } else {
          _stopOfferPolling();
        }
      }
    } catch (error) {
      if (mounted) setState(() => _profileError = error);
    }
  }

  void _profileChanged() {
    if (!mounted) return;
    setState(() => _profile = _repository.profileFor(widget.phoneNumber));
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
    _stopOfferPolling();
    _repository.removeListener(_profileChanged);
    if (widget.payoutRepository == null) {
      _payoutRepository.dispose();
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
      isApproved: true,
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
          if (ok) {
            _startOfferPolling();
          } else {
            _stopOfferPolling();
          }
        }
        return ok;
      },
      workerPhone: widget.phoneNumber,
      profileRepository: _repository,
      payoutRepository: _payoutRepository,
      workerName: _profile?.fullName.isNotEmpty == true
          ? _profile!.fullName
          : 'Hi Beauty Partner',
      location: _profile?.cityOrArea.isNotEmpty == true
          ? _profile!.cityOrArea
          : 'Latur',
      profilePhotoPath: _profile?.profilePhotoPath,
      operationsApi: _operationsApi,
      onLogoutTap: _exitPreview,
    );
  }
}
