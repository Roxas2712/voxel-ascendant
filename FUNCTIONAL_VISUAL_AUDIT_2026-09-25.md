# VASC 3.0.46-rc.6 — Funktionsmatrix und visuelle Abnahme

Lokaler Kandidat vom 25.09.2026 auf rc.5 (`fcbc78e97a8823304280e7cc1913e25d7552977a`). Enthält sämtliche vorherigen Terrarium- und Audit-Korrekturen. Nicht veröffentlicht.

## Behobene Funktionslücken

1. **Cobblemon im Pokédex:** neue Auswahl COBBLEMON 3D in beiden modernen Dex-Renderern und im Gen1-Setup. Im normalen Menü folgt sie direkt auf Crystal, damit kein fehlendes HD-Paket dazwischenliegt. Gen1: POKÉMON + MODELS → DEX SPRITES. Gen2: SKINS & OVERLAYS → DEX SPRITES. Setup: Pokémon im Pokédex.
2. **Gen2-Bildquelle:** der Host erzwang intern Crystal und ignorierte die angebotenen Alternativen. Crystal, aktiver Spriteanbieter, Spieloriginal und Cobblemon erreichen jetzt den richtigen Renderer.
3. **Gen2-Dexdesign:** der Host las den allgemeinen UI-Skin statt `pokedexStyle`. Liste und direkter Dateneintrag respektieren jetzt die eigene Wahl „Spielstandard“.
4. **Gen2-Dexdaten:** das Gen2-Format enthält direkte Texte in zwei Seiten und eine kombinierte Fuß/Zoll-Zahl. Der alte Adapter erwartete einen Gen1-Textschlüssel und fertige Höhenfelder. Beide Texte und die Größenangabe erscheinen jetzt; Zeilentrennungen mitten im Wort werden zusammengeführt. Originaldaten und Gesehen-/Gefangen-Markierungen bleiben unverändert.
5. **Falscher Downloadbedarf:** Gen2-Crystal-Dexbilder nutzen den eigenen vorhandenen Frontbild-/Ersatzpfad. Die Auswahl fordert kein sachfremdes KASC-Spritepaket mehr an. Gen1-KASC-Crystal und HD behalten ihre tatsächliche Inhaltsabhängigkeit.
6. **Setup-Kampfdetails:** die Sichtbarkeitsprüfung verwendete einen veralteten Seitennamen. Terrarium-, Arena- und Discs-spezifische Optionen werden nun nur bei der passenden Kulisse gezeigt.
7. **Setup-Dexvorschau:** „Spielstandard“ zeigt den aktiven Spriteanbieter; eine im Hintergrund gespeicherte Cobblemon-Wahl für den modernen Dex bestimmt diese Vorschau nicht mehr.

Die neue Modellvorschau besitzt genau einen Actor, Shader und Canvas je Dex-Screen. Artwechsel, Content-Aktivierung und Screen-Ende haben definierte Freigaben. Fehlende Arten und Renderfehler bleiben beim Sprite-Ersatz; ein fehlgeschlagener Aufbau wird nicht pro Bild erneut versucht. Der Gen2-Host erhält nur die Vorschau-Funktionen, keinen offenen Zugriff auf den internen Renderer-Loader. Die Darstellung nutzt tatsächliche Modellmaße und verändert keine Kampf-, Welt- oder Spielstandregeln.

## Funktionstest-Matrix

| Prüfung | Gen1/Red | Gen2/Crystal |
| --- | ---: | ---: |
| Einstellungsbereiche | 15 | 9 |
| Unterschiedliche getestete Einstellungskennungen | 110 | 118 |
| Ausgeführte Einstellungsübergänge | 455 | 426 |
| Davon erwartete Inhalts-/Download-Sperren | 10 | 10 |
| Ausgeführte Menüaktionen | 15 | 14 |
| Ausgeführte F3-Aktionen im Weltkontext | 41 | 45 |

Die Einstellungsprüfung benutzt die tatsächlichen Menü-Deskriptoren und Besitzerobjekte. Jeder deklarierte Wert der in dieser Konfiguration sichtbaren ModSettings wird über den echten Schritt-Handler angesteuert; Verfügbarkeitsregeln, effektiver Wert, Callback-Fehler und ein echter gezeichneter Frame werden geprüft. Inhaltsabhängige Optionen dürfen ihren Beschaffungsdialog öffnen und behalten den bisherigen Wert. Eigene Pipeline-/Profil-Deskriptoren werden zusätzlich vor/zurück betätigt. Bildschirmaktionen werden geöffnet und wieder verlassen. Die genaue Tabelle steht in `QA/menu-value-matrix.tsv`; die nativen Logs enthalten auch die Aktionsnamen.

