package com.fijacks.saacousticble

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.fijacks.saacousticble.acoustic.AcousticFrameDecoder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channelName = "sa_acoustic_ble/acoustic"
    private val logTag = "SaAcousticBle"
    private val requestAudioPermissionCode = 1203
    private val requestBleAdvertisePermissionCode = 1204
    private val requestBleConnectPermissionCode = 1205
    private val requestBleScanPermissionCode = 1206
    private val requestStudentScanPermissionsCode = 1207
    private val requestLecturerBroadcastPermissionsCode = 1208
    private val acousticFrameDecoder by lazy { AcousticFrameDecoder(this) }
    private val acousticExecutor = Executors.newSingleThreadExecutor()
    private val acousticScanInProgress = AtomicBoolean(false)
    private val bluetoothManager: BluetoothManager?
        get() = getSystemService(BluetoothManager::class.java)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBroadcast" -> {
                        val acousticToken = call.argument<String>("acousticToken")
                        val bleNonce = call.argument<String>("bleNonce")
                        Log.i(
                            logTag,
                            "startBroadcast sessionPayload acoustic=${!acousticToken.isNullOrBlank()} ble=${!bleNonce.isNullOrBlank()}"
                        )
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
                        }
                        if (acousticToken.isNullOrBlank() || bleNonce.isNullOrBlank()) {
                            result.error(
                                "BROADCAST_PAYLOAD_REQUIRED",
                                "Acoustic and BLE payloads are required for attendance broadcast.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        AttendanceBroadcastService.start(
                            this,
                            acousticToken,
                            bleNonce,
                        )
                        result.success(
                            mapOf(
                                "acousticStatus" to "foreground_broadcast_start_requested",
                                "bleStatus" to "foreground_broadcast_start_requested",
                                "blePayloadPresent" to !bleNonce.isNullOrBlank(),
                                "acousticPayloadPresent" to !acousticToken.isNullOrBlank()
                            )
                        )
                    }
                    "stopBroadcast" -> {
                        AttendanceBroadcastService.stop(this)
                        result.success(null)
                    }
                    "getLatestBroadcast" -> {
                        result.success(AttendanceBroadcastService.snapshot())
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
                    "ensureStudentScanPermissions" -> {
                        result.success(ensureStudentScanPermissions())
                    }
                    "ensureLecturerBroadcastPermissions" -> {
                        result.success(ensureLecturerBroadcastPermissions())
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
                        if (!acousticScanInProgress.compareAndSet(false, true)) {
                            result.success(
                                mapOf(
                                    "acousticToken" to "",
                                    "bleNonce" to null,
                                    "observedAt" to Instant.now().toString(),
                                    "source" to "microphone_scan_busy",
                                    "diagnostic" to "An acoustic scan is already running."
                                )
                            )
                            return@setMethodCallHandler
                        }
                        acousticExecutor.execute {
                            val decodedToken = acousticFrameDecoder.decodeFromMic()
                            val diagnostic = acousticFrameDecoder.lastDiagnostics
                            val source = if (!decodedToken.isNullOrBlank()) {
                                "microphone_decode"
                            } else {
                                "microphone_no_decode"
                            }
                            if (!decodedToken.isNullOrBlank()) {
                                Log.i(logTag, "Acoustic decode success: $diagnostic")
                            } else {
                                Log.w(logTag, "Acoustic decode failed: $diagnostic")
                            }
                            val payload = mapOf(
                                "acousticToken" to (decodedToken ?: ""),
                                "bleNonce" to AttendanceBroadcastService.snapshot()["bleNonce"],
                                "observedAt" to Instant.now().toString(),
                                "source" to source,
                                "diagnostic" to diagnostic
                            )
                            acousticScanInProgress.set(false)
                            runOnUiThread {
                                result.success(payload)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        acousticExecutor.shutdownNow()
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
        if (!isBluetoothOn()) {
            return "bluetooth_off"
        }
        return "ble_scan_ready"
    }

    private fun ensureStudentScanPermissions(): Map<String, Any> {
        val missingLabels = mutableListOf<String>()
        val missingPermissions = mutableListOf<String>()

        if (!hasRecordAudioPermission()) {
            missingLabels.add("microphone")
            missingPermissions.add(Manifest.permission.RECORD_AUDIO)
        }
        if (!hasBleScanPermission()) {
            missingLabels.add(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) "nearby_devices" else "location")
            missingPermissions.add(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Manifest.permission.BLUETOOTH_SCAN
                } else {
                    Manifest.permission.ACCESS_FINE_LOCATION
                }
            )
        }
        if (!hasBleConnectPermission()) {
            missingLabels.add("nearby_devices")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                missingPermissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
        if (!hasFineLocationPermission()) {
            missingLabels.add("location")
            missingPermissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        val uniquePermissions = missingPermissions.distinct()
        if (uniquePermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                uniquePermissions.toTypedArray(),
                requestStudentScanPermissionsCode
            )
        }

        if (missingLabels.isEmpty() && !isBluetoothOn()) {
            return mapOf(
                "ready" to false,
                "status" to "bluetooth_off",
                "missing" to emptyList<String>()
            )
        }

        return mapOf(
            "ready" to missingLabels.isEmpty(),
            "status" to if (missingLabels.isEmpty()) "permissions_ready" else "permissions_missing",
            "missing" to missingLabels.distinct()
        )
    }

    private fun ensureLecturerBroadcastPermissions(): Map<String, Any> {
        val missingLabels = mutableListOf<String>()
        val missingPermissions = mutableListOf<String>()

        if (!hasBleAdvertisePermission()) {
            missingLabels.add("nearby_devices")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                missingPermissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            }
        }
        if (!hasBleConnectPermission()) {
            missingLabels.add("nearby_devices")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                missingPermissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        val uniquePermissions = missingPermissions.distinct()
        if (uniquePermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                uniquePermissions.toTypedArray(),
                requestLecturerBroadcastPermissionsCode
            )
        }

        if (missingLabels.isEmpty() && !isBluetoothOn()) {
            return mapOf(
                "ready" to false,
                "status" to "bluetooth_off",
                "missing" to emptyList<String>()
            )
        }

        return mapOf(
            "ready" to missingLabels.isEmpty(),
            "status" to if (missingLabels.isEmpty()) "permissions_ready" else "permissions_missing",
            "missing" to missingLabels.distinct()
        )
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

    private fun hasFineLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
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

    private fun isBluetoothOn(): Boolean {
        return bluetoothManager?.adapter?.isEnabled == true
    }
}
