import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/fonts.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/dashia_colors.dart';
import '../apps/services/app_launcher_service.dart';
import '../dashboard/presentation/widgets/app_icon.dart';
import '../dashboard/presentation/widgets/shortcut_editor.dart';
import '../map/map_support.dart';
import '../map/offline_map_service.dart';
import '../media/services/media_service.dart';
import 'settings_service.dart';

const _accents = <int>[
  0xFF00D2FF, 0xFF38BDF8, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEC4899, 0xFFEF4444,
  0xFFF97316, 0xFFF59E0B, 0xFFEAB308, 0xFF84CC16, 0xFF10B981, 0xFFFFFFFF,
];

/// Dashia ayarları: tema, renk, harita, saat/hız, medya, kısayollar, sistem ve dil.
class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  final MediaService media;
  final AppLauncherService apps;
  const SettingsScreen({super.key, required this.settings, required this.media, required this.apps});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;
  static const _icons = [Icons.palette_rounded, Icons.map_rounded, Icons.speed_rounded, Icons.music_note_rounded, Icons.dashboard_customize_rounded, Icons.settings_suggest_rounded];

  SettingsService get s => widget.settings;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final tr = s.tr;
        final titles = tr.settingsTabs;
        return Scaffold(
          body: SafeArea(
            child: Row(children: [
              Container(
                width: 256,
                color: c.surface,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 28), onPressed: () => Navigator.pop(context)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset('assets/images/logo.png', width: 28, height: 28),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tr.settings, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
                  for (var i = 0; i < titles.length; i++)
                    ListTile(
                      selected: _tab == i,
                      selectedTileColor: c.accent.withValues(alpha: 0.15),
                      selectedColor: c.accent,
                      leading: Icon(_icons[i]),
                      title: Text(titles[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                      minTileHeight: 58,
                      onTap: () => setState(() => _tab = i),
                    ),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(titles[_tab], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._section(context),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  List<Widget> _section(BuildContext context) {
    switch (_tab) {
      case 0:
        return _appearance(context);
      case 1:
        return [_MapSettings(settings: s)];
      case 2:
        return _clockSpeed();
      case 3:
        return _media();
      case 4:
        return _shortcuts(context);
      default:
        return _system(context);
    }
  }

  // ---------- Bileşenler ----------
  Widget _row(String title, Widget trailing, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (sub != null) Text(sub, style: TextStyle(fontSize: 13, color: context.c.textMuted)),
            ]),
          ),
          trailing,
        ]),
      );

  Widget _switch(String t, bool v, void Function(bool) f, {String? sub}) => _row(t, Switch(value: v, onChanged: (x) => s.update(() => f(x))), sub: sub);

  Widget _slider(String t, double v, double min, double max, int div, void Function(double) f, String label) => _row(
        t,
        SizedBox(
          width: 360,
          child: Row(children: [
            Expanded(child: Slider(value: v.clamp(min, max), min: min, max: max, divisions: div, onChanged: (x) => s.update(() => f(x)))),
            SizedBox(width: 56, child: Text(label, textAlign: TextAlign.end)),
          ]),
        ),
      );

  // ---------- Görünüm ----------
  List<Widget> _appearance(BuildContext context) {
    final c = context.c;
    final tr = s.tr;
    return [
      _row(
        tr.uiStyleTitle,
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'classic', label: Text(tr.styleClassic), icon: const Icon(Icons.crop_square_rounded)),
            const ButtonSegment(value: 'material', label: Text('Material'), icon: Icon(Icons.auto_awesome_rounded)),
          ],
          selected: {s.uiStyle},
          onSelectionChanged: (v) => s.update(() => s.uiStyle = v.first),
        ),
        sub: tr.uiStyleSub,
      ),
      _row(
        tr.themeTitle,
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'dark', label: Text(tr.themeDark), icon: const Icon(Icons.dark_mode_rounded)),
            const ButtonSegment(value: 'amoled', label: Text('AMOLED'), icon: Icon(Icons.brightness_1_rounded)),
            ButtonSegment(value: 'light', label: Text(tr.themeLight), icon: const Icon(Icons.light_mode_rounded)),
          ],
          selected: {s.themeMode},
          onSelectionChanged: (v) => s.update(() => s.themeMode = v.first),
        ),
      ),
      const SizedBox(height: 8),
      Text(tr.accentColor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final a in _accents)
          GestureDetector(
            onTap: () => s.update(() => s.accent = a),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Color(a),
                shape: BoxShape.circle,
                border: Border.all(color: s.accent == a ? c.text : c.border, width: s.accent == a ? 4 : 1),
              ),
              child: s.accent == a ? Icon(Icons.check_rounded, color: Color(a).computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
            ),
          ),
      ]),
      const SizedBox(height: 10),
      _HexField(
        currentAccent: s.accent,
        labelText: tr.customHexLabel,
        applyLabel: tr.apply,
        onChanged: (v) => s.update(() => s.accent = v),
      ),
      const Divider(height: 28),
      _slider(tr.cornerRadius, s.radius, 4, 28, 12, (v) => s.radius = v, '${s.radius.round()}'),
      const Divider(height: 28),
      Row(children: [
        Expanded(
          child: Text(tr.fontFamilyTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        FilledButton.tonalIcon(
          onPressed: () async {
            final picked = await widget.apps.pickFontFile();
            if (picked == null) return;
            final ok = await AppFont.loadCustomFont(picked.path);
            if (!ok) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Geçerli bir .ttf veya .otf yazı tipi dosyası seçin.')),
                );
              }
              return;
            }
            s.update(() {
              s.customFontPath = picked.path;
              s.customFontName = picked.name;
              s.fontFamily = AppFont.customKey;
            });
          },
          icon: const Icon(Icons.upload_file_rounded, size: 20),
          label: Text(tr.uploadFontBtn),
        ),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final f in AppFont.all)
          ChoiceChip(
            selected: s.fontFamily == f.key,
            onSelected: (_) => s.update(() => s.fontFamily = f.key),
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(f.label, style: TextStyle(fontSize: 18, fontFamily: f.family, fontWeight: FontWeight.w600)),
            ),
          ),
        if (s.customFontPath != null)
          ChoiceChip(
            selected: s.fontFamily == AppFont.customKey,
            onSelected: (_) => s.update(() => s.fontFamily = AppFont.customKey),
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.font_download_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  s.customFontName ?? 'Font',
                  style: const TextStyle(fontSize: 18, fontFamily: AppFont.customFamily, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
      ]),
      _slider(tr.fontSizeTitle, s.fontScale, 0.85, 1.3, 9, (v) => s.fontScale = double.parse(v.toStringAsFixed(2)), '%${(s.fontScale * 100).round()}'),
      _switch(tr.fullscreenTitle, s.fullscreen, (v) => s.fullscreen = v, sub: tr.fullscreenSub),
    ];
  }

  // ---------- Saat & Hız ----------
  List<Widget> _clockSpeed() {
    final tr = s.tr;
    return [
      _switch(tr.format24h, s.use24h, (v) => s.use24h = v),
      _switch(tr.showSeconds, s.showSeconds, (v) => s.showSeconds = v),
      _switch(tr.showDate, s.showDate, (v) => s.showDate = v),
      const Divider(height: 28),
      _row(
        tr.speedUnit,
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'kmh', label: Text('km/h')), ButtonSegment(value: 'mph', label: Text('mph'))],
          selected: {s.speedUnit},
          onSelectionChanged: (v) => s.update(() => s.speedUnit = v.first),
        ),
      ),
      _slider(tr.maxDialSpeed, s.maxSpeed.toDouble(), 120, 300, 9, (v) => s.maxSpeed = v.round(), '${s.maxSpeed}'),
    ];
  }

  // ---------- Medya ----------
  List<Widget> _media() {
    final tr = s.tr;
    return [
      _switch(tr.showAlbumArt, s.showAlbumArt, (v) => s.showAlbumArt = v),
      const Divider(height: 28),
      ValueListenableBuilder<bool>(
        valueListenable: widget.media.hasAccess,
        builder: (context, ok, _) => _row(
          tr.notifAccess,
          FilledButton.tonal(
            onPressed: () async {
              await widget.media.openAccessSettings();
            },
            child: Text(ok ? tr.openSettingsBtn : tr.grantPermission),
          ),
          sub: ok ? tr.notifGrantedSub : tr.notifMissingSub,
        ),
      ),
      TextButton.icon(
        onPressed: widget.media.refreshAccess,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(tr.refreshStatus),
      ),
    ];
  }

  // ---------- Kısayollar & Düzen ----------
  List<Widget> _shortcuts(BuildContext context) {
    final c = context.c;
    final tr = s.tr;
    return [
      Text(tr.layoutHint, style: TextStyle(color: c.textMuted)),
      const SizedBox(height: 12),
      Text(tr.screenLayout, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final (i, name) in [(0, tr.slotTopLeft), (1, tr.slotBottomLeft), (2, tr.slotRightMain)])
        _row(
          name,
          DropdownButton<DashWidget>(
            value: s.slots[i],
            underline: const SizedBox.shrink(),
            items: [for (final w in DashWidget.values) DropdownMenuItem(value: w, child: Text(tr.widgetTitle(w.name)))],
            onChanged: (w) => w == null ? null : s.placeWidget(i, w),
          ),
        ),
      _switch(
        tr.showResizeHandlesTitle,
        s.showResizeHandles,
        (v) => s.showResizeHandles = v,
        sub: tr.showResizeHandlesSub,
      ),
      _slider(tr.leftColWidth, s.leftFrac, 0.2, 0.6, 20, (v) => s.leftFrac = double.parse(v.toStringAsFixed(2)), '%${(s.leftFrac * 100).round()}'),
      _slider(tr.leftTopHeight, s.leftSplit, 0.15, 0.75, 24, (v) => s.leftSplit = double.parse(v.toStringAsFixed(2)), '%${(s.leftSplit * 100).round()}'),
      _slider(tr.bottomBarHeight, s.barHeight, 60, 120, 12, (v) => s.barHeight = v.roundToDouble(), '${s.barHeight.round()}'),
      Row(children: [
        TextButton(onPressed: s.resetLayout, child: Text(tr.resetLayoutBtn)),
      ]),
      const Divider(height: 28),
      Row(children: [
        Expanded(child: Text('${tr.shortcutsTitle} (${s.shortcuts.length}/${SettingsService.maxShortcuts})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        if (s.shortcuts.length < SettingsService.maxShortcuts)
          FilledButton.icon(
            onPressed: () => showShortcutEditor(context, settings: s, apps: widget.apps),
            icon: const Icon(Icons.add_rounded),
            label: Text(tr.addShortcutBtn),
          ),
      ]),
      const SizedBox(height: 6),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorderItem: (o, n) => s.moveShortcut(o, n),
        children: [
          for (final sc in s.shortcuts)
            ListTile(
              key: ValueKey(sc.id),
              leading: SizedBox(width: 40, child: ShortcutIcon(apps: widget.apps, shortcut: sc, size: 30)),
              title: Text(sc.label),
              subtitle: Text(sc.package ?? '—', style: TextStyle(color: c.textMuted, fontSize: 12)),
              onTap: () => showShortcutEditor(context, settings: s, apps: widget.apps, existing: sc),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 36),
                child: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => showShortcutEditor(context, settings: s, apps: widget.apps, existing: sc)),
              ),
            ),
        ],
      ),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: s.resetShortcuts, child: Text(tr.resetShortcutsBtn))),
    ];
  }

  // ---------- Sistem ----------
  List<Widget> _system(BuildContext context) {
    final c = context.c;
    final tr = s.tr;
    return [
      Text(tr.languageTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(tr.languageSub, style: TextStyle(fontSize: 13, color: c.textMuted)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final lang in AppLanguage.all)
            ChoiceChip(
              selected: s.language == lang.code,
              onSelected: (_) => s.update(() => s.language = lang.code),
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('${lang.flag}  ${lang.nativeName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      const Divider(height: 28),
      _row(
        tr.defaultHomeTitle,
        FilledButton.tonal(onPressed: widget.apps.openHomeSettings, child: Text(tr.open)),
        sub: tr.defaultHomeSub,
      ),
      const Divider(height: 28),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: c.card(color: c.surfaceAlt),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/images/logo.png', width: 64, height: 64),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dashia v1.1.0', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr.systemAboutDesc, style: TextStyle(color: c.textMuted)),
              const SizedBox(height: 4),
              Text('© OpenStreetMap contributors · Google Maps Platform', style: TextStyle(color: c.textMuted, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    ];
  }
}

/// #RRGGBB özel renk girişi (Hem Klasik hem Material You temasında çalışır).
class _HexField extends StatefulWidget {
  final int currentAccent;
  final String labelText;
  final String applyLabel;
  final void Function(int) onChanged;
  const _HexField({
    required this.currentAccent,
    required this.labelText,
    required this.applyLabel,
    required this.onChanged,
  });

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final _ctl = TextEditingController(text: _hexOf(widget.currentAccent));

  static String _hexOf(int argb) => (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  @override
  void didUpdateWidget(covariant _HexField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAccent != widget.currentAccent) {
      final expected = _hexOf(widget.currentAccent);
      if (_ctl.text.replaceAll('#', '').trim().toUpperCase() != expected) {
        _ctl.text = expected;
      }
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _applyHex(String raw) {
    var clean = raw.replaceAll('#', '').trim().toUpperCase();
    if (clean.length == 3) {
      clean = '${clean[0]}${clean[0]}${clean[1]}${clean[1]}${clean[2]}${clean[2]}';
    }
    if (clean.length == 6) {
      final n = int.tryParse(clean, radix: 16);
      if (n != null) {
        widget.onChanged(0xFF000000 | n);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(widget.currentAccent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.text.withValues(alpha: 0.4), width: 2),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 220,
        child: TextField(
          controller: _ctl,
          maxLength: 7,
          decoration: InputDecoration(
            labelText: widget.labelText,
            prefixText: '# ',
            hintText: 'FF5500',
            counterText: '',
          ),
          onChanged: (v) {
            final clean = v.replaceAll('#', '').trim();
            if (clean.length == 6) _applyHex(clean);
          },
          onSubmitted: _applyHex,
        ),
      ),
      const SizedBox(width: 10),
      FilledButton.tonal(
        onPressed: () => _applyHex(_ctl.text),
        child: Text(widget.applyLabel),
      ),
    ]);
  }
}

/// Harita ayarları (OSM / Google Maps SDK + Çevrimdışı OSM Bölge İndirici).
class _MapSettings extends StatefulWidget {
  final SettingsService settings;
  const _MapSettings({required this.settings});

  @override
  State<_MapSettings> createState() => _MapSettingsState();
}

class _MapSettingsState extends State<_MapSettings> {
  late final _osm = TextEditingController(text: s.osmUrl);
  CityPreset _selectedCity = kCityPresets.first;
  String? _customName;
  double? _customLat;
  double? _customLng;
  double _radiusKm = 10.0;
  int _maxZoom = 15; // 14: Hızlı, 15: Sokak Detaylı (Önerilen), 16: Cadde/Bina

  SettingsService get s => widget.settings;

  String get _targetName => _customName ?? _selectedCity.name;
  double get _targetLat => _customLat ?? _selectedCity.lat;
  double get _targetLng => _customLng ?? _selectedCity.lng;

  @override
  void initState() {
    super.initState();
    OfflineMapManager.instance.ensureTilesDir();
  }

  @override
  void dispose() {
    _osm.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap(BuildContext context) async {
    final res = await showDialog<({String name, double lat, double lng})>(
      context: context,
      builder: (_) => _RegionPickerDialog(
        initialName: _targetName,
        initialLat: _targetLat,
        initialLng: _targetLng,
        radiusKm: _radiusKm,
        osmUrl: s.osmUrl,
      ),
    );
    if (res != null && mounted) {
      setState(() {
        _customName = res.name.trim().isEmpty ? 'Özel Bölge' : res.name.trim();
        _customLat = res.lat;
        _customLng = res.lng;
      });
    }
  }

  Widget _row(String title, Widget trailing, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (sub != null) Text(sub, style: TextStyle(fontSize: 13, color: context.c.textMuted)),
            ]),
          ),
          trailing,
        ]),
      );

  Widget _status(bool ok, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 20, color: ok ? Colors.green : Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tr = s.tr;
    final mgr = OfflineMapManager.instance;
    final estTiles = OfflineMapManager.estimateTileCount(
      lat: _targetLat,
      lng: _targetLng,
      radiusKm: _radiusKm,
      minZoom: 10,
      maxZoom: _maxZoom,
    );
    final estMb = OfflineMapManager.estimateSizeMb(estTiles);

    return ListenableBuilder(
      listenable: Listenable.merge([s, mgr]),
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(
          tr.mapProviderTitle,
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'osm', label: Text('OpenStreetMap')), ButtonSegment(value: 'google', label: Text('Google Maps'))],
            selected: {s.mapProvider},
            onSelectionChanged: (v) => s.update(() => s.mapProvider = v.first),
          ),
        ),
        const Divider(height: 24),

        // ---------- ÇEVRİMDIŞI HARİTA İNDİRME (OFFLINE OSM) ----------
        Row(children: [
          Icon(Icons.offline_pin_rounded, color: c.accent, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr.offlineOsmTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          tr.offlineOsmSub,
          style: TextStyle(color: c.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: c.card(color: c.surfaceAlt),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Şehir / Bölge Seçimi
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(tr.cityOrRegion, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: DropdownButton<CityPreset>(
                    value: _selectedCity,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final city in kCityPresets)
                        DropdownMenuItem(
                          value: city,
                          child: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ],
                    onChanged: mgr.isDownloading
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedCity = v;
                              _customName = null;
                              _customLat = null;
                              _customLng = null;
                            });
                          },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: mgr.isDownloading ? null : () => _pickOnMap(context),
                  icon: const Icon(Icons.pin_drop_rounded, size: 20),
                  label: Text(_customName != null ? '$_customName' : tr.pickRegionOnMap),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$_targetName (${_targetLat.toStringAsFixed(4)}, ${_targetLng.toStringAsFixed(4)})',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ),
            const SizedBox(height: 14),

            // Yarıçap (Kapsama Alanı)
            Row(children: [
              Expanded(
                child: Text(tr.radiusLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 5.0, label: Text('5 km')),
                  ButtonSegment(value: 10.0, label: Text('10 km')),
                  ButtonSegment(value: 15.0, label: Text('15 km')),
                  ButtonSegment(value: 25.0, label: Text('25 km')),
                ],
                selected: {_radiusKm},
                onSelectionChanged: mgr.isDownloading ? null : (v) => setState(() => _radiusKm = v.first),
              ),
            ]),
            const SizedBox(height: 12),

            // Detay Seviyesi (Zoom)
            Row(children: [
              Expanded(
                child: Text(tr.detailLevelLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 14, label: Text('Zoom 10–14')),
                  ButtonSegment(value: 15, label: Text('Zoom 10–15')),
                  ButtonSegment(value: 16, label: Text('Zoom 10–16')),
                ],
                selected: {_maxZoom},
                onSelectionChanged: mgr.isDownloading ? null : (v) => setState(() => _maxZoom = v.first),
              ),
            ]),
            const SizedBox(height: 16),

            // İndirme Özeti & Buton
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '$_targetName (${_radiusKm.round()} km · Zoom 10–$_maxZoom)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$estTiles tiles · ~${estMb.toStringAsFixed(1)} MB',
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ]),
                  ),
                  if (!mgr.isDownloading)
                    FilledButton.icon(
                      onPressed: () => mgr.downloadRegion(
                        name: _targetName,
                        lat: _targetLat,
                        lng: _targetLng,
                        radiusKm: _radiusKm,
                        minZoom: 10,
                        maxZoom: _maxZoom,
                        urlTemplate: s.osmUrl,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr.downloadRegionBtn),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: mgr.cancelDownload,
                      icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                      label: Text(tr.stopBtn),
                    ),
                ]),
                if (mgr.isDownloading) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: mgr.progress, minHeight: 10),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      '${mgr.activeRegionName}: ${mgr.downloadedTiles} / ${mgr.totalTiles}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '%${(mgr.progress * 100).round()}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.accent),
                    ),
                  ]),
                ] else if (mgr.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(mgr.statusMessage!, style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),

            const SizedBox(height: 14),
            // Depolama ve İndirilmiş Bölgeler Listesi
            Row(children: [
              Icon(Icons.folder_special_rounded, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline cache: ${mgr.cachedFilesCount} tiles (${mgr.cachedSizeMb.toStringAsFixed(1)} MB)',
                  style: TextStyle(fontSize: 13, color: c.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
              if (mgr.cachedFilesCount > 0 && !mgr.isDownloading)
                TextButton.icon(
                  onPressed: mgr.clearAllTiles,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text(tr.clearAllBtn),
                ),
            ]),
            if (mgr.regions.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final r in mgr.regions)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.download_done_rounded, color: c.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r.name} (${r.radiusKm.round()} km · Zoom ${r.minZoom}–${r.maxZoom})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${r.tileCount} tiles · ${r.dateIso}',
                            style: TextStyle(fontSize: 12, color: c.textMuted)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => mgr.removeRegionRecord(r.id),
                    ),
                  ]),
                ),
            ],
          ]),
        ),

        const Divider(height: 28),
        const Text('OpenStreetMap Tile Server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _osm,
          decoration: InputDecoration(
            labelText: 'Tile URL Template ({z}/{x}/{y})',
            suffixIcon: IconButton(
              icon: const Icon(Icons.restore_rounded),
              onPressed: () {
                _osm.text = SettingsService.defaultOsmUrl;
                s.update(() => s.osmUrl = SettingsService.defaultOsmUrl);
              },
            ),
          ),
          onChanged: (v) {
            if (v.contains('{z}') && v.contains('{x}') && v.contains('{y}')) s.update(() => s.osmUrl = v.trim());
          },
        ),
        const Divider(height: 24),
        Text(tr.mapThemeTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (key, label, icon) in [
            ('light', tr.themeLight, Icons.light_mode_rounded),
            ('dark', tr.themeDark, Icons.dark_mode_rounded),
            ('amoled', 'AMOLED', Icons.brightness_1_rounded),
            ('midnight', 'Midnight', Icons.nights_stay_rounded),
            ('warm', 'Amber', Icons.wb_twilight_rounded),
          ])
            ChoiceChip(
              selected: s.osmTheme == key,
              onSelected: (_) => s.update(() {
                s.osmTheme = key;
                s.mapDark = key != 'light';
              }),
              avatar: Icon(icon, size: 18),
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr.mapShowSpeedTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), value: s.mapShowSpeed, onChanged: (v) => s.update(() => s.mapShowSpeed = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr.mapRotateTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), value: s.mapRotate, onChanged: (v) => s.update(() => s.mapRotate = v)),
        _row(
          tr.defaultZoomTitle,
          SizedBox(
            width: 360,
            child: Row(children: [
              Expanded(child: Slider(value: s.mapZoom, min: 10, max: 19, divisions: 9, onChanged: (v) => s.update(() => s.mapZoom = v))),
              SizedBox(width: 40, child: Text(s.mapZoom.round().toString(), textAlign: TextAlign.end)),
            ]),
          ),
        ),
        const Divider(height: 24),
        const Text('Google Maps (Maps SDK for Android)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        FutureBuilder<MapSupport>(
          future: MapSupport.check(),
          builder: (context, snap) {
            final m = snap.data;
            if (m == null) return const LinearProgressIndicator();
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: c.card(color: c.surfaceAlt),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _status(m.hasPlayServices, m.hasPlayServices ? 'Google Play Hizmetleri yüklü' : 'Google Play Hizmetleri yok (Google Haritalar çalışmaz)'),
                _status(m.hasKey, m.hasKey ? 'Maps API anahtarı derlemeye eklenmiş' : 'Maps API anahtarı bu derlemede yok'),
                if (!m.googleReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Google seçili olsa bile bu durumda harita otomatik olarak OpenStreetMap ile gösterilir.', style: TextStyle(color: c.textMuted, fontSize: 13)),
                  ),
              ]),
            );
          },
        ),
        _row(
          'Google harita türü',
          DropdownButton<String>(
            value: s.googleMapType,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'roadmap', child: Text('Yol haritası')),
              DropdownMenuItem(value: 'satellite', child: Text('Uydu')),
              DropdownMenuItem(value: 'hybrid', child: Text('Karma')),
              DropdownMenuItem(value: 'terrain', child: Text('Arazi')),
            ],
            onChanged: (v) => v == null ? null : s.update(() => s.googleMapType = v),
          ),
        ),
      ]),
    );
  }
}

