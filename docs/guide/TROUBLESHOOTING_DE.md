# Fehlerbehebung und Diagnose

Stand: 29. August 2026

> Diese Seite verspricht keine Behebung der offenen RC11-Nutzerfehler. Der
> verbindliche Status steht im
> [Fehlerarbeitsvorrat](../maintainer/RC11_ERROR_BACKLOG.md). Ein grüner
> Headless-Test darf dort keinen Eintrag ohne Fach- und gegebenenfalls
> Screenshotbeleg schließen.

## Sichere Erstmaßnahmen

1. Im betroffenen Bereich auf `GAME DEFAULT`, `STANDARD`, `OFF` oder
   `VASC DEFAULT` zurückstellen.
2. Spiel und Mod-Laufzeit vollständig beenden und neu starten.
3. Nur eine VASC-Laufzeit aktiv lassen; `VASC4J` und ersetzte Einzelpakete
   deaktivieren.
4. Engine-, VASC-, KASC- und Spielversion notieren.
5. Fehler mit genau einer Änderung erneut auslösen.
6. Save, Optionsbucket und `active.json` nicht löschen oder von Hand ändern.

Wenn die native Darstellung funktioniert, ist das ein brauchbarer
Eingrenzungsbeleg. Es beweist aber noch nicht, dass der VASC-Pfad freigegeben
ist.

## VASC startet nicht oder bleibt vollständig nativ

Prüfen:

- unterstützte Edition und Enginebereich `>=0.1.90 <2.0.0`,
- unveränderte Paketstruktur mit `manifest.json` an der ZIP-Wurzel,
- keine zweite VASC-/Voxel-Laufzeit mit demselben Owner,
- Shader- und Depth-Canvas-Fähigkeit des Treibers.

Fehlt beim ersten Einstieg eine erforderliche Engine-Seam, meldet die Gen-1-
Runtime `unsupported` und installiert keinen Voxel-Wrapper. Wird eine zweite
Runtime-Instanz erkannt, wird sie nach sicherem Retirement mit
`restart required` abgewiesen. In beiden Fällen den Prozess neu starten, nicht
per Hot-Reload eine neue Besitzerinstanz erzwingen.

## Kampf fällt auf 2D zurück

Der Rückfall selbst ist die Sicherheitsgrenze. Für einen Bericht festhalten:

- Generation und Edition,
- Provider: DEFAULT, MAP, ARENA oder DISCS,
- HUD: ORAS oder Cartridge/Standard,
- ob der Fehler beim Start, beim echten Einwechseln, bei einer Attacke oder am
  Ende auftritt,
- erster Fehler im Log und ob der nächste Kampf sauber startet.

`BTL-001` (MAP/VOXEL), `BTL-003` (ARENA) und die gemeinsame Matrix `BTL-004`
sind offen. Der headless echte `resolveSwitch -> update -> commitShot`-Basisweg
belegt nicht die noch fehlenden transienten Rendererfehler oder GPU-Pixel.
Bis zur Abnahme `GAME DEFAULT` verwenden.

## MAP fehlt oder ARENA bleibt im nächsten Kampf hängen

1. Kampf vollständig beenden und keinen Hot-Reload ausführen.
2. Den nächsten Kampf mit `GAME DEFAULT` prüfen.
3. Danach die Sequenz MAP → Ende → ARENA → Ende → MAP mit jeweils neuem
   BattleState wiederholen.
4. Verspätete End-/Screen-Ereignisse und die sichtbare Provideranzeige im Log
   erfassen.

Dieser Pfad gehört zu `BTL-002` und ist nicht als behoben abgenommen.

## Falsche Pokémon-, Trainer- oder HUD-Position

- `BATTLE LAYOUT` zunächst für den betroffenen Zieltyp auf 0/0/100 %
  zurücksetzen.
- DEFAULT+Cartridge und DEFAULT+ORAS getrennt prüfen.
- Front-, Back-, Mega-, 16px-, HGSS-32px- und Custom-Sheet-Quelle notieren.
- Kein globales Offset als Workaround auf alle Provider übertragen.

`BTL-005`, `BTL-102` und mehrere Gen-2-HUD-Punkte bleiben offen. Erforderlich
ist ein echter Screenshot mit Build-Hash und genauer Kombination.

## Menüs, Bag, Team, Box oder Dex sind klein, leer oder falsch gefärbt

Die betroffene Oberfläche auf `GAME DEFAULT` beziehungsweise `GAME/KASC`
stellen. Die Auswahl für Overworld-Menüs, Bag, START-Team, Battle-Team,
Pokémon-UI und Battle-HUD ist getrennt; nur den fehlerhaften Owner ändern.

