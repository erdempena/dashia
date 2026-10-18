import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../settings/settings_service.dart';

/// RepaintBoundary ile izole saat: yalnızca kendini yeniden çizer.
class ClockWidget extends StatefulWidget {
  final SettingsService settings;
  const ClockWidget({super.key, required this.settings});

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

    return RepaintBoundary(
      child: Container(
        decoration: c.card(),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(time,
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.text, height: 1.05, letterSpacing: -1)),
              if (s.showDate)
                Text(date, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
