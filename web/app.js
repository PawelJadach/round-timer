import {
  canStart,
  createSession,
  dueCues,
  formatClock,
  formatStopwatch,
  lap,
  pauseSession,
  preview,
  resumeSession,
  snapshot,
  sparringTotalSeconds,
} from "./engine.js"
import { getLocale, setLocale, t, totalLine } from "./i18n.js"

const MODES = ["sparring", "countdown", "stopwatch"]

const SPARRING_PRESETS = [
  ["presetTabata", "20/10 × 8", { prepare: 5, work: 20, rest: 10, rounds: 8 }],
  ["presetInterval", "30/15 × 10", { prepare: 5, work: 30, rest: 15, rounds: 10 }],
  ["presetSparring", "3:00 / 1:00 × 5", { prepare: 10, work: 180, rest: 60, rounds: 5 }],
  ["presetRound", "5:00 / 1:00 × 3", { prepare: 10, work: 300, rest: 60, rounds: 3 }],
]

const COUNTDOWN_PRESETS = [
  ["0:30", "presetHalf", 30],
  ["1:00", "presetMinute", 60],
  ["3:00", "presetThree", 180],
  ["5:00", "presetFive", 300],
  ["10:00", "presetTen", 600],
]

const MODE_LABEL = {
  sparring: "modeSparring",
  countdown: "modeCountdown",
  stopwatch: "modeStopwatch",
}

const defaults = { prepare: 10, work: 180, rest: 60, rounds: 5, countdown: 180 }
const settings = loadSettings()
const ui = {
  mode: "sparring",
  runState: "idle",
  session: null,
  runMode: null,
  lastCueAt: 0,
  sound: loadSound(),
  volume: loadVolume(),
  audio: null,
  master: null,
  bell: null,
  bellArmed: false,
  bellLive: false,
  wakeLock: null,
  renderedKey: "",
  scheduledIds: new Set(),
  scheduledNodes: [],
  keepalive: null,
}

const langEl = document.querySelector("#lang")
const volumeLabelEl = document.querySelector("#volume-label")
const phaseEl = document.querySelector("#phase")
const timeEl = document.querySelector("#time")
const detailEl = document.querySelector("#detail")
const glowEl = document.querySelector("#glow")
const modesEl = document.querySelector("#modes")
const soundEl = document.querySelector("#sound")
const volumeEl = document.querySelector("#volume")
const volumeValueEl = document.querySelector("#volume-value")
const volumeRow = document.querySelector(".volume")
const settingsEl = document.querySelector("#settings")
const controlsEl = document.querySelector("#controls")
const lapsEl = document.querySelector("#laps")
const hintEl = document.querySelector("#hint")

soundEl.addEventListener("click", () => {
  ui.sound = !ui.sound
  localStorage.setItem("mmaclock.sound", ui.sound ? "1" : "0")
  applyVolume()
  renderSound()
})

let volumeTouched = false

volumeEl.addEventListener("pointerdown", () => {
  volumeTouched = true
})

volumeEl.addEventListener("input", () => {
  ui.volume = Number(volumeEl.value)
  localStorage.setItem("mmaclock.volume", String(ui.volume))
  volumeValueEl.textContent = String(ui.volume)
  applyVolume()
})

volumeEl.addEventListener("change", () => {
  const touched = volumeTouched
  volumeTouched = false
  if (!touched || ui.runState !== "idle" || !ui.sound || ui.volume <= 0) return
  armAudio()
  play("work")
})

document.addEventListener("pointerdown", armAudio)

document.addEventListener("visibilitychange", () => {
  if (ui.runState !== "running") return
  if (document.visibilityState === "hidden") {
    holdSessionAudio()
    scheduleUpcoming(Date.now())
  } else {
    catchUp()
    keepAwake()
  }
})

setLocale(loadLocale())
applyDocumentLocale()
renderLanguage()
renderSound()
renderModes()
renderFace(currentFace())
renderSettings()
renderControls()
renderHint()
ensureBellBuffer()
requestAnimationFrame(tick)

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").catch(() => {})
}

function tick() {
  stepSession()
  requestAnimationFrame(tick)
}

setInterval(stepSession, 100)

