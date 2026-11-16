package app.roundtimer.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.roundtimer.R
import app.roundtimer.detailText
import app.roundtimer.phaseText
import app.roundtimer.engine.Controls
import app.roundtimer.engine.Detail
import app.roundtimer.engine.Display
import app.roundtimer.engine.Mode
import app.roundtimer.engine.Nudge
import app.roundtimer.engine.PhaseLabel
import app.roundtimer.engine.RunState
import app.roundtimer.engine.SPARRING_PRESETS
import app.roundtimer.engine.Tint
import app.roundtimer.engine.formatClock
import app.roundtimer.engine.formatStopwatch
import app.roundtimer.presetTitle
import kotlin.math.abs
import kotlin.math.max

@Composable
fun TimerScreen(
    state: Display,
    language: String,
    usesManualLanguage: Boolean,
    settingsOpen: Boolean,
    onSettingsOpen: (Boolean) -> Unit,
    onLanguage: (String) -> Unit,
    onFollowSystemLanguage: () -> Unit,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onReset: () -> Unit,
    onAgain: () -> Unit,
    onLap: () -> Unit,
    onMode: (Mode) -> Unit,
    onPreset: (Int) -> Unit,
    onNudge: (Nudge, Int) -> Unit,
    onToggleSound: () -> Unit,
    onVolume: (Float) -> Unit,
    onVolumeCommit: () -> Unit,
) {
    val livePhase = liveRoundsPhase(state)
    val backdrop = livePhase?.let { liveBackdrop(it) } ?: Bg
    val glowTint = if (livePhase == null) decorativeGlowTint(state) else null
    val glowTarget = glowTint?.let { glowColor(it) } ?: Color.Transparent
    val glowIdle = state.runState == RunState.IDLE
    val glow by animateColorAsState(
        glowTarget,
        if (glowIdle) snap() else tween(350),
        label = "glow",
    )
    Box(modifier = Modifier.fillMaxSize()) {
        Box(Modifier.matchParentSize().background(backdrop))
        if (glowTint != null) {
            DecorativeGlow(color = glow, modifier = Modifier.matchParentSize())
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(state.chromeVisible, state.mode) {
                    if (!state.chromeVisible) return@pointerInput
                    var total = 0f
                    detectHorizontalDragGestures(
                        onHorizontalDrag = { _, delta -> total += delta },
                        onDragEnd = {
                            if (abs(total) > 80f) {
                                val modes = Mode.entries
                                val index = modes.indexOf(state.mode)
                                val next = if (total < 0) {
                                    modes[(index + 1) % modes.size]
                                } else {
                                    modes[(index - 1 + modes.size) % modes.size]
                                }
                                onMode(next)
                            }
                            total = 0f
                        },
                    )
                },
        ) {
            val showStopwatchLaps = (state.runMode ?: state.mode) == Mode.STOPWATCH &&
                state.laps.isNotEmpty() &&
                state.runState != RunState.IDLE
            Column(
                modifier = Modifier
                    .weight(1f)
                    .align(Alignment.CenterHorizontally)
                    .widthIn(max = 560.dp)
                    .fillMaxWidth()
                    .windowInsetsPadding(WindowInsets.safeDrawing)
                    .padding(horizontal = 16.dp)
                    .then(
                        if (!showStopwatchLaps) {
                            Modifier.verticalScroll(rememberScrollState())
                        } else {
                            Modifier.fillMaxHeight()
                        },
                    ),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (state.chromeVisible) {
                    Spacer(Modifier.height(8.dp))
                    TopBar(state, onMode, onSettingsOpen)
                } else if (state.runState != RunState.IDLE) {
                    Spacer(Modifier.height(if (showStopwatchLaps) 20.dp else if (state.laps.isNotEmpty()) 20.dp else 48.dp))
                }
                if (state.showClock || state.runState != RunState.IDLE) {
                    FaceBlock(state, livePhase, Modifier.padding(vertical = if (state.chromeVisible) 12.dp else 24.dp))
                }
                if (showStopwatchLaps) {
                    Laps(
                        state,
                        Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                    )
                } else if (state.settingsVisible) {
                    SettingsBlock(state, onPreset, onNudge)
                }
            }
            ControlsBar(
                state,
                onStart,
                onPause,
                onResume,
                onReset,
                onAgain,
                onLap,
                Modifier
                    .fillMaxWidth()
                    .windowInsetsPadding(WindowInsets.safeDrawing)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
        SettingsSheet(
            visible = settingsOpen,
            state = state,
            language = language,
            usesManualLanguage = usesManualLanguage,
            onDismiss = { onSettingsOpen(false) },
            onToggleSound = onToggleSound,
            onVolume = onVolume,
            onVolumeCommit = onVolumeCommit,
            onLanguage = onLanguage,
            onFollowSystemLanguage = onFollowSystemLanguage,
        )
    }
}

/** One full-screen soft wash (iOS blurred circle), centered on the clock. */
@Composable
private fun DecorativeGlow(color: Color, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    BoxWithConstraints(
        modifier.graphicsLayer { clip = false },
    ) {
        val w = constraints.maxWidth.toFloat()
        val h = constraints.maxHeight.toFloat()
        val centerX = w / 2f
        val centerY = with(density) { (h / 2f) - 80.dp.toPx() }
        val radius = max(w, h) * 1.18f
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colorStops = arrayOf(
                            0f to color.copy(alpha = 0.38f),
                            0.14f to color.copy(alpha = 0.30f),
                            0.30f to color.copy(alpha = 0.20f),
                            0.48f to color.copy(alpha = 0.11f),
                            0.66f to color.copy(alpha = 0.05f),
                            0.82f to color.copy(alpha = 0.015f),
                            1f to Color.Transparent,
                        ),
                        center = Offset(centerX, centerY),
                        radius = radius,
                    ),
                ),
        )
    }
}

