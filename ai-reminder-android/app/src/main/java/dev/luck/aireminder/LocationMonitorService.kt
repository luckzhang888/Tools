package dev.luck.aireminder

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.IBinder
import kotlin.math.max

class LocationMonitorService : Service(), LocationListener {
    companion object {
        const val ACTION_STOP = "dev.luck.aireminder.STOP"
        private const val STATUS_ID = 108
        private const val MONITOR_CHANNEL = "location_monitor"
        private const val ALERT_CHANNEL = "location_alerts"
    }

    private lateinit var manager: LocationManager

    override fun onCreate() {
        super.onCreate()
        manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notifications.createNotificationChannel(
            NotificationChannel(MONITOR_CHANNEL, "位置监测运行状态", NotificationManager.IMPORTANCE_LOW)
        )
        notifications.createNotificationChannel(
            NotificationChannel(ALERT_CHANNEL, "地点与快递提醒", NotificationManager.IMPORTANCE_HIGH)
        )
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(STATUS_ID, statusNotification())
        DataStore.setMonitoring(this, true)
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            try {
                if (manager.isProviderEnabled(provider)) {
                    manager.requestLocationUpdates(provider, 30_000L, 20f, this)
                }
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }
        return START_STICKY
    }

    private fun appIntent(): PendingIntent = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun statusNotification(): Notification =
        Notification.Builder(this, MONITOR_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("AI 地点提醒正在运行")
            .setContentText("正在本机检测地点进入与离开；点击打开 App")
            .setContentIntent(appIntent())
            .setOngoing(true)
            .build()

    override fun onLocationChanged(location: Location) {
        DataStore.saveLocation(this, location.latitude, location.longitude)
        for (place in DataStore.places(this)) {
            if (location.hasAccuracy() && location.accuracy > max(150f, place.radius)) continue
            val result = FloatArray(1)
            Location.distanceBetween(
                location.latitude, location.longitude, place.lat, place.lon, result
            )
            val entered = DataStore.checkTransition(this, place, result[0]) ?: continue
            when (place.kind) {
                "office" -> if (entered) {
                    notifyReminder("到达" + place.name, "请确认上班打卡。")
                } else {
                    notifyReminder("离开" + place.name, "请确认下班打卡。")
                }
                "pickup" -> if (entered) {
                    val count = DataStore.parcels(this).count { !it.collected }
                    if (count > 0) notifyReminder("到达" + place.name, "你有" + count + "件快递待领取。")
                }
                else -> if (entered) {
                    notifyReminder("到达" + place.name, "你已进入设定区域。")
                }
            }
        }
    }

    private fun notifyReminder(title: String, detail: String) {
        val event = ReminderEvent(title = title, detail = detail)
        DataStore.addReminder(this, event)
        val notice = Notification.Builder(this, ALERT_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(detail)
            .setAutoCancel(true)
            .setContentIntent(appIntent())
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify((event.timestamp % Int.MAX_VALUE).toInt(), notice)
    }

    override fun onDestroy() {
        if (::manager.isInitialized) manager.removeUpdates(this)
        DataStore.setMonitoring(this, false)
        super.onDestroy()
    }
}
