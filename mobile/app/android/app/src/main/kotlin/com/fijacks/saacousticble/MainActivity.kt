package com.fijacks.saacousticble

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlin.math.PI
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val channelName = "sa_acoustic_ble/acoustic"
    private var latestAcousticToken: String? = null
    private var latestBleNonce: String? = null
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBroadcast" -> {
                        val acousticToken = call.argument<String>("acousticToken")
                        val bleNonce = call.argument<String>("bleNonce")
                        latestAcousticToken = acousticToken
                        latestBleNonce = bleNonce
                        startUltrasonicCarrier()
                        result.success(null)
                    }
                    "stopBroadcast" -> {
                        stopUltrasonicCarrier()
                        latestAcousticToken = null
                        latestBleNonce = null
                        result.success(null)
                    }
                    "getLatestBroadcast" -> {
                        val payload = mapOf(
                            "acousticToken" to latestAcousticToken,
                            "bleNonce" to latestBleNonce
                        )
                        result.success(payload)
                    }
                    "startAcousticScan" -> {
                        val now = Instant.now().toString()
                        val payload = mapOf(
                            "acousticToken" to (latestAcousticToken ?: "android_mock_ac_${System.currentTimeMillis()}"),
                            "bleNonce" to latestBleNonce,
                            "observedAt" to now
                        )
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopUltrasonicCarrier()
        super.onDestroy()
    }

    private fun startUltrasonicCarrier() {
        stopUltrasonicCarrier()
        val sampleRate = 44100
        val frequency = 19000.0
        val durationSeconds = 1
        val count = sampleRate * durationSeconds
        val data = ShortArray(count)
        for (i in 0 until count) {
            val angle = 2.0 * PI * i * frequency / sampleRate
            data[i] = (sin(angle) * Short.MAX_VALUE * 0.15).toInt().toShort()
        }
        val minSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minSize, data.size * 2),
            AudioTrack.MODE_STATIC
        ).apply {
            write(data, 0, data.size)
            setLoopPoints(0, data.size, -1)
            play()
        }
    }

    private fun stopUltrasonicCarrier() {
        audioTrack?.apply {
            try {
                stop()
            } catch (_: Exception) {
            }
            release()
        }
        audioTrack = null
    }
}
