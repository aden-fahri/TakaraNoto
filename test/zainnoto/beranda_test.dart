import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/screens/zainnoto/group_picker_screen.dart';
import 'package:finflow_flutter/screens/zainnoto/tabs/beranda_tab.dart';
import 'package:finflow_flutter/screens/zainnoto/widgets/group_management_sheet.dart';
import 'package:finflow_flutter/screens/zainnoto/widgets/transaction_form_sheet.dart';
import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/widgets/app_header.dart';
import 'package:finflow_flutter/widgets/notched_card.dart';
import 'package:finflow_flutter/widgets/status_badge.dart';
import 'package:finflow_flutter/zainnoto/models/entities.dart';
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

Widget _app(ZainNotoProvider provider, {ValueChanged<int>? onGoToTab}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeController>(
          create: (_) => AppModeController(initial: AppMode.group),
        ),
        ChangeNotifierProvider<ZainNotoProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.getTheme(_seed, _bg, palette: ThemePalette.plum),
        home: Scaffold(
          backgroundColor: _tokens.pageBg,
          body: BerandaTab(onGoToTab: onGoToTab ?? (_) {}),
        ),
      ),
    );

/// Seed Kas RT 05 (asOf 2026-10-15) + provider yang sudah dimuat.
Future<ZainNotoProvider> _seeded(WidgetTester tester) async {
  final db = await tester.runAsync(openTestDatabase);
  await tester.runAsync(
    () => ExampleSeed.seed(db!, asOf: DateTime(2026, 10, 15)),
  );
  // Jam disuntik: tes tidak bergantung pada bulan kalender saat dijalankan.
  final provider = ZainNotoProvider(
    repository: ZainNotoRepository(),
    now: () => DateTime(2026, 10, 21),
  );
  await tester.runAsync(provider.loadGroups);
  return provider;
}

Future<void> _pumpBeranda(
  WidgetTester tester,
  ZainNotoProvider provider, {
  ValueChanged<int>? onGoToTab,
}) async {
  await tester.pumpWidget(_app(provider, onGoToTab: onGoToTab));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

/// Nilai pada kotak berlabel [label]: kolom terdekat di atas teks label selalu
/// berisi [label, nilai], sehingga pemetaan yang tertukar tetap ketahuan.
String _under(Finder label, WidgetTester tester) {
  final column = find.ancestor(of: label, matching: find.byType(Column)).first;
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: column, matching: find.byType(Text)),
      )
      .map((w) => w.data ?? '')
      .toList();
  expect(texts, hasLength(2), reason: 'kolom berisi label + nilai: $texts');
  return texts.last;
}

/// Widget teks nilai pada kolom terdekat (untuk memeriksa warna token).
Text _underWidget(Finder label, WidgetTester tester) {
  final column = find.ancestor(of: label, matching: find.byType(Column)).first;
  return tester
      .widgetList<Text>(
        find.descendant(of: column, matching: find.byType(Text)),
      )
      .last;
}

/// Teks terakhir pada baris terdekat (pasangan label → nilai di baris yang sama).
String _beside(Finder label, WidgetTester tester) {
  final row = find.ancestor(of: label, matching: find.byType(Row)).first;
  final texts = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((w) => w.data ?? '')
      .toList();
  expect(texts, isNotEmpty, reason: 'baris label berisi teks');
  return texts.last;
}

List<String> _allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data)
    .whereType<String>()
    .toList();

