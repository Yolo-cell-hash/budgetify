package com.jayrk.budget_tracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
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
                try {
                    when (call.method) {
                        "setIcon" -> {
                            setLauncherIcon(call.argument<String>("icon"))
                            result.success(true)
                        }
                        // Bring the app straight back up on the newly enabled
                        // launcher component, instead of leaving the user on
                        // their home screen to reopen it by hand.
                        "relaunch" -> result.success(relaunch())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }

        // When this package was FIRST installed on this device. Unlike
        // SharedPreferences this is not app data, so it survives "Clear data"
        // (and app updates); it resets only on uninstall or factory reset.
        // The silent trial clock uses it as a floor on its first-launch
        // anchor, so wiping app data can't hand out a fresh free window.
        // No permission required — we only ever ask about our own package.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "budgetify/install_info")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "firstInstallTime" ->
                            result.success(
                                packageManager.getPackageInfo(packageName, 0).firstInstallTime
                            )
                        "readTrialAnchor" -> {
                            val ms = anchorPrefs().getLong(TRIAL_ANCHOR_KEY, 0L)
                            result.success(if (ms > 0L) ms else null)
                        }
                        "writeTrialAnchor" -> {
                            val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                            if (ms > 0L) {
                                anchorPrefs().edit().putLong(TRIAL_ANCHOR_KEY, ms).apply()
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // Null means "unknown" on the Dart side: the anchor simply
                    // stands as stored. Never worth crashing over.
                    result.success(null)
                }
            }
    }

    /**
     * The install date, and nothing else, in a file of its own.
     *
     * Every other preference the app owns lives in Flutter's shared blob,
     * which `res/xml/backup_rules.xml` excludes from Android's automatic
     * backup. This file is the sole inclusion, so the only thing that ever
     * reaches the user's Google Drive is one timestamp — never a transaction,
     * a message, or a balance. Separating it is what makes that promise
     * expressible at all: Android's backup rules select whole files, so an
     * anchor sharing a file with everything else could not be backed up
     * alone.
     *
     * Being restored on reinstall is the entire point. Android puts this file
     * back before the app's first launch, so a reinstall resumes the free
     * window instead of starting a new one.
     */
    private fun anchorPrefs() =
        getSharedPreferences(TRIAL_ANCHOR_PREFS, Context.MODE_PRIVATE)

    private companion object {
        /** Must match `backup_rules.xml` / `data_extraction_rules.xml`. */
        const val TRIAL_ANCHOR_PREFS = "budgetify_trial_anchor"
        const val TRIAL_ANCHOR_KEY = "first_launch_at"
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
        "sapphire" to "MainActivitySapphire",
        "absinthe" to "MainActivityAbsinthe",
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

    /** Restart the app on whichever launcher component is currently enabled.
     *
     *  Used right after an icon swap. The swap itself does not kill us —
     *  [setLauncherIcon] passes DONT_KILL_APP — but the running task is
     *  attached to a component that has just been disabled, and launchers
     *  pick the new icon up reliably once the app has been through a fresh
     *  start. Rather than closing and asking the user to reopen it by hand,
     *  we relaunch: same fresh start, no trip to the home screen.
     *
     *  The target is resolved through the package manager rather than
     *  hardcoded, so it always lands on whichever alias `setLauncherIcon`
     *  just enabled. Returns false when no launch intent resolves, which lets
     *  Dart fall back to simply closing. */
    private fun relaunch(): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return false
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK,
        )
        // A beat for the component change to settle before the new task
        // resolves against it; without it the relaunch can race the swap and
        // come back up on the component we just disabled.
        Handler(Looper.getMainLooper()).postDelayed({
            startActivity(intent)
            finish()
        }, 220)
        return true
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
