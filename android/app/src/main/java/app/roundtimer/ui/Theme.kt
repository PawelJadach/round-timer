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

val Outfit = FontFamily(
    Font(R.font.outfit_regular, FontWeight.Normal),
    Font(R.font.outfit_semibold, FontWeight.SemiBold),
    Font(R.font.outfit_bold, FontWeight.Bold),
    Font(R.font.outfit_extrabold, FontWeight.ExtraBold),
)

fun tintColor(tint: Tint): Color = when (tint) {
    Tint.PREPARE -> PrepareGold
    Tint.WORK -> Work
    Tint.REST -> RestBlue
    Tint.END -> EndGreen
    Tint.STOPWATCH -> Ink
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
            val family = Outfit
            type.copy(
                displayLarge = type.displayLarge.copy(fontFamily = family),
                headlineLarge = type.headlineLarge.copy(fontFamily = family),
                titleLarge = type.titleLarge.copy(fontFamily = family),
                bodyLarge = type.bodyLarge.copy(fontFamily = family),
                bodyMedium = type.bodyMedium.copy(fontFamily = family),
                labelLarge = type.labelLarge.copy(fontFamily = family),
            )
        },
        content = content,
    )
}