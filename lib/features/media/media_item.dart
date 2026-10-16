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

  const MediaItem({
    required this.title,
    required this.artist,
    this.album = '',
    this.isPlaying = false,
    this.hasSession = false,
    this.packageName,
    this.albumArt,
  });

  static const MediaItem empty = MediaItem(title: 'Medya oynatılmıyor', artist: 'Bir müzik uygulaması başlatın');
}
