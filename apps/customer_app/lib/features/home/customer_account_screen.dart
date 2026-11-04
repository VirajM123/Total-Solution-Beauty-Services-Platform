import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../integration/customer_mobile_operations_api.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({
    super.key,
    required this.api,
    required this.section,
    required this.title,
  });
  final CustomerMobileOperationsApi api;
  final String section, title;
  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  late Future<Map<String, dynamic>> _data;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    if (widget.section == 'deletion') return {};
    final result = await widget.api.getAccountData(widget.section);
    return result;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    await next;
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save. Please retry.')),
        );
}
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    floatingActionButton: widget.section == 'support'
        ? FloatingActionButton.extended(
            onPressed: _busy ? null : _newTicket,
            icon: const Icon(Icons.add),
            label: const Text('Get help'),
          )
        : null,
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load. Please try again.'),
                TextButton(
                  onPressed: () {
                    _refresh().catchError((_) {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        final data = snapshot.data ?? {};
        final items = (data['items'] as List? ?? []).whereType<Map>().toList();
        final children = <Widget>[];
        if (widget.section == 'saved-professionals') {
          final savedIds = items.map((e) => '${e['_id']}').toSet();
          children.addAll(
            items.map(
              (item) => ListTile(
                title: Text('${item['fullName'] ?? 'Professional'}'),
                trailing: IconButton(
                  tooltip: 'Remove saved professional',
                  icon: const Icon(Icons.favorite),
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          () => widget.api.saveProfessional(
                            '${item['_id']}',
                            false,
                          ),
                        ),
                ),
              ),
            ),
          );
          if (items.isEmpty)
            children.add(
              const ListTile(title: Text('No saved professionals yet.')),
            );
          for (final professional
              in (data['candidates'] as List? ?? []).whereType<Map>()) {
            final userId = professional['_id'].toString();
            if (savedIds.contains(userId)) continue;
            children.add(
              ListTile(
                title: Text(
                  (professional['fullName'] ?? 'Your professional').toString(),
                ),
                subtitle: const Text('Previously assigned to your booking'),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          () => widget.api.saveProfessional(userId, true),
                        ),
                  child: const Text('Save'),
                ),
              ),
            );
          }
          children.add(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Saving a professional does not change booking allocation.',
              ),
            ),
          );
        } else if (widget.section == 'support') {
          if (items.isEmpty)
            children.add(
              const ListTile(
                title: Text(
                  'No support requests yet. Tap Get help to contact support.',
                ),
              ),
            );
          children.addAll(
            items.map(
              (item) => ListTile(
                title: Text('${item['subject'] ?? 'Support request'}'),
                subtitle: Text(
                  '${item['status'] ?? 'open'} · ${item['category'] ?? 'other'}',
                ),
              ),
            ),
          );
        } else if (widget.section == 'deletion') {
          children.add(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Request account deletion. Support will review active bookings and required record retention before processing. Your account remains active until the request is processed.',
              ),
            ),
          );
          children.add(
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await widget.api.requestAccountDeletion();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account deletion request received.',
                              ),
                            ),
                          );
}
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to send request. Please retry.',
                              ),
                            ),
                          );
}
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Request account deletion'),
            ),
          );
        } else if (widget.section == 'legal') {
          for (final entry in {
            'Terms & Conditions': data['termsUrl'],
            'Privacy Policy': data['privacyUrl'],
          }.entries) {
            final url = Uri.tryParse('${entry.value ?? ''}');
            final available = url?.scheme == 'https' && url!.hasAuthority;
            children.add(
              ListTile(
                title: Text(entry.key),
                subtitle: available
                    ? null
                    : const Text('Document has not been published yet.'),
                trailing: available ? const Icon(Icons.open_in_new) : null,
                onTap: !available
                    ? null
                    : () async {
                        try {
                          if (!await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          ))
                            throw Exception();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to open document. Please retry.',
                                ),
                              ),
                            );
}
                        }
                      },
              ),
            );
          }
        } else {
          children.add(
            ListTile(
              title: Text('${data['message'] ?? 'No information available.'}'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: children.length,
            itemBuilder: (_, index) => children[index],
          ),
        );
      },
    ),
  );

  Future<void> _newTicket() async {
    var subject = '';
    // The same key survives retries from this form to avoid duplicate tickets.
    final key = 'support_${DateTime.now().microsecondsSinceEpoch}';
    var category = 'other';
    var sending = false;
    String? error;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Contact support'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: ['booking', 'payment', 'quality', 'other']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: sending
                      ? null
                      : (value) => update(() => category = value!),
                ),
                TextField(
                  onChanged: (value) => subject = value,
                  enabled: !sending,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Describe your issue',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (subject.trim().length < 3) {
                        update(() => error = 'Please describe your issue.');
                        return;
                      }
                      update(() {
                        sending = true;
                        error = null;
                      });
                      try {
                        await widget.api.createSupportTicket(
                          subject: subject.trim(),
                          category: category,
                          idempotencyKey: key,
                        );
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (_) {
                        if (dialogContext.mounted)
                          update(() {
                            sending = false;
                            error = 'Unable to send. Please retry.';
                          });
                      }
                    },
              child: Text(sending ? 'Sending…' : 'Send'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true && mounted) await _refresh();
  }
}
