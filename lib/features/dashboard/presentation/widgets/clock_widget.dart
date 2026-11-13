import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../location/location_service.dart';
import '../../../settings/settings_service.dart';

/// RepaintBoundary ile izole saat: yalnızca kendini yeniden çizer.
class ClockWidget extends StatefulWidget {
  final SettingsService settings;
  final LocationService? location;
  const ClockWidget({super.key, required this.settings, this.location});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      final s = widget.settings;
      if (s.showSeconds ? n.second != _now.second : n.minute != _now.minute) {
        setState(() => _now = n);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.settings;
    final tr = s.tr;
    var h = _now.hour;
    String suffix = '';
    if (!s.use24h) {
      suffix = h >= 12 ? ' PM' : ' AM';
      h = h % 12 == 0 ? 12 : h % 12;
    }
    final time = '${_two(h)}:${_two(_now.minute)}${s.showSeconds ? ':${_two(_now.second)}' : ''}$suffix';
    final date = '${tr.weekdays[_now.weekday - 1]}, ${_now.day} ${tr.months[_now.month - 1]}';

    if (c.minimalist) {
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 4.5,
                height: 54,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: c.accent.withValues(alpha: 0.55), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.text, height: 1.02, letterSpacing: -1),
                        ),
                        if (s.showDate) ...[
                          const SizedBox(height: 3),
                          Text(date, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (s.clockShowSpeed && widget.location != null) ...[
                const SizedBox(width: 12),
                ValueListenableBuilder<LocationData>(
                  valueListenable: widget.location!.notifier,
                  builder: (context, d, _) {
                    final mph = s.speedUnit == 'mph';
                    final spd = (mph ? d.speedKmh * 0.621371 : d.speedKmh).round();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$spd', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.text, height: 1)),
                        const SizedBox(height: 2),
                        Text(mph ? 'MPH' : 'KM/H', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.accent, letterSpacing: 1.2)),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        decoration: c.card(),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(time,
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.text, height: 1.05, letterSpacing: -1)),
                  if (s.showDate)
                    Text(date, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textMuted)),
                ],
              ),
              if (s.clockShowSpeed && widget.location != null) ...[
                const SizedBox(width: 20),
                ValueListenableBuilder<LocationData>(
                  valueListenable: widget.location!.notifier,
                  builder: (context, d, _) {
                    final mph = s.speedUnit == 'mph';
                    final spd = (mph ? d.speedKmh * 0.621371 : d.speedKmh).round();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$spd', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: c.text, height: 1)),
                        Text(mph ? 'MPH' : 'KM/H', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
