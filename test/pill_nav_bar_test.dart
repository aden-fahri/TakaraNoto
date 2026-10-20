import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/widgets/pill_nav_bar.dart';

void main() {
  testWidgets('PillNavBar tinggi == 76 (tanpa inset)', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PillNavBar(
          currentIndex: 0,
          items: const [
            NavItem(icon: Icons.home, label: 'Home'),
            NavItem(icon: Icons.list, label: 'Riwayat'),
            NavItem(icon: Icons.pie_chart, label: 'Anggaran'),
            NavItem(icon: Icons.savings, label: 'Tabungan'),
            NavItem(icon: Icons.analytics, label: 'Laporan'),
          ],
          onTap: (_) {},
        ),
      ),
    ));
    await tester.pump();
    final size = tester.getSize(find.byType(PillNavBar));
    expect(size.height, 76);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('PillNavBar 5 item + label di 320dp tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PillNavBar(
          currentIndex: 0,
          items: const [
            NavItem(icon: Icons.home, label: 'Home'),
            NavItem(icon: Icons.list, label: 'Riwayat'),
            NavItem(icon: Icons.pie_chart, label: 'Anggaran'),
            NavItem(icon: Icons.savings, label: 'Tabungan'),
            NavItem(icon: Icons.analytics, label: 'Laporan'),
          ],
          onTap: (_) {},
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
