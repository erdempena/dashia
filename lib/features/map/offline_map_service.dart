import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

/// Türkiye şehir önayarları (Çevrimdışı harita indirme için hızlı seçim).
class CityPreset {
  final String name;
  final double lat;
  final double lng;
  const CityPreset(this.name, this.lat, this.lng);
}

const kCityPresets = <CityPreset>[
  CityPreset('İstanbul', 41.0082, 28.9784),
  CityPreset('Ankara', 39.9208, 32.8541),
  CityPreset('İzmir', 38.4237, 27.1428),
  CityPreset('Bursa', 40.1885, 29.0610),
  CityPreset('Antalya', 36.8969, 30.7133),
  CityPreset('Adana', 37.0000, 35.3213),
  CityPreset('Konya', 37.8746, 32.4932),
  CityPreset('Gaziantep', 37.0662, 37.3833),
  CityPreset('Kocaeli', 40.7654, 29.9408),
  CityPreset('Mersin', 36.8121, 34.6415),
  CityPreset('Kayseri', 38.7312, 35.4787),
  CityPreset('Eskişehir', 39.7767, 30.5206),
  CityPreset('Samsun', 41.2867, 36.3300),
  CityPreset('Trabzon', 41.0027, 39.7168),
  CityPreset('Diyarbakır', 37.9144, 40.2306),
  CityPreset('Sakarya', 40.7731, 30.3948),
  CityPreset('Denizli', 37.7765, 29.0864),
  CityPreset('Muğla', 37.2153, 28.3636),
  CityPreset('Çanakkale', 40.1553, 26.4142),
  CityPreset('Erzurum', 39.9043, 41.2679),
];

/// İndirilmiş bir harita bölgesinin bilgisi.
class DownloadedRegion {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusKm;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final String dateIso;

  const DownloadedRegion({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.dateIso,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'tileCount': tileCount,
        'dateIso': dateIso,
      };

  factory DownloadedRegion.fromJson(Map<String, dynamic> j) => DownloadedRegion(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Bölge',
        lat: (j['lat'] as num?)?.toDouble() ?? 41.0082,
        lng: (j['lng'] as num?)?.toDouble() ?? 28.9784,
        radiusKm: (j['radiusKm'] as num?)?.toDouble() ?? 10,
        minZoom: (j['minZoom'] as num?)?.toInt() ?? 10,
        maxZoom: (j['maxZoom'] as num?)?.toInt() ?? 15,
        tileCount: (j['tileCount'] as num?)?.toInt() ?? 0,
        dateIso: j['dateIso'] as String? ?? '',
      );
}

/// Çevrimdışı OpenStreetMap yöneticisi ve karo indiricisi.
class OfflineMapManager extends ChangeNotifier {
  OfflineMapManager._();
  static final OfflineMapManager instance = OfflineMapManager._();

  static const _ch = MethodChannel('com.dashia.launcher/apps');
  static const _userAgent = 'DashiaCarLauncher/1.0 (https://github.com/dashia/launcher)';

  Directory? _tilesDir;
  List<DownloadedRegion> _regions = [];
  int _cachedFilesCount = 0;
  int _cachedBytes = 0;

  bool _isDownloading = false;
  bool _cancelRequested = false;
  String _activeRegionName = '';
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  int _failedTiles = 0;
  String? _statusMessage;

  List<DownloadedRegion> get regions => List.unmodifiable(_regions);
  int get cachedFilesCount => _cachedFilesCount;
  double get cachedSizeMb => _cachedBytes / (1024 * 1024);
  bool get isDownloading => _isDownloading;
  String get activeRegionName => _activeRegionName;
  int get downloadedTiles => _downloadedTiles;
  int get totalTiles => _totalTiles;
  int get failedTiles => _failedTiles;
  String? get statusMessage => _statusMessage;
  double get progress => _totalTiles == 0 ? 0 : (_downloadedTiles / _totalTiles).clamp(0.0, 1.0);

