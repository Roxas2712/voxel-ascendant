# VASC — zweite Performance-Prüfung, 25.09.2026

Basis: 3.0.46-rc.2, Commit `7191414d2bbeb14e3c085b9a11966d63d2ca0957`. Ergebnis: lokaler Kandidat **3.0.46-rc.3**. Enthält weiterhin sämtliche Terrarien und die sieben Fehlergruppen-Korrekturen aus rc.2. Keine Veröffentlichung.

## Weitere Befunde und Änderungen

### 1. Crystal-Bildauswahl: wiederholte Dateizugriffe

`lib/Gen2CrystalFronts.lua` und `gen2/lib/Gen2CrystalFronts.lua` lasen PNG-Dateien, um ihre Existenz festzustellen. Bei einer fehlenden normalen Variante wurde derselbe Pfad sogar zweimal pro Abfrage gelesen. Die ORAS-Team-/Box-Bildauswahl löst den Pfad vor ihrem eigentlichen Bildcache auf; dieser Cache verhindert die vorgeschalteten Zugriffe daher nicht.

Nun wird die Existenz mit `mod.info` geprüft und je Pfad gespeichert. Der Cache hält ausschließlich Wahrheitswerte, maximal 999 Arten × zwei Varianten. Ältere Hosts ohne Metadaten-API verwenden einmaliges Lesen. Shiny kann weiterhin auf Normal und fehlende Kunst auf den aufrufenden Provider zurückfallen. Fehlerhafte API-Aufrufe werden nicht als dauerhaft fehlende Datei gespeichert. `invalidate()` ermöglicht erneute Prüfung; ein Mod-Neuladen erzeugt ebenfalls einen neuen Cache. Rückgabereceipts bleiben getrennte Tabellen.

Die sechs im nativen Test abgefragten optionalen Crystal-Dateien fehlen im aktuellen Paket. Das bisherige Fallback-Ergebnis bleibt gleich. Der irreführende historische Modulkommentar über generell mitgelieferte Bilder wurde entsprechend korrigiert.

### 2. Gen2: wiederholte Plattformprüfung während des Zeichnens

`ShadowMap`, `AntiAlias` und `Voxel3D` verwendeten jeweils eine eigene, pro Aufruf ausgeführte Erkennung über `love.system` und `Platform.detect`. Diese Zugriffe können im Mod-Sandboxkontext geschützte Host-Aufrufe beziehungsweise fehlgeschlagene Modulzugriffe auslösen.

Alle drei verwenden jetzt die bereits vorhandene `CanvasPresentation.OS`-Erkennung. Damit folgen Auflösung, Beleuchtung und Rückkehr zum Ziel-Canvas derselben Quelle. Native iOS-/Android-Antworten haben weiterhin Vorrang vor einer Desktop-Kompatibilitätsangabe. Legacy-Hosts mit gesperrter System-API werden über den bestehenden `_os`-Fallback korrekt erkannt. Ein Wechsel der Fensterorientierung braucht keine neue Betriebssystemerkennung.

### 3. Terrarium: vermeidbare Lichttabellen pro Frame

Lampen, Normalen, Besitzerobjekte, Fülllichtfarbe, Farbstimmung und Standardpaletten wurden fortlaufend neu aufgebaut. Nun wird das Lichtrig pro Arena wiederverwendet. Positionen, Farben, Bodenhöhe und Lava-Puls werden weiterhin aktualisiert. Desktop behält drei Lampen, Mobile/Handheld zwei.

Die Arena-Schlüssel sind schwach referenziert; beendete Arenen werden nicht festgehalten. `release()` leert den Rig-Cache ausdrücklich. Unterschiedliche Arenen erhalten eigene veränderliche Daten. Die lokale Fehlerbehandlung und Wiederherstellung aus rc.2 bleibt bestehen.

## Messungen

