import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/icon_registry.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../apps/services/app_launcher_service.dart';
import '../../../settings/settings_service.dart';

/// Bir uygulamanın kendi ikonunu (yoksa yedek ikonu) gösterir.
class AppIcon extends StatelessWidget {
  final AppLauncherService apps;
  final String? package;
  final double size;
  final IconData fallback;
  const AppIcon({super.key, required this.apps, required this.package, this.size = 36, this.fallback = Icons.apps_rounded});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (package == null) return Icon(fallback, size: size, color: c.accent);
    return FutureBuilder(
      future: apps.icon(package!),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return Icon(fallback, size: size, color: c.accent);
        return Image.memory(bytes, width: size, height: size, gaplessPlayback: true, cacheWidth: (size * 2).round());
      },
    );
  }
}

/// Bir kısayolun ikonunu (kayıtlı ikon, uygulama ikonu veya galeriden özel simge) çizer.
class ShortcutIcon extends StatelessWidget {
  final AppLauncherService apps;
  final ShortcutConfig shortcut;
  final double size;
  const ShortcutIcon({super.key, required this.apps, required this.shortcut, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final key = shortcut.iconKey;
    if (key == 'app') {
      return AppIcon(apps: apps, package: shortcut.package, size: size);
    }
    if (key.startsWith('file:')) {
      final path = key.substring(5);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.file(
          File(path),
          key: ValueKey(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2.5).round(),
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, size: size, color: c.accent),
        ),
      );
    }
    return Icon(IconRegistry.byKey(key), size: size, color: c.text);
  }
}
