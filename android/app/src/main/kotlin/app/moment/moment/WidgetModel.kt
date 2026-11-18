package app.moment.moment

import java.time.DayOfWeek
import java.time.LocalDate
import org.json.JSONObject

/** What the widget shows in its streak half. */
enum class Mode {
    /** Nothing written yet, or the text could not be read. */
    UNSET,

    /** The owner chose buttons only (or turned streaks off). */
    BUTTONS_ONLY,
    STREAK,
}

/**
 * What to draw today, worked out from the snapshot the app wrote.
 *
 * The app does the streak arithmetic (grace days and all) in Dart and says in
 * the snapshot how long the streak stays alive. This only compares today with
 * those dates, so a widget drawn the morning after is right without the app.
 */
data class WidgetState(
    val mode: Mode,
    val streak: Int,
    val loggedToday: Boolean,
    /** This week, Monday first. */
    val week: List<Boolean>,
    /** 0 for Monday. */
    val todayIndex: Int,
) {
    val atRisk: Boolean get() = mode == Mode.STREAK && streak > 0 && !loggedToday

    fun stateText(): String = when {
        mode != Mode.STREAK || streak == 0 -> "Start a streak"
        loggedToday -> "Logged today"
        else -> "Log today"
    }

    /** What a screen reader says for the whole widget. */
    fun describe(): String = when {
        mode == Mode.UNSET -> "Moment. Open the app to start."
        mode == Mode.BUTTONS_ONLY -> "Moment. Add a log."
        streak == 0 -> "No streak yet. Log today to start one."
        else -> {
            val days = if (streak == 1) "1 day" else "$streak days"
            val today = if (loggedToday) "logged today" else "not logged yet today"
            "Streak, $days, $today"
        }
    }
}

object WidgetModel {
    const val VERSION = 1

    fun parse(text: String?, today: LocalDate): WidgetState {
        val todayIndex = today.dayOfWeek.value - 1
        val unset = WidgetState(Mode.UNSET, 0, false, List(7) { false }, todayIndex)
        if (text.isNullOrBlank()) return unset
        return try {
            val json = JSONObject(text)
            if (json.getInt("v") != VERSION) return unset
            if (!json.getBoolean("show")) {
                return WidgetState(Mode.BUTTONS_ONLY, 0, false, List(7) { false }, todayIndex)
            }
            val asOf = LocalDate.parse(json.getString("asOf"))
            val streak = json.getInt("streak")
            val endsOn = if (json.isNull("endsOn")) null else LocalDate.parse(json.getString("endsOn"))
            val array = json.getJSONArray("week")
            if (array.length() != 7) return unset
            val stored = List(7) { array.getBoolean(it) }

            val alive = streak > 0 && endsOn != null && !today.isAfter(endsOn)
            // The squares are this week's. A later week has none yet (any log
            // would have made the app write a new snapshot).
            val week = if (weekStart(today) == weekStart(asOf) || today.isBefore(asOf)) {
                stored
            } else {
                List(7) { false }
            }
            WidgetState(
                mode = Mode.STREAK,
                streak = if (alive) streak else 0,
                loggedToday = today == asOf && stored[todayIndex],
                week = week,
                todayIndex = todayIndex,
            )
        } catch (e: Exception) {
            unset
        }
    }

    private fun weekStart(day: LocalDate): LocalDate =
        day.minusDays((day.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())
}

/** The four layouts, chosen from the size the launcher gives the widget. */
enum class WidgetLayout {
    /** 2 x 2: streak on top, six buttons below. */
    SMALL,

    /** 4 x 1: streak, then a row of six buttons. */
    ROW,

    /** 4 x 2: streak and week on the left, labelled buttons on the right. */
    WIDE,

    /** 2 x 1: streak and a button to write a text log. */
    MINI;

    companion object {
        /** [widthDp] and [heightDp] are the launcher's minimum size for the widget. */
        fun choose(widthDp: Int, heightDp: Int): WidgetLayout {
            if (widthDp == 0 && heightDp == 0) return SMALL
            return if (widthDp >= 250) {
                if (heightDp >= 130) WIDE else ROW
            } else {
                if (heightDp >= 140) SMALL else MINI
            }
        }
    }
}
