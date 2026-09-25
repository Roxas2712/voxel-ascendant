# VASC 3.0.46-rc.5 — Menü-, Download-, Setup- und F3-Prüfung

Lokaler Kandidat vom 25.09.2026. Baut auf rc.4 (`f229b19a8eefa6e125e5fb1fcf18a86c0e0a0e18`) und dem zuvor bezogenen öffentlichen v3.0.45-Stand auf. Sämtliche Terrarium-Zuordnungen und früheren Korrekturen bleiben enthalten. Kein GitHub-Publish.

## Behobene Fehler

| Bereich | Fehler und Korrektur | Regression |
| --- | --- | --- |
| Bedingte Einstellungsmenüs | Neue HELP-Kennungen wurden beim Neuladen verworfen. Beide Menücontroller erhalten die vorhandene Hilfezeile einschließlich namensgebundener Kennungen. | `menu_help_refresh_test.lua` |
| Download-Menüs | Neue oder entfernte Inventarzeilen verschoben die gewählte Aktion. Die Auswahl folgt jetzt der Sammlung/Paketkennung bzw. Aktion; Scrollposition und HELP bleiben konsistent. | `download_menu_refresh_test.lua` |
| Download-Status | Ein Statuswechsel konnte aus „Zurück“ versehentlich „Import“ machen. Die Aktion bleibt ausgewählt; entfällt sie, wird Zurück gewählt. Alternative Links erscheinen nur mit bekanntem Paket. Erfolgreiche Bestandsprüfung fordert keinen unnötigen Neustart/Download mehr. | `download_status_navigation_test.lua` |
| F3-Hilfe | Zurück sprang zur ersten Hauptzeile. Jetzt bleibt die Herkunftsgruppe ausgewählt. Leere Gruppen öffnen nicht; optionale Statusfehler zeigen „Nicht verfügbar“. Die Schrift unterstützte die angezeigten Pfeilzeichen nicht; stattdessen stehen lesbare Tastenbezeichnungen. | `f3_navigation_test.lua`, native Sichtprüfung |
| Setup speichern/übernehmen | Fehlgeschlagene Entwurfs- und Abschluss-Schreibvorgänge konnten abstürzen oder eine teilweise Übernahme hinterlassen. Der Guide bleibt bei Fehlern offen; Apply setzt Werte und bereits aufgerufene Effekte zurück, stellt den Options-Writer wieder her und ermöglicht Wiederholung. | `setup_persistence_failure_test.lua` |
| Setup fortsetzen | Falsche Datentypen, ungültige Einstellungswerte und gebrochene/nichtendliche Seitenzahlen wurden übernommen. Jetzt werden Werte geprüft und Seiten auf gültige Ganzzahlen begrenzt; beschädigte Unterbrechungsmarker werden toleriert. | `setup_resume_validation_test.lua` |

## Prüfung

**79/79 automatisierte Lua-Suiten bestanden.** Enthält die 72 vorhandenen Suiten und sieben neue Regressionstests. Die zusätzliche `download_batch_pause_resume_test.lua` prüft den echten Installer/Importer mit künstlichem Transport: Zustimmung erforderlich, Abbruch im zweiten Teil, Wiederaufnahme mit neu erzeugter Installer-Instanz, Wiederverwendung geprüfter Teile, erneutes Laden beschädigter Cacheteile, begrenzter Fortschritt, einmalige Aktivierung und Bereinigung. Die Hashfunktion dieses kleinen Fixtures ist deterministisch; sie ersetzt keinen kryptografischen Integritätstest mit echten Paketen.

Native LÖVE-11.5-Läufe mit getrennten QA-Spielständen:

- Gen1/Red: alle 15 registrierten Einstellungsbereiche öffnen, Kontext-Hilfe öffnen/schließen und zum Hauptmenü zurückkehren.
- Gen2/Crystal: dieselbe Navigation für alle neun registrierten Einstellungsbereiche.
- F3: fünf Gen1- und vier Gen2-Untergruppen jeweils bei 1100×760 und 540×960; Öffnen, Gamepad-Zurück, Fokus auf der Herkunftsgruppe und vollständiges Schließen.
- Downloads: alle vom Katalogmodell gelieferten Familien öffnen, Status öffnen, tatsächlichen Bestätigungsdialog abbrechen; ein gesicherter Installer-Startzähler bleibt null.
- Gen1-Setup: alle zehn Hauptseiten in beiden Formaten zeichnen; Vorschau verändert keine Live-Einstellung. HD, Crystal und MMO öffnen die jeweils erwartete Sammlung. Stadium-Picker-Abbruch und Picker-Fehler werden simuliert, der Guide und Entwurf bleiben erhalten.
- Entwurf pausieren/fortsetzen und beschädigte gespeicherte Daten im echten Host wiederherstellen.
- Fünf Varianten der Kampfsteuerung in beiden Formaten; Entwurf speichern, zurücksetzen, anwenden und wieder öffnen. Die normale Positionsänderung erhält die gewählte Darstellungsform.
- Grafiktest abbrechen: vollständiger ursprünglicher Spielstand, Welt, Position, Menüstack, Einstellungen, Animationsfunktion und Wetteruhr bleiben erhalten; kein Spielstand-/Options-Schreibvorgang. Tatsächlicher Shader/Depth/Readback-Preflight erfolgreich. Empfehlungsregeln berücksichtigen Fehler, unklare und nicht ausgeführte Messungen.

Der komplette Paketbau prüft die Lua-Syntax, ZIP-CRC, sämtliche Datei-Hashbelege und die 30 unveränderten Original-Terrarium-Quelldateien. Die erzeugte `verification.json` enthält die konkreten Paketwerte. `QA/` in der Auslieferung enthält native Protokolle, Screenshots, Headless-Ergebnisse und ausführbare Prüfskripte. Die drei `*-before.log` dokumentieren absichtlich reproduzierte Fehler des rc.4-Stands.

## Grenzen und Zuständigkeiten

Die Prüfung deckt die beschriebenen Flüsse und Fehlerfälle ab, nicht jede Kombination aller Mods, Spielstände und Eingaben. Native Bilder wurden mit der englischen Hostsprache aufgenommen; vorhandene deutsche Menü-/Sprachregressionen bleiben im grünen Gesamtlauf. Physische Android-/iOS-Geräte und reale CDN-Transfers waren nicht Bestandteil dieser Runde. Der Dateiauswahldialog selbst wurde nicht automatisiert; dessen Rückgaben wurden simuliert.

„Dein Look“ ist im bestehenden Aufbau ein Gen1-Guide. Gen2 nutzt seine eigenen Einstellungsmenüs und die gemeinsame F3-Hilfe; diese Runde portiert den Guide nicht nach Gen2.

Rollback beim Setup behandelt geworfene Fehler und gemeldete Fehlschläge. Host-APIs, die einen fehlgeschlagenen Dateizugriff nicht melden, können vom Mod nicht als Fehlschlag erkannt werden. Optionsdatei und Guide-Beleg sind keine gemeinsame atomare Dateitransaktion; ein Prozessabbruch exakt zwischen beiden Schreibvorgängen bleibt außerhalb dieser Garantie. Eine fehlgeschlagene Wiederherstellung wird im Guide ausdrücklich angezeigt.
