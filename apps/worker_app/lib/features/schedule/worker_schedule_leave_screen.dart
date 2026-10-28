import '../../integration/worker_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home/worker_booking_data.dart';
import '../home/worker_demo_booking_store.dart';
import '../widgets/worker_design.dart';
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
  });

  final bool demoMode;
  final List<WorkerScheduleAppointment> appointments;
  final List<WorkerDashboardOrder>? orders;
  final WorkerLeaveRepository? leaveRepository;
  final WorkerOperationsApi? operationsApi;

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
      _repo = WorkerBackendLeaveRepository(
        operationsApi: widget.operationsApi,
      );
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
      (!_leaveLoading && _leaveError == null)
          ? _repo.requests
          : const [];

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

  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(12)}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: WorkerDesign.surface(radius: 17),
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
                _isBackend ? 'Submit request to salon management for approval.' : 'Saved locally as a draft. No admin is notified.',
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
                child: Text(_isBackend ? 'Submit Leave Request' : 'Save Demo Request'),
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
          content: Text(_isBackend ? '✅ Leave request submitted to salon admin for review!' : 'Draft saved locally. No admin approval requested.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save leave draft: $error')),
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
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left, color: _deep),
              ),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
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
              if (dateNumber < 1 || dateNumber > days) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_month.year, _month.month, dateNumber);
              final selected = _sameDay(date, _selected);
              final hasBooking = _appointments.any(
                (a) => _sameDay(a.day, date),
              );
              final hasLeave = _isOnLeave(date);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selected = date),
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
                        '$dateNumber',
                        style: TextStyle(
                          color: selected ? Colors.white : _deep,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _calendar(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _dateLabel(_selected),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _deep,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '${matches.length} booking${matches.length == 1 ? '' : 's'}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (matches.isEmpty)
          _card(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Text(
                  'No preview appointments on this date.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ),
          )
        else
          for (final item in matches) ...[
            _card(
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _pink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.booking.time,
                          style: const TextStyle(
                            color: _pink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.booking.service,
                          style: const TextStyle(
                            color: _deep,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item.booking.customer} · ${item.booking.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCustomerRupees(item.booking.customerPayable),
                    style: const TextStyle(
                      color: _deep,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

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
      if (_requests.isEmpty)
        _card(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _isBackend ? 'No leave requests submitted yet.' : 'No demo leave requests yet.',
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
                    fontWeight: request.status == WorkerLeaveStatus.approved ? FontWeight.w600 : FontWeight.w400,
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
    appBar: AppBar(
      title: const Text(
        'My Schedule / Leave',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
      backgroundColor: _cream,
      foregroundColor: _deep,
      surfaceTintColor: _cream,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 7, 17, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_available_outlined,
                        color: _pink,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan your week',
                            style: TextStyle(
                              color: _pink,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Appointments and time away, together.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 7),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isBackend
                        ? 'LIVE PRODUCTION · Leave requests synced with salon admin'
                        : 'DEMO PREVIEW · Changes are not sent to admin',
                    style: TextStyle(
                      color: _isBackend ? const Color(0xFF00A95C) : _muted,
                      fontSize: 9,
                      fontWeight: _isBackend ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    Expanded(
                      child: _tab(
                        'Schedule',
                        !_leaveTab,
                        () => setState(() => _leaveTab = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tab(
                        'Leave',
                        _leaveTab,
                        () => setState(() => _leaveTab = true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                  children: [if (_leaveTab) _leaveHistory() else _schedule()],
                ),
              ),
              if (_previewAllowed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 14, 9),
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
                            ? 'Saving Draft…'
                            : 'Apply for Leave · Demo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _pink,
                        side: const BorderSide(color: _pink),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tab(String label, bool selected, VoidCallback tapped) => FilledButton(
    onPressed: tapped,
    style: FilledButton.styleFrom(
      backgroundColor: selected ? _pink : const Color(0xFFF5EFF1),
      foregroundColor: selected ? Colors.white : _muted,
      elevation: 0,
      minimumSize: const Size(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Text(label),
  );
}
