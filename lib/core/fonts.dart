import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Seçilebilir yazı tipleri. 'system' = cihazın varsayılanı (Roboto).
/// Poppins / Barlow / Rajdhani / Titillium Web uygulama içinde paketlidir (OFL lisanslı).
/// 'custom' = kullanıcının cihazdan yüklediği .ttf / .otf yazı tipi.
class AppFont {
  static const String customKey = 'custom';
  static const String customFamily = 'DashiaCustomFont';

  final String key;
  final String label;
  final String? family;
  const AppFont(this.key, this.label, this.family);

  static const all = <AppFont>[
    AppFont('system', 'Sistem', null),
    AppFont('poppins', 'Poppins', 'Poppins'),
    AppFont('barlow', 'Barlow', 'Barlow'),
    AppFont('rajdhani', 'Rajdhani', 'Rajdhani'),
    AppFont('titillium', 'Titillium', 'TitilliumWeb'),
    AppFont('serif', 'Serif', 'serif'),
    AppFont('mono', 'Mono', 'monospace'),
  ];

  static AppFont byKey(String key, {String? customName}) {
    if (key == customKey) {
      return AppFont(customKey, customName ?? 'Özel Font', customFamily);
    }
    return all.firstWhere((f) => f.key == key, orElse: () => all.first);
  }

  /// Kullanıcının seçtiği .ttf / .otf dosyasını çalışma zamanında Flutter motoruna yükler.
  static Future<bool> loadCustomFont(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      if (bytes.length < 128) return false;
      final loader = FontLoader(customFamily);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return true;
    } catch (e) {
      debugPrint('Özel yazı tipi yüklenemedi ($path): $e');
      return false;
    }
  }
}
