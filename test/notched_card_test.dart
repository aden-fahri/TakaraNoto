import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/widgets/notched_card.dart';

void main() {
  group('buildNotchedCardPath (358×214, notch 30%×44)', () {
    const rect = Rect.fromLTWH(0, 0, 358, 214);

    test('notchWidth ≈ 107.4 ± 1', () {
      // notch left edge = 358 − 107.4 = 250.6; pada y=22 (lurus, bukan fillet)
      // titik di dalam notch → di luar path
      expect(pathOutsideAt(rect, 252, 22), isTrue, reason: 'x=252 > 250.6, dalam notch');
      // titik di luar notch → di dalam path
      expect(pathInsideAt(rect, 248, 22), isTrue, reason: 'x=248 < 250.6, di luar notch');
    });

    test('memotong notch di sudut kanan atas (path = SVG mockup)', () {
      expect(pathOutsideAt(rect, 300, 20), isTrue, reason: 'dalam notch');
      expect(pathOutsideAt(rect, 357, 43), isTrue, reason: 'dalam notch');
      expect(pathInsideAt(rect, 150, 90), isTrue, reason: 'jauh dari notch');
      expect(pathInsideAt(rect, 200, 20), isTrue, reason: 'kiri notch');
      expect(pathInsideAt(rect, 300, 50), isTrue, reason: 'tepat di bawah dasar notch');
    });

    test('bahu luar radius 24 seperti SVG mockup (pusat (334,68))', () {
      // SVG: A24 24 0 0 1 358 68 dari titik (334,44).
      // Pada x=357 batas busur = 68 − √(24² − 23²) ≈ 61.1
      expect(pathOutsideAt(rect, 357, 50), isTrue, reason: 'di atas busur bahu (udara)');
      expect(pathInsideAt(rect, 357, 70), isTrue, reason: 'di bawah busur bahu');
      expect(pathInsideAt(rect, 345, 60), isTrue, reason: 'di dalam bahu');
      expect(pathOutsideAt(rect, 357, 45), isTrue, reason: 'dekat sudut luar yang terpotong');
    });

    test('mempertahankan sudut membulat radius 24', () {
      expect(pathOutsideAt(rect, 2, 2), isTrue);
      expect(pathOutsideAt(rect, 356, 212), isTrue);
      expect(pathOutsideAt(rect, 2, 212), isTrue);
      expect(pathInsideAt(rect, 12, 12), isTrue);
      expect(pathInsideAt(rect, 346, 202), isTrue);
    });

    testWidgets('NotchedCard me-render child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 358,
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

bool pathOutsideAt(Rect rect, double x, double y) =>
    !buildNotchedCardPath(rect).contains(Offset(x, y));

bool pathInsideAt(Rect rect, double x, double y) =>
    buildNotchedCardPath(rect).contains(Offset(x, y));