function stepSession() {
  if (ui.runState !== "running" || !ui.session) return
  if (document.visibilityState === "hidden") holdSessionAudio()
  const face = advance(Date.now())
  renderFace(face)
  if (face.finished) finish()
}

function advance(now) {
  const cues = dueCues(ui.session, ui.lastCueAt, now)
  ui.lastCueAt = now
  for (const cue of cues) {
    const late = now - cue.at
    if (ui.scheduledIds.has(cue.id) && (!ui.audio || ui.audio.state !== "running")) releaseScheduled(cue.id)
    const owned = ui.scheduledIds.has(cue.id)
    if (!owned && late < 1500 && cue.sound !== "end") {
      play(cue.sound)
      ui.scheduledIds.add(cue.id)
    }
    if (cue.sound === "end") {
      if (!owned && late < 1500) {
        play("end")
        ui.scheduledIds.add(cue.id)
      }
      return snapshot(ui.session, now)
    }
  }
  return snapshot(ui.session, now)
}

function catchUp() {
  if (!ui.session || ui.runState !== "running") return
  const now = Date.now()
  const gap = now - ui.lastCueAt
  if (gap > 2000) ui.lastCueAt = now
  const face = gap > 2000 ? snapshot(ui.session, now) : advance(now)
  renderFace(face)
  if (face.finished) finish()
}

function start() {
  if (!canStart(ui.mode, settings)) return
  armAudio()
  const now = Date.now()
  ui.runMode = ui.mode
  ui.session = createSession(ui.mode, settings, now)
  ui.lastCueAt = now - 1
  ui.runState = "running"
  holdSessionAudio()
  scheduleUpcoming(now)
  const face = advance(now)
  renderModes()
  renderFace(face)
  renderSettings()
  renderControls()
  renderLaps()
  keepAwake()
  track("timer_start", { mode: ui.mode })
}

function pause() {
  if (ui.runState !== "running" || !ui.session) return
  const now = Date.now()
  if (ui.runMode !== "stopwatch") {
    const face = advance(now)
    renderFace(face)
    if (face.finished) {
      finish()
      return
    }
  }
  pauseSession(ui.session, now)
  cancelScheduled(true)
  stopSessionAudio()
  ui.runState = "paused"
  const face = snapshot(ui.session, now)
  face.phaseName = t("phasePause")
  renderFace(face)
  renderControls()
  releaseAwake()
}

function resume() {
  if (ui.runState !== "paused" || !ui.session) return
  unlockAudio()
  const now = Date.now()
  resumeSession(ui.session, now)
  ui.lastCueAt = now
  ui.runState = "running"
  holdSessionAudio()
  scheduleUpcoming(now)
  renderFace(snapshot(ui.session, now))
  renderControls()
  keepAwake()
}

function reset() {
  cancelScheduled(true)
  stopSessionAudio()
  ui.runState = "idle"
  ui.session = null
  ui.runMode = null
  releaseAwake()
  renderModes()
  renderFace(currentFace())
  renderSettings()
  renderControls()
  renderLaps()
}

function finish() {
  if (ui.runState !== "running") return
  track("timer_finish", { mode: ui.runMode || ui.mode })
  ui.runState = "finished"
  cancelScheduled(false)
  stopSessionAudio()
  renderFace(snapshot(ui.session, Date.now()))
  renderModes()
  renderControls()
  releaseAwake()
}

function markLap() {
  if (ui.runState !== "running" || !ui.session) return
  unlockAudio()
  lap(ui.session, Date.now())
  if (ui.sound) play("tick")
  renderLaps()
  renderFace(snapshot(ui.session, Date.now()))
}

function currentFace() {
  if (ui.runState === "idle" || !ui.session) return preview(ui.mode, settings)
  const face = snapshot(ui.session, Date.now())
  if (ui.runState === "paused") face.phaseName = t("phasePause")
  return face
}

