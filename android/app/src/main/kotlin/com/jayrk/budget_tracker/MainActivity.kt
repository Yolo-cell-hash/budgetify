package com.jayrk.budget_tracker

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

// FlutterFragmentActivity is required by local_auth's BiometricPrompt
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Physical rumble for the royal screen-attack reactions. Flutter's
        // HapticFeedback.* rides View.performHapticFeedback, which the system
        // "touch feedback" setting silently disables on many phones — this
        // channel drives the Vibrator service directly (VIBRATE permission)
        // so the crash is actually felt. Pattern = alternating [wait, buzz]
        // millis; amps = one 1..255 amplitude per buzz segment.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "budgetify/rumble")
            .setMethodCallHandler { call, result ->
                if (call.method != "rumble") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val pattern = (call.argument<List<Int>>("pattern") ?: listOf(0, 60))
                        .map { it.toLong() }.toLongArray()
                    val amps = call.argument<List<Int>>("amps")
                    vibrate(pattern, amps)
                    result.success(null)
                } catch (e: Exception) {
                    // Cosmetic-only: never let a missing vibrator crash the app.
                    result.success(null)
                }
            }
    }

    private fun vibrator(): Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    private fun vibrate(pattern: LongArray, amps: List<Int>?) {
        val v = vibrator()
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Amplitude list must match the pattern length (0 for the waits).
            val effect = if (amps != null && v.hasAmplitudeControl()) {
                val amplitudes = IntArray(pattern.size)
                var buzz = 0
                for (i in pattern.indices) {
                    // Odd slots are buzz segments in the [wait, buzz, ...] shape.
                    amplitudes[i] = if (i % 2 == 1) {
                        amps.getOrNull(buzz++)?.coerceIn(1, 255) ?: 255
                    } else 0
                }
                VibrationEffect.createWaveform(pattern, amplitudes, -1)
            } else {
                VibrationEffect.createWaveform(pattern, -1)
            }
            v.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(pattern, -1)
        }
    }
}
