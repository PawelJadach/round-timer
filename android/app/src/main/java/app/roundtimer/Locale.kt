package app.roundtimer

import android.content.Context
import android.content.res.Configuration
import app.roundtimer.data.Prefs
import java.util.Locale

fun Context.withAppLocale(): Context {
    val code = Prefs(this).resolvedLanguage()
    val locale = if (code == "pl") Locale("pl") else Locale.ENGLISH
    val config = Configuration(resources.configuration)
    config.setLocale(locale)
    return createConfigurationContext(config)
}
