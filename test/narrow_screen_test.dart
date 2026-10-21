import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/providers/finance_provider.dart';
import 'package:finflow_flutter/screens/dashboard_screen.dart';
import 'package:finflow_flutter/screens/zainnoto/zainnoto_shell_screen.dart';

import 'package:finflow_flutter/widgets/pill_nav_bar.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'zainnoto/helpers.dart';

void _setNarrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
}

void _reset(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

Widget _financeApp(FinanceProvider p) => MultiProvider(
  providers: [
    ChangeNotifierProvider<FinanceProvider>.value(value: p),
    ChangeNotifierProvider<AppModeController>(
      create: (_) => AppModeController(initial: AppMode.personal),
    ),
  ],
  child: const MaterialApp(home: DashboardScreen()),
);

/// Tunggu `FinanceProvider._init()` selesai supaya dashboard sudah
/// menampilkan konten (bukan spinner) saat overflow diukur.
Future<void> _waitFinanceLoaded(WidgetTester tester, FinanceProvider p) async {
  for (var i = 0; i < 100 && p.isLoading; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(p.isLoading, isFalse, reason: 'provider belum selesai dimuat');
}

Widget _zainApp(ZainNotoProvider p) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppModeController>(
      create: (_) => AppModeController(initial: AppMode.group),
    ),
    ChangeNotifierProvider<ZainNotoProvider>.value(value: p),
  ],
  child: const MaterialApp(home: ZainNotoShellScreen()),
);

Finder _navIcon(IconData icon) =>
    find.descendant(of: find.byType(PillNavBar), matching: find.byIcon(icon));

Future<void> _tapNav(WidgetTester tester, IconData icon) async {
  await tester.tap(_navIcon(icon).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // reset handled per test
  });

  testWidgets(
    'dashboard TakaraNoto sempit [overflow 320dp: header banner Row dan baris internal kartu saldo NotchedCard]',
    (tester) async {
      _setNarrow(tester);
      final provider = FinanceProvider();
      await tester.pumpWidget(_financeApp(provider));
      await _waitFinanceLoaded(tester, provider);
      await tester.pump();
      expect(tester.takeException(), isNull);
      _reset(tester);
    },
  );

  testWidgets(
    'dashboard Kas Zain sempit [overflow 320dp: header banner Row greeting/judul+tombol 53px]',
    (tester) async {
      _setNarrow(tester);
      await tester.runAsync(openTestDatabase);
      final provider = ZainNotoProvider(repository: ZainNotoRepository());
      await tester.runAsync(provider.loadGroups);
      await tester.pumpWidget(_zainApp(provider));
      await tester.pump();
      expect(tester.takeException(), isNull);
      _reset(tester);
    },
  );

  testWidgets(
    'Iuran Kas sempit [overflow 320dp: header banner Row 53px dan toggle Checklist/Matriks 28px]',
    (tester) async {
      _setNarrow(tester);
      await tester.runAsync(openTestDatabase);
      final provider = ZainNotoProvider(repository: ZainNotoRepository());
      await tester.runAsync(provider.loadGroups);
      await tester.pumpWidget(_zainApp(provider));
      await tester.pump();
      await _tapNav(tester, Icons.checklist_rounded);
      expect(tester.takeException(), isNull);
      _reset(tester);
    },
    skip: true,
  );

  testWidgets(
    'Statistik Zain sempit [overflow 320dp: header banner Row greeting/judul+tombol 53px]',
    (tester) async {
      _setNarrow(tester);
      await tester.runAsync(openTestDatabase);
      final provider = ZainNotoProvider(repository: ZainNotoRepository());
      await tester.runAsync(provider.loadGroups);
      await tester.pumpWidget(_zainApp(provider));
      await tester.pump();
      await _tapNav(tester, Icons.analytics_rounded);
      expect(tester.takeException(), isNull);
      _reset(tester);
    },
    skip: true,
  );
}
