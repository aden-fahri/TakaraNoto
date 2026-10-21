import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/screens/zainnoto/tabs/beranda_tab.dart';
import 'package:finflow_flutter/screens/zainnoto/widgets/group_management_sheet.dart';
import 'package:finflow_flutter/screens/zainnoto/widgets/transaction_form_sheet.dart';
import 'package:finflow_flutter/services/example_seed.dart';
import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/widgets/app_header.dart';
import 'package:finflow_flutter/widgets/notched_card.dart';
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
  final provider = ZainNotoProvider(repository: ZainNotoRepository());
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

      // Rumus angka beranda (definisi masuk/keluar = akresi periode berjalan,
      // bukan total seluruh waktu): masuk = iuran terkumpul Oktober,
      // keluar = pengeluaran dalam rentang tanggal Oktober (seed: nol).
      expect(
        provider.incomeThisPeriod,
        275000,
        reason: 'incomeThisPeriod: akresi periode berjalan',
      );
      expect(
        provider.expenseThisPeriod,
        0,
        reason: 'expenseThisPeriod: tanpa transaksi keluar di Oktober',
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
        'Rp 275.000',
        reason: 'masuk = iuran terkumpul periode berjalan',
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

      // ── Angka beranda tetap periode berjalan walau periode lain dipilih ──
      final sep = provider.periods.firstWhere(
        (p) => p.label == 'September 2026',
      );
      await tester.runAsync(() => provider.selectPeriod(sep));
      await tester.pump();
      expect(
        _under(find.text('Masuk bulan ini'), tester),
        'Rp 275.000',
        reason:
            'beranda mengikuti periode berjalan, bukan yang dipilih '
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
    'Beranda 320dp textScale 1.3 (seed): tanpa overflow & tanpa ellipsis nominal',
    (tester) async {
      _viewport(tester, w: 320, h: 640, textScale: 1.3);
      final provider = await _seeded(tester);
      await _pumpBeranda(tester, provider);

      expect(find.text('Saldo kas bersama'), findsOneWidget);
      expect(
        find.text('Rp 1.425.000'),
        findsOneWidget,
        reason: 'nominal saldo utuh',
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
}