function renderFace(face) {
  const faceEl = document.querySelector("#face")
  glowEl.style.setProperty("--glow", color(face.tint))
  const showClock = ui.runState !== "idle" || ui.mode === "stopwatch" || ui.mode === "countdown"
  const screen = document.querySelector("main")
  const live = ui.runState !== "idle"
  screen.classList.toggle("has-clock", showClock)
  screen.classList.toggle("countdown", ui.mode === "countdown" && !live)
  screen.classList.toggle("is-live", live)
  faceEl.classList.toggle("wide", (live ? ui.runMode : ui.mode) === "stopwatch")
  if (!showClock) {
    faceEl.hidden = true
    phaseEl.textContent = ""
    timeEl.textContent = ""
    detailEl.textContent = ""
    delete faceEl.dataset.label
    faceEl.removeAttribute("aria-label")
    return
  }
  faceEl.hidden = false
  phaseEl.textContent = face.phaseName
  phaseEl.className = `phase ${face.tint}`
  timeEl.textContent = face.text
  detailEl.textContent = face.detail
  timeEl.style.fontSize = ""
  const label = `${face.phaseName} ${face.text}`
  if (faceEl.dataset.label !== label) {
    faceEl.dataset.label = label
    faceEl.setAttribute("aria-label", label)
  }
}

function renderModes() {
  const locked = ui.runState === "running" || ui.runState === "paused"
  modesEl.dataset.locked = String(locked)
  modesEl.innerHTML = MODES.map((id) => `
    <button type="button" role="tab" data-mode="${id}" aria-selected="${ui.mode === id}">${t(MODE_LABEL[id])}</button>
  `).join("")
  modesEl.querySelectorAll("button").forEach((button) => {
    button.addEventListener("click", () => {
      if (ui.runState === "running" || ui.runState === "paused") return
      const next = button.dataset.mode
      if (ui.runState === "finished" && next !== ui.mode) reset()
      ui.mode = next
      renderModes()
      renderFace(currentFace())
      renderSettings()
      renderControls()
    })
  })
}

function renderSettings() {
  if (!settingsVisible()) {
    settingsEl.innerHTML = ""
    return
  }
  if (ui.mode === "stopwatch") {
    settingsEl.innerHTML = ""
    return
  }
  if (ui.mode === "countdown") {
    settingsEl.innerHTML = `
      <div class="presets">${COUNTDOWN_PRESETS.map(([title, detail, seconds]) => chip(title, t(detail), `data-countdown="${seconds}"`)).join("")}</div>
      ${row(t("minutes"), String(Math.floor(settings.countdown / 60)), "countdown-minutes")}
      ${row(t("seconds"), String(settings.countdown % 60).padStart(2, "0"), "countdown-seconds")}
    `
  } else {
    settingsEl.innerHTML = `
      <div class="presets">${SPARRING_PRESETS.map(([title, detail], index) => chip(t(title), detail, `data-preset="${index}"`)).join("")}</div>
      ${row(t("prepare"), formatClock(settings.prepare), "prepare")}
      ${row(t("work"), formatClock(settings.work), "work")}
      ${row(t("rest"), formatClock(settings.rest), "rest")}
      ${row(t("rounds"), String(settings.rounds), "rounds")}
      <p class="total">${totalLine(formatClock(sparringTotalSeconds(settings)))}</p>
    `
  }
  settingsEl.querySelectorAll("[data-preset]").forEach((button) => {
    button.addEventListener("click", () => {
      Object.assign(settings, SPARRING_PRESETS[Number(button.dataset.preset)][2])
      saveSettings()
      renderSettings()
      renderFace(currentFace())
    })
  })
  settingsEl.querySelectorAll("[data-countdown]").forEach((button) => {
    button.addEventListener("click", () => {
      settings.countdown = Number(button.dataset.countdown)
      saveSettings()
      renderSettings()
      renderFace(currentFace())
      renderControls()
    })
  })
  settingsEl.querySelectorAll(".step").forEach((button) => {
    button.addEventListener("click", () => nudge(button.dataset.key, Number(button.dataset.delta)))
  })
}

