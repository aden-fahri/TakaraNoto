import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database for the ZainNoto group-cash mode.
///
/// Uses raw sqflite (same approach as the personal mode) in its own file so
/// group data stays fully isolated from `finflow.db`.
class ZainNotoDatabase {
  ZainNotoDatabase();

  static final ZainNotoDatabase instance = ZainNotoDatabase();

  static const String dbName = 'zainnoto.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final String dbPath;
    if (path != null) {
      dbPath = path;
    } else if (kIsWeb) {
      // The web factory (sqlite3 wasm + IndexedDB, set in main) stores
      // databases by virtual name instead of a file system path.
      dbPath = dbName;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = join(dir.path, dbName);
    }

    final resolvedFactory = factory ?? databaseFactory;
    final db = await resolvedFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        // In-memory databases must never be cached, otherwise every test
        // would share the same instance.
        singleInstance: dbPath != inMemoryDatabasePath,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      ),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }
}

/// Full v1 schema.
///
/// Safety rules baked in (see review of the ZainNoto plan):
/// - `charges` has no stored status; status is always derived.
/// - Unique indexes stop duplicate periods, charges and allocations.
/// - Every table supports soft delete via `deleted_at`.
const List<String> schemaStatements = [
  '''
  CREATE TABLE groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_index INTEGER NOT NULL DEFAULT 0,
    color_hex TEXT NOT NULL DEFAULT '#059669',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT
  )
  ''',
  '''
  CREATE TABLE members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone_number TEXT,
    joined_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'inactive')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX idx_members_group ON members(group_id)',
  '''
  CREATE TABLE dues_plans (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    amount INTEGER NOT NULL CHECK(amount >= 0),
    frequency TEXT NOT NULL CHECK(frequency IN ('weekly', 'monthly')),
    due_day INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX idx_dues_plans_group ON dues_plans(group_id)',
  '''
  CREATE TABLE periods (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    dues_plan_id TEXT NOT NULL,
    label TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    due_date TEXT NOT NULL,
    amount_snapshot INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
    FOREIGN KEY (dues_plan_id) REFERENCES dues_plans (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX uq_period ON periods(dues_plan_id, start_date)',
  'CREATE INDEX idx_periods_group ON periods(group_id)',
  '''
  CREATE TABLE charges (
    id TEXT PRIMARY KEY,
    member_id TEXT NOT NULL,
    period_id TEXT NOT NULL,
    amount_due INTEGER NOT NULL CHECK(amount_due >= 0),
    waived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE,
    FOREIGN KEY (period_id) REFERENCES periods (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX uq_charge ON charges(period_id, member_id)',
  'CREATE INDEX idx_charges_member ON charges(member_id)',
  '''
  CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    member_id TEXT,
    type TEXT NOT NULL CHECK(type IN ('dues', 'other_income', 'expense')),
    amount INTEGER NOT NULL CHECK(amount > 0),
    category TEXT,
    note TEXT,
    date TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT,
    client_ref TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE SET NULL
  )
  ''',
  'CREATE INDEX idx_transactions_group_date ON transactions(group_id, date)',
  '''
  CREATE UNIQUE INDEX uq_tx_client_ref ON transactions(client_ref)
    WHERE client_ref IS NOT NULL
  ''',
  '''
  CREATE TABLE allocations (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    charge_id TEXT NOT NULL,
    amount_allocated INTEGER NOT NULL CHECK(amount_allocated > 0),
    created_at TEXT NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
    FOREIGN KEY (charge_id) REFERENCES charges (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX uq_alloc ON allocations(transaction_id, charge_id)',
  'CREATE INDEX idx_alloc_charge ON allocations(charge_id)',
  '''
  CREATE TABLE member_credits (
    id TEXT PRIMARY KEY,
    member_id TEXT NOT NULL,
    source_transaction_id TEXT NOT NULL,
    amount_remaining INTEGER NOT NULL CHECK(amount_remaining > 0),
    created_at TEXT NOT NULL,
    FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE CASCADE,
    FOREIGN KEY (source_transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX idx_credits_member ON member_credits(member_id)',
  '''
  CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,
    old_json TEXT,
    new_json TEXT,
    created_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX idx_audit_entity ON audit_log(entity, entity_id)',
];
