import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/expense_model.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<Expense> _parsedExpenses = [];
  String? _fileName;
  bool _isPicking = false;
  bool _isImporting = false;
  String? _errorMessage;

  // ── File Picker ───────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
      _parsedExpenses = [];
      _fileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final pickedFile = result.files.first;
      _fileName = pickedFile.name;

      final bytes = pickedFile.bytes ??
          await File(pickedFile.path!).readAsBytes();

      final excel = Excel.decodeBytes(bytes);
      final expenses = _parseExcel(excel);

      setState(() {
        _parsedExpenses = expenses;
        _isPicking = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to read file: $e';
        _isPicking = false;
      });
    }
  }

  // ── Parser ─────────────────────────────────────────────────────────────────
  // Reads every sheet. Skips rows that are headers, summaries, or blank.
  // Expected columns (matching the exporter): Date | Item | Category | Amount
  List<Expense> _parseExcel(Excel excel) {
    final List<Expense> result = [];
    final dateFormats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
    ];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;

      // Detect column indices from header row
      int dateCol = 0, itemCol = 1, categoryCol = 2, amountCol = 3;
      bool headerFound = false;

      for (int r = 0; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final cellValues = row
            .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
            .toList();

        // Identify header row
        if (!headerFound &&
            cellValues.any((v) => v == 'date') &&
            cellValues.any((v) => v == 'item' || v == 'category')) {
          dateCol = cellValues.indexWhere((v) => v == 'date');
          itemCol = cellValues.indexWhere((v) => v == 'item');
          categoryCol = cellValues.indexWhere((v) => v == 'category');
          amountCol = cellValues.indexWhere(
              (v) => v.contains('amount') || v == 'cost' || v == 'total');
          if (amountCol < 0) amountCol = 3;
          headerFound = true;
          continue;
        }

        if (!headerFound) continue;

        // Skip blank rows and summary rows
        if (row.length <= amountCol) continue;
        final rawDate = row[dateCol]?.value?.toString().trim() ?? '';
        final rawItem = row[itemCol]?.value?.toString().trim() ?? '';
        final rawCategory = row[categoryCol]?.value?.toString().trim() ?? '';
        final rawAmount = row[amountCol]?.value;

        if (rawDate.isEmpty || rawItem.isEmpty || rawCategory.isEmpty) continue;
        // Skip "TOTAL" and category-summary rows (no date parsable)
        if (rawItem.toUpperCase() == 'TOTAL' ||
            rawCategory.toUpperCase() == 'TOTAL') continue;

        // Parse date
        DateTime? parsedDate;
        for (final fmt in dateFormats) {
          try {
            parsedDate = fmt.parseStrict(rawDate);
            break;
          } catch (_) {}
        }
        if (parsedDate == null) continue;

        // Parse amount
        double amount = 0;
        if (rawAmount is DoubleCellValue) {
          amount = rawAmount.value.toDouble();
        } else if (rawAmount is IntCellValue) {
          amount = rawAmount.value.toDouble();
        } else {
          amount = double.tryParse(rawAmount?.toString() ?? '') ?? 0;
        }
        if (amount <= 0) continue;

        result.add(Expense(
          item: rawItem,
          category: rawCategory,
          cost: amount,
          date: parsedDate.toIso8601String(),
        ));
      }
    }

    // Sort by date
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // ── Import ────────────────────────────────────────────────────────────────
  Future<void> _import() async {
    if (_parsedExpenses.isEmpty) return;
    setState(() => _isImporting = true);

    try {
      final inserted =
          await DatabaseHelper().insertExpenseBatch(_parsedExpenses);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inserted == _parsedExpenses.length
                ? '✅ Imported $inserted expense${inserted == 1 ? '' : 's'} successfully!'
                : '✅ Imported $inserted new expense${inserted == 1 ? '' : 's'} '
                    '(${_parsedExpenses.length - inserted} skipped — already exist)',
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _parsedExpenses = [];
        _fileName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Expenses'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Instructions card ──────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'How to Import',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '• Pick a .xlsx file exported by this app\n'
                      '• Each sheet\'s rows are read automatically\n'
                      '• Duplicate entries (same date, item, category & amount) are skipped\n'
                      '• A preview of detected rows is shown before importing',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Pick button ────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isPicking || _isImporting ? null : _pickFile,
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(_isPicking ? 'Reading file…' : 'Choose .xlsx File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_fileName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fileName!,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[800], fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Preview ────────────────────────────────────────────────────
            if (_parsedExpenses.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Preview — ${_parsedExpenses.length} row${_parsedExpenses.length == 1 ? '' : 's'} detected',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      itemCount: _parsedExpenses.length > 50
                          ? 51
                          : _parsedExpenses.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        if (index == 50) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '+ ${_parsedExpenses.length - 50} more rows…',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          );
                        }
                        final e = _parsedExpenses[index];
                        final date = DateTime.parse(e.date);
                        return ListTile(
                          dense: true,
                          leading: Text(
                            DateFormat('dd MMM').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          title: Text(
                            e.item,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            e.category,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '₹${e.cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _import,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(
                  _isImporting
                      ? 'Importing…'
                      : 'Import ${_parsedExpenses.length} Expense${_parsedExpenses.length == 1 ? '' : 's'}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else if (!_isPicking && _fileName == null && _errorMessage == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file_outlined,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No file selected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Choose .xlsx File" to get started',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
