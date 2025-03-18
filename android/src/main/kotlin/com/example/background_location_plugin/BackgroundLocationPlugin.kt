package com.example.background_location_plugin

import androidx.annotation.NonNull

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** BackgroundLocationPlugin */
class BackgroundLocationPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext  // Fix: use flutterPluginBinding instead of binding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_location_plugin")
    channel.setMethodCallHandler(this)
}
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                val args = call.arguments as? Map<String, Any>
                if (args == null) {
                    result.error("INVALID_ARGUMENTS", "Arguments must be a dictionary", null)
                    return
                }
                // Extract parameters; if missing, report error.
                val targetLat = args["targetLat"] as? Double
                    ?: return result.error("MISSING_PARAMETERS", "targetLat is missing", null)
                val targetLng = args["targetLng"] as? Double
                    ?: return result.error("MISSING_PARAMETERS", "targetLng is missing", null)
                val bufferRadius = args["bufferRadius"] as? Double
                    ?: return result.error("MISSING_PARAMETERS", "bufferRadius is missing", null)
                val verificationWindow = args["verificationWindow"] as? Double
                    ?: return result.error("MISSING_PARAMETERS", "verificationWindow is missing", null)
                val verificationThreshold = args["verificationThreshold"] as? Double
                    ?: return result.error("MISSING_PARAMETERS", "verificationThreshold is missing", null)

                // Pass these parameters to the service via Intent extras.
                val serviceIntent = Intent(context, BackgroundLocationService::class.java).apply {
                    action = "START_SERVICE"
                    putExtra("targetLat", targetLat)
                    putExtra("targetLng", targetLng)
                    putExtra("bufferRadius", bufferRadius)
                    putExtra("verificationWindow", verificationWindow)
                    putExtra("verificationThreshold", verificationThreshold)
                }
                // Start the foreground service.
                context.startForegroundService(serviceIntent)
                result.success("Android Service Started")
            }
            "stopService" -> {
                val serviceIntent = Intent(context, BackgroundLocationService::class.java)
                context.stopService(serviceIntent)
                result.success("Android Service Stopped")
            }
            "getVerificationStatus" -> {
                // Retrieve verification status from SharedPreferences.
                val prefs = context.getSharedPreferences("BackgroundLocationPrefs", Context.MODE_PRIVATE)
                val isRunning = prefs.getBoolean("isServiceRunning", false)
                val isVerified = prefs.getBoolean("isVerified", false)
                val timeRemaining = prefs.getFloat("timeRemaining", 0f).toDouble()
                val timeSpentInBuffer = prefs.getFloat("totalTimeInside", 0f).toDouble()
                val verificationThresholdSaved = prefs.getFloat("verificationThreshold", 0f).toDouble()
                val timeNeededInBuffer = verificationThresholdSaved / 1000.0
                val isCurrentlyInBuffer = prefs.getBoolean("isCurrentlyInBuffer", false)
                
                val status = mapOf(
                    "isRunning" to isRunning,
                    "timeRemaining" to timeRemaining,
                    "timeSpentInBuffer" to timeSpentInBuffer,
                    "timeNeededInBuffer" to timeNeededInBuffer,
                    "isCurrentlyInBuffer" to isCurrentlyInBuffer,
                    "isVerified" to isVerified
                )
                result.success(status)
            }
            "checkTotalTimeInsideValue" -> {
                val prefs = context.getSharedPreferences("BackgroundLocationPrefs", Context.MODE_PRIVATE)
                val totalTimeInside = prefs.getFloat("totalTimeInside", 0f).toDouble()
                result.success(mapOf("totalTimeInside" to totalTimeInside))
            }
            else -> {
                result.notImplemented()
            }
        }
    }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {}
  override fun onDetachedFromActivityForConfigChanges() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
  override fun onDetachedFromActivity() {}
}
