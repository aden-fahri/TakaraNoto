import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:finflow_flutter/models/transaction.dart';
import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/providers/finance_provider.dart';
import 'package:finflow_flutter/screens/dashboard_screen.dart';
import 'package:finflow_flutter/services/database_helper.dart';
import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/app_tokens.dart';
import 'package:finflow_flutter/widgets/app_header.dart';
import 'package:finflow_flutter/widgets/donut_chart.dart';
import 'package:finflow_flutter/widgets/list_row.dart';
import 'package:finflow_flutter/widgets/notched_card.dart';

import 'zainnoto/helpers.dart';

const _seed = Color(0xFF381932);
const _bg = Color(0xFFFFF3E6);

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _monthChipLabel(String monthYear) {
  final p = monthYear.split('-');
  return '${_shortMonths[int.parse(p[1]) - 1]} ${p[0]}';
}

class _TxSpec {
  const _TxSpec(this.amount, this.type, this.day, this.note, {this.date});
  final double amount;
  final String type;
  final int day;
  final String note;
  final String? date;
}

/// Provider yang selalu memberi tahu UI bahwa data belum dimuat.
class _UnloadedFinanceProvider extends FinanceProvider {
  @override
  bool get isLoading => true;
}

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

Widget _app(FinanceProvider provider, {bool dark = false}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<FinanceProvider>.value(value: provider),
    ChangeNotifierProvider<AppModeController>(
      create: (_) => AppModeController(initial: AppMode.personal),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.getTheme(_seed, _bg, palette: ThemePalette.plum),
    darkTheme: AppTheme.getTheme(
      _seed,
      _bg,
      dark: true,
      palette: ThemePalette.plum,
    ),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: const DashboardScreen(),
  ),
);

Future<FinanceProvider> _providerWith(
  WidgetTester tester, {
  List<_TxSpec> txs = const [],
}) async {
  await tester.runAsync(openTestDatabase);
  final dbh = DatabaseHelper.instance;
  final cats = await tester.runAsync(dbh.getCategories);
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  for (final spec in txs) {
    final catId = cats!.firstWhere((c) => c.type == spec.type).id;
    await tester.runAsync(
      () => dbh.addTransaction(
        FinanceTransaction(
          categoryId: catId!,
          amount: spec.amount,
          type: spec.type,
          date:
              spec.date ??
              '${now.year}-$month-${spec.day.toString().padLeft(2, '0')}',
          note: spec.note,
        ),
      ),
    );
  }
  final provider = FinanceProvider();
  await tester.runAsync(provider.refreshAll);
  return provider;
}

/// Tunggu `_init()` provider selesai (spinner hilang sebelum asersi konten).
Future<void> _waitLoaded(WidgetTester tester, FinanceProvider p) async {
  for (var i = 0; i < 100 && p.isLoading; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(p.isLoading, isFalse, reason: 'provider belum selesai dimuat');
}

bool _hasGradient(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .any((d) => d.decoration is LinearGradient);

List<String> _allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data)
    .whereType<String>()
    .toList();

/// Nilai pada kotak berlabel [label] (kotak statistik kartu saldo / tile
/// dompet): kolom terdekat di atas teks label selalu berisi [label, nilai],
/// sehingga pemetaan pemasukan/pengeluaran yang tertukar tetap ketahuan.
String _valueUnder(String label, WidgetTester tester) {
  final column = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: column, matching: find.byType(Text)),
      )
      .map((w) => w.data ?? '')
      .toList();
  expect(texts, hasLength(2), reason: 'kotak "$label" berisi label + nilai');
  return texts.last;
}

