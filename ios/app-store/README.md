# Round Timer — App Store kit

Assets and copy for **manual** upload to App Store Connect. Nothing here is submitted automatically.

## Contents

| Path | Purpose |
| --- | --- |
| `listing-en.md` | English name, subtitle, description, keywords |
| `listing-pl.md` | Polish store localisation |
| `privacy-app-store.md` | Privacy questionnaire answers |
| `age-rating.md` | Age rating worksheet notes |
| `icon/AppIcon-1024.png` | 1024×1024 marketing icon (also copied into `MMAClock` asset catalog) |
| `screenshots/{en,pl}/*.png` | 1290×2796 iPhone 6.7″ style frames |
| `generate-assets.py` | Regenerate icon and screenshots after UI changes |

Regenerate visuals:

```bash
python3 ios/app-store/generate-assets.py
```

## What Pawel must provide (not in repo)

1. **Apple Developer Program** membership (paid team).
2. **App Store Connect** app record with bundle ID (currently `dev.pawel.roundtimer` in Xcode — change to your production ID before release).
3. **Signing**: Distribution certificate + App Store provisioning profile for **MMAClock** and **MMAClockWidget** extension.
4. **Archive & upload** from Xcode (Product → Archive → Distribute App).
5. **Store localisations**: paste text from `listing-en.md` and `listing-pl.md`; upload screenshots per locale.
6. **Privacy**: answer questionnaire using `privacy-app-store.md`; confirm `PrivacyInfo.xcprivacy` is included (it is in the target).
7. **Age rating**: complete wizard using `age-rating.md`.
8. **Export compliance**: app declares no non-exempt encryption in `Info.plist`.
9. **Support / privacy URLs** must stay live at the marketing host (`AppConfig` URLs).

Optional but recommended: replace generated screenshots with captures from a real device after UI sign-off.

## Versioning

Marketing version **1.0**, build **1** (see `MARKETING_VERSION` in Xcode). Bump `CURRENT_PROJECT_VERSION` for each upload.
