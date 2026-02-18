import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database_helper.dart';
import '../widgets/sidebar.dart';
import 'category_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Daily state ──────────────────────────────────────────────────────────
  Map<String, double> _categoryTotals = {};
  bool _isDailyLoading = true;
  double _totalExpenses = 0;

  // ── Monthly state (only reloads when month changes) ───────────────────────
  Map<String, double> _categoryTotalsMonth = {};
  bool _isMonthlyLoading = true;
  double _monthlyTotal = 0;

  // ── Date tracking ─────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();

  bool _isExporting = false;

  // Vibrant colors for pie chart
  final List<Color> _chartColors = [
    const Color(0xFF6366F1),
    const Color(0xFFEC4899),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
    const Color(0xFF14B8A6),
    const Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Called once on init and on manual refresh
  Future<void> _loadAllData() async {
    await Future.wait([_loadMonthlyData(), _loadDailyData()]);
  }

  // Loads monthly total + monthly pie chart — only called when month changes
  Future<void> _loadMonthlyData() async {
    setState(() => _isMonthlyLoading = true);

    final categoryTotalsMonth = await DatabaseHelper().getCategoryTotalsByMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    final monthlyTotal =
        await DatabaseHelper().getMonthlyTotal(_selectedDate);

    if (!mounted) return;
    setState(() {
      _categoryTotalsMonth = categoryTotalsMonth;
      _monthlyTotal = monthlyTotal;
      _isMonthlyLoading = false;
    });
  }

  // Loads daily total + daily pie chart — called on every date change
  Future<void> _loadDailyData() async {
    setState(() => _isDailyLoading = true);

    final categoryTotals =
        await DatabaseHelper().getCategoryTotalsByDate(_selectedDate);
    final dailyTotal = await DatabaseHelper().getDailyTotal(_selectedDate);

    if (!mounted) return;
    setState(() {
      _categoryTotals = categoryTotals;
      _totalExpenses = dailyTotal;
      _isDailyLoading = false;
    });
  }

  void _previousDay() {
    final newDate = _selectedDate.subtract(const Duration(days: 1));
    final monthChanged =
        newDate.month != _selectedDate.month || newDate.year != _selectedDate.year;
    setState(() => _selectedDate = newDate);
    _loadDailyData();
    if (monthChanged) _loadMonthlyData();
  }

  void _nextDay() {
    final today = DateTime.now();
    final nextDate = _selectedDate.add(const Duration(days: 1));
    if (nextDate.year < today.year ||
        (nextDate.year == today.year && nextDate.month < today.month) ||
        (nextDate.year == today.year &&
            nextDate.month == today.month &&
            nextDate.day <= today.day)) {
      final monthChanged = nextDate.month != _selectedDate.month ||
          nextDate.year != _selectedDate.year;
      setState(() => _selectedDate = nextDate);
      _loadDailyData();
      if (monthChanged) _loadMonthlyData();
    }
  }

  bool _isToday() {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  // ── Excel Export ──────────────────────────────────────────────────────────
  Future<void> _downloadExcel() async {
    setState(() => _isExporting = true);
    try {
      final expenses = await DatabaseHelper().getExpensesByMonth(
        _selectedDate.year,
        _selectedDate.month,
      );

      final excel = Excel.createExcel();
      final sheetName =
          DateFormat('MMMM_yyyy').format(_selectedDate);
      final Sheet sheet = excel[sheetName];
      excel.delete('Sheet1'); // remove default sheet

      // Header row
      final headers = ['Date', 'Item', 'Category', 'Amount (₹)'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Data rows
      for (var rowIdx = 0; rowIdx < expenses.length; rowIdx++) {
        final e = expenses[rowIdx];
        final rowData = [
          DateFormat('dd/MM/yyyy').format(DateTime.parse(e.date)),
          e.item,
          e.category,
          e.cost,
        ];
        for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
                columnIndex: colIdx, rowIndex: rowIdx + 1),
          );
          final val = rowData[colIdx];
          if (val is double) {
            cell.value = DoubleCellValue(val);
          } else {
            cell.value = TextCellValue(val.toString());
          }
        }
      }

      // Total row
      final totalRow = expenses.length + 1;
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: totalRow))
          .value = TextCellValue('TOTAL');
      final totalCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow),
      );
      totalCell.value = DoubleCellValue(_monthlyTotal);
      totalCell.cellStyle = CellStyle(bold: true);

      // Save file
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      final dir = await getTemporaryDirectory();
      final fileName =
          'expenses_${DateFormat('MMMM_yyyy').format(_selectedDate)}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share / save
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Expenses - ${DateFormat('MMMM yyyy').format(_selectedDate)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Monthly Total Card ────────────────────────────────────────
            _isMonthlyLoading
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildMonthlyTotalCard(),

            const SizedBox(height: 24),

            // ── Monthly Pie Chart ─────────────────────────────────────────
            _isMonthlyLoading
                ? const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildMonthlyChartSection(),

            const SizedBox(height: 32),

            // ── Date Navigation Bar ───────────────────────────────────────
            _buildDateNavigator(),

            const SizedBox(height: 24),

            // ── Daily Section ─────────────────────────────────────────────
            _isDailyLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildDailySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTotalCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Monthly Total',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${_monthlyTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChartSection() {
    if (_categoryTotalsMonth.isEmpty) {
      return _buildEmptyState('No expenses for this month');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with download button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expenses of Month',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Download Excel',
                    onPressed: _downloadExcel,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: _buildPieChartSections(
                _monthlyTotal,
                _categoryTotalsMonth,
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildLegend(_categoryTotalsMonth, isMonthly: true),
      ],
    );
  }

  Widget _buildDailySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Total Card
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Daily Total',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Daily Pie Chart
        if (_categoryTotals.isEmpty)
          _buildEmptyState('No expenses for this day')
        else ...[
          const Text(
            'Expenses by Category',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: _buildPieChartSections(
                  _totalExpenses,
                  _categoryTotals,
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildLegend(_categoryTotals, isMonthly: false),
        ],
      ],
    );
  }

  Widget _buildDateNavigator() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: _previousDay,
              tooltip: 'Previous Day',
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: _isToday() ? null : _nextDay,
              tooltip: 'Next Day',
              color: _isToday() ? Colors.grey[400] : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an expense to see the breakdown',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    double totalExpenses,
    Map<String, double> categoryTotals,
  ) {
    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    categoryTotals.forEach((category, amount) {
      final percentage =
          (totalExpenses > 0) ? (amount / totalExpenses * 100) : 0;

      sections.add(
        PieChartSectionData(
          color: _chartColors[colorIndex % _chartColors.length],
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return sections;
  }

  Widget _buildLegend(
    Map<String, double> categoryTotals, {
    required bool isMonthly,
  }) {
    List<Widget> legendItems = [];
    int colorIndex = 0;

    categoryTotals.forEach((category, amount) {
      legendItems.add(
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDetailScreen(
                  category: category,
                  selectedDate: _selectedDate,
                  isMonthly: isMonthly,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _chartColors[colorIndex % _chartColors.length],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      );
      colorIndex++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: legendItems,
        ),
      ),
    );
  }
}
