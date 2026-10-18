import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../media/media_item.dart';
import '../../../media/services/media_service.dart';
import '../../../settings/settings_service.dart';

/// Müzik kontrol kartı. Alan genişse yatay, darsa dikey yerleşir.
class MediaWidget extends StatelessWidget {
  final SettingsService settings;
  final MediaService media;
  const MediaWidget({super.key, required this.settings, required this.media});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: c.card(),
      padding: const EdgeInsets.all(14),
      child: ValueListenableBuilder<MediaItem>(
        valueListenable: media.current,
        builder: (context, m, _) => LayoutBuilder(builder: (context, box) {
          final tr = settings.tr;
          final horizontal = box.maxWidth > box.maxHeight * 1.5;
          final art = settings.showAlbumArt ? _Art(m: m, size: horizontal ? box.maxHeight.clamp(60.0, 180.0) : (box.maxWidth - 8).clamp(60.0, 170.0)) : null;
          final info = _Info(m: m, settings: settings, center: !horizontal);
          final controls = _Controls(m: m, media: media, compact: box.maxWidth < 300);
          final access = ValueListenableBuilder<bool>(
            valueListenable: media.hasAccess,
            builder: (context, ok, _) => ok || m.hasSession
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton.icon(
                      onPressed: media.openAccessSettings,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(tr.grantNotifBtn),
                    ),
                  ),
          );
          if (horizontal) {
            return Row(children: [
              if (art != null) ...[art, const SizedBox(width: 16)],
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  info,
                  const SizedBox(height: 12),
                  controls,
                  access,
                ]),
              ),
            ]);
          }
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: (box.maxWidth).clamp(120.0, 600.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (art != null) ...[art, const SizedBox(height: 10)],
                  info,
                  const SizedBox(height: 10),
                  controls,
                  access,
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final MediaItem m;
  final double size;
  const _Art({required this.m, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bytes = m.albumArt;
    return ClipRRect(
      borderRadius: BorderRadius.circular(c.radius),
      child: Container(
        width: size,
        height: size,
        color: c.surfaceAlt,
        child: bytes != null && bytes.isNotEmpty
            ? Image.memory(
                bytes,
                key: ValueKey('${m.title}|${m.artist}|${bytes.length}|${bytes[0]}|${bytes[bytes.length - 1]}'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 300,
              )
            : Icon(Icons.music_note_rounded, size: size * 0.45, color: c.accent),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final MediaItem m;
  final SettingsService settings;
  final bool center;
  const _Info({required this.m, required this.settings, required this.center});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tr = settings.tr;
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final ta = center ? TextAlign.center : TextAlign.start;
    final title = (!m.hasSession || m.title == 'Müzik bekleniyor') ? tr.waitingMediaTitle : m.title;
    final artist = (!m.hasSession || m.artist == 'Bir medya oynatıcı başlatın') ? tr.waitingMediaArtist : m.artist;
    return Column(crossAxisAlignment: align, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: ta, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
      const SizedBox(height: 2),
      Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: ta, style: TextStyle(fontSize: 16, color: c.textMuted)),
    ]);
  }
}

class _Controls extends StatelessWidget {
  final MediaItem m;
  final MediaService media;
  final bool compact;
  const _Controls({required this.m, required this.media, required this.compact});

  @override
  Widget build(BuildContext context) {
    final w = compact ? 52.0 : 62.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(icon: Icons.skip_previous_rounded, width: w, onTap: media.skipPrevious),
      const SizedBox(width: 10),
      _Btn(icon: m.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, width: w + 12, primary: true, onTap: media.togglePlayPause),
      const SizedBox(width: 10),
      _Btn(icon: Icons.skip_next_rounded, width: w, onTap: media.skipNext),
    ]);
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double width;
  final bool primary;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.width, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: primary ? c.accent : c.surfaceAlt,
      borderRadius: BorderRadius.circular(c.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(c.radius),
        onTap: onTap,
        child: SizedBox(width: width, height: 54, child: Icon(icon, size: 32, color: primary ? c.onAccent : c.text)),
      ),
    );
  }
}
