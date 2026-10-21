import 'package:flutter/material.dart';

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
    this.notchRatio = 0.30,
    this.notchWidth,
    this.notchHeight = 44,
    this.notchRadius = 16,
  });

  final Color color;
  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final double radius;
  final double? notchRatio;
  final double? notchWidth;
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
      notchRatio: notchRatio ?? 0.30,
        notchWidth: notchWidth,
        notchHeight: notchHeight,
        notchRadius: notchRadius,
      ),
      child: child,
    );
  }
}

/// Path kartu bertakik persis seperti SVG di `docs/mockup/Main.dc.html`:
/// `M24 0H234 A16 16 0 0 1 250 16 V28 A16 16 0 0 0 266 44 H334
///  A24 24 0 0 1 358 68 V190 A24 24 0 0 1 334 214 H24 A24 24 0 0 1 0 190
///  V24 A24 24 0 0 1 24 0Z` (untuk 358×214).
///
/// Artinya: dinding takik `rect.right - notchWidth`, fillet 16 di dinding
/// atas dan dasar, lalu bahu luar radius 24 yang membuat tepi kanan kartu
/// baru mulai pada `top + notchHeight + 24`.
Path buildNotchedCardPath(
  Rect rect, {
  double radius = 24,
  double notchRatio = 0.30,
  double? notchWidth,
  double notchHeight = 44,
  double notchRadius = 16,
}) {
  final nW = notchWidth ?? rect.width * notchRatio;
  final usable =
      nW + notchRadius > radius && notchHeight + radius < rect.height;
  if (!usable) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  final wall = rect.right - nW;
  return Path()
    ..moveTo(rect.left + radius, rect.top)
    ..lineTo(wall - notchRadius, rect.top)
    ..arcToPoint(
      Offset(wall, rect.top + notchRadius),
      radius: Radius.circular(notchRadius),
      largeArc: false,
      clockwise: true,
    )
    ..lineTo(wall, rect.top + notchHeight - notchRadius)
    ..arcToPoint(
      Offset(wall + notchRadius, rect.top + notchHeight),
      radius: Radius.circular(notchRadius),
      largeArc: false,
      clockwise: false,
    )
    ..lineTo(rect.right - radius, rect.top + notchHeight)
    ..arcToPoint(
      Offset(rect.right, rect.top + notchHeight + radius),
      radius: Radius.circular(radius),
      largeArc: false,
      clockwise: true,
    )
    ..lineTo(rect.right, rect.bottom - radius)
    ..arcToPoint(
      Offset(rect.right - radius, rect.bottom),
      radius: Radius.circular(radius),
      largeArc: false,
      clockwise: true,
    )
    ..lineTo(rect.left + radius, rect.bottom)
    ..arcToPoint(
      Offset(rect.left, rect.bottom - radius),
      radius: Radius.circular(radius),
      largeArc: false,
      clockwise: true,
    )
    ..lineTo(rect.left, rect.top + radius)
    ..arcToPoint(
      Offset(rect.left + radius, rect.top),
      radius: Radius.circular(radius),
      largeArc: false,
      clockwise: true,
    )
    ..close();
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
    required this.notchRatio,
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
  final double? notchRatio;
  final double? notchWidth;
  final double notchHeight;
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildNotchedCardPath(
      Offset.zero & size,
      radius: radius,
      notchRatio: notchRatio ?? 0.30,
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
      old.notchRatio != notchRatio ||
      old.notchWidth != notchWidth ||
      old.notchHeight != notchHeight ||
      old.notchRadius != notchRadius;
}
