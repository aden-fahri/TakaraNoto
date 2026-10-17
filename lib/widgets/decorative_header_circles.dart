import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Lingkaran dekoratif khas TakaraNoto yang ada di header/banner (besar dan jelas).
///
/// Harus ditempatkan langsung sebagai child `Stack` banner: widget ini
/// mengembalikan `Positioned.fill`, sehingga mengisi area banner yang sudah
/// tersizing oleh konten di belakangnya tanpa membuat Stack berukuran tak
/// hingga saat banner berada di parent bertinggi unbounded (mis. Column).
class DecorativeHeaderCircles extends StatelessWidget {
  const DecorativeHeaderCircles({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -45,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.headerFg.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 65,
            top: 35,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.headerFg.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

