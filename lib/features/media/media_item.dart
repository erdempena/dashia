import 'dart:typed_data';

/// Arka planda çalan müziğin durum ve metadata modeli.
class MediaItem {
  final String title;
  final String artist;
  final String album;
  final bool isPlaying;
  final bool hasSession;
  final String? packageName;
  final Uint8List? albumArt;
  final int positionMs;
  final int durationMs;
  final int updatedAtMs;
  final bool canSeek;

  const MediaItem({
    required this.title,
    required this.artist,
    this.album = '',
    this.isPlaying = false,
    this.hasSession = false,
    this.packageName,
    this.albumArt,
    this.positionMs = 0,
    this.durationMs = 0,
    this.updatedAtMs = 0,
    this.canSeek = false,
  });

  static const MediaItem empty = MediaItem(title: 'Medya oynatılmıyor', artist: 'Bir müzik uygulaması başlatın');
}
