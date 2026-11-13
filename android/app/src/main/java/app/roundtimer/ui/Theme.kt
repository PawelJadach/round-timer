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
import app.roundtimer.engine.Tint

val Bg = Color(0xFF0E0F12)
val Work = Color(0xFFFF4E2E)
val Rest = Color(0xFF2EBDF8)
val Prepare = Color(0xFFFFBC4D)
val EndGreen = Color(0xFF7DDB73)
val StopwatchInk = Color(0xFFF2F2F5)
val Muted = Color.White.copy(alpha = 0.62f)
val InkDark = Color(0xFF141414)

val Outfit = FontFamily(
    Font(R.font.outfit_regular, FontWeight.Normal),
    Font(R.font.outfit_semibold, FontWeight.SemiBold),
    Font(R.font.outfit_bold, FontWeight.Bold),
    Font(R.font.outfit_extrabold, FontWeight.ExtraBold),
)

fun tintColor(tint: Tint): Color = when (tint) {
    Tint.PREPARE -> Prepare
    Tint.WORK -> Work
    Tint.REST -> Rest
    Tint.END -> EndGreen
    Tint.STOPWATCH -> StopwatchInk
}

fun inkOn(tint: Tint): Color = if (tint == Tint.WORK || tint == Tint.REST) Color.White else InkDark

@Composable
fun RoundTimerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Bg,
            surface = Bg,
            primary = Work,
            onPrimary = Color.White,
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
