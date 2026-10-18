import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dashia_colors.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/settings/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  final settings = SettingsService();
  await settings.load();
  runApp(DashiaApp(settings: settings));
}

class DashiaApp extends StatefulWidget {
  final SettingsService settings;
  const DashiaApp({super.key, required this.settings});

  @override
  State<DashiaApp> createState() => _DashiaAppState();
}

class _DashiaAppState extends State<DashiaApp> {
  bool? _lastFullscreen;

  void _applySystemUi() {
    final fs = widget.settings.fullscreen;
    if (fs == _lastFullscreen) return;
    _lastFullscreen = fs;
    SystemChrome.setEnabledSystemUIMode(fs ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        _applySystemUi();
        final s = widget.settings;
        final colors = DashiaColors.from(s);
        final theme = AppTheme.build(colors, fontKey: s.fontFamily).copyWith(extensions: [colors]);
        return MaterialApp(
          title: 'Dashia',
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s.fontScale)),
            child: child!,
          ),
          home: DashboardScreen(settings: s),
        );
      },
    );
  }
}
