import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class DonutChartItem {
  final double value;
  final Color color;

  DonutChartItem({required this.value, required this.color});
}

class DonutChart extends StatelessWidget {
  final List<DonutChartItem> items;
  final double size;
  final double strokeWidth;
  final Widget? centerWidget;

  const DonutChart({
    super.key,
    required this.items,
    this.size = 140.0,
    this.strokeWidth = 14.0,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    final double total = items.fold(0.0, (sum, item) => sum + item.value);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutChartPainter(
              items: items,
              total: total,
              strokeWidth: strokeWidth,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF381932)
                  : context.tokens.softSurface,
            ),
          ),
          if (centerWidget != null)
            SizedBox(
              width: size - (strokeWidth * 3),
              child: centerWidget,
            ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutChartItem> items;
  final double total;
  final double strokeWidth;
  final Color backgroundColor;

  _DonutChartPainter({
    required this.items,
    required this.total,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // Draw background circle
    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    if (total <= 0) return;

    double startAngle = -pi / 2; // Start from top

    for (final item in items) {
      if (item.value <= 0) continue;

      final sweepAngle = (item.value / total) * 2 * pi;

      paint.color = item.color;
      paint.strokeCap = StrokeCap.round;

      // Draw active slice arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.items.length != items.length;
  }
}
