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

    fun start(payload: String?): Boolean {
        if (payload.isNullOrBlank()) {
            Log.w(logTag, "BLE advertiser start skipped: payload missing")
            return false
        }
        if (!hasAdvertisePermission()) {
            Log.w(logTag, "BLE advertiser start blocked: advertise permission missing")
            return false
        }
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            Log.w(logTag, "BLE advertiser start blocked: adapter unavailable or disabled")
            return false
        }
        val bleAdvertiser = advertiser
        if (bleAdvertiser == null) {
            Log.w(logTag, "BLE advertiser not available on this device")
            return false
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
                    Log.i(logTag, "BLE advertising started")
                }

                override fun onStartFailure(errorCode: Int) {
                    Log.w(logTag, "BLE advertising failed with code=$errorCode")
                }
            }
        bleAdvertiser.startAdvertising(settings, data, callback)
        advertiseCallback = callback
        lastPayload = payload
        return true
    }

    fun stop() {
        val bleAdvertiser = advertiser ?: return
        val callback = advertiseCallback ?: return
        bleAdvertiser.stopAdvertising(callback)
        advertiseCallback = null
        lastPayload = null
        Log.i(logTag, "BLE advertising stopped")
    }

    fun latestPayload(): String? = lastPayload

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
