import 'worker_booking_data.dart' show formatCustomerPaise;
import 'package:flutter/material.dart';

import 'worker_payout_data.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _background = WorkerDesign.cream;
const _border = WorkerDesign.border;

enum _PayoutFilter { all, paid, pending, adjusted }

class WorkerPayoutsScreen extends StatefulWidget {
  const WorkerPayoutsScreen({
    super.key,
    this.repository,
    this.onNavigationSelected,
  });

  final WorkerPayoutRepository? repository;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<WorkerPayoutsScreen> createState() => _WorkerPayoutsScreenState();
}

class _WorkerPayoutsScreenState extends State<WorkerPayoutsScreen> {
  _PayoutFilter _filter = _PayoutFilter.all;
  bool _requestLoading = false;
  Object? _requestError;

  WorkerPayoutRepository? get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _repository?.addListener(_repositoryChanged);
    if (_repository != null) {
      _refresh();
    }
  }

  @override
  void didUpdateWidget(covariant WorkerPayoutsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository == widget.repository) return;
    oldWidget.repository?.removeListener(_repositoryChanged);
    widget.repository?.addListener(_repositoryChanged);
    _requestError = null;
    if (widget.repository != null) _refresh();
  }

  @override
  void dispose() {
    _repository?.removeListener(_repositoryChanged);
    super.dispose();
  }

  void _repositoryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final repository = _repository;
    if (repository == null || _requestLoading) return;
    setState(() {
      _requestLoading = true;
      _requestError = null;
    });
    try {
      await repository.refresh();
    } catch (error) {
      _requestError = error;
    } finally {
      if (mounted) setState(() => _requestLoading = false);
    }
  }

  List<WorkerPayoutRecord> get _records {
    final records = List<WorkerPayoutRecord>.of(
      _repository?.records ?? const [],
    )..sort((a, b) => b.date.compareTo(a.date));
    if (_filter == _PayoutFilter.all) return records;
    final status = WorkerPayoutStatus.values[_filter.index - 1];
    return records.where((record) => record.status == status).toList();
  }

  List<WorkerPayoutRecord> get _allRecords =>
      _repository?.records ?? const <WorkerPayoutRecord>[];

  int get _paidTotal => _allRecords
      .where((record) => record.status == WorkerPayoutStatus.paid)
      .fold(0, (total, record) => total + record.exactAmountPaise);

  int get _paidCount => _allRecords
      .where((record) => record.status == WorkerPayoutStatus.paid)
      .length;

  DateTime? get _lastPaidDate {
    final paid =
        _allRecords
            .where((record) => record.status == WorkerPayoutStatus.paid)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return paid.isEmpty ? null : paid.first.date;
  }

  bool get _isLoading =>
      _requestLoading ||
      _repository?.loadStatus == WorkerPayoutLoadStatus.loading;

  Object? get _error =>
      _requestError ??
      (_repository?.loadStatus == WorkerPayoutLoadStatus.error
          ? _repository?.error
          : null);

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payout help'),
        content: const Text(
          'Payouts are managed by Pinkora Admin. This screen displays payout '
          'records provided by the payout service. For payment questions, '
          'please contact Pinkora Admin through your approved support channel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showDetails(WorkerPayoutRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payout details',
                style: TextStyle(
                  color: _deep,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _detailRow(
                'Payout amount',
                formatCustomerPaise(record.exactAmountPaise),
              ),
              _detailRow('Status', _statusLabel(record.status)),
              _detailRow('Payout date', _formatDate(record.date)),
              _detailRow('Services', '${record.serviceCount}'),
              _detailRow('Payout ID', record.payoutId),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    final filteredRecords = _records;
    final isConfigured = repository != null;
    final loaded = repository?.loadStatus == WorkerPayoutLoadStatus.loaded;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _deep,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'My Earnings / Payouts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Payout help',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _pink,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const WorkerPageBanner(
                      eyebrow: 'Your earnings',
                      title: 'Payouts',
                      subtitle: 'A clear view of payments from Pinkora Admin.',
                      icon: Icons.currency_rupee_rounded,
                      photo: true,
                    ),
                    const SizedBox(height: 8),
                    _adminNotice(),
                    const SizedBox(height: 8),
                    _summaryCard(isConfigured: isConfigured, loaded: loaded),
                    const SizedBox(height: 8),
                    _filters(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Payout History',
                            style: TextStyle(
                              color: _deep,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isConfigured)
                          IconButton(
                            tooltip: 'Refresh payouts',
                            onPressed: _isLoading ? null : _refresh,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.refresh, color: _pink),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      const _StateCard(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Loading payout records',
                        message: 'Your latest payout information is loading.',
                        showProgress: true,
                      )
                    else if (_error != null)
                      _StateCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load payouts',
                        message: 'Please check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      )
                    else if (!isConfigured)
                      _payoutEmptyState(
                        connected: false,
                        title: 'Your payout space is ready',
                        message:
                            'Payout records will appear here when Pinkora Admin '
                            'shares them. Customer bills are never shown as worker payouts.',
                      )
                    else if (!loaded)
                      _StateCard(
                        icon: Icons.sync_outlined,
                        title: 'Payout records are not ready',
                        message:
                            'Refresh to request the latest records from Pinkora Admin.',
                        actionLabel: 'Refresh',
                        onAction: _refresh,
                      )
                    else if (filteredRecords.isEmpty)
                      _payoutEmptyState(
                        connected: true,
                        title: _filter == _PayoutFilter.all
                            ? 'No payout records yet'
                            : 'No ${_filter.name} payouts',
                        message: _filter == _PayoutFilter.all
                            ? 'When Pinkora Admin issues a payout, the amount and payment status will show here.'
                            : 'There are no records in this payout category. Try another filter.',
                      )
                    else
                      for (final record in filteredRecords) ...[
                        _payoutCard(record),
                        const SizedBox(height: 7),
                      ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 60,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFFE2EC),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected) ? _pink : _muted,
                fontSize: 10,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: 2,
            onDestinationSelected: widget.onNavigationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: _muted),
                selectedIcon: Icon(Icons.home_rounded, color: _pink),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined, color: _muted),
                selectedIcon: Icon(Icons.calendar_today_rounded, color: _pink),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _muted,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _pink,
                ),
                label: 'Payouts',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_outlined, color: _muted),
                selectedIcon: Icon(Icons.notifications_rounded, color: _pink),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: _muted),
                selectedIcon: Icon(Icons.person_rounded, color: _pink),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDF3),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, color: _pink, size: 19),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payouts are managed by Pinkora Admin',
                style: TextStyle(
                  color: _deep,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                'For payment questions, contact Admin.',
                style: TextStyle(color: _muted, height: 1.2, fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Payout help',
          visualDensity: VisualDensity.compact,
          onPressed: _showHelp,
          icon: const Icon(Icons.chevron_right_rounded, color: _pink, size: 20),
        ),
      ],
    ),
  );

  Widget _summaryCard({required bool isConfigured, required bool loaded}) {
    final canShowTotal = isConfigured && loaded && _error == null;
    if (!isConfigured) {
      return _awaitingPayoutSummary();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: WorkerDesign.surface(radius: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: _pink, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Total Payouts (All Time)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _deep,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _SummaryStatus(
                label: canShowTotal ? '$_paidCount paid' : 'Payouts',
                active: canShowTotal,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _isLoading
                      ? 'Loading…'
                      : canShowTotal
                      ? formatCustomerPaise(_paidTotal)
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 22,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'LAST PAYOUT',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    canShowTotal && _lastPaidDate != null
                        ? _formatDate(_lastPaidDate!)
                        : canShowTotal
                        ? 'No payouts yet'
                        : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _pink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _awaitingPayoutSummary() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEAF2), Colors.white, Color(0xFFFFF6F9)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF5D5E1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0DF50070),
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
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF50070), Color(0xFFFF78A9)],
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYOUT OVERVIEW',
                    style: TextStyle(
                      color: _pink,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Waiting for payout records',
                    style: TextStyle(
                      color: _deep,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.hourglass_top_rounded, color: _pink, size: 21),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Your paid total and latest payout will appear here when Pinkora Admin shares payout data.',
          style: TextStyle(color: _muted, height: 1.25, fontSize: 10),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: _pink, size: 15),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Verified payout amounts only',
                  style: TextStyle(
                    color: _deep,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _showHelp,
                style: TextButton.styleFrom(
                  foregroundColor: _pink,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'How it works',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _payoutEmptyState({
    required bool connected,
    required String title,
    required String message,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFE5EF), Color(0xFFFFF3F7)],
            ),
          ),
          child: Icon(
            connected ? Icons.receipt_long_rounded : Icons.wallet_rounded,
            color: _pink,
            size: 23,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            connected ? 'PAYOUT HISTORY' : 'PAYOUT DATA NOT CONNECTED',
            style: const TextStyle(
              color: _pink,
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _deep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.3, fontSize: 11),
        ),
        if (!connected) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showHelp,
            icon: const Icon(Icons.info_outline, size: 17),
            label: const Text('How payouts work'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _pink,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _filters() {
    const filters = _PayoutFilter.values;
    const labels = ['All', 'Paid', 'Pending', 'Adjusted'];
    return Row(
      children: [
        for (var i = 0; i < filters.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _FilterButton(
              label: labels[i],
              selected: _filter == filters[i],
              onTap: () => setState(() => _filter = filters[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _payoutCard(WorkerPayoutRecord record) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _showDetails(record),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDF3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '${record.date.toLocal().day}',
                    style: const TextStyle(
                      color: _deep,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _monthYear(record.date.toLocal()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _deep, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatCustomerPaise(record.exactAmountPaise),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _deep,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.serviceCount} ${record.serviceCount == 1 ? 'service' : 'services'}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Payout ID: ${record.payoutId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: record.status),
                  const SizedBox(height: 5),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _pink,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 17, color: _pink),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: _deep, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SummaryStatus extends StatelessWidget {
  const _SummaryStatus({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE4F8EF) : const Color(0xFFFFF0F5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? const Color(0xFF07864B) : _pink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: selected ? _pink : Colors.white,
        foregroundColor: selected ? Colors.white : _deep,
        side: BorderSide(color: selected ? _pink : _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final WorkerPayoutStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      WorkerPayoutStatus.paid => (
        'Paid',
        const Color(0xFF07864B),
        const Color(0xFFE0F7EC),
      ),
      WorkerPayoutStatus.pending => (
        'Pending',
        const Color(0xFFAD6800),
        const Color(0xFFFFF0CE),
      ),
      WorkerPayoutStatus.adjusted => (
        'Adjusted',
        const Color(0xFF5D55A5),
        const Color(0xFFEDEBFF),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(icon, color: _pink, size: 30),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _deep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.35, fontSize: 12),
        ),
        if (showProgress) ...[
          const SizedBox(height: 14),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _pink),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

String _statusLabel(WorkerPayoutStatus status) => switch (status) {
  WorkerPayoutStatus.paid => 'Paid',
  WorkerPayoutStatus.pending => 'Pending',
  WorkerPayoutStatus.adjusted => 'Adjusted',
};

String _monthYear(DateTime date) => '${_month(date.month)} ${date.year}';

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_month(local.month)} ${local.year}';
}

String _month(int month) => const [
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
][month - 1];
