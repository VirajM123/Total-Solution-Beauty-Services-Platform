import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'worker_booking_data.dart';
import 'worker_extra_service_item.dart';
import '../../integration/worker_mobile_operations_api.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// Loads catalog extras and sends live customer approval requests.
class WorkerAddExtraServiceScreen extends StatefulWidget {
  const WorkerAddExtraServiceScreen({
    super.key,
    required this.order,
    this.initialExtras = const <WorkerExtraServiceItem>[],
    this.demoMode = false,
    this.operationsApi,
  });

  final WorkerDashboardOrder order;
  final List<WorkerExtraServiceItem> initialExtras;
  final bool demoMode;
  final WorkerMobileOperationsApi? operationsApi;

  @override
  State<WorkerAddExtraServiceScreen> createState() =>
      _WorkerAddExtraServiceScreenState();
}

class _WorkerAddExtraServiceScreenState
    extends State<WorkerAddExtraServiceScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _confirming = false;
  List<WorkerExtraServiceItem> _catalog = [];
  bool _loading = true;
  String? _loadError;

  bool get _canPreview => kDebugMode && widget.demoMode;
  bool get _canManage =>
      !_loading &&
      _loadError == null &&
      (_canPreview || (!widget.demoMode && widget.operationsApi != null));

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final List<WorkerExtraServiceItem> catalog;
      if (_canPreview) {
        catalog = previewWorkerExtraServices;
      } else {
        final services =
            await (widget.operationsApi ?? WorkerMobileOperationsApi())
                .fetchCatalogServices();
        catalog = [
          for (final service in services)
            WorkerExtraServiceItem(
              id: '${service['id'] ?? service['_id']}',
              name: '${service['name']}',
              customerPrice: ((num.parse('${service['pricePaise']}')) / 100)
                  .round(),
              durationMinutes: int.parse('${service['durationMinutes']}'),
            ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = 'Unable to load services. Please retry.';
        });
    }
    final allowed = _catalog.map((item) => item.id).toSet();
    _selectedIds.addAll(
      widget.initialExtras.map((item) => item.id).where(allowed.contains),
    );
  }

  List<WorkerExtraServiceItem> get _selected => _catalog
      .where((item) => _selectedIds.contains(item.id))
      .toList(growable: false);

  int get _extraTotal =>
      _selected.fold<int>(0, (sum, item) => sum + item.customerPrice);

  IconData _iconFor(String id) => switch (id) {
    'face-bleach' => Icons.face_retouching_natural_outlined,
    'hair-spa' => Icons.spa_outlined,
    'manicure' => Icons.back_hand_outlined,
    'pedicure' => Icons.self_improvement_outlined,
    'threading' => Icons.face_outlined,
    'head-massage' => Icons.health_and_safety_outlined,
    _ => Icons.spa_outlined,
  };

  Future<void> _submitExtras() async {
    if (!_canManage || _confirming) return;
    if (_selected.isEmpty) {
      if (_canPreview) {
        Navigator.of(context).pop(<WorkerExtraServiceItem>[]);
      } else {
        _notice(
          'Select at least one extra service to request customer approval.',
        );
      }
      return;
    }
    setState(() => _confirming = true);
    try {
      final approvalMessage = _canPreview
          ? 'This simulates approval for screen testing only. '
                'The customer has NOT actually approved or been charged.'
          : 'The customer must approve or decline each requested amount '
                'in the Customer App before you complete this service.';
      final acknowledged = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _canPreview
                ? 'Simulate customer approval?'
                : 'Request customer approval?',
          ),
          content: Text(
            'Selected extras: ${_selected.length}\n'
            'Additional customer amount: ${formatCustomerRupees(_extraTotal)}\n'
            'Customer total if approved: ${formatCustomerPaise(widget.order.exactCustomerPayablePaise + _extraTotal * 100)}\n\n'
            '$approvalMessage',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review selection'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _pink),
              child: Text(_canPreview ? 'Simulate approval' : 'Send request'),
            ),
          ],
        ),
      );
      if (!mounted || acknowledged != true) return;
      if (_canPreview) {
        Navigator.of(context).pop(_selected);
      } else {
        for (final item in _selected) {
          await widget.operationsApi!.proposeExtraService(
            bookingId: widget.order.id,
            serviceKey: item.id,
            name: item.name,
            amountPaise: item.customerPrice * 100,
            durationMinutes: item.durationMinutes,
          );
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) _notice('Could not send extra service requests: $error');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _serviceRow(WorkerExtraServiceItem item) {
    final selected = _selectedIds.contains(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFFFF0F5) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !_canManage
              ? null
              : () => setState(() {
                  selected
                      ? _selectedIds.remove(item.id)
                      : _selectedIds.add(item.id);
                }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _pink : _border),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Container(
                  height: 57,
                  width: 57,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: const Color(0xFFFFE3EC),
                  ),
                  child: Icon(_iconFor(item.id), size: 28, color: _pink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: _deep,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.durationMinutes} mins · ${formatCustomerRupees(item.customerPrice)}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: selected ? _pink : const Color(0xFFFFEAF1),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    color: selected ? Colors.white : _pink,
                    size: 23,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          'Add Extra Service',
          style: TextStyle(
            color: _deep,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(17, 7, 17, 12),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAF1),
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: _pink,
                              size: 23,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Customer approval required',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _deep,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _canPreview
                                        ? 'DEMO ONLY · Changes are local to this preview. '
                                              'No real customer approval, charge, or booking update occurs.'
                                        : 'Requests are sent to the customer for approval. '
                                              'The final bill changes only when the customer approves.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        'Booking ${widget.order.id} · ${widget.order.customer}',
                        style: const TextStyle(color: _muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: CircularProgressIndicator()),
                      if (_loadError != null) ...[
                        Text(_loadError!),
                        TextButton(
                          onPressed: _loadCatalog,
                          child: const Text('Retry'),
                        ),
                      ],
                      if (!_loading && _loadError == null && _catalog.isEmpty)
                        const Text('No extra services are available.'),
                      for (final item in _catalog) _serviceRow(item),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(17, 13, 17, 15),
                  decoration: const BoxDecoration(
                    color: _cream,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected extras: ${_selectedIds.length}',
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Added: ${formatCustomerRupees(_extraTotal)}',
                            style: const TextStyle(
                              color: _pink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_canPreview ? 'Preview customer total' : 'Customer total if approved'}: '
                        '${formatCustomerPaise(widget.order.exactCustomerPayablePaise + _extraTotal * 100)}',
                        style: const TextStyle(color: _muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _canManage && !_confirming
                            ? _submitExtras
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 49),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _selectedIds.isEmpty
                              ? (_canPreview
                                    ? 'Save empty selection'
                                    : 'Select extras')
                              : _canPreview
                              ? 'Add to Booking · Demo'
                              : 'Send to Customer',
                        ),
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
}
