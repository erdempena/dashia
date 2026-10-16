import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/settings/settings_service.dart';

/// Tüm arayüzün kullandığı renk/şekil token'ları (ayarlardan üretilir).
class DashiaColors extends ThemeExtension<DashiaColors> {
  final Color background, surface, surfaceAlt, border, text, textMuted, accent, onAccent;
  final double radius;
  /// true: Material 3 (tonal, çerçevesiz) stil; false: klasik düz çerçeveli stil.
  final bool material;
  final ColorScheme? scheme;

  const DashiaColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.radius,
    this.material = false,
    this.scheme,
  });

  factory DashiaColors.from(SettingsService s) {
    final accent = Color(s.accent);
    final amoled = s.themeMode == 'amoled';
    final light = s.themeMode == 'light';
    final onAccent = accent.computeLuminance() > 0.45 ? const Color(0xFF0B0F14) : Colors.white;

    if (s.uiStyle == 'material') {
      final baseScheme = ColorScheme.fromSeed(
        seedColor: accent,
        brightness: light ? Brightness.light : Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      // Özel HEX renklerinin (düşük doygunluklu veya tam doygun renkler dahil)
      // Material You temasında birebir kullanılabilmesi için:
      final bgBase = amoled
          ? Colors.black
          : (light ? const Color(0xFFF6F8FC) : const Color(0xFF0E1116));
      final surfBase = amoled
          ? const Color(0xFF121212)
          : (light ? Colors.white : const Color(0xFF181C24));
      final surfAltBase = amoled
          ? const Color(0xFF202020)
          : (light ? const Color(0xFFE9EEF5) : const Color(0xFF242A36));

      final background = amoled ? Colors.black : Color.alphaBlend(accent.withValues(alpha: light ? 0.05 : 0.07), bgBase);
      final surface = Color.alphaBlend(accent.withValues(alpha: amoled ? 0.08 : (light ? 0.08 : 0.13)), surfBase);
      final surfaceAlt = Color.alphaBlend(accent.withValues(alpha: amoled ? 0.16 : (light ? 0.16 : 0.22)), surfAltBase);

      final scheme = baseScheme.copyWith(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        surface: surface,
        surfaceContainerHigh: surface,
        secondaryContainer: surfaceAlt,
      );

      return DashiaColors(
        background: background,
        surface: surface,
        surfaceAlt: surfaceAlt,
        border: Colors.transparent,
        text: light ? const Color(0xFF0F172A) : Colors.white,
        textMuted: light ? const Color(0xFF475569) : const Color(0xFFA0AEC0),
        accent: accent,
        onAccent: onAccent,
        radius: math.max(s.radius, 22),
        material: true,
        scheme: scheme,
      );
    }

    if (amoled) {
      return DashiaColors(
        background: const Color(0xFF000000),
        surface: const Color(0xFF0B0B0B),
        surfaceAlt: const Color(0xFF181818),
        border: const Color(0xFF282828),
        text: Colors.white,
        textMuted: const Color(0xFF9AA4B2),
        accent: accent,
        onAccent: onAccent,
        radius: s.radius,
      );
    }
    if (light) {
      return DashiaColors(
        background: const Color(0xFFEFF3F8),
        surface: Colors.white,
        surfaceAlt: const Color(0xFFE2E8F0),
        border: const Color(0xFFCBD5E1),
        text: const Color(0xFF0F172A),
        textMuted: const Color(0xFF475569),
        accent: accent,
        onAccent: onAccent,
        radius: s.radius,
      );
    }
    return DashiaColors(
      background: const Color(0xFF0C0E12),
      surface: const Color(0xFF161A22),
      surfaceAlt: const Color(0xFF222834),
      border: const Color(0xFF2E3646),
      text: Colors.white,
      textMuted: const Color(0xFF94A3B8),
      accent: accent,
      onAccent: onAccent,
      radius: s.radius,
    );
  }

  bool get isLight => background.computeLuminance() > 0.5;

  BoxDecoration card({Color? color, Color? borderColor}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border, width: 1),
      );

  @override
  DashiaColors copyWith() => this;

  @override
  DashiaColors lerp(ThemeExtension<DashiaColors>? other, double t) => other is DashiaColors ? other : this;
}

extension DashiaContext on BuildContext {
  DashiaColors get c => Theme.of(this).extension<DashiaColors>()!;
}
