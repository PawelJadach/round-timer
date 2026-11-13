# Round Timer

Monorepo: web PWA + native iOS. Gym clock for sparring / tabata, countdown timer, and stopwatch. No accounts.

Dark face, round glow, short cues that duck other music briefly. On iOS the countdown also shows on the Lock Screen (Live Activity / Dynamic Island).

Formerly MMA Clock / Train Clock — same product.

## Layout

```
round-timer/
  site/                → marketing site (EN + PL), separate from the clock
  web/                 → static PWA (engine.js + app.js)
  android/             → native Android app (Jetpack Compose)
  ios/
    MMAClock.xcodeproj → open this in Xcode
    MMAClock/          → SwiftUI app (iOS 17+)
    MMAClockWidget/    → Live Activity extension
    Shared/
    Tests/
  README.md
```

## Web

```bash
cd web
python3 -m http.server 8080
# open http://127.0.0.1:8080
```

Or deploy `web/` as a static site (e.g. Vercel).

## Marketing site

`site/` is only the public page: product, privacy, and terms, in English and Polish. It does not change the clock in `web/`.

```bash
cd site
python3 -m http.server 8090
# open http://127.0.0.1:8090
```

## iOS

1. Install Xcode from the Mac App Store (Command Line Tools alone are not enough).
2. Open `ios/MMAClock.xcodeproj`.
3. Plug in an iPhone, unlock it, trust the Mac.
4. On the phone: Settings → Privacy & Security → Developer Mode → on, then restart.
5. Select your device as the run destination.
6. Target **MMAClock** → Signing & Capabilities → Team: your Apple ID (free is fine). Same for **MMAClockWidget** if Xcode asks.
7. Run.

A free-team build lasts about 7 days; press Run again after that.

On first session start, allow notifications — backup cues when the system suspends the app.

### Locales

EN + PL via `Localizable.xcstrings` (system language).

### Product notes

- Modes: Rounds, countdown, stopwatch (laps). Presets: Interval and Sparring.
- Settings: prepare / work / rest / rounds, presets, sound + volume, About / share.
- Lean App Store shell: `AppConfig`, Privacy Manifest, review prompt, haptics — no heavy SDKs.

## Android

Open `android/` in Android Studio, or build from the command line with the Android SDK:

```bash
cd android
./gradlew :app:assembleDebug
```

Same clock as the web app: sparring, countdown, and stopwatch, the same presets, 5-second steps, the ring bell, volume starting at 80 with a preview, and English or Polish from the switch on the clock. A running session stays in a foreground service, so the bell still plays if you leave the app. Store listing copy, the icon, and privacy notes are in `android/play/` for a manual Play Console upload. Nothing here submits the app.
