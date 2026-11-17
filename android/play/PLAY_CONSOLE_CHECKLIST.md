# Google Play Console — Round Timer (`app.roundtimer`)

Draft-only internal testing. Do **not** roll out production or send for review.

## One-command upload (after API key exists)

1. Play Console → **Setup** → **API access** → link Google Cloud project → create/locate **service account** with **Release manager** (or admin) → download JSON.
2. Save JSON **outside the repo** as `~/round-timer-play-api.json` (or set `PLAY_CONSOLE_JSON`).
3. From `android/`:

```bash
fastlane internal_draft
```

AAB default: `/Users/pawel/round-timer-release/round-timer-1.0.0-1.aab` (override with `ROUND_TIMER_AAB`).

Fastlane metadata is synced from this folder under `android/fastlane/metadata/android/`.

## Manual Console (if no API key)

Create app **Round Timer** with package `app.roundtimer` if it does not exist.

### Main store listing

| Locale | Title / descriptions | Graphics |
|--------|----------------------|----------|
| en-US | `en-US/*.txt` | `graphics/icon-512.png`, `feature-1024x500.png`, `graphics/phone/en-*.png` |
| pl-PL | `pl-PL/*.txt` | same icon/feature, `graphics/phone/pl-*.png` |

### App content (questionnaire — obvious answers)

- **Privacy policy URL (en):** https://round-timer-marketing.vercel.app/privacy/
- **Privacy policy URL (pl):** use same EN URL or Polish page https://round-timer-marketing.vercel.app/pl/privacy/ (Console often accepts one default URL).
- **Ads:** No.
- **In-app purchases:** No.
- **Account:** No sign-in; no account required.
- **Data safety:** No data collected or shared (see `privacy-en.md` / `privacy-pl.md`).
- **Target audience:** General / not designed for children (timer utility).
- **Content rating:** Complete IARC questionnaire — sports/timer utility, no UGC, no violence depicted in app UI (combat sports **timing** only).

### Release

- **Testing** → **Internal testing** → upload `round-timer-1.0.0-1.aab` → save as **draft**; do not promote to production.