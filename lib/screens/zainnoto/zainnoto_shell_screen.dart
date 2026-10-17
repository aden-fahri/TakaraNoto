import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../widgets/pill_nav_bar.dart';
import '../../zainnoto/providers/zainnoto_provider.dart';
import 'tabs/beranda_tab.dart';
import 'tabs/iuran_tab.dart';
import 'tabs/statistik_tab.dart';
import 'tabs/transaksi_tab.dart';

/// Shell for ZainNoto (Kelompok) mode with 4 intuitive tabs.
/// Tab "Lainnya" telah dihapus dan fitur pengaturannya dapat diakses
/// langsung dari tombol pengaturan di Beranda.
class ZainNotoShellScreen extends StatefulWidget {
  const ZainNotoShellScreen({super.key});

  @override
  State<ZainNotoShellScreen> createState() => _ZainNotoShellScreenState();
}

class _ZainNotoShellScreenState extends State<ZainNotoShellScreen> {
  int _currentIndex = 0;

  static const List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Beranda'),
    NavItem(icon: Icons.checklist_rounded, label: 'Iuran'),
    NavItem(icon: Icons.receipt_long_rounded, label: 'Transaksi'),
    NavItem(icon: Icons.analytics_rounded, label: 'Statistik'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ZainNotoProvider>().loadGroups();
      }
    });
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BerandaTab(onGoToTab: _goToTab),
          const IuranTab(),
          const TransaksiTab(),
          const StatistikTab(),
        ],
      ),
      bottomNavigationBar: PillNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onTabTapped,
      ),
    );
  }
}
