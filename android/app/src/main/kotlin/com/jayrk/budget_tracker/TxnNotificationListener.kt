package com.jayrk.budget_tracker

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/**
 * Capture of payment-app notifications ("₹250 paid to …"), the second
 * transaction source next to bank SMS. Exists because banks are switching off
 * SMS for small-value UPI (HDFC: no SMS under ₹100), which only the payment
 * app's own notification still records.
 *
 * PRIVACY CONTRACT — the reason this file is written the way it is:
 * a notification listener can technically see every notification on the
 * device. Budgetify's promise is that anything not from a known payment app
 * is discarded HERE, in [onNotificationPosted]'s first check, before it can
 * reach Dart, the database, a log line, or the queue file. The allowlist
 * below is the single source of truth for what "a known payment app" means;
 * the Dart side keeps a mirror only to label sources in the UI, and drops
 * anything it doesn't recognise as a second gate.
 *
 * Delivery is a file queue, not a method channel: the service must work with
 * no Flutter engine alive (payment at 2 AM, app long killed). Events are
 * appended as JSON-lines to [NotifCapture.queueFile]; Dart drains the file on
 * launch/resume and from the hourly WorkManager scan, and remembers how far
 * it has read via a consumed-watermark preference. Draining is idempotent
 * (the transaction fingerprint dedupes replays), so the watermark is an
 * optimisation, never a correctness requirement. When an engine happens to
 * be alive, [NotifCapture.nudge] additionally triggers an immediate drain so
 * capture feels real-time.
 */
class TxnNotificationListener : NotificationListenerService() {

    /** Recently enqueued content hashes → post time; suppresses the
     *  updated/re-posted copies of the same notification that payment apps
     *  emit (progress → success rewrites, etc.). */
    private val recentHashes = LinkedHashMap<Int, Long>()

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            // 1) THE privacy gate. Anything not on the payment-app allowlist
            //    is dropped before it exists anywhere at all.
            if (!NotifCapture.ALLOWLIST.containsKey(sbn.packageName)) return

            // 2) Feature gate — user's in-app toggle (Flutter prefs).
            if (!NotifCapture.isEnabled(this)) return

            val n = sbn.notification ?: return

            // 3) Shapes that never describe a single completed payment:
            //    group summaries ("3 new messages") and ongoing/foreground
            //    notifications (progress, media, live activity).
            if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
            if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return

            val extras = n.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            if (title.isBlank() && text.isBlank() && big.isBlank()) return

            // 4) Same visible content within the dedupe window → an update
            //    of a notification we already queued, not a new payment.
            val hash = (sbn.packageName + "|" + title + "|" + text).hashCode()
            val now = System.currentTimeMillis()
            synchronized(recentHashes) {
                recentHashes.entries.removeAll { now - it.value > DEDUPE_WINDOW_MS }
                if (recentHashes.containsKey(hash)) return
                recentHashes[hash] = now
                while (recentHashes.size > DEDUPE_MAX) {
                    recentHashes.remove(recentHashes.keys.first())
                }
            }

            val event = JSONObject()
                .put("pkg", sbn.packageName)
                .put("title", title)
                .put("text", text)
                .put("big", big)
                .put("posted", sbn.postTime)
                .put("key", sbn.key ?: "")

            NotifCapture.append(this, event.toString())
            NotifCapture.nudge()
        } catch (_: Exception) {
            // A malformed notification must never take the app's process
            // down with it. Missing a single event is always the lesser harm.
        }
    }

    companion object {
        private const val DEDUPE_WINDOW_MS = 10 * 60 * 1000L
        private const val DEDUPE_MAX = 64
    }
}

/**
 * Shared state between [TxnNotificationListener] (binder threads, any time)
 * and the Flutter side (MainActivity's method channel + direct file reads
 * from Dart). Everything here is defensive: all callers swallow failures.
 */
object NotifCapture {

    /**
     * Payment apps whose notifications may be read — nothing else, ever.
     * Package → short label used in the Dart mirror and the UI.
     *
     * Deliberately absent: WhatsApp (messaging app — reading its
     * notifications would mean reading personal messages, even though
     * WhatsApp Pay exists) and bank apps (their payments are already
     * covered by bank SMS, which carries richer detail).
     */
    val ALLOWLIST: Map<String, String> = mapOf(
        "com.google.android.apps.nbu.paisa.user" to "GPay",
        "com.phonepe.app" to "PhonePe",
        "net.one97.paytm" to "Paytm",
        "in.org.npci.upiapp" to "BHIM",
        "com.dreamplug.androidapp" to "CRED",
        "in.amazon.mShop.android.shopping" to "Amazon Pay",
        "com.mobikwik_new" to "MobiKwik",
        "com.freecharge.android" to "Freecharge",
    )

    /** JSON-lines queue the listener appends to and Dart drains. Lives in
     *  filesDir, which path_provider exposes to Dart as the application
     *  support directory — same file, both worlds. */
    private const val QUEUE_FILE = "notif_capture_queue.jsonl"

    /** Trim thresholds: a queue only grows while the user never opens the
     *  app; keep the newest [TRIM_KEEP] lines once it passes [TRIM_AT]. */
    private const val TRIM_AT = 800
    private const val TRIM_KEEP = 500

    /** Live engine's channel for the "queue changed" nudge; null when no
     *  activity is up. Set/cleared by MainActivity. */
    @Volatile
    var channel: MethodChannel? = null

    private val lock = Any()

    fun queueFile(context: Context): File = File(context.filesDir, QUEUE_FILE)

    /** The user's in-app toggle, read from Flutter's SharedPreferences file
     *  (shared_preferences stores "flutter."-prefixed keys there). Defaults
     *  to false: with the feature off, the listener stores nothing even if
     *  system-level notification access happens to be granted. */
    fun isEnabled(context: Context): Boolean = try {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.notif_capture_enabled", false)
    } catch (_: Exception) {
        false
    }

    /** Append one event line; trim the file when it outgrows the cap. The
     *  trim rewrites to a temp file and renames over, so a concurrent Dart
     *  read sees either the old or the new file — never a torn one. */
    fun append(context: Context, line: String) {
        synchronized(lock) {
            val file = queueFile(context)
            file.appendText(line + "\n")
            try {
                val lines = file.readLines()
                if (lines.size > TRIM_AT) {
                    val tmp = File(context.filesDir, "$QUEUE_FILE.tmp")
                    tmp.writeText(
                        lines.takeLast(TRIM_KEEP).joinToString("\n", postfix = "\n")
                    )
                    if (!tmp.renameTo(file)) tmp.delete()
                }
            } catch (_: Exception) {
                // Trim is best-effort; the append above already landed.
            }
        }
    }

    /** Ask a live engine (if any) to drain the queue now. Fire-and-forget:
     *  when no activity is running this is a no-op and the queue waits for
     *  the next launch/resume/background scan. */
    fun nudge() {
        val ch = channel ?: return
        Handler(Looper.getMainLooper()).post {
            try {
                ch.invokeMethod("queueChanged", null)
            } catch (_: Exception) {
                // Engine torn down between the null-check and the call.
            }
        }
    }

    /** Whether the system has granted this app notification access. */
    fun isAccessGranted(context: Context): Boolean = try {
        val flat = android.provider.Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: ""
        flat.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == context.packageName
        }
    } catch (_: Exception) {
        false
    }
}