function renderControls() {
  const face = currentFace()
  const key = `${getLocale()}:${ui.runState}:${ui.runMode}:${ui.mode}:${canStart(ui.mode, settings)}:${face.tint}`
  if (controlsEl.dataset.key === key && controlsEl.childElementCount) return
  controlsEl.dataset.key = key
  const tint = face.tint
  if (ui.runState === "idle") {
    controlsEl.innerHTML = `<button class="primary" id="start" style="background:${color(tint)};color:${ink(tint)}" ${canStart(ui.mode, settings) ? "" : "disabled"}>${t("start")}</button>`
    controlsEl.querySelector("#start").addEventListener("click", start)
    return
  }
  if (ui.runState === "running" && ui.runMode === "stopwatch") {
    controlsEl.innerHTML = `
      <button class="secondary" id="lap">${t("lap")}</button>
      <button class="primary" id="pause">${t("pause")}</button>
    `
    controlsEl.querySelector("#lap").addEventListener("click", markLap)
    controlsEl.querySelector("#pause").addEventListener("click", pause)
    return
  }
  if (ui.runState === "running") {
    controlsEl.innerHTML = `
      <button class="secondary" id="reset">${t("reset")}</button>
      <button class="primary" id="pause">${t("pause")}</button>
    `
  } else if (ui.runState === "paused") {
    controlsEl.innerHTML = `
      <button class="secondary" id="reset">${t("reset")}</button>
      <button class="primary" id="resume" style="background:${color(tint)};color:${ink(tint)}">${t("resume")}</button>
    `
  } else {
    controlsEl.innerHTML = `
      <button class="secondary" id="reset">${t("reset")}</button>
      <button class="primary" id="again" style="background:${color("end")};color:${ink("end")}">${t("again")}</button>
    `
  }
  controlsEl.querySelector("#reset")?.addEventListener("click", reset)
  controlsEl.querySelector("#pause")?.addEventListener("click", pause)
  controlsEl.querySelector("#resume")?.addEventListener("click", resume)
  controlsEl.querySelector("#again")?.addEventListener("click", () => {
    ui.mode = ui.runMode
    reset()
    start()
  })
}

function renderLaps() {
  const laps = ui.session?.stopwatch?.laps ?? []
  if (ui.runMode !== "stopwatch" || !laps.length || ui.runState === "idle") {
    lapsEl.hidden = true
    lapsEl.innerHTML = ""
    return
  }
  lapsEl.hidden = false
  lapsEl.innerHTML = [...laps].reverse().map((item) => `
    <div class="lap"><span>${item.id}</span><span>${formatStopwatch(item.split)}</span><span>${formatStopwatch(item.total)}</span></div>
  `).join("")
}

function renderHint() {
  hintEl.innerHTML = `${t("hintBell")} <a href="https://freesound.org/s/66952/">Benboncan</a>, <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>.`
}

function renderLanguage() {
  langEl.setAttribute("aria-label", t("language"))
  langEl.innerHTML = ["en", "pl"].map((code) => `
    <button type="button" data-lang="${code}" aria-pressed="${getLocale() === code}">${code.toUpperCase()}</button>
  `).join("")
  langEl.querySelectorAll("button").forEach((button) => {
    button.addEventListener("click", () => {
      if (button.dataset.lang === getLocale()) return
      localStorage.setItem("mmaclock.lang", button.dataset.lang)
      setLocale(button.dataset.lang)
      applyDocumentLocale()
      controlsEl.dataset.key = ""
      renderLanguage()
      renderSound()
      renderModes()
      renderFace(currentFace())
      renderSettings()
      renderControls()
      renderHint()
    })
  })
}

function applyDocumentLocale() {
  document.documentElement.lang = getLocale()
}

function loadLocale() {
  const saved = localStorage.getItem("mmaclock.lang")
  if (saved === "en" || saved === "pl") return saved
  return (navigator.language || "").toLowerCase().startsWith("pl") ? "pl" : "en"
}

function renderSound() {
  soundEl.innerHTML = ui.sound ? speakerOn() : speakerOff()
  soundEl.setAttribute("aria-label", ui.sound ? t("soundOff") : t("soundOn"))
  volumeLabelEl.textContent = t("volume")
  volumeEl.setAttribute("aria-label", t("volumeAria"))
  volumeEl.value = String(ui.volume)
  volumeValueEl.textContent = String(ui.volume)
  volumeRow.classList.toggle("is-muted", !ui.sound)
}

