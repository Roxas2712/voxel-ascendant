# VASC Runtime-Audit — 25.09.2026

Basis: GitHub-Release v3.0.45 (`f3c663f308d44a020fbe8ae91e726d3366d7fc58`) plus Terrarium-Integration rc.1 (`a87d6e8dbc1417b1932e60952c781a26ae94c238`). Ergebnis: lokaler Kandidat **3.0.46-rc.2**. Kein Push und keine Veröffentlichung.

## Umfang und Aussagekraft

Repositoryweiter Syntax- und Referenzscan aller **857 Lua-Dateien** einschließlich beider Generationen, integrierter Module, Daten und Tests. **1.897 literale `V.require`-Referenzen** haben einen vorhandenen Modulpfad; Kommentare wurden herausgefiltert. Dies ist eine Existenzprüfung, kein Beweis für jede dynamische oder generationsabhängige Aufrufkombination. Die Gen2-Modellpfade werden zusätzlich durch den vorhandenen Routing-Test geprüft.

Vertieft geprüft wurden Fehler- und Ressourcenpfade von Schatten, Terrarium-Effekten und Cobblemon-Modellen sowie Stichproben in Modulrouting, HD-Inhalten/Receipts, Sprite-Downloads, Terrain-Streaming und Diagnostik. Die bestehenden Fachtests decken außerdem Kampfbesitz, Übergänge, UI-Eingabe, Einstellungen, mobile Renderregeln und Kartenwechsel ab. Eine manuelle Zeile-für-Zeile-Prüfung jedes Moduls oder ein Beweis vollständiger Fehlerfreiheit ist damit nicht verbunden.

Die gelieferten Designmodule wurden als Inhalte behandelt. Ihre 30 Herkunfts-Prüfsummen bleiben gültig; sämtliche 15 neuen Terrarien und 43 exakten Kartenbindungen bleiben enthalten.

## Behobene Befunde

| Priorität | Befund und Auswirkung | Korrektur / Nachweis |
| --- | --- | --- |
| Hoch | `CobblemonContent`: Bei syntaktisch ungültigem JSON liefert der Decoder `nil`, ohne zwingend zu werfen. Der bisherige `pcall`-Erfolg reichte nicht aus; `r.schema` konnte den Start abbrechen. Auch JSON-Skalare waren betroffen. | Ergebnis muss eine Tabelle sein. Neun beschädigte oder unpassende Receipt-Formen lassen die mitgelieferten Modelle verfügbar. |
| Hoch | Gen2 `ShadowMap.available()` forderte bei jeder Abfrage die kleinste Schatten-Canvas an. Eine anschließend benötigte größere Auflösung wurde dadurch fortlaufend neu angelegt. | Nach der ersten Auswahl ist die Verfügbarkeitsprüfung lesend. Reproduktion: 1.201 Anlegeversuche über 600 simulierte Frames vorher, **1 danach**. Mobile- und OFF-Regeln bleiben erhalten. |
| Mittel | Beide Schattenmodule verloren bei Invalidation oder fehlgeschlagenem Größenwechsel Objektverweise ohne explizites Freigeben. Temporäre ImageData wurde ebenfalls nicht explizit freigegeben. | Canvas, Ersatzbild und ImageData werden im jeweiligen Erfolgs-/Fehlerpfad freigegeben. Fehlversuche bleiben bis zur ausdrücklichen Invalidation gesperrt; danach ist Wiederherstellung möglich. |
| Mittel | `Dome.prepare()` akzeptierte vorhandene Ressourcen vor Prüfung des Fehlerzustands. Nach einem Draw-Fehler liefen Draw und Meldung deshalb erneut pro Frame. | Fehlerstatus hat Vorrang. 120 Folgeframes erzeugen keinen weiteren Draw-Fehlerbericht. `release()` erlaubt einen neuen Versuch. |
| Mittel | Der optionale Hintergrund kompilierte seinen Shader außerhalb des Schutzblocks. Fehlgeschlagenes Terrarium-Lichtbaking konnte bis zum Kampf-Renderer durchschlagen. | Hintergrund und Zusatzlicht fallen lokal aus, melden einmal und behalten die Geometrie. Tests für Compiler-, Draw-, Pixel-, Upload- und Lichtvorbereitungsfehler; Wiederherstellung nach Release. Gen2 meldet jetzt auch Kuppelfehler. |
| Mittel | Ein nicht verfügbares oder ungültiges Cobblemon-Modell wurde bei wiederholten Anfragen immer neu gelesen/geprüft und gemeldet. | Fehler werden pro Inhaltsstand gespeichert: 600 wiederholte Anfragen verursachen einen Leseversuch/eine Meldung. Inhaltsaktivierung erhöht die bestehende `epoch` und ermöglicht erneut das Laden. |
| Mittel | Cobblemon-Texturaufbereitung gab bereits erzeugte FileData, ImageData oder GPU-Bilder bei späteren Fehlern nicht zuverlässig frei. | Explizite Ressourcenbesitzliste; fehlgeschlagene Dekodierung, fehlender Layer, Blend-, Upload- und Filterfehler hinterlassen im Test keine eigenen Ressourcen. Nur das vollständig fertige Bild geht an das Modell. |

