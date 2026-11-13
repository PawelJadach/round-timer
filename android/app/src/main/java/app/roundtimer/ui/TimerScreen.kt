package app.roundtimer.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.roundtimer.R
import app.roundtimer.countdownSubtitle
import app.roundtimer.detailText
import app.roundtimer.engine.COUNTDOWN_PRESETS
import app.roundtimer.engine.Controls
import app.roundtimer.engine.Display
import app.roundtimer.engine.Mode
import app.roundtimer.engine.Nudge
import app.roundtimer.engine.SPARRING_PRESETS
import app.roundtimer.engine.Tint
import app.roundtimer.engine.formatClock
import app.roundtimer.engine.formatStopwatch
import app.roundtimer.engine.sparringTotalSeconds
import app.roundtimer.phaseText
import app.roundtimer.presetTitle

@Composable
fun TimerScreen(
    state: Display,
    language: String,
    onLanguage: (String) -> Unit,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onReset: () -> Unit,
    onAgain: () -> Unit,
    onLap: () -> Unit,
    onMode: (Mode) -> Unit,
    onPreset: (Int) -> Unit,
    onCountdown: (Int) -> Unit,
    onNudge: (Nudge, Int) -> Unit,
    onToggleSound: () -> Unit,
    onVolume: (Float) -> Unit,
    onVolumeCommit: () -> Unit,
) {
    val glow by animateColorAsState(tintColor(state.face.tint), tween(350), label = "glow")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Bg),
    ) {
        Box(
            modifier = Modifier
                .size(640.dp)
                .align(Alignment.TopCenter)
                .offset(y = (-180).dp)
                .background(
                    Brush.radialGradient(
                        listOf(glow.copy(alpha = 0.55f), Color.Transparent),
                    ),
                ),
        )
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .widthIn(max = 544.dp)
                .fillMaxHeight()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(start = 18.dp, end = 18.dp, top = 10.dp, bottom = 28.dp),
        ) {
            if (state.chromeVisible) {
                Header(state, language, onMode, onLanguage, onToggleSound)
                VolumeRow(state, onVolume, onVolumeCommit)
            }
            when {
                state.chromeVisible && state.mode == Mode.COUNTDOWN -> {
                    SettingsBlock(state, onPreset, onCountdown, onNudge, Modifier.verticalScroll(rememberScrollState()))
                    FaceBlock(state, Modifier.weight(1f))
                }
                state.chromeVisible && state.mode == Mode.SPARRING -> {
                    SettingsBlock(
                        state,
                        onPreset,
                        onCountdown,
                        onNudge,
                        Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState()),
                    )
                }
                else -> {
                    Column(Modifier.weight(1f)) {
                        if (state.showClock) FaceBlock(state, Modifier.weight(1f))
                        Laps(state)
                    }
                }
            }
            ControlsRow(state, onStart, onPause, onResume, onReset, onAgain, onLap)
            Credit(compact = !state.chromeVisible)
        }
    }
}

@Composable
private fun Header(
    state: Display,
    language: String,
    onMode: (Mode) -> Unit,
    onLanguage: (String) -> Unit,
    onToggleSound: () -> Unit,
) {
    val context = LocalContext.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .padding(4.dp),
        ) {
            Mode.entries.forEach { mode ->
                val label = when (mode) {
                    Mode.SPARRING -> stringResource(R.string.mode_sparring)
                    Mode.COUNTDOWN -> stringResource(R.string.mode_countdown)
                    Mode.STOPWATCH -> stringResource(R.string.mode_stopwatch)
                }
                val selected = state.mode == mode
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(if (selected) Color.White.copy(alpha = 0.14f) else Color.Transparent)
                        .clickable { onMode(mode) }
                        .padding(vertical = 10.dp)
                        .semantics { contentDescription = label },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = label,
                        color = if (selected) Color.White else Color.White.copy(alpha = 0.5f),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        Row(
            modifier = Modifier
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.08f))
                .semantics { contentDescription = context.getString(R.string.language) },
        ) {
            LanguageChip("EN", language == "en") { onLanguage("en") }
            LanguageChip("PL", language == "pl") { onLanguage("pl") }
        }
        val soundLabel = stringResource(if (state.sound) R.string.sound_off else R.string.sound_on)
        IconButton(
            onClick = onToggleSound,
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            Icon(
                painter = painterResource(if (state.sound) R.drawable.ic_volume_on else R.drawable.ic_volume_off),
                contentDescription = soundLabel,
                tint = Color.White,
            )
        }
    }
}

