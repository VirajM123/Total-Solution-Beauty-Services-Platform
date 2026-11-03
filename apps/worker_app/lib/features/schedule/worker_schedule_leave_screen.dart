import '../../integration/worker_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home/worker_booking_data.dart';
import '../home/worker_demo_booking_store.dart';
import '../widgets/worker_design.dart';
import '../widgets/worker_images.dart';
import '../widgets/worker_reference_widgets.dart';
import 'worker_leave_repository.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _cream = WorkerDesign.cream;

/// Appointment with a calendar day.
@immutable
class WorkerScheduleAppointment {
  const WorkerScheduleAppointment({required this.day, required this.booking});
  final DateTime day;
  final WorkerDashboardOrder booking;
}

@immutable
class WorkerLeavePreview {
  const WorkerLeavePreview({
    required this.from,
    required this.to,
    required this.reason,
  });
  final DateTime from;
  final DateTime to;
  final String reason;
}

/// Frontend-only schedule and leave UI. Nothing is sent to an admin or backend.
/// A future API-backed repository should provide appointments and leave state.
class WorkerScheduleLeaveScreen extends StatefulWidget {
  const WorkerScheduleLeaveScreen({
    super.key,
    this.demoMode = true,
    this.appointments = const [],
    this.orders,
    this.leaveRepository,
    this.operationsApi,
    this.location,
    this.onNotificationsTap,
    this.onNavigationSelected,
  });

  final bool demoMode;
  final List<WorkerScheduleAppointment> appointments;
  final List<WorkerDashboardOrder>? orders;
  final WorkerLeaveRepository? leaveRepository;
  final WorkerOperationsApi? operationsApi;
  final String? location;
  final VoidCallback? onNotificationsTap;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<WorkerScheduleLeaveScreen> createState() =>
      _WorkerScheduleLeaveScreenState();
}

