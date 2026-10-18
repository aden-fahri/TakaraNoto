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
                    iconIndex: group.iconIndex,
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
    iconIndex: result.iconIndex,
    colorHex: result.colorHex,
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
      initialIconIndex: group.iconIndex,
      initialColorHex: group.colorHex,
    ),
  );
  if (result == null || !context.mounted) return;

  final ok = await provider.updateGroup(
    id: group.id,
    name: result.name,
    description: result.description,
    iconIndex: result.iconIndex,
    colorHex: result.colorHex,
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
  const _GroupFormResult({
    required this.name,
    required this.description,
    required this.iconIndex,
    required this.colorHex,
  });

  final String name;
  final String description;
  final int iconIndex;
  final String colorHex;
}

/// Warna yang bisa dipakai grup (default lama #059669 ada di urutan pertama).
const List<String> _groupColorOptions = [
  '#059669',
  '#3498db',
  '#9b59b6',
  '#e74c3c',
  '#f1c40f',
  '#fd79a8',
  '#1abc9c',
  '#e67e22',
  '#ff7f50',
  '#34495e',
];

/// Name + description dialog that owns its controllers so they are disposed
/// only after the dialog route is fully removed from the tree.
class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog({
    required this.title,
    this.initialName = '',
    this.initialDescription = '',
    this.initialIconIndex = 0,
    this.initialColorHex = '#059669',
    this.nameHint,
    this.descriptionHint,
  });

  final String title;
  final String initialName;
  final String initialDescription;
  final int initialIconIndex;
  final String initialColorHex;
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
  late int _iconIndex = widget.initialIconIndex;
  late String _colorHex = widget.initialColorHex;

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
      _GroupFormResult(
        name: name,
        description: _descCtrl.text.trim(),
        iconIndex: _iconIndex,
        colorHex: _colorHex,
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    if (value == null) return const Color(0xFF059669);
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 16),
            Row(
              children: [
                GroupAvatar(
                  name: _nameCtrl.text.trim(),
                  colorHex: _colorHex,
                  iconIndex: _iconIndex,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tampilan grup di daftar & banner',
                    style: TextStyle(fontSize: 11.5, color: t.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Warna',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _groupColorOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final hex = _groupColorOptions[i];
                  final selected = _colorHex == hex;
                  final color = _parseColor(hex);
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: t.textPrimary, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ikon',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: groupIconOptions.length,
              itemBuilder: (_, i) {
                final icon = groupIconOptions[i];
                final selected = _iconIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _iconIndex = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? t.accent.withValues(alpha: 0.15)
                          : t.softSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? t.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: icon == null
                        ? Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: selected ? t.accent : t.textMuted,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            size: 18,
                            color: selected ? t.accent : t.textMuted,
                          ),
                  ),
                );
              },
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
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
