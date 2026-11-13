# App privacy (App Store Connect questionnaire)

Use this when filling **App Privacy** in App Store Connect. It matches `ios/MMAClock/PrivacyInfo.xcprivacy`.

## Data collection
**None.** The app does not collect, link, or track personal data for App Store privacy labels.

## Data linked to you
None.

## Data used to track you
None. `NSPrivacyTracking` is `false`.

## Privacy Nutrition labels (summary)
| Data type | Collected | Linked | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| — | No | — | — | — |

## On-device storage only
Timer settings (prepare/work/rest/rounds, countdown, sound, volume) are stored in **UserDefaults** on the device. They are not transmitted. The UI language follows the system locale; no language choice is stored unless the user previously picked one in an older app version (legacy key, harmless).

## Required-reason APIs
| API | Reason code | Use in app |
| --- | --- | --- |
| User Defaults | CA92.1 | Persist timer settings |

## Third-party SDKs
No analytics or advertising SDKs in the Release build. Debug-only review counters use Apple’s in-app review API locally. Release `Analytics` logs to OSLog only.

## Encryption
`ITSAppUsesNonExemptEncryption` = **false** (standard HTTPS only for optional links).

## Permissions (Info.plist / runtime)
| Permission | When | Purpose |
| --- | --- | --- |
| Notifications | Optional, on first timed session | Backup round cues if the app is suspended |
| Background audio | During an active timed session | Keep round schedule and play bells |
| Live Activities | Optional | Lock Screen countdown display |

No camera, photos, contacts, or location.