function nudge(key, delta) {
  if (key === "prepare") settings.prepare = clamp(settings.prepare + delta, 0, 120)
  if (key === "work") settings.work = clamp(settings.work + delta, 5, 3600)
  if (key === "rest") settings.rest = clamp(settings.rest + delta, 0, 1800)
  if (key === "rounds") settings.rounds = clamp(settings.rounds + delta, 1, 30)
  if (key === "countdown-minutes") settings.countdown = clamp(settings.countdown + delta * 60, 0, 86400)
  if (key === "countdown-seconds") settings.countdown = clamp(settings.countdown + delta, 0, 86400)
  saveSettings()
  renderSettings()
  renderFace(currentFace())
  controlsEl.dataset.key = ""
  renderControls()
}

function holdSessionAudio() {
  if (ui.runMode === "stopwatch") return
  preferPlayback()
  unlockAudio()
  if (!ui.keepalive) {
    const audio = new Audio(keepaliveWavUrl())
    audio.loop = true
    audio.preload = "auto"
    audio.volume = 0.02
    ui.keepalive = audio
  }
  ui.keepalive.play().catch(() => {})
  publishPlaybackSession(true)
}

function stopSessionAudio() {
  ui.keepalive?.pause()
  publishPlaybackSession(false)
}

function publishPlaybackSession(active) {
  const session = navigator.mediaSession
  if (!session) return
  try {
    session.playbackState = active ? "playing" : "none"
    if (active) {
      session.metadata = new MediaMetadata({ title: "Round Timer", artist: "Round Timer" })
      session.setActionHandler("pause", () => {
        if (ui.runState === "running") holdSessionAudio()
      })
      session.setActionHandler("play", () => {
        if (ui.runState === "running") holdSessionAudio()
      })
    }
  } catch {}
}

function keepaliveWavUrl() {
  if (ui.keepaliveUrl) return ui.keepaliveUrl
  const sampleRate = 8000
  const samples = sampleRate
  const dataBytes = samples * 2
  const buffer = new ArrayBuffer(44 + dataBytes)
  const view = new DataView(buffer)
  const write = (offset, text) => {
    for (let index = 0; index < text.length; index += 1) view.setUint8(offset + index, text.charCodeAt(index))
  }
  write(0, "RIFF")
  view.setUint32(4, 36 + dataBytes, true)
  write(8, "WAVE")
  write(12, "fmt ")
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true)
  view.setUint16(22, 1, true)
  view.setUint32(24, sampleRate, true)
  view.setUint32(28, sampleRate * 2, true)
  view.setUint16(32, 2, true)
  view.setUint16(34, 16, true)
  write(36, "data")
  view.setUint32(40, dataBytes, true)
  let seed = 1
  for (let index = 0; index < samples; index += 1) {
    seed = (seed * 16807) % 2147483647
    view.setInt16(44 + index * 2, (seed % 1300) - 650, true)
  }
  ui.keepaliveUrl = URL.createObjectURL(new Blob([buffer], { type: "audio/wav" }))
  return ui.keepaliveUrl
}

function scheduleUpcoming(now) {
  if (!ui.session || ui.runMode === "stopwatch" || !ui.audio) return
  if (ui.audio.state !== "running") {
    ui.audio.resume()
    return
  }
  const audioNow = ui.audio.currentTime
  const kept = []
  for (const item of ui.scheduledNodes) {
    if (item.when > audioNow + 0.03) {
      try { item.node.stop() } catch {}
    } else {
      kept.push(item)
    }
  }
  ui.scheduledNodes = kept
  ui.scheduledIds = new Set(kept.map((item) => item.id))
  for (const cue of ui.session.cues) {
    if (ui.scheduledIds.has(cue.id)) continue
    const delay = (cue.at - now) / 1000
    if (delay < -0.03) continue
    const when = audioNow + Math.max(0, delay)
    if (queueCue(cue, when)) ui.scheduledIds.add(cue.id)
  }
}

function queueCue(cue, when) {
  if (cue.sound === "prepare" || cue.sound === "tick") {
    queueTone(cue, when)
    return true
  }
  if (!ui.bellBuffer) return false
  const source = ui.audio.createBufferSource()
  source.buffer = ui.bellBuffer
  source.connect(output())
  try { source.start(when) } catch { return false }
  ui.scheduledNodes.push({ node: source, when, id: cue.id })
  return true
}

