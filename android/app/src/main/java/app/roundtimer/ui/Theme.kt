package app.roundtimer.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import app.roundtimer.R
import app.roundtimer.engine.Mode
import app.roundtimer.engine.PhaseLabel
import app.roundtimer.engine.Tint

val Bg = Color(0xFF100C0A)
val Ink = Color(0xFFF4EFEA)
val Gold = Color(0xFFE4B15A)
val Canvas = Color(0xFF1A120E)
val Work = Color(0xFFE23A2B)
val RestBlue = Color(0xFF3F86D6)
val LiveRestGreen = Color(0xFF298543)
val PrepareGold = Gold
val EndGreen = Color(0xFFD6E36A)
val StopwatchBlue = Color(0xFF7AC2F2)
val Muted = Ink.copy(alpha = 0.62f)
val InkDark = Color(0xFF1A100C)

/** iOS `Palette.ui` — Barlow Medium / SemiBold for chrome and settings. */
val Barlow = FontFamily(
    Font(R.font.barlow_medium, FontWeight.Normal),
    Font(R.font.barlow_medium, FontWeight.Medium),
    Font(R.font.barlow_semibold, FontWeight.SemiBold),
    Font(R.font.barlow_semibold, FontWeight.Bold),
)

/** iOS `Palette.display` — Barlow Condensed Bold for the main clock and phase titles. */
val BarlowCondensed = FontFamily(
    Font(R.font.barlow_condensed_bold, FontWeight.Bold),
    Font(R.font.barlow_condensed_bold, FontWeight.ExtraBold),
    Font(R.font.barlow_condensed_semibold, FontWeight.SemiBold),
)

fun tintColor(tint: Tint): Color = when (tint) {
    Tint.PREPARE -> PrepareGold
    Tint.WORK -> Work
    Tint.REST -> RestBlue
    Tint.END -> EndGreen
    Tint.STOPWATCH -> Ink
}

/** iOS `glowColor`: stopwatch uses blue; other modes use the phase tint. */
fun glowColor(tint: Tint): Color = when (tint) {
    Tint.STOPWATCH -> StopwatchBlue
    else -> tintColor(tint)
}

fun inkOn(tint: Tint): Color = if (tint == Tint.WORK || tint == Tint.REST) Color(0xFFFFF8F2) else InkDark

fun modeAccent(mode: Mode): Color = when (mode) {
    Mode.SPARRING -> Gold
    Mode.COUNTDOWN -> Work
    Mode.STOPWATCH -> StopwatchBlue
}

fun liveBackdrop(phase: PhaseLabel): Color = when (phase) {
    PhaseLabel.PREPARE -> Color.Black
    PhaseLabel.WORK -> Work
    PhaseLabel.REST -> LiveRestGreen
    else -> Bg
}

fun liveInk(phase: PhaseLabel): Color = when (phase) {
    PhaseLabel.PREPARE -> Ink
    PhaseLabel.WORK -> Color(0xFFFFF8F2)
    PhaseLabel.REST -> Color(0xFFFFF7F2)
    else -> Ink
}

/** Accent color for the ongoing session notification during live rounds (matches in-app backdrop). */
fun liveNotificationAccent(phase: PhaseLabel): Int = when (phase) {
    PhaseLabel.PREPARE -> 0xFF000000.toInt()
    PhaseLabel.WORK -> 0xFFE23A2B.toInt()
    PhaseLabel.REST -> 0xFF298543.toInt()
    else -> 0xFFE23A2B.toInt()
}

@Composable
fun RoundTimerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Bg,
            surface = Bg,
            primary = Gold,
            onPrimary = InkDark,
        ),
        typography = Typography().let { type ->
            type.copy(
                displayLarge = type.displayLarge.copy(
                    fontFamily = BarlowCondensed,
                    fontWeight = FontWeight.Bold,
                ),
                headlineLarge = type.headlineLarge.copy(fontFamily = BarlowCondensed, fontWeight = FontWeight.Bold),
                titleLarge = type.titleLarge.copy(fontFamily = Barlow, fontWeight = FontWeight.SemiBold),
                bodyLarge = type.bodyLarge.copy(fontFamily = Barlow, fontWeight = FontWeight.SemiBold),
                bodyMedium = type.bodyMedium.copy(fontFamily = Barlow, fontWeight = FontWeight.SemiBold),
                labelLarge = type.labelLarge.copy(fontFamily = Barlow, fontWeight = FontWeight.SemiBold),
            )
        },
        content = content,
    )
}