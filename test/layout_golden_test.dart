import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dashia/core/theme/app_theme.dart';
import 'package:dashia/core/theme/dashia_colors.dart';
import 'package:dashia/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:dashia/features/settings/settings_service.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _pumpDashboard(WidgetTester tester, SettingsService s) async {
  tester.view.physicalSize = const Size(1024, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final colors = DashiaColors.from(s);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(colors, fontKey: s.fontFamily).copyWith(extensions: [colors]),
    home: DashboardScreen(settings: s),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFont('Poppins', ['Poppins-Regular.ttf', 'Poppins-SemiBold.ttf', 'Poppins-Bold.ttf', 'Poppins-ExtraBold.ttf']);
    const ch = MethodChannel('com.dashia.launcher/apps');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async => null);
  });

  for (final style in ['classic', 'material']) {
    testWidgets('dashboard $style', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsService();
      await s.load();
      s.uiStyle = style;
      s.fontFamily = 'poppins';
      final old = FlutterError.onError;
      FlutterError.onError = (_) {};
      await _pumpDashboard(tester, s);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dashboard_$style.png'));
      await tester.pumpWidget(const SizedBox());
      FlutterError.onError = old;
    });
  }

  testWidgets('dashboard resized + speed + 2 shortcuts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsService();
    await s.load();
    s.fontFamily = 'poppins';
    s.slots = [DashWidget.speed, DashWidget.clock, DashWidget.media];
    s.leftFrac = 0.4;
    s.shortcuts = SettingsService.defaultShortcuts().take(2).toList();
    final old = FlutterError.onError;
    FlutterError.onError = (_) {};
    await _pumpDashboard(tester, s);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dashboard_custom.png'));
    await tester.pumpWidget(const SizedBox());
    FlutterError.onError = old;
  });
}
