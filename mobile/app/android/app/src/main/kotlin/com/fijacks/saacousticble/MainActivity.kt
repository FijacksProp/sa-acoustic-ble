package com.fijacks.saacousticble

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.fijacks.saacousticble.acoustic.AcousticTransmitter
import com.fijacks.saacousticble.acoustic.AcousticFrameDecoder
import com.fijacks.saacousticble.ble.BleAdvertiser
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

class MainActivity : FlutterActivity() {
    private val channelName = "sa_acoustic_ble/acoustic"
    private val logTag = "SaAcousticBle"
    private val requestAudioPermissionCode = 1203
    private val requestBleAdvertisePermissionCode = 1204
    private val requestBleConnectPermissionCode = 1205
    private val requestBleScanPermissionCode = 1206
    private var latestAcousticToken: String? = null
    private var latestBleNonce: String? = null
    private val acousticTransmitter = AcousticTransmitter()
    private val acousticFrameDecoder by lazy { AcousticFrameDecoder(this) }
    private val bleAdvertiser by lazy { BleAdvertiser(this, logTag) }

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
                        if (!bleNonce.isNullOrBlank()) {
                            if (!hasBleAdvertisePermission()) {
                                requestBleAdvertisePermission()
                                result.error(
                                    "BLE_ADVERTISE_PERMISSION_REQUIRED",
                                    "Bluetooth advertise permission is required for BLE broadcast.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                            if (!hasBleConnectPermission()) {
                                requestBleConnectPermission()
                                result.error(
                                    "BLE_CONNECT_PERMISSION_REQUIRED",
                                    "Bluetooth connect permission is required to inspect Bluetooth state.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                            bleAdvertiser.start(bleNonce)
                        }
                        result.success(
                            mapOf(
                                "acousticStatus" to if (!acousticToken.isNullOrBlank()) {
                                    "acoustic_broadcast_started"
                                } else {
                                    "acoustic_payload_missing"
                                },
                                "bleStatus" to bleAdvertiser.latestStatus(),
                                "blePayloadPresent" to !bleNonce.isNullOrBlank(),
                                "acousticPayloadPresent" to !acousticToken.isNullOrBlank()
                            )
                        )
                    }
                    "stopBroadcast" -> {
                        acousticTransmitter.stop()
                        bleAdvertiser.stop()
                        latestAcousticToken = null
                        latestBleNonce = null
                        result.success(null)
                    }
                    "getLatestBroadcast" -> {
                        val payload = mapOf(
                            "acousticToken" to latestAcousticToken,
                            "bleNonce" to latestBleNonce,
                            "bleStatus" to bleAdvertiser.latestStatus()
                        )
                        result.success(payload)
                    }
                    "ensureBleScanReady" -> {
                        val status = ensureBleScanReady()
                        result.success(
                            mapOf(
                                "ready" to (status == "ble_scan_ready"),
                                "status" to status
                            )
                        )
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
        bleAdvertiser.stop()
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

    private fun hasBleAdvertisePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_ADVERTISE
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestBleAdvertisePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE),
                requestBleAdvertisePermissionCode
            )
        }
    }

    private fun hasBleConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestBleConnectPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                requestBleConnectPermissionCode
            )
        }
    }

    private fun ensureBleScanReady(): String {
        if (!hasBleScanPermission()) {
            requestBleScanPermission()
            return "ble_scan_permission_missing"
        }
        if (!hasBleConnectPermission()) {
            requestBleConnectPermission()
            return "ble_connect_permission_missing"
        }
        return "ble_scan_ready"
    }

    private fun hasBleScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBleScanPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_SCAN),
                requestBleScanPermissionCode
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                requestBleScanPermissionCode
            )
        }
    }
}
