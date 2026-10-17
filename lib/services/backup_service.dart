import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import '../zainnoto/db/zainnoto_database.dart';

/// Thrown when a backup file is invalid or cannot be restored.
class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of validating a backup payload before restoring.
class BackupValidation {
  const BackupValidation._({
    this.error,
    this.tableCounts = const {},
    this.exportedAt,
  });

  factory BackupValidation.invalid(String error) =>
      BackupValidation._(error: error);

  factory BackupValidation.valid({
    required Map<String, int> tableCounts,
    String? exportedAt,
  }) =>
      BackupValidation._(tableCounts: tableCounts, exportedAt: exportedAt);

  final String? error;
  final Map<String, int> tableCounts;
  final String? exportedAt;

  bool get isValid => error == null;

  int get totalRows =>
      tableCounts.values.fold(0, (sum, count) => sum + count);
}

/// Result of a successful restore.
class RestoreResult {
  const RestoreResult({
    required this.safetyBackupPath,
    required this.finflowCounts,
    required this.zainnotoCounts,
  });

  /// Path of the automatic backup taken right before overwriting data.
  final String safetyBackupPath;

  final Map<String, int> finflowCounts;
  final Map<String, int> zainnotoCounts;

  int get finflowRows =>
      finflowCounts.values.fold(0, (sum, count) => sum + count);

  int get zainnotoRows =>
      zainnotoCounts.values.fold(0, (sum, count) => sum + count);
}

/// Exports and imports the whole app data as a single JSON file:
/// personal mode (`finflow.db`), group mode (`zainnoto.db`) and preferences
/// (theme colors, etc.).
///
/// The database openers and temp directory are injectable so the service can
/// be unit-tested with in-memory databases.
class BackupService {
  BackupService({
    Future<Database> Function()? openFinflow,
    Future<Database> Function()? openZainnoto,
    Future<Directory> Function()? tempDirectory,
  })  : _openFinflow = openFinflow ?? (() => DatabaseHelper.instance.database),
        _openZainnoto = openZainnoto ?? (() => ZainNotoDatabase.instance.open()),
        _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final Future<Database> Function() _openFinflow;
  final Future<Database> Function() _openZainnoto;
  final Future<Directory> Function() _tempDirectory;

  static const String appMarker = 'takaranoto';
  static const int backupVersion = 1;

  /// Personal-mode tables, parents first (insert order).
  static const List<String> finflowTables = [
    'categories',
    'transactions',
    'budgets',
    'savings_goals',
  ];

  /// Group-mode tables, parents first (insert order).
  static const List<String> zainnotoTables = [
    'groups',
    'members',
    'dues_plans',
    'periods',
    'charges',
    'transactions',
    'allocations',
    'member_credits',
    'audit_log',
  ];

  // ─── Export ─────────────────────────────────────────────────────────────────

  /// Collects the whole app data into a JSON-encodable payload.
  Future<Map<String, Object?>> collect() async {
    return <String, Object?>{
      'app': appMarker,
      'version': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'finflow': await _dumpTables(await _openFinflow(), finflowTables),
      'zainnoto': await _dumpTables(await _openZainnoto(), zainnotoTables),
      'prefs': await _dumpPrefs(),
    };
  }

  /// Writes the payload to a temp file and returns it.
  Future<File> exportToFile() async {
    if (kIsWeb) {
      throw BackupException('Backup tidak didukung di web.');
    }
    final payload = await collect();
    return _writePayloadFile(payload, prefix: 'takaranoto-backup');
  }

  /// Exports and opens the system share sheet with the backup file.
  Future<void> shareBackup() async {
    final file = await exportToFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: p.basename(file.path),
      ),
    );
  }

  Future<Map<String, List<Map<String, Object?>>>> _dumpTables(
    Database db,
    List<String> tables,
  ) async {
    final dump = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      dump[table] = await db.query(table);
    }
    return dump;
  }

  Future<Map<String, Object?>> _dumpPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dump = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      dump[key] = prefs.get(key);
    }
    return dump;
  }

  // ─── Validation ─────────────────────────────────────────────────────────────

  BackupValidation validate(Map<String, Object?> data) {
    if (data['app'] != appMarker) {
      return BackupValidation.invalid(
        'File ini bukan backup TakaraNoto.',
      );
    }
    final version = data['version'];
    if (version is! int || version < 1) {
      return BackupValidation.invalid('File backup tidak memiliki versi.');
    }
    if (version > backupVersion) {
      return BackupValidation.invalid(
        'Versi backup ($version) lebih baru dari yang didukung aplikasi. '
        'Perbarui aplikasi terlebih dahulu.',
      );
    }
    final finflow = data['finflow'];
    final zainnoto = data['zainnoto'];
    if (finflow is! Map || zainnoto is! Map) {
      return BackupValidation.invalid('Struktur file backup tidak lengkap.');
    }

    final counts = <String, int>{};
    for (final table in finflowTables) {
      counts[table] = _rowCount(finflow[table]);
    }
    for (final table in zainnotoTables) {
      counts[table] = _rowCount(zainnoto[table]);
    }

    final exportedAt = data['exportedAt'];
    return BackupValidation.valid(
      tableCounts: counts,
      exportedAt: exportedAt is String ? exportedAt : null,
    );
  }

  int _rowCount(Object? rows) => rows is List ? rows.length : 0;

  // ─── Restore ────────────────────────────────────────────────────────────────

  /// Restores data from a previously decoded backup payload.
  ///
  /// A safety copy of the current data is written to a temp file first.
  /// Rows are deleted children-first and inserted parents-first inside a
  /// single database transaction per database, so foreign keys stay valid.
  Future<RestoreResult> restoreFromJson(Map<String, Object?> data) async {
    final validation = validate(data);
    if (!validation.isValid) {
      throw BackupException(validation.error!);
    }

    final safety = await _writePayloadFile(
      await collect(),
      prefix: 'pra-restore',
    );

    final finflowCounts = await _restoreTables(
      await _openFinflow(),
      finflowTables,
      data['finflow'] as Map,
    );
    final zainnotoCounts = await _restoreTables(
      await _openZainnoto(),
      zainnotoTables,
      data['zainnoto'] as Map,
    );
    await _restorePrefs(data['prefs']);

    return RestoreResult(
      safetyBackupPath: safety.path,
      finflowCounts: finflowCounts,
      zainnotoCounts: zainnotoCounts,
    );
  }

  /// Reads a backup file from disk and restores it.
  Future<RestoreResult> restoreFromFile(String path) async {
    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw BackupException('Isi file bukan format backup yang dikenal.');
    }
    return restoreFromJson(Map<String, Object?>.from(decoded));
  }

  Future<Map<String, int>> _restoreTables(
    Database db,
    List<String> tables,
    Map data,
  ) async {
    final counts = <String, int>{};
    await db.transaction((txn) async {
      for (final table in tables.reversed) {
        await txn.delete(table);
      }
      for (final table in tables) {
        final rows = data[table];
        if (rows is! List) {
          counts[table] = 0;
          continue;
        }
        var inserted = 0;
        for (final row in rows) {
          if (row is! Map) continue;
          await txn.insert(
            table,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          inserted++;
        }
        counts[table] = inserted;
      }
    });
    return counts;
  }

  Future<void> _restorePrefs(Object? prefsData) async {
    if (prefsData is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final entry in prefsData.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      }
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Future<File> _writePayloadFile(
    Map<String, Object?> payload, {
    required String prefix,
  }) async {
    final dir = await _tempDirectory();
    final file = File(p.join(dir.path, _fileName(prefix)));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }

  String _fileName(String prefix) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '$prefix-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json';
  }
}