bool _hasGradient(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .any((d) => d.decoration is LinearGradient);

/// Warna latar kotak ikon di dalam tile (Container dengan BoxDecoration).
bool _hasBoxColor(WidgetTester tester, Finder tile, Color color) => tester
    .widgetList<Container>(
      find.descendant(of: tile, matching: find.byType(Container)),
    )
    .any(
      (c) =>
          c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).color == color,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  testWidgets(
    'Beranda 390: header 172 + chip grup, NotchedCard 358×214 top 96, chip bulan, tanpa FAB/gradient',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);
      await _pumpBeranda(tester, provider);

      // Header varian home: tinggi 172, judul 24/600 headerFg.
      final header = find.byType(AppHeader);
      expect(header, findsOneWidget);
      expect(tester.getSize(header).height, 172);
      final title = tester.widget<Text>(find.text('ZainNoto'));
      expect(title.style!.fontSize, AppText.display);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.color, _tokens.headerFg);

      // Chip grup: tinggi 24, latar chip, titik persik 7, nama grup data.
      final chip = find.byKey(const ValueKey('zn-group-chip'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('Kas RT 05')),
        findsOneWidget,
      );
      expect(tester.getSize(chip).height, 24);
      expect(
        (tester.widget<Container>(chip).decoration! as BoxDecoration).color,
        _tokens.chip,
      );
      final dot = find.byKey(const ValueKey('zn-group-chip-dot'));
      expect(tester.getSize(dot), const Size(7, 7));
      expect(
        (tester.widget<Container>(dot).decoration! as BoxDecoration).color,
        _tokens.persik,
      );

      // Kartu saldo notch: 358×214, top 96, left 16, warna persik.
      final card = find.byType(NotchedCard);
      expect(card, findsOneWidget);
      expect(tester.getSize(card), const Size(358, 214));
      expect(tester.getTopLeft(card).dy, 96);
      expect(tester.getTopLeft(card).dx, 16);
      expect(tester.widget<NotchedCard>(card).color, _tokens.persik);

      // Chip bulan di dalam takik: kanan 10, atas 6, tinggi 32, latar chip.
      final monthChip = find.byKey(const ValueKey('zn-month-chip'));
      expect(monthChip, findsOneWidget);
      expect(tester.getSize(monthChip).height, 32);
      final cardTr = tester.getTopRight(card);
      expect(cardTr.dx - tester.getTopRight(monthChip).dx, 10);
      expect(tester.getTopLeft(monthChip).dy - tester.getTopLeft(card).dy, 6);
      expect(
        (tester.widget<Container>(monthChip).decoration! as BoxDecoration)
            .color,
        _tokens.chip,
      );
      expect(find.text('Okt 2026'), findsOneWidget, reason: 'chip bulan data');

      // Label kartu & mockup tanpa FAB dan tanpa gradient.
      expect(find.text('Saldo kas bersama'), findsOneWidget);
      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'ZN-Beranda tanpa FAB',
      );
      expect(_hasGradient(tester), isFalse, reason: 'tanpa gradient');
    },
  );

  testWidgets(
    'Beranda angka seed: saldo 1.425.000, masuk/keluar, iuran 275.000/400.000, tunggakan 175.000 terikat label',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);

      // Hitungan tangan seed Kas RT 05 (asOf 2026-10-15).
      expect(provider.summary!.balance, 1425000);
      expect(provider.summary!.overdueTotal, 175000);
      expect(provider.currentPeriod!.label, 'Oktober 2026');
      expect(provider.periodRows, hasLength(8));
      expect(
        provider.periodRows.fold<int>(0, (s, r) => s + r.paid),
        275000,
        reason: 'iuran terkumpul periode Oktober = 5x50.000 + cicil 25.000',
      );

      // Masuk/Keluar = kalender bulan berjalan (bukan akresi periode).
      // Seluruh pembayaran seed bertanggal 10 Okt 2026:
      //   masuk = 5x200.000 + 175.000 + 100.000 + 150.000 = 1.425.000
      //   keluar = 0 (seed tanpa transaksi keluar)
      expect(
        provider.incomeThisMonth,
        1425000,
        reason: 'incomeThisMonth: semua pembayaran bertanggal Oktober',
      );
      expect(
        provider.expenseThisMonth,
        0,
        reason: 'expenseThisMonth: tanpa transaksi keluar di Oktober',
      );

      await _pumpBeranda(tester, provider);

      // ── Kartu saldo: nilai terikat per label ──
      expect(
        _under(find.text('Saldo kas bersama'), tester),
        'Rp 1.425.000',
        reason: 'saldo kas = total pembayaran iuran seed',
      );
      expect(
        _under(find.text('Masuk bulan ini'), tester),
        'Rp 1.425.000',
        reason: 'masuk = kas masuk kalender Okt (menjelaskan saldo)',
      );
      expect(
        _under(find.text('Keluar bulan ini'), tester),
        'Rp 0',
        reason: 'seed tanpa pengeluaran',
      );
      expect(
        _underWidget(find.text('Masuk bulan ini'), tester).style!.color,
        _tokens.incomeOnPersik,
      );
      expect(
        _underWidget(find.text('Keluar bulan ini'), tester).style!.color,
        _tokens.expenseOnPersik,
      );
      expect(find.text('8 anggota aktif'), findsOneWidget);
      expect(find.text('Iuran Rp 50.000 / bulan'), findsOneWidget);

      // ── Kartu iuran periode berjalan ──
      expect(find.text('Iuran Oktober 2026'), findsOneWidget);
      expect(find.text('Jatuh tempo 10 Okt'), findsOneWidget);
      expect(
        _beside(find.text('5 lunas · 1 cicil · 2 telat'), tester),
        'Rp 275.000 / 400.000',
        reason: 'terkumpul / target periode',
      );
      final bar = find.byKey(const ValueKey('zn-iuran-bar'));
      expect(bar, findsOneWidget);
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(of: bar, matching: find.byType(FractionallySizedBox)),
      );
      // Persentase bar = hitung tangan dari data seed, bukan angka ketikan
      // mockup ZN-Beranda (mockup mengetik "68%"; data menang):
      //   terkumpul = 5 lunas x 50.000 + cicil Maya 25.000 = 275.000
      //   target    = 8 anggota x 50.000                    = 400.000
      //   rasio     = 275.000 / 400.000                     = 0,6875 = 68,75%
      expect(
        fill.widthFactor,
        closeTo(0.6875, 1e-9),
        reason: '275.000 / 400.000 = 68,75% (bukan 68% mockup)',
      );

      // ── Tunggakan: per anggota terikat label ──
      expect(_beside(find.text('Tunggakan'), tester), 'Rp 175.000');
      expect(
        _under(find.text('Dewi'), tester),
        '2 periode belum lunas',
        reason: 'Dewi telat Sep+Okt = 100.000',
      );
      expect(
        _under(find.text('Joko'), tester),
        '1 periode belum lunas',
        reason: 'Joko telat Okt = 50.000',
      );
      expect(
        _under(find.text('Maya').first, tester),
        'Cicil Rp 25.000 dari 50.000',
        reason: 'Maya cicil Okt = 25.000 dari 50.000',
      );
      final badges = {
        for (final b in tester.widgetList<StatusBadge>(
          find.byType(StatusBadge),
        ))
          b.label: b.kind,
      };
      expect(badges.length, 3);
      expect(badges['Rp 100.000'], StatusKind.telat);
      expect(badges['Rp 50.000'], StatusKind.telat);
      expect(badges['Rp 25.000'], StatusKind.cicil);
      expect(find.text('D'), findsOneWidget, reason: 'avatar huruf Dewi');
      expect(find.text('J'), findsOneWidget, reason: 'avatar huruf Joko');
      expect(find.text('M'), findsOneWidget, reason: 'avatar huruf Maya');
      // Urutan = total tunggakan tertinggi (Dewi, Joko, Maya). Nama yang sama
      // bisa muncul juga di kartu aktivitas, jadi pakai yang pertama (urutan
      // pohon: kartu tunggakan sebelum aktivitas) — sama seperti Maya.
      expect(
        tester.getTopLeft(find.text('Dewi').first).dy,
        lessThan(tester.getTopLeft(find.text('Joko').first).dy),
      );
      expect(
        tester.getTopLeft(find.text('Joko').first).dy,
        lessThan(tester.getTopLeft(find.text('Maya').first).dy),
      );

      // ── Angka beranda tetap kalender bulan berjalan walau periode lain dipilih ──
      final sep = provider.periods.firstWhere(
        (p) => p.label == 'September 2026',
      );
      await tester.runAsync(() => provider.selectPeriod(sep));
      await tester.pump();
      expect(
        _under(find.text('Masuk bulan ini'), tester),
        'Rp 1.425.000',
        reason:
            'masuk mengikuti kalender Oktober, bukan periode yang dipilih '
            '(periode Sep terkumpul 350.000)',
      );
      expect(
        find.text('Iuran Oktober 2026'),
        findsOneWidget,
        reason: 'kartu iuran tetap Oktober',
      );
      expect(find.text('5 lunas · 1 cicil · 2 telat'), findsOneWidget);

      // ── Aktivitas terbaru (butuh geser: di bawah lipatan) ──
      await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Aktivitas kas terbaru'), findsOneWidget);
      expect(find.text('Lihat semua'), findsOneWidget);
      expect(
        find.text('Iuran kas · 10 Oktober 2026'),
        findsNWidgets(5),
        reason: '5 transaksi iuran terbaru (take 5)',
      );
      expect(
        _beside(find.text('Lina'), tester),
        '+ Rp 200.000',
        reason: 'pembayaran Lina 4 periode = 200.000',
      );
      expect(
        find.text('- Rp '),
        findsNothing,
        reason: 'seed tanpa transaksi keluar',
      );
    },
  );

  testWidgets(
    'Masuk bulan ini: bayar tunggakan hari ini menambah masuk sebesar nominalnya',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);
      expect(
        provider.incomeThisMonth,
        1425000,
        reason: 'awal: seluruh pembayaran seed bertanggal 10 Okt',
      );

      // Dewi menunggak Sep + Okt (100.000). Bayar 50.000 hari ini (21 Okt)
      // melunasi tunggakan Sep secara FIFO, jadi periode Okt tidak berubah
      // tetapi kas masuk hari ini bertambah.
      final dewi = provider.members.firstWhere((m) => m.name == 'Dewi');
      final id = await tester.runAsync(
        () => provider.markPaid(
          memberId: dewi.id,
          amount: 50000,
          date: '2026-10-21',
        ),
      );
      expect(id, isNotNull);
      expect(
        provider.currentPeriodRows.fold<int>(0, (s, r) => s + r.paid),
        275000,
        reason: 'pembayaran 50.000 masuk ke tunggakan Sep (FIFO)',
      );
      expect(
        provider.summary!.balance,
        1475000,
        reason: 'saldo bertambah 50.000',
      );
      expect(
        provider.incomeThisMonth,
        1475000,
        reason: 'masuk kalender Okt bertambah 50.000: 1.425.000 + 50.000',
      );
      expect(provider.expenseThisMonth, 0);

      await _pumpBeranda(tester, provider);
      expect(
        _under(find.text('Masuk bulan ini'), tester),
        'Rp 1.475.000',
        reason: 'kartu menjelaskan saldo: kas masuk hari ini ikut terhitung',
      );
      expect(_under(find.text('Keluar bulan ini'), tester), 'Rp 0');
    },
  );

  testWidgets(
    'Masuk/Keluar bulan kalender: transaksi bulan lalu tidak terhitung',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);

      // Di luar bulan: pemasukan 75.000 + pengeluaran 20.000 pada 30 Sep.
      await tester.runAsync(
        () => provider.addTransaction(
          type: TxType.otherIncome,
          amount: 75000,
          date: '2026-09-30',
        ),
      );
      await tester.runAsync(
        () => provider.addTransaction(
          type: TxType.expense,
          amount: 20000,
          date: '2026-09-30',
        ),
      );
      // Di dalam bulan: pemasukan 25.000 pada 1 Okt, keluar 30.000 pada 31 Okt.
      await tester.runAsync(
        () => provider.addTransaction(
          type: TxType.otherIncome,
          amount: 25000,
          date: '2026-10-01',
        ),
      );
      await tester.runAsync(
        () => provider.addTransaction(
          type: TxType.expense,
          amount: 30000,
          date: '2026-10-31',
        ),
      );

      // Hitung tangan:
      //   masuk  = 1.425.000 (iuran 10 Okt) + 25.000 (1 Okt) = 1.450.000
      //   keluar = 30.000 (31 Okt); Sep tidak ikut
      expect(
        provider.incomeThisMonth,
        1450000,
        reason: 'masuk: 1.425.000 + 25.000, tanpa pemasukan 30 Sep',
      );
      expect(
        provider.expenseThisMonth,
        30000,
        reason: 'keluar: hanya 30.000 pada 31 Okt, bukan 20.000 pada 30 Sep',
      );

      await _pumpBeranda(tester, provider);
      expect(_under(find.text('Masuk bulan ini'), tester), 'Rp 1.450.000');
      expect(_under(find.text('Keluar bulan ini'), tester), 'Rp 30.000');
    },
  );

  test(
    'jam disuntik: 31 Okt menghitung, 1 Nov mengeluarkan transaksi Okt',
    () async {
      final db = await openTestDatabase();
      await ExampleSeed.seed(db, asOf: DateTime(2026, 10, 15));
      var now = DateTime(2026, 10, 31, 23, 59);
      final provider = ZainNotoProvider(
        repository: ZainNotoRepository(),
        now: () => now,
      );
      await provider.loadGroups();

      expect(provider.error, isNull);
      expect(provider.selectedGroup?.name, 'Kas RT 05');
      expect(provider.transactions, hasLength(8));
      expect(
        provider.incomeThisMonth,
        1425000,
        reason: 'akhir 31 Okt masih bulan kalender yang sama',
      );
      now = DateTime(2026, 11, 1);
      expect(
        provider.incomeThisMonth,
        0,
        reason: '1 Nov: pembayaran 10 Okt keluar dari bulan berjalan',
      );
      expect(provider.expenseThisMonth, 0);
      expect(
        provider.totalIncome,
        1425000,
        reason: 'total semua waktu tidak terpengaruh jam',
      );
    },
  );

  testWidgets('Bar iuran mingguan berlabel periode, bukan "bulan ini"', (
    tester,
  ) async {
    _viewport(tester);
    final ctx = await tester.runAsync(seedWeekly);
    await tester.runAsync(
      () => ctx!.repo.generatePeriods(
        groupId: ctx.groupId,
        upTo: DateTime(2026, 10, 21),
      ),
    );
    final provider = ZainNotoProvider(
      repository: ctx!.repo,
      now: () => DateTime(2026, 10, 21),
    );
    await tester.runAsync(provider.loadGroups);
    final label = provider.currentPeriod!.label;
    expect(label, startsWith('Minggu '), reason: 'periode mingguan');

    await _pumpBeranda(tester, provider);

    // Bar tetap per periode: 2 anggota x 20.000 = 40.000, belum ada bayar.
    expect(find.text('Rp 0 / 40.000'), findsOneWidget);
    final heading = tester.widget<Text>(find.text('Iuran $label'));
    expect(
      heading.data!.contains('bulan'),
      isFalse,
      reason: 'label bar memakai nama periode, bukan "bulan ini"',
    );
  });

  testWidgets(
    'Beranda 320dp textScale 1.3 (seed): tanpa overflow & tanpa ellipsis nominal',
    (tester) async {
      _viewport(tester, w: 320, h: 640, textScale: 1.3);
      final provider = await _seeded(tester);
      await _pumpBeranda(tester, provider);

      expect(find.text('Saldo kas bersama'), findsOneWidget);
      expect(
        find.text('Rp 1.425.000'),
        findsNWidgets(2),
        reason: 'nominal saldo + masuk bulan ini utuh',
      );
      expect(find.text('Rp 275.000 / 400.000'), findsOneWidget);
      expect(find.text('5 lunas · 1 cicil · 2 telat'), findsOneWidget);
      expect(find.text('Iuran Rp 50.000 / bulan'), findsOneWidget);
      expect(find.text('Rp 175.000'), findsOneWidget);

      final truncated = _allTexts(
        tester,
      ).where((s) => s.endsWith('…') || s.endsWith('...')).toList();
      expect(truncated, isEmpty, reason: 'teks terpotong: $truncated');

      // Geser sampai bawah: kartu aktivitas ikut terbangun tanpa overflow.
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Aktivitas kas terbaru'), findsOneWidget);
      expect(find.text('Iuran kas · 10 Oktober 2026'), findsNWidgets(5));
      final afterDrag = _allTexts(
        tester,
      ).where((s) => s.endsWith('…') || s.endsWith('...')).toList();
      expect(afterDrag, isEmpty, reason: 'teks terpotong: $afterDrag');
    },
  );

  testWidgets('Beranda tile: 4 tile label + warna token + Setor kas → tab 1', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _seeded(tester);
    int? tapped;
    await _pumpBeranda(tester, provider, onGoToTab: (i) => tapped = i);

    const tiles = <(String, Color, IconData, Color)>[
      (
        'zn-tile-anggota',
        Color(0xFFF4ECEF), // soft
        Icons.groups_rounded,
        Color(0xFF381932), // ac
      ),
      (
        'zn-tile-setor',
        Color(0xFFD5F1E4), // lunasBg
        Icons.north_rounded,
        Color(0xFF047857), // inc
      ),
      (
        'zn-tile-keluar',
        Color(0xFFFBDADF), // telatBg
        Icons.south_rounded,
        Color(0xFFBE123C), // exp
      ),
      (
        'zn-tile-pengaturan',
        Color(0xFFFBE8C4), // cicilBg
        Icons.tune_rounded,
        Color(0xFF7A4A05), // cicilFg
      ),
    ];
    final labels = ['Anggota', 'Setor kas', 'Pengeluaran', 'Pengaturan'];
    for (var i = 0; i < tiles.length; i++) {
      final (key, boxColor, icon, iconColor) = tiles[i];
      final tile = find.byKey(ValueKey(key));
      expect(tile, findsOneWidget, reason: labels[i]);
      expect(tester.getSize(tile).height, 92, reason: labels[i]);
      expect(
        _hasBoxColor(tester, tile, boxColor),
        isTrue,
        reason: '${labels[i]}: kotak ikon $boxColor',
      );
      final iconWidget = tester.widget<Icon>(
        find.descendant(of: tile, matching: find.byIcon(icon)),
      );
      expect(iconWidget.color, iconColor, reason: '${labels[i]}: ikon');
      expect(
        find.descendant(of: tile, matching: find.text(labels[i])),
        findsOneWidget,
      );
    }

    // Aksi: Setor kas membuka tab Iuran (checklist pembayaran).
    await tester.tap(find.byKey(const ValueKey('zn-tile-setor')));
    await tester.pump();
    expect(tapped, 1, reason: 'Setor kas → tab Iuran');
  });

  testWidgets('Beranda tile Pengaturan membuka GroupManagementSheet', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _seeded(tester);
    await _pumpBeranda(tester, provider);

    await tester.tap(find.byKey(const ValueKey('zn-tile-pengaturan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Pengaturan & Anggota'), findsOneWidget);
    expect(find.text('Kas RT 05'), findsWidgets);
  });

  testWidgets(
    'Beranda tile Anggota & Pengeluaran: menuju layar anggota & form kas keluar',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);
      await _pumpBeranda(tester, provider);

      // Anggota → GroupManagementSheet, section "Anggota (n)" di mana member
      // dikelola (layar penuh Anggota menyusul di Fase 3.6).
      await tester.tap(find.byKey(const ValueKey('zn-tile-anggota')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(GroupManagementSheet), findsOneWidget);
      final sheetList = find.descendant(
        of: find.byType(GroupManagementSheet),
        matching: find.byType(ListView),
      );
      await tester.drag(sheetList.first, const Offset(0, -500));
      await tester.pump();
      expect(
        find.text('Anggota (8)'),
        findsOneWidget,
        reason: 'section member (8 anggota seed) terjangkau dari tile',
      );

      // Tutup sheet sebelum tap tile berikutnya (jalur Navigator, karena
      // tap barrier tidak menutup DraggableScrollableSheet di tes ini).
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GroupManagementSheet), findsNothing);

      // Pengeluaran → form kas keluar (TransactionFormSheet), tipe default
      // "Keluar" — alur lama "catat kas keluar" tetap terjangkau.
      await tester.tap(find.byKey(const ValueKey('zn-tile-keluar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionFormSheet), findsOneWidget);
      expect(
        find.text('Keluar'),
        findsOneWidget,
        reason: 'tipe default form = kas keluar',
      );
      expect(find.text('Simpan'), findsOneWidget);
    },
  );

  testWidgets(
    'Pilih grup (ZN-Grup): chip buka layar, kartu terpilih, subtitle data & aksi bawah',
    (tester) async {
      _viewport(tester);
      final provider = await _seeded(tester);

      // Grup kedua tanpa data (repo langsung, supaya grup terpilih tidak
      // ikut pindah) → subtitle '0 anggota · Rp 0'.
      final repo = ZainNotoRepository();
      await tester.runAsync(() => repo.createGroup(name: 'Arisan RT 05'));
      await tester.runAsync(provider.loadGroups);
      await tester.runAsync(provider.loadPickerInfo);

      await _pumpBeranda(tester, provider);

      // Chip grup → layar pilih grup (route penuh sesuai mockup ZN-Grup).
      await tester.tap(find.byKey(const ValueKey('zn-group-chip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(GroupPickerScreen), findsOneWidget);
      expect(find.text('Pilih grup kas'), findsOneWidget);

      // Header varian ZN-Grup: bottomPadding 26 + baris kecil 'Mode kelompok'
      // di atas judul (diketemukan hanya di dalam picker).
      final pickerHeader = find.descendant(
        of: find.byType(GroupPickerScreen),
        matching: find.byType(AppHeader),
      );
      expect(tester.widget<AppHeader>(pickerHeader).bottomPadding, 26);
      expect(find.text('Mode kelompok'), findsOneWidget);

      Finder card(String name) => find
          .ancestor(
            of: find.descendant(
              of: find.byType(GroupPickerScreen),
              matching: find.text(name),
            ),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).borderRadius ==
                      BorderRadius.circular(24),
            ),
          )
          .first;

      // Kartu terpilih: border 2 accent + ikon 48 persik + check 'Dipilih'.
      final selectedBorder =
          (tester.widget<Container>(card('Kas RT 05')).decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      expect(selectedBorder.top.width, 2, reason: 'kartu on: border 2');
      expect(selectedBorder.top.color, _tokens.accent);
      expect(
        find.descendant(
          of: card('Kas RT 05'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Dipilih',
          ),
        ),
        findsOneWidget,
        reason: 'check dalam Semantics(label: Dipilih) hanya di kartu terpilih',
      );
      final iconBox = find
          .descendant(
            of: card('Kas RT 05'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.constraints?.maxWidth == 48 &&
                  w.constraints?.maxHeight == 48,
            ),
          )
          .first;
      expect(tester.getSize(iconBox), const Size(48, 48));
      expect(
        (tester.widget<Container>(iconBox).decoration! as BoxDecoration).color,
        _tokens.persik,
        reason: 'ikon kartu terpilih: latar persik',
      );
      expect(
        find.descendant(
          of: card('Kas RT 05'),
          matching: find.byIcon(Icons.work_rounded),
        ),
        findsOneWidget,
        reason: 'briefcase (bukan GroupAvatar)',
      );

      // Kartu non-terpilih: border 1 border-token, tanpa check.
      final unselectedBorder =
          (tester.widget<Container>(card('Arisan RT 05')).decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      expect(unselectedBorder.top.width, 1);
      expect(unselectedBorder.top.color, _tokens.border);
      expect(
        find.descendant(
          of: card('Arisan RT 05'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Dipilih',
          ),
        ),
        findsNothing,
      );

      // Subtitle terikat data per kartu (anggota · saldo).
      expect(
        _under(
          find.descendant(
            of: find.byType(GroupPickerScreen),
            matching: find.text('Kas RT 05'),
          ),
          tester,
        ),
        '8 anggota · Rp 1.425.000',
        reason: '8 anggota seed, saldo = balance summary',
      );
      expect(
        _under(
          find.descendant(
            of: find.byType(GroupPickerScreen),
            matching: find.text('Arisan RT 05'),
          ),
          tester,
        ),
        '0 anggota · Rp 0',
        reason: 'grup baru tanpa anggota/transaksi',
      );

      // Aksi bawah: Gabung dengan kode → snackbar jelas "segera hadir".
      expect(find.text('Buat grup baru'), findsOneWidget);
      expect(find.text('Gabung dengan kode'), findsOneWidget);
      await tester.tap(find.text('Gabung dengan kode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Fitur gabung kode belum tersedia'), findsOneWidget);

      // Buat grup baru → dialog pembuatan lama tetap terjangkau (di atas picker).
      await tester.tap(find.text('Buat grup baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buat Grup Baru'), findsOneWidget);
      expect(
        find.byType(GroupPickerScreen),
        findsOneWidget,
        reason: 'picker tetap terbuka di bawah dialog',
      );
      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buat Grup Baru'), findsNothing);
      expect(find.byType(GroupPickerScreen), findsOneWidget);

      // Pilih grup kedua → picker pop, chip beranda menampilkan grup baru.
      await tester.tap(card('Arisan RT 05'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GroupPickerScreen), findsNothing);
      expect(provider.selectedGroup!.name, 'Arisan RT 05');
      expect(
        find.text('Arisan RT 05'),
        findsOneWidget,
        reason: 'chip beranda kini grup terpilih',
      );
      // selectGroup memicu refresh data grup; drain bergantian runAsync+pump
      // supaya kelanjutan future DB (zona fake) ikut maju dan tidak ada
      // query yang tersisa saat database ditutup di teardown.
      for (var i = 0; i < 100 && provider.isRefreshing; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(
        provider.isRefreshing,
        isFalse,
        reason: 'refresh grup selesai sebelum test berakhir',
      );
      await tester.pump();
      // Habiskan timer SnackBar (4 detik) agar tidak tertinggal di teardown.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}