function queueTone(cue, when) {
  if (cue.sound === "prepare") {
    ui.scheduledNodes.push({ node: tone(660, 0.11, when, 0.35), when, id: cue.id })
    ui.scheduledNodes.push({ node: tone(880, 0.14, when + 0.16, 0.35), when: when + 0.16, id: cue.id })
  } else {
    ui.scheduledNodes.push({ node: tone(1480, 0.05, when, 0.16), when, id: cue.id })
  }
}

function releaseScheduled(id) {
  for (const item of ui.scheduledNodes) {
    if (item.id !== id) continue
    try { item.node.stop() } catch {}
  }
  ui.scheduledNodes = ui.scheduledNodes.filter((item) => item.id !== id)
  ui.scheduledIds.delete(id)
}

function cancelScheduled(cutPlaying) {
  const audioNow = ui.audio ? ui.audio.currentTime : 0
  const kept = []
  for (const item of ui.scheduledNodes) {
    if (!cutPlaying && item.when <= audioNow) {
      kept.push(item)
      continue
    }
    try { item.node.stop() } catch {}
  }
  ui.scheduledNodes = kept
  ui.scheduledIds = new Set(kept.map((item) => item.id))
}

function play(sound) {
  if (!ui.sound || ui.volume <= 0) return
  if (sound !== "prepare" && sound !== "tick") {
    playGong()
    return
  }
  if (!ui.audio) return
  const now = ui.audio.currentTime
  applyVolume()
  if (sound === "prepare") {
    tone(660, 0.11, now, 0.35)
    tone(880, 0.14, now + 0.16, 0.35)
  } else {
    tone(1480, 0.05, now, 0.16)
  }
}

function bellElement() {
  if (ui.bell) return ui.bell
  const element = new Audio("bell.m4a")
  element.preload = "auto"
  element.setAttribute("playsinline", "true")
  ui.bell = element
  return element
}

function playGong() {
  unlockAudio()
  applyVolume()
  if (ui.audio && ui.bellBuffer) {
    try { ui.bellSource?.stop() } catch {}
    const source = ui.audio.createBufferSource()
    source.buffer = ui.bellBuffer
    source.connect(output())
    source.onended = () => {
      if (ui.bellSource === source) ui.bellLive = false
    }
    ui.bellSource = source
    ui.bellLive = true
    ui.bellArmed = true
    try { source.start() } catch {}
    return
  }
  ensureBellBuffer()
  const element = bellElement()
  routeBell(element)
  ui.bellLive = true
  ui.bellArmed = true
  element.muted = false
  element.volume = ui.bellRouted ? 1 : ui.volume / 100
  try { element.currentTime = 0 } catch {}
  element.onended = () => { ui.bellLive = false }
  element.play().catch(() => {})
}

function routeBell(element) {
  if (!ui.audio || ui.bellRouted) return
  try {
    ui.audio.createMediaElementSource(element).connect(output())
    ui.bellRouted = true
  } catch {}
}

function tone(freq, duration, when, amp) {
  const osc = ui.audio.createOscillator()
  const gain = ui.audio.createGain()
  osc.type = "sine"
  osc.frequency.value = freq
  gain.gain.setValueAtTime(0.0001, when)
  gain.gain.exponentialRampToValueAtTime(amp, when + 0.01)
  gain.gain.exponentialRampToValueAtTime(0.0001, when + duration)
  osc.connect(gain)
  gain.connect(output())
  osc.start(when)
  osc.stop(when + duration + 0.02)
  return osc
}

function output() {
  if (!ui.master) {
    ui.master = ui.audio.createGain()
    ui.master.connect(ui.audio.destination)
  }
  applyVolume()
  return ui.master
}

function applyVolume() {
  const level = ui.sound ? ui.volume / 100 : 0
  if (ui.master && ui.audio) {
    const now = ui.audio.currentTime
    ui.master.gain.cancelScheduledValues(now)
    ui.master.gain.setValueAtTime(level, now)
  }
  if (ui.bell) ui.bell.volume = ui.bellRouted ? 1 : level
}

function ensureBellBuffer() {
  if (ui.bellBuffer || ui.bellLoading) return
  const Context = window.AudioContext || window.webkitAudioContext
  if (!Context) return
  ui.bellLoading = true
  fetch("bell.m4a")
    .then((response) => response.arrayBuffer())
    .then((data) => {
      unlockAudio()
      return ui.audio.decodeAudioData(data)
    })
    .then((buffer) => {
      ui.bellBuffer = buffer
      if (ui.runState === "running") scheduleUpcoming(Date.now())
    })
    .catch(() => {})
    .finally(() => {
      ui.bellLoading = false
    })
}

