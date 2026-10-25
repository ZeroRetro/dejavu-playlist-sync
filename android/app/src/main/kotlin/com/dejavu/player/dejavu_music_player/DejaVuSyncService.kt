package com.dejavu.player.dejavu_music_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class DejaVuSyncService : Service() {

    companion object {
        const val CHANNEL_ID = "dejavu_sync_channel"
        const val NOTIFICATION_ID = 2002

        const val ACTION_START = "ACTION_START"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val ACTION_STOP = "ACTION_STOP"

        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val EXTRA_MESSAGE = "EXTRA_MESSAGE"
        const val EXTRA_PROGRESS = "EXTRA_PROGRESS"
        const val EXTRA_TOTAL = "EXTRA_TOTAL"
        const val EXTRA_INDETERMINATE = "EXTRA_INDETERMINATE"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_START, ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "DejaVu Sync"
                val message = intent.getStringExtra(EXTRA_MESSAGE) ?: "Synchronizing playlist..."
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val total = intent.getIntExtra(EXTRA_TOTAL, 0)
                val indeterminate = intent.getBooleanExtra(EXTRA_INDETERMINATE, total <= 0)

                val notification = buildNotification(title, message, progress, total, indeterminate)

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } catch (e: Exception) {
                    // Fallback in case of strict OEM constraint
                    try {
                        startForeground(NOTIFICATION_ID, notification)
                    } catch (_: Exception) {}
                }
            }
            ACTION_STOP -> {
                stopSync()
            }
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(
        title: String,
        message: String,
        progress: Int,
        total: Int,
        indeterminate: Boolean
    ): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_music_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (indeterminate || total <= 0) {
            builder.setProgress(0, 0, true)
        } else {
            builder.setProgress(total, progress, false)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Playlist Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress during playlist synchronization and downloads"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "dejavu:sync_wakelock"
            ).apply {
                setReferenceCounted(false)
                acquire(45 * 60 * 1000L) // 45-minute safety threshold
            }
        } catch (_: Exception) {}
    }

    private fun stopSync() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}
        stopSelf()
    }

    override fun onDestroy() {
        stopSync()
        super.onDestroy()
    }
}
