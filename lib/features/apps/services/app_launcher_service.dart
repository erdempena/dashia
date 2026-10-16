import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppInfo {
  final String label;
  final String package;
  const AppInfo(this.label, this.package);
}

/// Yüklü uygulamaları listeler, başlatır, ikonlarını getirir ve özel simge/font seçicileri açar.
class AppLauncherService {
  static const _channel = MethodChannel('com.dashia.launcher/apps');

  List<AppInfo>? _apps;
  final Map<String, Future<Uint8List?>> _icons = {};

  Future<bool> launch(String package) async {
    try {
      return (await _channel.invokeMethod<bool>('launchApp', {'packageName': package})) ?? false;
    } catch (e) {
      debugPrint('Uygulama açılamadı ($package): $e');
      return false;
    }
  }

  Future<List<AppInfo>> installedApps({bool refresh = false}) async {
    if (_apps != null && !refresh) return _apps!;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
      final list = raw
          .map((e) => AppInfo((e as Map)['label'] as String? ?? '', e['packageName'] as String? ?? ''))
          .where((a) => a.package.isNotEmpty)
          .toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      return _apps = list;
    } catch (e) {
      debugPrint('Uygulama listesi alınamadı: $e');
      return _apps = const [];
    }
  }

  Future<Uint8List?> icon(String package) {
    if (_icons.length > 150) _icons.remove(_icons.keys.first); // bellek sınırı
    return _icons.putIfAbsent(package, () async {
      try {
        return await _channel.invokeMethod<Uint8List>('getAppIcon', {'packageName': package});
      } catch (_) {
        return null;
      }
    });
  }

  /// Galeriden / dosya yöneticisinden özel bir simge resmi seçer ve yerel dosya yolunu döndürür.
  Future<String?> pickCustomIcon() async {
    try {
      return await _channel.invokeMethod<String>('pickCustomIcon');
    } catch (e) {
      debugPrint('Özel simge seçilemedi: $e');
      return null;
    }
  }

  /// Cihazdan .ttf / .otf yazı tipi dosyası seçer ve {path, name} döndürür.
  Future<({String path, String name})?> pickFontFile() async {
    try {
      final res = await _channel.invokeMapMethod<String, String>('pickFontFile');
      if (res == null) return null;
      final path = res['path'];
      final name = res['name'] ?? 'Özel Font';
      if (path == null || path.isEmpty) return null;
      return (path: path, name: name);
    } catch (e) {
      debugPrint('Yazı tipi seçilemedi: $e');
      return null;
    }
  }

  Future<void> openHomeSettings() async {
    try {
      await _channel.invokeMethod('openHomeSettings');
    } catch (e) {
      debugPrint('Ana ekran ayarı açılamadı: $e');
    }
  }
}
