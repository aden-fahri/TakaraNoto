import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/screens/zainnoto/tabs/iuran_tab.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tab Iuran: FAB & tombol empty state membuka form anggota '
      '(nama saja, tanpa nomor HP)', (tester) async {
    await tester.runAsync(openTestDatabase);
    final repository = ZainNotoRepository();
    final provider = ZainNotoProvider(repository: repository);

    await tester.runAsync(() async {
      final groupId = await repository.createGroup(name: 'Kas Futsal');
      await repository.upsertDuesPlan(
        groupId: groupId,
        amount: 20000,
        frequency: DuesFrequency.monthly,
        dueDay: 10,
        startDate: '2026-01-01',
      );
      await provider.loadGroups();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<ZainNotoProvider>.value(
        value: provider,
        child: const MaterialApp(home: IuranTab()),
      ),
    );
    await tester.pump();

    // Tanpa anggota: FAB dan tombol empty state sama-sama tersedia.
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Tambah Anggota'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Form anggota cukup nama: tidak ada field nomor HP.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Nomor HP (opsional)'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Tombol empty state membuka form yang sama.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Anggota'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Nomor HP (opsional)'), findsNothing);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('provider.addMember cukup nama (tanpa nomor WA) & masuk daftar aktif',
      () async {
    await openTestDatabase();

    final repository = ZainNotoRepository();
    final provider = ZainNotoProvider(repository: repository);
    final groupId = await repository.createGroup(name: 'Kas Futsal');
    await repository.upsertDuesPlan(
      groupId: groupId,
      amount: 20000,
      frequency: DuesFrequency.monthly,
      dueDay: 10,
      startDate: '2026-01-01',
    );
    await provider.loadGroups();

    final ok = await provider.addMember(name: 'Budi');

    expect(ok, isTrue);
    expect(provider.error, isNull);
    final budi = provider.allMembers.singleWhere(
      (member) => member.name == 'Budi',
    );
    expect(budi.phoneNumber, isNull);
    expect(budi.isActive, isTrue);
  });
}
