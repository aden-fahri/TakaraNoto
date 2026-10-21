import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/derived.dart';
import '../models/entities.dart';
import '../repositories/zainnoto_repository.dart';
import '../utils/dates.dart';

/// UI-facing state for the ZainNoto (group cash) mode.
///
/// Wraps [ZainNotoRepository]: loads the selected group's summary, current
/// period checklist, members, transactions and dues plans, and re-refreshes
/// after every write so derived statuses stay in sync.
class ZainNotoProvider extends ChangeNotifier {
  ZainNotoProvider({ZainNotoRepository? repository, Uuid? uuid})
    : _repository = repository ?? ZainNotoRepository(),
      _uuid = uuid ?? const Uuid();

  final ZainNotoRepository _repository;
  final Uuid _uuid;

  ZainNotoRepository get repository => _repository;

  List<Group> _groups = const [];
  Group? _selectedGroup;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _refreshPending = false;
  String? _error;

  GroupSummary? _summary;
  Period? _currentPeriod;
  List<PeriodMemberRow> _periodRows = const [];
  List<PeriodMemberRow> _currentPeriodRows = const [];
  List<Period> _periods = const [];
  List<Member> _members = const [];
  List<Member> _allMembers = const [];
  List<GroupTransaction> _transactions = const [];
  List<DuesPlan> _duesPlans = const [];
  List<MemberOverdueSummary> _overdueMembers = const [];

  Period? _selectedPeriod;
  Map<String, List<PeriodMemberRow>> _matrixByPeriod = {};
  bool _isLoadingMatrix = false;
  bool _matrixStale = true;

  List<Group> get groups => _groups;
  Group? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  GroupSummary? get summary => _summary;
  Period? get currentPeriod => _currentPeriod;
  List<PeriodMemberRow> get periodRows => _periodRows;

  /// Baris tagihan periode berjalan — selalu mengikuti [currentPeriod],
  /// bukan periode yang dipilih pengguna di tab Iuran.
  List<PeriodMemberRow> get currentPeriodRows => _currentPeriodRows;
  List<Period> get periods => _periods;
  List<Member> get members => _members;
  List<Member> get allMembers => _allMembers;
  List<GroupTransaction> get transactions => _transactions;
  List<DuesPlan> get duesPlans => _duesPlans;
  List<MemberOverdueSummary> get overdueMembers => _overdueMembers;

  Period? get selectedPeriod => _selectedPeriod;
  Map<String, List<PeriodMemberRow>> get matrixByPeriod => _matrixByPeriod;
  bool get isLoadingMatrix => _isLoadingMatrix;
  bool get matrixNeedsReload => _matrixStale;

  /// Total other income + dues collected (all time).
  int get totalIncome {
    var total = 0;
    for (final tx in _transactions) {
      if (tx.type.isIncome) total += tx.amount;
    }
    return total;
  }

  /// Total expenses (all time).
  int get totalExpense {
    var total = 0;
    for (final tx in _transactions) {
      if (tx.type == TxType.expense) total += tx.amount;
    }
    return total;
  }

  /// Iuran terkumpul periode berjalan + pemasukan lain pada rentang tanggal
  /// periode itu. Tanpa periode → total semua waktu.
  int get incomeThisPeriod {
    final period = _currentPeriod;
    if (period == null) return totalIncome;
    var total = 0;
    for (final row in _currentPeriodRows) {
      if (!row.waived) total += row.paid;
    }
    for (final tx in _transactions) {
      if (tx.type == TxType.otherIncome &&
          tx.date.compareTo(period.startDate) >= 0 &&
          tx.date.compareTo(period.endDate) <= 0) {
        total += tx.amount;
      }
    }
    return total;
  }

