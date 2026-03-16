import 'dart:io';
import 'package:expense_app/widgets/upi_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database_helper.dart';
import '../widgets/sidebar.dart';
import '../utils/category_colors.dart';
import 'category_detail_screen.dart';
import '../widgets/sidebar.dart';

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
    final monthlyTotal = await DatabaseHelper().getMonthlyTotal(_selectedDate);

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

    final categoryTotals = await DatabaseHelper().getCategoryTotalsByDate(
      _selectedDate,
    );
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
        newDate.month != _selectedDate.month ||
        newDate.year != _selectedDate.year;
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
      final monthChanged =
          nextDate.month != _selectedDate.month ||
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

  // ── Excel Export (all months, one sheet each) ─────────────────────────────
  Future<void> _downloadExcel() async {
    setState(() => _isExporting = true);
    try {
      final allMonths = await DatabaseHelper().getAllExpenseMonths();
      if (allMonths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No expense data to export.')),
          );
        }
        return;
      }

      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      for (final monthDate in allMonths) {
        final expenses = await DatabaseHelper().getExpensesByMonth(
          monthDate.year,
          monthDate.month,
        );
        if (expenses.isEmpty) continue;

        final sheetName = DateFormat('MMM_yyyy').format(monthDate);
        final Sheet sheet = excel[sheetName];

        // ── Header row ───────────────────────────────────────────────────
        final headers = ['Date', 'Item', 'Category', 'Amount (₹)'];
        for (var i = 0; i < headers.length; i++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = CellStyle(bold: true);
        }

        // ── Data rows ─────────────────────────────────────────────────────
        double monthTotal = 0;
        final Map<String, double> catTotals = {};

        for (var rowIdx = 0; rowIdx < expenses.length; rowIdx++) {
          final e = expenses[rowIdx];
          monthTotal += e.cost;
          catTotals[e.category] = (catTotals[e.category] ?? 0) + e.cost;

          final rowData = [
            DateFormat('dd/MM/yyyy').format(DateTime.parse(e.date)),
            e.item,
            e.category,
            e.cost,
          ];
          for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIdx,
                rowIndex: rowIdx + 1,
              ),
            );
            final val = rowData[colIdx];
            if (val is double) {
              cell.value = DoubleCellValue(val);
            } else {
              cell.value = TextCellValue(val.toString());
            }
          }
        }

        // ── Blank separator ───────────────────────────────────────────────
        int nextRow = expenses.length + 2;

        // ── Category summary header ───────────────────────────────────────
        final catHeaderDate = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow),
        );
        catHeaderDate.value = TextCellValue('Category');
        catHeaderDate.cellStyle = CellStyle(bold: true);

        final catHeaderAmt = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow),
        );
        catHeaderAmt.value = TextCellValue('Total (₹)');
        catHeaderAmt.cellStyle = CellStyle(bold: true);
        nextRow++;

        // ── Per-category rows ─────────────────────────────────────────────
        for (final entry in catTotals.entries) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow),
              )
              .value = TextCellValue(
            entry.key,
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow),
              )
              .value = DoubleCellValue(
            entry.value,
          );
          nextRow++;
        }

        // ── Grand total row ───────────────────────────────────────────────
        final totalLabelCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow),
        );
        totalLabelCell.value = TextCellValue('TOTAL');
        totalLabelCell.cellStyle = CellStyle(bold: true);

        final totalAmtCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow),
        );
        totalAmtCell.value = DoubleCellValue(monthTotal);
        totalAmtCell.cellStyle = CellStyle(bold: true);
      }

      // ── Save & share ──────────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      final dir = await getTemporaryDirectory();
      const fileName = 'expenses_all_months.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject:
            'All Expense Data — ${allMonths.length} month${allMonths.length == 1 ? '' : 's'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  : _buildMonthlyTotalCard(theme),

              const SizedBox(height: 24),

              // ── Monthly Pie Chart ─────────────────────────────────────────
              _isMonthlyLoading
                  ? const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildMonthlyChartSection(theme),

              const SizedBox(height: 32),

              // ── Date Navigation Bar ───────────────────────────────────────
              _buildDateNavigator(theme),

              const SizedBox(height: 24),

              // ── Daily Section ─────────────────────────────────────────────
              _isDailyLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildDailySection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyTotalCard(ThemeData theme) {
    return Row(
      children: [
        // ✅ Use IconButton instead of DrawerTile
        // Material(
        //   color: Color(0xFF30437A),
        //   child: InkWell(
        //     borderRadius: BorderRadius.circular(16),
        //     onTap: () {
        //       // ✅ Navigate WITHOUT popping drawer context
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => const UpiScannerScreen(),
        //         ),
        //       );
        //     },
        //     child: Container(
        //       padding: const EdgeInsets.all(16),
        //       decoration: BoxDecoration(
        //         color: Colors.white.withOpacity(0.1),
        //         borderRadius: BorderRadius.circular(16),
        //       ),
        //       child: Column(
        //         mainAxisSize: MainAxisSize.min,
        //         children: [
        //           Icon(
        //             Icons.qr_code_scanner_rounded,
        //             color: Colors.white,
        //             size: 28,
        //           ),
        //           const SizedBox(height: 4),
        //           const Text(
        //             'Scan QR',
        //             style: TextStyle(
        //               fontSize: 12,
        //               color: Colors.white70,
        //               fontWeight: FontWeight.w500,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
        // ),

        // const SizedBox(width: 16), // ✅ Spacing
        // Your existing card
        Expanded(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Monthly Total',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_monthlyTotal.toStringAsFixed(2)}',
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
        ),
      ],
    );
  }

  Widget _buildMonthlyChartSection(ThemeData theme) {
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
            Text('Expenses of Month', style: theme.textTheme.titleLarge),
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
                      backgroundColor: const Color(0xFF30437A).withOpacity(0.1),
                      foregroundColor: const Color(0xFF30437A),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 16),
        // Monthly Pie Chart
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

  Widget _buildDailySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Total Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                const Text(
                  'Daily Total',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 40,
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
          Text('Expenses by Category', style: theme.textTheme.titleLarge),
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

  Widget _buildDateNavigator(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _previousDay,
              tooltip: 'Previous Day',
              color: const Color(0xFF30437A),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30437A),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              onPressed: _isToday() ? null : _nextDay,
              tooltip: 'Next Day',
              color: _isToday() ? Colors.grey[400] : const Color(0xFF30437A),
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
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an expense to see the breakdown',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
    return categoryTotals.entries.map((entry) {
      final percentage = totalExpenses > 0
          ? (entry.value / totalExpenses * 100)
          : 0.0;
      return PieChartSectionData(
        color: CategoryColors.getColor(entry.key),
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(
    Map<String, double> categoryTotals, {
    required bool isMonthly,
  }) {
    final items = categoryTotals.entries.map((entry) {
      final color = CategoryColors.getColor(entry.key);
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDetailScreen(
                category: entry.key,
                selectedDate: _selectedDate,
                isMonthly: isMonthly,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
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
                '₹${entry.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF30437A),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      ),
    );
  }
}
