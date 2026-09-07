# Vollständiger deutscher Leitfaden

Stand: 29. August 2026

> Dieser Leitfaden beschreibt den RC11-Arbeitsstand, nicht einen RC11-Kandidaten
> oder Release. Funktionsangaben bedeuten „im aktuellen Quellpfad vorhanden“;
> sie ersetzen keine offene Fach-, ROM- oder Sichtabnahme.

## 1. Besitzmodell

VASC besitzt Darstellung: Voxelwelt, Kamera, HUD-/Menüzeichnung, Sprites,
Schatten und optionale lokale Inhalte. Die Engine besitzt Eingabe,
Kampfregeln, Screen-Stack und Spielstand. Kanto Ascendant besitzt seine Story,
Gameplayregeln, Transfers, Dex- und Save-Semantik. Ein VASC-Fehler muss deshalb
eine komplette native Oberfläche freigeben und darf nicht heimlich
Spielzustände nachbauen.

Die technischen Besitzer und Rückfallregeln sind im
[Hook- und Besitzregister](../maintainer/RC11_HOOK_OWNERSHIP.md) festgehalten.

## 2. Menü und Bedienung

In Rot, Blau und Gelb öffnet der reguläre START-Baum den Eintrag
**VOXEL ASCENDANT**. In Gold, Silber und Kristall wird genau ein öffentlicher
`VASC`-Eintrag nach `OPTION` beigesteuert. Optionales KASC darf diesen
Deskriptor gruppieren, übernimmt aber weder VASC-Renderer noch VASC-Saves.

Der Hub ordnet Einstellungen in diese Bereiche:

1. Ansicht und Welt
2. Wetter und Szenerie
3. Kampf
4. Skins und Overlays
5. Pokémon und Modelle
6. Wilds und Begleiter
7. Leistung
8. Benutzerinhalte
9. Erweitert

START beziehungsweise SELECT öffnet die kontextbezogene Hilfe. Kategorie,
Seite und Auswahl werden im VASC-eigenen Optionsbucket gespeichert. Die
vollständige vorhandene Wertetabelle steht bereits in der
[englischen Projektübersicht](../../README.md) und wird hier nicht dupliziert.

## 3. Welt und Kamera

### Generation 1

Die VOXEL-Leiter bietet OFF, FULL, 15, 35, 50, 75, erste und dritte Person.
FULL ist ein Startprofil, kein dauerhafter Lock. V-GRID, Höhen, Weltkurve,
Wasser, Himmel, Wolken, Wetter, Szenerie, Schatten, Preload und AA bleiben
getrennte Einstellungen. Die Engine bleibt alleinige Autorität für Kollision,
Warps, Begegnungen und Ledges.

### Generation 2

Gold, Silber und Kristall verwenden eine getrennte Laufzeit unter `gen2/`.
Sie bieten eine eigene Voxelwelt, dieselbe siebenteilige Kameraleiter,
verbundene Karten, Open-World-Streaming, Wetter, sichtbare Wild-Pokémon und
Begleiter. `VOXEL DISK CACHE` ist nur aus Kompatibilitätsgründen sichtbar;
persistente Cache-Ein-/Ausgabe bleibt wegen eines reproduzierten
Geometriefehlers deaktiviert.

Die genaue editionsbezogene Abdeckung steht in
[Gen-2-Feature-Parität](../GEN2_FEATURE_PARITY.md). „Implemented“ dort bedeutet
installierter Pfad plus Contract-Test, nicht abgeschlossene ROM-Sichtprüfung.

### Leistungsprofile

- **AUTO** wählt in Gen 2 bewusst HANDHELD für ausgewogene und starke Hosts.
- **PC/MAX** erhöht Qualität und Kosten ausdrücklich.
- **HANDHELD** behält die Voxelwelt mit reduzierter interner Auflösung,
  niedrigen Schatten und ohne AA.