  /// Uygulama dizininde `osm_tiles` klasörünü hazırlar.
  Future<Directory> ensureTilesDir() async {
    if (_tilesDir != null) return _tilesDir!;
    String? basePath;
    try {
      basePath = await _ch.invokeMethod<String>('getFilesDir');
    } catch (_) {}
    basePath ??= Directory.systemTemp.path;
    final dir = Directory('$basePath/osm_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _tilesDir = dir;
    await _loadMetadata();
    unawaited(refreshStorageStats());
    return dir;
  }

  File tileFileSync(String baseDir, int z, int x, int y) => File('$baseDir/$z/$x/$y.png');

  Future<File> getTileFile(int z, int x, int y) async {
    final dir = await ensureTilesDir();
    return File('${dir.path}/$z/$x/$y.png');
  }

  Future<void> _loadMetadata() async {
    try {
      final dir = _tilesDir;
      if (dir == null) return;
      final metaFile = File('${dir.path}/regions.json');
      if (await metaFile.exists()) {
        final raw = jsonDecode(await metaFile.readAsString()) as List;
        _regions = raw.map((e) => DownloadedRegion.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveMetadata() async {
    try {
      final dir = await ensureTilesDir();
      final metaFile = File('${dir.path}/regions.json');
      await metaFile.writeAsString(jsonEncode(_regions.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  /// Diskteki toplam çevrimdışı karo sayısını ve boyutunu hesaplar.
  Future<void> refreshStorageStats() async {
    try {
      final dir = await ensureTilesDir();
      if (!await dir.exists()) {
        _cachedFilesCount = 0;
        _cachedBytes = 0;
        notifyListeners();
        return;
      }
      int count = 0;
      int bytes = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.png')) {
          count++;
          try {
            bytes += await entity.length();
          } catch (_) {}
        }
      }
      _cachedFilesCount = count;
      _cachedBytes = bytes;
      notifyListeners();
    } catch (_) {}
  }

  /// Verilen merkez (lat, lng), yarıçap (km) ve zoom aralığı için toplam karo sayısını hesaplar.
  static int estimateTileCount({
    required double lat,
    required double lng,
    required double radiusKm,
    required int minZoom,
    required int maxZoom,
  }) {
    final bbox = _boundingBox(lat, lng, radiusKm);
    int total = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final xMin = _lonToTileX(bbox.minLng, z);
      final xMax = _lonToTileX(bbox.maxLng, z);
      final yMin = _latToTileY(bbox.maxLat, z); // Kuzey enlem daha küçük Y indeksine sahiptir
      final yMax = _latToTileY(bbox.minLat, z);
      total += (xMax - xMin + 1) * (yMax - yMin + 1);
    }
    return total;
  }

  /// Ortalama karo boyutu (~16 KB) üzerinden tahmini MB hesabı.
  static double estimateSizeMb(int tileCount) => (tileCount * 16.0) / 1024.0;

  /// Seçilen bölge için tüm (z, x, y) koordinatlarını üretir.
  static List<({int z, int x, int y})> generateTiles({
    required double lat,
    required double lng,
    required double radiusKm,
    required int minZoom,
    required int maxZoom,
  }) {
    final bbox = _boundingBox(lat, lng, radiusKm);
    final list = <({int z, int x, int y})>[];
    for (int z = minZoom; z <= maxZoom; z++) {
      final xMin = _lonToTileX(bbox.minLng, z);
      final xMax = _lonToTileX(bbox.maxLng, z);
      final yMin = _latToTileY(bbox.maxLat, z);
      final yMax = _latToTileY(bbox.minLat, z);
      for (int x = xMin; x <= xMax; x++) {
        for (int y = yMin; y <= yMax; y++) {
          list.add((z: z, x: x, y: y));
        }
      }
    }
    return list;
  }

  /// Seçilen bölgeyi çevrimdışı kullanım için indirir.
  Future<void> downloadRegion({
    required String name,
    required double lat,
    required double lng,
    required double radiusKm,
    required int minZoom,
    required int maxZoom,
    required String urlTemplate,
  }) async {
    if (_isDownloading) return;
    final dir = await ensureTilesDir();

    final tiles = generateTiles(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    _isDownloading = true;
    _cancelRequested = false;
    _activeRegionName = name;
    _downloadedTiles = 0;
    _failedTiles = 0;
    _totalTiles = tiles.length;
    _statusMessage = '$name bölgesi indiriliyor...';
    notifyListeners();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 15)
      ..userAgent = _userAgent;

    int cursor = 0;
    const concurrency = 4;

    Future<void> worker() async {
      while (!_cancelRequested) {
        final idx = cursor++;
        if (idx >= tiles.length) break;
        final t = tiles[idx];
        final file = File('${dir.path}/${t.z}/${t.x}/${t.y}.png');

        try {
          if (await file.exists() && await file.length() > 64) {
            _downloadedTiles++;
            if (_downloadedTiles % 8 == 0 || _downloadedTiles == _totalTiles) notifyListeners();
            continue;
          }

          const subdomains = ['a', 'b', 'c'];
          final sub = subdomains[(t.x + t.y) % subdomains.length];
          final url = urlTemplate
              .replaceAll('{z}', '${t.z}')
              .replaceAll('{x}', '${t.x}')
              .replaceAll('{y}', '${t.y}')
              .replaceAll('{s}', sub)
              .replaceAll('{r}', '');

          final req = await client.getUrl(Uri.parse(url));
          req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
          final resp = await req.close().timeout(const Duration(seconds: 15));
          if (resp.statusCode == HttpStatus.ok) {
            final bytes = await consolidateHttpClientResponseBytes(resp);
            if (bytes.isNotEmpty) {
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes, flush: false);
            } else {
              _failedTiles++;
            }
          } else {
            await resp.drain<void>();
            _failedTiles++;
          }
        } catch (_) {
          _failedTiles++;
        }

        _downloadedTiles++;
        if (_downloadedTiles % 5 == 0 || _downloadedTiles == _totalTiles) {
          notifyListeners();
        }
      }
    }

    try {
      await Future.wait(List.generate(concurrency, (_) => worker()));
    } finally {
      client.close(force: true);
    }

    final wasCancelled = _cancelRequested;
    _isDownloading = false;
    _cancelRequested = false;

    if (!wasCancelled) {
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      final region = DownloadedRegion(
        id: '${name}_${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_${radiusKm.round()}_$maxZoom',
        name: name,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        minZoom: minZoom,
        maxZoom: maxZoom,
        tileCount: tiles.length,
        dateIso: dateStr,
      );
      _regions.removeWhere((r) => r.id == region.id);
      _regions.insert(0, region);
      await _saveMetadata();
      _statusMessage = _failedTiles == 0
          ? '$name bölgesi başarıyla indirildi (${tiles.length} karo).'
          : '$name tamamlandı (${tiles.length - _failedTiles} indirildi, $_failedTiles başarısız).';
    } else {
      _statusMessage = 'İndirme durduruldu ($_downloadedTiles / $_totalTiles karo tamamlandı).';
    }

    await refreshStorageStats();
    notifyListeners();
  }

  void cancelDownload() {
    if (_isDownloading) {
      _cancelRequested = true;
      _statusMessage = 'İndirme durduruluyor...';
      notifyListeners();
    }
  }

  /// Kayıtlı bir bölgeyi listeden kaldırır.
  Future<void> removeRegionRecord(String id) async {
    _regions.removeWhere((r) => r.id == id);
    await _saveMetadata();
    notifyListeners();
  }

  /// Tüm indirilmiş çevrimdışı harita karolarını temizler.
  Future<void> clearAllTiles() async {
    if (_isDownloading) return;
    try {
      final dir = await ensureTilesDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      _regions.clear();
      _cachedFilesCount = 0;
      _cachedBytes = 0;
      _statusMessage = 'Tüm çevrimdışı harita verileri temizlendi.';
      notifyListeners();
    } catch (_) {}
  }

  static ({double minLat, double maxLat, double minLng, double maxLng}) _boundingBox(
    double lat,
    double lng,
    double radiusKm,
  ) {
    final dLat = radiusKm / 110.574;
    final cosLat = math.cos(lat * math.pi / 180.0).abs().clamp(0.05, 1.0);
    final dLng = radiusKm / (111.320 * cosLat);
    return (
      minLat: (lat - dLat).clamp(-85.0, 85.0),
      maxLat: (lat + dLat).clamp(-85.0, 85.0),
      minLng: (lng - dLng).clamp(-179.9, 179.9),
      maxLng: (lng + dLng).clamp(-179.9, 179.9),
    );
  }

  static int _lonToTileX(double lon, int z) {
    final n = 1 << z;
    return (((lon + 180.0) / 360.0) * n).floor().clamp(0, n - 1);
  }

  static int _latToTileY(double lat, int z) {
    final n = 1 << z;
    final latRad = lat * math.pi / 180.0;
    final y = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n;
    return y.floor().clamp(0, n - 1);
  }
}

/// Önce yerel diskteki (`osm_tiles/{z}/{x}/{y}.png`) çevrimdışı karoları okuyan,
/// diskte yoksa internetten indirip diske kaydeden ve internet yokken çökmeden çalışan TileProvider.
class OfflineTileProvider extends TileProvider {
  OfflineTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _OfflineTileImageProvider(
      url: url,
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
    );
  }
}

@immutable
class _OfflineTileImageProvider extends ImageProvider<_OfflineTileImageProvider> {
  final String url;
  final int z;
  final int x;
  final int y;

  const _OfflineTileImageProvider({
    required this.url,
    required this.z,
    required this.x,
    required this.y,
  });

  @override
  Future<_OfflineTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_OfflineTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_OfflineTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'OfflineTile($z/$x/$y)',
    );
  }

  Future<ui.Codec> _loadAsync(_OfflineTileImageProvider key, ImageDecoderCallback decode) async {
    Future<ui.Codec> decodeBytes(Uint8List bytes) async {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    try {
      // 1. Önce yerel diskte çevrimdışı karo var mı kontrol et
      final file = await OfflineMapManager.instance.getTileFile(z, x, y);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 64) {
          try {
            return await decodeBytes(bytes);
          } catch (_) {
            // Bozuk dosya ise silip ağdan dene
            unawaited(file.delete().catchError((_) => file));
          }
        }
      }

      // 2. Diskte yoksa internetten çek ve çevrimdışı önbelleğe yaz
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.userAgentHeader, 'DashiaCarLauncher/1.0 (com.dashia.launcher)');
        final resp = await req.close().timeout(const Duration(seconds: 10));
        if (resp.statusCode == HttpStatus.ok) {
          final bytes = await consolidateHttpClientResponseBytes(resp);
          if (bytes.length > 64) {
            unawaited(() async {
              try {
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes, flush: false);
              } catch (_) {}
            }());
            return await decodeBytes(bytes);
          }
        } else {
          await resp.drain<void>();
        }
      } finally {
        client.close(force: false);
      }
    } catch (_) {
      // Çevrimdışıyken ve karo diskte yokken hata fırlatma
    }

    // Karo bulunamadıysa bellek önbelleğinden çıkar (sonra tekrar denenebilsin) ve şeffaf karo döndür
    scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    return decodeBytes(TileProvider.transparentImage);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _OfflineTileImageProvider && other.z == z && other.x == x && other.y == y && other.url == url);

  @override
  int get hashCode => Object.hash(z, x, y, url);
}
