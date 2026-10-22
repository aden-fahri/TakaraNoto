import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// Chip nama grup di header (dipakai Beranda dan Iuran): tinggi 24, pil chip,
/// titik persik, nama yang menyusut tanpa ellipsis, ikon panah.
class GroupChip extends StatelessWidget {
  const GroupChip({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const ValueKey('zn-group-chip'),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('zn-group-chip-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: t.persik,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.expand_more_rounded,
              size: 12,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
