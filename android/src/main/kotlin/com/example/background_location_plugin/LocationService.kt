package com.example.background_location_plugin

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*

class LocationService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        locationRequest = LocationRequest.create().apply {
            interval = 60000
            fastestInterval = 30000
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
        }

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    sendNotification("New Location", "Lat: ${location.latitude}, Lng: ${location.longitude}")
                }
            }
        }

        startForeground(1, createNotification("Tracking Location..."))
        startLocationUpdates()
    }

    private fun startLocationUpdates() {
        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, null)
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    private fun createNotification(content: String): Notification {
        val channelId = "location_channel"
        val channel = NotificationChannel(channelId, "Location Tracking", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Location Service")
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_launcher)
            .build()
    }

    private fun sendNotification(title: String, content: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(this, "location_channel")
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_launcher)
            .build()
        notificationManager.notify(2, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}