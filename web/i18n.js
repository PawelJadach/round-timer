const STRINGS = {
  en: {
    modeSparring: "Sparring",
    modeCountdown: "Timer",
    modeStopwatch: "Stopwatch",
    volume: "Volume",
    volumeAria: "Sound volume",
    soundOff: "Mute",
    soundOn: "Unmute",
    language: "Language",
    less: "Less",
    more: "More",
    prepare: "Prepare",
    work: "Work",
    rest: "Rest",
    rounds: "Rounds",
    minutes: "Minutes",
    seconds: "Seconds",
    start: "Start",
    lap: "Lap",
    pause: "Pause",
    reset: "Reset",
    resume: "Resume",
    again: "Again",
    phasePrepare: "PREPARE",
    phaseWork: "WORK",
    phaseRest: "REST",
    phaseCountdown: "TIMER",
    phaseEnd: "END",
    phasePause: "PAUSE",
    phaseStopwatch: "STOPWATCH",
    detailPrepare: "Starting soon",
    detailCountdown: "Countdown",
    detailMinimum: "Minimum 5 seconds",
    detailFinishedCountdown: "Time’s up",
    detailFinishedSession: "Session complete",
    detailStopwatch: "Counting up",
    detailReady: "Ready",
    hintBell: "Bell:",
    presetTabata: "Tabata",
    presetInterval: "Interval",
    presetSparring: "Sparring",
    presetRound: "Round",
    presetHalf: "half a minute",
    presetMinute: "one minute",
    presetThree: "three minutes",
    presetFive: "five minutes",
    presetTen: "ten minutes",
  },
  pl: {
    modeSparring: "Sparing",
    modeCountdown: "Minutnik",
    modeStopwatch: "Stoper",
    volume: "Głośność",
    volumeAria: "Głośność dźwięku",
    soundOff: "Wyłącz dźwięk",
    soundOn: "Włącz dźwięk",
    language: "Język",
    less: "Mniej",
    more: "Więcej",
    prepare: "Przygotowanie",
    work: "Praca",
    rest: "Przerwa",
    rounds: "Rundy",
    minutes: "Minuty",
    seconds: "Sekundy",
    start: "Start",
    lap: "Okrążenie",
    pause: "Pauza",
    reset: "Reset",
    resume: "Wznów",
    again: "Jeszcze raz",
    phasePrepare: "PRZYGOTOWANIE",
    phaseWork: "PRACA",
    phaseRest: "PRZERWA",
    phaseCountdown: "MINUTNIK",
    phaseEnd: "KONIEC",
    phasePause: "PAUZA",
    phaseStopwatch: "STOPER",
    detailPrepare: "Zaraz start",
    detailCountdown: "Odliczanie",
    detailMinimum: "Minimum 5 sekund",
    detailFinishedCountdown: "Czas minął",
    detailFinishedSession: "Sesja zakończona",
    detailStopwatch: "Czas w górę",
    detailReady: "Gotowy",
    hintBell: "Dzwonek:",
    presetTabata: "Tabata",
    presetInterval: "Interwał",
    presetSparring: "Sparing",
    presetRound: "Runda",
    presetHalf: "pół minuty",
    presetMinute: "minuta",
    presetThree: "trzy minuty",
    presetFive: "pięć minut",
    presetTen: "dziesięć minut",
  },
}

let locale = "pl"

export function getLocale() {
  return locale
}

export function setLocale(next) {
  locale = next === "en" ? "en" : "pl"
  return locale
}

export function t(key) {
  return STRINGS[locale][key]
}

export function totalLine(clock) {
  return locale === "en" ? `Total ${clock}` : `Całość ${clock}`
}

export function roundDetail(round, total) {
  return locale === "en" ? `Round ${round} of ${total}` : `Runda ${round} z ${total}`
}

export function lapDetail(count) {
  return locale === "en" ? `Lap ${count}` : `Okrążenie ${count}`
}
