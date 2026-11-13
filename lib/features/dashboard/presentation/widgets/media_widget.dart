import 'dart:async';
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
      decoration: c.minimalist ? const BoxDecoration() : c.card(),
      padding: EdgeInsets.all(c.minimalist ? 10 : 14),
      child: ValueListenableBuilder<MediaItem>(
        valueListenable: media.current,
        builder: (context, m, _) => LayoutBuilder(builder: (context, box) {
          final tr = settings.tr;
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

          if (c.minimalist) {
            return _MinimalistMedia(
              m: m,
              settings: settings,
              media: media,
              box: box,
              access: access,
            );
          }

          final horizontal = box.maxWidth > box.maxHeight * 1.5;
          final art = settings.showAlbumArt ? _Art(m: m, size: horizontal ? box.maxHeight.clamp(60.0, 180.0) : (box.maxWidth - 8).clamp(60.0, 170.0)) : null;
          final info = _Info(m: m, settings: settings, center: !horizontal);
          final controls = _Controls(m: m, media: media, compact: box.maxWidth < 300, scale: settings.mediaControlScale);
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

/// Çerçevesiz minimalist medya görünümü.
class _MinimalistMedia extends StatelessWidget {
  final MediaItem m;
  final SettingsService settings;
  final MediaService media;
  final BoxConstraints box;
  final Widget access;

  const _MinimalistMedia({
    required this.m,
    required this.settings,
    required this.media,
    required this.box,
    required this.access,
  });

  bool get _isBt {
    final p = (m.packageName ?? '').toLowerCase();
    return p == 'com.syu.bt' ||
        p.contains('bluetooth') ||
        p.contains('a2dp') ||
        p.contains('avrcp') ||
        p.contains('btmusic') ||
        p.contains('.bt');
  }

  String get _sourceLabel {
    if (!m.hasSession) return 'Medya';
    if (_isBt) return 'Bluetooth';
    final p = (m.packageName ?? '').toLowerCase();
    if (p.contains('spotify')) return 'Spotify';
    if (p.contains('youtube')) return 'YouTube Music';
    if (p.contains('poweramp')) return 'Poweramp';
    if (p.contains('aimp')) return 'AIMP';
    if (p.contains('radio') || p.contains('fm')) return 'Radyo';
    return 'Medya';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tr = settings.tr;
    final title = (!m.hasSession || m.title == 'Müzik bekleniyor') ? tr.waitingMediaTitle : m.title;
    final artist = (!m.hasSession || m.artist == 'Bir medya oynatıcı başlatın') ? tr.waitingMediaArtist : m.artist;
    final artSize = (box.maxHeight * 0.42).clamp(60.0, 114.0);
    final circleBg = c.isLight ? const Color(0xFF0F172A) : Colors.white;
    final circleFg = c.isLight ? Colors.white : const Color(0xFF0F1114);
    final btnScale = settings.mediaControlScale.clamp(0.8, 1.6);
    final skipIconSize = (34.0 * btnScale).clamp(26.0, 56.0);
    final skipHitSize = (46.0 * btnScale).clamp(38.0, 72.0);
    final playBtnSize = (50.0 * btnScale).clamp(40.0, 78.0);
    final playIconSize = (30.0 * btnScale).clamp(24.0, 48.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst: Sol Kapak + Sağda Kaynak Rozeti, Şarkı Adı ve Sanatçı
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (settings.showAlbumArt) ...[
              _Art(m: m, size: artSize),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.text.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.text.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBt ? Icons.bluetooth_rounded : Icons.music_note_rounded,
                          size: 13,
                          color: c.accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text.withValues(alpha: 0.85)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.text, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Orta: Canlı İlerleme Çubuğu (Bluetooth için düz temaya uygun çubuk, diğerleri için dokunmatik & süre takipli)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _MediaProgressBar(
            m: m,
            media: media,
            isBt: _isBt,
            circleBg: circleBg,
          ),
        ),

        // Alt: Kutusuz İkonlar + Yuvarlak Beyaz Play/Pause
        Row(
          children: [
            IconButton(
              onPressed: media.skipPrevious,
              icon: Icon(Icons.skip_previous_rounded, size: skipIconSize, color: c.text.withValues(alpha: 0.9)),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: skipHitSize, minHeight: skipHitSize),
            ),
            SizedBox(width: 14 * btnScale),
            Material(
              color: circleBg,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: media.togglePlayPause,
                child: SizedBox(
                  width: playBtnSize,
                  height: playBtnSize,
                  child: Icon(
                    m.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: playIconSize,
                    color: circleFg,
                  ),
                ),
              ),
            ),
            SizedBox(width: 14 * btnScale),
            IconButton(
              onPressed: media.skipNext,
              icon: Icon(Icons.skip_next_rounded, size: skipIconSize, color: c.text.withValues(alpha: 0.9)),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: skipHitSize, minHeight: skipHitSize),
            ),
            const Spacer(),
            access,
          ],
        ),
      ],
    );
  }
}

class _MediaProgressBar extends StatefulWidget {
  final MediaItem m;
  final MediaService media;
  final bool isBt;
  final Color circleBg;

  const _MediaProgressBar({
    required this.m,
    required this.media,
    required this.isBt,
    required this.circleBg,
  });

  @override
  State<_MediaProgressBar> createState() => _MediaProgressBarState();
}

