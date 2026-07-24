package com.fijacks.saacousticble

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.fijacks.saacousticble.acoustic.AcousticTransmitter
import com.fijacks.saacousticble.ble.BleAdvertiser
import java.security.SecureRandom
import java.time.Instant

class AttendanceBroadcastService : Service() {
    companion object {
        private const val ACTION_START = "com.fijacks.saacousticble.START_ATTENDANCE_BROADCAST"
        private const val EXTRA_ACOUSTIC_TOKEN = "acousticToken"
        private const val EXTRA_BLE_NONCE = "bleNonce"
        private const val CHANNEL_ID = "attendance_broadcast"
        private const val NOTIFICATION_ID = 2107
        private const val REFRESH_INTERVAL_MS = 45_000L

        @Volatile
        private var current: AttendanceBroadcastService? = null

        fun start(context: Context, acousticToken: String, bleNonce: String) {
            val intent = Intent(context, AttendanceBroadcastService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ACOUSTIC_TOKEN, acousticToken)
                putExtra(EXTRA_BLE_NONCE, bleNonce)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AttendanceBroadcastService::class.java))
        }

        fun snapshot(): Map<String, Any?> {
            return current?.snapshotInternal() ?: mapOf(
                "acousticToken" to null,
                "bleNonce" to null,
                "acousticStatus" to "acoustic_broadcast_stopped",
                "bleStatus" to "ble_advertising_stopped",
                "running" to false,
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val random = SecureRandom()
    private val acousticTransmitter = AcousticTransmitter()
    private val bleAdvertiser by lazy {
        BleAdvertiser(applicationContext, "SaAcousticBle")
    }
    private var wakeLock: PowerManager.WakeLock? = null
    private var sessionId: Int? = null
    private var latestAcousticToken: String? = null
    private var latestBleNonce: String? = null
    private var acousticStatus = "acoustic_broadcast_stopped"
    private var running = false

    private val refreshRunnable = object : Runnable {
        override fun run() {
            if (!running) {
                return
            }
            refreshSignals()
            handler.postDelayed(this, REFRESH_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        current = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val acousticToken = intent.getStringExtra(EXTRA_ACOUSTIC_TOKEN).orEmpty()
                val bleNonce = intent.getStringExtra(EXTRA_BLE_NONCE).orEmpty()
                val parsedSessionId = parseSessionId(acousticToken, bleNonce)
                if (parsedSessionId == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                sessionId = parsedSessionId
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification("Attendance broadcast is active"),
                )
                acquireWakeLock()
                running = true
                startSignals(acousticToken, bleNonce)
                handler.removeCallbacks(refreshRunnable)
                handler.postDelayed(refreshRunnable, REFRESH_INTERVAL_MS)
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopBroadcastAndService()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        running = false
        acousticTransmitter.stop()
        bleAdvertiser.stop()
        releaseWakeLock()
        current = null
        super.onDestroy()
    }

    private fun refreshSignals() {
        val activeSessionId = sessionId ?: return
        val issuedEpoch = Instant.now().epochSecond
        val challenge = randomToken()
        val nonce = randomToken()
        val acousticToken = listOf(
            "ac2",
            Integer.toString(activeSessionId, 36),
            java.lang.Long.toString(issuedEpoch, 36),
            challenge,
        ).joinToString("|")
        val bleNonce = "ble|$activeSessionId|$issuedEpoch|$nonce"
        startSignals(acousticToken, bleNonce)
    }

    private fun startSignals(acousticToken: String, bleNonce: String) {
        latestAcousticToken = acousticToken
        latestBleNonce = bleNonce
        acousticStatus = try {
            acousticTransmitter.start(acousticToken)
            "acoustic_broadcast_started"
        } catch (error: Exception) {
            "acoustic_broadcast_failed_${error.javaClass.simpleName}"
        }
        bleAdvertiser.start(bleNonce)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(
            NOTIFICATION_ID,
            buildNotification("Broadcasting session ${sessionId ?: ""}"),
        )
    }

    private fun stopBroadcastAndService() {
        handler.removeCallbacks(refreshRunnable)
        running = false
        acousticTransmitter.stop()
        bleAdvertiser.stop()
        latestAcousticToken = null
        latestBleNonce = null
        acousticStatus = "acoustic_broadcast_stopped"
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun parseSessionId(acousticToken: String, bleNonce: String): Int? {
        val bleParts = bleNonce.split("|")
        if (bleParts.size == 4 && bleParts[0] == "ble") {
            bleParts[1].toIntOrNull()?.let { return it }
        }
        val acousticParts = acousticToken.split("|")
        if (acousticParts.size == 4 && acousticParts[0] == "ac2") {
            return acousticParts[1].toIntOrNull(36)
        }
        if (acousticParts.size == 5 && acousticParts[0] == "ac") {
            return acousticParts[1].toIntOrNull()
        }
        return null
    }

    private fun randomToken(): String {
        val chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return buildString(8) {
            repeat(8) {
                append(chars[random.nextInt(chars.length)])
            }
        }
    }

    private fun snapshotInternal(): Map<String, Any?> {
        return mapOf(
            "acousticToken" to latestAcousticToken,
            "bleNonce" to latestBleNonce,
            "acousticStatus" to acousticStatus,
            "bleStatus" to bleAdvertiser.latestStatus(),
            "running" to running,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Live attendance broadcast",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while acoustic and Bluetooth attendance signals are active."
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(content: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Smart Attendance")
            .setContentText(content)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            )
            .build()

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SmartAttendance::LiveBroadcast",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
}
