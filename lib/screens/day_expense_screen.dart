import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/expense_model.dart';
import '../utils/category_colors.dart';
import '../utils/currency_formatter.dart';
import 'category_detail_screen.dart';

/// Shown when the user taps a day bar in the Monthly Analysis bar chart.
/// Displays all expenses for that day, with a sorted category breakdown.
class DayExpenseScreen extends StatefulWidget {
  final int year;
  final int month;
  final int day;

  const DayExpenseScreen({
    super.key,
    required this.year,
    required this.month,
    required this.day,
  });

  @override
  State<DayExpenseScreen> createState() => _DayExpenseScreenState();
}

class _DayExpenseScreenState extends State<DayExpenseScreen> {
  static const _primaryColor = Color(0xFF30437A);

  List<Expense> _expenses = [];
  Map<String, double> _categoryTotals = {};
  bool _isLoading = true;
  double _total = 0;

  late final DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.year, widget.month, widget.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final expenses = await DatabaseHelper().getExpensesByDate(_date);
    final Map<String, double> cats = {};
    double total = 0;
    for (final e in expenses) {
      cats[e.category] = (cats[e.category] ?? 0) + e.cost;
      total += e.cost;
    }
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _categoryTotals = cats;
      _total = total;
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
      final pct = _total > 0 ? (entry.value / _total * 100) : 0.0;
      return PieChartSectionData(
        color: CategoryColors.getColor(entry.key),
        value: entry.value,
        title: '${pct.toStringAsFixed(1)}%',
        radius: 90,
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
    final dateLabel = DateFormat('dd MMMM yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header total card ─────────────────────────────
                      _buildHeaderCard(dateLabel),
                      const SizedBox(height: 24),

                      // ── Category pie chart ────────────────────────────
                      if (_categoryTotals.isNotEmpty) ...[
                        _buildPieChartCard(theme),
                        const SizedBox(height: 24),
                      ],

                      // ── Category legend / list ────────────────────────
                      _buildCategoryLegend(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(String dateLabel) {
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
              dateLabel,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daily Total',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupees(_total),
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_expenses.length} expense${_expenses.length == 1 ? '' : 's'}',
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
              height: 260,
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
                        selectedDate: _date,
                        isMonthly: false,
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
              'No expenses on this day',
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
