import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import 'group_sheets.dart';

/// Hasil dialog form anggota: nama (wajib) + status aktif (khusus ubah).
typedef MemberFormResult = ({String name, bool active});

/// Form tambah/ubah anggota: cukup nama, tanpa nomor WhatsApp.
class MemberFormDialog extends StatefulWidget {
  const MemberFormDialog({super.key, this.member});

  final Member? member;

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.member?.name ?? '');
  late bool _active = widget.member == null || widget.member!.isActive;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, active: _active));
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
          if (member != null) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Anggota aktif',
                style: TextStyle(fontSize: AppText.bodyLarge, color: t.textPrimary),
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
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Buka form anggota lalu simpan ke provider (tambah bila [member] null,
/// selain itu ubah). Menampilkan SnackBar hasil.
Future<void> showMemberForm(BuildContext context, {Member? member}) async {
  final provider = context.read<ZainNotoProvider>();
  final result = await showDialog<MemberFormResult>(
    context: context,
    builder: (_) => MemberFormDialog(member: member),
  );
  if (result == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ok = member == null
      ? await provider.addMember(name: result.name)
      : await provider.updateMember(
          id: member.id,
          name: result.name,
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