private fun liveRoundsPhase(state: Display): PhaseLabel? {
    if (state.runState != RunState.RUNNING && state.runState != RunState.PAUSED) return null
    val mode = state.runMode ?: state.mode
    if (mode != Mode.SPARRING) return null
    return when (state.face.phase) {
        PhaseLabel.PREPARE, PhaseLabel.WORK, PhaseLabel.REST -> state.face.phase
        else -> null
    }
}

private fun decorativeGlowTint(state: Display): Tint? {
    if (liveRoundsPhase(state) != null) return null
    if (state.runState == RunState.RUNNING || state.runState == RunState.PAUSED || state.runState == RunState.FINISHED) {
        return when (state.runMode ?: state.mode) {
            Mode.SPARRING -> null
            Mode.COUNTDOWN -> state.face.tint
            Mode.STOPWATCH -> Tint.STOPWATCH
        }
    }
    return state.face.tint
}

@Composable
private fun TopBar(state: Display, onMode: (Mode) -> Unit, onSettingsOpen: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(CircleShape)
                .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
                .padding(4.dp),
        ) {
            Mode.entries.forEach { mode ->
                val label = when (mode) {
                    Mode.SPARRING -> stringResource(R.string.mode_sparring)
                    Mode.COUNTDOWN -> stringResource(R.string.mode_countdown)
                    Mode.STOPWATCH -> stringResource(R.string.mode_stopwatch)
                }
                val accent = modeAccent(mode)
                val selected = state.mode == mode
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(if (selected) accent.copy(alpha = 0.2f) else Color.Transparent)
                        .then(if (selected) Modifier.border(1.dp, accent.copy(alpha = 0.55f), CircleShape) else Modifier)
                        .clickableNoRipple { onMode(mode) }
                        .padding(vertical = 10.dp)
                        .semantics { contentDescription = label },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        label,
                        color = if (selected) accent else Ink.copy(alpha = 0.48f),
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
                .clickableNoRipple { onSettingsOpen(true) },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.settings_title), tint = Ink)
        }
    }
}

@Composable
private fun SettingsBlock(state: Display, onPreset: (Int) -> Unit, onNudge: (Nudge, Int) -> Unit) {
    Column(Modifier.padding(top = 8.dp, bottom = 8.dp)) {
        if (state.mode == Mode.COUNTDOWN) {
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
            Spacer(Modifier.height(10.dp))
            Stepper(stringResource(R.string.setting_prepare), formatClock(state.settings.prepare.toLong()), Nudge.PREPARE, onNudge)
            Stepper(stringResource(R.string.setting_work), formatClock(state.settings.work.toLong()), Nudge.WORK, onNudge)
            Stepper(stringResource(R.string.setting_rest), formatClock(state.settings.rest.toLong()), Nudge.REST, onNudge)
            Stepper(stringResource(R.string.setting_rounds), state.settings.rounds.toString(), Nudge.ROUNDS, onNudge)
        }
    }
}

@Composable
private fun Chip(title: String, detail: String, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, Gold.copy(alpha = 0.32f), RoundedCornerShape(12.dp))
            .clickableNoRipple(onClick)
            .padding(vertical = 8.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            title,
            fontFamily = BarlowCondensed,
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            color = Ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(detail, color = Muted, fontSize = 11.sp, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
private fun Stepper(title: String, value: String, key: Nudge, onNudge: (Nudge, Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = Ink, modifier = Modifier.weight(1f))
        StepButton("−", stringResource(R.string.less)) { onNudge(key, -1) }
        Text(
            value,
            modifier = Modifier.width(64.dp),
            textAlign = TextAlign.Center,
            color = Ink,
            style = TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                fontFeatureSettings = "tnum",
            ),
        )
        StepButton("+", stringResource(R.string.more)) { onNudge(key, 1) }
    }
}

