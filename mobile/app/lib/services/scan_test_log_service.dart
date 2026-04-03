import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_test_log_model.dart';

class ScanTestLogService {
  static const _keyLogs = 'scan_test_logs_v1';
  static const _maxEntries = 20;

  Future<List<ScanTestLogModel>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyLogs) ?? <String>[];
    return raw
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .map(ScanTestLogModel.fromJson)
        .toList();
  }

  Future<List<ScanTestLogModel>> addLog(ScanTestLogModel log) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadLogs();
    final updated = [log, ...existing].take(_maxEntries).toList();
    await prefs.setStringList(
      _keyLogs,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
    return updated;
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogs);
  }
}
