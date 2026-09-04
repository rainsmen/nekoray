package com.nekoray.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log

class NekoVpnService : VpnService() {

    companion object {
        private const val TAG = "NekoVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "nekoray_vpn_service"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var activeInstance: NekoVpnService? = null
            private set

        @Volatile
        private var pendingMtu: Int = 1500

        @Volatile
        private var pendingIpv6: Boolean = false

        private val startLock = Object()
        private var establishedFd: Int = -1

        /**
         * Starts the VPN service from Flutter and waits synchronously for the
         * interface to establish, returning the detached native TUN fd.
         */
        fun start(context: Context, mtu: Int, ipv6: Boolean): Int {
            pendingMtu = if (mtu in 576..9000) mtu else 1500
            pendingIpv6 = ipv6
            establishedFd = -1

            val intent = Intent(context, NekoVpnService::class.java).apply {
                action = "START"
            }

            synchronized(startLock) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                // Wait up to 5 seconds for establish() inside onStartCommand
                try {
                    startLock.wait(5000)
                } catch (_: InterruptedException) {}
            }

            return establishedFd
        }

        fun stop(context: Context) {
            val instance = activeInstance
            if (instance != null) {
                instance.stopVpn()
            } else {
                val intent = Intent(context, NekoVpnService::class.java).apply {
                    action = "STOP"
                }
                context.startService(intent)
            }
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification())

        try {
            val fd = establishVpn(pendingMtu, pendingIpv6)
            synchronized(startLock) {
                establishedFd = fd
                startLock.notifyAll()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN: ${e.message}", e)
            synchronized(startLock) {
                establishedFd = -1
                startLock.notifyAll()
            }
            stopVpn()
        }

        return START_STICKY
    }

    private fun establishVpn(mtu: Int, ipv6: Boolean): Int {
        val builder = Builder()
            .setSession("NekoRay")
            .setMtu(mtu)
            .addAddress("172.19.0.1", 28)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("172.19.0.2")

        if (ipv6) {
            builder.addAddress("fdfe:dcba:9876::1", 126)
            builder.addRoute("::", 0)
        }

        // CRITICAL: Exclude this application from VPN routing.
        // This ensures outbound proxy connections from the app to the remote
        // server bypass the VPN interface and reach the physical network directly,
        // avoiding deadlocks and routing loops without needing socket-protect hooks.
        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            Log.w(TAG, "Could not disallow self package: ${e.message}")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val pfd = builder.establish() ?: throw IllegalStateException("VpnService.Builder.establish() returned null")
        vpnInterface = pfd
        val nativeFd = pfd.detachFd()
        isRunning = true
        Log.i(TAG, "VPN established successfully with native fd: $nativeFd")
        return nativeFd
    }

    private fun stopVpn() {
        isRunning = false
        try {
            vpnInterface?.close()
        } catch (_: Exception) {}
        vpnInterface = null
        activeInstance = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        Log.i(TAG, "VPN service stopped")
    }

    override fun onRevoke() {
        Log.i(TAG, "VPN permission revoked by system")
        stopVpn()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "NekoRay VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification displayed while NekoRay VPN is active"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else null

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("NekoRay")
            .setContentText("VPN service is active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        return builder.build()
    }
}
