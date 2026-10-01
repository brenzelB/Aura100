# Aura Quest 1.0.1 – Build 5

Android: Paket `com.auraquest.aura_quest`, Versionsname `1.0.1`, Versionscode `5`.
iOS: Bundle-ID `com.auraquest.auraQuest`, Version `1.0.1`, Build `5`.

## Google Play – kopierfertige Versionshinweise

```text
<de-DE>
• Duelle und das Entfernen von Trophäen funktionieren zuverlässiger.
• Nach einem Statistik-Reset werden die Profilanzeigen korrekt aktualisiert.
• Einladungen und Freundschaftsanfragen erscheinen auch nach Verbindungsabbrüchen.
• Neues Logo und ein eigenständiges Editorial-Growth-Design mit Light und Dark Mode.
</de-DE>
<en-US>
• More reliable duels and trophy removal.
• Profile displays refresh correctly after resetting stats.
• Invitations and friend requests catch up after connection interruptions.
• New logo and a distinctive Editorial Growth design with light and dark modes.
</en-US>
```

## Apple App Store – Neu in dieser Version

```text
Du kannst Duelle und Trophäen jetzt zuverlässiger verwalten. Nach einem Statistik-Reset zeigen die Profilansichten den aktuellen Stand. Einladungen und Freundschaftsanfragen werden nach Verbindungsabbrüchen nachgeladen. Außerdem enthält diese Version das neue Logo und das neue Editorial-Growth-Design mit Light und Dark Mode.
```

## Build und Upload

Die Release-Pipeline `.github/workflows/release.yml` mit `build_number=5` starten.
Sie erstellt `android-release-bundle-5` und `ios-unsigned-archive-5` aus demselben Commit.

Das signierte Android-AAB in einem neuen Release des gewünschten Play-Testkanals
hochladen. Bereits installierte Tester erhalten das Update nach dessen Freigabe
über Google Play. Paket-ID und vorhandener Upload-Schlüssel bleiben erhalten.

Der Apple-Build ist ein **unsigniertes Archiv für die Build-Prüfung**. Er kann
noch nicht in App Store Connect hochgeladen werden. Vor einem Apple-Upload fehlen
die Apple-Distributionssignatur und das Provisioning-Profil; für iOS-Push fehlen
außerdem Firebase-/APNs-Konfiguration und ein Gerätetest.

Die Pipeline lädt nichts automatisch in Google Play oder App Store Connect hoch.
Ein Store-Upload und dessen Freigabe sind eigenständige Schritte.