| Fall | Vorher | Nachher |
| --- | ---: | ---: |
| 600 Abfragen derselben Art, fehlende Shiny-Variante und vorhandene Normalvariante (Regressionstest) | 1.200 Dateizugriffe | 2 Prüfungen |
| Native Abfragen von sechs Arten, 600 Aufrufe, vorhandener Paket-/Hostzustand | 1.200 Leseversuche | 6 Metadatenprüfungen, 0 Leseversuche |
| Zeit für diesen nativen Aufrufblock | 10,8835 ms | 0,2318 ms |
| 10.000 vorbereitete Terrarium-Lichtaufrufe: erzeugte Lua-Daten bei gestopptem GC | 29.924,5 KiB | 5.084,15 KiB |
| Zeit für diesen isolierten Licht-Aufrufblock | 8,576 ms | 1,653 ms |
| 1.800 Gen2-Canvas-Policy-Abfragen, iOS-Testfall | 1.800 zusätzliche Host-Probes | 0 |

Die Lichtvorbereitung erzeugt in diesem isolierten Test etwa **83 % weniger temporäre Lua-Daten**. Gemessen wurde nach 1.000 Aufwärmaufrufen unter LuaJIT; GPU-Arbeit war beim Licht-Mikrobenchmark durch einen kleinen Stage-Stub ersetzt. Die Zeitwerte sind einzelne lokale Messläufe und keine FPS-Prognose. Der native Dateitest benutzt den echten Mod-Dateizugriff. Die funktionalen Tests prüfen die dauerhafte Reduktion der Aufrufe unabhängig von schwankenden Laufzeiten.

## Verifikation

- **37/37 Headless-Fachtests bestanden.** Neu: Crystal-Dateicache, gemeinsame Plattformquelle und Lichtwiederverwendung.
- Crystal: beide Modulvarianten, mit/ohne Metadaten-API, Shiny-/Normal-Fallback, fehlende Kunst, Mega-Ausschluss, Dex-Grenzen, getrennte Receipts, expliziter Reload und Erholung nach temporärem Lesefehler.
- Plattform: iOS, Android, Windows, Linux, Desktop-Kompatibilitätsangabe auf Mobile sowie gesperrte System-API ohne Platform-Modul; jeweils 1.800 Policy-Abfragen ohne erneute Host-Probes.
- Licht: 600 animierte Frames mit geprüften Werten, Arena-Trennung, Positions-/Familienwechsel, Desktop/Mobile/Handheld, OFF, Release und 250 nicht mehr festgehaltene kurzlebige Arenen.
- **3/3 native GPU-Fachtests bestanden** (Nebelkomposition, mobiles Nebelmesh, lokale Lichtquellen); beide Schattenmodule behalten ihre einmal erzeugte 2048-Pixel-Canvas über 600 Prüfzyklen.
- Native Gen1: **6/6 Ansichten** für Cinnabar Gym, Pokémon Tower und Viridian Forest; zwei Kameraperspektiven, Hochformat/Touch-Darstellung und Kampfaktion bestanden. Lava-Ansicht visuell geprüft.
- Native Crystal: **4/4 Kampfarten** MAP, ARENA, DISCS und TERRARIUM; absichtlich ausgelöster Lichtfehler und Wiederherstellung bestanden.
- Vollständiger Kandidat: **860 Lua-Dateien** auf Syntax geprüft; ZIP-CRC, alle Dateireceipts und 30 originale Design-Prüfsummen bestätigt. Zahlen und SHA-256 stehen in `verification.json`.

Der erste native Dateitreiber setzte fälschlich voraus, dass optionale Crystal-Dateien vorhanden seien. Der korrigierte Test vergleicht die tatsächlichen Vorher-/Nachher-Ergebnisse und bestätigt deren Gleichheit. Dieser verworfene Testaufbau ist separat protokolliert.

## Grenzen und nächste sinnvolle Messung

Diese Runde konzentrierte sich auf belegte wiederholte Arbeit in Bildauswahl, Plattformprüfung und Lichtvorbereitung. Physische Handy-/Windows-GPUs sowie lange Sitzungen mit vielen optionalen Mods bleiben eigene Prüfflächen. Native Tests hier liefen unter macOS. Für weitere FPS-Optimierung sollte ein konkretes langsames Szenario mit den vorhandenen Komponentenzeitmessungen profiliert werden; diese Änderungen belegen zunächst weniger Datei-/Hostzugriffe und temporäre Daten.

Der Lieferordner enthält Logs, Benchmark, native Treiber, Buildskript und einen Patch relativ zu rc.2. Frühere Kandidaten bleiben erhalten. Zum Import des vollständigen ZIP das Spiel schließen.
