import 'dart:io';
import 'dart:math' as math;
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
  final Color? color;
  const ShortcutIcon({super.key, required this.apps, required this.shortcut, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final key = shortcut.iconKey;
    final isDayNightToggle =
        shortcut.package == SettingsService.dayNightTogglePackage || key == 'day_night';
    if (isDayNightToggle && !key.startsWith('file:')) {
      return DayNightSwitchIcon(size: size, color: color);
    }
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
    return Icon(IconRegistry.byKey(key), size: size, color: color ?? c.text);
  }
}

/// Gece / Gündüz geçiş tuşu için diğer uygulama ikonlarıyla aynı renkte, sade ve minimal Güneş <-> Ay animasyonlu ikon.
class DayNightSwitchIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const DayNightSwitchIcon({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconColor = color ?? c.text;
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.isDayNotifier,
      builder: (context, isDay, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isDay ? 0.0 : 1.0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            final clamped = t.clamp(0.0, 1.0);
            final sunOpacity = (1.0 - clamped).clamp(0.0, 1.0);
            final moonOpacity = clamped.clamp(0.0, 1.0);

            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (sunOpacity > 0.01)
                    Opacity(
                      opacity: sunOpacity,
                      child: Transform.rotate(
                        angle: clamped * math.pi * 0.5,
                        child: Transform.scale(
                          scale: 1.0 - clamped * 0.35,
                          child: Icon(
                            Icons.light_mode_rounded,
                            size: size,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ),
                  if (moonOpacity > 0.01)
                    Opacity(
                      opacity: moonOpacity,
                      child: Transform.rotate(
                        angle: -(1.0 - clamped) * math.pi * 0.5,
                        child: Transform.scale(
                          scale: 0.65 + clamped * 0.35,
                          child: Icon(
                            Icons.dark_mode_rounded,
                            size: size,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
