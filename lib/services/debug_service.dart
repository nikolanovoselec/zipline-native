import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugService {
  static final DebugService _instance = DebugService._internal();
  factory DebugService() => _instance;
  DebugService._internal();

  final List<DebugLog> _logs = [];
  static const int _maxLogs = 5000; // Keep 5000 logs instead of 1000
  SharedPreferences? _prefs;
  bool _debugLogsEnabled = false; // Default to disabled

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _debugLogsEnabled = _prefs?.getBool('debug_logs_enabled') ?? false;
    await _loadLogs();
    // Only log if debugging is enabled
    if (_debugLogsEnabled) {
      // Temporarily bypass the check for this initialization log
      final timestamp = DateTime.now().toIso8601String();
      final log = DebugLog(
        timestamp: timestamp,
        category: 'DEBUG',
        level: 'INFO',
        message: 'Debug service initialized',
        data: {'totalLogs': _logs.length, 'logsEnabled': _debugLogsEnabled},
      );
      _logs.add(log);
      if (_logs.length > _maxLogs) {
        _logs.removeAt(0);
      }
      // Console output disabled in production
      _saveLogs();
    }
  }

  void log(String category, String message,
      {Map<String, dynamic>? data, String level = 'INFO'}) {
    if (!_debugLogsEnabled) return; // Skip logging if disabled

    final timestamp = DateTime.now().toIso8601String();
    final log = DebugLog(
      timestamp: timestamp,
      category: category,
      level: level,
      message: message,
      data: data,
    );

    _logs.add(log);

    // Keep only the last 5000 logs
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Console output disabled in production

    // Save logs persistently
    _saveLogs();
  }

  Future<void> _saveLogs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final logsJson = _logs
          .map((log) => {
                'timestamp': log.timestamp,
                'category': log.category,
                'level': log.level,
                'message': log.message,
                'data': log.data,
              })
          .toList();
      await _prefs!.setString('debug_logs', jsonEncode(logsJson));
    } catch (e) {
      // Error logging disabled in production
    }
  }

  Future<void> _loadLogs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final logsString = _prefs!.getString('debug_logs');
      if (logsString != null) {
        final logsJson = jsonDecode(logsString) as List;
        _logs.clear();
        for (final logMap in logsJson) {
          _logs.add(DebugLog(
            timestamp: logMap['timestamp'],
            category: logMap['category'],
            level: logMap['level'],
            message: logMap['message'],
            data: logMap['data'],
          ));
        }
        // Loading notification disabled in production
      }
    } catch (e) {
      // Error logging disabled in production
    }
  }

  void logAuth(String message,
      {Map<String, dynamic>? data, String level = 'INFO'}) {
    log('AUTH', message, data: data, level: level);
  }

  void logUpload(String message,
      {Map<String, dynamic>? data, String level = 'INFO'}) {
    log('UPLOAD', message, data: data, level: level);
  }

  void logIntent(String message,
      {Map<String, dynamic>? data, String level = 'INFO'}) {
    log('INTENT', message, data: data, level: level);
  }

  void logHttp(String message,
      {Map<String, dynamic>? data, String level = 'INFO'}) {
    log('HTTP', message, data: data, level: level);
  }

  void logError(String category, String message,
      {dynamic error,
      StackTrace? stackTrace,
      Map<String, dynamic>? data}) {
    final combinedData = <String, dynamic>{};
    if (data != null && data.isNotEmpty) {
      combinedData.addAll(data);
    }
    if (error != null) {
      combinedData['error'] = error.toString();
    }
    if (stackTrace != null) {
      combinedData['stackTrace'] = stackTrace.toString();
    }
    log(category, message, data: combinedData, level: 'ERROR');
  }

  List<DebugLog> getLogs({String? category, String? level}) {
    var filteredLogs = _logs;

    if (category != null) {
      filteredLogs =
          filteredLogs.where((log) => log.category == category).toList();
    }

    if (level != null) {
      filteredLogs = filteredLogs.where((log) => log.level == level).toList();
    }

    return filteredLogs;
  }

  String getLogsAsJson({String? category, String? level}) {
    final logs = getLogs(category: category, level: level);
    final logsMap = logs.map((log) => log.toMap()).toList();
    return jsonEncode({
      'exportTimestamp': DateTime.now().toIso8601String(),
      'totalLogs': logs.length,
      'filters': {
        'category': category,
        'level': level,
      },
      'logs': logsMap,
    });
  }

  Future<File> exportLogsToFile({String? category, String? level}) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'zipline_debug_logs_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    final jsonData = getLogsAsJson(category: category, level: level);
    await file.writeAsString(jsonData);

    return file;
  }

  void clearLogs() {
    _logs.clear();
    // Only log if debugging is enabled
    if (_debugLogsEnabled) {
      log('DEBUG', 'Debug logs cleared');
    }
    // Always save to persist the clear operation
    _saveLogs();
  }

  Map<String, int> getLogStats() {
    final stats = <String, int>{};
    for (final log in _logs) {
      final key = '${log.category}_${log.level}';
      stats[key] = (stats[key] ?? 0) + 1;
    }
    return stats;
  }

  List<String> getUniqueCategories() {
    return _logs.map((log) => log.category).toSet().toList()..sort();
  }

  List<String> getUniqueLevels() {
    return _logs.map((log) => log.level).toSet().toList()..sort();
  }

  bool get debugLogsEnabled => _debugLogsEnabled;

  Future<void> setDebugLogsEnabled(bool enabled) async {
    _debugLogsEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('debug_logs_enabled', enabled);

    // Log this change (will only show if logging was enabled)
    if (enabled) {
      log('DEBUG', 'Debug logging enabled');
    }
  }
}

class DebugLog {
  final String timestamp;
  final String category;
  final String level;
  final String message;
  final Map<String, dynamic>? data;

  DebugLog({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'category': category,
      'level': level,
      'message': message,
      'data': data,
    };
  }

  factory DebugLog.fromMap(Map<String, dynamic> map) {
    return DebugLog(
      timestamp: map['timestamp'],
      category: map['category'],
      level: map['level'],
      message: map['message'],
      data: map['data'],
    );
  }
}
