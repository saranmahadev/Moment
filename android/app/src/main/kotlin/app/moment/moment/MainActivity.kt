package app.moment.moment

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (biometric app lock) requires a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Before Flutter has drawn anything: the last choice the app made,
        // so a recreated activity is hidden from its first frame.
        applyPreviewHidden(previewPrefs().getBoolean(KEY_PREVIEW_HIDDEN, false))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The home screen widget: the app hands it a snapshot (never the
        // journal), and the widget hands taps back as links.
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.moment/widget")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val snapshot = call.arguments as? String
                    if (snapshot == null) {
                        result.error("bad_args", "publish needs the snapshot text", null)
                    } else {
                        MomentWidgetProvider.save(applicationContext, snapshot)
                        MomentWidgetProvider.updateAll(applicationContext)
                        result.success(null)
                    }
                }
                "requestPin" -> result.success(requestPin())
                "initialLink" -> result.success(takeLink(intent))
                else -> result.notImplemented()
            }
        }
        channel = ch

        // The app switcher preview: hidden while the app lock is on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.moment/screen_privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "setHidden") {
                    val hidden = call.arguments as? Boolean ?: false
                    previewPrefs().edit().putBoolean(KEY_PREVIEW_HIDDEN, hidden).apply()
                    applyPreviewHidden(hidden)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun previewPrefs() = getSharedPreferences("moment_screen_privacy", MODE_PRIVATE)

    /**
     * Android 13 and later can leave the Recents thumbnail out on its own.
     * Older versions only have FLAG_SECURE, which also blocks screenshots.
     */
    private fun applyPreviewHidden(hidden: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!hidden)
        } else if (hidden) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private companion object {
        const val KEY_PREVIEW_HIDDEN = "preview_hidden"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = takeLink(intent)
        if (link != null) channel?.invokeMethod("link", link)
    }

    /** The widget link in [intent], once: a rotation must not replay it. */
    private fun takeLink(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val link = intent.getStringExtra(MomentWidgetProvider.EXTRA_LINK)
        intent.removeExtra(MomentWidgetProvider.EXTRA_LINK)
        return link
    }

    private fun requestPin(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(AppWidgetManager::class.java) ?: return false
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(
            ComponentName(this, MomentWidgetProvider::class.java),
            null,
            null,
        )
    }
}
