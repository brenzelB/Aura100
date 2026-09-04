# Datenschutzerklärung — Aura Quest

**Stand:** 6. August 2026

> **HINWEIS AN DEN BETREIBER — vor Veröffentlichung entfernen**
>
> Dieser Text beschreibt die Verarbeitung so, wie die App sie am
> 06.08.2026 tatsächlich durchführt. Er wurde technisch geprüft, aber
> **nicht juristisch**. Lass ihn vor dem Live-Gang von jemandem mit
> Rechtskenntnis durchsehen.
>
> Alle mit `⟨…⟩` markierten Stellen musst du ausfüllen — sie enthalten
> Angaben, die nur du kennst.
>
> **Ändert sich die App, ändert sich dieser Text.** Kommt zum Beispiel
> ein Analysedienst, eine Werbebibliothek oder ein Foto-Upload hinzu,
> stimmt Abschnitt 4 nicht mehr.

---

## 1. Verantwortlicher

Verantwortlich für die Datenverarbeitung im Sinne der DSGVO:

```
⟨Vor- und Nachname⟩
⟨Straße und Hausnummer⟩
⟨PLZ und Ort⟩
Deutschland

E-Mail: ⟨Kontaktadresse⟩
```

Ein Datenschutzbeauftragter ist nicht bestellt; die Voraussetzungen des
Art. 37 DSGVO liegen nicht vor.

---

## 2. Grundsätzliches zu diesem Dienst

Aura Quest ist ein privat betriebener Gewohnheits-Tracker mit
Mehrspieler-Funktionen. Er läuft **auf eigener Hardware in Deutschland**
(NAS im Haushalt des Verantwortlichen). Es gibt **keinen Cloud-Anbieter,
der die Datenbank hält**, keine Werbung, keine Analyse- oder
Tracking-Werkzeuge und kein Nutzerprofiling zu Werbezwecken.

Die App ist nicht für Kinder unter 16 Jahren bestimmt.

---

## 3. Welche Daten verarbeitet werden

### 3.1 Kontodaten

| Datum | Zweck | Herkunft |
|---|---|---|
| E-Mail-Adresse | Anmeldung, Bestätigung, Passwort-Zurücksetzung | von dir |
| Passwort | Anmeldung — gespeichert **nur als Hash**, nie im Klartext | von dir |
| Benutzername | Anzeige gegenüber Mitspielern | von dir |
| Avatar (Emoji oder Symbol) | Anzeige gegenüber Mitspielern | von dir |
| Zeitzonen-Abweichung des Geräts | Damit Erinnerungen und zeitgebundene Spielelemente in deiner Ortszeit greifen | automatisch von der App |
| Registrierungszeitpunkt | Anzeige „Mitglied seit" | automatisch |

### 3.2 Spieldaten

Alles, was du im Spiel tust, wird gespeichert, weil es das Spiel
ausmacht:

