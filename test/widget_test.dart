import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/widgets/donut_chart.dart';

void main() {
  testWidgets('DonutChart renders slices and center widget',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DonutChart(
            items: [
              DonutChartItem(value: 60, color: const Color(0xFF1abc9c)),
              DonutChartItem(value: 40, color: const Color(0xFFe74c3c)),
            ],
            size: 160,
            strokeWidth: 16,
            centerWidget: const Text('100%'),
          ),
        ),
      ),
    );

    expect(find.byType(DonutChart), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('DonutChart handles empty items without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DonutChart(items: const [], size: 120),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DonutChart), findsOneWidget);
  });
}
