package com.dejavu.player.dejavu_music_player

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.ryanheise.audioservice.AudioService

/**
 * Monitors task removal (when the user swipes the app away from Recents)
 * and guarantees that background audio playback and foreground notification stop immediately.
 */
class CloseAppOnTaskRemovedService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            stopService(Intent(this, AudioService::class.java))
        } catch (_: Exception) {}
        stopSelf()
    }
}
