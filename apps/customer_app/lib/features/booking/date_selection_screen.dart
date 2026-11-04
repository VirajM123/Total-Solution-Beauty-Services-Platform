import 'package:flutter/material.dart';
import 'compact_booking_widgets.dart';

/// Presentation only. The checkout owner retains all selections and callbacks.
class DateSelectionScreen extends StatelessWidget {
  const DateSelectionScreen({
    super.key,
    required this.calendar,
    required this.date,
    required this.time,
    required this.preference,
    required this.onTimeChanged,
    required this.onPreferenceChanged,
    required this.onBack,
    required this.onContinue,
    this.address,
    this.onAddressTap,
  });
  final Widget calendar;
  final DateTime date;
  final String time;
  final String preference;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<String> onPreferenceChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String? address;
  final VoidCallback? onAddressTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('checkout-back'),
              onPressed: onBack,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const Expanded(
              child: Text(
                'Date & Time',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          key: const ValueKey('checkout-step-0'),
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          children: [
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            calendar,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                MaterialLocalizations.of(context).formatFullDate(date),
                key: const ValueKey('selected-booking-date'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF777078)),
              ),
            ),
            const Text(
              'Select Time',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _slots(const [
              '9:00 AM',
              '9:30 AM',
              '10:00 AM',
              '10:30 AM',
              '11:00 AM',
              '11:30 AM',
            ]),
            ExpansionTile(
              key: const ValueKey('additional-booking-times'),
              initiallyExpanded: !const [
                '9:00 AM',
                '9:30 AM',
                '10:00 AM',
                '10:30 AM',
                '11:00 AM',
                '11:30 AM',
              ].contains(time),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 6),
              dense: true,
              visualDensity: const VisualDensity(vertical: -3),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'More times',
                style: const TextStyle(fontSize: 11, color: bookingPink),
              ),
              children: [
                _slots(const [
                  '12:00 PM',
                  '12:30 PM',
                  '1:00 PM',
                  '2:00 PM',
                  '2:30 PM',
                  '3:00 PM',
                  '3:30 PM',
                  '4:00 PM',
                  '5:00 PM',
                  '6:00 PM',
                ]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Booking preference',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButton<String>(
                  value: preference,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Color(0xFF17152E),
                  ),
                  items: [
                    for (final value in ['Book Instantly', 'Schedule Later'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) onPreferenceChanged(value);
                  },
                ),
              ],
            ),
            if (address != null) ...[
              const SizedBox(height: 4),
              const Text(
                'Service Address',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE8DDE5)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  leading: const Icon(
                    Icons.home_outlined,
                    size: 21,
                    color: bookingPink,
                  ),
                  title: Text(address!, style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: onAddressTap,
                ),
              ),
            ],
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              key: const ValueKey('checkout-continue'),
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _slots(List<String> slots) => LayoutBuilder(
    builder: (context, bounds) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final slot in slots)
          SizedBox(
            width: (bounds.maxWidth - 12) / 3,
            height: 36,
            child: OutlinedButton(
              key: ValueKey('booking-time-$slot'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: time == slot ? bookingPink : Colors.white,
                foregroundColor: time == slot
                    ? Colors.white
                    : const Color(0xFF17152E),
              ),
              onPressed: () => onTimeChanged(slot),
              child: Text(slot, style: const TextStyle(fontSize: 11)),
            ),
          ),
      ],
    ),
  );
}
