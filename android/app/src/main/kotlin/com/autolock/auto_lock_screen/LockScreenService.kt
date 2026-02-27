package com.autolock.auto_lock_screen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class LockScreenService : Service() {

    companion object {
        const val CHANNEL_ID = "auto_lock_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_UPDATE_TIMEOUT = "com.autolock.UPDATE_TIMEOUT"
        const val EXTRA_TIMEOUT = "timeout_ms"
        var isRunning = false
            private set
    }

    private var timeoutMs: Long = 5 * 60 * 1000L
    private val handler = Handler(Looper.getMainLooper())
    private var isScreenOn = true

    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> {
                    isScreenOn = true
                    resetTimer()
                }
                Intent.ACTION_SCREEN_OFF -> {
                    isScreenOn = false
                    cancelTimer()
                }
                Intent.ACTION_USER_PRESENT -> {
                    resetTimer()
                }
            }
        }
    }

    private val lockRunnable = Runnable {
        if (isScreenOn) {
            lockScreen()
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true

        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, AutoLockDeviceAdminReceiver::class.java)

        // Check current screen state
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        isScreenOn = powerManager.isInteractive

        // Register screen state receiver
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Update timeout if provided
        val newTimeout = when (val value = intent?.extras?.get(EXTRA_TIMEOUT)) {
            is Long -> value
            is Int -> value.toLong()
            is Number -> value.toLong()
            else -> null
        }
        if (newTimeout != null) {
            timeoutMs = newTimeout
        }

        if (intent?.action == ACTION_UPDATE_TIMEOUT) {
            resetTimer()
            // Update notification with new timeout
            val notification = createNotification()
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, notification)
            return START_STICKY
        }

        createNotificationChannel()
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        resetTimer()

        return START_STICKY
    }

    private fun resetTimer() {
        handler.removeCallbacks(lockRunnable)
        if (isScreenOn) {
            handler.postDelayed(lockRunnable, timeoutMs)
        }
    }

    private fun cancelTimer() {
        handler.removeCallbacks(lockRunnable)
    }

    private fun lockScreen() {
        if (devicePolicyManager.isAdminActive(adminComponent)) {
            devicePolicyManager.lockNow()
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "自动锁屏服务",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "监控用户无操作状态并自动锁定屏幕"
        }
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        val timeoutMinutes = timeoutMs / 60000
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("自动锁屏运行中")
            .setContentText("将在 ${timeoutMinutes} 分钟无操作后锁定屏幕")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        cancelTimer()
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
