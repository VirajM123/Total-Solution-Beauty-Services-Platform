import 'package:flutter/material.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

class WorkerRejectionReason {
  const WorkerRejectionReason(this.reason, this.note);
  final String reason;
  final String note;
}

/// Returns a reason only; no server-side rejection or penalty is recorded.
class WorkerRejectionReasonScreen extends StatefulWidget {
  const WorkerRejectionReasonScreen({super.key});
  @override
  State<WorkerRejectionReasonScreen> createState() => _WorkerRejectionReasonScreenState();
}

class _WorkerRejectionReasonScreenState extends State<WorkerRejectionReasonScreen> {
  static const reasons = [
    'Too far from customer',
    'Already busy / running late',
    'Cannot arrive at requested time',
    'Service outside my expertise',
    'Equipment or materials unavailable',
    'Personal emergency',
    'Other',
  ];
  final _note = TextEditingController();
  String? _selected;
  @override
  void dispose() { _note.dispose(); super.dispose(); }

  void _confirm() {
    if (_selected == null || (_selected == 'Other' && _note.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a reason. Add details for Other.')),
      );
      return;
    }
    Navigator.pop(context, WorkerRejectionReason(_selected!, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(backgroundColor: _cream, foregroundColor: _deep,
      title: const Text('Reject booking', style: TextStyle(fontWeight: FontWeight.w800))),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Why can’t you accept this booking?',
            style: TextStyle(color: _deep, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Please select an accurate reason. A rejection is not an automatic penalty.',
            style: TextStyle(color: _muted, height: 1.45)),
          const SizedBox(height: 16),
          for (final reason in reasons)
            Padding(padding: const EdgeInsets.only(bottom: 7), child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: _selected == reason ? _pink : _border)),
              child: RadioListTile<String>(
                title: Text(reason, style: const TextStyle(color: _deep, fontSize: 13)),
                value: reason, groupValue: _selected, activeColor: _pink,
                onChanged: (value) => setState(() => _selected = value),
              ),
            )),
          const SizedBox(height: 8),
          TextField(controller: _note, maxLength: 200, maxLines: 3,
            decoration: InputDecoration(labelText: _selected == 'Other' ? 'Please explain (required)' : 'Additional details (optional)',
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        ])),
        Padding(padding: const EdgeInsets.all(17), child: SizedBox(width: double.infinity, height: 50,
          child: FilledButton(onPressed: _confirm,
            style: FilledButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white),
            child: const Text('Confirm rejection')))),
      ]),
    ))),
  );
}
