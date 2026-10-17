import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/widgets/notched_card.dart';

void main() {
  group('buildNotchedCardPath', () {
    const rect = Rect.fromLTWH(0, 0, 300, 180);

    test('memotong step di sudut kanan atas', () {
      final path = buildNotchedCardPath(rect);

      expect(path.contains(const Offset(299, 2)), isFalse);
      expect(path.contains(const Offset(299, 40)), isTrue);
      expect(path.contains(const Offset(230, 2)), isTrue);
      expect(path.contains(const Offset(255, 2)), isFalse);
      expect(path.contains(const Offset(255, 40)), isTrue);
      expect(path.contains(const Offset(150, 90)), isTrue);
    });

    test('mempertahankan sudut membulat lainnya', () {
      final path = buildNotchedCardPath(rect);

      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(298, 178)), isFalse);
      expect(path.contains(const Offset(2, 178)), isFalse);
      expect(path.contains(const Offset(12, 12)), isTrue);
    });

    testWidgets('NotchedCard me-render child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              child: NotchedCard(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('isi'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('isi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
