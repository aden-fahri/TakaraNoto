/// Persisted entities for the ZainNoto group-cash mode.
///
/// All ids are UUID strings so data stays merge-safe in the future.
/// All money values are integer rupiah. Dates are `YYYY-MM-DD` strings.
enum DuesFrequency {
  weekly('weekly'),
  monthly('monthly');

  const DuesFrequency(this.dbValue);

  final String dbValue;

  static DuesFrequency fromDb(String value) =>
      values.firstWhere((e) => e.dbValue == value, orElse: () => weekly);
}

enum MemberStatus {
  active('active'),
  inactive('inactive');

  const MemberStatus(this.dbValue);

  final String dbValue;

  static MemberStatus fromDb(String value) =>
      values.firstWhere((e) => e.dbValue == value, orElse: () => active);
}

enum TxType {
  dues('dues'),
  otherIncome('other_income'),
  expense('expense');

  const TxType(this.dbValue);

  final String dbValue;

  static TxType fromDb(String value) =>
      values.firstWhere((e) => e.dbValue == value, orElse: () => otherIncome);

  bool get isIncome => this != TxType.expense;
}

class Group {
  const Group({
    required this.id,
    required this.name,
    this.description,
    this.iconIndex = 0,
    this.colorHex = '#059669',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int iconIndex;
  final String colorHex;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Group.fromMap(Map<String, Object?> map) => Group(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        iconIndex: (map['icon_index'] as num?)?.toInt() ?? 0,
        colorHex: map['color_hex'] as String? ?? '#059669',
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'icon_index': iconIndex,
        'color_hex': colorHex,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class Member {
  const Member({
    required this.id,
    required this.groupId,
    required this.name,
    this.phoneNumber,
    required this.joinedAt,
    this.status = MemberStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String groupId;
  final String name;
  final String? phoneNumber;
  final String joinedAt;
  final MemberStatus status;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isActive => status == MemberStatus.active;

  factory Member.fromMap(Map<String, Object?> map) => Member(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phone_number'] as String?,
        joinedAt: map['joined_at'] as String,
        status: MemberStatus.fromDb(map['status'] as String? ?? 'active'),
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'phone_number': phoneNumber,
        'joined_at': joinedAt,
        'status': status.dbValue,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class DuesPlan {
  const DuesPlan({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.frequency,
    required this.dueDay,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String groupId;
  final int amount;
  final DuesFrequency frequency;
  final int dueDay;
  final String startDate;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory DuesPlan.fromMap(Map<String, Object?> map) => DuesPlan(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        amount: (map['amount'] as num).toInt(),
        frequency: DuesFrequency.fromDb(map['frequency'] as String),
        dueDay: (map['due_day'] as num).toInt(),
        startDate: map['start_date'] as String,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'group_id': groupId,
        'amount': amount,
        'frequency': frequency.dbValue,
        'due_day': dueDay,
        'start_date': startDate,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class Period {
  const Period({
    required this.id,
    required this.groupId,
    required this.duesPlanId,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.dueDate,
    required this.amountSnapshot,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String groupId;
  final String duesPlanId;
  final String label;
  final String startDate;
  final String endDate;
  final String dueDate;
  final int amountSnapshot;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Period.fromMap(Map<String, Object?> map) => Period(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        duesPlanId: map['dues_plan_id'] as String,
        label: map['label'] as String,
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String,
        dueDate: map['due_date'] as String,
        amountSnapshot: (map['amount_snapshot'] as num).toInt(),
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'group_id': groupId,
        'dues_plan_id': duesPlanId,
        'label': label,
        'start_date': startDate,
        'end_date': endDate,
        'due_date': dueDate,
        'amount_snapshot': amountSnapshot,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class Charge {
  const Charge({
    required this.id,
    required this.memberId,
    required this.periodId,
    required this.amountDue,
    this.waived = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String memberId;
  final String periodId;
  final int amountDue;
  final bool waived;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Charge.fromMap(Map<String, Object?> map) => Charge(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        periodId: map['period_id'] as String,
        amountDue: (map['amount_due'] as num).toInt(),
        waived: ((map['waived'] as num?)?.toInt() ?? 0) == 1,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'member_id': memberId,
        'period_id': periodId,
        'amount_due': amountDue,
        'waived': waived ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class GroupTransaction {
  const GroupTransaction({
    required this.id,
    required this.groupId,
    this.memberId,
    required this.type,
    required this.amount,
    this.category,
    this.note,
    required this.date,
    this.isDeleted = false,
    this.deletedAt,
    this.clientRef,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String groupId;
  final String? memberId;
  final TxType type;
  final int amount;
  final String? category;
  final String? note;
  final String date;
  final bool isDeleted;
  final String? deletedAt;
  final String? clientRef;
  final String createdAt;
  final String updatedAt;

  factory GroupTransaction.fromMap(Map<String, Object?> map) => GroupTransaction(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        memberId: map['member_id'] as String?,
        type: TxType.fromDb(map['type'] as String),
        amount: (map['amount'] as num).toInt(),
        category: map['category'] as String?,
        note: map['note'] as String?,
        date: map['date'] as String,
        isDeleted: ((map['is_deleted'] as num?)?.toInt() ?? 0) == 1,
        deletedAt: map['deleted_at'] as String?,
        clientRef: map['client_ref'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'group_id': groupId,
        'member_id': memberId,
        'type': type.dbValue,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date,
        'is_deleted': isDeleted ? 1 : 0,
        'deleted_at': deletedAt,
        'client_ref': clientRef,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Allocation {
  const Allocation({
    required this.id,
    required this.transactionId,
    required this.chargeId,
    required this.amountAllocated,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String chargeId;
  final int amountAllocated;
  final String createdAt;

  factory Allocation.fromMap(Map<String, Object?> map) => Allocation(
        id: map['id'] as String,
        transactionId: map['transaction_id'] as String,
        chargeId: map['charge_id'] as String,
        amountAllocated: (map['amount_allocated'] as num).toInt(),
        createdAt: map['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'charge_id': chargeId,
        'amount_allocated': amountAllocated,
        'created_at': createdAt,
      };
}

class MemberCredit {
  const MemberCredit({
    required this.id,
    required this.memberId,
    required this.sourceTransactionId,
    required this.amountRemaining,
    required this.createdAt,
  });

  final String id;
  final String memberId;
  final String sourceTransactionId;
  final int amountRemaining;
  final String createdAt;

  factory MemberCredit.fromMap(Map<String, Object?> map) => MemberCredit(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        sourceTransactionId: map['source_transaction_id'] as String,
        amountRemaining: (map['amount_remaining'] as num).toInt(),
        createdAt: map['created_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'member_id': memberId,
        'source_transaction_id': sourceTransactionId,
        'amount_remaining': amountRemaining,
        'created_at': createdAt,
      };
}

class AuditEntry {
  const AuditEntry({
    this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    this.oldJson,
    this.newJson,
    required this.createdAt,
  });

  final int? id;
  final String entity;
  final String entityId;
  final String action;
  final String? oldJson;
  final String? newJson;
  final String createdAt;

  factory AuditEntry.fromMap(Map<String, Object?> map) => AuditEntry(
        id: (map['id'] as num?)?.toInt(),
        entity: map['entity'] as String,
        entityId: map['entity_id'] as String,
        action: map['action'] as String,
        oldJson: map['old_json'] as String?,
        newJson: map['new_json'] as String?,
        createdAt: map['created_at'] as String,
      );
}