@Composable
private fun LanguageChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) Color.White.copy(alpha = 0.16f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontWeight = FontWeight.Bold, fontSize = 12.sp, color = if (selected) Color.White else Muted)
    }
}

@Composable
private fun VolumeRow(state: Display, onVolume: (Float) -> Unit, onCommit: () -> Unit) {
    val label = stringResource(R.string.volume)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .alpha(if (state.sound) 1f else 0.4f),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.width(72.dp), color = Muted, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        Slider(
            value = state.volume.toFloat(),
            onValueChange = onVolume,
            onValueChangeFinished = onCommit,
            valueRange = 0f..100f,
            modifier = Modifier
                .weight(1f)
                .semantics { contentDescription = label },
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = Color.White,
                inactiveTrackColor = Color.White.copy(alpha = 0.22f),
            ),
        )
        Text(
            text = state.volume.toString(),
            modifier = Modifier.width(36.dp),
            color = Muted,
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            textAlign = TextAlign.End,
        )
    }
}

@Composable
private fun SettingsBlock(
    state: Display,
    onPreset: (Int) -> Unit,
    onCountdown: (Int) -> Unit,
    onNudge: (Nudge, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.padding(top = 8.dp)) {
        if (state.mode == Mode.COUNTDOWN) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                COUNTDOWN_PRESETS.forEach { preset ->
                    Chip(preset.title, LocalContext.current.countdownSubtitle(preset.subtitle), Modifier.weight(1f)) {
                        onCountdown(preset.seconds)
                    }
                }
            }
            Stepper(stringResource(R.string.setting_minutes), (state.settings.countdown / 60).toString(), Nudge.COUNTDOWN_MINUTES, onNudge)
            Stepper(
                stringResource(R.string.setting_seconds),
                (state.settings.countdown % 60).toString().padStart(2, '0'),
                Nudge.COUNTDOWN_SECONDS,
                onNudge,
            )
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                SPARRING_PRESETS.forEachIndexed { index, preset ->
                    Chip(LocalContext.current.presetTitle(preset.title), preset.detail, Modifier.weight(1f)) {
                        onPreset(index)
                    }
                }
            }
            Stepper(stringResource(R.string.setting_prepare), formatClock(state.settings.prepare.toLong()), Nudge.PREPARE, onNudge)
            Stepper(stringResource(R.string.setting_work), formatClock(state.settings.work.toLong()), Nudge.WORK, onNudge)
            Stepper(stringResource(R.string.setting_rest), formatClock(state.settings.rest.toLong()), Nudge.REST, onNudge)
            Stepper(stringResource(R.string.setting_rounds), state.settings.rounds.toString(), Nudge.ROUNDS, onNudge)
            Text(
                text = stringResource(R.string.setting_total, formatClock(sparringTotalSeconds(state.settings).toLong())),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                color = Muted,
                textAlign = TextAlign.Center,
                fontSize = 14.sp,
            )
        }
    }
}

