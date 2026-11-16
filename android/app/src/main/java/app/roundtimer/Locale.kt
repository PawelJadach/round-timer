package app.roundtimer

import android.content.Context
import android.content.res.Configuration
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import app.roundtimer.data.Prefs
import java.util.Locale

fun Context.withAppLocale(languageCode: String? = null): Context {
    val code = languageCode ?: Prefs(this).resolvedLanguage()
    val locale = if (code == "pl") Locale("pl") else Locale.ENGLISH
    val config = Configuration(resources.configuration)
    config.setLocale(locale)
    return createConfigurationContext(config)
}

fun applyAppLanguage(prefs: Prefs) {
    val locales = if (prefs.usesManualLanguage()) {
        LocaleListCompat.forLanguageTags(prefs.resolvedLanguage())
    } else {
        LocaleListCompat.getEmptyLocaleList()
    }
    AppCompatDelegate.setApplicationLocales(locales)
}