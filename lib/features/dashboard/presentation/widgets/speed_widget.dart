import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../location/location_service.dart';
import '../../../settings/settings_service.dart';

class SpeedWidget extends StatelessWidget {
  final SettingsService settings;
  final LocationService location;
  const SpeedWidget({super.key, required this.settings, required this.location});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return RepaintBoundary(
      child: Container(
        decoration: c.card(),
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder<LocationData>(
          valueListenable: location.notifier,
          builder: (context, d, _) {
            final mph = settings.speedUnit == 'mph';
            final speed = (mph ? d.speedKmh * 0.621371 : d.speedKmh).round();
            final max = mph ? (settings.maxSpeed * 0.621371).round() : settings.maxSpeed;
            final status = d.permissionDenied
                ? 'KONUM İZNİ YOK'
                : d.serviceDisabled
                    ? 'GPS KAPALI'
                    : d.hasFix
                        ? 'GPS AKTİF'
                        : 'GPS ARANIYOR';
            final ok = d.hasFix;
            return LayoutBuilder(builder: (context, box) {
              final side = math.min(box.maxWidth, box.maxHeight - 24).clamp(80.0, 400.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        fraction: (speed / max).clamp(0.0, 1.0),
                        track: c.surfaceAlt,
                        color: speed > max * 0.65
                            ? Colors.redAccent
                            : speed > max * 0.45
                                ? Colors.amber
                                : c.accent,
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$speed',
                                    style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: c.text, height: 1, letterSpacing: -2)),
                                Text(mph ? 'MPH' : 'KM/H',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.accent, letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? Colors.green : Colors.amber)),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted)),
                  ]),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color track, color;
  const _GaugePainter({required this.fraction, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke);
    const start = 135 * math.pi / 180;
    const sweep = 270 * math.pi / 180;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, p..color = track);
    if (fraction > 0) canvas.drawArc(rect, start, sweep * fraction, false, p..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.fraction != fraction || o.color != color || o.track != track;
}
