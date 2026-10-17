import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';

/// Settings screen to pick the app colors: accent + background.
/// Each has preset swatches and a custom HSV/hex picker.
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  Future<void> _openCustomPicker(
    BuildContext context, {
    required bool forBackground,
  }) async {
    final controller = context.read<ThemeController>();
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _CustomColorDialog(
        initial: forBackground ? controller.background : controller.seed,
      ),
    );
    if (picked == null) return;
    if (forBackground) {
      await controller.setBackground(picked);
    } else {
      await controller.setSeed(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.pageBg,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text(
                  'Warna Aksen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Warna ini dipakai untuk banner, tombol utama, dan elemen aktif di seluruh aplikasi.',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                const SizedBox(height: 20),
                const _PreviewCard(),
                const SizedBox(height: 28),
                Text(
                  'Preset Warna',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final preset in ThemeController.presets)
                      _PresetCircle(
                        preset: preset,
                        selected: controller.seed.toARGB32() ==
                            preset.color.toARGB32(),
                        onTap: () => controller.setSeed(preset.color),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Warna Kustom',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _CustomColorTile(
                  color: controller.seed,
                  label: 'Pilih warna kustom',
                  onTap: () =>
                      _openCustomPicker(context, forBackground: false),
                ),
                const SizedBox(height: 32),
                Text(
                  'Warna Latar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Warna dasar halaman di belakang kartu-kartu aplikasi.',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final preset in ThemeController.backgroundPresets)
                      _PresetCircle(
                        preset: preset,
                        selected: controller.background.toARGB32() ==
                            preset.color.toARGB32(),
                        onTap: () => controller.setBackground(preset.color),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _CustomColorTile(
                  color: controller.background,
                  label: 'Pilih warna latar kustom',
                  onTap: () =>
                      _openCustomPicker(context, forBackground: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header banner ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.headerSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.headerBorder, width: 1),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: t.headerFg,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Pengaturan Tema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.headerFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live preview card ────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRATINJAU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Rp 2.450.000',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saldo saat ini',
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewChip(label: 'Pemasukan', color: t.income),
              _PreviewChip(label: 'Pengeluaran', color: t.expense),
              _PreviewChip(label: 'Transfer', color: t.transfer),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tombol Utama',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: t.softSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.add_rounded, color: t.accent, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preset circle ────────────────────────────────────────────────────────────
class _PresetCircle extends StatelessWidget {
  const _PresetCircle({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: preset.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.textPrimary : t.border,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: preset.color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    color: ThemeData.estimateBrightnessForColor(preset.color) ==
                            Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              preset.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? t.textPrimary : t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom color entry tile ──────────────────────────────────────────────────
class _CustomColorTile extends StatelessWidget {
  const _CustomColorTile({
    required this.color,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback onTap;

  String get _hex => color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .substring(2)
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#$_hex',
                    style: TextStyle(fontSize: 11.5, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Custom color dialog (HSV sliders + hex input, no extra dependency) ───────
class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexCtrl = TextEditingController(text: _hexOf(widget.initial));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _hexOf(Color color) => color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .substring(2)
      .toUpperCase();

  void _syncHex() {
    _hexCtrl.text = _hexOf(_hsv.toColor());
  }

  void _onHexChanged(String value) {
    final cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length != 6) return;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return;
    setState(() {
      _hsv = HSVColor.fromColor(Color(0xFF000000 | parsed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final preview = _hsv.toColor();

    return AlertDialog(
      title: const Text('Warna Kustom'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
            ),
            const SizedBox(height: 16),
            _slider('Hue', _hsv.hue, 0, 360, (v) {
              setState(() {
                _hsv = _hsv.withHue(v);
                _syncHex();
              });
            }),
            _slider('Saturasi', _hsv.saturation, 0, 1, (v) {
              setState(() {
                _hsv = _hsv.withSaturation(v);
                _syncHex();
              });
            }),
            _slider('Kecerahan', _hsv.value, 0, 1, (v) {
              setState(() {
                _hsv = _hsv.withValue(v);
                _syncHex();
              });
            }),
            const SizedBox(height: 6),
            TextField(
              controller: _hexCtrl,
              onChanged: _onHexChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: '# ',
                labelText: 'Kode Hex',
                filled: true,
                fillColor: t.softSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          onPressed: () => Navigator.pop(context, preview),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textMuted,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: _hsv.toColor(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
