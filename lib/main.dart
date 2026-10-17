import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'providers/app_mode_controller.dart';
import 'providers/finance_provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/zainnoto/zainnoto_shell_screen.dart';
import 'widgets/pill_nav_bar.dart';
import 'zainnoto/providers/zainnoto_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ganti layar putih polos saat widget gagal di-build dengan kartu error
  // yang terlihat, supaya kegagalan tidak lagi menyamar menjadi blank screen.
  ErrorWidget.builder = (details) => _BuildErrorView(details: details);
  if (kIsWeb) {
    // Browsers have no native sqflite: use the sqlite3 wasm + IndexedDB
    // factory so both databases work and persist in web builds too.
    databaseFactory = databaseFactoryFfiWeb;
  }
  await initializeDateFormatting('id', null);
  // Force light status bar over the accent banner
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController()..load(),
        ),
        ChangeNotifierProvider<AppModeController>(
          create: (_) => AppModeController(),
        ),
        ChangeNotifierProvider<ZainNotoProvider>(
          create: (_) => ZainNotoProvider(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'TakaraNoto',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(
            themeController.seed,
            themeController.background,
          ),
          themeMode: ThemeMode.light, // ← Force light mode
          home: const SplashScreen(nextScreen: AppModeGate()),
        ),
      ),
    );
  }
}

// ─── Visible build error card ─────────────────────────────────────────────────
/// Ditampilkan menggantikan widget yang gagal di-build, di debug maupun
/// release, agar kegagalan selalu terlihat alih-alih menjadi blank screen.
class _BuildErrorView extends StatelessWidget {
  const _BuildErrorView({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF1F2),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Color(0xFFF43F5E),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Terjadi kesalahan pada bagian ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${details.exception}',
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mode gate ────────────────────────────────────────────────────────────────
/// Chooses the shell based on the current [AppMode]: the app starts in
/// Pribadi (TakaraNoto) and switches to ZainNoto via the dashboard toggle.
class AppModeGate extends StatelessWidget {
  const AppModeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeController>().mode;
    return mode == AppMode.group
        ? const ZainNotoShellScreen()
        : const MainNavigationScreen();
  }
}
// ─── Main Navigation Shell ────────────────────────────────────────────────────
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.list_alt_rounded, label: 'Riwayat'),
    NavItem(icon: Icons.pie_chart_rounded, label: 'Anggaran'),
    NavItem(icon: Icons.savings_rounded, label: 'Tabungan'),
    NavItem(icon: Icons.analytics_rounded, label: 'Laporan'),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  List<Widget> _buildScreens() => [
    DashboardScreen(
      onSeeAll: () => _goToTab(1),
    ),
    const HistoryScreen(),
    const BudgetScreen(),
    const SavingsScreen(),
    StatsScreen(onGoToBudget: () => _goToTab(2)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: Consumer<FinanceProvider>(
        builder: (context, provider, _) => PillNavBar(
          currentIndex: _currentIndex,
          items: _navItems,
          showBadge: provider.hasBudgetAlert,
          badgeIndex: 2,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
