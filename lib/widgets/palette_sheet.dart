import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/theme_settings_screen.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';
import 'sheet_scaffold.dart';

/// Lembar pemilih tema sederhana: Plum Klasik, Teal, Kustom + toggle gelap.
void showPaletteSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PaletteSheet(),
  );
}

class _PaletteSheet extends StatelessWidget {
  const _PaletteSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final controller = context.watch<ThemeController>();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SingleChildScrollView(
        child: SheetScaffold(
          title: 'Pilih tema',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaletteTile(
                label: 'Plum Klasik',
                selected: controller.palette == ThemePalette.plum,
                onTap: () => controller.setPalette(ThemePalette.plum),
              ),
              _PaletteTile(
                label: 'Teal',
                selected: controller.palette == ThemePalette.teal,
                onTap: () => controller.setPalette(ThemePalette.teal),
              ),
              _PaletteTile(
                label: 'Kustom',
                selected: controller.palette == ThemePalette.custom,
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop(); // tutup sheet
                  nav.push(
                    MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  'Mode gelap',
                  style: TextStyle(fontSize: AppText.bodyLarge, color: t.textPrimary),
                ),
                value: controller.darkMode,
                onChanged: (v) => controller.setDarkMode(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      title: Text(label, style: TextStyle(fontSize: AppText.bodyLarge, color: t.textPrimary)),
      trailing: selected ? Icon(Icons.check, color: t.accent) : null,
      onTap: onTap,
    );
  }
}
