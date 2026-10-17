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
    final t = context.tokens;
    final mode = context.watch<AppModeController>().mode;
    final toGroup = mode == AppMode.personal;
    final label = toGroup ? 'ZainNoto' : 'TakaraNoto';
    final icon = toGroup ? Icons.groups_rounded : Icons.person_rounded;

    return GestureDetector(
      onTap: () => _switch(
        context,
        toGroup ? AppMode.group : AppMode.personal,
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.headerSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.headerBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: t.headerFg),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.headerFg,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 15, color: t.headerFg),
          ],
        ),
      ),
    );
  }
}
