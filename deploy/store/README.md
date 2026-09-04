# Release-Signatur für den Play Store

Der Build ist fertig verdrahtet: [`android/app/build.gradle.kts`](../../android/app/build.gradle.kts)
liest `android/key.properties` und signiert damit. Fehlt die Datei, fällt
er auf den Debug-Schlüssel zurück — praktisch für `flutter run --release`,
aber **vom Play Store abgelehnt**.

Es fehlt nur der Schlüssel. Den musst du selbst erzeugen, weil dabei ein
Passwort gewählt wird.

---

## 1. Keystore erzeugen

In **PowerShell**, im Projektordner:

```bash
keytool -genkey -v -keystore android/aura-quest-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias aura-quest
```

`keytool` liegt bei der Java-Installation, die Android Studio mitbringt.
Wird es nicht gefunden, hilft der volle Pfad, etwa:
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.

Das Werkzeug fragt nacheinander:

| Frage | Hinweis |
|---|---|
| Keystore-Passwort | **Frei wählbar. Merken.** Ohne dieses Passwort ist der Schlüssel verloren. |
| Vor- und Nachname, Organisation, Ort, Land | Erscheint nirgends öffentlich; Name und Land genügen |
| Schlüssel-Passwort | Enter drücken übernimmt das Keystore-Passwort |

`-validity 10000` sind gut 27 Jahre. Google verlangt eine Gültigkeit
mindestens bis zum 22. Oktober 2033.

---

## 2. `android/key.properties` anlegen

Neue Datei, vier Zeilen:

```properties
storePassword=DEIN_KEYSTORE_PASSWORT
keyPassword=DEIN_SCHLUESSEL_PASSWORT
keyAlias=aura-quest
storeFile=../aura-quest-release.jks
```

**Zum Pfad:** `storeFile` wird von Gradle im Modul `android/app`
aufgelöst. Der Keystore liegt nach Schritt 1 eine Ebene höher unter
`android/`, deshalb das vorangestellte `../`. Ein falscher Pfad wirft
keinen Fehler — der Build fällt still auf die Debug-Signatur zurück.
Genau dafür ist Schritt 4 da.

---

## 3. Beides aus der Versionsverwaltung heraushalten

Diese zwei Dateien sind Zugangsdaten:

```
android/aura-quest-release.jks
android/key.properties
```

Wer sie in ein Repository legt, gibt die Kontrolle über künftige
Aktualisierungen der App aus der Hand. Gehört in `.gitignore`, sobald das
Projekt versioniert wird.

**Sichere den Keystore getrennt** — Passwortmanager, verschlüsselter
USB-Stick, was auch immer. Geht er verloren, lässt sich eine
veröffentlichte App **nie wieder aktualisieren**; sie müsste unter neuem
Paketnamen neu eingereicht werden, und alle Installationen wären
abgeschnitten. Das ist die einzige wirklich unumkehrbare Stelle im
gesamten Veröffentlichungsweg.

---

## 4. Prüfen, ob es greift

```bash
flutter build appbundle --release
```

Danach:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Steht dort dein Name aus Schritt 1, ist alles richtig. Steht dort
`CN=Android Debug`, wurde `key.properties` nicht gefunden — meist ein
falscher `storeFile`-Pfad.

---

## Was danach noch fehlt

- **Play Console:** Entwicklerkonto, einmalig 25 USD
- **Store-Eintrag:** Beschreibung, Bildschirmfotos, Alterseinstufung,
  Link zur Datenschutzerklärung → `https://legal.brenzel.uk`
- **Datensicherheitsformular:** Google fragt ab, welche Daten die App
  erhebt. Die Antworten stehen in
  [`legal/datenschutz.md`](../../legal/datenschutz.md) — Konto, Spieldaten,
  Geräte-Kennung für Push; keine Werbung, kein Tracking.
- **`applicationId`** ist `com.auraquest.aura_quest` und liegt nach der
  ersten Veröffentlichung fest.