- **ECO** ist der konservativste VASC-Pfad.
- **CUSTOM** entsteht, sobald verwaltete Einzelwerte abweichen.

Bei Stottern zuerst AA ausschalten, Schatten reduzieren und Preload/Open World
getrennt prüfen. Messungen in Eichs Labor bleiben als `FLD-105` offen; ohne
Messbeleg ist keine pauschale Leistungsänderung gerechtfertigt.

## 4. Kampf

### Architekturen

| Auswahl | Bedeutung | Aktueller RC11-Status |
| --- | --- | --- |
| DEFAULT / GAME DEFAULT | vollständige native Editionsdarstellung | Gen 1 und Gen 2 besitzen einen exakten, pixelneutralen DEFAULT-Provider. |
| MAP | Begegnungswelt als Bühne | Gen 1 transitional Legacy; Gen 2 transitional hinter dem Gen-2-Adapter. |
| ARENA | authored beziehungsweise aufgelöste Arenabühne | Gen 1 transitional Legacy; Gen 2 transitional hinter dem Gen-2-Adapter. |
| DISCS | neutrale Stadium-Plattformen | Gen 1 als eigene Provider-Card segmentiert; Gen 2 noch transitional. |

Die Auswahl wird für einen Kampf eingefroren. HUD, Kamera und Spritequelle sind
getrennte Präsentationsverträge. In Gen 2 bleibt
`BattleState:animForMove` der einzige Besitzer der Attackenanimation; der
Lifecycle beobachtet `battle.move_used` nur.

Lokale Presets dürfen den Hintergrund ausschließlich für **ARENA** ergänzen
oder ersetzen. Eine Regel ist immer an Generation, Edition und Route/Karte
gebunden und kann zusätzlich Kampfart, Trainer oder Einzelkampf eingrenzen.
Ein Shuffle wählt nur innerhalb dieses ausdrücklich benannten Pools, einmal
pro Kampf und stabil über alle Einwechslungen. Ohne Treffer bleibt das bisherige
ARENA-Bild erhalten; MAP, DISCS und DEFAULT/2D werden nie verändert.

Das 31/31-Architecture-Gate belegt exakten Besitzerwechsel, stale Events,
Cleanup und nativen Fallback in den ausgeführten Headless-Pfaden. Es belegt
nicht, dass die offenen Probleme `BTL-001` bis `BTL-005` visuell behoben sind.
Insbesondere Positionen, transiente Rendererfehler, Schatten/Occlusion und die
ORAS-/Cartridge-Kombinationen benötigen Gate H.

### Sichere Auswahl

- Bei einem festhängenden oder falsch gezeichneten Kampf zunächst
  **GAME DEFAULT** wählen.
- Für einen vollständigen nativen Gen-1-Look auch den HUD auf **STANDARD**
  beziehungsweise **GAME DEFAULT** stellen.
- Für einen vollständigen nativen Gen-2-Look `BATTLE WORLD=GAME DEFAULT` und
  `BATTLE HUD=GAME DEFAULT` kombinieren.
- Einen neuen Modus erst nach dem vollständigen Ende des vorherigen Kampfes
  und bei reproduzierbaren Tests bewerten.

## 5. Menüs, Team, Bag, Box und Dex

`OVERWORLD MENUS=ORAS GLASS` verändert nur das Zeichnen unterstützter nativer
Oberflächen. `GAME DEFAULT` gibt die erfasste Originaldarstellung live zurück.
Die Team-, Battle-Team-, Bag-, Box- und HUD-Auswahl sind bewusst unabhängig.

In Gen 1 kann ein vollständiger Provider nur auf den Oberflächen erscheinen,
die sein Receipt gemeinsam mit dem Host unterstützt. Native Aktionen,
Feldattacken, Speichern und KASC-Transferlogik bleiben unverändert. Der
autoritative Host-/Providervertrag ist
[Pokémon UI Provider/Host v1](../POKEMON_UI_PROVIDER_CONTRACT.md).

