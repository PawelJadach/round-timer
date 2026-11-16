package app.roundtimer.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.roundtimer.AppLinks
import app.roundtimer.R
import app.roundtimer.engine.Display

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(
    visible: Boolean,
    state: Display,
    language: String,
    usesManualLanguage: Boolean,
    onDismiss: () -> Unit,
    onToggleSound: () -> Unit,
    onVolume: (Float) -> Unit,
    onVolumeCommit: () -> Unit,
    onLanguage: (String) -> Unit,
    onFollowSystemLanguage: () -> Unit,
) {
    if (!visible) return
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var showAbout by remember { mutableStateOf(false) }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Bg,
        dragHandle = null,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 28.dp),
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = stringResource(R.string.close),
                        tint = Ink,
                        modifier = Modifier
                            .background(Canvas.copy(alpha = 0.9f), CircleShape)
                            .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
                            .padding(8.dp),
                    )
                }
            }
            if (showAbout) {
                AboutPanel(language) { showAbout = false }
            } else {
                Text(
                    stringResource(R.string.settings_title),
                    color = Ink,
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                    modifier = Modifier.padding(bottom = 16.dp),
                )
                SettingsScroll(
                    state = state,
                    language = language,
                    usesManualLanguage = usesManualLanguage,
                    onOpenAbout = { showAbout = true },
                    onToggleSound = onToggleSound,
                    onVolume = onVolume,
                    onVolumeCommit = onVolumeCommit,
                    onLanguage = onLanguage,
                    onFollowSystemLanguage = onFollowSystemLanguage,
                )
            }
        }
    }
}

@Composable
private fun SettingsScroll(
    state: Display,
    language: String,
    usesManualLanguage: Boolean,
    onOpenAbout: () -> Unit,
    onToggleSound: () -> Unit,
    onVolume: (Float) -> Unit,
    onVolumeCommit: () -> Unit,
    onLanguage: (String) -> Unit,
    onFollowSystemLanguage: () -> Unit,
) {
    Column(
        modifier = Modifier.verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SettingsPanel {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.settings_sound), color = Ink, fontWeight = FontWeight.SemiBold)
                Switch(
                    checked = state.sound,
                    onCheckedChange = { onToggleSound() },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = InkDark,
                        checkedTrackColor = Gold,
                        uncheckedThumbColor = Ink,
                        uncheckedTrackColor = Canvas,
                    ),
                )
            }
            Column(Modifier.padding(top = 12.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.volume), color = Ink, fontWeight = FontWeight.SemiBold)
                    Text(
                        state.volume.toString(),
                        color = Muted,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                Slider(
                    value = state.volume.toFloat(),
                    onValueChange = onVolume,
                    onValueChangeFinished = onVolumeCommit,
                    valueRange = 0f..100f,
                    enabled = state.sound,
                    colors = SliderDefaults.colors(
                        thumbColor = Gold,
                        activeTrackColor = Gold,
                        inactiveTrackColor = Ink.copy(alpha = 0.22f),
                    ),
                )
            }
            Text(
                stringResource(R.string.settings_audio_footer),
                color = Muted,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }

        SettingsPanel {
            SettingsLinkRow(
                title = stringResource(R.string.about_title),
                icon = { Icon(Icons.Default.Info, null, tint = Gold) },
                onClick = onOpenAbout,
            )
            Spacer(Modifier.height(12.dp))
            val context = LocalContext.current
            SettingsLinkRow(
                title = stringResource(R.string.share),
                icon = { Icon(Icons.Default.Share, null, tint = Gold) },
                onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, AppLinks.marketing(language))
                    }
                    context.startActivity(Intent.createChooser(intent, null))
                },
            )
        }

        Column {
            Text(
                stringResource(R.string.language),
                color = Muted,
                fontSize = 13.sp,
                modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
            )
            SettingsPanel {
                LanguagePicker(language, onLanguage)
                if (usesManualLanguage) {
                    Spacer(Modifier.height(12.dp))
                    Text(
                        stringResource(R.string.settings_language_system),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(CircleShape)
                            .background(Bg.copy(alpha = 0.55f))
                            .border(1.dp, Gold.copy(alpha = 0.24f), CircleShape)
                            .clickable(onClick = onFollowSystemLanguage)
                            .padding(vertical = 12.dp),
                        color = Ink,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
            }
            Text(
                stringResource(R.string.settings_language_footer),
                color = Muted,
                fontSize = 12.sp,
                modifier = Modifier.padding(start = 4.dp, top = 8.dp),
            )
        }
    }
}

@Composable
private fun AboutPanel(language: String, onBack: () -> Unit) {
    val context = LocalContext.current
    Column(
        modifier = Modifier.verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.about_title), color = Ink, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Text(
                stringResource(R.string.back),
                color = Gold,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onBack),
            )
        }
        SettingsPanel {
            LabeledRow(stringResource(R.string.about_app), stringResource(R.string.app_name))
            LabeledRow(stringResource(R.string.about_version), "1.0.0")
        }
        SettingsPanel {
            ExternalLink(stringResource(R.string.about_privacy), AppLinks.privacy(language), context)
            Spacer(Modifier.height(12.dp))
            ExternalLink(stringResource(R.string.about_terms), AppLinks.terms(language), context)
            Spacer(Modifier.height(12.dp))
            ExternalLink(stringResource(R.string.about_website), AppLinks.marketing(language), context)
        }
        SettingsPanel {
            ExternalLink(stringResource(R.string.about_support), "mailto:${AppLinks.SUPPORT_EMAIL}", context)
        }
        Text(AppLinks.SUPPORT_EMAIL, color = Muted, fontSize = 12.sp)
        SettingsPanel {
            ExternalLink(stringResource(R.string.hint_bell_link), "https://freesound.org/s/66952/", context)
        }
        Text(stringResource(R.string.hint_bell_credit), color = Muted, fontSize = 12.sp)
    }
}

@Composable
private fun LabeledRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Muted)
        Text(value, color = Ink, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ExternalLink(title: String, url: String, context: android.content.Context) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = Ink, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.OpenInNew, null, tint = Muted)
    }
}

@Composable
private fun SettingsLinkRow(
    title: String,
    icon: @Composable () -> Unit,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        icon()
        Text(title, color = Ink, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Text("›", color = Muted, fontSize = 18.sp)
    }
}

@Composable
private fun LanguagePicker(language: String, onLanguage: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(Canvas.copy(alpha = 0.9f))
            .border(1.dp, Gold.copy(alpha = 0.32f), CircleShape)
            .padding(4.dp),
    ) {
        LanguageOption("English", "en", language == "en", Modifier.weight(1f)) { onLanguage("en") }
        LanguageOption("Polski", "pl", language == "pl", Modifier.weight(1f)) { onLanguage("pl") }
    }
}

@Composable
private fun LanguageOption(label: String, tag: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(if (selected) Gold.copy(alpha = 0.2f) else androidx.compose.ui.graphics.Color.Transparent)
            .then(if (selected) Modifier.border(1.dp, Gold.copy(alpha = 0.55f), CircleShape) else Modifier)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = if (selected) Gold else Ink.copy(alpha = 0.48f),
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
        )
    }
}

@Composable
private fun SettingsPanel(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Canvas.copy(alpha = 0.9f))
            .border(1.dp, Gold.copy(alpha = 0.32f), RoundedCornerShape(16.dp))
            .padding(16.dp),
    ) {
        content()
    }
}