import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';

/// Vietnamese Coastal Heritage date picker bottom sheet with quick-pick chips
/// ("Hôm nay", "Ngày mai", "Cuối tuần", "Tuần sau") and a clean month calendar.
Future<DateTime?> showCoastalDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final palette = CoastalPalette.of(context);
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CoastalDatePickerSheet(
      initialDate: _dateOnly(initialDate),
      firstDate: _dateOnly(firstDate),
      lastDate: _dateOnly(lastDate),
    ),
  );
}

/// Vietnamese Coastal Heritage time picker bottom sheet with popular time chips
/// and a two-column vertical wheel picker (`Giờ` 00–23 : `Phút` 00–55 step 5).
Future<TimeOfDay?> showCoastalTimePickerSheet({
  required BuildContext context,
  required TimeOfDay initialTime,
  required DateTime selectedDate,
  int? availableMinutes,
}) {
  final palette = CoastalPalette.of(context);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CoastalTimePickerSheet(
      initialTime: initialTime,
      selectedDate: _dateOnly(selectedDate),
      availableMinutes: availableMinutes,
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _vietnameseFullDate(DateTime date) {
  final weekday = switch (date.weekday) {
    DateTime.monday => 'Thứ 2',
    DateTime.tuesday => 'Thứ 3',
    DateTime.wednesday => 'Thứ 4',
    DateTime.thursday => 'Thứ 5',
    DateTime.friday => 'Thứ 6',
    DateTime.saturday => 'Thứ 7',
    DateTime.sunday => 'Chủ nhật',
    _ => '',
  };
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$weekday, $dd/$mm/${date.year}';
}

String _hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

final class _CoastalDatePickerSheet extends StatefulWidget {
  const _CoastalDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CoastalDatePickerSheet> createState() =>
      _CoastalDatePickerSheetState();
}

final class _CoastalDatePickerSheetState
    extends State<_CoastalDatePickerSheet> {
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  late DateTime _selected = _clampDate(widget.initialDate);
  late DateTime _visibleMonth = DateTime(_selected.year, _selected.month);

  DateTime _clampDate(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  DateTime _nextWeekend() {
    final daysUntilSaturday =
        (DateTime.saturday - widget.firstDate.weekday) % 7;
    return _clampDate(widget.firstDate.add(Duration(days: daysUntilSaturday)));
  }

  bool get _canPrevMonth => DateTime(
    _visibleMonth.year,
    _visibleMonth.month - 1,
    1,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month - 1, 1));

  bool get _canNextMonth => DateTime(
    _visibleMonth.year,
    _visibleMonth.month + 1,
    1,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1, 1));

  void _selectDate(DateTime date) {
    final clamped = _clampDate(date);
    setState(() {
      _selected = clamped;
      _visibleMonth = DateTime(clamped.year, clamped.month);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final leadingBlanks = firstDayOfMonth.weekday - 1; // Monday = 0
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final quickOptions = <(String, DateTime)>[
      ('Hôm nay', widget.firstDate),
      ('Ngày mai', _clampDate(widget.firstDate.add(const Duration(days: 1)))),
      ('Cuối tuần', _nextWeekend()),
      ('Tuần sau', _clampDate(widget.firstDate.add(const Duration(days: 7)))),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chọn ngày bắt đầu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTypography.displayFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _vietnameseFullDate(_selected),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, date) in quickOptions) ...[
                    _QuickPillChip(
                      palette: palette,
                      label: label,
                      selected: _selected == date,
                      onTap: () => _selectDate(date),
                    ),
                    if (label != quickOptions.last.$1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: palette.border, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _CircleNavButton(
                  palette: palette,
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Tháng trước',
                  onTap: _canPrevMonth ? () => _shiftMonth(-1) : null,
                ),
                Expanded(
                  child: Text(
                    'Tháng ${_visibleMonth.month}, ${_visibleMonth.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.displayFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
                _CircleNavButton(
                  palette: palette,
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Tháng sau',
                  onTap: _canNextMonth ? () => _shiftMonth(1) : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final day in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var row = 0; row < rowCount; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _buildDayCell(
                          palette: palette,
                          dayNumber: row * 7 + col - leadingBlanks + 1,
                          daysInMonth: daysInMonth,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.ink,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text('Xác nhận ngày'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell({
    required CoastalPalette palette,
    required int dayNumber,
    required int daysInMonth,
  }) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 38);
    }
    final cellDate = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      dayNumber,
    );
    final isDisabled =
        cellDate.isBefore(widget.firstDate) ||
        cellDate.isAfter(widget.lastDate);
    final isSelected = cellDate == _selected;

    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isDisabled ? null : () => setState(() => _selected = cellDate),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? palette.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? palette.onPrimary
                  : (isDisabled
                        ? palette.secondary.withValues(alpha: 0.42)
                        : palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}

final class _CoastalTimePickerSheet extends StatefulWidget {
  const _CoastalTimePickerSheet({
    required this.initialTime,
    required this.selectedDate,
    this.availableMinutes,
  });

  final TimeOfDay initialTime;
  final DateTime selectedDate;
  final int? availableMinutes;

  @override
  State<_CoastalTimePickerSheet> createState() =>
      _CoastalTimePickerSheetState();
}

final class _CoastalTimePickerSheetState
    extends State<_CoastalTimePickerSheet> {
  static const _minuteStep = 5;
  static const _minuteCount = 60 ~/ _minuteStep; // 12 items: 00, 05..55
  static const _quickTimes = <(int, int)>[
    (7, 0),
    (8, 0),
    (9, 0),
    (14, 0),
    (18, 0),
  ];

  late int _hour;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  int get _minute => _minuteIndex * _minuteStep;

  @override
  void initState() {
    super.initState();
    // Round initial minute to nearest 5-minute step for smooth wheel selection.
    final roundedMinutes =
        ((widget.initialTime.minute + (_minuteStep ~/ 2)) ~/ _minuteStep) *
        _minuteStep;
    if (roundedMinutes >= 60) {
      _hour = (widget.initialTime.hour + 1) % 24;
      _minuteIndex = 0;
    } else {
      _hour = widget.initialTime.hour;
      _minuteIndex = roundedMinutes ~/ _minuteStep;
    }
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _selectPreset(int hour, int minute) {
    final targetMinuteIndex = (minute ~/ _minuteStep) % _minuteCount;
    setState(() {
      _hour = hour;
      _minuteIndex = targetMinuteIndex;
    });
    _hourController.animateToItem(
      hour,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _minuteController.animateToItem(
      targetMinuteIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String? _endPreviewLabel() {
    final duration = widget.availableMinutes;
    if (duration == null) return null;
    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _hour,
      _minute,
    );
    final end = start.add(Duration(minutes: duration));
    final sameDay =
        end.year == start.year &&
        end.month == start.month &&
        end.day == start.day;
    final dd = end.day.toString().padLeft(2, '0');
    final mm = end.month.toString().padLeft(2, '0');
    final endClock = _hhmm(end.hour, end.minute);
    return sameDay
        ? 'Dự kiến kết thúc lúc $endClock (cùng ngày $dd/$mm)'
        : 'Dự kiến kết thúc lúc $endClock (ngày $dd/$mm)';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final preview = _endPreviewLabel();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chọn giờ xuất phát',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTypography.displayFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _hhmm(_hour, _minute),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (h, m) in _quickTimes) ...[
                    _QuickPillChip(
                      palette: palette,
                      label: _hhmm(h, m),
                      selected: _hour == h && _minute == m,
                      onTap: () => _selectPreset(h, m),
                    ),
                    if (h != _quickTimes.last.$1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: palette.border, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giờ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'Phút',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.softAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          key: const Key('hour_wheel'),
                          controller: _hourController,
                          itemExtent: 44,
                          diameterRatio: 1.5,
                          perspective: 0.003,
                          overAndUnderCenterOpacity: 0.45,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() => _hour = index % 24);
                          },
                          childDelegate: ListWheelChildLoopingListDelegate(
                            children: [
                              for (var h = 0; h < 24; h++)
                                Center(
                                  child: Text(
                                    h.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: h == _hour ? 26 : 20,
                                      fontWeight: h == _hour
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: h == _hour
                                          ? palette.primary
                                          : palette.ink,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          key: const Key('minute_wheel'),
                          controller: _minuteController,
                          itemExtent: 44,
                          diameterRatio: 1.5,
                          perspective: 0.003,
                          overAndUnderCenterOpacity: 0.45,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() => _minuteIndex = index % _minuteCount);
                          },
                          childDelegate: ListWheelChildLoopingListDelegate(
                            children: [
                              for (var i = 0; i < _minuteCount; i++)
                                Center(
                                  child: Text(
                                    (i * _minuteStep).toString().padLeft(
                                      2,
                                      '0',
                                    ),
                                    style: TextStyle(
                                      fontSize: i == _minuteIndex ? 26 : 20,
                                      fontWeight: i == _minuteIndex
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i == _minuteIndex
                                          ? palette.primary
                                          : palette.ink,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
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
            if (preview != null) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: palette.secondary),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.ink,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(TimeOfDay(hour: _hour, minute: _minute)),
                      child: const Text('Xác nhận giờ'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _QuickPillChip extends StatelessWidget {
  const _QuickPillChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CoastalPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? palette.onPrimary : palette.ink,
          ),
        ),
      ),
    );
  }
}

final class _CircleNavButton extends StatelessWidget {
  const _CircleNavButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final CoastalPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.surface,
        shape: CircleBorder(side: BorderSide(color: palette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? palette.secondary.withValues(alpha: 0.35)
                  : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
