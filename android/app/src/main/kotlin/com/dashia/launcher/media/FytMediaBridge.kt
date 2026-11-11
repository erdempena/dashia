package com.dashia.launcher.media

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Binder
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Parcel
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * FYT / SYU (UIS8581, UIS7862, SC9863a, Sofia) araç multimedya üniteleri için doğrudan
 * `com.syu.ms` (`com.syu.ms.toolkit`) Binder IPC köprüsü.
 *
 * Bu cihazlarda Bluetooth çipi (`BLINK` / `com.syu.bt`) standart Android MediaSession veya
 * genel broadcast yayını AÇMAZ; şarkı adı, sanatçı, albüm ve çalma durumu yalnızca `com.syu.ms`
 * içindeki `IRemoteToolkit -> getRemoteModule(2) (MODULE_BT)` üzerinden `IModuleCallback` ile iletilir.
 */
class FytMediaBridge private constructor(
    private val context: Context,
) {
    @Volatile var onStateChanged: (() -> Unit)? = null
    companion object {
        private const val TAG = "DashiaFytBridge"

        private const val PKG_MS = "com.syu.ms"
        private const val ACTION_TOOLKIT = "com.syu.ms.toolkit"
        private const val CLS_TOOLKIT = "app.ToolkitService"

        private const val DESC_TOOLKIT = "com.syu.ipc.IRemoteToolkit"
        private const val DESC_MODULE = "com.syu.ipc.IRemoteModule"
        private const val DESC_CALLBACK = "com.syu.ipc.IModuleCallback"

        private const val TXN_GET_MODULE = 1       // IRemoteToolkit.getRemoteModule(int)
        private const val TXN_CMD = 1              // IRemoteModule.cmd(int, int[], float[], String[])
        private const val TXN_REGISTER_STD = 3     // IRemoteModule.register (standart 4-metotlu AIDL)
        private const val TXN_UNREGISTER_STD = 4   // IRemoteModule.unregister
        private const val TXN_REGISTER_ALT = 2     // IRemoteModule.register (3-metotlu AIDL varyantı)
        private const val TXN_UPDATE = 1           // IModuleCallback.update(int, int[], float[], String[])

        const val MODULE_MAIN = 0
        const val MODULE_BT = 2

        // FinalMain sabitleri
        const val U_APP_ID = 0
        const val C_APP_ID = 0
        const val APP_ID_BTAV = 3

        // FinalBt güncelleme (U_*) sabitleri
        const val U_BTAV_ID3_TITLE = 0
        const val U_BTAV_ID3_ARTIST = 1
        const val U_BTAV_TOTAL_TIME = 2
        const val U_PHONE_NAME = 7
        const val U_PHONE_STATE = 9
        const val U_BTAV_PLAY_STATE = 13
        const val U_HFP = 18
        const val U_BTAV_ID3_ALBUM = 26
        const val U_BTAV_PLAY_TIME = 28
        const val U_A2DP_SINK_STATE = 34

        // FinalBt komut (C_*) sabitleri
        const val C_BTAV_PREV = 0
        const val C_BTAV_NEXT = 1
        const val C_BTAV_PAUSE = 3
        const val C_BTAV_PLAY = 27
        const val C_MODULE_RAW = 59
        private const val MODULE_QUERY_MUSIC_INFO = "MK"

        private val PHONE_CONNECTED_STATES = setOf(2, 3, 4, 5, 7)
        private val BT_CODES = intArrayOf(
            U_BTAV_ID3_TITLE,
            U_BTAV_ID3_ARTIST,
            U_BTAV_TOTAL_TIME,
            U_PHONE_NAME,
            U_PHONE_STATE,
            U_BTAV_PLAY_STATE,
            U_HFP,
            U_BTAV_ID3_ALBUM,
            U_BTAV_PLAY_TIME,
            U_A2DP_SINK_STATE,
        )
        private val TRACK_CODES = intArrayOf(
            U_BTAV_ID3_TITLE,
            U_BTAV_ID3_ARTIST,
            U_BTAV_ID3_ALBUM,
            U_BTAV_PLAY_STATE,
        )

        @Volatile private var instance: FytMediaBridge? = null

        fun getInstance(context: Context): FytMediaBridge {
            return instance ?: synchronized(this) {
                instance ?: FytMediaBridge(context.applicationContext).also { instance = it }
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    @Volatile var serviceBound = false
        private set
    @Volatile var serviceConnected = false
        private set
    @Volatile var btModuleConnected = false
        private set
    @Volatile var registerTxnUsed = TXN_REGISTER_STD
        private set
    @Volatile var lastError: String? = null
        private set

    @Volatile var appId: Int = -1
        private set
    @Volatile var title: String = ""
        private set
    @Volatile var artist: String = ""
        private set
    @Volatile var album: String = ""
        private set
    @Volatile var phoneName: String = ""
        private set
    @Volatile var phoneConnected: Boolean = false
        private set
    @Volatile var isPlaying: Boolean = false
        private set
    @Volatile var lastUpdateMs: Long = 0L
        private set

    private var mainModule: IBinder? = null
    private var btModule: IBinder? = null
    private var lastPositionMs = -1
    private var lastPositionAt = 0L
    private var lastMkQueryAt = 0L
    private var callbackCount = 0

    val rawEvents = ConcurrentHashMap<String, String>()

    /** FYT Bluetooth üzerinden geçerli bir medya oturumu var mı? */
    val hasActiveTrack: Boolean
        get() = btModuleConnected && (
            title.isNotBlank() ||
                artist.isNotBlank() ||
                isPlaying ||
                appId == APP_ID_BTAV ||
                (phoneConnected && phoneName.isNotBlank() && isPlaying)
            )

    private val mainCallback = makeCallback("main") { code, ints, _ ->
        val i0 = ints?.firstOrNull() ?: return@makeCallback
        if (code == U_APP_ID) {
            val prev = appId
            appId = i0
            if (i0 == APP_ID_BTAV && prev != APP_ID_BTAV) {
                scheduleTrackRefresh()
            }
            handler.post { onStateChanged?.invoke() }
        }
    }

    private val btCallback = makeCallback("bt") { code, ints, strs ->
        val i0 = ints?.firstOrNull()
        val s0 = strs?.firstOrNull()?.trim()
        var changed = false

        when (code) {
            U_BTAV_ID3_TITLE -> {
                val newTitle = s0.orEmpty()
                if (newTitle != title) {
                    title = newTitle
                    lastUpdateMs = System.currentTimeMillis()
                    changed = true
                }
            }
            U_BTAV_ID3_ARTIST -> {
                val newArtist = s0.orEmpty()
                if (newArtist != artist) {
                    artist = newArtist
                    lastUpdateMs = System.currentTimeMillis()
                    changed = true
                }
            }
            U_BTAV_ID3_ALBUM -> {
                val newAlbum = s0.orEmpty()
                if (newAlbum != album) {
                    album = newAlbum
                    changed = true
                }
            }
            U_BTAV_PLAY_STATE -> if (i0 != null) {
                val nowPlaying = i0 == 1
                if (nowPlaying != isPlaying) {
                    isPlaying = nowPlaying
                    lastUpdateMs = System.currentTimeMillis()
                    changed = true
                }
                if (nowPlaying && title.isBlank()) {
                    handler.post { queryMusicInfoIfNeeded() }
                }
            }
            U_BTAV_PLAY_TIME -> if (i0 != null) {
                val now = SystemClock.elapsedRealtime()
                val advancing = lastPositionMs in 0 until i0 && (now - lastPositionAt) < 2600L
                lastPositionMs = i0
                lastPositionAt = now
                if (advancing && !isPlaying) {
                    isPlaying = true
                    lastUpdateMs = System.currentTimeMillis()
                    changed = true
                }
                if (advancing && title.isBlank()) {
                    handler.post { queryMusicInfoIfNeeded() }
                }
            }
            U_PHONE_STATE -> if (i0 != null) {
                val connected = i0 in PHONE_CONNECTED_STATES
                if (connected != phoneConnected) {
                    phoneConnected = connected
                    if (!connected) {
                        isPlaying = false
                        title = ""
                        artist = ""
                        album = ""
                    } else {
                        scheduleTrackRefresh()
                    }
                    changed = true
                }
            }
            U_PHONE_NAME -> {
                val name = if (strs != null && strs.size >= 2 && strs[0]?.toIntOrNull() in 0..1) {
                    strs[1]?.trim().orEmpty()
                } else {
                    s0.orEmpty()
                }
                if (name.isNotEmpty() && name != phoneName) {
                    phoneName = name
                    changed = true
                }
            }
        }

        if (changed) {
            handler.post { onStateChanged?.invoke() }
        }
    }

    private fun makeCallback(
        prefix: String,
        onUpdate: (code: Int, ints: IntArray?, strs: Array<String?>?) -> Unit,
    ): Binder = object : Binder() {
        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            return when (code) {
                TXN_UPDATE -> {
                    try {
                        data.enforceInterface(DESC_CALLBACK)
                        val updateCode = data.readInt()
                        val ints = data.createIntArray()
                        data.createFloatArray()
                        val strs = data.createStringArray()
                        callbackCount++
                        rawEvents["$prefix.$updateCode"] =
                            "ints=${ints?.contentToString() ?: "[]"} strs=${strs?.contentToString() ?: "[]"}"
                        onUpdate(updateCode, ints, strs)
                    } catch (e: Exception) {
                        lastError = "onTransact($prefix): ${e.message}"
                    }
                    true
                }
                INTERFACE_TRANSACTION -> {
                    reply?.writeString(DESC_CALLBACK)
                    true
                }
                else -> super.onTransact(code, data, reply, flags)
            }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            if (service == null) return
            serviceConnected = true
            lastError = null
            Thread {
                try {
                    mainModule = getRemoteModule(service, MODULE_MAIN)
                    btModule = getRemoteModule(service, MODULE_BT)
                    btModuleConnected = btModule != null

                    val beforeCount = callbackCount
                    mainModule?.let { registerCode(it, mainCallback, U_APP_ID, 1, TXN_REGISTER_STD) }
                    btModule?.let { mod ->
                        for (c in BT_CODES) {
                            registerCode(mod, btCallback, c, 1, TXN_REGISTER_STD)
                        }
                    }

                    // Bazı FYT derlemelerinde IRemoteModule içinde get() metodu bulunmaz ve register txn=2 olur.
                    // 450ms içinde hiçbir geri çağırım gelmediyse txn=2 ile de kayıt dene.
                    Thread.sleep(450)
                    if (callbackCount == beforeCount) {
                        registerTxnUsed = TXN_REGISTER_ALT
                        mainModule?.let { registerCode(it, mainCallback, U_APP_ID, 1, TXN_REGISTER_ALT) }
                        btModule?.let { mod ->
                            for (c in BT_CODES) {
                                registerCode(mod, btCallback, c, 1, TXN_REGISTER_ALT)
                            }
                        }
                    }

                    handler.post {
                        queryMusicInfoIfNeeded()
                        scheduleTrackRefresh()
                        onStateChanged?.invoke()
                    }
                } catch (e: Exception) {
                    lastError = "connect: ${e.javaClass.simpleName}: ${e.message}"
                    Log.w(TAG, "FYT bağlantı hatası: $lastError")
                }
            }.start()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            serviceConnected = false
            btModuleConnected = false
            mainModule = null
            btModule = null
            handler.post { onStateChanged?.invoke() }
        }
    }

    fun start() {
        if (serviceBound) return
        try {
            val intent = Intent(ACTION_TOOLKIT).setPackage(PKG_MS)
            var ok = context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
            if (!ok) {
                val explicit = Intent(ACTION_TOOLKIT).setComponent(ComponentName(PKG_MS, CLS_TOOLKIT))
                ok = context.bindService(explicit, connection, Context.BIND_AUTO_CREATE)
            }
            serviceBound = ok
        } catch (e: Exception) {
            lastError = "bind: ${e.message}"
        }
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        if (serviceBound) {
            try { context.unbindService(connection) } catch (_: Exception) {}
            serviceBound = false
        }
        serviceConnected = false
        btModuleConnected = false
        mainModule = null
        btModule = null
    }

    // ---------------------------------------------------------------- Kontrol Komutları

    fun togglePlayPause(): Boolean {
        return if (isPlaying) pause() else play()
    }

    fun play(): Boolean {
        val ok = sendBtCmd(C_BTAV_PLAY)
        if (ok) {
            isPlaying = true
            handler.post { onStateChanged?.invoke() }
            scheduleTrackRefresh()
        }
        return ok
    }

    fun pause(): Boolean {
        val ok = sendBtCmd(C_BTAV_PAUSE)
        if (ok) {
            isPlaying = false
            handler.post { onStateChanged?.invoke() }
        }
        return ok
    }

    fun skipNext(): Boolean {
        val ok = sendBtCmd(C_BTAV_NEXT)
        if (ok) scheduleTrackRefresh()
        return ok
    }

    fun skipPrevious(): Boolean {
        val ok = sendBtCmd(C_BTAV_PREV)
        if (ok) scheduleTrackRefresh()
        return ok
    }

    private fun queryMusicInfoIfNeeded() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastMkQueryAt < 4000L) return
        lastMkQueryAt = now
        sendBtCmd(C_MODULE_RAW, strs = arrayOf(MODULE_QUERY_MUSIC_INFO))
    }

    private val refreshRunnable = Runnable {
        val mod = btModule ?: return@Runnable
        Thread {
            for (c in TRACK_CODES) {
                unregisterCode(mod, btCallback, c)
                registerCode(mod, btCallback, c, 1, registerTxnUsed)
            }
        }.start()
    }

    private fun scheduleTrackRefresh() {
        handler.removeCallbacks(refreshRunnable)
        handler.postDelayed(refreshRunnable, 1200L)
        handler.postDelayed(refreshRunnable, 3500L)
    }

    // ---------------------------------------------------------------- Düşük Seviye Binder İşlemleri

    private fun getRemoteModule(toolkit: IBinder, moduleCode: Int): IBinder? {
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        return try {
            data.writeInterfaceToken(DESC_TOOLKIT)
            data.writeInt(moduleCode)
            toolkit.transact(TXN_GET_MODULE, data, reply, 0)
            reply.readException()
            reply.readStrongBinder()
        } catch (e: Exception) {
            lastError = "getModule($moduleCode): ${e.message}"
            null
        } finally {
            reply.recycle()
            data.recycle()
        }
    }

    private fun registerCode(module: IBinder, cb: Binder, code: Int, update: Int, txn: Int) {
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            data.writeInterfaceToken(DESC_MODULE)
            data.writeStrongBinder(cb)
            data.writeInt(code)
            data.writeInt(update)
            module.transact(txn, data, reply, 0)
            reply.readException()
        } catch (e: Exception) {
            lastError = "reg($code,txn=$txn): ${e.message}"
        } finally {
            reply.recycle()
            data.recycle()
        }
    }

    private fun unregisterCode(module: IBinder, cb: Binder, code: Int) {
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        try {
            data.writeInterfaceToken(DESC_MODULE)
            data.writeStrongBinder(cb)
            data.writeInt(code)
            val unregTxn = if (registerTxnUsed == TXN_REGISTER_ALT) 3 else TXN_UNREGISTER_STD
            module.transact(unregTxn, data, reply, 0)
            reply.readException()
        } catch (_: Exception) {
        } finally {
            reply.recycle()
            data.recycle()
        }
    }

    private fun sendBtCmd(cmdCode: Int, ints: IntArray? = null, strs: Array<String>? = null): Boolean {
        val mod = btModule ?: return false
        val data = Parcel.obtain()
        val reply = Parcel.obtain()
        return try {
            data.writeInterfaceToken(DESC_MODULE)
            data.writeInt(cmdCode)
            data.writeIntArray(ints)
            data.writeFloatArray(null)
            data.writeStringArray(strs)
            mod.transact(TXN_CMD, data, reply, 0)
            reply.readException()
            true
        } catch (e: Exception) {
            lastError = "cmd($cmdCode): ${e.message}"
            false
        } finally {
            reply.recycle()
            data.recycle()
        }
    }

    fun diagnostics(): Map<String, Any?> = mapOf(
        "bound" to serviceBound,
        "connected" to serviceConnected,
        "btModule" to btModuleConnected,
        "txn" to registerTxnUsed,
        "appId" to appId,
        "phoneConnected" to phoneConnected,
        "phoneName" to phoneName,
        "playing" to isPlaying,
        "title" to title,
        "artist" to artist,
        "album" to album,
        "callbacks" to callbackCount,
        "error" to lastError,
        "raw" to rawEvents.toMap(),
    )
}
