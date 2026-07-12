import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/expense_model.dart';

class BackupService {
  static const _prefLastVersion = 'last_app_version';
  static const _prefLastBackupPath = 'last_backup_path';
  static const _prefLastBackupTime = 'last_backup_time';
  static const _backupPrefix = 'expense_backup_';

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Silently exports all data to Downloads.
  /// Called on app pause / detach. Swallows all errors gracefully.
  static Future<void> silentExportToDownloads() async {
    try {
      await _exportToDownloads();
    } catch (e) {
      debugPrint('[BackupService] Silent export failed: $e');
    }
  }

  /// Checks if the app version changed (i.e., an update was installed).
  /// Returns the path of the latest backup if one was found, otherwise null.
  static Future<String?> checkForUpdateRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final lastBuild = prefs.getInt(_prefLastVersion) ?? 0;

      if (lastBuild > 0 && currentBuild > lastBuild) {
        // Version was upgraded — look for a backup
        final backupPath = await _findLatestBackupInDownloads();
        if (backupPath != null) {
          return backupPath;
        }
      }

      // Save current version for next launch
      await prefs.setInt(_prefLastVersion, currentBuild);
    } catch (e) {
      debugPrint('[BackupService] Version check failed: $e');
    }
    return null;
  }

  /// Imports expenses from the given Excel file path.
  /// Returns the number of newly inserted rows.
  static Future<int> importFromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final expenses = _parseExcel(excel);
    return await DatabaseHelper().insertExpenseBatch(expenses);
  }

  /// Returns a human-readable last backup time, or null if never backed up.
  static Future<String?> getLastBackupDescription() async {
    final prefs = await SharedPreferences.getInstance();
    final isoTime = prefs.getString(_prefLastBackupTime);
    if (isoTime == null) return null;
    final dt = DateTime.tryParse(isoTime);
    if (dt == null) return null;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  // ── Internal helpers ─────────────────────────────────────────────────────────

  static Future<void> _exportToDownloads() async {
    // Check (and request) storage permission
    if (Platform.isAndroid) {
      final sdkInt = _androidSdkVersion();
      if (sdkInt < 30) {
        final status = await Permission.storage.request();
        if (!status.isGranted) return;
      }
    }

    final allMonths = await DatabaseHelper().getAllExpenseMonths();
    if (allMonths.isEmpty) return;

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

      final headers = ['Date', 'Item', 'Category', 'Amount'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

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
          final cell = sheet.cell(CellIndex.indexByColumnRow(
              columnIndex: colIdx, rowIndex: rowIdx + 1));
          final val = rowData[colIdx];
          cell.value =
              val is double ? DoubleCellValue(val) : TextCellValue(val.toString());
        }
      }

      // Category summary
      int nextRow = expenses.length + 2;
      final catH0 = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow));
      catH0.value = TextCellValue('Category');
      catH0.cellStyle = CellStyle(bold: true);
      final catH1 = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow));
      catH1.value = TextCellValue('Total');
      catH1.cellStyle = CellStyle(bold: true);
      nextRow++;

      for (final entry in catTotals.entries) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow))
            .value = TextCellValue(entry.key);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow))
            .value = DoubleCellValue(entry.value);
        nextRow++;
      }

      final totalLabel = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow));
      totalLabel.value = TextCellValue('TOTAL');
      totalLabel.cellStyle = CellStyle(bold: true);
      final totalAmt = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: nextRow));
      totalAmt.value = DoubleCellValue(monthTotal);
      totalAmt.cellStyle = CellStyle(bold: true);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await _getDownloadsDirectory();
    if (dir == null) return;

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '$_backupPrefix$timestamp.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Save metadata
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastBackupPath, file.path);
    await prefs.setString(_prefLastBackupTime, DateTime.now().toIso8601String());

    debugPrint('[BackupService] Saved backup to ${file.path}');

    // Clean up old backups (keep latest 5)
    await _pruneOldBackups(dir, keepCount: 5);
  }

  static Future<String?> _findLatestBackupInDownloads() async {
    final dir = await _getDownloadsDirectory();
    if (dir == null) return null;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(_backupPrefix) && f.path.endsWith('.xlsx'))
        .toList();

    if (files.isEmpty) return null;

    // Sort descending by name (timestamps are in name)
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.first.path;
  }

  static Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // External storage Downloads on Android
        final extDir = await getExternalStorageDirectory();
        if (extDir == null) return null;
        // Walk up to reach /sdcard/Download
        final parts = extDir.path.split('/');
        final androidIdx = parts.indexOf('Android');
        if (androidIdx > 0) {
          final downloadPath = '${parts.sublist(0, androidIdx).join('/')}/Download';
          final downloadDir = Directory(downloadPath);
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          return downloadDir;
        }
        return extDir;
      }
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('[BackupService] Could not get downloads dir: $e');
      return null;
    }
  }

  static Future<void> _pruneOldBackups(Directory dir, {int keepCount = 5}) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(_backupPrefix) && f.path.endsWith('.xlsx'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (int i = keepCount; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  static List<Expense> _parseExcel(Excel excel) {
    final List<Expense> result = [];
    final dateFormats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
    ];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;

      int dateCol = 0, itemCol = 1, categoryCol = 2, amountCol = 3;
      bool headerFound = false;

      for (int r = 0; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final cellValues = row
            .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
            .toList();

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
        if (row.length <= amountCol) continue;

        final rawDate = row[dateCol]?.value?.toString().trim() ?? '';
        final rawItem = row[itemCol]?.value?.toString().trim() ?? '';
        final rawCategory = row[categoryCol]?.value?.toString().trim() ?? '';
        final rawAmount = row[amountCol]?.value;

        if (rawDate.isEmpty || rawItem.isEmpty || rawCategory.isEmpty) continue;
        if (rawItem.toUpperCase() == 'TOTAL' ||
            rawCategory.toUpperCase() == 'TOTAL') {
          continue;
        }

        DateTime? parsedDate;
        for (final fmt in dateFormats) {
          try {
            parsedDate = fmt.parseStrict(rawDate);
            break;
          } catch (_) {}
        }
        if (parsedDate == null) continue;

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

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  static int _androidSdkVersion() {
    // Flutter doesn't expose SDK version directly; use a safe default.
    // Returning 29 means we request storage permission on Android 9–11.
    return 29;
  }
}
