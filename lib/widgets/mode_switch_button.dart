import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_controller.dart';
import '../theme/app_tokens.dart';

/// Tombol ringkas untuk berpindah shell antar mode.
///
/// Dipasang di deret tombol header: di samping tombol theme pada dashboard
/// TakaraNoto dan di deret kanan-atas banner ZainNoto. Menampilkan mode
/// TUJUAN beserta panah: `ZainNoto →` saat berada di mode Pribadi, dan
/// `TakaraNoto →` saat berada di mode Kelompok.
class ModeSwitchButton extends StatelessWidget {
  const ModeSwitchButton({super.key});

  static const double _height = 40;

  void _switch(BuildContext context, AppMode target) {
    HapticFeedback.selectionClick();
    context.read<AppModeController>().setMode(target);
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeController>().mode;
    final toGroup = mode == AppMode.personal;
    final label = toGroup ? 'ZainNoto' : 'TakaraNoto';
    final t = context.tokens;

    // Tombol header sesuai mockup (`.btn40`): latar chip, radius 14,
    // border putih 25%, ikon panah 16 + nama aplikasi tujuan, jarak 6.
    return GestureDetector(
      onTap: () => _switch(context, toGroup ? AppMode.group : AppMode.personal),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
