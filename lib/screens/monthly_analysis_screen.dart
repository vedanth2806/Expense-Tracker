import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../widgets/sidebar.dart';
import '../utils/category_colors.dart';

class MonthlyAnalysisScreen extends StatefulWidget {
  const MonthlyAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<MonthlyAnalysisScreen> createState() => _MonthlyAnalysisScreenState();
}

class _MonthlyAnalysisScreenState extends State<MonthlyAnalysisScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<int, double> _dailyTotals = {};
  Map<String, double> _categoryTotals = {};
  bool _isLoading = true;
  double _monthlyTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final totals = await DatabaseHelper().getDailyTotalsForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final categoryTotals = await DatabaseHelper().getCategoryTotalsByMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final monthTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (!mounted) return;
    setState(() {
      _dailyTotals = totals;
      _categoryTotals = categoryTotals;
      _monthlyTotal = monthTotal;
      _isLoading = false;
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.year < now.year ||
        (next.year == now.year && next.month <= now.month)) {
      setState(() => _selectedMonth = next);
      _loadData();
    }
  }

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  int get _daysInMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

  double get _maxValue {
    if (_dailyTotals.isEmpty) return 100;
    final max = _dailyTotals.values.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max * 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Analysis'),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Month Navigator ────────────────────────────────────
                  _buildMonthNavigator(theme),

                  const SizedBox(height: 20),

                  // ── Summary Card ───────────────────────────────────────
                  _buildSummaryCard(theme),

                  const SizedBox(height: 24),

                  // ── Category Pie Chart ─────────────────────────────────
                  if (_categoryTotals.isNotEmpty) ...[
                    _buildCategoryPieChart(theme),
                    const SizedBox(height: 24),
                  ],

                  // ── Bar Chart ──────────────────────────────────────────
                  _dailyTotals.isEmpty
                      ? _buildEmptyState()
                      : _buildBarChartCard(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthNavigator(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _previousMonth,
              tooltip: 'Previous Month',
              color: const Color(0xFF30437A),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30437A),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _isCurrentMonth()
                    ? Colors.grey[400]
                    : const Color(0xFF30437A),
              ),
              onPressed: _isCurrentMonth() ? null : _nextMonth,
              tooltip: 'Next Month',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF30437A), Color(0xFF4A6FA5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Total Spent',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${_monthlyTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_dailyTotals.length} active day${_dailyTotals.length == 1 ? '' : 's'} of $_daysInMonth',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  /// Pie chart by category for the current month
  Widget _buildCategoryPieChart(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Category Breakdown',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sections: _categoryTotals.entries.map((entry) {
                    final pct = _monthlyTotal > 0
                        ? (entry.value / _monthlyTotal * 100)
                        : 0.0;
                    return PieChartSectionData(
                      color: CategoryColors.getColor(entry.key),
                      value: entry.value,
                      title: '${pct.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 55,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            ..._categoryTotals.entries.map((entry) {
              final color = CategoryColors.getColor(entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30437A),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(ThemeData theme) {
    // Each bar slot is 28px wide for a scrollable view
    const double barSlotWidth = 28.0;
    final double chartInnerWidth = _daysInMonth * barSlotWidth;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Daily Expenses',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Scrollable bar chart
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartInnerWidth,
                height: 300,
                child: BarChart(
                  BarChartData(
                    maxY: _maxValue,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            const Color(0xFF30437A).withOpacity(0.85),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final day = group.x + 1;
                          return BarTooltipItem(
                            'Day $day\n₹${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final day = value.toInt() + 1;
                            final total = _dailyTotals[day] ?? 0;
                            if (total == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                total >= 1000
                                    ? '${(total / 1000).toStringAsFixed(1)}k'
                                    : total.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final day = value.toInt() + 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                day.toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            final label = value >= 1000
                                ? '₹${(value / 1000).toStringAsFixed(0)}k'
                                : '₹${value.toStringAsFixed(0)}';
                            return Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.15),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(_daysInMonth, (index) {
                      final day = index + 1;
                      final total = _dailyTotals[day] ?? 0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: total,
                            color: total > 0
                                ? const Color(0xFF30437A)
                                : Colors.grey.withOpacity(0.1),
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '← Scroll to see all days →',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No expenses this month',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses to see the daily breakdown',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