function preferPlayback() {
  try {
    if (navigator.audioSession) navigator.audioSession.type = "playback"
  } catch {}
}

function unlockAudio() {
  preferPlayback()
  const Context = window.AudioContext || window.webkitAudioContext
  if (!Context) return
  if (!ui.audio) {
    ui.audio = new Context()
    ui.audio.onstatechange = () => {
      if (ui.runState === "running" && ui.audio.state === "running") scheduleUpcoming(Date.now())
    }
  }
  if (ui.audio.state === "suspended") ui.audio.resume()
}

function armAudio() {
  preferPlayback()
  unlockAudio()
  ensureBellBuffer()
  if (!ui.audio || ui.bellArmed || ui.bellLive) return
  const buffer = ui.audio.createBuffer(1, 1, ui.audio.sampleRate)
  const source = ui.audio.createBufferSource()
  source.buffer = buffer
  source.connect(ui.audio.destination)
  try { source.start() } catch {}
  ui.bellArmed = true
}

async function keepAwake() {
  if (!navigator.wakeLock) return
  try {
    ui.wakeLock = await navigator.wakeLock.request("screen")
  } catch {
    ui.wakeLock = null
  }
}

function releaseAwake() {
  ui.wakeLock?.release().catch(() => {})
  ui.wakeLock = null
}

function settingsVisible() {
  return ui.runState === "idle"
}

function row(title, value, key) {
  const delta = key === "rounds" || key === "countdown-minutes" ? 1 : 5
  return `
    <div class="row">
      <p>${title}</p>
      <span style="flex:1"></span>
      <button class="step" type="button" data-key="${key}" data-delta="-${delta}" aria-label="${t("less")}">−</button>
      <span class="value">${value}</span>
      <button class="step" type="button" data-key="${key}" data-delta="${delta}" aria-label="${t("more")}">+</button>
    </div>
  `
}

function chip(title, detail, attrs) {
  return `<button class="chip" type="button" ${attrs}><strong>${title}</strong><small>${detail}</small></button>`
}

function ink(tint) {
  return tint === "work" || tint === "rest" ? "#fff8f2" : "#1a100c"
}

function color(tint) {
  return {
    work: "#e23a2b",
    rest: "#3f86d6",
    prepare: "#e4b15a",
    end: "#d6e36a",
    stopwatch: "#f4efe6",
  }[tint] ?? "#e23a2b"
}

function loadSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem("mmaclock.settings") || "null")
    return saved ? { ...defaults, ...saved } : { ...defaults }
  } catch {
    return { ...defaults }
  }
}

function saveSettings() {
  localStorage.setItem("mmaclock.settings", JSON.stringify(settings))
}

function loadSound() {
  return localStorage.getItem("mmaclock.sound") !== "0"
}

function loadVolume() {
  const raw = localStorage.getItem("mmaclock.volume")
  if (raw == null || raw === "") return 80
  const value = Number(raw)
  if (!Number.isFinite(value)) return 80
  return Math.min(100, Math.max(0, Math.round(value)))
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

function track(name, data) {
  try {
    if (typeof window.va !== "function") return
    window.va("event", { name, data })
  } catch {}
}

function speakerOn() {
  return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9h3.2L12 5.2v13.6L7.2 15H4V9zm9.2.2a4.2 4.2 0 0 1 0 5.6l-1.1-1.1a2.6 2.6 0 0 0 0-3.4l1.1-1.1zm2.5-2.5a7.6 7.6 0 0 1 0 10.6l-1.1-1.1a6 6 0 0 0 0-8.4l1.1-1.1z"/></svg>`
}

function speakerOff() {
  return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9h3.2L12 5.2v13.6L7.2 15H4V9zm12.1 1.1 1.4 1.4 1.4-1.4 1.1 1.1-1.4 1.4 1.4 1.4-1.1 1.1-1.4-1.4-1.4 1.4-1.1-1.1 1.4-1.4-1.4-1.4 1.1-1.1z"/></svg>`
}
