# Keystore dla pierwszej wersji produkcyjnej (Google Play)

Pliki **nie trafiają do gita** (`keystore.properties`, `*.jks`).

## Jednorazowo: utwórz keystore

```bash
keytool -genkeypair -v \
  -keystore android/app/round-timer-upload.jks \
  -alias round-timer-upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Zapisz hasła w menedżerze haseł.

## `android/keystore.properties`

```properties
storeFile=round-timer-upload.jks
storePassword=TWOJE_HASLO_SKLEPU
keyAlias=round-timer-upload
keyPassword=TWOJE_HASLO_KLUCZA
```

## Zbuduj AAB (wersja 1.0.0, versionCode 1)

Z katalogu repo:

```bash
chmod +x android/scripts/build-play-release.sh
./android/scripts/build-play-release.sh
```

Wynik: `android/app/build/outputs/bundle/release/app-release.aab` → Play Console → **Wersja produkcyjna**.

Informacje o wersji: `android/play/release-notes-1.0.0.txt`.