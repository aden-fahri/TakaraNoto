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
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _descCtrl = TextEditingController(
    text: widget.initialDescription,
  );
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
                    style: TextStyle(
                      fontSize: AppText.label,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Warna',
              style: TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              // ListView horizontal tidak mendukung intrinsik (AlertDialog
              // membungkus konten dalam IntrinsicWidth); SingleChildScrollView
              // punya viewport sendiri yang aman untuk intrinsik.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _groupColorOptions.length; i++)
                      if (i > 0) const SizedBox(width: 8),
                    for (final hex in _groupColorOptions)
                      Builder(
                        builder: (context) {
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
                                    ? Border.all(
                                        color: t.textPrimary,
                                        width: 2.5,
                                      )
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ikon',
              style: TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            // GridView (sliver) tidak mendukung intrinsik; Wrap menampilkan
            // pilihan ikon 6-per-baris tanpa viewport.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < groupIconOptions.length; i++)
                  Builder(
                    builder: (context) {
                      final icon = groupIconOptions[i];
                      final selected = _iconIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _iconIndex = i),
                        child: Container(
                          width: 44,
                          height: 44,
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
                                      fontSize: AppText.subtitle,
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
          ],
        ),
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
