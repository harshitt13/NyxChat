package com.nyxchat.nyxchat

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Last-known device position for the emergency channel. Only read on
 * explicit user action; never transmitted unless the user opts in.
 */
class LocationChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object { const val CHANNEL = "nyxchat/location" }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lastKnown" -> result.success(lastKnown())
            else -> result.notImplemented()
        }
    }

    private fun lastKnown(): Map<String, Any>? {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (fine != PackageManager.PERMISSION_GRANTED && coarse != PackageManager.PERMISSION_GRANTED) return null
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        var best: android.location.Location? = null
        for (provider in lm.getProviders(true)) {
            try {
                val l = lm.getLastKnownLocation(provider) ?: continue
                if (best == null || l.time > best!!.time) best = l
            } catch (_: SecurityException) {}
        }
        val loc = best ?: return null
        return mapOf(
            "lat" to loc.latitude,
            "lon" to loc.longitude,
            "accuracy" to loc.accuracy.toDouble(),
            "ageMs" to (System.currentTimeMillis() - loc.time)
        )
    }
}