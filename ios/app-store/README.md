# Round Timer — App Store kit

Assets and copy for **manual** upload to App Store Connect. Nothing here is submitted automatically.

## Contents

| Path | Purpose |
| --- | --- |
| `listing-en.md` | English name, subtitle, description, keywords |
| `listing-pl.md` | Polish store localisation |
| `privacy-app-store.md` | Privacy questionnaire answers |
| `age-rating.md` | Age rating worksheet notes |
| `icon/AppIcon-1024.png` | 1024×1024 marketing icon (RGB, no alpha; synced to `MMAClock` asset catalog) |
| `screenshots/{en,pl}/*.png` | 1290×2796 (6.7″ class) **mock** frames from `generate-assets.py` |
| `generate-assets.py` | Regenerate icon and screenshot mocks after UI changes |

Regenerate visuals (requires Pillow):

```bash
pip install pillow
python3 ios/app-store/generate-assets.py
```

## Signing and distribution (Paweł only)

1. **Team in Xcode**: On your Mac at `~/repos/round-timer`, choose your **paid Apple Developer Program** team under **Signing & Capabilities** for **MMAClock** and **MMAClockWidget**. Automatic signing is configured; do not commit `DEVELOPMENT_TEAM` to the repo.
2. **Bundle ID** in Xcode: `dev.pawel.roundtimer` (main) and `dev.pawel.roundtimer.widget` (widget). Create matching IDs in the developer portal if needed.
3. **Archive & upload**: Xcode → Product → Archive → Distribute App (Release, scheme **MMAClock**).
4. Paste store text from `listing-en.md` / `listing-pl.md`; use live URLs on `round-timer-marketing.vercel.app` (see `AppConfig` for locale paths).
5. **Privacy** questionnaire: `privacy-app-store.md`; `PrivacyInfo.xcprivacy` is in the app target.
6. **Age rating**: `age-rating.md`.
7. **Export compliance**: `ITSAppUsesNonExemptEncryption` = false in `Info.plist` (HTTPS links only).

## Screenshot gaps (first submission)

| Gap | Notes |
| --- | --- |
| **Obsolete mocks** | Current PNGs show old UI (mode tab “Sparring”, on-screen volume bar, EN/PL toggle). Prefer **device captures** after this build. |
| **Count** | Only **2** images per locale; Apple allows up to 10 — add timer, stopwatch, and settings as needed. |
| **Device sizes** | Only **1290×2796** (6.7″). Also provide **6.9″** (1320×2868) if App Store Connect requires the largest iPhone size for your account. No iPad screenshots (iPhone-only app). |
| **Widget / Live Activity** | Optional extra frames if you want to highlight Lock Screen countdown. |

Do not invent App Store or Play Store listing URLs for the marketing site buttons.

## Versioning

Marketing version **1.0**, build **1** (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in Xcode). Bump build for each upload.
