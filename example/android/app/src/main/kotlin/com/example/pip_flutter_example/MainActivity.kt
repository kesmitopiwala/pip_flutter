package com.example.pip_flutter_example

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.example.pip_flutter.PipFlutterPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.e("CALLMETHOD", "onCreate: CALL MainActivity")
        startNotificationService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.e("CALLMETHOD", "configureFlutterEngine: CALL plugin")
        flutterEngine.plugins.add(PipFlutterPlugin())
    }

    override fun onDestroy() {
        super.onDestroy()
        stopNotificationService()
    }

    ///TODO: Call this method via channel after remote notification start
    private fun startNotificationService() {
        try {
            val intent = Intent(this, PipFlutterPlayerService::class.java)
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (exception: Exception) {
        }
    }

    ///TODO: Call this method via channel after remote notification stop
    private fun stopNotificationService() {
        try {
            val intent = Intent(this, PipFlutterPlayerService::class.java)
            stopService(intent)
        } catch (exception: Exception) {

        }
    }
}
