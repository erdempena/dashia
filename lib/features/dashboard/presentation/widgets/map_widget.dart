import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../apps/services/app_launcher_service.dart';
import '../../../location/location_service.dart';
import '../../../map/map_support.dart';
import '../../../map/offline_map_service.dart';
import '../../../settings/settings_service.dart';

const _googleDarkStyle = '[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#9aa4b2"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#3a4555"}]},'
    '{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#7a6a55"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},'
    '{"featureType":"poi","stylers":[{"visibility":"off"}]},'
    '{"featureType":"transit","stylers":[{"visibility":"off"}]}]';

/// Yumuşak geçişli (60 FPS interpolasyonlu) anlık konum durumu.
class _SmoothLoc {
  final double? lat;
  final double? lng;
  final double heading;
  const _SmoothLoc({this.lat, this.lng, this.heading = 0});
}

/// OpenStreetMap (flutter_map) veya Google Maps SDK ile anlık konum haritası.
class MapWidget extends StatefulWidget {
  final SettingsService settings;
  final LocationService location;
  final AppLauncherService apps;
  final VoidCallback onMenu;
  const MapWidget({super.key, required this.settings, required this.location, required this.apps, required this.onMenu});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with SingleTickerProviderStateMixin {
  static const _defaultCenter = LatLng(41.0082, 28.9784);

  // 1) Koyu (Standart Gece): invert + hue-rotate(180deg), dengeli koyu gri zemin
  static const _darkMatrix = <double>[
    0.574, -1.430, -0.144, 0, 255, //
    -0.426, -0.430, -0.144, 0, 255,
    -0.426, -1.430, 0.856, 0, 255,
    0, 0, 0, 1, 0,
  ];

  // 2) AMOLED (Tam Siyah): zemini tam siyaha çeker, yolları ve yazıları parlak tutar
  static const _amoledMatrix = <double>[
    -0.38, -0.75, -0.07, 0, 290, // R, G, B tamamen eşitlendi
    -0.38, -0.75, -0.07, 0, 290, // Yeşil veya mavi patlaması imkansızdır
    -0.38, -0.75, -0.07, 0, 290,
    0, 0, 0, 1, 0,
  ];

  // 3) Gece Mavisi (Midnight): koyu lacivert kokpit tonu
  static const _midnightMatrix = <double>[
    -0.38, -0.75, -0.07, 0, 290, // R, G, B tamamen eşitlendi
    -0.38, -0.75, -0.07, 0, 290, // Yeşil veya mavi patlaması imkansızdır
    -0.38, -0.75, -0.07, 0, 320,
    0, 0, 0, 1, 0,
  ];

  // 4) Sıcak Kehribar (Warm Night): gece sürüşünde göz yormayan kehribar/sıcak koyu ton
  static const _warmMatrix = <double>[
    0.66, -1.50, -0.15, 0, 255, //
    -0.40, -0.45, -0.15, 0, 238,
    -0.45, -1.55, 0.65, 0, 200,
    0, 0, 0, 1, 0,
  ];

  List<double>? get _activeOsmMatrix => switch (_s.osmTheme) {
        'light' => null,
        'amoled' => _amoledMatrix,
        'midnight' => _midnightMatrix,
        'warm' => _warmMatrix,
        _ => _darkMatrix,
      };

  Color _osmBg(DashiaColors c) => switch (_s.osmTheme) {
        'light' => const Color(0xFFE8E6E1),
        'amoled' => Colors.black,
        'midnight' => const Color(0xFF0A1222),
        'warm' => const Color(0xFF16110C),
        _ => const Color(0xFF141820),
      };

  final _mc = MapController();
  final _tileProvider = OfflineTileProvider();
  g.GoogleMapController? _gc;
  double _gZoom = 16;
  MapSupport? _support;
  bool _ready = false;
  bool _follow = true;
  bool _firstFix = true;
  bool _wasGoogle = false;

  // Google Maps tarzı yumuşak konum & yön interpolasyonu
  late final AnimationController _anim;
  final ValueNotifier<_SmoothLoc> _smooth = ValueNotifier(const _SmoothLoc());
  double? _fromLat, _fromLng, _toLat, _toLng;
  double _fromHeading = 0, _toHeading = 0;

  SettingsService get _s => widget.settings;

  bool get _useGoogle => _s.mapProvider == 'google' && (_support?.googleReady ?? false);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
      ..addListener(_onAnimTick);
    final initLoc = widget.location.notifier.value;
    if (initLoc.lat != null && initLoc.lng != null) {
      _fromLat = _toLat = initLoc.lat;
      _fromLng = _toLng = initLoc.lng;
      _fromHeading = _toHeading = initLoc.heading;
      _smooth.value = _SmoothLoc(lat: initLoc.lat, lng: initLoc.lng, heading: initLoc.heading);
    }
    _s.addListener(_onSettings);
    widget.location.notifier.addListener(_onLocation);
    OfflineMapManager.instance.ensureTilesDir().then((_) {
      if (mounted) setState(() {});
    });
    MapSupport.check().then((v) {
      if (mounted) setState(() => _support = v);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _smooth.dispose();
    _s.removeListener(_onSettings);
    widget.location.notifier.removeListener(_onLocation);
    _mc.dispose();
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  /// İki açı (derece) arasında en kısa yoldan yumuşak geçiş yapar (örn. 358° -> 2°).
  static double _lerpAngle(double from, double to, double t) {
    final diff = ((to - from + 540.0) % 360.0) - 180.0;
    return (from + diff * t + 360.0) % 360.0;
  }

  void _onAnimTick() {
    if (_fromLat == null || _toLat == null || _fromLng == null || _toLng == null) return;
    final t = Curves.linear.transform(_anim.value);
    final lat = _fromLat! + (_toLat! - _fromLat!) * t;
    final lng = _fromLng! + (_toLng! - _fromLng!) * t;
    final hdg = _lerpAngle(_fromHeading, _toHeading, t);
    _smooth.value = _SmoothLoc(lat: lat, lng: lng, heading: hdg);

    if (_follow && !_useGoogle && _ready) {
      final zoom = _mc.camera.zoom;
      final bearing = _s.mapRotate ? hdg : 0.0;
      _mc.moveAndRotate(LatLng(lat, lng), zoom, -bearing);
    }
  }

  void _onLocation() {
    final d = widget.location.notifier.value;
    if (d.lat == null || d.lng == null) return;

    final cur = _smooth.value;
    final isJump = cur.lat == null ||
        cur.lng == null ||
        (d.lat! - cur.lat!).abs() > 0.02 ||
        (d.lng! - cur.lng!).abs() > 0.02;

    if (isJump) {
      _anim.stop();
      _fromLat = _toLat = d.lat;
      _fromLng = _toLng = d.lng;
      _fromHeading = _toHeading = d.heading;
      _smooth.value = _SmoothLoc(lat: d.lat, lng: d.lng, heading: d.heading);
    } else {
      _fromLat = cur.lat;
      _fromLng = cur.lng;
      _fromHeading = cur.heading;
      _toLat = d.lat;
      _toLng = d.lng;
      _toHeading = d.heading;
      _anim.forward(from: 0);
    }

    if (!_follow) return;
    final bearing = _s.mapRotate ? d.heading : 0.0;
    if (_useGoogle) {
      final c = _gc;
      if (c == null) return;
      final zoom = _firstFix ? _s.mapZoom : _gZoom;
      _firstFix = false;
      c.animateCamera(g.CameraUpdate.newCameraPosition(
        g.CameraPosition(target: g.LatLng(d.lat!, d.lng!), zoom: zoom, bearing: bearing),
      ));
    } else if (_ready) {
      if (_firstFix || isJump) {
        final zoom = _firstFix ? _s.mapZoom : _mc.camera.zoom;
        _firstFix = false;
        _mc.moveAndRotate(LatLng(d.lat!, d.lng!), zoom, -bearing);
      }
    }
  }

  void _recenter() {
    setState(() => _follow = true);
    _firstFix = true;
    final cur = _smooth.value;
    if (!_useGoogle && _ready && cur.lat != null && cur.lng != null) {
      final bearing = _s.mapRotate ? cur.heading : 0.0;
      _mc.moveAndRotate(LatLng(cur.lat!, cur.lng!), _s.mapZoom, -bearing);
      _firstFix = false;
    } else {
      _onLocation();
    }
  }

  void _zoom(double delta) {
    if (_useGoogle) {
      _gc?.animateCamera(delta > 0 ? g.CameraUpdate.zoomIn() : g.CameraUpdate.zoomOut());
    } else if (_ready) {
      _mc.move(_mc.camera.center, (_mc.camera.zoom + delta).clamp(3.0, 19.0));
    }
  }

  g.MapType get _gType => switch (_s.googleMapType) {
        'satellite' => g.MapType.satellite,
        'terrain' => g.MapType.terrain,
        'hybrid' => g.MapType.hybrid,
        _ => g.MapType.normal,
      };

  Widget _osmMap(DashiaColors c, LatLng start, bool hasPos) {
    final hasOfflineRegion = OfflineMapManager.instance.regions.isNotEmpty;
    final matrix = _activeOsmMatrix;
    return FlutterMap(
      mapController: _mc,
      options: MapOptions(
        initialCenter: start,
        initialZoom: hasPos ? _s.mapZoom : (hasOfflineRegion ? 12.0 : 11.0),
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: _osmBg(c),
        onMapReady: () {
          _ready = true;
          _onLocation();
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _follow) setState(() => _follow = false);
        },
      ),
      children: [
        TileLayer(
          key: ValueKey('${_s.osmUrl}|${_s.osmTheme}'),
          urlTemplate: _s.osmUrl,
          tileProvider: _tileProvider,
          userAgentPackageName: 'com.dashia.launcher',
          maxNativeZoom: 19,
          tileBuilder: matrix != null
              ? (context, tile, info) => ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: tile)
              : null,
        ),
        ValueListenableBuilder<_SmoothLoc>(
          valueListenable: _smooth,
          builder: (context, pos, _) => MarkerLayer(markers: [
            if (pos.lat != null && pos.lng != null)
              Marker(
                point: LatLng(pos.lat!, pos.lng!),
                width: 46,
                height: 46,
                child: Transform.rotate(
                  angle: pos.heading * math.pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Icon(Icons.navigation_rounded, color: c.onAccent, size: 24),
                  ),
                ),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _googleMap(LatLng start, bool hasPos) {
    return Listener(
      onPointerMove: (e) {
        if (_follow && e.delta.distance > 2) setState(() => _follow = false);
      },
      child: g.GoogleMap(
        initialCameraPosition: g.CameraPosition(target: g.LatLng(start.latitude, start.longitude), zoom: hasPos ? _s.mapZoom : 6),
        mapType: _gType,
        style: _s.mapDark && _s.googleMapType == 'roadmap' ? _googleDarkStyle : null,
        myLocationEnabled: hasPos,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        tiltGesturesEnabled: false,
        onMapCreated: (c) {
          _gc = c;
          _onLocation();
        },
        onCameraMove: (p) => _gZoom = p.zoom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = _s;
    final tr = s.tr;
    final googleWanted = s.mapProvider == 'google';
    final useGoogle = _useGoogle;
    if (useGoogle != _wasGoogle) {
      _wasGoogle = useGoogle;
      _ready = false;
      _gc = null;
      _firstFix = true;
    }
    final d = widget.location.notifier.value;
    final hasPos = d.lat != null;
    final regions = OfflineMapManager.instance.regions;
    final fallbackCenter = regions.isNotEmpty ? LatLng(regions.first.lat, regions.first.lng) : _defaultCenter;
    final start = hasPos ? LatLng(d.lat!, d.lng!) : fallbackCenter;

    String? banner;
    if (googleWanted && _support != null && !useGoogle) {
      banner = '${_support!.problem} → OpenStreetMap';
    }
    if (d.permissionDenied) banner = tr.locPermDenied;
    if (d.serviceDisabled) banner = tr.locServiceDisabled;

    return Container(
      decoration: c.card(),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: (googleWanted && _support == null)
              ? const SizedBox.shrink()
              : (useGoogle ? _googleMap(start, hasPos) : _osmMap(c, start, hasPos)),
        ),

        // Hız çipi
        if (s.mapShowSpeed)
          Positioned(
            left: 10,
            top: 10,
            child: ValueListenableBuilder<LocationData>(
              valueListenable: widget.location.notifier,
              builder: (context, d, _) {
                final mph = s.speedUnit == 'mph';
                final v = (mph ? d.speedKmh * 0.621371 : d.speedKmh).round();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: c.background.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(c.radius)),
                  child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('$v', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.text)),
                    const SizedBox(width: 4),
                    Text(mph ? 'mph' : 'km/h', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                  ]),
                );
              },
            ),
          ),

        // Üst sağ: Google Haritalar uygulaması + özelleştir
        Positioned(
          right: 10,
          top: 10,
          child: Row(children: [
            _MapBtn(icon: Icons.open_in_new_rounded, onTap: () async {
              final ok = await widget.apps.launch('com.google.android.apps.maps');
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Maps not installed')));
              }
            }),
            const SizedBox(width: 8),
            _MapBtn(icon: Icons.tune_rounded, onTap: widget.onMenu),
          ]),
        ),

        // Sağ alt: yakınlaştırma ve konuma dön
        Positioned(
          right: 10,
          bottom: 10,
          child: Column(children: [
            _MapBtn(icon: Icons.add_rounded, onTap: () => _zoom(1)),
            const SizedBox(height: 8),
            _MapBtn(icon: Icons.remove_rounded, onTap: () => _zoom(-1)),
            const SizedBox(height: 8),
            _MapBtn(icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded, active: !_follow, onTap: _recenter),
          ]),
        ),

        if (!useGoogle)
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black54,
              child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ),
          ),

        if (banner != null)
          Positioned(
            left: 10,
            right: 70,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.amber.shade800.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10)),
              child: Text(banner, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _MapBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: active ? c.accent : c.background.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(c.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(c.radius),
        onTap: onTap,
        child: SizedBox(width: 52, height: 52, child: Icon(icon, size: 28, color: active ? c.onAccent : c.text)),
      ),
    );
  }
}
