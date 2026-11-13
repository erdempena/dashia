import 'dart:async';
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
import '../widgets/app_icon.dart';
import '../widgets/shortcut_editor.dart';
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
  bool _sideMenuOpen = false;

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
      if (_sideMenuOpen && mounted) {
        setState(() => _sideMenuOpen = false);
      }
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
        return ClockWidget(settings: _s, location: _location);
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

    final c = context.c;
    return Stack(children: [
      if (hasLeft)
        Positioned(
          left: 0,
          top: 0,
          width: leftW,
          height: h,
          child: Column(children: [
            if (top) SizedBox(height: topH, width: leftW, child: _slot(0)),
            if (split)
              SizedBox(
                height: gap,
                child: c.minimalist
                    ? Center(child: Container(height: 1, color: c.border))
                    : null,
              ),
            if (bot) SizedBox(height: botH, width: leftW, child: _slot(1)),
          ]),
        ),
      if (both && c.minimalist)
        Positioned(
          left: leftW + gap / 2 - 0.5,
          top: 4,
          bottom: 4,
          width: 1,
          child: Container(color: c.border),
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
      builder: (context, _) {
        final showSide = context.c.minimalist && _sideMenuOpen;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (_s.showTopBar)
                  _TopStatusBar(settings: _s, location: _location),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Expanded(
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              width: showSide ? 114.0 : 0.0,
                              margin: EdgeInsets.only(right: showSide ? 14.0 : 0.0),
                              child: ClipRect(
                                child: OverflowBox(
                                  minWidth: 114.0,
                                  maxWidth: 114.0,
                                  alignment: Alignment.centerLeft,
                                  child: _SideShortcutsCard(
                                    settings: _s,
                                    apps: _apps,
                                    onClose: () => setState(() => _sideMenuOpen = false),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, box) => _layout(box.maxWidth, box.maxHeight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      QuickAppsBar(
                        settings: _s,
                        apps: _apps,
                        sideMenuOpen: showSide,
                        onToggleSideMenu: () => setState(() => _sideMenuOpen = !_sideMenuOpen),
                        onOpenDrawer: () => showAppDrawer(context, apps: _apps),
                        onOpenSettings: _openSettings,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Minimalist temada sol alttaki ana ekran tuşuyla açılan geçici dikey kısayol kartı (maks. 4 uygulama).
class _SideShortcutsCard extends StatelessWidget {
  final SettingsService settings;
  final AppLauncherService apps;
  final VoidCallback onClose;

  const _SideShortcutsCard({
    required this.settings,
    required this.apps,
    required this.onClose,
  });

  Future<void> _launch(BuildContext context, ShortcutConfig s) async {
    if (s.package == null) {
      await showShortcutEditor(context, settings: settings, apps: apps, existing: s, isSidePanel: true);
      return;
    }
    onClose();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await apps.launch(s.package!);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('"${s.label}" açılamadı. Uygulama yüklü olmayabilir — basılı tutup değiştirin.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = settings.sideShortcuts;
    final showLabels = settings.sideShortcutsShowLabels;
    final canAdd = list.length < SettingsService.maxSideShortcuts;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: canAdd
          ? () => showShortcutEditor(context, settings: settings, apps: apps, isSidePanel: true)
          : null,
      child: Container(
        width: 114,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: c.isLight ? Colors.white : const Color(0xFF0A0C0F),
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) Divider(height: 8, thickness: 1, color: c.border),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _launch(context, list[i]),
                    onLongPress: () => showShortcutEditor(
                      context,
                      settings: settings,
                      apps: apps,
                      existing: list[i],
                      isSidePanel: true,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShortcutIcon(
                            apps: apps,
                            shortcut: list[i],
                            size: showLabels ? 34 : 42,
                            color: c.text.withValues(alpha: 0.9),
                          ),
                          if (showLabels) ...[
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                list[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.text.withValues(alpha: 0.88),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (canAdd) ...[
              if (list.isNotEmpty) Divider(height: 8, thickness: 1, color: c.border),
              SizedBox(
                height: list.isEmpty ? 80 : 40,
                width: double.infinity,
                child: Material(
                  color: c.text.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => showShortcutEditor(
                      context,
                      settings: settings,
                      apps: apps,
                      isSidePanel: true,
                    ),
                    child: Icon(Icons.add_rounded, size: 22, color: c.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// İnce üst durum şeridi (GPS durumu, Saat/Tarih, İsteğe Bağlı Hız).
class _TopStatusBar extends StatefulWidget {
  final SettingsService settings;
  final LocationService location;
  const _TopStatusBar({required this.settings, required this.location});

  @override
  State<_TopStatusBar> createState() => _TopStatusBarState();
}

class _TopStatusBarState extends State<_TopStatusBar> {
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

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: c.isLight ? Colors.white : const Color(0xFF0A0C0F),
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: ValueListenableBuilder<LocationData>(
        valueListenable: widget.location.notifier,
        builder: (context, d, _) {
          final mph = s.speedUnit == 'mph';
          final spd = (mph ? d.speedKmh * 0.621371 : d.speedKmh).round();
          final gpsText = d.permissionDenied
              ? 'KONUM İZNİ YOK'
              : d.serviceDisabled
                  ? 'GPS KAPALI'
                  : d.hasFix
                      ? 'GPS AKTİF'
                      : 'GPS ARANIYOR';

          return Row(
            children: [
              // Sol: Kokpit ikonu + İsteğe bağlı GPS durumu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_filled_rounded, size: 17, color: c.text.withValues(alpha: 0.85)),
                  if (s.topBarShowGps) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.text.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        gpsText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: d.hasFix ? c.accent : Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Orta: İsteğe bağlı Saat ve Tarih
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.topBarShowClock)
                        Text(
                          time,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.3),
                        ),
                      if (s.topBarShowClock && s.topBarShowDate)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('·', style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w800)),
                        ),
                      if (s.topBarShowDate)
                        Text(
                          date,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
              // Sağ: İsteğe bağlı Anlık Hız
              if (s.topBarShowSpeed)
                Text(
                  '$spd ${mph ? 'mph' : 'km/h'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textMuted),
                )
              else
                const SizedBox(width: 24),
            ],
          );
        },
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
