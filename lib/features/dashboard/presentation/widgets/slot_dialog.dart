import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../settings/settings_service.dart';

/// Bir alana basılı tutunca açılan özelleştirme penceresi:
/// bileşen seçimi, boyut ayarı ve seçili bileşenin hızlı ayarları.
Future<void> showSlotDialog(BuildContext context, {required SettingsService settings, required int slot, required VoidCallback onOpenSettings}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SlotDialog(settings: settings, slot: slot, onOpenSettings: onOpenSettings),
  );
}

const _icons = {
  DashWidget.clock: Icons.access_time_rounded,
  DashWidget.speed: Icons.speed_rounded,
  DashWidget.media: Icons.music_note_rounded,
  DashWidget.map: Icons.map_rounded,
  DashWidget.none: Icons.visibility_off_rounded,
};

class _SlotDialog extends StatelessWidget {
  final SettingsService settings;
  final int slot;
  final VoidCallback onOpenSettings;
  const _SlotDialog({required this.settings, required this.slot, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.of(context).size;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final current = settings.slots[slot];
        final s = settings;
        final t = s.tr;
        final hasLeft = s.slots[0] != DashWidget.none || s.slots[1] != DashWidget.none;
        final hasMain = s.slots[2] != DashWidget.none;
        final both = hasLeft && hasMain;
        final split = s.slots[0] != DashWidget.none && s.slots[1] != DashWidget.none;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * 0.92),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.customizeSlot, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ]),
                Text(t.customizeSlotSub, style: TextStyle(color: c.textMuted)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final w in DashWidget.values)
                    SizedBox(
                      width: 164,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(c.radius),
                        onTap: () => settings.placeWidget(slot, w),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: w == current ? c.accent.withValues(alpha: 0.15) : c.surfaceAlt,
                            borderRadius: BorderRadius.circular(c.radius),
                            border: Border.all(color: w == current ? c.accent : (c.material ? Colors.transparent : c.border), width: 2),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(_icons[w], size: 30, color: w == current ? c.accent : c.text),
                            const SizedBox(height: 6),
                            Text(_wTitle(w), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(_wDesc(w), style: TextStyle(fontSize: 12, color: c.textMuted)),
                            if (w != DashWidget.none && !settings.slots.contains(w)) Text(t.currentlyHidden, style: TextStyle(fontSize: 11, color: c.accent)),
                          ]),
                        ),
                      ),
                    ),
                ]),
                const Divider(height: 28),
                Text(t.sizeAndLock, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                _switch(
                  t.showResizeHandles,
                  s.showResizeHandles,
                  (v) => s.showResizeHandles = v,
                ),
                if (both)
                  _slider(t.leftColWidth, s.leftFrac, 0.2, 0.6, (v) => s.update(() => s.leftFrac = v), '%${(s.leftFrac * 100).round()}'),
                if (split)
                  _slider(t.topLeftHeight, s.leftSplit, 0.15, 0.75, (v) => s.update(() => s.leftSplit = v), '%${(s.leftSplit * 100).round()}'),
                if (!both && !split)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(t.needTwoSlots, style: TextStyle(color: c.textMuted))),
                _slider(t.bottomBarHeight, s.barHeight, 60, 120, (v) => s.update(() => s.barHeight = v.roundToDouble()), '${s.barHeight.round()}'),
                if (current != DashWidget.none) ...[
                  const Divider(height: 28),
                  Text(_wTitle(current), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _quick(context, current),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(onPressed: s.resetLayout, child: Text(t.resetLayout)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onOpenSettings();
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(t.allSettings),
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  String _wTitle(DashWidget w) {
    final t = settings.tr;
    switch (w) {
      case DashWidget.clock: return t.wClock;
      case DashWidget.speed: return t.wSpeed;
      case DashWidget.media: return t.wMedia;
      case DashWidget.map: return t.wMap;
      case DashWidget.none: return t.wNone;
    }
  }

  String _wDesc(DashWidget w) {
    final t = settings.tr;
    switch (w) {
      case DashWidget.clock: return t.wClockDesc;
      case DashWidget.speed: return t.wSpeedDesc;
      case DashWidget.media: return t.wMediaDesc;
      case DashWidget.map: return t.wMapDesc;
      case DashWidget.none: return t.wNoneDesc;
    }
  }

  Widget _slider(String t, double v, double min, double max, void Function(double) f, String label) => Row(children: [
        SizedBox(width: 190, child: Text(t)),
        Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: f)),
        SizedBox(width: 52, child: Text(label, textAlign: TextAlign.end)),
      ]);

  Widget _switch(String t, bool v, void Function(bool) f) =>
      SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t), value: v, onChanged: (x) => settings.update(() => f(x)));

  Widget _quick(BuildContext context, DashWidget w) {
    final s = settings;
    final t = s.tr;
    switch (w) {
      case DashWidget.none:
        return const SizedBox.shrink();
      case DashWidget.clock:
        return Column(children: [
          _switch(t.format24h, s.use24h, (v) => s.use24h = v),
          _switch(t.showSeconds, s.showSeconds, (v) => s.showSeconds = v),
          _switch(t.showDate, s.showDate, (v) => s.showDate = v),
        ]);
      case DashWidget.speed:
        return Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'kmh', label: Text('km/h')), ButtonSegment(value: 'mph', label: Text('mph'))],
            selected: {s.speedUnit},
            onSelectionChanged: (v) => s.update(() => s.speedUnit = v.first),
          ),
        );
      case DashWidget.media:
        return _switch(t.showAlbumArt, s.showAlbumArt, (v) => s.showAlbumArt = v);
      case DashWidget.map:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'osm', label: Text('OpenStreetMap')), ButtonSegment(value: 'google', label: Text('Google Maps'))],
            selected: {s.mapProvider},
            onSelectionChanged: (v) => s.update(() => s.mapProvider = v.first),
          ),
          const SizedBox(height: 10),
          Text(t.osmThemeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'light', label: Text(t.mapLight)),
              ButtonSegment(value: 'dark', label: Text(t.mapDark)),
              const ButtonSegment(value: 'amoled', label: Text('AMOLED')),
              ButtonSegment(value: 'midnight', label: Text(t.mapMidnight)),
              ButtonSegment(value: 'warm', label: Text(t.mapWarm)),
            ],
            selected: {s.osmTheme},
            onSelectionChanged: (v) => s.update(() {
              s.osmTheme = v.first;
              s.mapDark = s.osmTheme != 'light';
            }),
          ),
          const SizedBox(height: 4),
          _switch(t.showSpeedChip, s.mapShowSpeed, (v) => s.mapShowSpeed = v),
          _switch(t.rotateMapHeading, s.mapRotate, (v) => s.mapRotate = v),
        ]);
    }
  }
}
