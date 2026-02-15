package com.fijacks.saacousticble

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

class MainActivity : FlutterActivity() {
    private val channelName = "sa_acoustic_ble/acoustic"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAcousticScan" -> {
                        val now = Instant.now().toString()
                        val payload = mapOf(
                            "acousticToken" to "android_mock_ac_${System.currentTimeMillis()}",
                            "observedAt" to now
                        )
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
