import '../widgets/worker_images.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/worker_auth_visuals.dart';
import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_booking_state_repository.dart';
import 'worker_demo_booking_store.dart';
import 'worker_extra_service_item.dart';
import 'worker_add_extra_service_screen.dart';
import 'worker_finish_service_screen.dart';
import '../../app/slide_page_route.dart';

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _cream = Color(0xFFFFF8FB);

/// Development-only service-workspace preview.
/// Does not alter bookings, approve extras, or complete services remotely.
class WorkerServiceInProgressScreen extends StatefulWidget {
  const WorkerServiceInProgressScreen({
    super.key,
    required this.order,
    required this.demoStartedAt,
    this.demoMode = true,
    this.liveMode = false,
    this.bottomActions,
    this.refreshError,
    this.onRetry,
    this.serviceNotice,
  });

  final WorkerDashboardOrder order;
  final DateTime demoStartedAt;
  final bool demoMode;
  final bool liveMode;
  final Widget? bottomActions;
  final String? refreshError;
  final VoidCallback? onRetry;
  final String? serviceNotice;

  @override
  State<WorkerServiceInProgressScreen> createState() =>
      _WorkerServiceInProgressScreenState();
}

class _WorkerServiceInProgressScreenState
    extends State<WorkerServiceInProgressScreen> {
  Timer? _ticker;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  List<WorkerExtraServiceItem> _extras = const <WorkerExtraServiceItem>[];

  Future<void> _openExtraServices() async {
    if (!_previewAllowed || _busy) return;
    final updated = await Navigator.of(context)
        .push<List<WorkerExtraServiceItem>>(
          SlidePageRoute<List<WorkerExtraServiceItem>>(
            page: WorkerAddExtraServiceScreen(
              order: widget.order,
              initialExtras: _extras,
              demoMode: widget.demoMode,
            ),
          ),
        );
    if (!mounted || updated == null) return;
    setState(() => _busy = true);
    try {
      await WorkerDemoBookingStore.repository.updateExtras(
        bookingId: widget.order.id,
        extras: updated
            .map(
              (e) => WorkerExtraSnapshot(
                id: e.id,
                name: e.name,
                customerPrice: e.customerPrice,
                durationMinutes: e.durationMinutes,
              ),
            )
            .toList(growable: false),
      );
      if (mounted) {
        setState(() => _extras = List.unmodifiable(updated));
        _notice(
          'Demo extras saved locally · customer has not approved charges.',
        );
      }
    } on WorkerBookingStateException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Unable to save extra services. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFinishServicePreview() async {
    if (!_previewAllowed || _busy) return;
    final session = WorkerDemoBookingStore.session(widget.order.id);
    if (session?.serviceStage != WorkerServiceStage.inProgress) {
      _notice(
        'This service is no longer active. Reopen the booking to view its status.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerFinishServiceScreen(
          order: widget.order,
          extraServices: List.unmodifiable(_extras),
          demoStartedAt: widget.demoStartedAt,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }

  bool get _previewAllowed => kDebugMode && widget.demoMode;

  @override
  void initState() {
    super.initState();
    final saved = WorkerDemoBookingStore.session(widget.order.id);
    if (saved != null) {
      _extras = List.unmodifiable(
        saved.extras.map(
          (e) => WorkerExtraServiceItem(
            id: e.id,
            name: e.name,
            customerPrice: e.customerPrice,
            durationMinutes: e.durationMinutes,
          ),
        ),
      );
    }
    _updateElapsed();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsed(),
    );
  }

  void _updateElapsed() {
    if (!mounted) return;
    final now = DateTime.now();
    final startedAt = widget.liveMode
        ? widget.order.serviceStartedAt
        : widget.demoStartedAt;
    final difference = startedAt == null
        ? _plannedDuration -
              (widget.order.serviceEndsAt?.difference(now) ?? _plannedDuration)
        : now.difference(startedAt);
    setState(
      () => _elapsed = difference.isNegative ? Duration.zero : difference,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String get _elapsedText {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Duration get _plannedDuration {
    final matches = RegExp(
      r'(\d+)\s*(h|hr|hrs|hour|hours|min|mins|m)\b',
      caseSensitive: false,
    ).allMatches(widget.order.duration);
    var minutes = 0;
    for (final match in matches) {
      final amount = int.tryParse(match.group(1) ?? '');
      if (amount == null) continue;
      final unit = match.group(2)!.toLowerCase();
      minutes += unit.startsWith('h') ? amount * 60 : amount;
    }
    return Duration(minutes: minutes > 0 ? minutes : 60);
  }

  int get _remainingMinutes {
    final end = widget.liveMode ? widget.order.serviceEndsAt : null;
    if (end != null) {
      final remaining = end.difference(DateTime.now());
      return remaining.isNegative ? 0 : remaining.inMinutes;
    }
    final remaining = _plannedDuration - _elapsed;
    return remaining.isNegative ? 0 : remaining.inMinutes;
  }

  Duration get _displayDuration {
    final startedAt = widget.order.serviceStartedAt;
    final end = widget.order.serviceEndsAt;
    if (widget.liveMode &&
        startedAt != null &&
        end != null &&
        end.isAfter(startedAt)) {
      return end.difference(startedAt);
    }
    return _plannedDuration;
  }

  double get _elapsedProgress =>
      (_elapsed.inSeconds / _displayDuration.inSeconds).clamp(0.0, 1.0);

  String get _serviceLocation {
    final parts = widget.order.location
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    const regionNames = {
      'andhra pradesh',
      'assam',
      'bihar',
      'delhi',
      'goa',
      'gujarat',
      'karnataka',
      'kerala',
      'madhya pradesh',
      'maharashtra',
      'punjab',
      'rajasthan',
      'tamil nadu',
      'telangana',
      'uttar pradesh',
      'west bengal',
      'india',
    };
    parts.removeWhere(
      (part) =>
          RegExp(r'^\d{6}$').hasMatch(part) ||
          regionNames.contains(part.toLowerCase()),
    );
    return parts.isEmpty ? widget.order.location : parts.last;
  }

  List<_ServiceStep> get _serviceSteps {
    if (widget.order.service.toLowerCase().contains('facial')) {
      return const [
        _ServiceStep(
          Icons.cleaning_services_outlined,
          'Cleansing',
          'Cleanse skin and remove impurities',
        ),
        _ServiceStep(
          Icons.spa_outlined,
          'Scrubbing',
          'Exfoliate dead skin cells',
        ),
        _ServiceStep(
          Icons.face_retouching_natural_outlined,
          'Massage',
          'Relaxing facial massage with serum',
        ),
        _ServiceStep(
          Icons.face_3_outlined,
          'Face Pack',
          'Nourish and rejuvenate skin',
        ),
        _ServiceStep(
          Icons.water_drop_outlined,
          'Moisturizer',
          'Lock in hydration',
        ),
      ];
    }
    return [
      _ServiceStep(
        Icons.checkroom_outlined,
        'Preparation',
        'Prepare for ${widget.order.service.toLowerCase()}',
      ),
      _ServiceStep(
        Icons.spa_outlined,
        'Service',
        'Perform the requested service',
      ),
      const _ServiceStep(
        Icons.auto_awesome_outlined,
        'Finishing touches',
        'Complete the final checks',
      ),
    ];
  }

  Widget _surface(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(12),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFFFE3ED)),
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C6A2540),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(13, 6, 13, 1),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/dashboard/reference_brand.png',
                    width: 174,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 63, top: 1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF776A93),
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            _serviceLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF776A93),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF776A93),
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Help',
              onPressed: () =>
                  _notice('Help will be connected in a later step.'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF9B2E19),
                    size: 28,
                  ),
                  Positioned(
                    right: -6,
                    top: -5,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _pink,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
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
        const SizedBox(height: 5),
        Row(
          children: [
            IconButton(
              key: const Key('service-progress-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
              color: _deep,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Service In Progress',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _deep,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBookingSummary() {
    final price = widget.order.customerPayablePaise == null
        ? formatCustomerRupees(widget.order.customerPayable)
        : formatCustomerPaise(widget.order.customerPayablePaise!);
    return _surface(
      Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WorkerServiceImage(
              service: widget.order.service,
              serviceId: widget.order.serviceId,
              imageUrl: widget.order.serviceImageUrl,
              width: 94,
              height: 94,
              demoMode: widget.demoMode,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final serviceName = Text(
                      widget.order.service,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _deep,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    final status = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7FFF5),
                        border: Border.all(color: const Color(0xFF8BF0C7)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Color(0xFF0DBB78),
                            size: 8,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            constraints.maxWidth < 200
                                ? 'Running'
                                : 'Service Running',
                            style: const TextStyle(
                              color: Color(0xFF087B56),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                    return constraints.maxWidth < 200
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [serviceName, status],
                          )
                        : Row(
                            children: [
                              Expanded(child: serviceName),
                              const SizedBox(width: 4),
                              status,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 6),
                _summaryLine(
                  Icons.person_outline_rounded,
                  widget.order.customer,
                ),
                const SizedBox(height: 4),
                _summaryLine(
                  Icons.access_time_rounded,
                  widget.order.duration,
                  trailing: price,
                ),
                const SizedBox(height: 4),
                _summaryLine(
                  Icons.location_on_outlined,
                  widget.order.location,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
    );
  }

  Widget _summaryLine(
    IconData icon,
    String text, {
    String? trailing,
    int maxLines = 1,
  }) => Row(
    children: [
      Icon(icon, size: 17, color: _deep),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF716888),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 7),
        Text(
          trailing,
          style: const TextStyle(
            color: _deep,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ],
  );

  Widget _buildElapsedCard() => _surface(
    SizedBox(
      height: 178,
      child: Stack(
        children: [
          Positioned(
            right: -23,
            bottom: -34,
            width: 174,
            height: 190,
            child: IgnorePointer(
              child: Opacity(opacity: .20, child: const WorkerLotusArtwork()),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: SizedBox(
                    width: 148,
                    height: 148,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: _elapsedProgress,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0xFFD8F8EB),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF19D78B),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _elapsedText,
                              key: const Key('service-elapsed-time'),
                              style: const TextStyle(
                                color: _deep,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Time Elapsed',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                            Text(
                              '/ ${widget.order.duration}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 74, color: const Color(0xFFFFD6E4)),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated time\nremaining',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_remainingMinutes min',
                        key: const Key('service-remaining-time'),
                        style: const TextStyle(
                          color: _deep,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  );

  Widget _buildSteps() {
    final steps = _serviceSteps;
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
            child: Text(
              widget.order.service.toLowerCase().contains('facial')
                  ? 'Facial Steps'
                  : 'Service Steps',
              style: const TextStyle(
                color: _deep,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_extras.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Added extra services · Preview',
                    style: TextStyle(
                      color: _deep,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final extra in _extras)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              extra.name,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            formatCustomerRupees(extra.customerPrice),
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Preview customer payable',
                          style: TextStyle(
                            color: _deep,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        formatCustomerRupees(
                          widget.order.customerPayable +
                              _extras.fold<int>(
                                0,
                                (sum, extra) => sum + extra.customerPrice,
                              ),
                        ),
                        style: const TextStyle(
                          color: _pink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          for (var index = 0; index < steps.length; index++)
            _buildStep(steps[index], index, steps.length),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
    );
  }

  Widget _buildStep(_ServiceStep step, int index, int count) {
    final isDone = index < 2;
    final isCurrent = index == 2;
    final tone = isDone
        ? const Color(0xFF0CC982)
        : isCurrent
        ? _pink
        : const Color(0xFF9AA0B5);
    final label = isDone
        ? 'Completed'
        : isCurrent
        ? 'In Progress'
        : 'Pending';
    final background = isCurrent ? const Color(0xFFFFEDF4) : Colors.white;
    return SizedBox(
      height: 59,
      child: Row(
        children: [
          SizedBox(
            width: 33,
            height: 59,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (index < count - 1)
                  Positioned(
                    top: 23,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: isDone
                          ? const Color(0xFF45E6A3)
                          : const Color(0xFFA8A9C2),
                    ),
                  ),
                Positioned(
                  top: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? tone : Colors.white,
                      border: Border.all(color: tone, width: 2),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 15,
                          )
                        : isCurrent
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: tone,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: tone.withValues(alpha: .22),
                                    blurRadius: 5,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(step.icon, color: tone, size: 29),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _deep,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          step.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFE7FAF2)
                          : isCurrent
                          ? const Color(0xFFFFDCE9)
                          : const Color(0xFFF1F1F4),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF087B56)
                            : isCurrent
                            ? _pink
                            : _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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

  Widget _buildBottomActions() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: const Color(0xFFFFE3ED)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C6A2540),
          blurRadius: 14,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final addButton = OutlinedButton.icon(
          key: const Key('add-extra-service'),
          onPressed: _previewAllowed ? _openExtraServices : null,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text('Add Extra Service'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _pink,
            side: const BorderSide(color: _pink, width: 1.3),
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final finishButton = FilledButton.icon(
          key: const Key('finish-service'),
          onPressed: _previewAllowed ? _openFinishServicePreview : null,
          icon: const Icon(Icons.check_rounded, size: 23),
          label: const Text('Finish Service'),
          style: FilledButton.styleFrom(
            backgroundColor: _pink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFF5BED2),
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
        if (constraints.maxWidth < 350) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [addButton, const SizedBox(height: 8), finishButton],
          );
        }
        return Row(
          children: [
            Expanded(child: addButton),
            const SizedBox(width: 10),
            Expanded(child: finishButton),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    children: [
                      _buildBookingSummary(),
                      const SizedBox(height: 8),
                      _buildElapsedCard(),
                      if (widget.serviceNotice != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFE2A8)),
                          ),
                          child: Text(
                            widget.serviceNotice!,
                            style: const TextStyle(
                              color: Color(0xFF70531A),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (widget.refreshError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFCACA)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.refreshError!,
                                  style: const TextStyle(
                                    color: Color(0xFF8F2525),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (widget.onRetry != null)
                                TextButton(
                                  onPressed: widget.onRetry,
                                  child: const Text('Retry'),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildSteps(),
                    ],
                  ),
                ),
                widget.bottomActions ?? _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceStep {
  const _ServiceStep(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}
