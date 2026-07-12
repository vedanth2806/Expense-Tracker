import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../utils/category_colors.dart';
import '../utils/currency_formatter.dart';
import 'category_detail_screen.dart';

/// Shown when the user taps a month bar in the Yearly Analysis bar chart.
/// Displays that month's spending with a sorted category pie chart and legend.
class MonthExpenseScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthExpenseScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<MonthExpenseScreen> createState() => _MonthExpenseScreenState();
}

class _MonthExpenseScreenState extends State<MonthExpenseScreen> {
  static const _primaryColor = Color(0xFF30437A);

  Map<String, double> _categoryTotals = {};
  bool _isLoading = true;
  double _monthlyTotal = 0;
  int _expenseCount = 0;

  late final DateTime _monthDate;

  @override
  void initState() {
    super.initState();
    _monthDate = DateTime(widget.year, widget.month);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final expenses = await DatabaseHelper().getExpensesByMonth(
      widget.year,
      widget.month,
    );
    final catTotals = await DatabaseHelper().getCategoryTotalsByMonth(
      widget.year,
      widget.month,
    );
    final total = catTotals.values.fold(0.0, (a, b) => a + b);

    if (!mounted) return;
    setState(() {
      _categoryTotals = catTotals;
      _monthlyTotal = total;
      _expenseCount = expenses.length;
      _isLoading = false;
    });
  }

  List<MapEntry<String, double>> get _sortedCategories {
    final list = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<PieChartSectionData> _buildPieSections() {
    return _sortedCategories.map((entry) {
      final pct = _monthlyTotal > 0 ? (entry.value / _monthlyTotal * 100) : 0.0;
      return PieChartSectionData(
        color: CategoryColors.getColor(entry.key),
        value: entry.value,
        title: '${pct.toStringAsFixed(1)}%',
        radius: 95,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_monthDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(monthLabel),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryTotals.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header total card ─────────────────────────────
                      _buildHeaderCard(monthLabel),
                      const SizedBox(height: 24),

                      // ── Category pie chart ────────────────────────────
                      _buildPieChartCard(theme),
                      const SizedBox(height: 24),

                      // ── Category legend ───────────────────────────────
                      _buildCategoryLegend(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(String monthLabel) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [_primaryColor, Color(0xFF4A6FA5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Monthly Total',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupees(_monthlyTotal),
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_expenseCount expense${_expenseCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(ThemeData theme) {
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
                Icon(Icons.pie_chart_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Category Breakdown',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sections: _buildPieSections(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 55,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by Category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._sortedCategories.map((entry) {
              final color = CategoryColors.getColor(entry.key);
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryDetailScreen(
                        category: entry.key,
                        selectedDate: _monthDate,
                        isMonthly: true,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        formatRupees(entry.value),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.grey[400]),
                    ],
                  ),
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
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No expenses for this month',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
