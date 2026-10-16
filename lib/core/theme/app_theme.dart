import 'package:flutter/material.dart';
import '../fonts.dart';
import 'dashia_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(DashiaColors c, {String fontKey = 'system'}) {
    final family = AppFont.byKey(fontKey).family;
    final base = c.isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
    final scheme = c.scheme ??
        (c.isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
          primary: c.accent,
          onPrimary: c.onAccent,
          surface: c.surface,
          onSurface: c.text,
        );
    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: scheme,
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.radius + 4),
          side: c.material ? BorderSide.none : BorderSide(color: c.border),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: family),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
      iconTheme: IconThemeData(color: c.text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceAlt),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(activeTrackColor: c.accent, thumbColor: c.accent, inactiveTrackColor: c.surfaceAlt),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(c.radius), borderSide: BorderSide.none),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.accent,
        dividerColor: c.border,
      ),
    );
  }
}
