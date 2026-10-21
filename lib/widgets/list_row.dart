import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Baris daftar: ikon kotak 42×42 radius 14 (atau [leading] kustom), judul
/// 13/500, keterangan 12 mu, nominal kanan 600 berwarna inc/exp — atau
/// [trailing] kustom (mis. StatusBadge).
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.icon,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.amount,
    this.amountColor,
    this.iconColor,
    this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final String title;
  final String? subtitle;
  final String? amount;
  final Color? amountColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final showBox = leading != null || icon != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (showBox) ...[
              leading ??
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.softSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon!, size: 20, color: iconColor ?? t.accent),
                  ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppText.bodyLarge,
                        fontWeight: FontWeight.w500,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        subtitle!,
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
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (amount != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    amount!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppText.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: amountColor ?? t.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
