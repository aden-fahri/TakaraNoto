import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/widgets/max_width_body.dart';
import 'package:finflow_flutter/widgets/pill_nav_bar.dart';

void main() {
  testWidgets('MaxWidthBody membatasi lebar konten di layar lebar',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MaxWidthBody(
            child: SizedBox.expand(key: Key('content')),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 600);
  });

  testWidgets('MaxWidthBody tetap penuh di layar sempit', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MaxWidthBody(
            child: SizedBox.expand(key: Key('content')),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 400);
  });

  testWidgets('PillNavBar punya label semantik per tab', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PillNavBar(
            currentIndex: 0,
            items: const [
              NavItem(icon: Icons.home_rounded, label: 'Beranda'),
              NavItem(icon: Icons.list_alt_rounded, label: 'Riwayat'),
            ],
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Beranda')),
      matchesSemantics(
        label: 'Beranda',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
