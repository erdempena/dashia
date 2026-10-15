package com.dashia.launcher.media

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * Bildirim erişimi verildiğinde sistem bu servisi bağlar; aktif MediaSession'ları
 * (Spotify, YouTube Music, radyo, A2DP...) dinleyip Flutter'a iletir.
 */
class MediaListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "DashiaMedia"

        @Volatile var controller: MediaController? = null
        @Volatile var listener: ((Map<String, Any?>) -> Unit)? = null
        @Volatile var lastState: Map<String, Any?> = mapOf("hasSession" to false)

        fun isPlaying(c: MediaController?) = c?.playbackState?.state == PlaybackState.STATE_PLAYING
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val retryPublish = Runnable { publish() }

    private var manager: MediaSessionManager? = null
    private var registered: MediaController? = null
    private var lastArtKey: String? = null
    private var lastBmpGenId: Int = -1
    private var lastArt: ByteArray? = null

    private val callback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            publish()
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            publish(metadata)
        }

        override fun onSessionDestroyed() = pick(currentSessions())
    }

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { list -> pick(list) }

    override fun onListenerConnected() {
        super.onListenerConnected()
        try {
            manager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            manager?.addOnActiveSessionsChangedListener(sessionsListener, component())
            pick(currentSessions())
        } catch (e: SecurityException) {
            Log.e(TAG, "MediaSession erişimi yok: ${e.message}")
        }
    }

    override fun onListenerDisconnected() {
        mainHandler.removeCallbacks(retryPublish)
        try { manager?.removeOnActiveSessionsChangedListener(sessionsListener) } catch (_: Exception) {}
        registered?.unregisterCallback(callback)
        registered = null
        controller = null
        super.onListenerDisconnected()
    }

    private fun component() = ComponentName(this, MediaListenerService::class.java)

    private fun currentSessions(): List<MediaController>? =
        try { manager?.getActiveSessions(component()) } catch (e: SecurityException) { null }

    private fun pick(list: List<MediaController>?) {
        val best = list?.firstOrNull { isPlaying(it) } ?: list?.firstOrNull()
        if (best?.sessionToken != registered?.sessionToken) {
            registered?.unregisterCallback(callback)
            registered = best
            lastArtKey = null
            lastBmpGenId = -1
            lastArt = null
            best?.registerCallback(callback)
        }
        controller = best
        publish()
    }

    private fun publish(overrideMeta: MediaMetadata? = null) {
        val c = controller
        val state: Map<String, Any?> = if (c == null) {
            mapOf("hasSession" to false)
        } else {
            val m = overrideMeta ?: c.metadata
            val title = m?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: m?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                ?: ""
            val artist = m?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: m?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                ?: m?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
                ?: ""
            val album = m?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
            val artBytes = art(m, "${c.packageName}|$title|$artist|$album")

            // Şarkı yeni değiştiğinde bazı oynatıcılar (Spotify vb.) kapak resmini 200-800ms gecikmeli yükler.
            // Kapak henüz null ise kısa süre sonra otomatik yeniden kontrol et.
            if (artBytes == null && title.isNotEmpty()) {
                mainHandler.removeCallbacks(retryPublish)
                mainHandler.postDelayed(retryPublish, 400)
                mainHandler.postDelayed(retryPublish, 1100)
            }

            mapOf(
                "hasSession" to true,
                "title" to title,
                "artist" to artist,
                "album" to album,
                "isPlaying" to isPlaying(c),
                "packageName" to c.packageName,
                "albumArt" to artBytes,
            )
        }
        lastState = state
        listener?.invoke(state)
    }

    /**
     * Albüm kapağını 300px JPEG'e küçültür.
     * ÖNEMLİ: Kapak henüz yüklenmediyse (null) önbelleğe null kaydetmez; böylece kapak
     * birkaç yüz milisaniye sonra geldiğinde anında yakalanır ve ekranda güncellenir.
     */
    private fun art(m: MediaMetadata?, key: String): ByteArray? {
        if (m == null) return null
        val bmp = m.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: m.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: m.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)

        if (bmp == null) {
            // Yeni şarkıya geçildiyse eski şarkının kapağını temizle ama anahtarı kilitleme
            if (key != lastArtKey) {
                lastArtKey = null
                lastBmpGenId = -1
                lastArt = null
            }
            return null
        }

        val genId = bmp.generationId
        if (key == lastArtKey && genId == lastBmpGenId && lastArt != null) {
            return lastArt
        }

        return try {
            val maxDim = maxOf(bmp.width, bmp.height).coerceAtLeast(1)
            val scale = 300f / maxDim
            val scaled = if (scale < 1f) {
                Bitmap.createScaledBitmap(
                    bmp,
                    (bmp.width * scale).toInt().coerceAtLeast(1),
                    (bmp.height * scale).toInt().coerceAtLeast(1),
                    true
                )
            } else {
                bmp
            }
            val bytes = ByteArrayOutputStream().also { o ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 84, o)
            }.toByteArray()
            lastArtKey = key
            lastBmpGenId = genId
            lastArt = bytes
            bytes
        } catch (e: Exception) {
            Log.w(TAG, "Kapak dönüştürülemedi: ${e.message}")
            null
        }
    }
}