class _WorkerScheduleLeaveScreenState extends State<WorkerScheduleLeaveScreen> {
  DateTime _selected = _day(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  bool _leaveTab = false;
  bool _leaveLoading = true;
  bool _savingLeave = false;
  Object? _leaveError;
  late final WorkerLeaveRepository _repo;
  bool _isBackend = false;

  @override
  void initState() {
    super.initState();
    if (widget.leaveRepository != null) {
      _repo = widget.leaveRepository!;
      _isBackend = _repo is WorkerBackendLeaveRepository;
    } else if (widget.operationsApi != null) {
      _repo = WorkerBackendLeaveRepository(operationsApi: widget.operationsApi);
      _isBackend = true;
    } else if (!widget.demoMode) {
      _repo = WorkerBackendLeaveRepository();
      _isBackend = true;
    } else {
      _repo = WorkerDemoLeaveStore.repository;
      _isBackend = false;
    }
    _repo.addListener(_onLeaveUpdated);
    if (widget.demoMode && !_isBackend) {
      WorkerDemoBookingStore.repository.addListener(_onLeaveUpdated);
    }
    _loadLeave();
  }

  void _onLeaveUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLeave() async {
    try {
      if (_repo is WorkerBackendLeaveRepository) {
        await _repo.initialize();
      } else if (_previewAllowed) {
        await WorkerDemoLeaveStore.initialize();
      }

      if (mounted) {
        setState(() {
          _leaveLoading = false;
          _leaveError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leaveLoading = false;
          _leaveError = e;
        });
      }
    }
  }

  Future<void> _refreshLeave() async {
    if (_leaveLoading) return;
    setState(() {
      _leaveLoading = true;
      _leaveError = null;
    });
    try {
      if (_repo is WorkerBackendLeaveRepository) {
        await _repo.refresh();
      } else if (_previewAllowed) {
        await WorkerDemoLeaveStore.initialize();
      }
      if (mounted) setState(() => _leaveLoading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _leaveLoading = false;
          _leaveError = error;
        });
      }
    }
  }

  @override
  void dispose() {
    _repo.removeListener(_onLeaveUpdated);
    if (widget.demoMode && !_isBackend) {
      WorkerDemoBookingStore.repository.removeListener(_onLeaveUpdated);
    }
    if (_isBackend && widget.leaveRepository == null) {
      _repo.dispose();
    }
    super.dispose();
  }

  List<WorkerLeaveRequest> get _requests =>
      (!_leaveLoading && _leaveError == null) ? _repo.requests : const [];

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool get _previewAllowed => kDebugMode && widget.demoMode;

  List<WorkerScheduleAppointment> get _appointments {
    if (widget.orders != null) {
      final source =
          _previewAllowed && WorkerDemoBookingStore.repository.isInitialized
          ? WorkerDemoBookingStore.resolveAll(widget.orders!)
          : widget.orders!;
      return [
        for (final order in source)
          if (order.appointmentDate != null && _isSchedulable(order.status))
            WorkerScheduleAppointment(
              day: _day(order.appointmentDate!.toLocal()),
              booking: order,
            ),
      ];
    }
    if (widget.appointments.isNotEmpty) return widget.appointments;
    if (!_previewAllowed) return const [];
    final source = WorkerDemoBookingStore.repository.isInitialized
        ? WorkerDemoBookingStore.resolveAll(
            WorkerDemoBookingStore.repository.bookings,
          )
        : WorkerDemoBookingStore.bookings;
    final dated = source.where((o) => o.appointmentDate != null).toList();
    if (dated.isNotEmpty) {
      return [
        for (final order in dated)
          WorkerScheduleAppointment(
            day: _day(order.appointmentDate!.toLocal()),
            booking: order,
          ),
      ];
    }
    return const [];
  }

  bool _isSchedulable(String status) => const {
    'accepted',
    'assigned',
    'arrived',
    'confirmed',
    'in progress',
    'in_progress',
    'ongoing',
    'scheduled',
    'service_started',
    'traveling',
    'travelling',
    'upcoming',
  }.contains(status.trim().toLowerCase());

  String _dateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';
  String _shortDateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1].substring(0, 3)} ${date.year}';
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
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
  ];

  DateTime? _appointmentDateTime(WorkerScheduleAppointment appointment) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$',
      caseSensitive: false,
    ).firstMatch(appointment.booking.time.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (minute > 59 ||
        hour > (period == null ? 23 : 12) ||
        (period != null && hour == 0)) {
      return null;
    }
    if (period != null) {
      hour %= 12;
      if (period == 'PM') hour += 12;
    }
    return DateTime(
      appointment.day.year,
      appointment.day.month,
      appointment.day.day,
      hour,
      minute,
    );
  }

  bool _isOnLeave(DateTime date) => _requests.any(
    (request) =>
        !_day(date).isBefore(_day(request.from)) &&
        !_day(date).isAfter(_day(request.to)),
  );

  Widget _card(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(12),
    bool tinted = false,
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: tinted
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFEDF4), Color(0xFFFFF8FA)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: WorkerDesign.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0DF52D7A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          )
        : WorkerDesign.surface(radius: 17),
    child: child,
  );

  Future<void> _applyForLeave() async {
    if (_leaveLoading || _leaveError != null || _savingLeave) {
      return;
    }
    DateTimeRange range = DateTimeRange(start: _selected, end: _selected);
    String reason = 'Personal';
    final result = await showModalBottomSheet<WorkerLeavePreview>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _cream,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isBackend ? 'Apply for Leave' : 'Request leave · Demo',
                style: const TextStyle(
                  color: _deep,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _isBackend
                    ? 'Submit request to salon management for approval.'
                    : 'Saved locally as a draft. No admin is notified.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  '${_dateLabel(range.start)}  →  ${_dateLabel(range.end)}',
                  maxLines: 2,
                ),
                onPressed: () async {
                  final selected = await showDateRangePicker(
                    context: sheetContext,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 2),
                    initialDateRange: range,
                  );
                  if (selected != null) update(() => range = selected);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                  DropdownMenuItem(value: 'Medical', child: Text('Medical')),
                  DropdownMenuItem(value: 'Family', child: Text('Family')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) update(() => reason = value);
                },
              ),
              const SizedBox(height: 12),
              if (_appointments.any(
                (a) =>
                    !a.day.isBefore(_day(range.start)) &&
                    !a.day.isAfter(_day(range.end)),
              ))
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Booking conflict: appointments exist within these dates. Applying for leave will not cancel or reassign them.',
                    style: TextStyle(color: Color(0xFFAD6027), fontSize: 12),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
                onPressed: () => Navigator.pop(
                  sheetContext,
                  WorkerLeavePreview(
                    from: _day(range.start),
                    to: _day(range.end),
                    reason: reason,
                  ),
                ),
                child: Text(
                  _isBackend ? 'Submit Leave Request' : 'Save Demo Request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _savingLeave = true);
    try {
      await _repo.saveDraft(
        from: result.from,
        to: result.to,
        reason: result.reason,
      );
      if (!mounted) return;
      setState(() => _leaveTab = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBackend
                ? '✅ Leave request submitted to salon admin for review!'
                : 'Draft saved locally. No admin approval requested.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit leave request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLeave = false);
    }
  }

  Widget _calendar() {
    final startOffset = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((startOffset + days + 6) ~/ 7) * 7;
    return _card(
      Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left, color: _deep),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                tooltip: 'Next month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right, color: _deep),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(color: _muted, fontSize: 10.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.08,
            ),
            itemCount: cells,
            itemBuilder: (context, index) {
              final dateNumber = index - startOffset + 1;
              final date = DateTime(_month.year, _month.month, dateNumber);
              final inMonth = date.month == _month.month;
              final selected = _sameDay(date, _selected);
              final hasBooking = _appointments.any(
                (a) => _sameDay(a.day, date),
              );
              final hasLeave = _isOnLeave(date);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _selected = date;
                  if (!inMonth) _month = DateTime(date.year, date.month);
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? _pink
                        : hasLeave
                        ? const Color(0xFFFFE9EE)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : inMonth
                              ? _deep
                              : const Color(0xFFB8B4C0),
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : hasBooking
                              ? _pink
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      tinted: true,
    );
  }

  Widget _schedule() {
    final matches =
        _appointments.where((a) => _sameDay(a.day, _selected)).toList()
          ..sort((first, second) {
            final firstTime = _appointmentDateTime(first);
            final secondTime = _appointmentDateTime(second);
            if (firstTime == null) return secondTime == null ? 0 : 1;
            if (secondTime == null) return -1;
            return firstTime.compareTo(secondTime);
          });
    final isToday = _sameDay(_selected, _day(DateTime.now()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _calendar(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                isToday ? "Today's appointments" : 'Appointments',
                style: TextStyle(
                  color: _deep,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              _shortDateLabel(_selected),
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          _card(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No appointments scheduled for this date.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ),
          )
        else
          for (final item in matches) ...[
            _card(
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.booking.time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _pink,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFC5D8),
                              width: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  WorkerServiceImage(
                    service: item.booking.service,
                    imageUrl: item.booking.serviceImageUrl,
                    serviceId: item.booking.serviceId,
                    width: 58,
                    height: 68,
                    demoMode: _previewAllowed,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.booking.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _deep,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _appointmentInfo(
                          Icons.person_outline_rounded,
                          item.booking.customer,
                        ),
                        _appointmentInfo(
                          Icons.schedule_rounded,
                          item.booking.duration,
                          trailing: item.booking.formattedCustomerPayable,
                        ),
                        _appointmentInfo(
                          Icons.location_on_outlined,
                          item.booking.location,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 21,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }

  Widget _appointmentInfo(IconData icon, String text, {String? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Text(
                trailing,
                style: const TextStyle(
                  color: _deep,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      );

  String _statusLabel(WorkerLeaveStatus status) => switch (status) {
    WorkerLeaveStatus.draft => 'Draft · Not Submitted',
    WorkerLeaveStatus.pending => 'Pending',
    WorkerLeaveStatus.approved => 'Approved',
    WorkerLeaveStatus.rejected => 'Rejected',
  };

  Widget _leaveHistory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Leave Requests',
        style: TextStyle(
          color: _deep,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      if (_leaveLoading)
        _card(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: CircularProgressIndicator(color: _pink, strokeWidth: 2),
            ),
          ),
        )
      else if (_leaveError != null)
        _card(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                const Text(
                  'Could not load leave requests.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: _refreshLeave,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        )
      else if (_requests.isEmpty)
        _card(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _isBackend
                    ? 'No leave requests submitted yet.'
                    : 'No demo leave requests yet.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ),
        )
      else
        for (final request in _requests.reversed) ...[
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.reason,
                        style: const TextStyle(
                          color: _deep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _statusLabel(request.status),
                      style: const TextStyle(color: _pink, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_dateLabel(request.from)}  →  ${_dateLabel(request.to)}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBackend
                      ? (request.status == WorkerLeaveStatus.approved
                            ? 'Approved by salon admin. Assignments paused for these dates.'
                            : request.status == WorkerLeaveStatus.rejected
                            ? 'Request was declined by salon management.'
                            : 'Pending salon admin review.')
                      : 'Local demo only. No admin action or booking reassignment occurred.',
                  style: TextStyle(
                    color: request.status == WorkerLeaveStatus.approved
                        ? const Color(0xFF00A95C)
                        : request.status == WorkerLeaveStatus.rejected
                        ? const Color(0xFFDC2626)
                        : _muted,
                    fontSize: 11,
                    fontWeight: request.status == WorkerLeaveStatus.approved
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
        ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    body: SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: _deep),
              ),
              Expanded(
                child: WorkerReferenceHeader(
                  location: widget.location,
                  onNotifications: widget.onNotificationsTap,
                  brandWidth: 165,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Schedule & Leave',
                  style: TextStyle(
                    color: _deep,
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Manage your appointments and plan your time.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                if (_previewAllowed) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'DEMO PREVIEW · Changes are not sent to admin',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: WorkerDesign.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _tab(
                      'My Schedule',
                      Icons.calendar_month_outlined,
                      !_leaveTab,
                      () => setState(() => _leaveTab = false),
                    ),
                  ),
                  Expanded(
                    child: _tab(
                      'Schedule Leave',
                      Icons.flight_outlined,
                      _leaveTab,
                      () => setState(() => _leaveTab = true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(13, 2, 13, 10),
              children: [if (_leaveTab) _leaveHistory() else _schedule()],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isBackend || _previewAllowed)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed:
                      _savingLeave || _leaveLoading || _leaveError != null
                      ? null
                      : _applyForLeave,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    _savingLeave
                        ? 'Submitting…'
                        : _previewAllowed && !_isBackend
                        ? 'Apply for Leave · Demo'
                        : 'Apply for Leave',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pink,
                    side: const BorderSide(color: _pink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          _bottomNavigation(),
        ],
      ),
    ),
  );

  Widget _tab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback tapped,
  ) => FilledButton(
    onPressed: tapped,
    style: FilledButton.styleFrom(
      backgroundColor: selected ? _pink : Colors.transparent,
      foregroundColor: selected ? Colors.white : _deep,
      elevation: selected ? 1 : 0,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _bottomNavigation() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      boxShadow: [
        BoxShadow(
          color: Color(0x0DF52D7A),
          blurRadius: 12,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: Row(
      children: [
        for (var index = 0; index < 4; index++)
          Expanded(
            child: InkWell(
              onTap: () {
                if (index == 1) return;
                final callback = widget.onNavigationSelected;
                if (callback != null) {
                  callback(index);
                } else if (index == 0) {
                  Navigator.of(context).maybePop();
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: index == 1
                      ? const Color(0xFFFFE8F2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      const [
                        Icons.home_outlined,
                        Icons.calendar_month_outlined,
                        Icons.bar_chart_rounded,
                        Icons.person_outline,
                      ][index],
                      color: index == 1 ? _pink : _muted,
                      size: 24,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      const ['Home', 'Schedule', 'Earnings', 'Profile'][index],
                      style: TextStyle(
                        fontSize: 10,
                        color: index == 1 ? _pink : _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
