package com.fijacks.saacousticble

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.fijacks.saacousticble.acoustic.AcousticTransmitter
import com.fijacks.saacousticble.acoustic.AcousticFrameDecoder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

class MainActivity : FlutterActivity() {
    private val channelName = "sa_acoustic_ble/acoustic"
    private val logTag = "SaAcousticBle"
    private val requestAudioPermissionCode = 1203
    private var latestAcousticToken: String? = null
    private var latestBleNonce: String? = null
    private val acousticTransmitter = AcousticTransmitter()
    private val acousticFrameDecoder by lazy { AcousticFrameDecoder(this) }

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
                        Log.i(
                            logTag,
                            "startBroadcast sessionPayload acoustic=${!acousticToken.isNullOrBlank()} ble=${!bleNonce.isNullOrBlank()}"
                        )
                        if (!acousticToken.isNullOrBlank()) {
                            acousticTransmitter.start(acousticToken)
                        }
                        result.success(null)
                    }
                    "stopBroadcast" -> {
                        acousticTransmitter.stop()
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
                        if (!hasRecordAudioPermission()) {
                            Log.w(logTag, "startAcousticScan blocked: microphone permission missing")
                            requestRecordAudioPermission()
                            result.error(
                                "MIC_PERMISSION_REQUIRED",
                                "Microphone permission is required for acoustic scan.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val decodedToken = acousticFrameDecoder.decodeFromMic()
                        val now = Instant.now().toString()
                        val source = if (!decodedToken.isNullOrBlank()) {
                            "microphone_decode"
                        } else {
                            "microphone_no_decode"
                        }
                        val diagnostic = acousticFrameDecoder.lastDiagnostics
                        if (!decodedToken.isNullOrBlank()) {
                            Log.i(logTag, "Acoustic decode success: $diagnostic")
                        } else {
                            Log.w(logTag, "Acoustic decode failed: $diagnostic")
                        }
                        val payload = mapOf(
                            "acousticToken" to (decodedToken ?: ""),
                            "bleNonce" to latestBleNonce,
                            "observedAt" to now,
                            "source" to source,
                            "diagnostic" to diagnostic
                        )
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        acousticTransmitter.stop()
        super.onDestroy()
    }

    private fun hasRecordAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestRecordAudioPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            requestAudioPermissionCode
        )
    }
}
