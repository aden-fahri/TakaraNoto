import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finflow_flutter/providers/app_mode_controller.dart';
import 'package:finflow_flutter/screens/theme_settings_screen.dart';
import 'package:finflow_flutter/theme/app_theme.dart';
import 'package:finflow_flutter/theme/theme_controller.dart';
import 'package:finflow_flutter/widgets/app_header.dart';
import 'package:finflow_flutter/widgets/palette_sheet.dart';

Widget _app(ThemeController c) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: c),
        ChangeNotifierProvider<AppModeController>(
          create: (_) => AppModeController(initial: AppMode.personal),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.getTheme(c.seed, c.background, palette: c.palette),
        home: Builder(
          builder: (context) => Scaffold(
            body: AppHeader(
              title: 'TakaraNoto',
              onPaletteTap: () => showPaletteSheet(context),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tombol palet membuka bottom sheet, bukan ThemeSettingsScreen', (tester) async {
    final c = ThemeController();
    await c.load();
    await tester.pumpWidget(_app(c));
    await tester.pump(const Duration(milliseconds: 300));

    // ketuk ikon palet
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    // bottom sheet muncul (ListTile "Plum Klasik") dan ThemeSettingsScreen TIDAK ada
    expect(find.text('Plum Klasik'), findsOneWidget);
    expect(find.byType(ThemeSettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kustom membuka ThemeSettingsScreen', (tester) async {
    final c = ThemeController();
    await c.load();
    await tester.pumpWidget(_app(c));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Kustom'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kustom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull, reason: 'exception saat tap Kustom');
    expect(find.byType(ThemeSettingsScreen), findsOneWidget);
    expect(find.text('Pilih tema'), findsNothing, reason: 'sheet harus tertutup');
    expect(tester.takeException(), isNull);
  });
}