@Composable
private fun Chip(title: String, detail: String, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(13.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(
            detail,
            color = Muted,
            fontSize = 10.sp,
            lineHeight = 12.sp,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun Stepper(title: String, value: String, key: Nudge, onNudge: (Nudge, Int) -> Unit) {
    val less = stringResource(R.string.less)
    val more = stringResource(R.string.more)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        Spacer(Modifier.weight(1f))
        StepButton("−", "$less $title") { onNudge(key, -1) }
        Text(
            value,
            modifier = Modifier.width(72.dp),
            textAlign = TextAlign.Center,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
        )
        StepButton("+", "$more $title") { onNudge(key, 1) }
    }
}

@Composable
private fun StepButton(label: String, description: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.08f))
            .clickable(onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun FaceBlock(state: Display, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val phase = context.phaseText(state.face.phase)
    val detail = context.detailText(state.face.detail)
    val wide = state.face.text.length > 5
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.semantics { contentDescription = "$phase ${state.face.text}" },
        ) {
            Text(
                text = phase,
                color = tintColor(state.face.tint),
                fontWeight = FontWeight.Bold,
                fontSize = if (state.chromeVisible) 14.sp else 22.sp,
                letterSpacing = 0.16.em,
            )
            Text(
                text = state.face.text,
                fontWeight = FontWeight.ExtraBold,
                fontSize = faceSize(wide, state.chromeVisible),
                letterSpacing = (-0.04).em,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
            Text(
                text = detail,
                color = Muted,
                fontSize = if (state.chromeVisible) 18.sp else 22.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(top = 6.dp),
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun faceSize(wide: Boolean, setup: Boolean): androidx.compose.ui.unit.TextUnit {
    val density = LocalDensity.current
    return with(density) {
        val base = if (setup) 72.dp else if (wide) 64.dp else 108.dp
        base.toSp()
    }
}

@Composable
private fun Laps(state: Display) {
    if (state.laps.isEmpty()) return
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = 132.dp)
            .verticalScroll(rememberScrollState()),
    ) {
        state.laps.forEach { lap ->
            Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                Text(lap.id.toString(), modifier = Modifier.width(28.dp), color = Muted)
                Text(formatStopwatch(lap.split), color = Muted)
                Spacer(Modifier.weight(1f))
                Text(formatStopwatch(lap.total), fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun ControlsRow(
    state: Display,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onReset: () -> Unit,
    onAgain: () -> Unit,
    onLap: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        when (state.controls) {
            Controls.START -> PrimaryButton(
                stringResource(R.string.action_start),
                state.face.tint,
                state.canStart,
                Modifier.weight(1f),
                onStart,
            )
            Controls.RESET_PAUSE -> {
                SecondaryButton(stringResource(R.string.action_reset), Modifier.weight(1f), onReset)
                PlainButton(stringResource(R.string.action_pause), Modifier.weight(1f), onPause)
            }
            Controls.LAP_PAUSE -> {
                SecondaryButton(stringResource(R.string.action_lap), Modifier.weight(1f), onLap)
                PlainButton(stringResource(R.string.action_pause), Modifier.weight(1f), onPause)
            }
            Controls.RESET_RESUME -> {
                SecondaryButton(stringResource(R.string.action_reset), Modifier.weight(1f), onReset)
                PrimaryButton(stringResource(R.string.action_resume), state.face.tint, true, Modifier.weight(1f), onResume)
            }
            Controls.RESET_AGAIN -> {
                SecondaryButton(stringResource(R.string.action_reset), Modifier.weight(1f), onReset)
                PrimaryButton(stringResource(R.string.action_again), Tint.END, true, Modifier.weight(1f), onAgain)
            }
        }
    }
}

@Composable
private fun PrimaryButton(label: String, tint: Tint, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .height(58.dp)
            .alpha(if (enabled) 1f else 0.4f),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = tintColor(tint),
            contentColor = inkOn(tint),
            disabledContainerColor = tintColor(tint),
            disabledContentColor = inkOn(tint),
        ),
    ) {
        Text(label, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
    }
}

@Composable
private fun PlainButton(label: String, modifier: Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = modifier.height(58.dp),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Color.Black),
    ) {
        Text(label, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
    }
}

@Composable
private fun SecondaryButton(label: String, modifier: Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = modifier.height(58.dp),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White.copy(alpha = 0.08f),
            contentColor = Color.White,
        ),
    ) {
        Text(label, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
    }
}

@Composable
private fun Credit(compact: Boolean) {
    val lead = stringResource(R.string.hint_lead)
    val link = TextLinkStyles(SpanStyle(color = Muted, textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline))
    val text = buildAnnotatedString {
        append(lead)
        pushLink(LinkAnnotation.Url("https://freesound.org/s/66952/", link))
        append("Benboncan")
        pop()
        append(", ")
        pushLink(LinkAnnotation.Url("https://creativecommons.org/licenses/by/4.0/", link))
        append("CC BY 4.0")
        pop()
        append(".")
    }
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = if (compact) 6.dp else 12.dp),
        color = Muted,
        fontSize = if (compact) 11.sp else 12.sp,
        textAlign = TextAlign.Center,
    )
}
