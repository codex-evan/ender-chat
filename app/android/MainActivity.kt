// MainActivity.kt - Android
// Implements FLAG_SECURE to prevent screenshots and screen recording

package com.encchat.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.encchat/security"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE: Prevent screenshots and screen recording
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "detectScreenshot" -> {
                    // Android 10+ can detect screenshots via MediaProjection
                    result.success(false)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
