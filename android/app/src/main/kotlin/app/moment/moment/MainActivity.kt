package app.moment.moment

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (biometric app lock) requires a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

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
