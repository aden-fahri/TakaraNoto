import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/screens/zainnoto/tabs/iuran_tab.dart';
import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/widgets/status_badge.dart';
import 'package:finflow_flutter/zainnoto/providers/zainnoto_provider.dart';
import 'package:finflow_flutter/zainnoto/repositories/zainnoto_repository.dart';

import 'helpers.dart';

const _seed = Color(0xFF381932);
const _bg = Color(0xFFFFF3E6);

AppTokens get _tokens => AppTokens.plum(Brightness.light);

void _viewport(
  WidgetTester tester, {
  double w = 390,
  double h = 844,
  double textScale = 1.0,
}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _app(ZainNotoProvider provider) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppModeController>(
      create: (_) => AppModeController(initial: AppMode.group),
    ),
    ChangeNotifierProvider<ZainNotoProvider>.value(value: provider),
  ],
  child: MaterialApp(
    theme: AppTheme.getTheme(_seed, _bg, palette: ThemePalette.plum),
    home: const IuranTab(),
  ),
);

/// Seed Kas RT 05 (pembayaran 10 Okt 2026) + jam disuntik 21 Okt 2026.
Future<ZainNotoProvider> _seeded(
  WidgetTester tester, {
  DateTime? now,
}) async {
  final db = await tester.runAsync(openTestDatabase);
  await tester.runAsync(
    () => ExampleSeed.seed(db!, asOf: DateTime(2026, 10, 15)),
  );
  final provider = ZainNotoProvider(
    repository: ZainNotoRepository(),
    now: () => now ?? DateTime(2026, 10, 21),
  );
  await tester.runAsync(provider.loadGroups);
  return provider;
}

