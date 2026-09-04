package com.nyxchat.nyxchat

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var blePeripheral: BlePeripheral? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Screen capture protection is a user setting (default on); the
        // Dart side calls setSecure on startup and whenever it changes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nyxchat/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: true
                        runOnUiThread {
                            if (secure) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LocationChannel.CHANNEL)
            .setMethodCallHandler(LocationChannel(applicationContext))

        val peripheral = BlePeripheral(applicationContext)
        blePeripheral = peripheral
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BlePeripheral.METHOD_CHANNEL)
            .setMethodCallHandler(peripheral)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BlePeripheral.EVENT_CHANNEL)
            .setStreamHandler(peripheral)
    }
}