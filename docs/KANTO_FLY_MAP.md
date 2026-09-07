# Integrierte VASC Kanto Fly Map Widescreen 1.0.0

Eine zweisprachige 576×324-Kanto-Karte für **Pokémon Rot, Blau und Gelb** mit
Voxel Ascendant. Sie dient gleichzeitig als echte räumliche Flugauswahl und
als öffentlicher Widescreen-Fundortprovider für kompatible Pokédex-Ansichten.

## Öffentliche Auswahl und Fallback

Die gespeicherte Option `KANTO MAP` besitzt exakt zwei sichtbare Werte:

- `CARTRIDGE MAP` lässt normale Town Map, Fly-Picker und Pokédex AREA vollständig
  bei der Engine;
- `VASC WIDESCREEN` verwendet die integrierte 576×324-Karte für normale Karte
  und Fly sowie ihren öffentlichen Dex-Area-Provider.

Die frühere 288×240-Custom-Karte ist weder im Ascendant-Menü noch in einem
normalen Town-Map-Pfad auswählbar. Sie wird intern erst konstruiert, wenn ein
Widescreen-Bild fehlt oder der breite Renderer zur Laufzeit ausfällt. Scheitert
auch dieser Rettungspfad, übernimmt die unveränderte Engine-Karte. Alte Werte
`game`/`default` migrieren zu `CARTRIDGE MAP`; `custom`/`classic`/`wide` zu
`VASC WIDESCREEN`.

## Funktionen

- Ersetzt im Modus `VASC WIDESCREEN` normale `TownMap` und Flugauswahl durch
  dieselbe 576×324-Karte. `CARTRIDGE MAP`, unbekannte Companion-Flugziele und
  der reguläre Pokédex-AREA-Aufruf bleiben bytegleich beim nativen Owner.
- Zeigt nur bereits besuchte Ziele, die die jeweilige Edition selbst in
  `flyOrder` und `flyWarps` als gültige Flugziele registriert hat.
- Das Steuerkreuz wählt räumlich den nächsten Ort. In der Übersicht zoomt das
  erste **A** auf die Stadt; im Zoom fliegt das nächste **A** über den
  originalen Engine-`onFly`-Callback. Das erste **B** kehrt zur Übersicht
  zurück, das zweite **B** schließt die Karte.
- Der Cursor bleibt beim Navigieren in der Gesamtübersicht herausgezoomt.
  Erst **A** wechselt wieder in den zentrierten Ziel-/Flugmodus; im Zoom folgt
  die Kamera weiteren Steuerkreuz-Bewegungen weich.
- Nur die echte Flugauswahl startet kurz mit der vollständigen Kanto-Übersicht
  und fährt anschließend automatisch weich auf das gewählte Ziel. Dieser
  automatische Zoom gilt bereits als erste Stufe, sodass anschließend ein
  einziges **A** fliegt. Die normale Karte bleibt stabil in der Übersicht.
- **SELECT** öffnet zu jeder markierten Stadt eine lokalisierte Info mit
  aktuellem Standort-/Entdeckungsstatus, Kurzbeschreibung und freigeschalteter
  Ortsinfo. Unbesuchte Orte verraten keine Details; Arena-Hinweise beachten den
  Spielstand. Deutsch und Englisch sind in ruhige Zwei-Zeilen-Seiten aufgeteilt.
- Die Info-Box behält die volle 576×324-Widescreen-Fläche bei und liegt in der
  östlichen Bedienleiste. **SELECT** verändert weder Zoom noch Kartenausschnitt,
  auch nicht beim Ablauf des Flug-Zoomtimers.
- ORAS-inspirierte Ein-Bildschirm-Oberfläche mit großer Ortsleiste, grünen
  Flugzielen, rotem Zielpfeil und einer separaten unteren Aktionsleiste.
- Echte 576×324-Widescreen-UI-Fläche mit separater 1152×648-Zoomtextur; die
  östliche Meeresleiste trägt Ortsname, A/B/SELECT-Hilfe und Stadtinfos, ohne
  Kanto zu verdecken oder das Artwork zu strecken.
