package pers.cyh128.hikari_novel_plus

import android.content.Intent
import android.content.pm.PackageManager
import android.view.KeyEvent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val intentChannelName = "hikari/system_intents"
    private val volumeKeyChannelName = "hikari/volume_keys"

    private var volumeKeySink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, intentChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTtsSettings" -> {
                        try {
                            val candidates = arrayListOf(
                                Intent("android.speech.tts.engine.TTS_SETTINGS"),
                                Intent("com.android.settings.TTS_SETTINGS"),
                                Intent(android.provider.Settings.ACTION_SETTINGS)
                            )
                            var launched = false
                            var lastErr: Exception? = null
                            for (it in candidates) {
                                try {
                                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(it)
                                    launched = true
                                    break
                                } catch (e: Exception) {
                                    lastErr = e
                                }
                            }
                            if (launched) {
                                result.success(true)
                            } else {
                                result.error(
                                    "INTENT_FAILED",
                                    lastErr?.message ?: "no activity found",
                                    null
                                )
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    "openApp" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrBlank()) {
                            result.error("ARG_ERROR", "package is null/blank", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val pm: PackageManager = applicationContext.packageManager
                            val launchIntent = pm.getLaunchIntentForPackage(pkg)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.error("NOT_FOUND", "app not found: $pkg", null)
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, volumeKeyChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeKeySink = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeKeySink = null
                }
            })
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeKeySink?.success("volumeUp")
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeKeySink?.success("volumeDown")
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