  /// Pengeluaran pada rentang tanggal periode berjalan; tanpa periode →
  /// total semua waktu.
  int get expenseThisPeriod {
    final period = _currentPeriod;
    if (period == null) return totalExpense;
    var total = 0;
    for (final tx in _transactions) {
      if (tx.type == TxType.expense &&
          tx.date.compareTo(period.startDate) >= 0 &&
          tx.date.compareTo(period.endDate) <= 0) {
        total += tx.amount;
      }
    }
    return total;
  }

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final member in _members) {
      if (member.id == id) return member;
    }
    return null;
  }

  // ── Info layar pilih grup ──────────────────────────────────────────────────

  final Map<String, GroupPickerInfo> _pickerInfo = {};

  /// Info anggota & saldo per grup untuk layar pilih grup (per grup di-skip
  /// bila sudah termuat).
  Map<String, GroupPickerInfo> get pickerInfo => _pickerInfo;

  /// Mengisi [_pickerInfo] untuk semua grup; kartu tampil dulu tanpa subtitle,
  /// data menyusul per grup (gagal dimuat dibiarkan tanpa subtitle).
  Future<void> loadPickerInfo() async {
    for (final g in _groups) {
      if (_pickerInfo.containsKey(g.id)) continue;
      try {
        final summary = await _repository.getGroupSummary(groupId: g.id);
        final members = await _repository.getMembers(g.id);
        _pickerInfo[g.id] = GroupPickerInfo(
          memberCount: members.length,
          balance: summary.balance,
        );
        notifyListeners();
      } catch (_) {
        // Info tidak wajib: kartu tetap tampil tanpa subtitle.
      }
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> loadGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await _repository.getGroups();
      _pickerInfo.clear();
      final selected = _selectedGroup;
      if (selected != null &&
          !_groups.any((group) => group.id == selected.id)) {
        _selectedGroup = null;
      }
      _selectedGroup ??= _groups.isNotEmpty ? _groups.first : null;
      final group = _selectedGroup;
      if (group != null) {
        await _loadGroupData(group.id);
      } else {
        _clearGroupData();
      }
    } catch (error) {
      _error = 'Gagal memuat grup: $error';
    }
    _isLoading = false;
    notifyListeners();
  }

  void selectGroup(Group group) {
    if (_selectedGroup?.id == group.id) return;
    _selectedGroup = group;
    notifyListeners();
    refreshGroup();
  }

  Future<void> refreshGroup() async {
    final group = _selectedGroup;
    if (group == null) return;
    // Coalesce concurrent refreshes: while one refresh is running, further
    // requests just mark it dirty and are served by the running loop.
    if (_isRefreshing) {
      _refreshPending = true;
      return;
    }
    _isRefreshing = true;
    _error = null;
    notifyListeners();
    try {
      do {
        _refreshPending = false;
        await _loadGroupData(group.id);
      } while (_refreshPending);
    } catch (error) {
      _error = 'Gagal memuat data grup: $error';
    }
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> _loadGroupData(String groupId) async {
    await _repository.generatePeriods(groupId: groupId);

    // All reads are independent, so start them together and await after.
    final summaryFuture = _repository.getGroupSummary(groupId: groupId);
    final currentFuture = _repository.getCurrentPeriod(groupId);
    final periodsFuture = _repository.getPeriods(groupId);
    final membersFuture = _repository.getMembers(groupId);
    final allMembersFuture = _repository.getMembers(
      groupId,
      includeInactive: true,
    );
    final transactionsFuture = _repository.getTransactions(groupId);
    final plansFuture = _repository.getDuesPlans(groupId);
    final overdueFuture = _repository.getOverdueMembers(groupId: groupId);

    _summary = await summaryFuture;
    _currentPeriod = await currentFuture;
    _periods = await periodsFuture;
    _members = await membersFuture;
    _allMembers = await allMembersFuture;
    _transactions = await transactionsFuture;
    _duesPlans = await plansFuture;
    _overdueMembers = await overdueFuture;

    final selectedId = _selectedPeriod?.id;
    Period? keepSelected;
    for (final period in _periods) {
      if (period.id == selectedId) {
        keepSelected = period;
        break;
      }
    }
    _selectedPeriod = keepSelected ?? _currentPeriod;
    final period = _selectedPeriod;
    _periodRows = period == null
        ? const []
        : await _repository.getPeriodRows(period.id);
    final current = _currentPeriod;
    _currentPeriodRows = current == null
        ? const []
        : (period != null && period.id == current.id)
        ? _periodRows
        : await _repository.getPeriodRows(current.id);
    _matrixStale = true;
  }

  void _clearGroupData() {
    _summary = null;
    _currentPeriod = null;
    _periodRows = const [];
    _currentPeriodRows = const [];
    _periods = const [];
    _members = const [];
    _allMembers = const [];
    _transactions = const [];
    _duesPlans = const [];
    _overdueMembers = const [];
    _selectedPeriod = null;
    _matrixByPeriod = {};
    _matrixStale = true;
  }

  // ── Group ─────────────────────────────────────────────────────────────────

  Future<Group?> createGroup({
    required String name,
    String? description,
    int iconIndex = 0,
    String colorHex = '#059669',
  }) async {
    try {
      final id = await _repository.createGroup(
        name: name,
        description: description,
        iconIndex: iconIndex,
        colorHex: colorHex,
      );
      _groups = await _repository.getGroups();
      final created = _groups.firstWhere(
        (g) => g.id == id,
        orElse: () => _groups.first,
      );
      _selectedGroup = created;
      await _loadGroupData(created.id);
      notifyListeners();
      return created;
    } catch (error) {
      _error = 'Gagal membuat grup: $error';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateGroup({
    required String id,
    required String name,
    String? description,
    int? iconIndex,
    String? colorHex,
  }) async {
    try {
      await _repository.updateGroup(
        id: id,
        name: name,
        description: description,
        iconIndex: iconIndex,
        colorHex: colorHex,
      );
      await loadGroups();
      return true;
    } catch (error) {
      _error = 'Gagal mengubah grup: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String id) async {
    try {
      await _repository.softDeleteGroup(id);
      if (_selectedGroup?.id == id) _selectedGroup = null;
      await loadGroups();
      return true;
    } catch (error) {
      _error = 'Gagal menghapus grup: $error';
      notifyListeners();
      return false;
    }
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  /// Marks a member paid. Pass [amount] = remaining for the 1-tap flow;
  /// the uuid idempotency key makes double taps safe.
  Future<String?> markPaid({
    required String memberId,
    required int amount,
    String? date,
  }) async {
    final group = _selectedGroup;
    if (group == null || amount <= 0) return null;
    try {
      final id = await _repository.recordDuesPayment(
        groupId: group.id,
        memberId: memberId,
        amount: amount,
        date: date ?? dateToStr(DateTime.now()),
        idempotencyKey: _uuid.v4(),
      );
      await refreshGroup();
      return id;
    } catch (error) {
      _error = 'Gagal mencatat pembayaran: $error';
      notifyListeners();
      return null;
    }
  }

  Future<bool> editTransaction({
    required String id,
    int? amount,
    String? date,
    String? note,
    String? category,
    String? memberId,
  }) async {
    try {
      await _repository.editTransaction(
        id: id,
        amount: amount,
        date: date,
        note: note,
        category: category,
        memberId: memberId,
      );
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal mengubah transaksi: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal menghapus transaksi: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setChargeWaived(String chargeId, {required bool waived}) async {
    try {
      await _repository.setChargeWaived(chargeId, waived: waived);
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal mengubah status bebas iuran: $error';
      notifyListeners();
      return false;
    }
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<String?> addTransaction({
    required TxType type,
    required int amount,
    String? category,
    String? note,
    String? date,
  }) async {
    final group = _selectedGroup;
    if (group == null || amount <= 0) return null;
    try {
      final id = await _repository.recordTransaction(
        groupId: group.id,
        type: type,
        amount: amount,
        category: category,
        note: note,
        date: date ?? dateToStr(DateTime.now()),
        idempotencyKey: _uuid.v4(),
      );
      await refreshGroup();
      return id;
    } catch (error) {
      _error = 'Gagal mencatat transaksi: $error';
      notifyListeners();
      return null;
    }
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<bool> addMember({
    required String name,
    String? phoneNumber,
    String? joinedAt,
  }) async {
    final group = _selectedGroup;
    if (group == null) return false;
    try {
      await _repository.addMember(
        groupId: group.id,
        name: name,
        phoneNumber: phoneNumber,
        joinedAt: joinedAt ?? dateToStr(DateTime.now()),
      );
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal menambah anggota: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMember({
    required String id,
    String? name,
    String? phoneNumber,
    MemberStatus? status,
  }) async {
    try {
      await _repository.updateMember(
        id: id,
        name: name,
        phoneNumber: phoneNumber,
        status: status,
      );
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal mengubah anggota: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String id) async {
    try {
      await _repository.softDeleteMember(id);
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal menghapus anggota: $error';
      notifyListeners();
      return false;
    }
  }

  // ── Dues plans & periods ──────────────────────────────────────────────────

  Future<bool> saveDuesPlan({
    String? id,
    required int amount,
    required DuesFrequency frequency,
    required int dueDay,
    required String startDate,
  }) async {
    final group = _selectedGroup;
    if (group == null) return false;
    try {
      await _repository.upsertDuesPlan(
        id: id,
        groupId: group.id,
        amount: amount,
        frequency: frequency,
        dueDay: dueDay,
        startDate: startDate,
      );
      await refreshGroup();
      return true;
    } catch (error) {
      _error = 'Gagal menyimpan rencana iuran: $error';
      notifyListeners();
      return false;
    }
  }

  /// Generates every period due up to today; returns the number created.
  Future<int> generatePeriodsNow() async {
    final group = _selectedGroup;
    if (group == null) return 0;
    try {
      final created = await _repository.generatePeriods(groupId: group.id);
      await refreshGroup();
      return created;
    } catch (error) {
      _error = 'Gagal membuat periode: $error';
      notifyListeners();
      return 0;
    }
  }

  // ── Period checklist & matrix ─────────────────────────────────────────────

  Future<void> selectPeriod(Period period) async {
    if (_selectedPeriod?.id == period.id) return;
    _selectedPeriod = period;
    notifyListeners();
    try {
      _periodRows = await _repository.getPeriodRows(period.id);
    } catch (error) {
      _error = 'Gagal memuat checklist: $error';
    }
    notifyListeners();
  }

  /// Loads rows for the most recent [maxPeriods] periods (matrix view).
  Future<void> loadMatrix({int maxPeriods = 12}) async {
    if (_selectedGroup == null || _isLoadingMatrix) return;
    _isLoadingMatrix = true;
    notifyListeners();
    try {
      final recent = _periods.length <= maxPeriods
          ? _periods
          : _periods.sublist(_periods.length - maxPeriods);
      final loaded = <String, List<PeriodMemberRow>>{};
      final results = await Future.wait([
        for (final period in recent) _repository.getPeriodRows(period.id),
      ]);
      for (var i = 0; i < recent.length; i++) {
        loaded[recent[i].id] = results[i];
      }
      _matrixByPeriod = loaded;
      _matrixStale = false;
    } catch (error) {
      _error = 'Gagal memuat matriks: $error';
    }
    _isLoadingMatrix = false;
    notifyListeners();
  }

  Future<List<AllocationDetail>> allocationDetailsFor(String transactionId) =>
      _repository.getAllocationDetails(transactionId);
}