- Rahmenlose Crystal-Glass-Kartenleiste mit nur 25 % dunkler Deckkraft;
  `SELECT` und `KARTE/MAP` stehen ohne mittleren Button frei über der Karte.
- Aktueller Spielerort mit eigenem cyan-weißem Personenmarker und dem
  lokalisierten Hinweis `DU` beziehungsweise `YOU`; der rote Pfeil bezeichnet
  weiterhin ausschließlich das gewählte Flugziel.
- Klare 5×7-Bitmap-Schrift mit echten Diagonalen für N, M, W, R und weitere
  zuvor schwer unterscheidbare Buchstaben.
- Rot, Blau und Gelb verwenden denselben editionsneutralen Code. Editionsdaten,
  Besuchsstatus und Landepunkte kommen immer aus dem aktuell laufenden Spiel.
- Englische und deutsche Ortsnamen sowie alle Bedien- und Stadtinfotexte
  sind enthalten. `translation-german-universal` steuert die Sprache über sein
  öffentliches `bootLanguage`-Signal; alternativ werden Kanto Ascendant und die
  editionsspezifischen Übersetzungsmodule erkannt.
- **KANTO MAP** beziehungsweise **KANTO-KARTE** öffnet im Start-/Ascendant-Menü
  immer den gerade gespeicherten CARTRIDGE-/WIDESCREEN-Owner.
- Nicht dargestellte zusätzliche Companion-Flugziele lösen automatisch den
  vollständigen eingebauten Fly-Picker aus und werden niemals versteckt.

## Installation

Die geprüfte Widescreen-Fassung 1.0.0 ist direkt im Gen-1-Laufzeitbaum
enthalten. Eine zweite Installation von `vasc-kanto-fly-map` oder
`vasc-kanto-fly-map-widescreen` ist weder nötig noch zulässig; der Launcher
ersetzt beide zugunsten des einen integrierten Owners. Ein Pokémon mit
**Fliegen** öffnet den gewählten Town-Map-Owner direkt als Flugzielauswahl;
der originale `onFly`-Callback bleibt unverändert mit der Glurak-/Species-Fly-
Cinematic gekoppelt.

Die Mod schreibt keine eigenen Spielstandsdaten und verändert weder Karten,
Kollisionen, Warps, Storyflags noch Fluglandepunkte. Deaktivieren entfernt die
Darstellung vollständig, ohne den Spielstand umzubauen.

Die deklarierte Berechtigung `engine_internals` wird ausschließlich benötigt,
um gültige Flugziele aus den laufenden Editionsdaten zu lesen und normale
Town-Map-/Pokédex-Aufrufe sauber an die unveränderte eingebaute Ansicht
zurückzugeben.

## Geografie und Assets

Die bereinigte Vintage-Karte enthält unter anderem:

- Alabastia → Vertania → Route 2 → Vertania-Wald → Marmoria,
- Marmoria → Mondberg → Azuria,
- Route 22/23 → Siegesstraße → Indigo Plateau,
- den hölzernen Küsten-/Stegweg Lavandia → Routen 12–15 → Fuchsania,
- getrennte Verbindungen für Prismania, Saffronia, Orania, Zinnoberinsel und
  Seeschauminseln.

Die Übersicht verwendet die geprüfte 576×324-Textur und der Zoom eine eigene
1152×648-Detailtextur des bereitgestellten Vintage-Artworks. Nur diese beiden
Runtime-Dateien stehen in der Release-Allowlist; das 3067215-Byte-Masterbild
aus dem Source-Paket wird nicht noch einmal ausgeliefert. Der exakte Intake,
alle Hashes und die interne Fallback-Policy stehen in
`integrated/kanto_fly_map/SOURCE_RECEIPT.json`. Rechte am bereitgestellten
Ausgangsartwork verbleiben bei den jeweiligen Rechteinhabern.