In Gen 2 sind START TEAM UI, BATTLE TEAM UI und BATTLE HUD auf draw-only
`ORAS GLASS` oder `GAME DEFAULT` begrenzt. Intro, Animation, Fang,
Lern-/Entwicklungsphasen, Submenüs und Spezialkämpfe müssen vollständig nativ
bleiben.

Mehrere UI-Punkte (`UI-101` bis `UI-110`) sind weiterhin offen. Eine
vorhandene Option oder ein Headless-Layouttest ist keine visuelle Freigabe.

## 6. Benutzerinhalte und Presets

`CONTENT PROFILE` speichert genau eine gewünschte Quelle für Sprites und
Musik:

- **VASC DEFAULT:** verpackte VASC-Standards; sicherer Rückfall.
- **KASC:** nur über einen expliziten öffentlichen Provider.
- **RETRO:** nur über einen vollständigen öffentlichen Provider.
- **CUSTOM:** atomar validierte Selector-Generation oder die eng begrenzte
  historische Loose-Folder-Migration.

Die v2-Pointerauflösung ist deterministisch: Spiel, Generation, Default. Ein
ungültiges CUSTOM-Preset wird nicht halb verwendet. Sein deklariertes
`base_profile` bestimmt RETRO- oder VASC-DEFAULT-Fallback. `RESTORE VASC
DEFAULT` löscht nicht die benannten Presets.

Schema, Plattformgrenzen und Dateiprüfungen stehen vollständig in
[Content-Presets](../CONTENT_PRESETS.md). Der aktuelle externe Windows-/Linux-
Buildvertrag ist noch offen; daraus folgt kein auslieferbarer Selector.

## 7. Feldtechniken und Wetter

Fly, Surf und Fishing sind Präsentationspfade mit nativer Rückgabe. Die
integrierten Gen-1-Cinematics und ihre Provenienz sind in
[Species Cinematics](../SPECIES_CINEMATICS.md) dokumentiert. Fishing und Fly
sind als `FLD-001` beziehungsweise `FLD-101` erneut im echten Produktpfad zu
prüfen. Gen-2-Fishing besitzt noch keinen echten GPU-Beleg.

Wetter, Tageszeit und Himmelsereignisse besitzen save-lokale deterministische
Uhren. Das Kampf-Regenbogenbild muss nach dem Kampf zur Overworldposition
zurückkehren; `BTL-105` bleibt bis zur Sichtprüfung offen.

## 8. Save- und Rücksetzregeln

Einstellungen leben in VASC-eigenen Options- beziehungsweise Mod-Data-Buckets.
Die eingebauten RC11-Cards sind stateless und schreiben keine Saves. Alte
`VASC4J`-Werte sind Migrationsquelle und werden nicht gelöscht. Einzelheiten,
Schlüsselklassen und Rollbackregeln stehen im
[Save-Schema](../maintainer/SAVE_SCHEMA.md).

Nicht als erste Maßnahme:

- keinen kompletten Save löschen,
- keinen fremden Mod-Bucket leeren,
- kein `active.json` von Hand umschreiben,
- kein ZIP neu packen,
- keinen Hot-Reload als Freigabetest verwenden.

## 9. Bekannte Grenzen

Der verbindliche offene Stand steht im
[RC11-Fehlerarbeitsvorrat](../maintainer/RC11_ERROR_BACKLOG.md). Besonders
releaseblockierend sind derzeit die Kampfpfade `BTL-001` bis `BTL-005`, der
Gen-2-Kartenwechsel `GEN2-001`, die Gen-2-Kampfdarstellung `GEN2-002` und
Fishing `FLD-001`. Das vollständige Gate H/I, die echte ROM-/GPU-Matrix und
die zugehörigen Nachher-Screenshots fehlen.

Der [RC11-Release-Audit](../maintainer/RC11_RELEASE_AUDIT.md) fasst deshalb
ausdrücklich **kein Kandidat / kein Release** zusammen.
