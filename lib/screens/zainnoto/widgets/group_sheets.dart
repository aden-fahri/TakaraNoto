import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tokens.dart';
import '../../../zainnoto/models/entities.dart';
import '../../../zainnoto/providers/zainnoto_provider.dart';
import 'group_avatar.dart';

InputDecoration groupInputDecoration(
  AppTokens t,
  String label, {
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: t.softSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

/// Bottom sheet listing every group with the active one checked.
Future<void> showGroupSwitcher(BuildContext context) async {
  final provider = context.read<ZainNotoProvider>();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Grup',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final group in provider.groups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GroupAvatar(
                    name: group.name,
                    colorHex: group.colorHex,
                    size: 42,
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  subtitle: group.description != null
                      ? Text(
                          group.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: t.textMuted),
                        )
                      : null,
                  trailing: provider.selectedGroup?.id == group.id
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: t.accent,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    provider.selectGroup(group);
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showCreateGroupDialog(context);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah Grup Baru'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dialog to create a new group; returns the created group if successful.
Future<Group?> showCreateGroupDialog(BuildContext context) async {
  final provider = context.read<ZainNotoProvider>();

  final result = await showDialog<_GroupFormResult>(
    context: context,
    builder: (_) => const _GroupFormDialog(
      title: 'Buat Grup Baru',
      nameHint: 'mis. Kas Futsal',
      descriptionHint: 'mis. Iuran mingguan',
    ),
  );
  if (result == null || !context.mounted) return null;

  final group = await provider.createGroup(
    name: result.name,
    description: result.description.isEmpty ? null : result.description,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          group != null
              ? 'Grup "${group.name}" berhasil dibuat'
              : provider.error ?? 'Gagal membuat grup. Coba lagi.',
        ),
      ),
    );
  }
  return group;
}

/// Dialog to rename a group or change its description.
Future<void> showEditGroupDialog(BuildContext context, Group group) async {
  final provider = context.read<ZainNotoProvider>();

  final result = await showDialog<_GroupFormResult>(
    context: context,
    builder: (_) => _GroupFormDialog(
      title: 'Ubah Grup',
      initialName: group.name,
      initialDescription: group.description ?? '',
    ),
  );
  if (result == null || !context.mounted) return;

  final ok = await provider.updateGroup(
    id: group.id,
    name: result.name,
    description: result.description,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Grup diperbarui' : 'Gagal memperbarui grup'),
      ),
    );
  }
}

/// Payload collected by [_GroupFormDialog]; values are already trimmed.
class _GroupFormResult {
  const _GroupFormResult({required this.name, required this.description});

  final String name;
  final String description;
}

/// Name + description dialog that owns its controllers so they are disposed
/// only after the dialog route is fully removed from the tree.
class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog({
    required this.title,
    this.initialName = '',
    this.initialDescription = '',
    this.nameHint,
    this.descriptionHint,
  });

  final String title;
  final String initialName;
  final String initialDescription;
  final String? nameHint;
  final String? descriptionHint;

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _GroupFormResult(name: name, description: _descCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: groupInputDecoration(
              t,
              'Nama grup',
              hint: widget.nameHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: groupInputDecoration(
              t,
              'Deskripsi (opsional)',
              hint: widget.descriptionHint,
            ),
          ),
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
