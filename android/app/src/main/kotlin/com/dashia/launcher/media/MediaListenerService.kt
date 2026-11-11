package com.dashia.launcher.media

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * Bildirim erişimi verildiğinde sistem bu servisi bağlar ve çalan medyayı iki kaynaktan okur:
 *
 * 1. MediaSession: Spotify, YouTube Music, radyo ve MediaSession açan Bluetooth uygulamaları.
 *    Tüm aktif oturumlar izlenir; en son çalmaya başlayan oturum seçilir.
 * 2. Broadcast: MediaSession açmayan multimedya Bluetooth müzik uygulamalarının yaydığı
 *    standart "metachanged / playstatechanged" ve AVRCP yayınları.
 *
 * Ayrıca Ayarlar → Medya → Tanılama ekranı için canlı teşhis verisi tutar.
 */
class MediaListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "DashiaMedia"

        // Gizli AOSP AVRCP Controller yayınları (Android 6-8 ve bazı üretici yazılımları).
        private const val AVRCP_TRACK_EVENT = "android.bluetooth.avrcp-controller.profile.action.TRACK_EVENT"
        private const val AVRCP_EXTRA_METADATA = "android.bluetooth.avrcp-controller.profile.extra.METADATA"
        private const val AVRCP_EXTRA_PLAYBACK = "android.bluetooth.avrcp-controller.profile.extra.PLAYBACK"

        /** Bluetooth müzik uygulamalarının ve oynatıcıların yaydığı bilinen medya yayınları. */
        private val BROADCAST_ACTIONS = listOf(
            AVRCP_TRACK_EVENT,
            "com.android.music.metachanged",
            "com.android.music.playstatechanged",
            "com.android.music.playbackcomplete",
            "com.android.music.queuechanged",
            "com.android.bluetooth.metachanged",
            "com.android.bluetooth.playstatechanged",
            "com.android.btmusic.metachanged",
            "com.android.btmusic.playstatechanged",
            "android.bluetooth.music.metachanged",
            "android.bluetooth.music.playstatechanged",
            "com.htc.music.metachanged",
            "com.htc.music.playstatechanged",
            "com.sec.android.app.music.metachanged",
            "com.sec.android.app.music.playstatechanged",
            "com.miui.player.metachanged",
            "com.miui.player.playstatechanged",
            "com.samsung.sec.android.MusicPlayer.metachanged",
            "com.samsung.sec.android.MusicPlayer.playstatechanged",
            "com.fyt.launcher.music",
            "com.fyt.systemui.remove",
            "titlesReceiver",
            "removeReceiver",
        )

        private val TITLE_KEYS = listOf("track", "title", "TRACK", "TITLE", "music_title", "songName", "song_name", "song", "trackName", "track_name", "name", "id3_title")
        private val ARTIST_KEYS = listOf("artist", "ARTIST", "play_artist", "music_artist", "artistName", "artist_name", "singer", "id3_artist")
        private val ALBUM_KEYS = listOf("album", "ALBUM", "play_album", "music_album", "albumName", "album_name", "id3_album")
        private val PLAYING_KEYS = listOf("playing", "isPlaying", "isplaying", "is_playing", "playstate", "play_state", "playState", "state")

        @Volatile var controller: MediaController? = null
        @Volatile var listener: ((Map<String, Any?>) -> Unit)? = null
        @Volatile var lastState: Map<String, Any?> = mapOf("hasSession" to false)

        /** "session" | "fyt" | "broadcast" | "none" */
        @Volatile var activeSource: String = "none"
        /** true ise çalan kaynak broadcast tabanlıdır; kontrol tuşları medya tuşu olarak gönderilir. */
        @Volatile var useMediaKeys: Boolean = false
        @Volatile private var instance: MediaListenerService? = null

        fun isPlaying(c: MediaController?) = c?.playbackState?.state == PlaybackState.STATE_PLAYING

        fun isBluetoothPackage(pkg: String?): Boolean {
            val p = pkg?.lowercase() ?: return false
            return p.contains("bluetooth") || p.contains("a2dp") || p.contains("avrcp") ||
                Regex("(^|\\.)bt(\\.|music|player|$)").containsMatchIn(p)
        }

        fun diagnostics(): Map<String, Any?> =
            instance?.buildDiagnostics() ?: mapOf("connected" to false, "sessions" to emptyList<Any>(), "broadcasts" to emptyList<Any>())

        private fun stateName(s: Int?): String = when (s) {
            PlaybackState.STATE_PLAYING -> "PLAYING"
            PlaybackState.STATE_PAUSED -> "PAUSED"
            PlaybackState.STATE_STOPPED -> "STOPPED"
            PlaybackState.STATE_BUFFERING -> "BUFFERING"
            PlaybackState.STATE_CONNECTING -> "CONNECTING"
            PlaybackState.STATE_NONE -> "NONE"
            PlaybackState.STATE_ERROR -> "ERROR"
            null -> "-"
            else -> "STATE_$s"
        }
    }

    /** Broadcast ile gelen son parça bilgisi. */
    private data class BroadcastTrack(
        val action: String,
        val title: String,
        val artist: String,
        val album: String,
        val playing: Boolean,
        val time: Long,
        val meta: MediaMetadata?,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val retryPublish = Runnable { publish() }

    private var manager: MediaSessionManager? = null
    private val watched = LinkedHashMap<MediaSession.Token, Pair<MediaController, MediaController.Callback>>()
    private val playingSince = HashMap<MediaSession.Token, Long>()
    private val lastActivity = HashMap<MediaSession.Token, Long>()

    private var broadcastTrack: BroadcastTrack? = null
    private val broadcastLog = ArrayDeque<Map<String, Any?>>()
    private var receiverRegistered = false
    private var fytBridge: FytMediaBridge? = null

    private var lastArtKey: String? = null
    private var lastBmpGenId: Int = -1
    private var lastArt: ByteArray? = null

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { list -> sync(list) }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent != null) onMediaBroadcast(intent)
        }
    }

    // ---------------------------------------------------------------- Yaşam döngüsü

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        fytBridge = FytMediaBridge.getInstance(this).also {
            it.onStateChanged = { reevaluate() }
            it.start()
        }
        try {
            manager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            manager?.addOnActiveSessionsChangedListener(sessionsListener, component())
            sync(currentSessions())
        } catch (e: SecurityException) {
            Log.e(TAG, "MediaSession erişimi yok: ${e.message}")
        }
        registerBroadcasts()
    }

    override fun onListenerDisconnected() {
        mainHandler.removeCallbacks(retryPublish)
        try { manager?.removeOnActiveSessionsChangedListener(sessionsListener) } catch (_: Exception) {}
        unregisterBroadcasts()
        watched.values.forEach { (c, cb) -> try { c.unregisterCallback(cb) } catch (_: Exception) {} }
        watched.clear()
        controller = null
        useMediaKeys = false
        if (instance === this) instance = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        unregisterBroadcasts()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun component() = ComponentName(this, MediaListenerService::class.java)

    private fun currentSessions(): List<MediaController>? =
        try { manager?.getActiveSessions(component()) } catch (e: SecurityException) { null }

    // ---------------------------------------------------------------- MediaSession izleme

    /** Aktif oturum listesini izlenenlerle eşitler; her oturuma ayrı geri çağırım bağlar. */
    private fun sync(list: List<MediaController>?) {
        val now = System.currentTimeMillis()
        val incoming = list.orEmpty()
        val tokens = incoming.map { it.sessionToken }.toSet()

        watched.keys.filter { it !in tokens }.forEach { t ->
            watched.remove(t)?.let { (c, cb) -> try { c.unregisterCallback(cb) } catch (_: Exception) {} }
            playingSince.remove(t)
            lastActivity.remove(t)
        }

        for (c in incoming) {
            val t = c.sessionToken
            if (watched.containsKey(t)) continue
            val cb = makeCallback(t)
            try { c.registerCallback(cb, mainHandler) } catch (_: Exception) {}
            watched[t] = c to cb
            lastActivity[t] = now
            if (isPlaying(c)) playingSince[t] = now
        }
        reevaluate()
    }

    private fun makeCallback(token: MediaSession.Token) = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            val now = System.currentTimeMillis()
            lastActivity[token] = now
            if (state?.state == PlaybackState.STATE_PLAYING) {
                if (!playingSince.containsKey(token)) playingSince[token] = now
            } else {
                playingSince.remove(token)
            }
            reevaluate()
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            lastActivity[token] = System.currentTimeMillis()
            if (controller?.sessionToken == token && !useMediaKeys) publish(metadata) else reevaluate()
        }

        override fun onSessionDestroyed() = sync(currentSessions())
    }

    /** En uygun oturumu seçer: en son çalmaya başlayan → mevcut seçim → Bluetooth → ilk oturum. */
    private fun chooseSession(): MediaController? {
        val list = watched.values.map { it.first }
        if (list.isEmpty()) return null
        val playing = list.filter { isPlaying(it) }
        if (playing.isNotEmpty()) {
            return playing.maxByOrNull { playingSince[it.sessionToken] ?: 0L }
        }
        list.firstOrNull { it.sessionToken == controller?.sessionToken }?.let { return it }
        return list.firstOrNull { isBluetoothPackage(it.packageName) } ?: list.first()
    }

    /**
     * MediaSession, FYT (com.syu.ms / com.syu.bt) ve Broadcast kaynakları arasında öncelik seçimi:
     * 1. Aktif çalan bir MediaSession (Spotify, YouTube Music vb.) varsa her zaman MediaSession.
     * 2. FYT Bluetooth (com.syu.ms MODULE_BT=2) aktifse veya çalıyorsa FYT köprüsü.
     * 3. Broadcast kaynağı (diğer multimedyalar / com.syu.music).
     * 4. Duraklatılmış MediaSession.
     */
    private fun reevaluate() {
        val s = chooseSession()
        val sPlaying = isPlaying(s)
        val sm = try { s?.metadata } catch (_: Exception) { null }
        val sTitle = (sm?.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: sm?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: "").trim()
        val b = broadcastTrack?.takeIf { it.title.isNotBlank() }
        val fyt = fytBridge
        val fytActive = fyt != null && fyt.hasActiveTrack
        val fytPriority = fytActive && (fyt!!.isPlaying || fyt.appId == FytMediaBridge.APP_ID_BTAV || s == null)

        val sameAsSession = b != null && sTitle.isNotEmpty() && sTitle.equals(b.title.trim(), ignoreCase = true)

        val src = when {
            sPlaying && (fyt == null || fyt.appId != FytMediaBridge.APP_ID_BTAV || !fyt.isPlaying) -> "session"
            fytPriority -> "fyt"
            sPlaying -> "session"
            b != null && !sameAsSession && (s == null || b.playing) -> "broadcast"
            fytActive -> "fyt"
            s != null -> "session"
            b != null -> "broadcast"
            else -> "none"
        }

        controller = s
        activeSource = src
        useMediaKeys = (src == "broadcast" || src == "fyt")
        publish()
    }

    // ---------------------------------------------------------------- Broadcast kaynağı

    private fun registerBroadcasts() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply { BROADCAST_ACTIONS.forEach { addAction(it) } }
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            receiverRegistered = true
        } catch (e: Exception) {
            Log.w(TAG, "Medya yayınları dinlenemedi: ${e.message}")
        }
    }

    private fun unregisterBroadcasts() {
        if (!receiverRegistered) return
        try { unregisterReceiver(receiver) } catch (_: Exception) {}
        receiverRegistered = false
    }

    private fun onMediaBroadcast(intent: Intent) {
        val action = intent.action ?: return
        val extras: Bundle = try { intent.extras ?: Bundle() } catch (e: Exception) { Bundle() }
        val now = System.currentTimeMillis()

        logBroadcast(action, extras, now)

        val meta = parcel<MediaMetadata>(extras, AVRCP_EXTRA_METADATA)
        val playback = parcel<PlaybackState>(extras, AVRCP_EXTRA_PLAYBACK)

        val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: str(extras, TITLE_KEYS)
        val artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: str(extras, ARTIST_KEYS)
        val album = meta?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: str(extras, ALBUM_KEYS)
        val playing = playback?.let { it.state == PlaybackState.STATE_PLAYING } ?: bool(extras)

        val prev = broadcastTrack
        val sameTrack = title == null || title == prev?.title
        val isComplete = action.endsWith("playbackcomplete")

        broadcastTrack = BroadcastTrack(
            action = action,
            title = title ?: prev?.title ?: "",
            artist = artist ?: (if (sameTrack) prev?.artist else null) ?: "",
            album = album ?: (if (sameTrack) prev?.album else null) ?: "",
            playing = when {
                isComplete -> false
                playing != null -> playing
                title != null && !sameTrack -> true
                else -> prev?.playing ?: true
            },
            time = now,
            meta = meta ?: if (sameTrack) prev?.meta else null,
        )
        reevaluate()
    }

    private fun logBroadcast(action: String, extras: Bundle, time: Long) {
        val values = LinkedHashMap<String, String>()
        try {
            for (k in extras.keySet()) {
                @Suppress("DEPRECATION")
                val v = try { extras.get(k) } catch (e: Exception) { "<?>" }
                values[k] = v?.toString()?.take(120) ?: "null"
            }
        } catch (_: Exception) {}
        broadcastLog.addFirst(mapOf("action" to action, "time" to time, "extras" to values))
        while (broadcastLog.size > 15) broadcastLog.removeLast()
    }

    @Suppress("DEPRECATION")
    private inline fun <reified T> parcel(b: Bundle, key: String): T? =
        try { b.get(key) as? T } catch (e: Exception) { null }

    private fun str(b: Bundle, keys: List<String>): String? {
        for (k in keys) {
            @Suppress("DEPRECATION")
            val v = try { b.get(k) } catch (e: Exception) { null }
            if (v is CharSequence && v.isNotBlank()) return v.toString().trim()
        }
        return null
    }

    private fun bool(b: Bundle): Boolean? {
        for (k in PLAYING_KEYS) {
            @Suppress("DEPRECATION")
            val v = try { b.get(k) } catch (e: Exception) { null } ?: continue
            when (v) {
                is Boolean -> return v
                is Number -> return if (k.contains("state", true)) v.toInt() == PlaybackState.STATE_PLAYING else v.toInt() != 0
                is CharSequence -> {
                    val s = v.toString().lowercase()
                    if (s == "true" || s == "playing" || s == "play") return true
                    if (s == "false" || s == "paused" || s == "pause" || s == "stopped") return false
                }
            }
        }
        return null
    }

    // ---------------------------------------------------------------- Flutter'a yayın

    private fun publish(overrideMeta: MediaMetadata? = null) {
        val b = broadcastTrack
        val c = controller
        val fyt = fytBridge
        val state: Map<String, Any?> = when {
            activeSource == "fyt" && fyt != null -> {
                val fytTitle = fyt.title.ifBlank { fyt.phoneName.ifBlank { "Bluetooth Müzik" } }
                val fytArtist = fyt.artist.ifBlank { fyt.phoneName }
                mapOf(
                    "hasSession" to true,
                    "title" to fytTitle,
                    "artist" to fytArtist,
                    "album" to fyt.album,
                    "isPlaying" to fyt.isPlaying,
                    "packageName" to "com.syu.bt",
                    "albumArt" to null,
                )
            }
            activeSource == "broadcast" && b != null -> {
                val artBytes = art(b.meta, "bc|${b.title}|${b.artist}|${b.album}")
                mapOf(
                    "hasSession" to true,
                    "title" to b.title,
                    "artist" to b.artist,
                    "album" to b.album,
                    "isPlaying" to b.playing,
                    "packageName" to "broadcast:${b.action}",
                    "albumArt" to artBytes,
                )
            }
            c == null -> mapOf("hasSession" to false)
            else -> {
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
        }
        lastState = state
        listener?.invoke(state)
    }

    // ---------------------------------------------------------------- Tanılama

    private fun buildDiagnostics(): Map<String, Any?> {
        val sessions = watched.values.map { (c, _) ->
            val m = try { c.metadata } catch (e: Exception) { null }
            mapOf(
                "package" to c.packageName,
                "state" to stateName(c.playbackState?.state),
                "title" to (m?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""),
                "artist" to (m?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""),
                "selected" to (activeSource == "session" && c.sessionToken == controller?.sessionToken),
                "bluetooth" to isBluetoothPackage(c.packageName),
            )
        }
        val b = broadcastTrack
        return mapOf(
            "connected" to true,
            "receiver" to receiverRegistered,
            "source" to activeSource,
            "fyt" to fytBridge?.diagnostics(),
            "sessions" to sessions,
            "broadcastTrack" to b?.let {
                mapOf("action" to it.action, "title" to it.title, "artist" to it.artist, "playing" to it.playing, "time" to it.time)
            },
            "broadcasts" to broadcastLog.toList(),
        )
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
            // Aynı şarkıdaysak ve kapak daha önce yüklendiyse mevcut kapağı koru
            if (key == lastArtKey && lastArt != null) {
                return lastArt
            }
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