@Composable
private fun StepButton(label: String, description: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(34.dp)
            .clip(CircleShape)
            .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
            .clickableNoRipple(onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Ink)
    }
}

@Composable
private fun FaceBlock(state: Display, livePhase: PhaseLabel?, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val phaseLabel = when {
        livePhase != null -> when (livePhase) {
            PhaseLabel.PREPARE -> stringResource(R.string.setting_prepare)
            PhaseLabel.WORK -> stringResource(R.string.setting_work)
            PhaseLabel.REST -> stringResource(R.string.setting_rest)
            else -> context.phaseText(state.face.phase)
        }
        else -> context.phaseText(state.face.phase)
    }
    val detail = context.detailText(state.face.detail)
    val showDetail = shouldShowDetail(state)
    val ink = livePhase?.let { liveInk(it) } ?: Ink
    val phaseColor = livePhase?.let { liveInk(it) } ?: tintColor(state.face.tint)
    val wide = state.face.text.length > 5
    val stopwatchFace = state.mode == Mode.STOPWATCH || state.runMode == Mode.STOPWATCH
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            if (livePhase != null) {
                Text(
                    phaseLabel,
                    color = phaseColor,
                    fontFamily = BarlowCondensed,
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp,
                    letterSpacing = 0.08.em,
                )
            }
            val clockStyle = TextStyle(
                fontFamily = BarlowCondensed,
                fontWeight = FontWeight.Bold,
                fontSize = faceSize(state.mode, state.runState, wide, state.chromeVisible, livePhase != null),
                letterSpacing = (-0.04).em,
            ).let { base ->
                if (stopwatchFace) base.copy(fontFeatureSettings = "tnum") else base
            }
            Text(
                state.face.text,
                color = ink,
                style = clockStyle,
                textAlign = TextAlign.Center,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Clip,
            )
            if (showDetail) {
                Text(
                    detail,
                    color = if (livePhase != null) ink.copy(alpha = 0.78f) else Muted,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(top = 6.dp),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

private fun shouldShowDetail(state: Display): Boolean {
    return when (val detail = state.face.detail) {
        is Detail.Ready -> state.mode != Mode.STOPWATCH
        is Detail.Countdown -> !(state.chromeVisible && state.settings.countdown >= 5)
        is Detail.CountingUp -> state.runState != RunState.IDLE
        is Detail.MinimumFive -> true
        else -> true
    }
}

@Composable
private fun faceSize(
    mode: Mode,
    runState: RunState,
    wide: Boolean,
    setup: Boolean,
    live: Boolean,
): androidx.compose.ui.unit.TextUnit {
    val density = LocalDensity.current
    return with(density) {
        val stopwatchIdle = mode == Mode.STOPWATCH && runState == RunState.IDLE
        val base = when {
            live -> 104.dp
            stopwatchIdle -> 96.dp
            setup -> 84.dp
            wide -> 96.dp
            else -> 104.dp
        }
        base.toSp()
    }
}

@Composable
private fun Laps(state: Display, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.verticalScroll(rememberScrollState()),
    ) {
        state.laps.forEach { lap ->
            Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                Text(lap.id.toString(), modifier = Modifier.width(28.dp), color = Muted)
                Text(
                    formatStopwatch(lap.split),
                    color = Muted,
                    style = TextStyle(fontFeatureSettings = "tnum"),
                )
                Spacer(Modifier.weight(1f))
                Text(
                    formatStopwatch(lap.total),
                    color = Ink,
                    style = TextStyle(
                        fontWeight = FontWeight.SemiBold,
                        fontFeatureSettings = "tnum",
                    ),
                )
            }
        }
    }
}

@Composable
private fun ControlsBar(
    state: Display,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onReset: () -> Unit,
    onAgain: () -> Unit,
    onLap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier.heightIn(min = 60.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        when (state.controls) {
            Controls.START -> PrimaryButton(stringResource(R.string.action_start), state.face.tint, state.canStart, Modifier.weight(1f), onStart)
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
    Box(
        modifier = modifier
            .height(56.dp)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(CircleShape)
            .background(tintColor(tint))
            .then(if (enabled) Modifier.clickableNoRipple(onClick) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            fontFamily = BarlowCondensed,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            color = inkOn(tint),
        )
    }
}

@Composable
private fun PlainButton(label: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .height(56.dp)
            .clip(CircleShape)
            .background(Ink)
            .clickableNoRipple(onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            fontFamily = BarlowCondensed,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            color = InkDark,
        )
    }
}

@Composable
private fun SecondaryButton(label: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .height(56.dp)
            .clip(CircleShape)
            .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
            .clickableNoRipple(onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            fontFamily = BarlowCondensed,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            color = Ink,
        )
    }
}

@Composable
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    this.then(
        Modifier.clickable(
            interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
            indication = null,
            onClick = onClick,
        ),
    )