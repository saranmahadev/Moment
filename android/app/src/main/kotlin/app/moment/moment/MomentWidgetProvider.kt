package app.moment.moment

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.LocalDate

/**
 * The home screen widget: the streak and a button for each kind of log.
 *
 * It never opens the journal. It reads one small snapshot that the app wrote
 * into [PREFS] (see lib/widgets/widget_snapshot.dart) and draws it; a tap
 * starts the app with a link saying where to go.
 */
class MomentWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) update(context, manager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: android.os.Bundle,
    ) {
        update(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> updateAll(context)
        }
    }

    companion object {
        const val PREFS = "moment_widget"
        const val KEY_SNAPSHOT = "snapshot"
        const val EXTRA_LINK = "moment_link"

        private val TILES = listOf(
            Triple(R.id.tile_text, "text", "moment://add/text"),
            Triple(R.id.tile_emoji, "emoji", "moment://add/emoji"),
            Triple(R.id.tile_photo, "photo", "moment://add/photo"),
            Triple(R.id.tile_video, "video", "moment://add/video"),
            Triple(R.id.tile_audio, "audio", "moment://add/audio"),
            Triple(R.id.tile_location, "location", "moment://add/location"),
        )

        private val WEEK = listOf(
            R.id.week_0, R.id.week_1, R.id.week_2, R.id.week_3,
            R.id.week_4, R.id.week_5, R.id.week_6,
        )

        fun save(context: Context, snapshot: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_SNAPSHOT, snapshot).apply()
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MomentWidgetProvider::class.java))
            for (id in ids) update(context, manager, id)
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val options = manager.getAppWidgetOptions(id)
            val layout = WidgetLayout.choose(
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0),
                options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0),
            )
            val state = WidgetModel.parse(
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getString(KEY_SNAPSHOT, null),
                LocalDate.now(),
            )
            manager.updateAppWidget(id, build(context, layout, state))
        }

        private fun build(context: Context, layout: WidgetLayout, state: WidgetState): RemoteViews {
            val res = when (layout) {
                WidgetLayout.SMALL -> R.layout.moment_widget_small
                WidgetLayout.ROW -> R.layout.moment_widget_row
                WidgetLayout.WIDE -> R.layout.moment_widget_wide
                WidgetLayout.MINI -> R.layout.moment_widget_mini
            }
            val views = RemoteViews(context.packageName, res)
            val showStreak = state.mode == Mode.STREAK

            views.setViewVisibility(R.id.streak_group, if (showStreak) android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.plain_group, if (showStreak) android.view.View.GONE else android.view.View.VISIBLE)

            if (showStreak) {
                views.setTextViewText(R.id.count, state.streak.toString())
                views.setContentDescription(R.id.streak_group, state.describe())
                views.setOnClickPendingIntent(R.id.streak_group, link(context, "streaks", "moment://streaks"))
                if (layout != WidgetLayout.MINI) bindState(context, views, layout, state)
                if (layout == WidgetLayout.WIDE) bindWeek(views, state)
            } else {
                views.setTextViewText(
                    R.id.plain_group,
                    context.getString(
                        if (state.mode == Mode.UNSET) R.string.widget_unset else R.string.widget_buttons_only,
                    ),
                )
                views.setContentDescription(R.id.plain_group, state.describe())
                views.setOnClickPendingIntent(R.id.plain_group, link(context, "open", null))
            }

            val tiles = if (layout == WidgetLayout.MINI) TILES.take(1) else TILES
            for ((viewId, name, uri) in tiles) {
                views.setOnClickPendingIntent(viewId, link(context, name, uri))
            }
            return views
        }

        private fun bindState(context: Context, views: RemoteViews, layout: WidgetLayout, state: WidgetState) {
            val text = state.stateText()
            if (layout == WidgetLayout.ROW) {
                // Four cells and one row leave no room for a label: the
                // count and the flame carry it, and the pill stays hidden.
                views.setViewVisibility(R.id.state, android.view.View.GONE)
                return
            }
            views.setTextViewText(R.id.state, text)
            if (state.loggedToday && state.streak > 0) {
                views.setInt(R.id.state, "setBackgroundResource", R.drawable.pill_solid)
                views.setTextColor(R.id.state, context.getColor(R.color.widget_on_ink))
            } else {
                views.setInt(R.id.state, "setBackgroundResource", R.drawable.pill_risk)
                views.setTextColor(R.id.state, context.getColor(R.color.widget_ink))
            }
        }

        private fun bindWeek(views: RemoteViews, state: WidgetState) {
            for ((i, viewId) in WEEK.withIndex()) {
                val on = state.week[i]
                val today = i == state.todayIndex
                val background = when {
                    on && today -> R.drawable.cell_on_today
                    on -> R.drawable.cell_on
                    today -> R.drawable.cell_off_today
                    else -> R.drawable.cell_off
                }
                views.setInt(viewId, "setBackgroundResource", background)
            }
        }

        /** Starts the app, saying where to go; [uri] null just opens it. */
        private fun link(context: Context, key: String, uri: String?): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                // The action makes each button's PendingIntent its own;
                // extras alone would not (Intent.filterEquals ignores them).
                action = "app.moment.widget.$key"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                if (uri != null) putExtra(EXTRA_LINK, uri)
            }
            return PendingIntent.getActivity(
                context,
                key.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
