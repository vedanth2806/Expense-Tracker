import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../widgets/sidebar.dart';

class YearlyAnalysisScreen extends StatefulWidget {
  const YearlyAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<YearlyAnalysisScreen> createState() => _YearlyAnalysisScreenState();
}

class _YearlyAnalysisScreenState extends State<YearlyAnalysisScreen> {
  int _selectedYear = DateTime.now().year;
  Map<int, double> _monthlyTotals = {};
  bool _isLoading = true;
  double _yearlyTotal = 0;

  // A curated monthly palette (not category-based)
  final List<Color> _barColors = const [
    Color(0xFF30437A),
    Color(0xFF4A6FA5),
    Color(0xFF6389C0),
    Color(0xFF30437A),
    Color(0xFF4A6FA5),
    Color(0xFF6389C0),
    Color(0xFF30437A),
    Color(0xFF4A6FA5),
    Color(0xFF6389C0),
    Color(0xFF30437A),
    Color(0xFF4A6FA5),
    Color(0xFF6389C0),
  ];

  final List<String> _monthShortNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final totals = await DatabaseHelper().getMonthlyTotalsForYear(_selectedYear);
    final yearTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (!mounted) return;
    setState(() {
      _monthlyTotals = totals;
      _yearlyTotal = yearTotal;
      _isLoading = false;
    });
  }

  void _previousYear() {
    setState(() => _selectedYear--);
    _loadData();
  }

  void _nextYear() {
    if (_selectedYear < DateTime.now().year) {
      setState(() => _selectedYear++);
      _loadData();
    }
  }

  bool _isCurrentYear() => _selectedYear == DateTime.now().year;

  double get _maxValue {
    if (_monthlyTotals.isEmpty) return 100;
    final max = _monthlyTotals.values.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max * 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Yearly Analysis')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildYearNavigator(theme),
                  const SizedBox(height: 20),
                  _buildSummaryCard(theme),
                  const SizedBox(height: 24),
                  _monthlyTotals.isEmpty
                      ? _buildEmptyState()
                      : _buildBarChartCard(theme),
                  const SizedBox(height: 20),
                  if (_monthlyTotals.isNotEmpty) _buildMonthlyList(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildYearNavigator(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _previousYear,
              tooltip: 'Previous Year',
              color: const Color(0xFF30437A),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _selectedYear.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30437A),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _isCurrentYear() ? Colors.grey[400] : const Color(0xFF30437A),
              ),
              onPressed: _isCurrentYear() ? null : _nextYear,
              tooltip: 'Next Year',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final activeMonths = _monthlyTotals.length;
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
              _selectedYear.toString(),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Annual Total',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${_yearlyTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$activeMonths active month${activeMonths == 1 ? '' : 's'} of 12',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(ThemeData theme) {
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
                Text('Monthly Breakdown', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
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
                        return BarTooltipItem(
                          '${_monthShortNames[group.x]}\n₹${rod.toY.toStringAsFixed(0)}',
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
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final month = value.toInt() + 1;
                          final total = _monthlyTotals[month] ?? 0;
                          if (total == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              total >= 1000
                                  ? '${(total / 1000).toStringAsFixed(1)}k'
                                  : total.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 9,
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
                          final index = value.toInt();
                          if (index < 0 || index >= 12) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _monthShortNames[index],
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
                  barGroups: List.generate(12, (index) {
                    final month = index + 1;
                    final total = _monthlyTotals[month] ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          color: total > 0
                              ? _barColors[index]
                              : Colors.grey.withOpacity(0.1),
                          width: 22,
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
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Month of Year →',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyList(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Month-by-Month', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(12, (i) {
              final month = i + 1;
              final total = _monthlyTotals[month] ?? 0;
              final pct = _yearlyTotal > 0 ? total / _yearlyTotal : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: total > 0
                            ? _barColors[i]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text(
                        _monthShortNames[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: total > 0 ? null : Colors.grey[400],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 6,
                          backgroundColor: Colors.grey.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            total > 0
                                ? _barColors[i]
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: Text(
                        total > 0 ? '₹${total.toStringAsFixed(0)}' : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: total > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: total > 0 ? null : Colors.grey[400],
                        ),
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
              'No expenses in $_selectedYear',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses to see the monthly breakdown',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
