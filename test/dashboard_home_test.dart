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
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _monthChipLabel(String monthYear) {
  final p = monthYear.split('-');
  return '${_shortMonths[int.parse(p[1]) - 1]} ${p[0]}';
}

class _TxSpec {
  const _TxSpec(this.amount, this.type, this.day, this.note);
  final double amount;
  final String type;
  final int day;
  final String note;
}

void _viewport(WidgetTester tester, {double w = 390, double h = 844}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        darkTheme:
            AppTheme.getTheme(_seed, _bg, dark: true, palette: ThemePalette.plum),
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
    final catId = cats!
        .firstWhere((c) => c.type == spec.type)
        .id;
    await tester.runAsync(
      () => dbh.addTransaction(
        FinanceTransaction(
          categoryId: catId!,
          amount: spec.amount,
          type: spec.type,
          date: '${now.year}-$month-${spec.day.toString().padLeft(2, '0')}',
          note: spec.note,
        ),
      ),
    );
  }
  final provider = FinanceProvider();
  await tester.runAsync(provider.refreshAll);
  return provider;
}

bool _hasGradient(WidgetTester tester) =>
    tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any(
          (d) => d.decoration is LinearGradient,
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Home terang: header 172, kartu notch 358×214 di top 96, 3 tile, FAB 52',
      (tester) async {
    _viewport(tester);
    final provider = await _providerWith(tester, txs: [
      const _TxSpec(364000, 'income', 13, 'uang jajan'),
      const _TxSpec(19000, 'expense', 9, 'Makanan & Minuman'),
    ]);

    await tester.pumpWidget(_app(provider));
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

    expect(find.byType(DonutChart), findsNothing, reason: 'Home tanpa statistik');
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
  });

  testWidgets('Home kosong: empty state, tanpa FAB, saldo Rp 0', (tester) async {
    _viewport(tester);
    final provider = await _providerWith(tester);

    await tester.pumpWidget(_app(provider));
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
    expect(find.widgetWithText(ElevatedButton, 'Tambah transaksi pertama'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-fab')), findsNothing,
        reason: 'FAB disembunyikan saat kosong');
    expect(find.text('Rp 0'), findsWidgets);
    expect(find.byType(ListRow), findsNothing);
  });

  testWidgets('Home gelap: warna token gelap dipakai, tanpa overflow', (tester) async {
    _viewport(tester);
    final provider = await _providerWith(tester, txs: [
      const _TxSpec(50000, 'income', 13, 'uang jajan'),
    ]);

    await tester.pumpWidget(_app(provider, dark: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final tokens = AppTokens.plum(Brightness.dark);
    final scaffoldBg =
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
    expect(scaffoldBg, tokens.pageBg);
    expect(find.text('Saldo keuangan'), findsOneWidget);
    expect(find.text('uang jajan'), findsOneWidget);
    expect(_hasGradient(tester), isFalse);
  });

  testWidgets('Home: judul & greeting memakai token header', (tester) async {
    _viewport(tester);
    final provider = await _providerWith(tester);

    await tester.pumpWidget(_app(provider));
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
