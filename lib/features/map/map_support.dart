import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Maps SDK'nın bu cihazda/derlemede kullanılabilirliği.
class MapSupport {
  final bool hasPlayServices;
  final bool hasKey;
  const MapSupport({required this.hasPlayServices, required this.hasKey});

  bool get googleReady => hasPlayServices && hasKey;

  String? get problem {
    if (!hasPlayServices) return 'Bu cihazda Google Play Hizmetleri yok';
    if (!hasKey) return 'Derlemede Maps API anahtarı tanımlı değil';
    return null;
  }

  static const _channel = MethodChannel('com.dashia.launcher/apps');
  static Future<MapSupport>? _cached;

  static Future<MapSupport> check() => _cached ??= _load();

  static Future<MapSupport> _load() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('mapsInfo');
      return MapSupport(hasPlayServices: m?['playServices'] == true, hasKey: m?['hasKey'] == true);
    } catch (e) {
      debugPrint('mapsInfo alınamadı: $e');
      return const MapSupport(hasPlayServices: false, hasKey: false);
    }
  }
}