/// Kullanıcının harita üzerinden dokunarak veya kaydırarak indireceği bölgeyi seçmesini sağlayan pencere.
class _RegionPickerDialog extends StatefulWidget {
  final String initialName;
  final double initialLat;
  final double initialLng;
  final double radiusKm;
  final String osmUrl;

  const _RegionPickerDialog({
    required this.initialName,
    required this.initialLat,
    required this.initialLng,
    required this.radiusKm,
    required this.osmUrl,
  });

  @override
  State<_RegionPickerDialog> createState() => _RegionPickerDialogState();
}

class _RegionPickerDialogState extends State<_RegionPickerDialog> {
  late final _nameCtl = TextEditingController(text: widget.initialName);
  late LatLng _center = LatLng(widget.initialLat, widget.initialLng);
  final _tileProvider = OfflineTileProvider();

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(c.radius)),
      child: SizedBox(
        width: 680,
        height: 440,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Text('Haritadan İndirilecek Bölgeyi Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Bölge Adı',
                    isDense: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Haritayı kaydırın veya istediğiniz merkeze dokunun (${widget.radiusKm.round()} km yarıçaplı alan indirilecek).',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 11,
                      minZoom: 4,
                      maxZoom: 17,
                      onTap: (_, pt) => setState(() => _center = pt),
                      onPositionChanged: (cam, hasGesture) {
                        if (hasGesture) setState(() => _center = cam.center);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: widget.osmUrl,
                        tileProvider: _tileProvider,
                        userAgentPackageName: 'com.dashia.launcher',
                      ),
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _center,
                          radius: widget.radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: c.accent.withValues(alpha: 0.20),
                          borderColor: c.accent,
                          borderStrokeWidth: 2.5,
                        ),
                      ]),
                      MarkerLayer(markers: [
                        Marker(
                          point: _center,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_on_rounded, color: c.accent, size: 38),
                        ),
                      ]),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  (name: _nameCtl.text, lat: _center.latitude, lng: _center.longitude),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Bu Bölgeyi Seç'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

