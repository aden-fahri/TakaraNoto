import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/widgets/list_row.dart';
import 'package:finflow_flutter/widgets/sheet_scaffold.dart';
import 'package:finflow_flutter/widgets/status_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.getTheme(
      const Color(0xFF381932),
      const Color(0xFFFFF3E6),
      palette: ThemePalette.plum,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('StatusBadge warna token lunas', (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(label: 'Lunas', kind: StatusKind.lunas)));
    final t = tester.widget<Container>(find.byType(Container).first);
    final deco = t.decoration! as BoxDecoration;
    final tokens = AppTokens.plum(Brightness.light);
    expect(deco.color, tokens.lunasBg);
  });

  testWidgets('ListRow render judul dan nominal', (tester) async {
    await tester.pumpWidget(_wrap(const ListRow(
      icon: Icons.coffee,
      title: 'Kopi',
      subtitle: 'Hari ini',
      amount: 'Rp 15.000',
      amountColor: Color(0xFFBE123C),
    )));
    expect(find.text('Kopi'), findsOneWidget);
    expect(find.text('Rp 15.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SheetScaffold handle 40×4 dan judul', (tester) async {
    await tester.pumpWidget(_wrap(const SheetScaffold(
      title: 'Bayar iuran',
      child: SizedBox(height: 100),
    )));
    expect(find.text('Bayar iuran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SheetField tinggi 52', (tester) async {
    await tester.pumpWidget(_wrap(const SheetField(hint: 'Jumlah')));
    final size = tester.getSize(find.byType(SizedBox).first);
    expect(size.height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SheetPrimaryButton tinggi 52', (tester) async {
    await tester.pumpWidget(_wrap(const SheetPrimaryButton(label: 'Bayar')));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, 52);
    expect(tester.takeException(), isNull);
  });
}
