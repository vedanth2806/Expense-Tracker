import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/expense_model.dart';
import '../utils/currency_formatter.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final DateTime selectedDate;
  final bool isMonthly;

  /// When true, shows all expenses for the entire year of [selectedDate].
  final bool isYearly;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.selectedDate,
    this.isMonthly = false,
    this.isYearly = false,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Expense> _expenses = [];
  List<Expense> _allExpenses = [];
  bool _isLoading = true;
  double _total = 0;

  int? _selectedFilterMonth;
  String _currentSort = 'Date (Newest)';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    List<Expense> fetched;

    if (widget.isYearly) {
      fetched = await DatabaseHelper().getExpensesByCategoryAndYear(
        widget.category,
        widget.selectedDate.year,
      );
    } else if (widget.isMonthly) {
      // Fetch all expenses for the month, then filter by category
      final allMonthly = await DatabaseHelper().getExpensesByMonth(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
      fetched = allMonthly.where((e) => e.category == widget.category).toList();
    } else {
      // Fetch expenses for the specific day, then filter by category
      final allDaily = await DatabaseHelper().getExpensesByDate(
        widget.selectedDate,
      );
      fetched = allDaily.where((e) => e.category == widget.category).toList();
    }

    _allExpenses = fetched;
    _applyFiltersAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFiltersAndSort() {
    List<Expense> filtered = List.from(_allExpenses);

    if (widget.isYearly && _selectedFilterMonth != null) {
      filtered = filtered.where((e) {
        final d = DateTime.parse(e.date);
        return d.month == _selectedFilterMonth;
      }).toList();
    }

    filtered.sort((a, b) {
      if (_currentSort == 'Cost (High to Low)') {
        return b.cost.compareTo(a.cost);
      } else if (_currentSort == 'Cost (Low to High)') {
        return a.cost.compareTo(b.cost);
      } else if (_currentSort == 'Date (Oldest)') {
        return a.date.compareTo(b.date);
      } else {
        return b.date.compareTo(a.date);
      }
    });

    final total = filtered.fold<double>(0, (sum, e) => sum + e.cost);

    setState(() {
      _expenses = filtered;
      _total = total;
    });
  }

  String get _headerDateLabel {
    if (widget.isYearly) {
      return widget.selectedDate.year.toString();
    }
    if (widget.isMonthly) {
      return DateFormat('MMMM yyyy').format(widget.selectedDate);
    }
    return DateFormat('dd MMM yyyy').format(widget.selectedDate);
  }

  String get _periodLabel {
    if (widget.isYearly) return 'This Year';
    return widget.isMonthly ? 'This Month' : 'This Day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        elevation: 0,
        actions: [
          if (widget.isYearly)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterBottomSheet,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _periodLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _headerDateLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Total Spent',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
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
                    ],
                  ),
                ),

                // Sort and Item Count Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_expenses.length} Transactions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.sort, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _currentSort,
                            underline: const SizedBox(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                            items:
                                [
                                      'Date (Newest)',
                                      'Date (Oldest)',
                                      'Cost (High to Low)',
                                      'Cost (Low to High)',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _currentSort = val);
                                _applyFiltersAndSort();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Expense List
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses in this category',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Scrollbar(
                          thickness: 15,
                          interactive: true,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final expense = _expenses[index];
                              final expenseDate = DateTime.parse(expense.date);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.receipt,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    expense.item,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    // Yearly/monthly: show full date; daily: show time
                                    (widget.isYearly || widget.isMonthly)
                                        ? DateFormat(
                                            'dd MMM yyyy',
                                          ).format(expenseDate)
                                        : DateFormat(
                                            'hh:mm a',
                                          ).format(expenseDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  trailing: Text(
                                    formatRupees(expense.cost),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (widget.isYearly) ...[
                    const Text(
                      'Month',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: _selectedFilterMonth,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Months'),
                        ),
                        ...List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(
                              DateFormat(
                                'MMMM',
                              ).format(DateTime(2000, index + 1)),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() => _selectedFilterMonth = val);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFiltersAndSort();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
