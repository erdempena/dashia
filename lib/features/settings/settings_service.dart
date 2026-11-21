import 'dart:async';
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
        DashWidget.map => 'Anlık konum (OpenStreetMap)',
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
  static const int maxSideShortcuts = 4;
  static const String defaultOsmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String dayNightTogglePackage = 'dashia://day_night_toggle';
  static final ValueNotifier<bool> isDayNotifier = ValueNotifier<bool>(true);

  late SharedPreferences _prefs;

  // Dil & Görünüm
  String language = 'tr'; // tr | en | de | fr | es | ru
  AppStrings get tr => AppStrings(language);
  String uiStyle = 'classic'; // classic | material | minimalist
  String themeMode = 'dark'; // dark | amoled | light
  int accent = 0xFF00D2FF;

  // Gece & Gündüz Otomatik Döngüsü
  bool dayNightAuto = false;
  int dayStartMinutes = 7 * 60; // 07:00
  int nightStartMinutes = 19 * 60; // 19:00
  String dayThemeMode = 'light'; // light | dark | amoled
  String nightThemeMode = 'dark'; // light | dark | amoled
  String dayOsmTheme = 'light'; // light | dark | amoled | midnight | warm
  String nightOsmTheme = 'warm'; // light | dark | amoled | midnight | warm
  bool? dayNightOverrideIsDay;
  int? dayNightOverrideExpiresAtMs;

  Timer? _dayNightTimer;
  bool? _lastIsDayTime;

  /// Şu anki sistem saatinin gündüz aralığında [dayStartMinutes, nightStartMinutes) olup olmadığını döner.
  bool get _scheduledIsDay {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    if (dayStartMinutes == nightStartMinutes) return true;
    if (dayStartMinutes < nightStartMinutes) {
      return cur >= dayStartMinutes && cur < nightStartMinutes;
    } else {
      return cur >= dayStartMinutes || cur < nightStartMinutes;
    }
  }

  bool get _hasValidOverride {
    if (dayNightOverrideIsDay == null) return false;
    if (!dayNightAuto) return true;
    if (dayNightOverrideExpiresAtMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < dayNightOverrideExpiresAtMs!;
  }

  /// Aktif modun Gündüz (true) mi yoksa Gece (false) mi olduğunu döner.
  bool get isDayTime {
    if (_hasValidOverride) return dayNightOverrideIsDay!;
    if (dayNightAuto) return _scheduledIsDay;
    return themeMode == 'light';
  }

  /// Bir sonraki planlı gündüz veya gece geçiş vaktinin milisaniye zaman damgasını hesaplar.
  int _nextTransitionMs(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day);
    final candidates = <DateTime>[
      midnight.add(Duration(minutes: dayStartMinutes)),
      midnight.add(Duration(minutes: nightStartMinutes)),
      midnight.add(Duration(days: 1, minutes: dayStartMinutes)),
      midnight.add(Duration(days: 1, minutes: nightStartMinutes)),
    ].where((dt) => dt.isAfter(now)).toList()
      ..sort();
    return candidates.first.millisecondsSinceEpoch;
  }

  /// Kısayol veya ayarlardan tek tıkla Gece <-> Gündüz modunu değiştirir (sonraki planlı vakte kadar korur).
  void toggleDayNight() {
    final nextIsDay = !isDayTime;
    update(() {
      dayNightOverrideIsDay = nextIsDay;
      dayNightOverrideExpiresAtMs = _nextTransitionMs(DateTime.now());
    });
  }

  /// Döngü veya manuel switch aktifse gündüz/gece uygulama temasını, aksi halde [themeMode] değerini döner.
  String get effectiveThemeMode =>
      (dayNightAuto || _hasValidOverride) ? (isDayTime ? dayThemeMode : nightThemeMode) : themeMode;

  /// Döngü veya manuel switch aktifse gündüz/gece harita temasını, aksi halde [osmTheme] değerini döner.
  String get effectiveOsmTheme =>
      (dayNightAuto || _hasValidOverride) ? (isDayTime ? dayOsmTheme : nightOsmTheme) : osmTheme;

  static String formatMinutes(int totalMinutes) {
    final m = totalMinutes.clamp(0, 24 * 60 - 1);
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final min = (m % 60).toString().padLeft(2, '0');
    return '$h:$min';
  }
  List<int> savedColors = [];
  double radius = 14;
  bool fullscreen = true;
  String fontFamily = 'system';
  String? customFontPath;
  String? customFontName;
  double fontScale = 1.0;

  // Saat & Üst Çubuk
  bool use24h = true;
  bool showSeconds = false;
  bool showDate = true;
  bool clockShowSpeed = false;
  bool showTopBar = false;
  bool topBarShowGps = true;
  bool topBarShowClock = true;
  bool topBarShowDate = false;
  bool topBarShowSpeed = false;

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
  double mediaControlScale = 1.15;

  // Düzen: [sol-üst, sol-alt, sağ-ana]
  List<DashWidget> slots = [DashWidget.clock, DashWidget.media, DashWidget.map];
  double leftFrac = 0.30; // sol sütunun genişlik oranı
  double leftSplit = 0.30; // sol sütunda üst alanın yükseklik oranı
  double barHeight = 78; // alt kısayol çubuğu yüksekliği
  bool showResizeHandles = true; // ana ekranda dokunmatik boyutlandırma çubuklarını göster/gizle
  List<ShortcutConfig> shortcuts = defaultShortcuts();
  List<ShortcutConfig> sideShortcuts = defaultSideShortcuts();
  bool sideShortcutsShowLabels = true;

  static List<ShortcutConfig> defaultShortcuts() => const [
        ShortcutConfig(id: 's1', label: 'Navigasyon', iconKey: 'navigation', package: 'com.google.android.apps.maps'),
        ShortcutConfig(id: 's2', label: 'Müzik', iconKey: 'music', package: 'com.spotify.music'),
        ShortcutConfig(id: 's3', label: 'Radyo', iconKey: 'radio', package: 'com.android.fmradio'),
        ShortcutConfig(id: 's4', label: 'Telefon', iconKey: 'phone', package: 'com.android.dialer'),
      ];

  static List<ShortcutConfig> defaultSideShortcuts() => const [
        ShortcutConfig(id: 'side1', label: 'Navigasyon', iconKey: 'navigation', package: 'com.google.android.apps.maps'),
        ShortcutConfig(id: 'side2', label: 'Müzik', iconKey: 'music', package: 'com.spotify.music'),
        ShortcutConfig(id: 'side3', label: 'Radyo', iconKey: 'radio', package: 'com.android.fmradio'),
        ShortcutConfig(id: 'side4', label: 'Telefon', iconKey: 'phone', package: 'com.android.dialer'),
      ];

  Future<void> load() async {
    _startDayNightWatcher();
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('settings_v1');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      language = j['language'] as String? ?? language;
      uiStyle = j['uiStyle'] ?? uiStyle;
      themeMode = j['themeMode'] ?? themeMode;
      dayNightAuto = j['dayNightAuto'] as bool? ?? dayNightAuto;
      dayStartMinutes = ((j['dayStartMinutes'] ?? dayStartMinutes) as num).toInt().clamp(0, 1439);
      nightStartMinutes = ((j['nightStartMinutes'] ?? nightStartMinutes) as num).toInt().clamp(0, 1439);
      dayThemeMode = j['dayThemeMode'] as String? ?? dayThemeMode;
      nightThemeMode = j['nightThemeMode'] as String? ?? nightThemeMode;
      dayOsmTheme = j['dayOsmTheme'] as String? ?? dayOsmTheme;
      nightOsmTheme = j['nightOsmTheme'] as String? ?? nightOsmTheme;
      dayNightOverrideIsDay = j['dayNightOverrideIsDay'] as bool?;
      dayNightOverrideExpiresAtMs = (j['dayNightOverrideExpiresAtMs'] as num?)?.toInt();
      if (dayNightOverrideExpiresAtMs != null &&
          DateTime.now().millisecondsSinceEpoch >= dayNightOverrideExpiresAtMs!) {
        dayNightOverrideIsDay = null;
        dayNightOverrideExpiresAtMs = null;
      }
      isDayNotifier.value = isDayTime;
      accent = j['accent'] ?? accent;
      savedColors = (j['savedColors'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      radius = (j['radius'] ?? radius).toDouble();
      fullscreen = j['fullscreen'] ?? fullscreen;
      fontFamily = j['fontFamily'] ?? fontFamily;
      customFontPath = j['customFontPath'] as String?;
      customFontName = j['customFontName'] as String?;
      fontScale = (j['fontScale'] ?? fontScale).toDouble();
      use24h = j['use24h'] ?? use24h;
      showSeconds = j['showSeconds'] ?? showSeconds;
      showDate = j['showDate'] ?? showDate;
      clockShowSpeed = j['clockShowSpeed'] ?? clockShowSpeed;
      showTopBar = j['showTopBar'] ?? (uiStyle == 'minimalist');
      topBarShowGps = j['topBarShowGps'] ?? topBarShowGps;
      topBarShowClock = j['topBarShowClock'] ?? topBarShowClock;
      topBarShowDate = j['topBarShowDate'] ?? topBarShowDate;
      topBarShowSpeed = j['topBarShowSpeed'] ?? topBarShowSpeed;
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
      mediaControlScale = ((j['mediaControlScale'] ?? mediaControlScale) as num).toDouble().clamp(0.8, 1.5);
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
      final ssc = (j['sideShortcuts'] as List?)?.map((e) => ShortcutConfig.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (ssc != null) sideShortcuts = ssc.take(maxSideShortcuts).toList();
      sideShortcutsShowLabels = j['sideShortcutsShowLabels'] as bool? ?? sideShortcutsShowLabels;

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

  void _startDayNightWatcher() {
    _dayNightTimer?.cancel();
    _lastIsDayTime = isDayTime;
    isDayNotifier.value = _lastIsDayTime!;
    _dayNightTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (dayNightAuto &&
          dayNightOverrideExpiresAtMs != null &&
          DateTime.now().millisecondsSinceEpoch >= dayNightOverrideExpiresAtMs!) {
        dayNightOverrideIsDay = null;
        dayNightOverrideExpiresAtMs = null;
        save();
      }
      final cur = isDayTime;
      isDayNotifier.value = cur;
      if (_lastIsDayTime != cur) {
        _lastIsDayTime = cur;
        notifyListeners();
      }
    });
  }

  Map<String, dynamic> _toJson() => {
        'language': language,
        'uiStyle': uiStyle,
        'themeMode': themeMode,
        'dayNightAuto': dayNightAuto,
        'dayStartMinutes': dayStartMinutes,
        'nightStartMinutes': nightStartMinutes,
        'dayThemeMode': dayThemeMode,
        'nightThemeMode': nightThemeMode,
        'dayOsmTheme': dayOsmTheme,
        'nightOsmTheme': nightOsmTheme,
        'dayNightOverrideIsDay': dayNightOverrideIsDay,
        'dayNightOverrideExpiresAtMs': dayNightOverrideExpiresAtMs,
        'accent': accent,
        'savedColors': savedColors,
        'radius': radius,
        'fullscreen': fullscreen,
        'fontFamily': fontFamily,
        'customFontPath': customFontPath,
        'customFontName': customFontName,
        'fontScale': fontScale,
        'use24h': use24h,
        'showSeconds': showSeconds,
        'showDate': showDate,
        'clockShowSpeed': clockShowSpeed,
        'showTopBar': showTopBar,
        'topBarShowGps': topBarShowGps,
        'topBarShowClock': topBarShowClock,
        'topBarShowDate': topBarShowDate,
        'topBarShowSpeed': topBarShowSpeed,
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
        'mediaControlScale': mediaControlScale,
        'slots': slots.map((e) => e.name).toList(),
        'leftFrac': leftFrac,
        'leftSplit': leftSplit,
        'barHeight': barHeight,
        'showResizeHandles': showResizeHandles,
        'shortcuts': shortcuts.map((e) => e.toJson()).toList(),
        'sideShortcuts': sideShortcuts.map((e) => e.toJson()).toList(),
        'sideShortcutsShowLabels': sideShortcutsShowLabels,
      };

  /// Değişikliği uygular, kaydeder ve dinleyenleri bilgilendirir.
  void update(VoidCallback change) {
    change();
    _lastIsDayTime = isDayTime;
    isDayNotifier.value = _lastIsDayTime!;
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
  void resetSideShortcuts() => update(() => sideShortcuts = defaultSideShortcuts());

  void saveSideShortcut(ShortcutConfig s) {
    update(() {
      final i = sideShortcuts.indexWhere((e) => e.id == s.id);
      final list = List<ShortcutConfig>.from(sideShortcuts);
      if (i >= 0) {
        list[i] = s;
      } else if (list.length < maxSideShortcuts) {
        list.add(s);
      }
      sideShortcuts = list;
    });
  }

  void removeSideShortcut(String id) => update(() => sideShortcuts = sideShortcuts.where((e) => e.id != id).toList());

  void moveSideShortcut(int from, int to) {
    update(() {
      final list = List<ShortcutConfig>.from(sideShortcuts);
      final item = list.removeAt(from);
      list.insert(to.clamp(0, list.length), item);
      sideShortcuts = list;
    });
  }

  void saveCustomColor(int color) {
    final normalized = 0xFF000000 | (color & 0xFFFFFF);
    update(() {
      accent = normalized;
      if (!savedColors.contains(normalized)) {
        savedColors = [...savedColors, normalized];
      }
    });
  }

  void removeSavedColor(int color) {
    update(() {
      savedColors = savedColors.where((c) => c != color).toList();
    });
  }

  String newShortcutId() => 's${DateTime.now().microsecondsSinceEpoch}';
}
