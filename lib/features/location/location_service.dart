import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Anlık konum / hız bilgisi.
class LocationData {
  final double? lat, lng;
  final double speedKmh;
  final double heading;
  final bool hasFix;
  final bool permissionDenied;
  final bool serviceDisabled;

  const LocationData({
    this.lat,
    this.lng,
    this.speedKmh = 0,
    this.heading = 0,
    this.hasFix = false,
    this.permissionDenied = false,
    this.serviceDisabled = false,
  });
}

/// Harita ve hız göstergesinin ortak kullandığı tek GPS akışı.
/// Android LocationManager zorlanır: Google Play Hizmetleri olmayan
/// araç multimedya üniteleri için gereklidir.
class LocationService {
  final ValueNotifier<LocationData> notifier = ValueNotifier(const LocationData());
  StreamSubscription<Position>? _sub;
  bool _starting = false;

  bool get isRunning => _sub != null;

  Future<void> start() async {
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        notifier.value = const LocationData(serviceDisabled: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        notifier.value = const LocationData(permissionDenied: true);
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _onPosition(last, fix: false);

      _sub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(milliseconds: 500),
          forceLocationManager: true,
        ),
      ).listen(_onPosition, onError: (Object e) {
        debugPrint('GPS hatası: $e');
      });
    } catch (e) {
      debugPrint('LocationService başlatılamadı: $e');
    } finally {
      _starting = false;
    }
  }

  void _onPosition(Position p, {bool fix = true}) {
    var kmh = p.speed > 0 ? p.speed * 3.6 : 0.0;
    if (kmh < 2) kmh = 0; // durma titreşimini sıfırla
    final prev = notifier.value;

    double heading = prev.heading;
    if (kmh > 2.5) {
      if (p.heading > 0.1) {
        heading = p.heading % 360;
      } else if (prev.lat != null && prev.lng != null) {
        final dist = Geolocator.distanceBetween(prev.lat!, prev.lng!, p.latitude, p.longitude);
        if (dist > 1.5) {
          final b = Geolocator.bearingBetween(prev.lat!, prev.lng!, p.latitude, p.longitude);
          heading = (b + 360) % 360;
        }
      }
    }

    notifier.value = LocationData(
      lat: p.latitude,
      lng: p.longitude,
      speedKmh: kmh,
      heading: heading,
      hasFix: fix,
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
    notifier.dispose();
  }
}