class _MediaProgressBarState extends State<_MediaProgressBar> {
  Timer? _timer;
  double? _dragFrac;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _MediaProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final needsTimer = !widget.isBt && widget.m.hasSession && widget.m.isPlaying && widget.m.durationMs > 0;
    if (needsTimer && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTimer && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _currentPositionMs {
    final m = widget.m;
    if (m.durationMs <= 0) return 0;
    if (_dragFrac != null) {
      return (_dragFrac! * m.durationMs).round().clamp(0, m.durationMs);
    }
    var pos = m.positionMs;
    if (m.isPlaying && m.updatedAtMs > 0) {
      final delta = DateTime.now().millisecondsSinceEpoch - m.updatedAtMs;
      if (delta > 0) pos += delta;
    }
    return pos.clamp(0, m.durationMs);
  }

  String _fmtMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 359999);
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _seekAt(double localX, double maxWidth) {
    if (maxWidth <= 0 || widget.m.durationMs <= 0 || !widget.m.canSeek) return;
    final frac = (localX / maxWidth).clamp(0.0, 1.0);
    final targetMs = (frac * widget.m.durationMs).round();
    setState(() => _dragFrac = null);
    widget.media.seekTo(targetMs);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = widget.m;
    final hasTimeline = !widget.isBt && m.hasSession && m.durationMs > 0;

    // Bluetooth müzik veya süre verisi olmayan kaynak: temaya uygun işlevsiz dümdüz çubuk
    if (!hasTimeline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: m.hasSession ? c.accent.withValues(alpha: 0.55) : c.text.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    final posMs = _currentPositionMs;
    final durMs = m.durationMs;
    final frac = (_dragFrac ?? (posMs / durMs)).clamp(0.0, 1.0);
    final remMs = (durMs - posMs).clamp(0, durMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmtMs(posMs),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted),
            ),
            Text(
              '-${_fmtMs(remMs)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, lineBox) {
            final maxW = lineBox.maxWidth;
            final activeW = maxW * frac;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: m.canSeek ? (d) => _seekAt(d.localPosition.dx, maxW) : null,
              onHorizontalDragStart: m.canSeek
                  ? (d) => setState(() => _dragFrac = (d.localPosition.dx / maxW).clamp(0.0, 1.0))
                  : null,
              onHorizontalDragUpdate: m.canSeek
                  ? (d) => setState(() => _dragFrac = (d.localPosition.dx / maxW).clamp(0.0, 1.0))
                  : null,
              onHorizontalDragEnd: m.canSeek
                  ? (_) {
                      final f = _dragFrac;
                      if (f != null) {
                        setState(() => _dragFrac = null);
                        widget.media.seekTo((f * durMs).round());
                      }
                    }
                  : null,
              child: SizedBox(
                height: 18,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: c.text.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      height: 4,
                      width: activeW,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: (activeW - 6).clamp(0.0, (maxW - 12).clamp(0.0, double.infinity)),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: widget.circleBg,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Art extends StatelessWidget {
  final MediaItem m;
  final double size;
  const _Art({required this.m, required this.size});

  bool get _isBluetooth {
    final p = (m.packageName ?? '').toLowerCase();
    return p == 'com.syu.bt' ||
        p.contains('bluetooth') ||
        p.contains('a2dp') ||
        p.contains('avrcp') ||
        p.contains('btmusic') ||
        p.contains('.bt');
  }

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
            : _isBluetooth
                ? _BtVinylIcon(size: size)
                : Icon(Icons.music_note_rounded, size: size * 0.45, color: c.accent),
      ),
    );
  }
}

/// Seçenek 4: Plak & Bluetooth (Bluetooth bağlıyken kapak yoksa gösterilen simge).
class _BtVinylIcon extends StatelessWidget {
  final double size;
  const _BtVinylIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final discSize = size * 0.76;
    final grooveSize = size * 0.58;
    final centerSize = size * 0.36;
    return Center(
      child: Container(
        width: discSize,
        height: discSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF263042), Color(0xFF141A24), Color(0xFF202938), Color(0xFF0D1118)],
            stops: [0.0, 0.45, 0.72, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: grooveSize,
            height: grooveSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
            ),
            child: Center(
              child: Container(
                width: centerSize,
                height: centerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bluetooth_rounded,
                  size: size * 0.22,
                  color: c.onAccent,
                ),
              ),
            ),
          ),
        ),
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
  final double scale;
  const _Controls({required this.m, required this.media, required this.compact, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final s = scale.clamp(0.8, 1.5);
    final w = (compact ? 52.0 : 62.0) * s;
    final h = 54.0 * s;
    final iconSize = 32.0 * s;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(icon: Icons.skip_previous_rounded, width: w, height: h, iconSize: iconSize, onTap: media.skipPrevious),
      const SizedBox(width: 10),
      _Btn(icon: m.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, width: w + 12 * s, height: h, iconSize: iconSize, primary: true, onTap: media.togglePlayPause),
      const SizedBox(width: 10),
      _Btn(icon: Icons.skip_next_rounded, width: w, height: h, iconSize: iconSize, onTap: media.skipNext),
    ]);
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double width;
  final double height;
  final double iconSize;
  final bool primary;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.width, required this.height, required this.iconSize, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: primary ? c.accent : c.surfaceAlt,
      borderRadius: BorderRadius.circular(c.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(c.radius),
        onTap: onTap,
        child: SizedBox(width: width, height: height, child: Icon(icon, size: iconSize, color: primary ? c.onAccent : c.text)),
      ),
    );
  }
}
