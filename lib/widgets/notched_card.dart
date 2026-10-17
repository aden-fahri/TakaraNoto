import 'package:flutter/material.dart';

/// Kartu dengan sudut membulat dan potongan notch berbentuk step di sudut
/// kanan atas. Shadow dan border mengikuti kontur notch.
class NotchedCard extends StatelessWidget {
  const NotchedCard({
    super.key,
    required this.color,
    required this.child,
    this.borderColor,
    this.borderWidth = 1.2,
    this.shadowColor,
    this.shadowBlur = 14,
    this.shadowOffset = const Offset(0, 4),
    this.radius = 24,
    this.notchWidth = 64,
    this.notchHeight = 26,
    this.notchRadius = 10,
  });

  final Color color;
  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final double notchRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedCardPainter(
        color: color,
        borderColor: borderColor,
        borderWidth: borderWidth,
        shadowColor: shadowColor,
        shadowBlur: shadowBlur,
        shadowOffset: shadowOffset,
        radius: radius,
        notchWidth: notchWidth,
        notchHeight: notchHeight,
        notchRadius: notchRadius,
      ),
      child: child,
    );
  }
}

/// Kontur [NotchedCard] untuk [rect]: rounded rect dikurangi notch step
/// di kanan atas, dengan fillet dalam di dua sudut notch.
Path buildNotchedCardPath(
  Rect rect, {
  double radius = 24,
  double notchWidth = 64,
  double notchHeight = 26,
  double notchRadius = 10,
}) {
  final base = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  final notch = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          rect.right - notchWidth,
          rect.top,
          rect.right + notchWidth,
          rect.top + notchHeight,
        ),
        Radius.circular(notchRadius),
      ),
    );
  return Path.combine(PathOperation.difference, base, notch);
}

class _NotchedCardPainter extends CustomPainter {
  _NotchedCardPainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.radius,
    required this.notchWidth,
    required this.notchHeight,
    required this.notchRadius,
  });

  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildNotchedCardPath(
      Offset.zero & size,
      radius: radius,
      notchWidth: notchWidth,
      notchHeight: notchHeight,
      notchRadius: notchRadius,
    );

    if (shadowColor != null && shadowBlur > 0) {
      final shadowPaint = Paint()
        ..color = shadowColor!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur / 2);
      canvas.drawPath(path.shift(shadowOffset), shadowPaint);
    }

    canvas.drawPath(path, Paint()..color = color);

    if (borderColor != null && borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_NotchedCardPainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.shadowColor != shadowColor ||
      old.shadowBlur != shadowBlur ||
      old.shadowOffset != shadowOffset ||
      old.radius != radius ||
      old.notchWidth != notchWidth ||
      old.notchHeight != notchHeight ||
      old.notchRadius != notchRadius;
}
