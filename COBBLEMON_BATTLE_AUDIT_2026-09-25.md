# VASC 3.0.46-rc.7 — Cobblemon-Kampfanimationen

Lokaler Kandidat auf rc.6 (`9b5fbdd760f118323ed8a980eaacf31f41f0a947`). Der öffentliche Push bleibt angehalten.

## Verhalten

Bei aktivem Cobblemon-Modell werden physische, spezielle und Status-Attacken getrennt auf unterstützte Originalclips abgebildet. Eine explizite Kategorie der Attackendefinition hat Vorrang; ohne Kategorie gilt die Gen1/Gen2-Typzuordnung. Statusattacken mit Stärke 0 verwenden den Statusclip. Unbekannte oder nicht verfügbare Kategorien verwenden den eigenständigen VASC-Standardclip, niemals versehentlich den Originalclip einer anderen Kategorie.

Treffer benutzen den Cobblemon-Rückstoß (`recoil`) statt des Ruf-/Auftrittsclips. In Gen2 löst auch die beobachtete HP-Abnahme diesen Clip aus; eine bereits laufende Trefferreaktion wird dadurch nicht erneut gestartet. Fehlt ein Originalclip, bleibt die VASC-Ersatzbewegung. Stadium behält seine eigene Bewegungszuordnung. Die VASC-Attackeneffekte (z. B. Strahlen, Trefferbilder und Geräusche) werden nicht durch Skelettanimationen ersetzt.

Mehrere unterstützte Bedrock-Clips einer Pose laufen gemeinsam: Translation und Rotation addieren sich, Skalierung multipliziert sich, und jede Spur behält ihre eigene Schleifenlänge. Eine ungültige Spur verwirft nicht die gültigen Spuren derselben Haltung. Der bestehende Posepuffer wird wiederverwendet.

Cobblemon ist jetzt auch in der dauerhaften Gen2-Auswahl für Kampfmodelle verfügbar. Beim Umschalten auf Crystal werden die 3D-Ressourcen freigegeben, ohne unnötig Stadium-Pakete zu laden. Der Gen2-Pfad für den gemeinsamen Stadium-Inhaltsstatus ist korrigiert.

## Datenbestand

463 Arten und 1.894 Varianten wurden mit Importrevision 4 neu erzeugt; alle Varianten konnten vorbereitet werden. 1.069 alte, durch Hash benannte Modellobjekte wurden durch ihre neuen Versionen ersetzt. Originale Quelldateien, Texturen und Lizenzdateien bleiben erhalten. Alte optionale Cache-Belege werden nur bei passender Importrevision und Katalog-Prüfsumme aktiviert.

Originale, erfolgreich importierte Aktionen bei den 463 Normalvarianten (eigene Ascendant-Modelle nicht als Cobblemon-Originale gezählt):

| Aktion | Arten |
| --- | ---: |
| Physischer Angriff | 55 |
| Spezieller Angriff | 50 |
| Status-Attacke | 48 |
| Rückstoß | 100 |
| Ruf/Auftreten | 297 |
| Besiegtwerden | 108 |

Das ist die gemessene Unterstützung der ausgelieferten Daten, keine Behauptung, dass jede Art all diese Originalclips besitzt. Fehlende Aktionen bleiben durch VASC abgedeckt. `QA/action-inventory.json` enthält die Zuordnung und Importwarnungen pro Art.

## Prüfung

- 85/85 Headless-Suiten: Kategorien, beide Generationen, benannte Attacken ohne numerische ID, fehlende/ungültige Clips, Priorität besiegter Modelle, Rückstoß, unveränderte Stadium-Zuordnung, Shader-/Modellfehlerpfade und alter Cache.
- 25.944 Animations-Stichproben über alle 463 Normalvarianten: jede zugeordnete Aktion an acht Zeitpunkten, auch nach Schleifenübergängen; keine ungültigen Knochenwerte.
- Native Red-Prüfung: tatsächlicher `performMove`-Hook für Tackle, Donnerblitz und Heuler; passende Originalclips, Rückstoß und Wechsel zu Crystal. Isolierte QA-Kampfsituation, keine vollständige Kampagne.
- Native Crystal-Prüfung: tatsächlicher `animForMove`-Hook mit Smogon, drei Kategorien, künstlich fehlender Spezialclip, Trefferereignis und HP-Rückstoß; Crystal-Wechsel mit weiter vorhandenen Attackeneffekten, Rückkehr zu Cobblemon und reguläres Kampfende.
- Beide Dex-Renderer erneut nativ mit allen angebotenen Bildquellen geprüft. Screenshots dokumentieren die Darstellung; keine alleinige Freigabe aller Animationen jeder Art.

Die nativen Treiber stehen unter `tests/native/cobblemon_gen1_battle_audit.lua` und `tests/native/cobblemon_gen2_battle_audit.lua`. Logs, lokale Startkonfiguration, Inventar und Screenshots liegen neben dem ZIP in `QA/`.

## Grenzen

Keine vollständige Ausführung von Cobblemons Kotlin-Posern, allen Molang-Abfragen, zufälligen Verhaltensregeln, Blend-Kurven oder animierten Texturschichten. Nicht unterstützte Clips nutzen weiterhin Ersatzbewegungen. Für diese Änderung wurde keine neue Außenwelt-/Schwimmzustandslogik gebaut. Geprüft unter macOS/LÖVE 11.5; kein physischer Mobilgerätetest. Der bekannte schmale Dex im Hochformat bleibt offen.
