import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../apps/services/app_launcher_service.dart';
import '../../../location/location_service.dart';
import '../../../media/services/media_service.dart';
import '../../../settings/settings_screen.dart';
import '../../../settings/settings_service.dart';
import '../widgets/clock_widget.dart';
import '../widgets/map_widget.dart';
import '../widgets/media_widget.dart';
import '../widgets/quick_apps_bar.dart';
import '../widgets/slot_dialog.dart';
import '../widgets/speed_widget.dart';

class DashboardScreen extends StatefulWidget {
  final SettingsService settings;
  const DashboardScreen({super.key, required this.settings});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final _location = LocationService();
  final _media = MediaService();
  final _apps = AppLauncherService();

  SettingsService get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _location.start();
    _media.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _location.start();
      _media.refreshAccess();
    } else if (state == AppLifecycleState.paused) {
      // Başka uygulama (navigasyon) öndeyken GPS dinlemeyi bırak: CPU/RAM tasarrufu
      _location.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location.dispose();
    _media.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(settings: _s, media: _media, apps: _apps),
    ));
  }

  void _customize(int slot) {
    HapticFeedback.mediumImpact();
    showSlotDialog(context, settings: _s, slot: slot, onOpenSettings: _openSettings);
  }

  Widget _build(DashWidget w, int slot) {
    switch (w) {
      case DashWidget.clock:
        return ClockWidget(settings: _s);
      case DashWidget.speed:
        return SpeedWidget(settings: _s, location: _location);
      case DashWidget.media:
        return MediaWidget(settings: _s, media: _media);
      case DashWidget.map:
        return MapWidget(settings: _s, location: _location, apps: _apps, onMenu: () => _customize(slot));
      case DashWidget.none:
        return Container(
          decoration: context.c.card(),
          alignment: Alignment.center,
          child: Text(_s.tr.emptySlotHint, textAlign: TextAlign.center, style: TextStyle(color: context.c.textMuted)),
        );
    }
  }

  Widget _slot(int i) => KeyedSubtree(
        key: ValueKey('slot$i-${_s.slots[i].name}'),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onLongPress: () => _customize(i),
          child: _build(_s.slots[i], i),
        ),
      );

  Widget _layout(double w, double h) {
    const gap = 14.0;
    final s = _s;
    final top = s.slots[0] != DashWidget.none;
    final bot = s.slots[1] != DashWidget.none;
    final main = s.slots[2] != DashWidget.none;
    final hasLeft = top || bot;

    if (!hasLeft && !main) return SizedBox(width: w, height: h, child: _slot(2));

    final both = hasLeft && main;
    final leftW = both ? (w - gap) * s.leftFrac : (hasLeft ? w : 0.0);
    final mainW = main ? (both ? w - gap - leftW : w) : 0.0;
    final split = top && bot;
    final avail = split ? h - gap : h;
    final topH = split ? avail * s.leftSplit : (top ? h : 0.0);
    final botH = split ? avail - topH : (bot ? h : 0.0);

    return Stack(children: [
      if (hasLeft)
        Positioned(
          left: 0,
          top: 0,
          width: leftW,
          height: h,
          child: Column(children: [
            if (top) SizedBox(height: topH, width: leftW, child: _slot(0)),
            if (split) const SizedBox(height: gap),
            if (bot) SizedBox(height: botH, width: leftW, child: _slot(1)),
          ]),
        ),
      if (main) Positioned(left: both ? leftW + gap : 0, top: 0, width: mainW, height: h, child: _slot(2)),
      // Dikey ayırıcı: sol sütun genişliği (isteğe bağlı gizlenebilir)
      if (both && s.showResizeHandles)
        Positioned(
          left: leftW + gap / 2 - 18,
          top: h / 2 - 50,
          width: 36,
          height: 100,
          child: _ResizeHandle(
            vertical: true,
            onDrag: (d) => s.updateLive(() => s.leftFrac = (s.leftFrac + d / (w - gap)).clamp(0.2, 0.6)),
            onEnd: s.save,
          ),
        ),
      // Yatay ayırıcı: sol sütunda üst/alt oranı (isteğe bağlı gizlenebilir)
      if (split && s.showResizeHandles)
        Positioned(
          left: leftW / 2 - 50,
          top: topH + gap / 2 - 18,
          width: 100,
          height: 36,
          child: _ResizeHandle(
            vertical: false,
            onDrag: (d) => s.updateLive(() => s.leftSplit = (s.leftSplit + d / avail).clamp(0.15, 0.75)),
            onEnd: s.save,
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Expanded(child: LayoutBuilder(builder: (context, box) => _layout(box.maxWidth, box.maxHeight))),
              const SizedBox(height: 12),
              QuickAppsBar(
                settings: _s,
                apps: _apps,
                onOpenDrawer: () => showAppDrawer(context, apps: _apps),
                onOpenSettings: _openSettings,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Alanlar arasındaki sürüklenebilir boyutlandırma tutamacı.
class _ResizeHandle extends StatelessWidget {
  final bool vertical;
  final void Function(double delta) onDrag;
  final VoidCallback onEnd;
  const _ResizeHandle({required this.vertical, required this.onDrag, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => onDrag(vertical ? d.delta.dx : d.delta.dy),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: Center(
        child: Container(
          width: vertical ? 6 : 48,
          height: vertical ? 48 : 6,
          decoration: BoxDecoration(color: c.textMuted.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(3)),
        ),
      ),
    );
  }
}
