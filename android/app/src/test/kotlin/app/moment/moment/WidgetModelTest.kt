package app.moment.moment

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the widget draws from the snapshot the app wrote. The snapshot's own
 * rules (streak, grace days) live in Dart; this only decides how it looks on
 * the day the widget is drawn, which can be later than the day it was written.
 */
class WidgetModelTest {
    // Wednesday 18 November 2026.
    private val wednesday = LocalDate.of(2026, 11, 18)

    private fun snapshot(
        show: Boolean = true,
        asOf: String = "2026-11-18",
        streak: Int = 6,
        endsOn: String? = "2026-11-19",
        week: String = "[true,true,true,false,false,false,false]",
        version: Int = 1,
    ) = """{"v":$version,"show":$show,"asOf":"$asOf","streak":$streak,""" +
        """"endsOn":${endsOn?.let { "\"$it\"" } ?: "null"},"week":$week}"""

    @Test
    fun drawsTheStreakAndThisWeekOnTheDayItWasWritten() {
        val s = WidgetModel.parse(snapshot(), wednesday)

        assertEquals(Mode.STREAK, s.mode)
        assertEquals(6, s.streak)
        assertTrue(s.loggedToday)
        assertFalse(s.atRisk)
        assertEquals(listOf(true, true, true, false, false, false, false), s.week)
        assertEquals(2, s.todayIndex)
        assertEquals("Logged today", s.stateText())
        assertEquals("Streak, 6 days, logged today", s.describe())
    }

    @Test
    fun aStreakWithTodayStillToLogIsAtRisk() {
        val s = WidgetModel.parse(
            snapshot(week = "[true,true,false,false,false,false,false]", streak = 5),
            wednesday,
        )

        assertFalse(s.loggedToday)
        assertTrue(s.atRisk)
        assertEquals("Log today", s.stateText())
        assertEquals("Streak, 5 days, not logged yet today", s.describe())
    }

    @Test
    fun theNextMorningTheSameStreakIsAtRiskWithoutTheAppRunning() {
        val thursday = wednesday.plusDays(1)

        val s = WidgetModel.parse(snapshot(), thursday)

        assertEquals(6, s.streak)
        assertFalse(s.loggedToday)
        assertTrue(s.atRisk)
        // The week is still Monday's, and Thursday has no log.
        assertEquals(listOf(true, true, true, false, false, false, false), s.week)
        assertEquals(3, s.todayIndex)
    }

    @Test
    fun afterTheStreakEndsDateItIsGone() {
        val friday = wednesday.plusDays(2)

        val s = WidgetModel.parse(snapshot(endsOn = "2026-11-19"), friday)

        assertEquals(0, s.streak)
        assertFalse(s.atRisk)
        assertEquals("Start a streak", s.stateText())
        assertEquals("No streak yet. Log today to start one.", s.describe())
    }

    @Test
    fun aNewWeekStartsWithNoSquaresFilled() {
        val nextMonday = LocalDate.of(2026, 11, 23)

        val s = WidgetModel.parse(snapshot(endsOn = "2026-11-24"), nextMonday)

        assertEquals(List(7) { false }, s.week)
        assertEquals(0, s.todayIndex)
        assertEquals(6, s.streak)
    }

    @Test
    fun withTheStreakSwitchedOffOnlyTheButtonsShow() {
        val s = WidgetModel.parse(snapshot(show = false, streak = 0, endsOn = null), wednesday)

        assertEquals(Mode.BUTTONS_ONLY, s.mode)
        assertEquals(0, s.streak)
        assertEquals("Moment. Add a log.", s.describe())
    }

    @Test
    fun nothingWrittenYetAsksToOpenTheApp() {
        for (text in listOf(null, "", "not json", "{}", snapshot(version = 2))) {
            val s = WidgetModel.parse(text, wednesday)

            assertEquals(text, Mode.UNSET, s.mode)
            assertEquals("Moment. Open the app to start.", s.describe())
        }
    }

    @Test
    fun aWeekThatIsNotSevenDaysIsDamaged() {
        val s = WidgetModel.parse(snapshot(week = "[true,true]"), wednesday)

        assertEquals(Mode.UNSET, s.mode)
    }

    @Test
    fun oneDayIsSingular() {
        val s = WidgetModel.parse(
            snapshot(streak = 1, week = "[false,false,true,false,false,false,false]"),
            wednesday,
        )

        assertEquals("Streak, 1 day, logged today", s.describe())
    }

    @Test
    fun picksTheLayoutFromTheSizeTheLauncherGives() {
        // Widths and heights in dp, as the launcher reports them.
        assertEquals(WidgetLayout.WIDE, WidgetLayout.choose(320, 150))
        assertEquals(WidgetLayout.ROW, WidgetLayout.choose(320, 70))
        assertEquals(WidgetLayout.SMALL, WidgetLayout.choose(160, 160))
        assertEquals(WidgetLayout.MINI, WidgetLayout.choose(160, 70))
        assertEquals(WidgetLayout.SMALL, WidgetLayout.choose(110, 140))
        assertEquals(WidgetLayout.WIDE, WidgetLayout.choose(250, 130))
        // Nothing reported yet: the 2 x 2 layout.
        assertEquals(WidgetLayout.SMALL, WidgetLayout.choose(0, 0))
    }
}
