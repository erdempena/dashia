package com.dashia.launcher

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.KeyEvent
import com.dashia.launcher.media.MediaListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQ_PICK_ICON = 9001
        private const val REQ_PICK_FONT = 9002
    }

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var pendingIconResult: MethodChannel.Result? = null
    private var pendingFontResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ---------- Uygulamalar & Dosya Seçiciler ----------
        MethodChannel(messenger, "com.dashia.launcher/apps").setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    val pkg = call.argument<String>("packageName")
                    val intent = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                    if (intent != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try { startActivity(intent); result.success(true) } catch (e: Exception) { result.success(false) }
                    } else result.success(false)
                }
                "getInstalledApps" -> io.execute {
                    val q = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                    val list = packageManager.queryIntentActivities(q, 0)
                        .filter { it.activityInfo.packageName != packageName }
                        .distinctBy { it.activityInfo.packageName }
                        .map { mapOf("label" to it.loadLabel(packageManager).toString(), "packageName" to it.activityInfo.packageName) }
                    main.post { result.success(list) }
                }
                "getAppIcon" -> {
                    val pkg = call.argument<String>("packageName")
                    io.execute {
                        val bytes = try { iconBytes(pkg!!) } catch (e: Exception) { null }
                        main.post { result.success(bytes) }
                    }
                }
                "mapsInfo" -> {
                    val gms = try { packageManager.getPackageInfo("com.google.android.gms", 0); true } catch (e: Exception) { false }
                    val key = try {
                        packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
                            .metaData?.getString("com.google.android.geo.API_KEY") ?: ""
                    } catch (e: Exception) { "" }
                    result.success(mapOf("playServices" to gms, "hasKey" to key.isNotBlank()))
                }
                "getFilesDir" -> result.success(filesDir.absolutePath)
                "pickCustomIcon" -> {
                    pendingIconResult?.success(null)
                    pendingIconResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Simge Resmi Seçin"), REQ_PICK_ICON)
                    } catch (e: Exception) {
                        pendingIconResult = null
                        result.success(null)
                    }
                }
                "pickFontFile" -> {
                    pendingFontResult?.success(null)
                    pendingFontResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Yazı Tipi (.ttf / .otf) Seçin"), REQ_PICK_FONT)
                    } catch (e: Exception) {
                        pendingFontResult = null
                        result.success(null)
                    }
                }
                "openHomeSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_HOME_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        try { startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); result.success(true) }
                        catch (e2: Exception) { result.success(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ---------- Medya kontrol ----------
        MethodChannel(messenger, "com.dashia.launcher/media").setMethodCallHandler { call, result ->
            when (call.method) {
                "togglePlayPause" -> { control(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE) { c ->
                    if (MediaListenerService.isPlaying(c)) c.transportControls.pause() else c.transportControls.play() }; result.success(true) }
                "skipNext" -> { control(KeyEvent.KEYCODE_MEDIA_NEXT) { it.transportControls.skipToNext() }; result.success(true) }
                "skipPrevious" -> { control(KeyEvent.KEYCODE_MEDIA_PREVIOUS) { it.transportControls.skipToPrevious() }; result.success(true) }
                "isListenerEnabled" -> result.success(isListenerEnabled())
                "openListenerSettings" -> {
                    try {
                        startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }

        // ---------- Medya durum akışı ----------
        EventChannel(messenger, "com.dashia.launcher/media_stream").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                MediaListenerService.listener = { state -> main.post { sink.success(state) } }
                sink.success(MediaListenerService.lastState)
            }
            override fun onCancel(args: Any?) { MediaListenerService.listener = null }
        })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_ICON) {
            val res = pendingIconResult
            pendingIconResult = null
            if (res == null) return
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                res.success(null)
                return
            }
            io.execute {
                val savedPath = saveCustomIcon(uri)
                main.post { res.success(savedPath) }
            }
        } else if (requestCode == REQ_PICK_FONT) {
            val res = pendingFontResult
            pendingFontResult = null
            if (res == null) return
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null) {
                res.success(null)
                return
            }
            io.execute {
                val savedFont = saveCustomFont(uri)
                main.post { res.success(savedFont) }
            }
        }
    }

    private fun saveCustomIcon(uri: Uri): String? {
        return try {
            val raw = contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return null
            val maxDim = maxOf(raw.width, raw.height).coerceAtLeast(1)
            val scale = (256f / maxDim).coerceAtMost(1f)
            val w = (raw.width * scale).toInt().coerceAtLeast(1)
            val h = (raw.height * scale).toInt().coerceAtLeast(1)
            val scaled = if (scale < 1f) Bitmap.createScaledBitmap(raw, w, h, true) else raw
            val dir = File(filesDir, "custom_icons").apply { mkdirs() }
            val file = File(dir, "icon_${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { out ->
                scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun saveCustomFont(uri: Uri): Map<String, String>? {
        return try {
            var fileName = "OzelFont.ttf"
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) {
                    val n = cursor.getString(idx)
                    if (!n.isNullOrBlank()) fileName = n
                }
            }
            val lower = fileName.lowercase()
            if (!lower.endsWith(".ttf") && !lower.endsWith(".otf")) {
                fileName = "$fileName.ttf"
            }
            val displayName = fileName.substringBeforeLast('.').replace('_', ' ').replace('-', ' ').trim().ifEmpty { "Özel Font" }
            val dir = File(filesDir, "custom_fonts").apply { mkdirs() }
            val dest = File(dir, "font_${System.currentTimeMillis()}_${fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")}")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            if (dest.length() < 128) {
                dest.delete()
                return null
            }
            mapOf("path" to dest.absolutePath, "name" to displayName)
        } catch (e: Exception) {
            null
        }
    }

    /** Aktif oturum varsa doğrudan onu kontrol eder; yoksa medya tuşu gönderir. */
    private fun control(keyCode: Int, action: (android.media.session.MediaController) -> Unit) {
        val c = MediaListenerService.controller
        if (c != null) { action(c); return }
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val me = ComponentName(this, MediaListenerService::class.java)
        return flat.split(":").any { ComponentName.unflattenFromString(it) == me }
    }

    private fun iconBytes(pkg: String): ByteArray {
        val d = packageManager.getApplicationIcon(pkg)
        val size = 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(canvas)
        return ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }
}
