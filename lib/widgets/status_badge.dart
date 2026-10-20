import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Lencana status pil (Lunas/Telat/Cicil) dengan warna dari token.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.kind});

  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (kind) {
      StatusKind.lunas => (t.lunasBg, t.lunasFg),
      StatusKind.telat => (t.telatBg, t.telatFg),
      StatusKind.cicil => (t.cicilBg, t.cicilFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

enum StatusKind { lunas, telat, cicil }