Zusätzlich korrigiert: Der bestehende `gen1_cobblemon_grass_visibility_test` stellte keine `love`-Umgebung bereit. Das war ein Fehler der Testumgebung, kein nachgewiesener Spielabsturz.

## Verifikation

- **34/34 Headless-Fachtests erfolgreich**, einschließlich vier neuer Testdateien und erweitertem Kuppeltest. Vorher/Nachher-Reproduktionen der neuen Fehlergruppen liegen im Lieferordner.
- **3/3 vorhandene native GPU-Tests erfolgreich**: Nebelkomposition, mobiles Nebelmesh und 72 lokale Lichtquellen einschließlich Verdeckung, OFF und Reset.
- Reale OpenGL-Canvas-Prüfung für beide Schattenmodule: jeweils 600 stabile Abfrage-/Auswahlzyklen bei 2048 Pixeln mit nur einer Canvas-Anlegung.
- Native Gen1-Prüfung: **30/30 Szenen** (alle 15 neuen Terrarien, seitliche und rückwärtige Kamera), Silph-Storywechsel, Hochformat/Touch-Darstellung und Kampfaktion bestanden. Stichproben der erzeugten Bilder visuell geprüft.
- Native Crystal-Prüfung: **4/4 Kampfarten** (MAP, ARENA, DISCS, TERRARIUM) bestanden. Ein absichtlich ausgelöster Lightmap-Fehler erhielt das Terrarium und den Kampf; anschließendes Release stellte die Beleuchtung wieder her.
- Vollständiges ZIP: Syntax aller Lua-Dateien, ZIP-CRC, Dateihashes beider Receipts und alle 30 unveränderten Design-Prüfsummen geprüft. Einzelwerte stehen in `verification.json`.

Die Code-Fachtests laufen unter der LuaJIT-Laufzeit von LÖVE 11.5. Native Grafikprüfungen liefen unter macOS. Die bereitgestellte Gen1-Testumgebung hatte zunächst keine Crystal-Sprites; für Gen2 wurde eine getrennte Umgebung mit dem vorhandenen Crystal-Assetcache verwendet. Weitere verworfene Driver-Läufe griffen auf absichtlich nicht öffentliche Diagnose-APIs zu. Diese Testaufbaufehler wurden getrennt protokolliert und zählen nicht als bestandene Läufe oder Produktionsfehler.

## Laufzeitbewertung und verbleibende Prüfflächen

Die beiden belegten Verbesserungen reduzieren GPU-Allokationen beziehungsweise wiederholte Modell-Ladeversuche. Daraus wird keine ungemessene FPS-Steigerung abgeleitet. Normale Terrarium-Geometrie und Kontaktlichtkarten sind bereits gecacht; diese Caches bleiben auf vier Szenen begrenzt. Die neue Schutzfunktion für die Lichtvorbereitung erzeugt keine zusätzliche Closure pro Frame.

Weiteres Optimierungspotenzial liegt bei den kleinen, pro Frame erzeugten Lichttabellen und beim erstmaligen Laden großer Szenen/Modelle. Vor Änderungen sollten reale Framezeit- und Speicherprofile auf dem betroffenen Gerät zeigen, dass diese Pfade relevant sind. Allgemeine Cachevergrößerungen oder eine globale Abschaltung von Effekten sind keine nachgewiesene Verbesserung.

Nicht vollständig abgedeckt: physische Android-/iOS-/Windows-GPUs, Langzeit-Speicherdruck, alle optionalen Mod-Kombinationen, jede Speicherstandvariante und sämtliche Kampf-/Menüsequenzen. Gold/Silver wurden durch gemeinsame Gen2-Code- und Policytests abgedeckt; der native Gen2-Spieltest verwendet Crystal. Der Prüflauf hat keine echten Spielstände verändert und keine Supportberichte versandt.

## Reproduzierbare Testdateien

- `tests/cobblemon_receipt_fallback_test.lua`
- `tests/cobblemon_failure_lifecycle_test.lua`
- `tests/shadow_resource_lifecycle_test.lua`
- `tests/terrarium_effect_failure_test.lua`
- `tests/terrarium_dome_failure_test.lua`
- `tests/terrarium_locations_driver.lua`

Im Lieferordner liegen zusätzlich Testprotokolle, native Testtreiber, ein Buildskript und der Patch dieses Audits. Den vollständigen Kandidaten mit geschlossenem Spiel importieren; rc.1 bleibt als vorheriger lokaler Kandidat erhalten.
