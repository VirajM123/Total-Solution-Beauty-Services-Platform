import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Checkout presentation only. The parent owns all selections and navigation.
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
  });
  final Widget calendar;
  final DateTime date;
  final String time;
  final String preference;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<String> onPreferenceChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  static const _pink = Color(0xFFCE0051);
  static const _ink = Color(0xFF17152E);
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
  static const _gradient = LinearGradient(
    colors: [Color(0xFFEF2879), Color(0xFFBF0048)],
  );
  static const _times = [
    '9:00 AM',
    '9:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final dense = bounds.maxHeight < 740;
      final gap = dense ? 8.0 : 12.0;
      final fullDate =
          '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';
      return Material(
        color: const Color(0xFFFFFBFE),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFBFE), Color(0xFFFFF7FC), Colors.white],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                right: 0,
                width: 108,
                height: 82,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _CornerFlower()),
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: dense ? 54 : 68,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          top: 2,
                          child: IconButton(
                            key: const ValueKey('checkout-back'),
                            tooltip: 'Back',
                            onPressed: onBack,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _ink,
                              size: 21,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 46),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Select Date & Time',
                                  style: TextStyle(
                                    fontSize: dense ? 21 : 24,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Choose your preferred slot',
                                style: TextStyle(
                                  fontSize: dense ? 11 : 13,
                                  color: const Color(0xFF686477),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('checkout-step-0'),
                      padding: EdgeInsets.fromLTRB(16, dense ? 2 : 6, 16, 4),
                      children: [
                        calendar,
                        SizedBox(height: gap),
                        Container(
                          key: const ValueKey('selected-booking-date'),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: dense ? 7 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE8F2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                color: _pink,
                                size: dense ? 26 : 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Date',
                                      style: TextStyle(
                                        fontSize: dense ? 10 : 11,
                                        color: const Color(0xFF776074),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fullDate,
                                      style: TextStyle(
                                        fontSize: dense ? 11 : 13,
                                        color: const Color(0xFF35142F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              color: Color(0xFF35142F),
                              size: 21,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'Available Time Slots',
                              style: TextStyle(
                                fontSize: dense ? 13 : 15,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 9,
                            runSpacing: dense ? 5 : 6,
                            children: [
                              for (final slot in _times)
                                SizedBox(
                                  width: (constraints.maxWidth - 9) / 2,
                                  height: dense ? 28 : 34,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      key: ValueKey('booking-time-$slot'),
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => onTimeChanged(slot),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          color: time == slot
                                              ? null
                                              : Colors.white.withValues(
                                                  alpha: .85,
                                                ),
                                          gradient: time == slot
                                              ? _gradient
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: time == slot
                                                ? Colors.transparent
                                                : const Color(0xFFE3DFE8),
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              slot,
                                              style: TextStyle(
                                                fontSize: dense ? 11 : 13,
                                                color: time == slot
                                                    ? Colors.white
                                                    : const Color(0xFF17151B),
                                                fontWeight: time == slot
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                            if (time == slot)
                                              Positioned(
                                                right: dense ? 9 : 12,
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: dense ? 15 : 18,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            Expanded(
                              child: _pill(
                                Icons.wb_sunny_outlined,
                                DropdownButton<String>(
                                  isExpanded: true,
                                  isDense: true,
                                  value: _times.contains(time) ? null : time,
                                  hint: const Text(
                                    'Afternoon / Evening',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF35142F),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Color(0xFF35142F),
                                  ),
                                  items: [
                                    for (final slot in [
                                      '1:00 PM',
                                      '4:00 PM',
                                      '5:00 PM',
                                      '6:00 PM',
                                    ])
                                      DropdownMenuItem(
                                        value: slot,
                                        child: Text(
                                          slot,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) onTimeChanged(value);
                                  },
                                ),
                                dense,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pill(
                                Icons.bolt_rounded,
                                DropdownButton<String>(
                                  isExpanded: true,
                                  isDense: true,
                                  value: preference,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: Color(0xFF35142F),
                                  ),
                                  items: [
                                    for (final value in [
                                      'Book Instantly',
                                      'Schedule Later',
                                    ])
                                      DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF35142F),
                                          ),
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null)
                                      onPreferenceChanged(value);
                                  },
                                ),
                                dense,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, dense ? 8 : 12),
                      child: Container(
                        height: dense ? 44 : 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: _gradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x27D30055),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('checkout-continue'),
                            onTap: onContinue,
                            borderRadius: BorderRadius.circular(28),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _pill(IconData icon, Widget menu, bool dense) => Container(
    height: dense ? 36 : 42,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0F6),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF8C9DF)),
    ),
    child: Row(
      children: [
        Icon(icon, size: dense ? 17 : 21, color: _pink),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonHideUnderline(child: menu)),
      ],
    ),
  );
}

class _CornerFlower extends CustomPainter {
  const _CornerFlower();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .86, -5);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / 5 + .2);
      final petal = Rect.fromLTWH(-12, 0, 28, 70);
      canvas.drawOval(
        petal,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x66F39FCB), Color(0x04FFE3F2)],
          ).createShader(petal),
      );
      canvas.restore();
    }
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7;
      canvas.drawCircle(
        Offset(math.cos(angle) * 13, math.sin(angle) * 13),
        2,
        Paint()..color = const Color(0xA8CF1658),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CornerFlower oldDelegate) => false;
}
