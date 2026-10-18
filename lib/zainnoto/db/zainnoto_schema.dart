import 'package:sqflite/sqflite.dart';

/// Schema tabel ZainNoto yang kini hidup di database sharing `finflow.db`
/// dengan prefix `zn_` (merger Fase 3).
///
/// Dipakai dua jalur sekaligus: fresh install (`DatabaseHelper._createDB`)
/// dan upgrade v7 → v8, karena itu semua statement bersifat
/// `IF NOT EXISTS` sehingga idempoten.
///
/// Aturan keamanan tetap sama seperti sebelumnya:
/// - `zn_charges` tidak menyimpan status; status selalu turunan.
/// - Unique index mencegah periode, tagihan, dan alokasi ganda.
/// - Semua tabel mendukung soft delete lewat `deleted_at`.
const List<String> zainnotoSchemaStatements = [
  '''
  CREATE TABLE IF NOT EXISTS zn_groups (
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
  CREATE TABLE IF NOT EXISTS zn_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone_number TEXT,
    joined_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'inactive')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (group_id) REFERENCES zn_groups (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_zn_members_group ON zn_members(group_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_dues_plans (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    amount INTEGER NOT NULL CHECK(amount >= 0),
    frequency TEXT NOT NULL CHECK(frequency IN ('weekly', 'monthly')),
    due_day INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (group_id) REFERENCES zn_groups (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_zn_dues_plans_group ON zn_dues_plans(group_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_periods (
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
    FOREIGN KEY (group_id) REFERENCES zn_groups (id) ON DELETE CASCADE,
    FOREIGN KEY (dues_plan_id) REFERENCES zn_dues_plans (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_zn_period ON zn_periods(dues_plan_id, start_date)',
  'CREATE INDEX IF NOT EXISTS idx_zn_periods_group ON zn_periods(group_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_charges (
    id TEXT PRIMARY KEY,
    member_id TEXT NOT NULL,
    period_id TEXT NOT NULL,
    amount_due INTEGER NOT NULL CHECK(amount_due >= 0),
    waived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    FOREIGN KEY (member_id) REFERENCES zn_members (id) ON DELETE CASCADE,
    FOREIGN KEY (period_id) REFERENCES zn_periods (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_zn_charge ON zn_charges(period_id, member_id)',
  'CREATE INDEX IF NOT EXISTS idx_zn_charges_member ON zn_charges(member_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_transactions (
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
    FOREIGN KEY (group_id) REFERENCES zn_groups (id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES zn_members (id) ON DELETE SET NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_zn_transactions_group_date ON zn_transactions(group_id, date)',
  '''
  CREATE UNIQUE INDEX IF NOT EXISTS uq_zn_tx_client_ref ON zn_transactions(client_ref)
    WHERE client_ref IS NOT NULL
  ''',
  '''
  CREATE TABLE IF NOT EXISTS zn_allocations (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    charge_id TEXT NOT NULL,
    amount_allocated INTEGER NOT NULL CHECK(amount_allocated > 0),
    created_at TEXT NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES zn_transactions (id) ON DELETE CASCADE,
    FOREIGN KEY (charge_id) REFERENCES zn_charges (id) ON DELETE CASCADE
  )
  ''',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_zn_alloc ON zn_allocations(transaction_id, charge_id)',
  'CREATE INDEX IF NOT EXISTS idx_zn_alloc_charge ON zn_allocations(charge_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_member_credits (
    id TEXT PRIMARY KEY,
    member_id TEXT NOT NULL,
    source_transaction_id TEXT NOT NULL,
    amount_remaining INTEGER NOT NULL CHECK(amount_remaining > 0),
    created_at TEXT NOT NULL,
    FOREIGN KEY (member_id) REFERENCES zn_members (id) ON DELETE CASCADE,
    FOREIGN KEY (source_transaction_id) REFERENCES zn_transactions (id) ON DELETE CASCADE
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_zn_credits_member ON zn_member_credits(member_id)',
  '''
  CREATE TABLE IF NOT EXISTS zn_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,
    old_json TEXT,
    new_json TEXT,
    created_at TEXT NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_zn_audit_entity ON zn_audit_log(entity, entity_id)',
];

/// Membuat seluruh tabel `zn_*` bila belum ada.
Future<void> createZainNotoSchema(DatabaseExecutor db) async {
  for (final statement in zainnotoSchemaStatements) {
    await db.execute(statement);
  }
}
