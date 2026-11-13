# Round Timer

Monorepo: web PWA + native iOS. Gym clock for sparring / tabata, countdown timer, and stopwatch. No accounts.

Dark face, round glow, short cues that duck other music briefly. On iOS the countdown also shows on the Lock Screen (Live Activity / Dynamic Island).

Formerly MMA Clock / Train Clock — same product.

## Layout

```
round-timer/
  web/                 → static PWA (engine.js + app.js)
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

- Modes: Sparring/Tabata, Countdown, Stopwatch (laps).
- Settings: prepare / work / rest / rounds, presets, sound + volume, About / share.
- Lean App Store shell: `AppConfig`, Privacy Manifest, review prompt, haptics — no heavy SDKs.
