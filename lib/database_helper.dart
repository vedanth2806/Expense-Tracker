import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/expense_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expenses.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item TEXT NOT NULL,
        category TEXT NOT NULL,
        cost REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  // Insert a new expense
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  // Get all expenses
  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    return List.generate(maps.length, (i) {
      return Expense.fromMap(maps[i]);
    });
  }

  // Delete an expense
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get expenses grouped by category with totals
  Future<Map<String, double>> getCategoryTotals() async {
    final expenses = await getExpenses();
    Map<String, double> categoryTotals = {};
    
    for (var expense in expenses) {
      if (categoryTotals.containsKey(expense.category)) {
        categoryTotals[expense.category] = 
            categoryTotals[expense.category]! + expense.cost;
      } else {
        categoryTotals[expense.category] = expense.cost;
      }
    }
    
    return categoryTotals;
  }

  // Get expenses for a specific date
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final expenses = await getExpenses();
    final dateStr = date.toIso8601String().split('T')[0];
    
    return expenses.where((expense) {
      final expenseDate = expense.date.split('T')[0];
      return expenseDate == dateStr;
    }).toList();
  }

  // Get total expenses for a specific date
  Future<double> getDailyTotal(DateTime date) async {
    final dailyExpenses = await getExpensesByDate(date);
    return dailyExpenses.fold<double>(0.0, (sum, expense) => sum + expense.cost);
  }

  // Get total expenses for a specific month
  Future<double> getMonthlyTotal(DateTime date) async {
    final expenses = await getExpenses();
    final targetMonth = date.month;
    final targetYear = date.year;
    
    double total = 0;
    for (var expense in expenses) {
      final expenseDate = DateTime.parse(expense.date);
      if (expenseDate.month == targetMonth && expenseDate.year == targetYear) {
        total += expense.cost;
      }
    }
    
    return total;
  }

  // Get category totals for a specific date
  Future<Map<String, double>> getCategoryTotalsByDate(DateTime date) async {
    final dailyExpenses = await getExpensesByDate(date);
    Map<String, double> categoryTotals = {};
    
    for (var expense in dailyExpenses) {
      if (categoryTotals.containsKey(expense.category)) {
        categoryTotals[expense.category] = 
            categoryTotals[expense.category]! + expense.cost;
      } else {
        categoryTotals[expense.category] = expense.cost;
      }
    }
    
    return categoryTotals;
  }
}
