package com.jayrk.budget_tracker

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
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

        // Opt-in "Match app icon to my royal": swap the launcher icon by
        // toggling activity-aliases (see AndroidManifest). Purely cosmetic — a
        // failure must never crash the app, so errors resolve to false.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "budgetify/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    setLauncherIcon(call.argument<String>("icon"))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

        // Payment-app notification capture (see TxnNotificationListener).
        // The channel only serves the foreground concerns — access status,
        // the system-settings deep link, and the live "queue changed" nudge.
        // Draining the queue itself is a direct file read from Dart, so the
        // background WorkManager isolate needs no channel at all.
        val notifChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "budgetify/notif_capture"
        )
        notifChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isAccessGranted" ->
                        result.success(NotifCapture.isAccessGranted(this))
                    "openAccessSettings" -> {
                        openNotificationAccessSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                // Settings screens vary by OEM; never let the lookup crash.
                result.success(false)
            }
        }
        NotifCapture.channel = notifChannel
    }

    override fun onDestroy() {
        // Drop the live-nudge target; the queue file keeps working without it.
        NotifCapture.channel = null
        super.onDestroy()
    }

    /** Open the system's notification-access screen, scoped to this app on
     *  API 30+ and falling back to the full list before that (or on OEMs
     *  that don't resolve the scoped intent). */
    private fun openNotificationAccessSettings() {
        val component = ComponentName(this, TxnNotificationListener::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    android.content.Intent(
                        android.provider.Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS
                    ).putExtra(
                        android.provider.Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        component.flattenToString()
                    )
                )
                return
            } catch (_: Exception) {
                // Fall through to the unscoped screen.
            }
        }
        startActivity(
            android.content.Intent(
                android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            )
        )
    }

    // ── Royal launcher-icon switching ──────────────────────────────────────
    // Variant name (matches the Dart RoyalAppIcon) → activity-alias class.
    private val iconAliases = mapOf(
        "bronze" to "MainActivityBronze",
        "silver" to "MainActivitySilver",
        "emerald" to "MainActivityEmerald",
        "golden" to "MainActivityGolden",
        "ruby" to "MainActivityRuby",
        "amethyst" to "MainActivityAmethyst",
    )

    /** Enable the launcher component for [icon] (a royal variant name) and
     *  disable the others; a null/unknown name restores the default icon.
     *  Exactly one launcher entry stays enabled so the icon never vanishes. */
    private fun setLauncherIcon(icon: String?) {
        val defaultComp = "$packageName.MainActivity"
        val targetComp = iconAliases[icon]?.let { "$packageName.$it" } ?: defaultComp
        val all = listOf(defaultComp) + iconAliases.values.map { "$packageName.$it" }
        // Enable the target first, then disable the rest — never leave zero
        // launcher components enabled (that would drop the icon entirely).
        packageManager.setComponentEnabledSetting(
            ComponentName(this, targetComp),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (comp in all) {
            if (comp == targetComp) continue
            packageManager.setComponentEnabledSetting(
                ComponentName(this, comp),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
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
