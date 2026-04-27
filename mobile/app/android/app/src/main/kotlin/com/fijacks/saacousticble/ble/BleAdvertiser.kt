package com.fijacks.saacousticble.ble

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets

class BleAdvertiser(
    private val context: Context,
    private val logTag: String,
) {
    companion object {
        const val MANUFACTURER_ID = 0x0A91
    }

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(BluetoothManager::class.java)
    private val bluetoothAdapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter
    private val advertiser: BluetoothLeAdvertiser?
        get() = bluetoothAdapter?.bluetoothLeAdvertiser

    private var advertiseCallback: AdvertiseCallback? = null
    private var lastPayload: String? = null
    private var lastStatus: String = "ble_idle"

    fun start(payload: String?): String {
        if (payload.isNullOrBlank()) {
            return updateStatus("ble_payload_missing")
        }
        if (!hasAdvertisePermission()) {
            return updateStatus("ble_advertise_permission_missing")
        }
        if (!hasConnectPermission()) {
            return updateStatus("ble_connect_permission_missing")
        }
        val adapter = bluetoothAdapter
        if (adapter == null) {
            return updateStatus("ble_adapter_unavailable")
        }
        if (!adapter.isEnabled) {
            return updateStatus("ble_bluetooth_off")
        }
        if (!adapter.isMultipleAdvertisementSupported) {
            return updateStatus("ble_advertising_unsupported")
        }
        val bleAdvertiser = advertiser
        if (bleAdvertiser == null) {
            return updateStatus("ble_advertiser_unavailable")
        }

        stop()
        val settings =
            AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(false)
                .build()
        val data =
            AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .setIncludeTxPowerLevel(false)
                .addManufacturerData(MANUFACTURER_ID, encodePayload(payload))
                .build()
        val callback =
            object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    updateStatus("ble_advertising_started")
                }

                override fun onStartFailure(errorCode: Int) {
                    updateStatus("ble_advertising_failed_code_$errorCode")
                }
            }
        return try {
            bleAdvertiser.startAdvertising(settings, data, callback)
            advertiseCallback = callback
            lastPayload = payload
            updateStatus("ble_advertising_start_requested")
        } catch (error: SecurityException) {
            updateStatus("ble_security_exception_${error.javaClass.simpleName}")
        } catch (error: Exception) {
            updateStatus("ble_start_exception_${error.javaClass.simpleName}")
        }
    }

    fun stop() {
        val bleAdvertiser = advertiser ?: return
        val callback = advertiseCallback ?: return
        try {
            bleAdvertiser.stopAdvertising(callback)
        } catch (_: Exception) {
        }
        advertiseCallback = null
        lastPayload = null
        updateStatus("ble_advertising_stopped")
    }

    fun latestPayload(): String? = lastPayload
    fun latestStatus(): String = lastStatus

    private fun hasAdvertisePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun hasConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun updateStatus(status: String): String {
        lastStatus = status
        if (status.contains("failed") || status.contains("missing") || status.contains("off") ||
            status.contains("unsupported") || status.contains("unavailable") || status.contains("exception")
        ) {
            Log.w(logTag, "BLE advertiser status=$status")
        } else {
            Log.i(logTag, "BLE advertiser status=$status")
        }
        return status
    }

    private fun encodePayload(payload: String): ByteArray {
        val parts = payload.split("|")
        if (parts.size != 4 || parts[0] != "ble") {
            return payload.toByteArray(StandardCharsets.UTF_8)
        }
        val sessionId = parts[1].toIntOrNull() ?: return payload.toByteArray(StandardCharsets.UTF_8)
        val issuedEpoch = parts[2].toLongOrNull() ?: return payload.toByteArray(StandardCharsets.UTF_8)
        val nonce = parts[3].take(8).padEnd(8, '_')
        val buffer = ByteBuffer.allocate(16).order(ByteOrder.BIG_ENDIAN)
        buffer.putInt(sessionId)
        buffer.putInt(issuedEpoch.toInt())
        buffer.put(nonce.toByteArray(StandardCharsets.UTF_8))
        return buffer.array()
    }
}
