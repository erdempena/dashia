import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fonts.dart';
import '../../core/i18n/app_strings.dart';

/// Ana ekranda yer alabilecek bileşen türleri. [none] = alan boş/gizli.
enum DashWidget { clock, speed, media, map, none }

extension DashWidgetX on DashWidget {
  String get title => switch (this) {
        DashWidget.clock => 'Saat & Tarih',
        DashWidget.speed => 'Hız Göstergesi',
        DashWidget.media => 'Müzik Kontrol',
        DashWidget.map => 'Harita',
        DashWidget.none => 'Boş',
      };
  String get description => switch (this) {
        DashWidget.clock => 'Dijital saat ve tarih',
        DashWidget.speed => 'GPS tabanlı anlık hız kadranı',
        DashWidget.media => 'Çalan parça ve oynatma kontrolleri',
        DashWidget.map => 'Anlık konum (OpenStreetMap / Google)',
        DashWidget.none => 'Bu alanı gizle, diğerleri genişlesin',
      };
}

/// Hızlı erişim kısayolu yapılandırması (ikon + isim + uygulama).
class ShortcutConfig {
  final String id;
  final String label;
  /// 'app' = uygulamanın kendi ikonu, 'file:/path/...' = galeriden özel simge, aksi halde IconRegistry anahtarı.
  final String iconKey;
  final String? package;

  const ShortcutConfig({
    required this.id,
    required this.label,
    required this.iconKey,
    this.package,
  });

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'icon': iconKey, 'package': package};

  factory ShortcutConfig.fromJson(Map<String, dynamic> j) => ShortcutConfig(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        iconKey: j['icon'] as String? ?? 'apps',
        package: j['package'] as String?,
      );
}

class SettingsService extends ChangeNotifier {
  static const int maxShortcuts = 6;
  static const String defaultOsmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  late SharedPreferences _prefs;

  // Dil & Görünüm
  String language = 'tr'; // tr | en | de | fr | es | ru
  AppStrings get tr => AppStrings(language);
  String uiStyle = 'classic'; // classic | material
  String themeMode = 'dark'; // dark | amoled | light
  int accent = 0xFF00D2FF;
  double radius = 14;
  bool fullscreen = true;
  String fontFamily = 'system';
  String? customFontPath;
  String? customFontName;
  double fontScale = 1.0;

  // Saat
  bool use24h = true;
  bool showSeconds = false;
  bool showDate = true;

  // Hız
  String speedUnit = 'kmh'; // kmh | mph
  int maxSpeed = 200;

  // Harita
  String mapProvider = 'osm'; // osm | google
  String googleMapType = 'roadmap'; // roadmap | satellite | terrain | hybrid
  String osmUrl = defaultOsmUrl;
  bool mapDark = true;
  /// OSM harita teması: 'light' (Açık), 'dark' (Koyu), 'amoled' (AMOLED Tam Siyah), 'midnight' (Gece Mavisi), 'warm' (Sıcak Gece)
  String osmTheme = 'dark';
  double mapZoom = 16;
  bool mapRotate = false;
  bool mapShowSpeed = true;

  // Medya
  bool showAlbumArt = true;

  // Düzen: [sol-üst, sol-alt, sağ-ana]
  List<DashWidget> slots = [DashWidget.clock, DashWidget.media, DashWidget.map];
  double leftFrac = 0.30; // sol sütunun genişlik oranı
  double leftSplit = 0.30; // sol sütunda üst alanın yükseklik oranı
  double barHeight = 78; // alt kısayol çubuğu yüksekliği
  bool showResizeHandles = true; // ana ekranda dokunmatik boyutlandırma çubuklarını göster/gizle
  List<ShortcutConfig> shortcuts = defaultShortcuts();