List<_TxSpec> _twoTxs() => [
  const _TxSpec(364000, 'income', 13, 'uang jajan'),
  const _TxSpec(19000, 'expense', 9, 'Makanan & Minuman'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'Home terang: header 172, kartu notch 358×214 di top 96, 3 tile, FAB 52',
    (tester) async {
      _viewport(tester);
      final provider = await _providerWith(tester, txs: _twoTxs());

      await tester.pumpWidget(_app(provider));
      await _waitLoaded(tester, provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final tokens = AppTokens.plum(Brightness.light);

      // Header: tinggi 172
      expect(find.byType(AppHeader), findsOneWidget);
      expect(tester.getSize(find.byType(AppHeader)).height, 172);

      // Kartu saldo notch: 358×214, top 96, left 16
      final card = find.byType(NotchedCard);
      expect(card, findsOneWidget);
      expect(tester.getSize(card), const Size(358, 214));
      expect(tester.getTopLeft(card).dy, 96);
      expect(tester.getTopLeft(card).dx, 16);

      // Chip bulan di dalam takik: kanan 10, atas 6, tinggi 32, latar chip
      final chip = find.byKey(const ValueKey('home-month-chip'));
      expect(chip, findsOneWidget);
      expect(tester.getSize(chip).height, 32);
      final cardTr = tester.getTopRight(card);
      expect(cardTr.dx - tester.getTopRight(chip).dx, 10);
      expect(tester.getTopLeft(chip).dy - tester.getTopLeft(card).dy, 6);
      expect(
        (tester.widget<Container>(chip).decoration! as BoxDecoration).color,
        tokens.chip,
      );
      expect(find.text(_monthChipLabel(provider.currentMonth)), findsOneWidget);

      expect(find.text('Saldo keuangan'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Arus kas bulan ini'), findsOneWidget);

      expect(find.text('Dompet utama'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);
      expect(find.text('Tabungan'), findsOneWidget);

      expect(find.text('Transaksi terbaru'), findsOneWidget);
      expect(find.text('Lihat semua'), findsOneWidget);
      expect(find.byType(ListRow), findsNWidgets(2));

      expect(
        find.byType(DonutChart),
        findsNothing,
        reason: 'Home tanpa statistik',
      );
      expect(_hasGradient(tester), isFalse, reason: 'Home tanpa gradient');

      // FAB: tinggi 52, kanan 16, atas 92 dari bawah kerangka (76 nav + 16)
      final fab = find.byKey(const ValueKey('home-fab'));
      expect(fab, findsOneWidget);
      expect(tester.getSize(fab).height, 52);
      expect(tester.getTopRight(fab).dx, 374);
      expect(
        844 - (tester.getTopLeft(fab).dy + tester.getSize(fab).height),
        16,
      );
      expect(find.text('Tambah Transaksi'), findsOneWidget);
    },
  );

  testWidgets('Home angka rupiah sesuai hitungan tangan (364.000 - 19.000)', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _providerWith(tester, txs: _twoTxs());

    await tester.pumpWidget(_app(provider));
    await _waitLoaded(tester, provider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Hitungan tangan: pemasukan 364.000, pengeluaran 19.000.
    // Saldo kumulatif = 364.000 - 19.000 = 345.000 (tanpa tabungan/transfer).
    expect(provider.cumulativeBalance, 345000.0);
    expect(provider.monthlyTotals['income'], 364000.0);
    expect(provider.monthlyTotals['expense'], 19000.0);

    // Kartu saldo + ringkasan arus kas — nilai terikat ke labelnya lewat
    // _valueUnder, jadi pemasukan/pengeluaran yang tertukar tetap ketahuan.
    expect(find.text('Rp 345.000'), findsOneWidget, reason: 'saldo kumulatif');
    expect(
      _valueUnder('Pemasukan', tester),
      'Rp 364rb',
      reason: 'kotak pemasukan bulan ini',
    );
    expect(
      _valueUnder('Pengeluaran', tester),
      'Rp 19rb',
      reason: 'kotak pengeluaran bulan ini',
    );
    expect(find.text('+ Rp 345.000'), findsOneWidget, reason: 'arus kas');

    // Tile dompet: Dompet utama = saldo kumulatif, E-Wallet = topup,
    // Tabungan = tabungan (keduanya 0 pada data ini) — kolom gerbang1.md.
    expect(
      _valueUnder('Dompet utama', tester),
      'Rp 345 rb',
      reason: 'Dompet utama',
    );
    expect(_valueUnder('E-Wallet', tester), 'Rp 0', reason: 'E-Wallet kosong');
    expect(_valueUnder('Tabungan', tester), 'Rp 0', reason: 'Tabungan kosong');

    // Baris transaksi memakai format penuh.
    expect(find.text('+ Rp 364.000'), findsOneWidget);
    expect(find.text('- Rp 19.000'), findsOneWidget);
  });

  testWidgets(
    'Sheet pilih bulan: tahun dibangun dari data, tahun now-3 bisa dipilih',
    (tester) async {
      _viewport(tester);
      final now = DateTime.now();
      final oldYear = now.year - 3;
      final provider = await _providerWith(
        tester,
        txs: [
          ..._twoTxs(),
          _TxSpec(123456, 'income', 15, 'gaji lama', date: '$oldYear-07-15'),
        ],
      );

      await tester.pumpWidget(_app(provider));
      await _waitLoaded(tester, provider);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('home-month-chip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pilih bulan'), findsOneWidget);
      expect(
        find.text('$oldYear'),
        findsOneWidget,
        reason: 'tahun terlama transaksi ikut tampil',
      );
      expect(find.text('${now.year}'), findsOneWidget);
      expect(find.text('${now.year + 1}'), findsOneWidget);

      await tester.tap(find.text('Jul $oldYear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (
        var i = 0;
        i < 100 && provider.monthlyTotals['income'] != 123456.0;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(provider.currentMonth, '$oldYear-07');
      expect(provider.monthlyTotals['income'], 123456.0);
      expect(provider.cumulativeBalance, 123456.0);

      // Ringkasan & chip menunjukkan bulan yang dipilih, bukan bulan berjalan.
      expect(find.text('Jul $oldYear'), findsOneWidget, reason: 'chip bulan');
      expect(
        find.text('Rp 123rb'),
        findsOneWidget,
        reason: 'pemasukan bulan lama',
      );
      expect(
        find.text('Rp 123.456'),
        findsOneWidget,
        reason: 'saldo kumulatif',
      );
      expect(find.text('Rp 364rb'), findsNothing);
      expect(
        find.text('gaji lama'),
        findsOneWidget,
        reason: 'list transaksi bulan lama',
      );
      expect(
        find.text('+ Rp 123.456'),
        findsNWidgets(2),
        reason:
            'arus kas lama di baris "Arus kas bulan ini" + baris list transaksi (keduanya + Rp 123.456)',
      );
    },
  );

  testWidgets('320dp textScale 1.3: tidak ada teks yang terpotong tanda …', (
    tester,
  ) async {
    _viewport(tester, w: 320, h: 640, textScale: 1.3);
    final provider = await _providerWith(tester, txs: _twoTxs());

    await tester.pumpWidget(_app(provider));
    await _waitLoaded(tester, provider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final texts = _allTexts(tester);
    final truncated = texts
        .where((s) => s.endsWith('…') || s.endsWith('...'))
        .toList();
    expect(truncated, isEmpty, reason: 'teks terpotong: $truncated');
    expect(find.text('Saldo keuangan'), findsOneWidget);
    expect(find.text('+ Rp 345.000'), findsOneWidget, reason: 'arus kas utuh');
    expect(find.text('Rp 364rb'), findsOneWidget, reason: 'pemasukan utuh');
  });

  testWidgets('provider belum dimuat: spinner, bukan saldo 0 palsu', (
    tester,
  ) async {
    _viewport(tester);
    await tester.runAsync(openTestDatabase);
    final provider = _UnloadedFinanceProvider();

    await tester.pumpWidget(_app(provider));
    await tester.pump();

    expect(provider.isLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NotchedCard), findsNothing);
    expect(find.text('Saldo keuangan'), findsNothing);
    expect(
      find.text('Rp 0'),
      findsNothing,
      reason: 'saldo 0 tidak boleh tampil sebelum data dimuat',
    );
  });

  testWidgets('Home kosong: empty state, tanpa FAB, saldo Rp 0', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _providerWith(tester);

    await tester.pumpWidget(_app(provider));
    await _waitLoaded(tester, provider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    expect(find.text('Belum ada transaksi bulan ini'), findsOneWidget);
    expect(
      find.text(
        'Catat pemasukan atau pengeluaran pertama Anda. Saldo dan dompet akan terisi otomatis.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ElevatedButton, 'Tambah transaksi pertama'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-fab')),
      findsNothing,
      reason: 'FAB disembunyikan saat kosong',
    );
    expect(find.text('Rp 0'), findsWidgets);
    // Bulan tanpa data: saldo (32px) tetap menampilkan Rp 0 yang benar.
    expect(
      tester
          .widgetList<Text>(find.text('Rp 0'))
          .any((t) => t.style?.fontSize == AppText.stat),
      isTrue,
      reason: 'saldo bulan kosong = Rp 0',
    );
    expect(find.byType(ListRow), findsNothing);
  });

  testWidgets('Home gelap: warna token gelap dipakai, tanpa overflow', (
    tester,
  ) async {
    _viewport(tester);
    final provider = await _providerWith(
      tester,
      txs: [const _TxSpec(50000, 'income', 13, 'uang jajan')],
    );

    await tester.pumpWidget(_app(provider, dark: true));
    await _waitLoaded(tester, provider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final tokens = AppTokens.plum(Brightness.dark);
    final scaffoldBg = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(scaffoldBg, tokens.pageBg);
    expect(find.text('Saldo keuangan'), findsOneWidget);
    expect(find.text('uang jajan'), findsOneWidget);
    expect(_hasGradient(tester), isFalse);
  });

  testWidgets('Home: judul & greeting memakai token header', (tester) async {
    _viewport(tester);
    final provider = await _providerWith(tester);

    await tester.pumpWidget(_app(provider));
    await _waitLoaded(tester, provider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final tokens = AppTokens.plum(Brightness.light);
    final title = tester.widget<Text>(find.text('TakaraNoto'));
    expect(title.style!.fontSize, AppText.display);
    expect(title.style!.fontWeight, FontWeight.w600);
    expect(title.style!.color, tokens.headerFg);

    final greeting = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => t.data != null && t.data!.startsWith('Selamat '));
    expect(greeting.style!.color, tokens.headerMuted);
    expect(greeting.style!.fontSize, AppText.body);
  });
}
