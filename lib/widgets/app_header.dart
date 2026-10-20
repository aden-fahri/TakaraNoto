import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'mode_switch_button.dart';

/// Header bersama: latar hd, sudut bawah radius 32, padding 18/16/16/24.
/// Variant home (tinggi 172, kartu saldo menimpa) dan inner (tombol kembali).
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.topRow,
    this.onPaletteTap,
    this.height,
    this.child,
  });

  final String title;
  final Widget? leading;
  final Widget? topRow;
  final VoidCallback? onPaletteTap;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 8),
                  ],
                  if (topRow != null) Expanded(child: topRow!) else const Spacer(),
                  _PaletteButton(onTap: onPaletteTap),
                  const SizedBox(width: 8),
                  const ModeSwitchButton(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.display,
                  fontWeight: FontWeight.w600,
                  color: t.headerFg,
                ),
              ),
              if (child != null) ...[
                const SizedBox(height: 12),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'Pilih tema',
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.chip,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.palette_outlined, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
