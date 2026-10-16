import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../media_item.dart';

/// Android MediaSession (Spotify, YouTube Music, radyo, A2DP...) köprüsü.
class MediaService {
  static const _method = MethodChannel('com.dashia.launcher/media');
  static const _events = EventChannel('com.dashia.launcher/media_stream');

  final ValueNotifier<MediaItem> current = ValueNotifier(MediaItem.empty);
  final ValueNotifier<bool> hasAccess = ValueNotifier(true);
  StreamSubscription<dynamic>? _sub;

  void init() {
    _sub = _events.receiveBroadcastStream().listen((dynamic e) {
      if (e is! Map) return;
      if (e['hasSession'] != true) {
        current.value = MediaItem.empty;
        return;
      }
      current.value = MediaItem(
        title: (e['title'] as String?)?.trim().isNotEmpty == true ? e['title'] as String : 'Bilinmeyen parça',
        artist: (e['artist'] as String?) ?? '',
        album: (e['album'] as String?) ?? '',
        isPlaying: e['isPlaying'] == true,
        hasSession: true,
        packageName: e['packageName'] as String?,
        albumArt: e['albumArt'] as Uint8List?,
      );
    }, onError: (Object e) => debugPrint('Medya akışı hatası: $e'));
    refreshAccess();
  }

  Future<void> refreshAccess() async {
    try {
      hasAccess.value = (await _method.invokeMethod<bool>('isListenerEnabled')) ?? false;
    } catch (_) {}
  }

  Future<void> openAccessSettings() async {
    try {
      await _method.invokeMethod('openListenerSettings');
    } catch (e) {
      debugPrint('Bildirim erişimi ayarı açılamadı: $e');
    }
  }

  Future<void> _call(String m) async {
    try {
      await _method.invokeMethod(m);
    } catch (e) {
      debugPrint('Medya komutu başarısız ($m): $e');
    }
  }

  Future<void> togglePlayPause() => _call('togglePlayPause');
  Future<void> skipNext() => _call('skipNext');
  Future<void> skipPrevious() => _call('skipPrevious');

  void dispose() {
    _sub?.cancel();
    current.dispose();
    hasAccess.dispose();
  }
}
