import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_header.dart';
import '../../widgets/palette_sheet.dart';
import '../../zainnoto/models/derived.dart';
import '../../zainnoto/providers/zainnoto_provider.dart';
import '../../zainnoto/utils/format.dart';
import 'widgets/group_sheets.dart';

/// Layar pilih grup kas sesuai mockup `ZN-Grup.dc.html`: header varian
/// ZN-Grup (bottom padding 26, baris "Mode kelompok"), judul "Pilih grup kas",
/// kartu grup (kartu terpilih: border 2 aksen + check "Dipilih"), lalu tombol
/// "Buat grup baru" dan "Gabung dengan kode".
class GroupPickerScreen extends StatefulWidget {
  const GroupPickerScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const GroupPickerScreen()));

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  @override
  void initState() {
    super.initState();
    // Isi info anggota & saldo per grup (cache di-skip bila sudah termuat).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ZainNotoProvider>().loadPickerInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = context.watch<ZainNotoProvider>();
    final selectedId = provider.selectedGroup?.id;

    return Scaffold(
      backgroundColor: t.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            bottomPadding: 26,
            title: 'ZainNoto',
            topRow: Text(
              'Mode kelompok',
              maxLines: 1,
              style: TextStyle(fontSize: AppText.body, color: t.headerMuted),
            ),
            onPaletteTap: () => showPaletteSheet(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Pilih grup kas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final group in provider.groups) ...[
                  _GroupCard(
                    title: group.name,
                    info: provider.pickerInfo[group.id],
                    selected: group.id == selectedId,
                    onTap: () {
                      if (group.id != selectedId) {
                        provider.selectGroup(group);
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                _PickerButton(
                  label: 'Buat grup baru',
                  primary: true,
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    final created = await showCreateGroupDialog(context);
                    if (created != null && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _PickerButton(
                  label: 'Gabung dengan kode',
                  primary: false,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fitur gabung kode belum tersedia'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final GroupPickerInfo? info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(selected ? 15 : 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? t.accent : t.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? t.persik : t.softSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.work_rounded, size: 24, color: t.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  if (info != null) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${info!.memberCount} anggota · '
                        '${formatRupiah(info!.balance)}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppText.body,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Semantics(
                label: 'Dipilih',
                child: Icon(Icons.check_rounded, size: 22, color: t.accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.primary,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool primary;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? t.accent : t.card,
          foregroundColor: primary ? Colors.white : t.accent,
          elevation: 0,
          side: primary ? null : BorderSide(color: t.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
