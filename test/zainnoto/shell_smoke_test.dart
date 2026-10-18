import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/screens/zainnoto/zainnoto_shell_screen.dart';
import 'package:finflow_flutter/widgets/mode_switch_button.dart';
import 'package:finflow_flutter/widgets/pill_nav_bar.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

Widget _app(ZainNotoProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeController>(
          create: (_) => AppModeController(initial: AppMode.group),
        ),
        ChangeNotifierProvider<ZainNotoProvider>.value(value: provider),
      ],
      child: const MaterialApp(home: ZainNotoShellScreen()),
    );

Finder _navIcon(IconData icon) => find.descendant(
      of: find.byType(PillNavBar),
      matching: find.byIcon(icon),
    );

Future<void> _tapNav(WidgetTester tester, IconData icon) async {
  await tester.tap(_navIcon(icon).first);
  await tester.pump();
  // Biarkan animasi pill/AnimatedSwitcher selesai sebelum tap berikutnya.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell ZainNoto tanpa grup: banner tampil & semua tab aman dibuild',
      (tester) async {
    await tester.runAsync(openTestDatabase);
    final provider = ZainNotoProvider(repository: ZainNotoRepository());
    await tester.runAsync(provider.loadGroups);

    await tester.pumpWidget(_app(provider));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Banner dengan nama grup fallback harus selalu terlihat.
    expect(find.text('Belum ada grup'), findsOneWidget);
    // Tombol pindah mode menampilkan mode tujuan (TakaraNoto).
    expect(find.byType(ModeSwitchButton), findsOneWidget);
    expect(find.text('TakaraNoto'), findsOneWidget);

    await _tapNav(tester, Icons.checklist_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Iuran');

    await _tapNav(tester, Icons.receipt_long_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Transaksi');

    await _tapNav(tester, Icons.analytics_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Statistik');

    await _tapNav(tester, Icons.home_rounded);
    expect(tester.takeException(), isNull, reason: 'kembali ke Beranda');
  });

  testWidgets('shell ZainNoto dengan data grup: kartu dompet & tab aman dibuild',
      (tester) async {
    await tester.runAsync(openTestDatabase);
    final repository = ZainNotoRepository();
    final provider = ZainNotoProvider(repository: repository);

    await tester.runAsync(() async {
      final groupId = await repository.createGroup(name: 'Kas Futsal');
      await repository.addMember(
        groupId: groupId,
        name: 'Budi',
        joinedAt: '2026-01-01',
      );
      await repository.addMember(
        groupId: groupId,
        name: 'Ani',
        joinedAt: '2026-01-01',
      );
      await repository.upsertDuesPlan(
        groupId: groupId,
        amount: 20000,
        frequency: DuesFrequency.monthly,
        dueDay: 10,
        startDate: '2026-01-01',
      );
      await provider.loadGroups();
    });

    await tester.pumpWidget(_app(provider));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Kas Futsal'), findsWidgets);
    expect(find.text('Saldo Kas Bersama'), findsOneWidget);

    await _tapNav(tester, Icons.checklist_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Iuran (ada data)');

    await _tapNav(tester, Icons.receipt_long_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Transaksi (ada data)');

    await _tapNav(tester, Icons.analytics_rounded);
    expect(tester.takeException(), isNull, reason: 'tab Statistik (ada data)');
  });
}