Die Punkte `UI-101` bis `UI-110` sind offen, darunter Fullscreen-Menü,
Navigation, Wide-Bags, Icons, Werte/Typen, Teamfarben, Box/Legacy Bank und
vollständige Rückwege. Bei KASC keine Transfer- oder Save-Daten ändern, um
einen reinen Darstellungsfehler zu umgehen.

## Fly, Surf oder Fishing funktioniert nicht

Auf die native Feldanimation zurückfallen und berichten:

- Edition, Karte und Richtung,
- ausgewählte Spezies/Form und Shiny-Status,
- Erfolg, Abbruch und erneuter Einstieg,
- VASC aktiv oder DEFAULT/2D,
- Controller-/Touchpfad.

Fishing (`FLD-001`), Fly (`FLD-101`) und Surf-Ausrichtung (`FLD-103`) benötigen
erneute Produktpfad- beziehungsweise GPU-Abnahme. Vorhandene Quellmodule sind
kein Funktionsbeleg.

## Stottern, schwarzer Frame oder unvollständige Gen-2-Karte

1. AA auf OFF, Schatten auf OFF/LOW und Geräteprofil auf HANDHELD oder ECO.
2. OPEN WORLD deaktivieren.
3. Einen kalten Kartenwechsel mit sichtbarer nativer 2D-Fläche bis zur
   atomaren Voxelübernahme beobachten.
4. `VOXEL DISK CACHE` nicht als Reparatur verwenden; persistente Cache-I/O ist
   weiterhin deaktiviert.
5. Gold, Silber und Kristall getrennt melden.

`GEN2-001` und die vollständige
[Gen-2-ROM-Matrix](../GEN2_ROM_QA.md) bleiben offen. Eine mehrsekündige
Blockade beim aktuellen Map-Body ist releaseblockierend.

## CUSTOM-Inhalte werden nicht geladen

1. Im VASC-Menü den effektiven Content-Status und Fehlergrund notieren.
2. `RESTORE VASC DEFAULT` verwenden; `active.json` nicht manuell korrigieren.
3. Prüfen, ob Pointer, Manifest und jede Assetdatei aus derselben atomaren
   Generation stammen.
4. Nach einer Änderung den Prozess neu starten, falls `restart-required`
   gemeldet wird.

Eine ungültige CUSTOM-Generation wird vollständig verworfen. Je nach
`base_profile` folgt RETRO und danach VASC DEFAULT oder direkt VASC DEFAULT.
Die genauen Grenzen stehen in [Content-Presets](../CONTENT_PRESETS.md).

## KASC/VASC wird als Konflikt angezeigt

Nur die im
[`COMPANION_SOURCE_CONTRACT.json`](../../COMPANION_SOURCE_CONTRACT.json)
beziehungsweise in der
[RC10-Baseline](../maintainer/RC10_BASELINE.md) exakt gepinnte Kombination
aktivieren; `manifest.json` markiert KASC lediglich als optionale Abhängigkeit
und ist dafür keine Versionspaarung. `VASC4J` und die ersetzten eigenständigen
Karten-, Cinematic-, Storage- und Dex-Pakete dürfen nicht parallel besitzen.
KASC bleibt optional; VASC darf nicht durch Kopieren privater KASC-Dateien
„verbunden“ werden. `COMP-101` bleibt bis zur Loader-/Manifestprüfung offen.

## Save oder Einstellung scheint vergessen

- Nicht den gesamten `modOptions`- oder `modData`-Block löschen.
- Prüfen, ob derselbe Mod-ID-Bucket und dieselbe Edition geladen wurden.
- Gen 2 darf fehlende Werte aus `VASC4J` übernehmen, löscht diesen alten
  Bucket aber nicht.
- Menü-Navigation, Inhaltsquelle und sichtbare Einstellung sind verschiedene
  Schlüssel.
- Bei einem Bericht vorher/nachher nur die betroffenen Schlüssel aus dem
  [Save-Schema](../maintainer/SAVE_SCHEMA.md) nennen; keine kompletten
  persönlichen Spielstände veröffentlichen.

## Reproduzierbarer Bericht

Mindestens diese Angaben beilegen:

```text
Build/Commit:
Manifest-Version:
Engine-Version:
Generation/Edition:
VASC/KASC/weitere aktive Mods:
Startzustand und exakte Einstellungen:
Schrittfolge:
Erwartet:
Beobachtet:
Erster Logfehler:
Funktioniert GAME DEFAULT?:
Folgekampf/zweiter Kartenwechsel:
Screenshot- oder Receipt-Datei:
```

Ein visueller Beleg wird mit Build-Hash, Generation, Edition, Provider,
Screen und Testfall benannt. Welche Belege vorhanden beziehungsweise noch
fehlend sind, steht im
[Screenshot-Inventar](../maintainer/SCREENSHOT_EVIDENCE_INVENTORY.md). Die
vollständige Abnahmereihenfolge steht in der
[RC11-Testmatrix](../maintainer/RC11_TEST_MATRIX.md).