  static List<ShortcutConfig> defaultShortcuts() => const [
        ShortcutConfig(id: 's1', label: 'Navigasyon', iconKey: 'navigation', package: 'com.google.android.apps.maps'),
        ShortcutConfig(id: 's2', label: 'Müzik', iconKey: 'music', package: 'com.spotify.music'),
        ShortcutConfig(id: 's3', label: 'Radyo', iconKey: 'radio', package: 'com.android.fmradio'),
        ShortcutConfig(id: 's4', label: 'Telefon', iconKey: 'phone', package: 'com.android.dialer'),
      ];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('settings_v1');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      language = j['language'] as String? ?? language;
      uiStyle = j['uiStyle'] ?? uiStyle;
      themeMode = j['themeMode'] ?? themeMode;
      accent = j['accent'] ?? accent;
      radius = (j['radius'] ?? radius).toDouble();
      fullscreen = j['fullscreen'] ?? fullscreen;
      fontFamily = j['fontFamily'] ?? fontFamily;
      customFontPath = j['customFontPath'] as String?;
      customFontName = j['customFontName'] as String?;
      fontScale = (j['fontScale'] ?? fontScale).toDouble();
      use24h = j['use24h'] ?? use24h;
      showSeconds = j['showSeconds'] ?? showSeconds;
      showDate = j['showDate'] ?? showDate;
      speedUnit = j['speedUnit'] ?? speedUnit;
      maxSpeed = j['maxSpeed'] ?? maxSpeed;
      mapProvider = j['mapProvider'] ?? mapProvider;
      googleMapType = j['googleMapType'] ?? googleMapType;
      osmUrl = j['osmUrl'] ?? osmUrl;
      mapDark = j['mapDark'] ?? mapDark;
      osmTheme = j['osmTheme'] as String? ?? (mapDark ? 'dark' : 'light');
      mapDark = osmTheme != 'light';
      mapZoom = (j['mapZoom'] ?? mapZoom).toDouble();
      mapRotate = j['mapRotate'] ?? mapRotate;
      mapShowSpeed = j['mapShowSpeed'] ?? mapShowSpeed;
      showAlbumArt = j['showAlbumArt'] ?? showAlbumArt;
      leftFrac = ((j['leftFrac'] ?? leftFrac) as num).toDouble().clamp(0.2, 0.6);
      leftSplit = ((j['leftSplit'] ?? leftSplit) as num).toDouble().clamp(0.15, 0.75);
      barHeight = ((j['barHeight'] ?? barHeight) as num).toDouble().clamp(60, 120);
      showResizeHandles = j['showResizeHandles'] as bool? ?? showResizeHandles;
      final s = (j['slots'] as List?)?.map((e) => DashWidget.values.byName(e as String)).toList();
      if (s != null && s.length == 3) {
        final real = s.where((e) => e != DashWidget.none).toList();
        if (real.toSet().length == real.length) slots = s;
      }
      final sc = (j['shortcuts'] as List?)?.map((e) => ShortcutConfig.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (sc != null) shortcuts = sc.take(maxShortcuts).toList();

      if (customFontPath != null) {
        final ok = await AppFont.loadCustomFont(customFontPath);
        if (!ok && fontFamily == AppFont.customKey) {
          fontFamily = 'system';
        }
      }
    } catch (e) {
      debugPrint('Ayarlar okunamadı, varsayılanlar kullanılıyor: $e');
    }
  }

  Map<String, dynamic> _toJson() => {
        'language': language,
        'uiStyle': uiStyle,
        'themeMode': themeMode,
        'accent': accent,
        'radius': radius,
        'fullscreen': fullscreen,
        'fontFamily': fontFamily,
        'customFontPath': customFontPath,
        'customFontName': customFontName,
        'fontScale': fontScale,
        'use24h': use24h,
        'showSeconds': showSeconds,
        'showDate': showDate,
        'speedUnit': speedUnit,
        'maxSpeed': maxSpeed,
        'mapProvider': mapProvider,
        'googleMapType': googleMapType,
        'osmUrl': osmUrl,
        'mapDark': mapDark,
        'osmTheme': osmTheme,
        'mapZoom': mapZoom,
        'mapRotate': mapRotate,
        'mapShowSpeed': mapShowSpeed,
        'showAlbumArt': showAlbumArt,
        'slots': slots.map((e) => e.name).toList(),
        'leftFrac': leftFrac,
        'leftSplit': leftSplit,
        'barHeight': barHeight,
        'showResizeHandles': showResizeHandles,
        'shortcuts': shortcuts.map((e) => e.toJson()).toList(),
      };

  /// Değişikliği uygular, kaydeder ve dinleyenleri bilgilendirir.
  void update(VoidCallback change) {
    change();
    save();
    notifyListeners();
  }

  /// Sürükleme gibi sık değişimlerde: yalnızca arayüzü günceller (kaydetmez).
  void updateLive(VoidCallback change) {
    change();
    notifyListeners();
  }

  void save() => _prefs.setString('settings_v1', jsonEncode(_toJson()));

  /// [widget] bileşenini [slot] alanına yerleştirir; o bileşen başka alandaysa yer değiştirir.
  void placeWidget(int slot, DashWidget widget) {
    update(() {
      final list = List<DashWidget>.from(slots);
      if (widget != DashWidget.none) {
        final other = list.indexOf(widget);
        if (other >= 0) list[other] = list[slot];
      }
      list[slot] = widget;
      slots = list;
    });
  }

  void saveShortcut(ShortcutConfig s) {
    update(() {
      final i = shortcuts.indexWhere((e) => e.id == s.id);
      final list = List<ShortcutConfig>.from(shortcuts);
      if (i >= 0) {
        list[i] = s;
      } else if (list.length < maxShortcuts) {
        list.add(s);
      }
      shortcuts = list;
    });
  }

  void removeShortcut(String id) => update(() => shortcuts = shortcuts.where((e) => e.id != id).toList());

  void moveShortcut(int from, int to) {
    update(() {
      final list = List<ShortcutConfig>.from(shortcuts);
      final item = list.removeAt(from);
      list.insert(to.clamp(0, list.length), item);
      shortcuts = list;
    });
  }

  void resetLayout() => update(() {
        slots = [DashWidget.clock, DashWidget.media, DashWidget.map];
        leftFrac = 0.30;
        leftSplit = 0.30;
        barHeight = 78;
      });
  void resetShortcuts() => update(() => shortcuts = defaultShortcuts());

  String newShortcutId() => 's${DateTime.now().microsecondsSinceEpoch}';
}