Das ist eine Funktionsprüfung der registrierten Optionen in diesen QA-Konfigurationen, keine Behauptung, dass jede sichtbare Wirkung jeder Option in sämtlichen Karten, Kämpfen, Modkombinationen und Geräten geprüft wurde. Beispielsweise beweist eine erfolgreich übernommene Wetteroption im Innenraum noch nicht ihre Darstellung in jeder Außenwelt.

Zusätzlich:

- **211 Setup-Auswahlen in 23 Seiten-/Kontextfällen**, einschließlich aller fünf Kampfkulissen auf der Detailseite. Keine dieser Entwurfsänderungen schreibt Live-Einstellungen. Haupt- und Detailseiten werden in Quer- und Hochformat gezeichnet.
- **Dex:** jede angebotene Bildquelle in beiden Generationen; Cobblemon-Liste und Datenseite; Pikachu, Bisasam, Glurak, Endivie, Lugia und Rayquaza, soweit im Host vorhanden. Modellfreigabe nach Schließen und Rückkehr zum nativen Dex werden geprüft. Fehlende HD-Inhalte nutzen im isolierten Renderer-Test den vorgesehenen Ersatzpfad; die Menümatrix prüft separat die tatsächliche Inhaltssperre.
- **82/82 Headless-Suiten bestanden.** Neue Tests betreffen Modell-Ressourcen/Fehlerpfade, Gen2-Dexoptionen/Daten/Inhaltsbedarf und kontextabhängige Setup-Zeilen. Der Download-Statustest prüft zusätzlich, dass 120 unveränderte Refreshes dieselben Aktionszeilen behalten, Fortschritt aber weiter aktualisiert wird.
- Die bisherigen Tests für Setup-Speicherfehler/Rollback, Download-Wiederaufnahme, Hilfezeilen und F3-Navigation bleiben enthalten.

Die reproduzierbaren nativen Treiber liegen unter `tests/native/`: `menu_functional_audit.lua`, `dex_source_audit.lua`, `setup_choice_audit.lua`, `f3_action_audit.lua`. Sie verlangen ausdrücklich eine QA-Identität. Die lokale Startkonfiguration, Testprotokolle, Matrix und Screenshots liegen unter `QA/` der Auslieferung.

## Visuelle Abnahme und Optimierungen

Native Screenshots bei 1100×760 und 540×960 zeigen Dex-Quellen, Modelle, Setup-Haupt-/Detailseiten und Einstellungsbereiche. Die Dex-Bedienelemente wurden zusätzlich mit deutscher UI-Sprache aufgenommen; Pokédex-Texte und Artnamen stammen weiterhin aus dem jeweiligen Host-Spiel und werden dadurch nicht künstlich übersetzt. Sichtprüfungen deckten die falschen Gen2-Dexdaten und die unpassenden Setup-Detailzeilen auf; korrigierte Bilder liegen bei.

Setup-Hilfetext erzeugt im Querformat keine zusätzliche Mess-Schrift pro Frame mehr, sondern nutzt den vorhandenen Fontcache. Der Download-Status baut seine Aktionszeilen nur bei relevanten Zustandsänderungen neu auf. Die neue Modellvorschau hält Ressourcen während unveränderter Anzeige. Es wird kein ungemessener FPS-Gewinn behauptet. Ein weitergehender Cache für den Download-Katalog wurde in dieser Runde nicht eingeführt.

**Offener UX-Punkt:** Der Pokédex behält im Hochformat sein breites Layout mit freien Flächen oben/unten. Er ist bedienbar, aber Text und Modellfenster wirken auf einem schmalen Bildschirm klein. Ein eigener Hochformat-Aufbau mit neu angeordneten Daten, Modell und Touch-Zielen bleibt eine separate Verbesserung; die jetzige Sichtprüfung ist dafür keine pauschale Freigabe.

Native Tests laufen auf macOS/LÖVE 11.5. Kein physischer Android-/iOS-Test und kein echter CDN-Großdownload. Stadium-Dateiauswahl und Support-Versand werden nicht gegen echte externe Ziele ausgeführt; bestehende Tests benutzen dafür simulierte Rückgaben/Callbacks. F3-Aktionen dieser Runde wurden im Weltkontext aktiviert; Kampfphasen behalten die bisherigen separaten Regressionstests. Test-Spiele und Artefakte sind von normalen Benutzerspielständen getrennt.
