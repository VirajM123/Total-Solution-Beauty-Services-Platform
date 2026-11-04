import 'package:flutter/material.dart';
import 'compact_booking_widgets.dart';

/// Month view only; the checkout owner retains the selected appointment date.
class CompactCheckoutCalendar extends StatelessWidget {
  const CompactCheckoutCalendar({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.onSelected,
    required this.onMonthChanged,
    required this.onPickDate,
    this.dense = false,
  });
  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onPickDate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = first.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDate = today.add(const Duration(days: 365));
    final rows = ((offset + days) / 7).ceil();
    return Container(
      key: const ValueKey('booking-calendar'),
      padding: EdgeInsets.all(dense ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DDE5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('booking-week-previous'),
                tooltip: 'Previous month',
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEDF5),
                  foregroundColor: bookingPink,
                ),
                onPressed: DateTime(month.year, month.month, 0).isBefore(today)
                    ? null
                    : () => onMonthChanged(-1),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: TextButton(
                  key: const ValueKey('booking-month-picker'),
                  onPressed: onPickDate,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(first),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17152E),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('booking-week-next'),
                tooltip: 'Next month',
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEDF5),
                  foregroundColor: bookingPink,
                ),
                onPressed:
                    DateTime(month.year, month.month + 1).isAfter(lastDate)
                    ? null
                    : () => onMonthChanged(1),
                icon: const Icon(
                  Icons.chevron_right,
                  color: bookingPink,
                  size: 20,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in [
                'Sun',
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: dense ? 10 : 11,
                        color: label == 'Sun'
                            ? const Color(0xFFEF5A8B)
                            : const Color(0xFF686477),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < rows; row++)
            SizedBox(
              height: dense ? 22 : 28,
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = row * 7 + column - offset + 1;
                          if (day < 1 || day > days)
                            return const SizedBox.shrink();
                          final date = DateTime(month.year, month.month, day);
                          final disabled =
                              date.isBefore(today) || date.isAfter(lastDate);
                          final selected = DateUtils.isSameDay(
                            date,
                            selectedDate,
                          );
                          return Semantics(
                            selected: selected,
                            button: true,
                            label: MaterialLocalizations.of(
                              context,
                            ).formatFullDate(date),
                            child: InkResponse(
                              key: ValueKey(
                                'booking-date-${date.year}-${date.month}-${date.day}',
                              ),
                              onTap: disabled ? null : () => onSelected(date),
                              child: Center(
                                child: Container(
                                  width: dense ? 22 : 27,
                                  height: dense ? 22 : 27,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: selected
                                        ? bookingPink
                                        : Colors.transparent,
                                  ),
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: dense ? 11 : 12,
                                      color: selected
                                          ? Colors.white
                                          : disabled
                                          ? const Color(0xFFBDB5BB)
                                          : column == 0
                                          ? const Color(0xFFEF5A8B)
                                          : const Color(0xFF17151B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
