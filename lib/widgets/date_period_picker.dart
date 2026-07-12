import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PeriodPickerMode { day, month, year }

/// A reusable bottom-sheet picker for selecting a date, month, or year.
///
/// Usage:
/// ```dart
/// final result = await DatePeriodPicker.show(
///   context: context,
///   mode: DatePickerMode.day,
///   initialDate: _selectedDate,
/// );
/// if (result != null) setState(() => _selectedDate = result);
/// ```
class DatePeriodPicker {
  static Future<DateTime?> show({
    required BuildContext context,
    required PeriodPickerMode mode,
    required DateTime initialDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatePeriodPickerSheet(
        mode: mode,
        initialDate: initialDate,
      ),
    );
  }
}

class _DatePeriodPickerSheet extends StatefulWidget {
  final PeriodPickerMode mode;
  final DateTime initialDate;

  const _DatePeriodPickerSheet({
    required this.mode,
    required this.initialDate,
  });

  @override
  State<_DatePeriodPickerSheet> createState() => _DatePeriodPickerSheetState();
}

class _DatePeriodPickerSheetState extends State<_DatePeriodPickerSheet> {
  static const _primaryColor = Color(0xFF30437A);

  final DateTime _now = DateTime.now();

  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  // Year range: 2000 → current year
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;

    _years = List.generate(_now.year - 1999, (i) => 2000 + i);

    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_selectedYear),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDay - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  int get _daysInSelectedMonth =>
      DateTime(_selectedYear, _selectedMonth + 1, 0).day;

  bool _isMonthDisabled(int month) {
    if (_selectedYear < _now.year) return false;
    return month > _now.month;
  }

  bool _isDayDisabled(int day) {
    if (_selectedYear < _now.year) return false;
    if (_selectedMonth < _now.month) return false;
    return day > _now.day;
  }

  void _clampDay() {
    final maxDay = _daysInSelectedMonth;
    if (_selectedDay > maxDay) {
      setState(() => _selectedDay = maxDay);
      _dayController.jumpToItem(_selectedDay - 1);
    }
    // Also clamp to today if needed
    if (_isDayDisabled(_selectedDay)) {
      setState(() => _selectedDay = _now.day);
      _dayController.jumpToItem(_selectedDay - 1);
    }
  }

  void _onConfirm() {
    DateTime result;
    switch (widget.mode) {
      case PeriodPickerMode.day:
        result = DateTime(_selectedYear, _selectedMonth, _selectedDay);
        break;
      case PeriodPickerMode.month:
        result = DateTime(_selectedYear, _selectedMonth);
        break;
      case PeriodPickerMode.year:
        result = DateTime(_selectedYear);
        break;
    }
    Navigator.of(context).pop(result);
  }

  static const _itemExtent = 48.0;
  static const _wheelHeight = 200.0;

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      height: _wheelHeight,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemExtent,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
        diameterRatio: 1.8,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= itemCount) return null;
            return itemBuilder(index);
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  Widget _wheelItem(String label, bool isSelected, {bool disabled = false}) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(
        fontSize: isSelected ? 20 : 15,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: disabled
            ? Colors.grey[300]
            : isSelected
                ? _primaryColor
                : Colors.grey[500],
      ),
      child: Center(child: Text(label)),
    );
  }

  Widget _buildYearWheel() {
    return _buildWheel(
      controller: _yearController,
      itemCount: _years.length,
      onChanged: (i) {
        setState(() => _selectedYear = _years[i]);
        // clamp month if needed
        if (_isMonthDisabled(_selectedMonth)) {
          setState(() => _selectedMonth = _now.month);
          _monthController.jumpToItem(_selectedMonth - 1);
        }
        _clampDay();
      },
      itemBuilder: (i) => _wheelItem(
        _years[i].toString(),
        _years[i] == _selectedYear,
      ),
    );
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Widget _buildMonthWheel() {
    return _buildWheel(
      controller: _monthController,
      itemCount: 12,
      onChanged: (i) {
        if (_isMonthDisabled(i + 1)) return;
        setState(() => _selectedMonth = i + 1);
        _clampDay();
      },
      itemBuilder: (i) => _wheelItem(
        _monthNames[i],
        i + 1 == _selectedMonth,
        disabled: _isMonthDisabled(i + 1),
      ),
    );
  }

  Widget _buildDayWheel() {
    final days = _daysInSelectedMonth;
    return _buildWheel(
      controller: _dayController,
      itemCount: days,
      onChanged: (i) {
        if (_isDayDisabled(i + 1)) return;
        setState(() => _selectedDay = i + 1);
      },
      itemBuilder: (i) => _wheelItem(
        (i + 1).toString().padLeft(2, '0'),
        i + 1 == _selectedDay,
        disabled: _isDayDisabled(i + 1),
      ),
    );
  }

  String get _title {
    switch (widget.mode) {
      case PeriodPickerMode.day:
        return 'Select Date';
      case PeriodPickerMode.month:
        return 'Select Month';
      case PeriodPickerMode.year:
        return 'Select Year';
    }
  }

  String get _previewText {
    switch (widget.mode) {
      case PeriodPickerMode.day:
        return DateFormat('dd MMMM yyyy').format(
          DateTime(_selectedYear, _selectedMonth, _selectedDay),
        );
      case PeriodPickerMode.month:
        return DateFormat('MMMM yyyy').format(
          DateTime(_selectedYear, _selectedMonth),
        );
      case PeriodPickerMode.year:
        return _selectedYear.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),

          // Preview
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _previewText,
              key: ValueKey(_previewText),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider highlight behind center item
          Stack(
            alignment: Alignment.center,
            children: [
              // Centre highlight bar
              Container(
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Wheels
              Row(
                children: [
                  if (widget.mode == PeriodPickerMode.day) ...[
                    // Day | Month | Year
                    SizedBox(width: 52, child: _buildDayWheel()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMonthWheel()),
                    const SizedBox(width: 8),
                    SizedBox(width: 68, child: _buildYearWheel()),
                  ] else if (widget.mode == PeriodPickerMode.month) ...[
                    // Month | Year
                    Expanded(child: _buildMonthWheel()),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: _buildYearWheel()),
                  ] else ...[
                    // Year only
                    Expanded(child: _buildYearWheel()),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