- angelegte und beigetretene Quests samt Titel, Beschreibung und Regeln
- Check-ins, Fortschrittseinträge und Rückfälle („Slips") mit Zeitpunkt
- Aura-Stände, Strikes, Abrechnungsereignisse
- Käufe im Quest-Shop und deren Einsatz
- Würfelduelle, Aura-Raubzüge, Roasts, Blackouts, Anstupser
- Freundschaften, Quest-Einladungen
- Blockierungen und Meldungen anderer Nutzer

**Für Mitspieler sichtbar** sind: Benutzername, Avatar, Aura-Stand,
Fortschritt, Zeitpunkt der letzten Aktivität und Titel innerhalb der
gemeinsamen Quests. Deine E-Mail-Adresse ist für Mitspieler **nicht**
sichtbar.

### 3.3 Benachrichtigungen

Nur wenn du Push-Benachrichtigungen aktivierst:

- eine Geräte-Kennung des Zustelldienstes (Firebase-Token oder
  UnifiedPush-Endpunkt-Adresse)
- welche Kategorien du erhalten möchtest
- pro Quest eine optionale Erinnerungszeit
- die zu versendenden Nachrichten, bis zu 14 Tage in einer Warteschlange

### 3.4 Serverseitige Protokolle

Beim Zugriff auf den Server fallen technisch bedingt Verbindungsdaten an
(IP-Adresse, Zeitpunkt, aufgerufener Pfad). Sie dienen ausschließlich
dem Betrieb und der Abwehr von Missbrauch.

---

## 4. Empfänger und Drittanbieter

Diese Dienste sind eingebunden. Andere gibt es nicht — insbesondere
**keine** Analyse-, Werbe- oder Absturzberichts-Dienste.

### 4.1 Cloudflare — Erreichbarkeit und Verschlüsselung

Cloudflare Inc. bzw. Cloudflare Germany GmbH leitet die Verbindung
zwischen deinem Gerät und dem Server weiter und verschlüsselt sie
(TLS). Dabei werden Verbindungsdaten einschließlich IP-Adresse
verarbeitet.

Rechtsgrundlage: Art. 6 Abs. 1 lit. f DSGVO — berechtigtes Interesse an
einem sicher und ohne offene Portfreigabe erreichbaren Dienst.

### 4.2 Resend — E-Mail-Versand

Bestätigungs- und Passwort-E-Mails werden über Resend (Plus Five Five,
Inc.) versendet, technisch über Amazon SES in der **Region Irland
(eu-west-1)**. Übermittelt werden deine E-Mail-Adresse und der
Nachrichteninhalt.

Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO — Erfüllung des
Nutzungsvertrags.

### 4.3 Google Firebase Cloud Messaging — Push (optional)

Nur wenn du Push-Benachrichtigungen aktivierst und dein Gerät Firebase
nutzt. Google verarbeitet dabei die Geräte-Kennung und kann Zeitpunkt
und Empfängergerät einer Benachrichtigung erkennen.

**Der Inhalt einer Benachrichtigung wird Google nicht mitgeteilt.** Die
App überträgt bewusst nur ein inhaltsleeres Wecksignal — eine Kategorie
und eine Kennung. Den lesbaren Text holt die App anschließend direkt von
diesem Server. Namen von Mitspielern, Quest-Titel oder Nachrichtentexte
erreichen Google nicht.

Dabei kann eine Übermittlung in die USA erfolgen. Google LLC ist unter
dem EU-US Data Privacy Framework zertifiziert.

Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO — deine Einwilligung, die du
mit dem Aktivieren erteilst und in den Einstellungen jederzeit
widerrufen kannst.

### 4.4 Selbst betriebener Push-Weg (ntfy)

Alternativ kann die Zustellung über einen selbst betriebenen
ntfy-Server auf derselben Hardware laufen. Dabei ist **kein Dritter**
beteiligt; der volle Nachrichtentext bleibt auf diesem Server.

---

## 5. Rechtsgrundlagen im Überblick

| Verarbeitung | Grundlage |
|---|---|
| Konto, Anmeldung, Spielbetrieb | Art. 6 Abs. 1 lit. b DSGVO (Vertrag) |
| E-Mail-Bestätigung, Passwort-Zurücksetzung | Art. 6 Abs. 1 lit. b DSGVO |
| Push-Benachrichtigungen | Art. 6 Abs. 1 lit. a DSGVO (Einwilligung) |
| Betriebsprotokolle, Missbrauchsabwehr | Art. 6 Abs. 1 lit. f DSGVO |
| Blockieren und Melden | Art. 6 Abs. 1 lit. f DSGVO (Schutz der Nutzer) |

---

## 6. Speicherdauer

| Daten | Dauer |
|---|---|
| Konto- und Spieldaten | bis zur Löschung des Kontos |
| Benachrichtigungs-Warteschlange | 14 Tage |
| Sicherungskopien der Datenbank | 14 Tage, danach automatisch gelöscht |
| Geräte-Kennungen für Push | bis zum Abmelden oder Deinstallieren |

**Zur Ehrlichkeit:** Löschst du dein Konto, verschwinden deine Daten aus
dem laufenden Betrieb sofort. In den Sicherungskopien sind sie noch bis
zu 14 Tage enthalten, danach nicht mehr. Sicherungen werden nur zur
Wiederherstellung nach einem Ausfall verwendet.

---

## 7. Löschung des Kontos

In der App unter **Profil → Danger Zone → Delete account**. Dabei
werden gelöscht: Konto, Profil, Check-ins, Fortschritt, Aura-Stände,
Käufe, Freundschaften und Geräte-Kennungen.

Zwei Besonderheiten, die technisch nicht anders lösbar sind:

- **Quests, die du angelegt hast und in denen weitere Mitspieler sind**,
  werden an ein anderes Mitglied übergeben statt gelöscht — sonst
  würdest du mit deinem Konto auch fremde Spielstände vernichten. Der
  Quest-Titel bleibt dann bestehen, deine personenbezogenen Daten nicht.
- **Quests, in denen niemand sonst ist**, werden vollständig gelöscht.

---

## 8. Deine Rechte

Dir stehen zu: Auskunft (Art. 15), Berichtigung (Art. 16), Löschung
(Art. 17), Einschränkung (Art. 18), Datenübertragbarkeit (Art. 20) und
Widerspruch (Art. 21 DSGVO). Eine erteilte Einwilligung — etwa für Push
— kannst du jederzeit mit Wirkung für die Zukunft widerrufen.

Wende dich dafür an ⟨Kontaktadresse⟩.

Außerdem hast du das Recht auf Beschwerde bei einer
Datenschutz-Aufsichtsbehörde, insbesondere in dem Bundesland deines
gewöhnlichen Aufenthalts.

---

## 9. Datensicherheit

- Die gesamte Verbindung ist mit TLS verschlüsselt.
- Passwörter werden ausschließlich als Hash gespeichert.
- Der Zugriff auf Datensätze ist datenbankseitig je Nutzer beschränkt
  (Row Level Security); ein manipulierter Client kann keine fremden
  Daten lesen.
- Am Router ist kein Port geöffnet; der Server ist ausschließlich über
  einen ausgehenden Tunnel erreichbar.

---

## 10. Änderungen

Ändert sich die App wesentlich, wird diese Erklärung angepasst. Die
jeweils geltende Fassung ist in der App und unter ⟨URL der
Datenschutzerklärung⟩ abrufbar.
