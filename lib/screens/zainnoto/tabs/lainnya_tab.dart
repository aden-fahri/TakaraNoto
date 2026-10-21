import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/logic/dues_status.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import '../../../zainnoto/utils/dates.dart';
import '../../../zainnoto/utils/format.dart';
import '../../backup_restore_screen.dart';
import '../widgets/group_avatar.dart';
import '../group_picker_screen.dart';
import '../widgets/group_sheets.dart';
import '../widgets/member_avatar.dart';

/// Lainnya tab: group & member management, dues plan and period generation,
/// WhatsApp recap and a backup shortcut.
class LainnyaTab extends StatelessWidget {
  const LainnyaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ZainNotoProvider>();
    final t = context.tokens;
    final group = provider.selectedGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(groupName: group?.name),
        if (provider.isRefreshing)
          LinearProgressIndicator(
            minHeight: 2,
            color: t.accent,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: group == null
              ? _NoGroup(onCreate: () => showCreateGroupDialog(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _GroupSection(provider: provider),
                    const SizedBox(height: 14),
                    _MembersSection(provider: provider),
                    const SizedBox(height: 14),
                    _DuesSection(provider: provider),
                    const SizedBox(height: 14),
                    _ShareSection(provider: provider),
                    const SizedBox(height: 14),
                    const _BackupSection(),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  const _Banner({required this.groupName});

  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.headerBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lainnya',
                style: TextStyle(
                  fontSize: AppText.headline,
                  fontWeight: FontWeight.w800,
                  color: t.headerFg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                groupName ?? 'Belum ada grup',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppText.body, color: t.headerMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Group ────────────────────────────────────────────────────────────────────
class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.provider});

  final ZainNotoProvider provider;

  Future<void> _confirmDelete(BuildContext context) async {
    final group = provider.selectedGroup;
    if (group == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Grup?'),
        content: Text(
          'Grup "${group.name}" disembunyikan dari daftar. Data kas yang '
          'sudah tercatat tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.deleteGroup(group.id);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Grup dihapus' : 'Gagal menghapus grup')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final group = provider.selectedGroup;
    if (group == null) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Grup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GroupAvatar(name: group.name, colorHex: group.colorHex, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.label,
                          height: 1.4,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => GroupPickerScreen.show(context),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Ganti'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showCreateGroupDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => showEditGroupDialog(context, group),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Ubah Grup'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: t.expense,
                  ),
                  label: Text('Hapus Grup', style: TextStyle(color: t.expense)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _MemberFormResult = ({String name, String phone, bool active});

/// Add/edit member dialog that owns its controllers and active switch, so
/// they are disposed only after the dialog route is fully removed.
class _MemberFormDialog extends StatefulWidget {
  const _MemberFormDialog({this.member});

  final Member? member;

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.member?.name ?? '',
  );
  late final TextEditingController _phoneCtrl = TextEditingController(
    text: widget.member?.phoneNumber ?? '',
  );
  late bool _active = widget.member == null || widget.member!.isActive;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (
      name: name,
      phone: _phoneCtrl.text.trim(),
      active: _active,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final member = widget.member;
    return AlertDialog(
      title: Text(member == null ? 'Tambah Anggota' : 'Ubah Anggota'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: groupInputDecoration(t, 'Nama anggota'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: groupInputDecoration(
              t,
              'Nomor HP (opsional)',
              hint: 'mis. 0812xxxxxxx',
            ),
          ),
          if (member != null) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Anggota aktif',
                style: TextStyle(
                  fontSize: AppText.bodyLarge,
                  color: t.textPrimary,
                ),
              ),
              subtitle: Text(
                _active
                    ? 'Ikut ditagih iuran periode baru'
                    : 'Tidak ikut ditagih iuran periode baru',
                style: TextStyle(fontSize: AppText.label, color: t.textMuted),
              ),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

// ─── Members ──────────────────────────────────────────────────────────────────
class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.provider});

  final ZainNotoProvider provider;

  Future<void> _showMemberDialog(BuildContext context, {Member? member}) async {
    final result = await showDialog<_MemberFormResult>(
      context: context,
      builder: (_) => _MemberFormDialog(member: member),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = member == null
        ? await provider.addMember(
            name: result.name,
            phoneNumber: result.phone.isEmpty ? null : result.phone,
          )
        : await provider.updateMember(
            id: member.id,
            name: result.name,
            phoneNumber: result.phone.isEmpty ? null : result.phone,
            status: result.active ? MemberStatus.active : MemberStatus.inactive,
          );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (member == null ? 'Anggota ditambahkan' : 'Anggota diperbarui')
              : 'Gagal menyimpan anggota',
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: Text(
          '"${member.name}" disembunyikan dari daftar. Riwayat iurannya '
          'tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.removeMember(member.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Anggota dihapus' : 'Gagal menghapus anggota'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final members = provider.allMembers;

    return _SectionCard(
      title: 'Anggota (${members.length})',
      trailing: TextButton.icon(
        onPressed: () => _showMemberDialog(context),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Tambah'),
      ),
      child: members.isEmpty
          ? Text(
              'Belum ada anggota. Tambahkan anggota agar tagihan iuran '
              'terbuat otomatis.',
              style: TextStyle(
                fontSize: AppText.body,
                height: 1.4,
                color: t.textMuted,
              ),
            )
          : Column(
              children: [
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        MemberAvatar(
                          name: member.name,
                          color: member.isActive ? t.accent : t.textMuted,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.bodyLarge,
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                member.isActive
                                    ? (member.phoneNumber ?? 'Anggota aktif')
                                    : 'Nonaktif',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.label,
                                  color: t.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showMemberDialog(context, member: member),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: t.textMuted,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _confirmRemove(context, member),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                            color: t.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

typedef _DuesPlanResult = ({
  int amount,
  DuesFrequency frequency,
  int dueDay,
  DateTime startDate,
});

/// Set/edit dues plan dialog that owns its controller, frequency, due day and
/// start date, so they are disposed with the route.
class _DuesPlanFormDialog extends StatefulWidget {
  const _DuesPlanFormDialog({this.plan});

  final DuesPlan? plan;

  @override
  State<_DuesPlanFormDialog> createState() => _DuesPlanFormDialogState();
}

class _DuesPlanFormDialogState extends State<_DuesPlanFormDialog> {
  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.plan?.amount.toString() ?? '',
  );
  late DuesFrequency _frequency =
      widget.plan?.frequency ?? DuesFrequency.monthly;
  late int _dueDay = widget.plan?.dueDay ?? 10;
  late DateTime _startDate =
      DateTime.tryParse(widget.plan?.startDate ?? '') ?? DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) return;
    Navigator.pop(context, (
      amount: amount,
      frequency: _frequency,
      dueDay: _dueDay.clamp(1, _frequency == DuesFrequency.weekly ? 7 : 28),
      startDate: _startDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plan = widget.plan;
    final maxDueDay = _frequency == DuesFrequency.weekly ? 7 : 28;
    final effectiveDueDay = _dueDay.clamp(1, maxDueDay);
    final amount = int.tryParse(_amountCtrl.text) ?? 0;

    return AlertDialog(
      title: Text(plan == null ? 'Atur Rencana Iuran' : 'Ubah Rencana Iuran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountCtrl,
              autofocus: plan == null,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: groupInputDecoration(
                t,
                'Nominal per periode',
                hint: 'mis. 50000',
              ).copyWith(prefixText: 'Rp '),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlanFrequencyPill(
                    label: 'Mingguan',
                    selected: _frequency == DuesFrequency.weekly,
                    onTap: () =>
                        setState(() => _frequency = DuesFrequency.weekly),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PlanFrequencyPill(
                    label: 'Bulanan',
                    selected: _frequency == DuesFrequency.monthly,
                    onTap: () =>
                        setState(() => _frequency = DuesFrequency.monthly),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _frequency == DuesFrequency.weekly
                  ? 'Jatuh tempo (hari ke-N dalam blok minggu)'
                  : 'Tanggal jatuh tempo',
              style: TextStyle(fontSize: AppText.label, color: t.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: t.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: effectiveDueDay,
                  isExpanded: true,
                  items: [
                    for (var day = 1; day <= maxDueDay; day++)
                      DropdownMenuItem(
                        value: day,
                        child: Text(
                          _frequency == DuesFrequency.weekly
                              ? 'Hari ke-$day'
                              : 'Tanggal $day',
                          style: TextStyle(
                            fontSize: AppText.bodyLarge,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _dueDay = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (plan == null)
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _startDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: t.softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: t.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mulai ${formatTanggalSingkat(dateToStr(_startDate))}',
                        style: TextStyle(
                          fontSize: AppText.bodyLarge,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'Mulai ${formatTanggalSingkat(plan.startDate)} · '
                'perubahan berlaku untuk periode baru',
                style: TextStyle(
                  fontSize: AppText.label,
                  height: 1.4,
                  color: t.textMuted,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: amount > 0 ? _submit : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

// ─── Dues plan & periods ──────────────────────────────────────────────────────
class _DuesSection extends StatelessWidget {
  const _DuesSection({required this.provider});

  final ZainNotoProvider provider;

  Future<void> _showPlanDialog(BuildContext context, {DuesPlan? plan}) async {
    final result = await showDialog<_DuesPlanResult>(
      context: context,
      builder: (_) => _DuesPlanFormDialog(plan: plan),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.saveDuesPlan(
      id: plan?.id,
      amount: result.amount,
      frequency: result.frequency,
      dueDay: result.dueDay,
      startDate: dateToStr(result.startDate),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Rencana iuran disimpan'
              : (provider.error ?? 'Gagal menyimpan rencana iuran'),
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await provider.generatePeriodsNow();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          created > 0
              ? '$created periode baru dibuat'
              : 'Semua periode sudah terbaru',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final plan = provider.duesPlans.isNotEmpty
        ? provider.duesPlans.first
        : null;
    final isWeekly = plan?.frequency == DuesFrequency.weekly;

    return _SectionCard(
      title: 'Iuran & Periode',
      trailing: TextButton.icon(
        onPressed: () => _showPlanDialog(context, plan: plan),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: Text(plan == null ? 'Atur' : 'Ubah'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan == null)
            Text(
              'Belum ada rencana iuran. Atur nominal dan jadwal agar '
              'periode dan tagihan dibuat otomatis.',
              style: TextStyle(
                fontSize: AppText.body,
                height: 1.4,
                color: t.textMuted,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatRupiah(plan.amount)} · '
                          '${isWeekly ? 'Mingguan' : 'Bulanan'}',
                          style: TextStyle(
                            fontSize: AppText.subtitle,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isWeekly
                              ? 'Jatuh tempo hari ke-${plan.dueDay} · '
                                    'mulai ${formatTanggalSingkat(plan.startDate)}'
                              : 'Jatuh tempo tanggal ${plan.dueDay} · '
                                    'mulai ${formatTanggalSingkat(plan.startDate)}',
                          style: TextStyle(
                            fontSize: AppText.label,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.periods.length} periode tercatat',
                  style: TextStyle(fontSize: AppText.label, color: t.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: plan == null ? null : () => _generate(context),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Buat Periode Sekarang'),
          ),
        ],
      ),
    );
  }
}

class _PlanFrequencyPill extends StatelessWidget {
  const _PlanFrequencyPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.12) : t.softSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? t.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w700,
              color: selected ? t.accent : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── WhatsApp recap ───────────────────────────────────────────────────────────
class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.provider});

  final ZainNotoProvider provider;

  Future<void> _shareRecap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final group = provider.selectedGroup;
    final period = provider.currentPeriod;
    if (group == null || period == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Belum ada periode iuran')),
      );
      return;
    }

    try {
      final rows = await provider.repository.getPeriodRows(period.id);
      final waived = rows
          .where((row) => row.status == ChargeStatus.waived)
          .length;
      final paid = rows
          .where((row) => row.status == ChargeStatus.paid)
          .toList();
      final unpaid = rows
          .where(
            (row) =>
                row.status == ChargeStatus.unpaid ||
                row.status == ChargeStatus.partial,
          )
          .toList();

      final buffer = StringBuffer()
        ..writeln('*${group.name}*')
        ..writeln('Rekap Kas · ${period.label}')
        ..writeln('Jatuh tempo: ${formatTanggalSingkat(period.dueDate)}')
        ..writeln()
        ..writeln('Saldo kas: ${formatRupiah(provider.summary?.balance ?? 0)}')
        ..writeln(
          'Tunggakan: ${formatRupiah(provider.summary?.overdueTotal ?? 0)}',
        )
        ..writeln()
        ..writeln('Lunas (${paid.length}/${rows.length - waived}):');
      if (paid.isEmpty) {
        buffer.writeln('- Belum ada');
      } else {
        for (final row in paid) {
          buffer.writeln('- ${row.memberName}');
        }
      }
      if (unpaid.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('Belum lunas:');
        for (final row in unpaid) {
          buffer.writeln(
            '- ${row.memberName}: sisa ${formatRupiah(row.remaining)}',
          );
        }
      }

      await SharePlus.instance.share(
        ShareParams(text: buffer.toString(), subject: 'Rekap ${group.name}'),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal membagikan rekap')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return _SectionCard(
      title: 'Rekap WhatsApp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bagikan ringkasan iuran periode berjalan: status per anggota, '
            'saldo kas, dan tunggakan.',
            style: TextStyle(
              fontSize: AppText.body,
              height: 1.4,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _shareRecap(context),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Bagikan Rekap'),
          ),
        ],
      ),
    );
  }
}

// ─── Backup ───────────────────────────────────────────────────────────────────
class _BackupSection extends StatelessWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return _SectionCard(
      title: 'Data',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BackupRestoreScreen()),
        ),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.backup_rounded, size: 18, color: t.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup & Restore',
                    style: TextStyle(
                      fontSize: AppText.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    'Cadangkan seluruh data aplikasi',
                    style: TextStyle(
                      fontSize: AppText.label,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── No group ─────────────────────────────────────────────────────────────────
class _NoGroup extends StatelessWidget {
  const _NoGroup({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.softSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.groups_rounded, size: 30, color: t.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Grup',
              style: TextStyle(
                fontSize: AppText.title,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat grup dulu untuk mengelola anggota dan iuran.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.bodyLarge,
                height: 1.5,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Grup Pertama'),
            ),
          ],
        ),
      ),
    );
  }
}
