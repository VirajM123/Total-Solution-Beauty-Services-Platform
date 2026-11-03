import '../widgets/worker_images.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/worker_auth_visuals.dart';
import 'worker_booking_data.dart';
import 'worker_extra_service_item.dart';
import '../../integration/worker_mobile_operations_api.dart';

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _cream = Color(0xFFFFF8FB);
const _border = Color(0xFFFFDFEB);

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategory = 'All';

  bool get _canPreview => kDebugMode && widget.demoMode;
  bool get _canManage =>
      !_loading &&
      _loadError == null &&
      (_canPreview || (!widget.demoMode && widget.operationsApi != null));

  static const _categories = ['All', 'Hair', 'Skin', 'Nails', 'Beauty'];

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
              imageUrl: service['thumbnail'] as String?,
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
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Unable to load services. Please retry.';
        });
      }
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

  void _toggleService(WorkerExtraServiceItem item) {
    if (!_canManage) return;
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  List<WorkerExtraServiceItem> get _visibleCatalog {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog
        .where((item) {
          final name = item.name.toLowerCase();
          final matchesQuery = query.isEmpty || name.contains(query);
          final matchesCategory =
              _selectedCategory == 'All' ||
              switch (_selectedCategory) {
                'Hair' =>
                  name.contains('hair') || name.contains('head massage'),
                'Skin' =>
                  name.contains('facial') ||
                      name.contains('face') ||
                      name.contains('skin') ||
                      name.contains('thread'),
                'Nails' =>
                  name.contains('nail') ||
                      name.contains('manicure') ||
                      name.contains('pedicure'),
                'Beauty' =>
                  name.contains('makeup') ||
                      name.contains('wax') ||
                      name.contains('bleach') ||
                      name.contains('beauty'),
                _ => true,
              };
          return matchesQuery && matchesCategory;
        })
        .toList(growable: false);
  }

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
    return Material(
      color: selected ? const Color(0xFFFFF5F8) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('extra-service-${item.id}'),
        onTap: !_canManage ? null : () => _toggleService(item),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _pink : const Color(0xFFFFE4ED),
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A6A2540),
                blurRadius: 9,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => WorkerServiceImage(
                    service: item.name,
                    imageUrl: item.imageUrl,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    demoMode: _canPreview,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? _pink : const Color(0xFFA8A9B7),
                          size: 21,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: _deep,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${item.durationMinutes} min',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            formatCustomerRupees(item.customerPrice),
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        leading: IconButton(
          key: const Key('extra-service-back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const WorkerAuthBrand(subtitle: 'Worker App'),
        centerTitle: false,
        backgroundColor: _cream,
        foregroundColor: _deep,
        surfaceTintColor: _cream,
        toolbarHeight: 68,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(15, 5, 15, 14),
                    children: [
                      const Text(
                        'Add Extra Service',
                        style: TextStyle(
                          color: _deep,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.55,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Enhance your client’s beauty experience',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        key: const Key('extra-service-search'),
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search services...',
                          hintStyle: const TextStyle(color: _muted),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _deep,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFF0F5),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(17),
                            borderSide: const BorderSide(color: _pink),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 7),
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final selected = category == _selectedCategory;
                            final icon = switch (category) {
                              'All' => Icons.grid_view_rounded,
                              'Hair' => Icons.face_retouching_natural_outlined,
                              'Skin' => Icons.face_3_outlined,
                              'Nails' => Icons.back_hand_outlined,
                              _ => Icons.local_florist_outlined,
                            };
                            return ChoiceChip(
                              key: Key('extra-service-category-$category'),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = category),
                              avatar: Icon(
                                icon,
                                size: 19,
                                color: selected ? _pink : _muted,
                              ),
                              label: Text(category),
                              labelStyle: TextStyle(
                                color: selected ? _pink : _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFFFFE1EB),
                              side: BorderSide(
                                color: selected ? _pink : _border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_loadError != null) ...[
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _deep),
                        ),
                        TextButton(
                          onPressed: _loadCatalog,
                          child: const Text('Retry'),
                        ),
                      ],
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(color: _pink),
                          ),
                        )
                      else if (_loadError == null && _catalog.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'No extra services are available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        )
                      else if (_loadError == null && _visibleCatalog.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'No services match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        )
                      else if (_loadError == null)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final ratio = constraints.maxWidth < 380 ? .9 : 1.1;
                            return GridView.builder(
                              key: const Key('extra-service-grid'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _visibleCatalog.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: ratio,
                                  ),
                              itemBuilder: (context, index) =>
                                  _serviceRow(_visibleCatalog[index]),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add a note (optional)',
                        style: TextStyle(
                          color: _deep,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('extra-service-note'),
                        controller: _noteController,
                        maxLength: 200,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Any special request for this service?',
                          hintStyle: const TextStyle(
                            color: Color(0xFF89839E),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF89839E),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          counterStyle: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _pink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C6A2540),
                        blurRadius: 14,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Extra total',
                                style: TextStyle(color: _muted, fontSize: 13),
                              ),
                              Text(
                                formatCustomerRupees(_extraTotal),
                                key: const Key('extra-service-total'),
                                style: const TextStyle(
                                  color: _deep,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: FilledButton.icon(
                            key: const Key('submit-extra-services'),
                            onPressed:
                                _canManage &&
                                    !_confirming &&
                                    _selectedIds.isNotEmpty
                                ? _submitExtras
                                : null,
                            icon: _confirming
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _confirming ? 'Sending...' : 'Add to Service',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFF4BDD1),
                              minimumSize: const Size(0, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
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
          ),
        ),
      ),
    );
  }
}
