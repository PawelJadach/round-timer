package app.roundtimer

object AppLinks {
    const val HOST = "https://round-timer-marketing.vercel.app"
    const val SUPPORT_EMAIL = "pawel.jadach.96@gmail.com"

    fun marketing(language: String) = if (language == "pl") "$HOST/pl/" else "$HOST/"

    fun privacy(language: String) = if (language == "pl") "$HOST/pl/privacy/" else "$HOST/privacy/"

    fun terms(language: String) = if (language == "pl") "$HOST/pl/terms/" else "$HOST/terms/"
}