import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/finance_provider.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  // Force light status bar over plum banner
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(),
      child: MaterialApp(
        title: 'TakaraNoto',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(false),
        darkTheme: AppTheme.getTheme(true),
        themeMode: ThemeMode.light, // ← Force light mode
        home: const SplashScreen(nextScreen: MainNavigationScreen()),
      ),
    );
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    BudgetScreen(),
    SavingsScreen(),
    StatsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Riwayat'),
    _NavItem(icon: Icons.pie_chart_rounded, label: 'Anggaran'),
    _NavItem(icon: Icons.savings_rounded, label: 'Tabungan'),
    _NavItem(icon: Icons.analytics_rounded, label: 'Laporan'),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<FinanceProvider>(
        builder: (context, provider, _) => _PillNavBar(
          currentIndex: _currentIndex,
          items: _navItems,
          hasBudgetAlert: provider.hasBudgetAlert,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}

// ─── Nav Item data class ─────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Custom Pill Navigation Bar ───────────────────────────────────────────────
class _PillNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final bool hasBudgetAlert;
  final ValueChanged<int> onTap;

  const _PillNavBar({
    required this.currentIndex,
    required this.items,
    required this.hasBudgetAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Always light mode styling
    const bgColor = Colors.white;
    const activeColor = AppTheme.darkPlum;
    const inactiveColor = AppTheme.mutedLightPlum;
    const pillColor = AppTheme.surfaceHeroLight;

    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 0.5,
            color: AppTheme.borderLight,
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: List.generate(items.length, (i) {
                    final isActive = i == currentIndex;
                    final isBudgetTab = i == 2;
                    final showBadge = isBudgetTab && hasBudgetAlert;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isActive ? pillColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      items[i].icon,
                                      key: ValueKey(isActive),
                                      size: isActive ? 26 : 24,
                                      color: isActive ? activeColor : inactiveColor,
                                    ),
                                  ),
                                  // Budget alert badge
                                  if (showBadge)
                                    Positioned(
                                      right: -4,
                                      top: -3,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.roseRed,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: activeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
