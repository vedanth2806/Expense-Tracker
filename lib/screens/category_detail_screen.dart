import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/expense_model.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final DateTime selectedDate;
  final bool isMonthly;

  const CategoryDetailScreen({
    Key? key,
    required this.category,
    required this.selectedDate,
    this.isMonthly = false,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    List<Expense> filtered;

    if (widget.isMonthly) {
      // Fetch all expenses for the month, then filter by category
      final allMonthly = await DatabaseHelper().getExpensesByMonth(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
      filtered = allMonthly
          .where((e) => e.category == widget.category)
          .toList();
    } else {
      // Fetch expenses for the specific day, then filter by category
      final allDaily =
          await DatabaseHelper().getExpensesByDate(widget.selectedDate);
      filtered =
          allDaily.where((e) => e.category == widget.category).toList();
    }

    final total = filtered.fold<double>(0, (sum, e) => sum + e.cost);

    setState(() {
      _expenses = filtered;
      _total = total;
      _isLoading = false;
    });
  }

  String get _headerDateLabel {
    if (widget.isMonthly) {
      return DateFormat('MMMM yyyy').format(widget.selectedDate);
    }
    return DateFormat('dd MMM yyyy').format(widget.selectedDate);
  }

  String get _periodLabel => widget.isMonthly ? 'This Month' : 'This Day';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        elevation: 0,
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
                            horizontal: 10, vertical: 4),
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
                        '₹${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_expenses.length} ${_expenses.length == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final expenseDate =
                                DateTime.parse(expense.date);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
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
                                  // For monthly view show full date; for daily show time
                                  widget.isMonthly
                                      ? DateFormat('dd MMM yyyy')
                                          .format(expenseDate)
                                      : DateFormat('hh:mm a')
                                          .format(expenseDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: Text(
                                  '₹${expense.cost.toStringAsFixed(2)}',
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
              ],
            ),
    );
  }
}