Future<void> _pumpIuran(WidgetTester tester, ZainNotoProvider provider) async {
  await tester.pumpWidget(_app(provider));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

Future<void> _switchToMatrix(
  WidgetTester tester,
  ZainNotoProvider provider,
) async {
  await tester.runAsync(() => provider.loadMatrix(maxPeriods: 4));
  await tester.tap(find.byKey(const ValueKey('zn-view-matriks')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

Finder _row(String name) => find.byKey(ValueKey('zn-iuran-row-$name'));

StatusBadge _badgeOf(WidgetTester tester, String name) =>
    tester.widget<StatusBadge>(
      find.descendant(of: _row(name), matching: find.byType(StatusBadge)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  testWidgets(
    'Checklist Iuran: header, toggle, periode, ringkasan, badge & sisa per anggota seed',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);

      // Hitung tangan seed (pembayaran 10 Okt, jam 21 Okt 2026):
      //   terkumpul = 5 x 50.000 + 25.000 = 275.000; target 8 x 50.000
      //   lunas = Budi, Sari, Andi, Rudi, Lina (5)
      //   cicil = Maya (25.000 dari 50.000), sisa 25.000
      //   telat = Dewi (Sep+Okt), Joko (Okt): lewat jatuh tempo 10 Okt
      final remaining = {
        for (final row in provider.periodRows) row.memberName: row.remaining,
      };
      expect(remaining, {
        'Budi': 0,
        'Sari': 0,
        'Andi': 0,
        'Dewi': 50000,
        'Rudi': 0,
        'Maya': 25000,
        'Joko': 50000,
        'Lina': 0,
      });

      await _pumpIuran(tester, provider);

      // Header sama dengan ZN-Iuran: chip grup + judul ZainNoto.
      expect(find.text('Kas RT 05'), findsOneWidget);
      expect(find.text('ZainNoto'), findsOneWidget);
      expect(find.text('Iuran kas'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Matriks'), findsOneWidget);

      // Periode terpilih + ringkasan periode berjalan.
      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.text('5 dari 8 lunas'), findsOneWidget);
      expect(
        find.text('Terkumpul Rp 275.000 / 400.000'),
        findsOneWidget,
      );

      const kinds = {
        'Budi': StatusKind.lunas,
        'Sari': StatusKind.lunas,
        'Andi': StatusKind.lunas,
        'Dewi': StatusKind.telat,
        'Rudi': StatusKind.lunas,
        'Maya': StatusKind.cicil,
        'Joko': StatusKind.telat,
        'Lina': StatusKind.lunas,
      };
      const labels = {
        'Budi': 'Lunas',
        'Sari': 'Lunas',
        'Andi': 'Lunas',
        'Dewi': 'Telat',
        'Rudi': 'Lunas',
        'Maya': 'Cicil',
        'Joko': 'Telat',
        'Lina': 'Lunas',
      };
      for (final name in kinds.keys) {
        expect(_row(name), findsOneWidget, reason: 'baris $name');
        final badge = _badgeOf(tester, name);
        expect(badge.kind, kinds[name], reason: 'badge $name');
        expect(badge.label, labels[name], reason: 'label badge $name');
      }

      // Sisa tagihan per baris (angka hitung tangan, bukan keberadaan teks).
      final subtitles = {
        'Budi': 'Bayar Rp 50.000',
        'Sari': 'Bayar Rp 50.000',
        'Andi': 'Bayar Rp 50.000',
        'Dewi': 'Telat 11 hari · 2 periode · sisa Rp 50.000',
        'Rudi': 'Bayar Rp 50.000',
        'Maya': 'Masuk Rp 25.000 dari Rp 50.000',
        'Joko': 'Telat 11 hari · sisa Rp 50.000',
        'Lina': 'Bayar Rp 50.000',
      };
      for (final entry in subtitles.entries) {
        expect(
          find.descendant(
            of: _row(entry.key),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
          reason: '${entry.key}: ${entry.value}',
        );
      }

      // Warna badge dari token (bukan hex lokal).
      Color badgeBg(String name) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          of: find.descendant(
                            of: _row(name),
                            matching: find.byType(StatusBadge),
                          ),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(badgeBg('Budi'), _tokens.lunasBg);
      expect(badgeBg('Maya'), _tokens.cicilBg);
      expect(badgeBg('Dewi'), _tokens.telatBg);

      // Tanpa ellipsis pada nominal.
      final truncated = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => s.endsWith('…') || s.endsWith('...'))
          .toList();
      expect(truncated, isEmpty, reason: 'teks terpotong: $truncated');
    },
  );

  testWidgets(
    'Checklist Iuran: waived tidak Telat dan periode belum jatuh tempo netral',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);

      // Bebaskan Joko pada periode Oktober (dia telat sebelum waived).
      final joko = provider.periodRows.firstWhere(
        (row) => row.memberName == 'Joko',
      );
      await tester.runAsync(
        () => provider.setChargeWaived(joko.chargeId, waived: true),
      );
      await _pumpIuran(tester, provider);

      // Joko tidak lagi dihitung lunas dan tidak boleh tampil Telat.
      expect(
        find.descendant(of: _row('Joko'), matching: find.byType(StatusBadge)),
        findsNothing,
        reason: 'waived bukan Lunas/Telat/Cicil',
      );
      expect(
        find.descendant(
          of: _row('Joko'),
          matching: find.text('Bebas iuran'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: _row('Joko'), matching: find.text('Telat')), findsNothing);
      expect(find.text('5 dari 7 lunas'), findsOneWidget);

      // Periode November yang belum jatuh tempo (jam 21 Okt): tanpa Telat.
      await tester.runAsync(
        () => provider.repository.generatePeriods(
          groupId: provider.selectedGroup!.id,
          upTo: DateTime(2026, 11, 30),
        ),
      );
      await tester.runAsync(provider.refreshGroup);
      final nov = provider.periods.firstWhere(
        (period) => period.label == 'November 2026',
      );
      await tester.runAsync(() => provider.selectPeriod(nov));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byType(StatusBadge), findsNothing, reason: 'belum ada Telat');
      expect(
        find.descendant(
          of: _row('Joko'),
          matching: find.text('Jatuh tempo 10 Nov · sisa Rp 50.000'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Matriks Iuran: sel anggota x periode seed diuji per sel', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _seeded(tester);
    await _pumpIuran(tester, provider);
    await _switchToMatrix(tester, provider);

    final periods = provider.periods; // Jul, Agu, Sep, Okt 2026
    expect(periods.map((p) => p.label), [
      'Juli 2026',
      'Agustus 2026',
      'September 2026',
      'Oktober 2026',
    ]);
    for (final label in ['Jul', 'Agu', 'Sep', 'Okt']) {
      expect(find.text(label), findsOneWidget, reason: 'header $label');
    }

    // Hitung tangan FIFO pembayaran seed:
    //   Budi/Sari/Andi/Rudi/Lina 200.000 = 4 x 50.000 -> OK semua
    //   Maya 175.000 = Jul-Sep lunas + 25.000 Okt  -> ½ di Okt
    //   Dewi 100.000 = Jul-Agu lunas; Sep & Okt telat (!)
    //   Joko 150.000 = Jul-Sep lunas; Okt telat (!)
    const expected = {
      'Budi': ['OK', 'OK', 'OK', 'OK'],
      'Sari': ['OK', 'OK', 'OK', 'OK'],
      'Andi': ['OK', 'OK', 'OK', 'OK'],
      'Dewi': ['OK', 'OK', '!', '!'],
      'Rudi': ['OK', 'OK', 'OK', 'OK'],
      'Maya': ['OK', 'OK', 'OK', '½'],
      'Joko': ['OK', 'OK', 'OK', '!'],
      'Lina': ['OK', 'OK', 'OK', 'OK'],
    };
    final colors = <String, (Color, Color)>{
      'OK': (_tokens.lunasBg, _tokens.lunasFg),
      '½': (_tokens.cicilBg, _tokens.cicilFg),
      '!': (_tokens.telatBg, _tokens.telatFg),
    };

    for (final member in provider.members) {
      final marks = expected[member.name]!;
      for (var i = 0; i < periods.length; i++) {
        final period = periods[i];
        final cell = find.byKey(
          ValueKey('zn-cell-${member.id}-${period.id}'),
        );
        expect(cell, findsOneWidget, reason: '${member.name} ${period.label}');
        final text = tester.widget<Text>(
          find.descendant(of: cell, matching: find.byType(Text)),
        );
        expect(
          text.data,
          marks[i],
          reason: '${member.name} ${period.label}',
        );
        final (bg, fg) = colors[marks[i]]!;
        final container = tester.widget<Container>(cell);
        expect(
          (container.decoration! as BoxDecoration).color,
          bg,
          reason: 'latar ${member.name} ${period.label}',
        );
        expect(
          text.style!.color,
          fg,
          reason: 'teks ${member.name} ${period.label}',
        );
      }
    }

    for (final label in ['Lunas', 'Cicil', 'Telat', 'Belum bergabung']) {
      expect(find.text(label), findsOneWidget, reason: 'legenda $label');
    }
  });

  testWidgets(
    'Bayar Iuran: sheet ZN-Bayar mencatat cicilan dan detail lama tetap terjangkau',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);
      await _pumpIuran(tester, provider);

      // Ketuk lingkaran Maya (cicil 25.000 dari 50.000).
      await tester.tap(find.byKey(const ValueKey('zn-pay-Maya')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bayar iuran'), findsOneWidget);
      expect(find.text('Maya · tagihan Oktober 2026'), findsOneWidget);
      expect(find.text('Jumlah bayar'), findsOneWidget);
      expect(find.text('Total tagihan'), findsOneWidget);
      expect(find.text('Lunasi semua'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('zn-pay-chip-partial')),
          matching: find.text('Cicil'),
        ),
        findsOneWidget,
        reason: 'chip Cicil di sheet (badge di belakang sheet tidak dihitung)',
      );
      expect(find.text('21 Okt 2026'), findsOneWidget);
      expect(
        find.text(
          'Dibayar lebih dari tagihan akan menjadi kredit dan otomatis '
          'dipakai di periode berikutnya.',
        ),
        findsOneWidget,
      );

      final amountField = tester.widget<TextField>(
        find.byKey(const ValueKey('zn-pay-amount')),
      );
      expect(amountField.controller!.text, '25.000', reason: 'sisa tagihan');

      // Cicil 10.000: sisa menjadi 15.000, status tetap Cicil.
      await tester.enterText(
        find.byKey(const ValueKey('zn-pay-amount')),
        '10000',
      );
      await tester.pump();
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pump();
      await tester.runAsync(() async {
        final sw = Stopwatch()..start();
        while (sw.elapsed < const Duration(seconds: 5) &&
            provider.periodRows
                    .firstWhere((r) => r.memberName == 'Maya')
                    .paid !=
                35000) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bayar iuran'), findsNothing, reason: 'sheet tertutup');
      final maya = provider.periodRows.firstWhere(
        (row) => row.memberName == 'Maya',
      );
      expect(maya.paid, 35000, reason: '25.000 lama + 10.000 cicilan');
      expect(maya.remaining, 15000);
      expect(provider.summary!.balance, 1435000);
      expect(
        find.descendant(of: _row('Maya'), matching: find.text('Cicil')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('Maya'),
          matching: find.text('Masuk Rp 35.000 dari Rp 50.000'),
        ),
        findsOneWidget,
      );
      // Habiskan timer SnackBar (Undo) agar teardown bersih.
      await tester.pump(const Duration(seconds: 5));

      // Detail lama tetap terjangkau: ketuk baris Maya.
      await tester.tap(_row('Maya'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Riwayat Pembayaran'), findsOneWidget);
      expect(find.byTooltip('Edit transaksi'), findsOneWidget);
      expect(find.byTooltip('Hapus transaksi'), findsOneWidget);
      expect(find.text('Bayar Sebagian'), findsOneWidget);
      expect(find.text('Tandai Bebas Iuran'), findsOneWidget);
      expect(find.text('Tandai Lunas · Rp 15.000'), findsOneWidget);
    },
    skip: true,
  );

  testWidgets('Iuran 320dp textScale 1.3: checklist & matriks tanpa overflow', (
    tester,
  ) async {
    _viewport(tester, w: 320, h: 640, textScale: 1.3);
    final provider = await _seeded(tester);
    await _pumpIuran(tester, provider);

    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final truncated = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => s.endsWith('…') || s.endsWith('...'))
        .toList();
    expect(truncated, isEmpty, reason: 'nominal terpotong: $truncated');

    // Kembali ke atas agar toggle Checklist/Matriks ikut ter-build lagi.
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pump();
    await _switchToMatrix(tester, provider);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
