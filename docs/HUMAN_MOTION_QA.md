# Menschliche Kartenanimation: geprüfter Zwischenstand

Basis: VASC 3.0.20, Commit `19039d6c`. Keine Orange-Abhängigkeit.

## Aktuelle Gesamtprüfung und Mutter-Übergang (2026-09-11)

Der aktuelle vollständige Runner besteht: 198 menschliche Atlanten, 2.376
Einzelbilder und 9.504 Karten-/Relief-/Raster-/Würfelvarianten. Alle sechs
Helden sowie die echten Startrollen in Alabastia und Neuborkia behalten ihre
exakten Quellbindungen. NATUERLICH ist zentral schaltbar; KLASSISCH bleibt
Standard, HD-MENSCHEN AUS stellt Vanilla her, und fehlende Schauspielbilder,
Aktionen oder nicht zugelassene Szenen bleiben im bisherigen Pfad.

Rots sitzende Mutter verwendet beim Kopfdrehen nun genau eine geprüfte
Kopfansicht je Bild. Eine kleine halsverankerte Kompression/Absenkung trägt die
Bewegung über den Ansichtswechsel; die frühere optische Mischung mit doppelten
Haar-/Augen-/Ohrkonturen ist entfernt. Acht unbenutzte Flow-Puffer entfallen.
Neun Renderstufen wurden geprüft, der echte Dialog besteht in beide Richtungen,
und ein eigener Regressionstest erzwingt einzelne Quellen, exakte Endpunkte und
Ressourcenfreiheit. Classic/Vanilla und die native Stuhlposition bleiben exakt.

Der abschließende Mehrfigurenlauf mit Spieler plus sechs Helden bleibt in Gen1
und Gen2 im Natural Walk bei höchstens 17,605/17,595 ms pro beobachtetem Frame;
Blinkvorbereitung liegt im Mittel bei 0,008/0,012 ms. Daisy, beide Neuborkia-
Sitzfiguren und die Mutter-Kopfdrehung wurden zusätzlich im echten Karten-/
Dialogpfad geprüft. Details und Rohdaten: `final-performance/` im Prüfpaket.

## Daisy sitzt; spätere Daisy bleibt gehfähig (2026-09-11)

Die echte `BLUES_HOUSE_obj_1` an Zelle `(2,3)` sitzt im Natural-
Schauspielmodus auf ihrem linken Hocker und beugt die Knie zum Tisch. Im
eigenen `world.talk`-Dialog dreht sie den Kopf weich zu Rot. Objektposition,
Kollision und das ursprüngliche Daisy-Atlasbild bleiben unverändert. Classic
stellt die bisherige stehende Karte auf dem Hocker wieder her; HD-MENSCHEN AUS
stellt Vanilla her.

Nach dem Kartenereignis ersetzt die Engine sie durch `BLUES_HOUSE_obj_2` an
`(6,4)`. Exakte Objekt-, Index-, Karten-, Quell-, Rollen- und Positionswächter
halten dieses spätere Objekt vollständig aus der Sitzlogik; es behält die
normale Lauf-/Idle-Bewegung. Echter Hauslauf und voller 198-Quellen-Runner
bestehen. Details: `daisy-states/` im Prüfpaket.

Drei mit dem eingebauten ImageGen erzeugte Silber-Schauspielentwürfe wurden
verworfen, weil alle trotz Vorgabe nur RGB mit eingebranntem Schachbrett waren.
Keiner wurde integriert. Silber behält seine bereits geprüfte natürliche
Lauf-, Arm-, Atem-, Idle- und Blinzelbewegung. Prompts und Ablehnungsbeleg:
`daisy-states/SILVER_ACTING_REJECTED.md`.

## Professor Lind: schräge Dialogpose mit Atmung und Blinzeln (2026-09-11)

Professor Lind richtet in seinem exakt zugeordneten Gen2-Labordialog eine von
vier geprüften schrägen Körperansichten auf den tatsächlichen Gesprächspartner
aus. Die Spielrichtung, Kollision, Skriptposition und Bewegung bleiben
unverändert. Beide vorderen Ansichten blinzeln mit zwei Augen, die hinteren
Ansichten mit dem jeweils sichtbaren Auge; die gemeinsame Idle-Uhr hält zudem
die dezente fußverankerte Atmung in der Spezialpose aktiv.

Der volle 198-Quellen-Runner besteht. Ein echter Crystal-Lauf in ELMS_LAB
bestätigt Dialogbesitz, diagonale Quellwahl, Blinzeln, Atmung, Rückkehr zur
kardinalen Karte sowie Classic und HD-MENSCHEN AUS. Der diagonale Zielwinkel
wird darin innerhalb des echten Dialogs über einen temporären 12-Pixel-
Darstellungsversatz erzeugt. Ein GPU-Test bestätigt unverändertes Alpha und
unveränderte Pixel außerhalb der geprüften Augenbereiche. 120 Renderproben
lagen auf diesem Rechner bei 0,080 ms im Mittel, 0,083 ms p95 und 6,276 ms
Maximum. Asset, vollständiger ImageGen-Prompt und Belege: `elm-diagonal/` im
Prüfpaket.

## Blau beobachtet mit verschränkten Armen (2026-09-11)

Während Eich dem Spieler im echten Gen1-Labor die Pokémonwahl erklärt, nimmt
NPC-Blau als exakt erkannter Beobachter eine eigene vierseitige Pose mit
verschränkten Armen ein. Die vorderen Ansichten lächeln dezent. Seine eigenen
Gesprächsphasen verwenden weiter die registrierten Blick-/Drehbewegungen.
Spieler-, Arenaleiter- und Aktions-Blau bleiben ausgeschlossen. Ein fehlendes
optionales Posebild fällt nur für diesen Akteur auf seine geprüfte
Diagonalansicht zurück.

Der native Gras-/Eskort-/Laborlauf besteht einschließlich zwölf
Dialogpausen, Quellenprüfung, Eich-/Blau-Drehungen sowie Classic/Vanilla. Der
volle Runner und ein exakter RGBA-/Maß-/Alpha-/Hash-/Dialogmetadaten-Test
bestehen. Das finale Asset wurde mit dem eingebauten ImageGen-Werkzeug erzeugt;
ein RGB-Kandidat mit eingebranntem Schachbrett wurde verworfen und nicht
installiert. Details, Prompts und Szene: `blue-folded/` im Prüfpaket.

## Kontinuierliche Gewichtsverlagerung beim Laufen (2026-09-11)

Unter der vorhandenen neutral/A/B-Kadenz bewegt sich der Oberkörper jetzt
kontinuierlich mit der geglätteten Schrittphase. Eine kleine symmetrische
Hebung und wechselnde Balance laufen zur Sohle auf exakt null aus. Dadurch
bleiben Fußanker und Schuhrichtung erhalten; es werden weder Unterkörper
gespiegelt noch Spritebilder überblendet. Beim Anhalten kehrt die Geometrie
zusammen mit den Armen exakt zur Neutralstellung zurück.

Alle sechs Helden bestehen in beiden nativen Generationen beide seitlichen
Schrittphasen, Neutralrückkehr, Quellenstabilität sowie Classic- und
Vanilla-Abbruch. Voller 198-Quellen-Runner und GPU-Körpervergleich für 84
Augenquellen/996 Fälle/36.976.500 Pixel bestehen. Im Sieben-Karten-Lauf lag
die Rig-Arbeit bei 0,341 ms in Gen1 und 0,260 ms in Gen2 im Mittel; der große
Gen1-Ausreißer lag in `present`, nicht im Figuren-Rig. Die teils sehr ähnlichen
gezeichneten A/B-Seitenbilder bleiben als mögliche spätere Grafikverbesserung
separat dokumentiert. Details: `step-transfer/` im Prüfpaket.

## Blinzel-Warmup über mehrere Bilder verteilt (2026-09-11)

Mehrere erstmals sichtbare Augenprofile erzeugen ihre Shader-, Bild-, Canvas-
und Offscreen-Warmup-Arbeit nicht mehr gemeinsam in einem Idle-Bild. Bei
offenen Augen wird höchstens ein kaltes Profil pro vorbereitetem
Präsentationsbild zugelassen. Ein wirklich begonnenes Blinzeln wird immer
sofort gezeichnet. Ein Zwölf-Profil-GPU-Test besteht in beiden
Testreihenfolgen mit exakt zwölf Warmups und höchstens einem neuen Profil je
Bild; beobachtete Maximalzeiten sanken von 32,481 auf 18,025 ms beziehungsweise
von 16,711 auf 9,659 ms. Diese Zeiten sind hostabhängig; die strukturelle
Arbeitsbegrenzung ist die belastbare Aussage.

Native Sieben-Karten-Läufe mit sechs Helden plus Spieler bestehen in Gen1 und
Gen2. Natural Idle lag bei 16,667/17,200/28,608 ms (Mittel/p95/Maximum) in
Gen1 und 16,667/17,245/17,758 ms in Gen2. Die Blinzelvorbereitung benötigte
0,022/0,124 ms beziehungsweise 0,025/0,114 ms (Mittel/Maximum). Der
GPU-Körpervergleich für 84 Quellen, 996 Fälle und 36.976.500 Pixel sowie der
vollständige 198-Quellen-Runner bestehen. Classic/Vanilla und fehlende Quellen
behalten ihren bisherigen Pfad. Kein PNG geändert; keine Orange-Umgebung.
Details: `blink-warmup-budget/` im Prüfpaket.

## Alle menschlichen Armquellen registriert (2026-09-11)

Die Pokéfan-Frau und beide alpha-identischen Gen2-Farbvarianten verwenden nun
ein quellgenaues Korbprofil. Korbhand und Standbein bleiben als ruhige Einheit
zusammen; freier Arm und gegenüberliegendes Bein bewegen sich. Dadurch
entstehen keine Korb-, Hand- oder Fußfragmente. Die vergrößerte
Zwölf-Karten-Ansicht, Pixelwächter, native Gen1-/Gen2-Läufe, Variantenregeln,
Classic/HD-aus/Natural-Rückkehr und der vollständige Runner bestehen.
Armabdeckung: 198/198 katalogisierte menschliche Quellen. Augenabdeckung: 84.
Die allgemeine Seitenkadenz, weitere Ausdrucksposen und Performance-Abnahme
bleiben getrennte offene Arbeitsbereiche.

## Historisch: Rot am Silberberg und Kappen-Youngster (2026-09-11)

Rot am Silberberg besitzt jetzt ein exakt gebundenes Profil. Eine eng
begrenzte Laufzeitmaske entfernt nur das abgetrennte Sohlenfragment der
linken Quellzeile; die Original-PNG bleibt bytegleich. Der Kappen-Youngster
und seine beiden alpha-identischen Farbvarianten verwenden in Gen2 ein
eigenes Profil. Die bestehende Gen1-Sperre aller drei Kappen-Dateien bleibt
erhalten. Vergrößerte Ansichten, Pixelwächter, native Gen1-/Gen2-Rückfälle und
der vollständige Runner bestehen. Armabdeckung: 195/198; offen sind nur die
drei Korb-Pokéfan-Quellen. Augenabdeckung bleibt 84 Quellen.

## Historisch: Agathas Stock bleibt vollständig (2026-09-11)

Eine quellgebundene statische Schutzregion hält Agathas neutralen Stock aus
den verkürzten Laufspalten heraus. Die Beine wechseln weiter, beide Hände
bleiben passend am Stock. Vergrößerte Zwölf-Karten-Prüfung, Pixelwächter,
native Gen1-/Gen2-Läufe, Classic/HD-aus/Natural-Rückkehr und voller Runner
bestehen. Armabdeckung: 191/198; sechs offen, eine runtime-seitig abgelehnt.
Kein PNG wurde verändert. Details: agatha-static-cane/ im Prüfpaket.

## Armabdeckung 96 Prozent und wichtige Blinkrollen (2026-09-11)

Der damalige Stand betrug 190 von 198 quellgenau freigegebene Armprofile.
31 neue Quellen umfassen Alltagsfiguren und wichtige Rollen wie Misty Gen2,
Erika, Janine, Sabrina, Lance und Lt. Surge Gen2. Stock, Fächer, Umhang und
andere belegte Körperseiten werden je Quelle geschützt. 84 Quellen besitzen
geprüfte Augenprofile. Sabrina blinzelt frontal; ihre von Haar überdeckten
Seitenaugen bleiben unverändert.

Der vollständige Runner, native Gen1-/Gen2-Läufe samt Classic/HD-aus/Natural-
Rückkehr und der GPU-Körpervergleich mit 996 Fällen und 36.976.500 Pixeln
bestehen. Die 31 neuen Quell-PNGs sind bytegleich zur Basis. Sieben unsichere
Armquellen und eine bereits runtime-seitig abgelehnte Quelle bleiben im
bisherigen Darstellungsweg. Details: NPC_MOTION_QA.md und
near-complete-residents/ im Prüfpaket.

## Weitere Bewohnerprofile (2026-09-11)

Juggler, Burglar, Cue Ball, Jr. Trainer Male, Cook, Silph Worker Female,
Middle-aged Woman und Safari Zone Worker haben quellgenaue Armprofile. Die
beiden Farbvarianten der Middle-aged Woman sind in Gen2 enthalten; Gen1 lehnt
sie weiterhin regulär ab. Tasche, Sack und belegte Armseiten bleiben in den
betroffenen Ansichten ruhig und zusammenhängend. Sieben Rollen einschließlich
der Middle-aged-Woman-Varianten blinzeln. Der maskierte Burglar ist per
Negativtest vom prozeduralen Lid ausgeschlossen.

Der aktuelle Stand beträgt 159 von 198 Armquellen und 74 Augenquellen. Native
Gen1-/Gen2-Prüfungen, Classic/HD-aus/Natural-Rückkehr, visueller Vergleich,
GPU-Körpervergleich über 884 Fälle und 32.818.500 Pixel sowie der vollständige
Runner bestehen. Alle zehn Quell-PNGs des Blocks sind bytegleich zur Basis.
Die native Szenenprüfung setzt die Rollen synthetisch ein und ersetzt keine
vollständige Storyabnahme.

## Gen1-Anlaufkorrektur (2026-09-11)

Die Gen1-Spielerprojektion berücksichtigt jetzt den ersten sichtbaren Simulationsschritt 1. Anlauf und Landung wurden separat geprüft; im neuen nativen Lauf sank der größte erfasste Anlaufsprung von 1,46 auf 0,53 Pixel. Gen2/NPCs behalten ihre Formel. Details und Grenzen: HUMAN_MOTION_ONSET.md. Dies ist keine Freigabe der weiterhin unfertigen Sitz-/Kopfanimationen oder des gesamten Charakterumfangs.

## Giovanni-Blinzeln (2026-09-11)

Giovanni hat jetzt eine quellenspezifische schräge Lidkante. Die oberen Augenkonturen bleiben erhalten; die bisherigen 20 Blinkquellen liefern unveränderte Pixel. Gesamtstand: 29 Blinkquellen, 99/198 Armquellen. Details: HUMAN_BLINK_OCCLUSION.md und giovanni-blink/README.md im Paket.

## Archer/Ariana-Blinzeln (2026-09-11)

Beide Quellen haben eigene Augenbereiche. Die rote Iris von Ariana wird jetzt geschlossen, ohne ihre Haare zu übermalen; die bisherigen 21 Quellen bleiben pixelgleich. Details und Testgrenzen: executive-blink/README.md im Paket.

## Anwendbar

Unter KARTENANIMATION schaltet NATUERLICH die distanzgebundene Schrittfolge,
einen festen Maßstab/Bezugspunkt der Schrittbilder und dezente Atmung ein.
Die Darstellung gilt für die gebundenen menschlichen HD-Karten in beiden
Generationen. Standard bleibt KLASSISCH. KLASSISCH stellt die bisherige
Darstellung wieder her; HD-MENSCHEN = AUS verwendet die ursprünglichen Sprites.
Aktionsgrafiken und fehlende HD-Grafiken behalten ihren bestehenden Pfad.
Dialoge, Menüs, laufende Skripte und Eingabesperren unterbrechen die neue
Lauf-/Idle-Darstellung. Der separate, standardmäßig ausgeschaltete Schalter
DIALOGPOSEN (TEST) erlaubt inzwischen ausdrücklich zugeordnete Eich-Dialoge
im Alabastia-Startablauf sowie die sitzende Mutter mit dialoggebundener
Kopfdrehung; siehe HUMAN_ACTING_PILOT.md. Nach einem Szenen-/Kartenwechsel beginnt sie mit frischem Zustand.

Es werden weder Spielbewegung, Kollision, Save-Identität noch die gelieferten
PNG-Dateien verändert. Die vorhandenen Pokémon-Animationen bleiben unverändert.
Maßstab und Bodenanker gelten für flache Karten, Relief, Raster und Würfel.
Einzelne speziell authored Layouts behalten ausdrücklich ihre eigenen Anker.

## Geprüft

- Native Engine 0.2.57, ausschließlich VASC: Red, Green, Blue in Gen 1 sowie
  Gold, Kris und Silver in Gen 2; vier Richtungen, Raster an/aus,
  Schrittphasen 0/A/B und Natural → Classic → Vanilla → HD/Natural.
- Tatsächliche Render-Schnittstelle: gemeinsam verwendete NPC-Textur,
  Aktions-/Identitätswechsel, fehlendes Asset, schnelles Vanilla-Umschalten,
  optionale fehlende Schattenmatrix und vollständige Wiederherstellung.
- Native Dialogfenster in Red und Crystal: neue Animation stoppt und kehrt
  nach Schließen zurück; ebenso Skript-Runner, Eingabesperre, Karten-Reload-
  Ereignis und direktes Classic/Natural-Umschalten. Gen 2 berücksichtigt
  seine außerhalb des leeren Zustandsstapels gezeichnete Spielwelt.
- Distanzfolge bei 30/60/120 Samples pro Sekunde; zusätzliche Render-Pässe,
  Stoppen, Teleport, Zeitrücksprung und Pause. Keine neue Gangphase durch
  einen zusätzlichen Schattenpass.
- Katalogprüfung: 198 reale menschliche Atlanten, 2.376 Frames und 9.504
  Karten-/Relief-/Raster-/Würfelmodelle bestanden. Reproduzierbar:
  `love tests/human_motion_runner` aus einer LOVE-Installation starten
  (der Runner ermittelt den Repository-Pfad selbst).
- Bestehende Gen-2-Identitäts- und HD-Menütests einschließlich 80
  Master/Modell/Raster/Relief-Kombinationen und 160 Umschaltungen bestanden.

Vor der Arm-/Lidintegration ergab ein isolierter Vergleich im identischen Innenraum im uncapped
Testtreiber 7 Drawcalls und 39,1 MiB Texturspeicher für beide Modi.
Die mittleren Frame-Abstände lagen bei 3,76–3,90 ms (klassisch) und
3,85–3,87 ms (natürlich), p95 der Draw-Dauer bei 5,73–6,10 bzw. 5,48–6,01 ms.
Das ist ein Vergleich des Renderaufwands, kein Nachweis einer stabilen
Bildschirm-Framerate oder einer insgesamt ruckelfreien Spielwelt.

## Integrierte Arme und Lider — weiterhin ein Zwischenstand

`human_rig.lua` bewegt die Arme der sechs ursprünglichen Heldenatlanten mit
unveränderten neutralen Oberkörperpixeln und vorhandenen Beinphasen. Die Arme
laufen beim Anhalten über 180 ms aus; die Füße stehen bereits neutral.
Relief und vorhandene Shader bleiben erhalten. Gemeinsam genutzte Atlanten
bekommen getrennte Mesh-Zustände pro Figur.

`human_idle.lua` berechnet einen 170-ms-Lidschluss mit individuellen Pausen
von 2,2 bis 5,4 Sekunden. Nach Bewegung beginnt die Wartezeit erst nach 700 ms.
`human_blink.lua` zeichnet die Lider der sechs Helden. Fünf kompakte Augenatlanten
übernehmen nur die registrierten Augenbereiche generierter Vorlagen; Kris
verwendet ihre vorhandenen Gesichtspixel und eine gezeichnete Lidkurve.
Die übrigen Original-PNGs werden nicht geändert. Die Vorlagen werden vor dem
ersten Blinzeln vorbereitet. Maximal 32 getrennte temporäre Zeichenflächen
bleiben erhalten; doppelte Zeichenpässe verwenden die berechnete Fassung.

Klassisch, Vanilla, Aktionen, Szenensperren, abweichende Kostüme und Raster
verwenden die neue Arm-/Liddarstellung nicht. Fehlende Augen-Assets lassen die
ursprüngliche Darstellung stehen. Installation und Rücknahme berücksichtigen
auch neu hinzugefügte Dateien und verweigern das Überschreiben späterer Änderungen.

Ein 60-Hz-Vergleich für einen Helden in Gen1/Gen2 liegt in
HUMAN_MOTION_PERFORMANCE.md vor. Die vollständige Performance-Freigabe für
mehrere laufende Figuren und weitere Geräte steht noch aus.
Die älteren Messwerte oben belegen ausschließlich den damaligen Grundstand.
Die Raster-Erweiterung, weitere NPC-Profile sowie Lächeln, verschränkte Arme und
andere passende Ausdrucksposen fehlen weiterhin. Das Gesamtziel ist offen.

## Reproduzierbare native Augenprüfungen

Die privaten Nicht-Orange-Treiber `integrated-blink.lua`,
`integrated-blink-cancel.lua` und `integrated-blink-resources.lua` verwenden
keinen Ersatz-Renderer. Ihre Wartefunktion zählt tatsächlich gezeichnete Frames;
mehrere Spiel-Updates können in einem einzelnen Render-Frame laufen.
Die Prüfungen decken Blickrichtungen, sichtbaren Abbruch bei Bewegung/Dialog/
Klassisch/Vanilla, getrennte Figuren, Cache-Grenze, zusätzliche Zeichenpässe und
fehlende Dateien ab. Die zugehörigen Logs werden im Prüfpaket mitgeliefert.


### Six hero combined native regression, 2026-09-11

integrated-six-hero-final.lua exercises all six exact hero sources in the
isolated Red indoor fixture (no Orange): Red, Green, Blue, Gold, Kris, Silver.
Each gets 6.2 seconds of unforced idle scheduling, actual left/right movement,
arm settling, Classic and Vanilla roundtrips. All six reach blink amount 1,
travel more than 16 pixels, exercise the rendered arm rig and settle to zero.
The six closed-eye native captures were inspected. Source identities remain
stable during idle and movement. Kris intentionally uses its reviewed
procedural eyelid profile; the other five use packed eyelid assets.
This is shared-renderer coverage in Gen1, not six separate Gen2 story tests,
a paced performance benchmark, or completion of all new dialogue poses.
Evidence: six-hero-final-native.log and shots/heroes-final-blink-*.png.

### Gen2 house apparent duplicate diagnostic — 2026-09-11

The actual PlayersHouse1F actors are bound to johto-mother at (112,64) and
pokefan-female-gen2 at (64,64). A private 30-frame observation traced their
low-level Voxel3D output: 30 mother draws used 165×225 generated cards; 30 visitor
draws used the 495×900 reviewed atlas. Neither emitted a native small texture
at that seam. The visitor source includes a basket/handbag in the apparent
small-figure region. No renderer change was made on this evidence.

This bounded observation does not rule out intermittent fallback flashes,
other paths/scenes, or the separately confirmed head-morph ghosting. Evidence:
private QA integrated-johto-house-ghost.lua, johto-house-ghost.log and
johto-house-ghost-review.json.

### Rig input geometry cache identity — 2026-09-11

A regression reproduced aliasing when one actor received two relief input
meshes with identical unit scale and first shade, but different depth and other
face shades. The old cache returned the first generated mesh for both. Keys
now include input mesh identity, and each resident entry retains that input
object so its identity cannot be recycled while cached. The existing 128-mesh
LRU and explicit teardown still apply.

The new test fails against the prior implementation, then verifies fresh-owner
attribute parity, distinct geometry, switch-back reuse and full release after
the fix. The 1,032-pose exact-triangle test, full runner and native Daisy/Blue
flat/relief/direction/cell tests pass. This is a reproduced cache defect, not
a claim that the user's intermittent ghosting or all scene artifacts are fixed.
Evidence: rig-geometry-identity-before.log, human-motion-geometry-identity.log,
geometry-identity-native.log and tests/human_rig_geometry_identity_test.lua.


### Bill/Kurt profile expansion and open context diagnostic — 2026-09-11

82/198 exact human arm sources now registered. Bill and Kurt four-view gait
galleries inspected; focused native Red/Crystal renderer geometry/pixel checks
and full human-motion regression passed. See NPC_MOTION_QA.md for scope and
evidence. No Bill/Kurt blink or story acting is claimed.

The older integrated-npc-rig driver failed its synthetic map.reloaded
state-identity assertion before reaching NPC checks. This remains unresolved;
the focused renderer passes do not supersede that context failure. The review
package remains incomplete and is not a universal animation acceptance.


## Map-reload diagnostic resolved: wait for actor rendering — 2026-09-11

The prior synthetic map.reloaded failure was a fixed-frame QA synchronization
error, not evidence that production reused a stale animation on its next draw.
A native probe verifies the live renderer epoch advances immediately (29 to
30), the same current imageDefs table is inspected, and the actor receives a
new motion table on its subsequent draw (frame 3 in this probe). Several
completed love.draw calls can occur before that actor is drawn again.

The canonical private integrated-npc-rig.lua now asserts immediate renderer
epoch invalidation, then waits for the actor's matching epoch with a five-second
wall-clock deadline, and only then asserts a new non-nil motion table. It does
not weaken the identity assertion or accept an absent actor draw. Full native
Red and Crystal runs pass this condition plus real dialogue, script runner,
input lock, options roundtrip, movement/blink cancellation, Classic/Vanilla and
Bill/Kurt geometry/pixel checks. Production code did not need a reload change.

Evidence: map-reload-probe-red.log, integrated-map-reload-probe.lua,
map-reload-draw-synchronized-{red,crystal}.log and integrated-npc-rig.lua in
private non-Orange QA. This resolves the specific synthetic reload diagnostic;
it does not resolve head-morph ghost contours or universal animation coverage.


### Bill/Kurt ordinary blink — 2026-09-11

The two source-specific eye profiles passed production GPU gallery checks,
visual review, scheduled idle/side/rear/movement/Classic/Vanilla checks in
private Red and Crystal render fixtures, and the full human-motion runner.
See HUMAN_BLINK_OCCLUSION.md for exact scope. Ordinary eyelid coverage is now
15 exact atlases; arm coverage is unchanged at 82/198. Universal acceptance
and known head-morph ghost contours remain incomplete.


## Partial-stop arm restart continuity — 2026-09-11

A short stop resets the foot-frame distance while arms are still settling.
Previously, restarting immediately sampled the reset sine phase and snapped
the arms away from their current pose. A new failing regression reproduced
this before the change. Natural now resumes from the actual settling excursion,
selects the phase branch with the previous swing direction, and eases the
shortest phase offset back to the feet over 32 travelled units. The phase
adjustment is bounded so it cannot reverse progression; a full rest, warp,
hidden-time gap or clock reset clears it. Foot columns/cadence are unchanged.

The regression covers 36 partial-stop combinations at 30/60/120 FPS, exact
first-resume continuity, both swing directions, bounded next increments,
rejoining the foot cadence, duplicate render passes and warp reset. The full
human-motion runner passes including Classic/Vanilla/missing-asset roundtrips.
Native Red and Crystal renderer fixtures each exercise four short-stop
restarts for each of the six hero atlases and assert actual pre/post draw arm
continuity. These fixtures inject moving render actors into ordinary interiors;
they do not prove arbitrary input/story paths or visual perfection. No new
textures, meshes or render passes are introduced.

Evidence in private non-Orange QA: arm-restart-before.log,
arm-restart-rejoin-regression.log, integrated-arm-restart.lua and
arm-restart-rejoin-native-{red,crystal}.log. tests/human_arm_restart_test.lua
is included in the standard runner. This fixes a concrete restart jump; head
ghosting, remaining NPC coverage and scene-wide long frames remain open.


## Actual player input follow-up — 2026-09-11

A new private input driver selects Red/Green/Blue in Red and Gold/Kris/Silver
in Crystal, presses/releases real left/right controls for four short walking
sequences per hero, and records each distinct rendered human-motion sample.
No actor positions or motion states are injected. At a requested 60 FPS,
median sample spacing is 16.57–16.82 ms. Travel is 63 measured units in Red
(the first unit predates the first sample) and 64 in Crystal; maximum position
increment is 1 and maximum arm increment .1950903 for every hero. All observed
positions are integer-valued. No nonzero arm-rejoin offset is entered during
these complete native steps; they are distinct from the partial-stop renderer
fixtures that reproduced the now-fixed restart discontinuity. This limits the
scope of the fix: it is not evidence that ordinary whole-step jitter is solved.

Native player code explicitly floors step displacement (src/world/Player.lua
and src/world/gen2/Player.lua in the private engine). Presentation interpolation
is therefore a relevant next investigation, provided it preserves native
coordinates, collision, grounded poses, actions and immediate fallback. The
current traces do not prove that integer stepping causes every reported stutter.

The driver captures moving/resting screenshots, so its maximum sample gaps
(48–66 ms) must not be interpreted as screenshot-free frame performance. The
Red moving capture was inspected; still images do not establish temporal
visual acceptance. Earlier uncapped Red data is retained separately.
Evidence: integrated-actual-input-restart.lua, actual-input-restart-gen{1,2}.csv,
actual-input-restart-{red,crystal}-60.log, actual-input-restart-review.json and
actual-input-moving-*.png in private non-Orange QA. No production change was
made by this follow-up; the prior arm fix and remaining scope are unchanged.


## QA-only fractional player projection — 2026-09-11

The private projection driver uses the remaining FixedStep fraction to present
(progress + alpha) / stepFrames along a one-cell already-authorized walking
segment. The captured pose is adjusted before the shared shadow/color passes;
native actor px/py are asserted unchanged. Only the player, straight one-cell
walks with at least 16 frames, zero lift and no action marker are admitted.
Projection is clamped to the step endpoint and stays within one native unit.
This prototype has not been added to the production payload.

Two fixture pitfalls were diagnosed before accepting results. The engine's
POKEPORT_DRIVER advances logic with a constant 1/60 dt per rendered frame;
MOTION_QA_PACED enables presentation pacing only. At 120 FPS that driver mode
is not normal realtime simulation. The final private driver feeds the actual
host dt to Game:update and restores its wrappers afterward. Also, a map event
reinstalls the production renderer when a foreign prepare hook is active,
invalidating captured record references. The final driver restores the owned
hook before map changes and installs its probe after binding. Early failed
travel assertions and constant-alpha traces are diagnostic, not acceptance.
Gen2 exposes the shared FixedStep module locally instead of game.fixedStep;
the final driver uses the verified src.core.FixedStep fallback. Its initial
missing-clock failure is retained, not a production bug.

At requested 120 FPS with actual input, the Red/Green/Blue and Gold/Kris/Silver
runs complete. For adjacent moving samples separated by 4–12 ms and less than
two units of travel, Gen1 has 281 pairs: native holds 142, projected holds 0;
step-increment standard deviation falls from .5000 to .0739. Gen2 has 355 pairs:
native holds 181, projected holds 0; standard deviation .4999 to .0593. Maximum
projection distance is .9792/.9764 units. These paired trajectory statistics
exclude stalls and are not a frame-time benchmark or proof of visual perfection.
The Red moving still was inspected. Camera motion, NPC schemas, high/low speed,
scene/action gates, full fallback and temporal visual acceptance remain open
before production integration.

Evidence in private non-Orange QA: integrated-position-projection.lua,
position-projection-{red-realtime,crystal-realtime-clock}.log,
position-projection-gen{1,2}.csv, position-projection-motion-gen{1,2}.csv,
review_position_projection.py and position-projection-review.json.


## Shared player/NPC projection calculation — 2026-09-11

The QA-only human_position_projection.lua replaces the inline player arithmetic
in the realtime projection driver. Its pure query does not mutate actor or
pose tables. It verifies the current coordinates against the engine's native
floored step equation, requires matching cardinal facing/target and a one-cell
segment, admits 16–64 frame steps, and uses Gen1 NPC's 32-frame default versus
16 frames for both players and Gen2 NPCs. Inconsistent/unknown schemas, altered
poses, nonfinite values, finished steps, lift, frozen/input/script ownership,
walking-in-place, jump/hop, bicycle/surf, teleport/tree-shake/rock-smash/bounce
and explicit action/Pokemon markers are excluded. Scene, option and exact
source readiness admission are caller responsibilities and remain to be wired.

The pure test passes 12,800 samples over four directions, player/NPC defaults,
explicit step durations, bounded projection, input immutability, repeated
queries and rejection cases. Native Red and Crystal test drivers call the
actual NPC.update methods on isolated fixture objects: 3,840 and 3,520
projection samples match those native step equations and finish at exactly
the native target with no residual offset. This is native-method coverage,
not yet a world-NPC visual or collision/pathfinding test.

The final shared helper also passes the actual-input, realtime 120-FPS player
fixtures for all six heroes. Updated paired trace results: Gen1 308 pairs,
156 native holds versus zero projected holds, increment standard deviation
.5000 to .0713; Gen2 339 pairs, 169 holds versus zero, .5000 to .0921. The
same 4–12 ms adjacent-moving-pair filter applies. Maximum offset stays below
one unit (.9727/.9750). Earlier prototype measurements remain historical.

Evidence: human_position_projection.lua, position-projection-test/main.lua,
position-projection-core.log, integrated-npc-position-projection.lua,
npc-position-projection-{red,crystal}-final.log,
position-projection-helper-{red,crystal}.log and updated projection CSV/JSON.
All reside in private non-Orange QA. No production source or payload changed.
Camera coordination, normal-option/scene/source gates, runtime fallback and
temporal visual acceptance must be completed before integrating this helper.


## QA camera/pose coordination — 2026-09-11

The camera prototype snapshots the player's fractional offset once at the
start of each host draw and uses that alpha for pose preparation. The same
x/y offset is supplied to Voxel3D.beginScene, ShadowMap.begin and the glass
glint camera query. Each main-camera invocation asserts its offset matches
the prepared player pose. No native camera fields are assigned. Calls at
each prototype camera boundary assert unchanged native camera fields and
preserve all return values.

Final private realtime 120-FPS Red/Green/Blue and Gold/Kris/Silver input runs
pass: Red has 319 main-camera and 319 shadow-camera nonzero-offset calls;
Crystal has 368 and 182. The latter counts reflect actual invocations, not
a promise that a cached shadow is rebuilt for every main-camera call. Moving
Red and Gold screenshots were inspected. This tests the current ordinary
interior camera only; first-person/VR, outdoor/reflection coverage and temporal
visual acceptance remain open.

The initial camera test needed two fixture corrections. Renderer ownership
includes beginScene as well as preparePokemonFrame, so both must be restored
before map changes and rewrapped after binding. Red's public facade omits
ShadowMap; the test retrieves the active private module from
scene.render -> renderWorld -> castShadows. This debug access is QA-only,
not a proposed production API. Crystal's World:draw normally calls Camera:follow
and applies screen-position lift during drawing (src/world/gen2/World.lua).
A whole-draw unchanged-camera assertion therefore falsely attributed native
updates to the prototype. It was replaced by assertions around the actual
three prototype camera boundaries, supported by inspection of the native code.
The first failed process entered LOVE's error display and was explicitly
interrupted; subsequent tests print fatal errors and exit instead of idling.

Evidence: integrated-camera-projection.lua,
camera-projection-{red,crystal}-hook-boundary.log, camera-projection-gen{1,2}.csv,
camera-projection-motion-gen{1,2}.csv and camera-projection-moving-{red,gold}.png
in private non-Orange QA. Production code/payload are unchanged. Normal
option/scene/source admission, fallback and further camera modes must still
be implemented and tested before integrating fractional presentation.


## Production fractional walking integration (2026-09-11)

This section supersedes the prototype-only status above. `human_position.lua`
now prepares fractional presentation coordinates once before shared rendering;
`VoxelScene.lua` applies the matching local player camera offset before
first-person preparation, shadows, glint and scene rendering. Native actor and
camera state remain owned by the engine. Repeated preparation is idempotent;
Classic/HD-off restores an already prepared pose. The renderer admits only
ready human card sources in the active matching world/map/player, Natural
mode and normal walking. Dialogue/script locks, special actions, malformed
clocks, missing assets and mismatched providers retain native positions.

The regression runner passes, including 12,800 projection samples and actual
production admission/camera-block tests, partial-error rollback, plus existing
198-atlas geometry and Gen2 rendering/fallback checks. Native real-input
Red/Green/Blue and Gold/Kris/Silver tests pass with 131/129/127 and 141/143/143
fractionally positioned frames, respectively, including camera and live
Classic/Vanilla switches. The private driver adapts its forced update delta
to real time at 120 FPS; this is QA setup, not a production engine change.

Isolated real NPC classes also pass: Bill/Kurt yield 185/193 fractional frames
in Red and 113/140 in Crystal, with immutable simulation, zero NPC camera
offset, Classic, Vanilla and real TextBox-dialogue exclusions. These are
controlled fixtures, not story-map or pathfinding acceptance. Each fixture
owns a baseline renderer made from the player definition so fallback can be
exercised; its baseline artwork is not a claim of authentic Bill/Kurt sprites.
An earlier fixture omitted this baseline and failed on Vanilla; corrected
fixtures passed both generations.

Production moving Red and Gold screenshots were visually inspected: each
shows one main character at the floor anchor. A still image cannot establish
absence of intermittent sprite flashes or temporal jitter. Head-turn blend
ghosts remain open, as do wider camera/VR/first-person/outdoor/transition and
performance acceptance. The package remains review-foundation-incomplete.
Evidence: human-position-integration/ contains production drivers, four native
logs, regression output, trajectory CSVs and six-hero captures.


## Correction: Gen2 camera integration and four-direction runtime audit

The previous production-position-crystal.log contained a swallowed
`Stadium VoxelScene overlay failed` camera assertion even though the process
exited zero and printed per-role PASS markers. Its earlier camera acceptance
is withdrawn. Marker-only verification was too weak. The root cause was a
missing production change in `gen2/lib/VoxelScene.lua`: Gen2's patched scene
uses that separate source. Player positions were fractional but its local
camera centre was still integer. The same bounded offset now runs after pose
preparation and before glint, first-person and shadows in that source too.
Externally supplied VR eyes retain their caller-owned centre; this guard is
unit-tested, not a VR visual acceptance claim.

A new native driver exercises right/down/left/up twice for each of the six
heroes, resetting to known clear indoor cells before each segment. It audits
the actual renderer submission seam with QA-only stack inspection to identify
player calls, permitting animated canvas textures but rejecting the native
proxy texture. It also tests Classic/Vanilla switches. Red/Green/Blue each
produced 1,014 authored submissions and zero proxy submissions; Gold/Kris/
Silver produced 1,056/1,048/1,064 and zero proxy submissions. There were 2,003
Gen1 and 2,076 Gen2 camera assertions. Both logs have no runtime error lines.
The new external log verifier rejects the old swallowed-error log as a
negative control. The full regression runner passes with both production
camera source blocks exercised, including the external-eye ownership guard.

Earlier test attempts used a square path that hit furniture, compared only
the atlas texture instead of animation canvases, and subsequently exposed
the real Gen2 camera omission. Those attempts are not acceptance evidence.
Trajectory CSV travel totals include explicit between-segment repositioning;
do not interpret them as uninterrupted distance or performance measurements.
Source submission checks exclude old-proxy fall-through in these observed
player calls only. They do not prove absence of every possible ghost pixel,
head-morph double contour, or fallback transition in every scene. Grid,
free-camera, outdoor, NPC story scenes and longer frame pacing remain open.

Evidence: four-direction-camera-fix/ contains the driver, source-aware log
verifier, accepted logs, verification summary and regression log. This section
supersedes the earlier Gen2 camera conclusion. Package status stays incomplete.


## Grid preparation preserves animated poses (2026-09-11)

The natural human path previously discarded the already computed flat rig
when `humanGrid.prepare` returned pending, drawing the static card until the
queued grid became available. This could switch arm poses during initial
preparation or a new direction. It now keeps that same animated mesh and
texture until a grid is ready; grid initialization/preparation failure also
retains the available flat rig. Classic behavior is unchanged.

A native grid-enabled version of the four-direction test exercises all six
heroes, eight real-input segments per hero, repeated cold map preparation,
live Classic/Vanilla switches and camera alignment. A QA wrapper records the
flat animated mesh passed into grid preparation and checks exact mesh
identity at the actual player submission when preparation reports pending.
Red/Green/Blue passed 128/140/140 such checks; Gold/Kris/Silver passed
130/136/132. Each also produced over 1,000 ready-grid draw calls. The
source-aware audit found zero native player proxy submissions, and the logs
contain no runtime errors. Gen1/Gen2 camera checks total 1,844/2,027.

Grid counters include shadow/color passes; pending totals are cumulative,
not unique frames. Concurrent private tests are functional checks, not FPS
benchmarks. Indoor Red/Gold stills were inspected for silhouette/floor anchor;
stills do not prove temporal perfection. The brief transition from animated
flat surface to prepared grid is still a representation change and has not
been established visually imperceptible. Camera variants, outdoor scenes,
head-turn ghosts and wider NPC coverage remain open. No Orange interaction.
Evidence: grid-position-continuity/ in the review package.


## Johto ace trainers: reviewed arm profiles (2026-09-11)

Added exact v1 profiles for ace-trainer-male-gen2 and ace-trainer-female-gen2.
Neutral hand boxes were inspected in all four atlas rows. The female profile
preserves the long hair and shorts in the reviewed neutral/A/B gallery.
The initial male side profile left a detached source-hand remnant in stride B;
a second source-hand protection region at normalized x=.82 (left-facing) and
.18 (right-facing) removes it. The corrected twelve-pose gallery was inspected.
No sprite PNG was modified. Atlas coverage is now 84/198, leaving 114 pending.

Native isolated NPC render fixtures passed both profiles in Red and Crystal:
independent NPC records, four directions, pixel composition and shared mesh
geometry/lifetime checks. The same driver also passed its existing player
Classic/Vanilla, dialogue, script/input lock and map/option epoch checks.
These context checks concern the driver player, not a claim that each new
NPC was separately exercised in every story scene. Logs contain no runtime
errors, and the full human regression runner passes (84 admitted sources).
The Red fixture explicitly binds these Gen2 cards for renderer compatibility;
it does not change Gen1 map bindings. The inventory lists 14 male and 17
female references; live encounters at those references remain to be reviewed.

Evidence: ace-trainer-profiles/ in the review package contains source landmark
notes, galleries, native logs, driver and regression output. No new blink
profiles were added here. General head-turn ghosting, all remaining NPCs,
additional acting poses and wider performance acceptance remain open.


## Johto ace-trainer idle blinking (2026-09-11)

Both exact v1 ace-trainer sources now have procedural front/left/right eye
profiles. Source inspection supplied the hair-adjacent front eye missed by
the automatic probe: male [65,68,78,83], female [63,59,76,76]. Remaining boxes
were checked against the source and the open/half/closed renderer gallery.
The gallery verifies unchanged source alpha and opaque pixels outside eye
regions, shared shader allocation, and no rear output. No raster edits or
additional eyelid assets were needed. Ordinary exact blink coverage is now
17 sources; arm coverage remains 84/198.

Native isolated NPC fixtures pass Red and Crystal scheduled idle cycles,
side output, rear exclusion, moving-eye cancellation, Classic and Vanilla.
Observed closure peaks: male/female .99857/.99965 in Red and .98596/.99020 in
Crystal. Logs contain no runtime errors. The native Red female closure capture
was visually inspected. The full human regression runner passes. This is
renderer/fixture evidence, not a claim of checking all real trainer encounters
or their dialogue scenes. Those wider scenes and remaining NPC sources stay
open. Evidence: ace-trainer-blink/ in the review package. No Orange tests.


## Outdoor real-input frame measurements (2026-09-11)

Private Red Pallet Town and Crystal New Bark Town walks use production human
animation/positioning, normal residents/followers and real left/right input.
Each sequential process takes Classic/Natural/Natural/Classic seven-second
samples, excluding the first second from steady summaries. A private real-dt
adapter corrects the engine driver's forced timestep; a private cap adapter
requires VSync before reporting hardware pacing. Resolution 960x720, cap60,
VSync off, human grid off. No simultaneous QA games were used for these runs.

Red initial interval p95 (ms): 17.589,19.268,17.607,17.487; corresponding mean
whole-draw costs: 3.888,4.682,4.902,4.509. The first Natural sample has a
112.541ms interval, with 48.736ms spent in its preceding draw. Crystal p95:
17.735,17.793,17.808,18.313; mean draw: 4.180,4.569,4.755,4.838. Its longest
interval is 61.939ms in the final Classic sample. These are observed samples,
not controlled identical routes: live NPC collisions and the player's continuing
position change the view. The driver checks substantial travel per sample.
Blinks were enabled normally but the moving player had zero blink frames;
these runs do not benchmark an actual eyelid closure.

A second sequential Red run adds measured game.update time per draw interval.
The four worst intervals are 66.674,47.325,71.369,42.850ms. Their preceding
draws are 64.487,3.397,70.139,4.625ms, and measured updates 1.484,.870,.524,
.685ms. Remaining time is .704,43.058,.706,37.540ms. This residual includes
presentation/pacing/host scheduling and uninstrumented engine work; it is not
attributed to a specific subsystem. Long drawing and non-drawing intervals
occur in both modes. The measured update call does not explain these worst
pauses; further profiling should focus on drawing and inter-frame work.

All three processes exited successfully with four completed samples each and
no runtime error lines. Natural outdoor Red and Kris screenshots were visually
inspected, with resident actors and floor shadows present. These stills do not
prove temporal smoothness. Production code was not changed during measurement,
and no general performance acceptance is granted. Raw per-frame CSV, logs,
drivers and update breakdown live in outdoor-frame-measurements/ in the review
package. No Orange interaction; no frame-cap patch was installed in a live game.


## Outdoor render-stage diagnosis and held matrix prototype (2026-09-11)

Red's corrected stage driver classifies preparation, human cards, Pokemon
cards and other Voxel3D submissions during normal outdoor walking. Its four
worst draw frames (Classic/Natural/Natural/Classic) were 20.276/22.337/24.924/
41.076ms; human drawing took .218/.703/.851/.363ms in those frames. A later
instrumented run timed draw/drawInstanced, setCanvas/setShader and creation
of canvases/images/meshes/shaders. None of those individual calls exceeded
8ms. Their combined durations in each sample's worst whole draw were
.573/.526/.741/.850ms out of 23.550/19.132/26.071/25.981ms. This list does
not cover every graphics method, and graphics timings overlap the card
categories; do not sum the two measurements. It narrows these observed
frames away from human card submission and the sampled graphics calls.

A separate Lua instruction hook (every 20,000 VM instructions, only during
draw) frequently sampled Mat4.mul, loader option lookup, diagnostic string
cleanup and alpha-bound scanning. Instruction frequency is not wall-time
attribution; JIT/hook overhead prevents using that run as an FPS benchmark.
The first stage attempt failed because a QA counter inspected the timing
wrapper rather than its original function; corrected logs passed.

An unrolled Mat4.mul candidate preserves original arithmetic order and
allocates its result in one table constructor. 2,048 random general matrix
pairs matched exactly in the benchmark. A temporary full regression test
checked both Gen1/Gen2 files (4,096 products, fresh results, unchanged inputs
and affine composition), and the full human runner passed. Alternating
150,000-product trials gave median times of 120.742 -> 31.710ms with JIT
and 231.983 -> 105.724ms without JIT, with substantial individual variance.

The candidate's subsequent real outdoor run was slower than the earlier
baseline, but a fresh original-function control was slower still, with large
outliers. A process snapshot after the control observed three unrelated
LOVE processes at approximately 50-60 percent CPU each, as well as other
host load. Those processes used a different executable path and were not
interacted with. This contemporaneous observation does not reconstruct
host load for every earlier sample. It prevents treating these runs as a
controlled overall-performance comparison.

The candidate was therefore NOT promoted: both production Mat4 files were
restored byte-exactly, the temporary test was moved into private QA, and the
54-file package payload remains unchanged. Evidence is retained under
matrix-render-optimization/ as a prototype, including both controls. Future
whole-game acceptance needs a controlled host/scene comparison; work on
other missing actor profiles and poses can proceed independently. No Orange
interaction and no general performance completion claim.


## Approved Gen1 youngster family (2026-09-11)

Added an exact arm profile for the bald Gen1 youngster and its approved green
and red palettes. All three alpha channels are byte-identical. Neutral hands
were inspected and front/back/side windows fitted; side source-hand protection
also suppresses distant remnants from the walking atlas. Twelve-pose galleries
for base/green/red were inspected. No sprite PNG changed. Arm source coverage
is now 87/198, leaving 111 sources without reviewed profiles.

The initial side configuration carried an inappropriate equipment gains field.
Side motion does not consume that field, but the equipment invariant checker
rightly rejected the advertised pinning. It was removed; the figure carries no
prop, and actual side geometry was unchanged. An initial test also incorrectly
assumed the legacy cap atlas was globally rejected. Source inspection confirms
WalkingSprites applies that rejection only to Gen1. The corrected test checks
the existing Gen1 rejection; Gen2 binding policy remains unchanged. No profile
for the cap artwork is added by this change.

Corrected isolated native NPC fixtures pass Red and Crystal: four directions,
shared geometry, source pixel composition, independent record and both palettes.
Their pre-existing player context checks also pass Classic/Vanilla, dialogue,
script/input lock and map/option invalidation. These context checks are not a
claim that each youngster encounter was individually tested. The base inventory
has 34 references; live story/route acceptance remains open. Logs contain no
runtime errors. No new youngster blinking profile is included in this step.
Evidence: youngster-profiles/ in the review bundle. No Orange interaction.


## Approved youngster family blinking (2026-09-11)

Added exact procedural front/left/right profiles for the bald youngster and
both approved palettes, with distinct alternate profile identities. Manually
reviewed eyes are front [59,52,74,68] and [89,52,104,68], left [57,282,67,299],
right [97,739,107,756]. The automatic face probe also found eyebrow/scalp/ear
components, which were excluded. No source PNG or generic binding policy changed.
Ordinary blink coverage is now 20 exact atlas sources; arm coverage stays 87.

Base/green/red GPU galleries pass original alpha, unchanged opaque pixels
outside eye bands, shared procedural shader and rear exclusion. Base and green
galleries were visually inspected. Native isolated NPC tests exercise each
palette in Red and Crystal with scheduled closure, both sides, rear exclusion,
movement cancellation and live Classic/Vanilla. Closure peaks are .99746/1/1
in Red and 1/1/1 in Crystal. All logs lack runtime errors. The full regression
runner passes. Each native palette case creates its own NPC fixture; it does
not prove a same-live-NPC palette swap or every real story encounter.

Small bright edge remnants visible around the original bald head are present
in the source and deliberately unchanged by the eye-only render. They remain
an artwork/edge-cleanup concern, not a claim of final all-character perfection.
Evidence: youngster-blink/ in the review package. No Orange interaction.


## Youngster bright-rim diagnosis and shader prototype (2026-09-11)

Read-only source inspection finds an almost-white horizontal run at source
row 12, x75..88, directly above the dark scalp outline. Most of that run has
alpha 241..246/255, so increasing a low-alpha cutoff would not remove it.
Eight-connected alpha components do not isolate it from the main body;
a generic small-island removal would miss this artifact. The rim is already
in the source; it is not a blink or double-render product.

A private LOVE shader prototype removes pale near-neutral boundary pixels
only where transparent exterior and a dark opaque inward neighbour establish
a rim. The first broad pass removed 432 pixels but also touched shoes, so it
was not selected. The revised version limits treatment to the first 105 rows
of each 225-row cell and checks up to two pixels across the boundary. GPU
checks assert that only alpha-clearing occurs, every changed pixel is within
two pixels of transparent exterior, clothing/shoe rows remain unchanged, and
retained opaque pixels preserve RGB. All twelve source poses were rendered
side by side and inspected. Large scalp/side ticks are reduced; tiny edge
remnants remain, so this is not complete cleanup acceptance.

This is a shader/code prototype; source PNGs are unchanged. It is not wired
into production. Integration must keep the correction consistent between
rig composition, blink output and grid preparation, and preserve exact
Classic/Vanilla behavior. It must not clean only the base rig and let old
bright pixels reappear with an eyelid canvas. Other character sources need
separate review before any general admission rule. Native/performance and
cross-palette acceptance are still pending. Evidence: youngster-rim-lab/,
youngster-rim-prototype.log, youngster-head-rim-prototype.log and comparison
screenshots in private QA. No Orange interaction.


## Shared youngster rim integration (2026-09-11)

The earlier QA-only prototype is now integrated through optional human_rim.lua.
Only the three reviewed 495x900 bald youngster sources opt in, via matching
rig and blink profiles. Both shaders share the same source sampling rule;
grid preparation consumes the resulting animated texture. Source PNGs remain
unchanged. Other sources do not opt in. Classic/Vanilla retain their existing
render path. This supersedes the prototype-only status above, not its visual
limitations: tiny edge remnants and other characters still need review.

The separate graphics-enabled tests/human_rim_runner passes against actual
LOVE shaders: 280 alpha removals across three palettes and three neutral
views, rig/blink alpha agreement, unchanged clothing and opaque non-eye RGB,
strict profile/dimension admission, and rear/moving blink exclusion. This is
a different sampling scope from the earlier all-twelve-cell prototype count.
The ordinary non-graphics human_motion_runner also passes.

Native isolated NPC fixtures in Red and Crystal pass all three palettes with
grid off and on: scheduled closure, side output, rear exclusion, moving blink
cancellation, Classic and Vanilla overlay shutdown. Grid runs assert that
the exact target NPC entered animated grid preparation without grid errors.
All four logs are checked for runtime errors as well as per-palette markers.
Grid/base/Gen1 and flat/red/Gen2 captures were visually inspected. They show
closed eyelids and reduced scalp ticks; still images cannot establish absence
of every transient flash. Fixtures do not prove real story encounters or a
live same-NPC palette change. No host-isolated performance approval is claimed.
Evidence: youngster-rim-integration/ in the review package. No Orange access.


## Oak dialogue eyelids (2026-09-11)

Oak's two hash-validated 256x256 turn endpoint textures now have reviewed eye
rectangles and procedural eyelid sweeps. human_turn uses the existing human_idle
schedule only at an exact settled endpoint. Starting a turn cancels eyelids;
unsupported directions, actor/reset/options epochs clear the schedule. Blue's
rear turn has no eye profile. This adds two acting endpoint treatments, not
two ordinary atlas sources: the ordinary coverage remains 87 arm / 20 blink.

Actual LOVE GPU tests verify partial/full closure in both endpoint views,
unchanged alpha and opaque non-eye pixels, and no eyelids during interpolation.
The six-cell gallery was inspected. The portable test lives under
tests/human_turn_blink_runner. The regular human_motion_runner also passes;
its turn test now exercises the real idle schedule, multipass caching, turn
cancellation and reset. An initial test setup failure retained the preceding
injected GPU-failure flag; clearing it before the new case corrected the test.

A private Red native run follows the real Pallet high-grass trigger and escort
through six laboratory dialogue boxes. Oak reaches full scheduled eye closure
while facing Blue and while facing Red (peak 1 in both); captures were inspected.
It also passes Blue turn continuity, 15 exact native pause observations,
Classic/Vanilla shutdown and stale-dialogue epoch rejection. Logs are checked
for swallowed runtime errors as well as terminal successful completion.

This does not fix the known optical-flow double contours during head/body
turns, add front-facing dialogue blinks to other actors, or establish global
performance acceptance. Only open-eye settled frames retain the prior canvas
cache; active eyelids redraw their small canvas. No Orange access. Evidence:
oak-dialogue-blink/ in the review package.


## Idle crowd blink-cache correction (2026-09-11)

Reproduced a concrete rendering-work defect: 40 open-eyed actors sharing an
approved profile, visited in stable order for 30 frames, caused 1,200 canvas
allocations and eyelid warmup renders. The 32-owner LRU evicted each actor
before its next visit (1,168 evictions), so every frame repeated initialization.

Warmup completion now belongs to the exact eye profile resource. Once warmed,
open eyes return the original source without touching the actor LRU or creating
a canvas. Active eyelids still allocate/reuse bounded per-owner output. Resource
clear resets warmup state; invalid amounts are rejected before shader loading.
The first actual draw still warms each profile, preserving the existing intent
to exercise its shader ahead of scheduled closure. This does not precompile
all profiles globally or eliminate every first-use allocation.

The new 40-actor regression fails on the prior implementation with 1,200
renders and passes after the change. A real LOVE GPU A/B using the same exact
youngster source reproduces 1,200 renders/allocations before versus one after,
with zero idle evictions after. All 40 subsequently requested partial closures
still render in both versions. The prior module is preserved with its SHA-256
in blink-crowd-lab/ for reproduction. Counts describe workload, not a measured
whole-game FPS gain. Simultaneous active blinks beyond the 32-owner budget can
still require eviction; the fix specifically removes open-eye churn.

The complete ordinary regression runner and shared rim GPU tests pass. Native
isolated fixtures in Red and Crystal pass all three youngster palettes with
scheduled closure, side/rear policy, movement cancellation and Classic/Vanilla
shutdown. Both native processes terminated successfully, with error-aware log
checks. Native tests use three palette cases, not an actual 40-NPC story scene.
Evidence: blink-idle-crowd/ in the review package. No Orange access.


## Active crowd eyelid canvas reuse (2026-09-11)

The preceding open-eye fix did not eliminate GPU allocation churn when more
than 32 actors actually blink. The new regression reproduces repeated
allocation with 40 active actors. Matching width/height canvas and quad sets
are now transferred from the LRU victim to the next owner. Source, role, eye
profile, amount and row metadata are freshly initialized; the new owner must
render its own face, even when its amount equals the previous owner's amount.
Different dimensions release/reallocate instead. Capacity remains 32 owners.

Real LOVE GPU A/B: 40 actors across 30 frames, changing closure amount and
front/left/right views across three exact youngster palettes. Both versions
render 1,200 requested eye outputs. Canvas allocations fall from 1,200 to 32,
with 1,168 successful reuses. Each eye output is immediately drawn into a crowd
canvas; all 30 complete RGBA frame hashes match the prior implementation. This
checks that repainting a canvas does not corrupt already submitted draws. The
final crowd image was inspected. This is allocation reduction and image parity,
not a whole-game FPS benchmark or proof that existing source rim artifacts are
fully resolved. No new native scene run is claimed for this isolated cache fix.

The portable GPU test tests/human_blink_crowd_runner retains the prior module
as a test-only baseline. The ordinary regression runner passes, including
active allocation stability, incompatible-size rejection, bounded ownership,
exact resource release, packed asset failure and rebuild. Existing native
Classic/Vanilla/source tests are part of that runner. Evidence and baseline
are included under blink-active-crowd/. No Orange access.


## Elm interaction-owned dialogue idle (2026-09-11)

New human_dialogue_idle.lua admits only the exact bound Professor Elm source
in ELMS_LAB during a directly initiated NPC conversation. It is controlled by
the existing DIALOGUE POSES (TEST) switch plus NATURAL, HD PEOPLE and people
grid OFF. The option descriptions now include Elm. This extends the pilot's
Johto coverage to dialogue breathing/eyelids, not diagonal/head poses. Ordinary
arm/eye atlas coverage remains 87 / 20.

Ownership starts with world.interacted kind=npc and binds the ensuing
script.started context only when VM, script key and object index match. Johto
resumes its coroutine BEFORE invoking showTextFn, so a coroutine.running
check at screen.pushed was correctly found insufficient in the first native
run. The final adapter wraps only that active VM's showTextFn, preserving its
return values/errors, and captures only the textbox pushed during its actual
text request. General humanScene remains closed. Source/world/save/map/actor
identity, frozen stationary position and exact current box are required.
Other actors and the player remain ineligible. Dialogue entry/exit clears
travel state; weight shifts are disabled in this dialogue pilot.

Script end or reset restores the VM callback if still owned; another mod's
later wrapper is preserved. Map/save/options changes clear ownership. Classic,
Vanilla and grid activation disable the adapter; re-enabling does not revive
an existing dialogue. Missing/replaced source or actor action invalidates it.

Native private Crystal test: actual World:interact with Elm, 2,310 sampled
textbox frames, zero missing motion states, full blink peak 1, breath range
.006, no walking/arm stride/weight shift, and no bystander/player admission.
Closed-eye screenshot inspected. Classic restores the exact VM callback and
clears motion; Natural/Vanilla toggles cannot resurrect the old dialog. The
final ordinary regression runner passes, including the new admission tests
for foreign textboxes/actors, signs, script/object mismatch, movement, source
action, map/save/VM changes, option shutdown, callback restoration, later
wrapper preservation and original text errors. Final native log is checked
for swallowed errors as well as terminal success. Subsequent defensive nil
source/nonnumeric index guards are covered by the final unit run.

The private fixture sets both save and live mapScenes to 1 before interacting.
It does not validate automatic Elm map-entry cutscenes or other Johto actors.
It also does not resolve the existing optical-flow double contours or provide
a global performance approval. Evidence: elm-dialogue-idle/ in review package.
No Orange access.


## New Bark mother dialogue idle (2026-09-11)

The interaction-owned Johto pilot now admits the exact johto-mother atlas in
PLAYERS_HOUSE_1F as well as Elm in ELMS_LAB. Admission profiles pair each map
with its role and source; neither actor inherits the other map's permission.
A captured map object's label is also pinned against in-place relabelling.
The existing dialog test switch and Classic/Vanilla/grid restrictions apply.

Native private Crystal run uses the real mother and World:interact after
setting scene 1 in both private save/live scene stores. It observes 2,455
textbox frames with motion present, blink peak .98965, breath range .006,
neutral legs/arms and no weight shifts. Other human NPCs and the player do
not inherit permission. Classic removes the VM wrapper; subsequent Natural
and Vanilla toggles cannot revive the old dialogue. Screenshot inspected;
process terminates successfully and log is error-checked. Unit coverage adds
the mother route, wrong actor/map pairing and in-place map relabelling; the
complete regression runner passes.

Explicit outstanding user requirement: THE NEW BARK MOTHER MUST ALSO SIT ON
HER OWN CHAIR. This patch still uses her standing atlas, and does not satisfy
that requirement. Her seated body, chair alignment and dialogue head turn are
next visual work, distinct from Red's seated mother. Automatic introductory
scenes and dialogue choices remain outside this direct-interaction acceptance.
No all-character completion or global percentage is claimed. Source arm
coverage is 87/198 (about 44%); this is not overall task completion.

Evidence: johto-mother-dialogue-idle/ in the review package. No Orange access.


## Opposite New Bark guest dialogue ownership (2026-09-11)

The direct-conversation adapter now also admits the requested opposite woman,
PLAYERS_HOUSE_1F object index 5 with the exact base pokefan-female-gen2 atlas.
All routes are explicit map/role/atlas/object-index pairs (mother index1,
Elm index1). Matching artwork in another slot does not inherit admission.
This prepares exact ownership for the pending seated rendering of both women.

Private native Crystal test interacts with the real guest at cell4,4. Across
2,572 textbox frames her presentation state is available and breathing varies
by .006; no arm stride, walk or weight shift is introduced. Mother, player
and other human bystanders remain ineligible. Classic restores the exact
VM text callback and clears motion; re-enabling Natural/Vanilla cannot revive
that conversation. Native screenshot inspected, process exited successfully,
log error-checked. The ordinary regression runner passes, including the new
guest route, wrong participant and same-looking wrong object slot exclusions.

The logged blink clock peak is NOT evidence of visible guest eyelids: this
ordinary source has smile-closed front eyes and no admitted eye-render profile.
The two women still use standing artwork in production. Their seated body
plates, natural head motion and seated blinking remain outstanding. The
seated QA experiments are not promoted by this change. No Orange access.
Evidence: johto-guest-dialogue/ in the review package.


## Johto dialogue query failure cleanup (2026-09-11)

The direct-dialogue owner now pins its state-stack identity and guards both
stack.top and world.scriptRunning queries. A replaced stack or failed query
revokes admission and restores the still-owned VM text callback. It cannot
throw a renderer error or retain dialogue animation through such a failure.
The regular regression runner passes with explicit injected stack/VM query
failures and stack replacement. The actual guest conversation and Classic/
Vanilla rollback run passes again in private Crystal; final logs are checked
for runtime errors and both processes ended successfully.

Separately, another generated shoulder-reference image failed the transparency
requirement (RGB with painted checkerboard). A read-only neutral-background
connectivity analysis identifies a plausible extraction region but has not
changed any image. An explicit user method question is pending for code-based
image extraction/alignment because the image tool instructions require that
exception to be requested by the user. Seated art remains unapproved.
Evidence: johto-dialogue-query/ in review package; private seated art audit.
# New Bark mother: alternate lower step (2026-09-11)

The exact johto-mother walking atlas repeats the same lead foot in front/rear
step columns. The Natural rig now reflects lower-body sampling for column 2
only in this profile's front/back directions. Source/target body centres define
the reflection axis; the existing .87–.895 leg blend preserves the neutral
skirt, hands and face. All source PNGs and Classic/Vanilla sampling are unchanged.

Evidence in the private QA directory: `mother-step-mirror-gpu.log` verifies
all ten unselected mother cells byte-identical to the previous renderer and
exact upper-region preservation in the two changed cells. The default-profile
control (`mother-step-default-parity.log`) verifies all twelve Red cells retain
exact RGBA output. `mother-step-mirror-native-production.log` exercises the
actual mother's native NPC step updater in a relocated private house lane:
128 movement samples, both front/back directions and all three columns,
settled idle, Classic exclusion and Vanilla original-source restoration.
The full `human_motion_runner` passes (`mother-step-mirror-regression.log`).

Static enlarged GPU comparison and native screenshots were inspected. This
does not prove perfect foot contact across all frame rates or fix the side
view poses. It does not complete either seated woman, head turns or the guest's
basket continuity. The runtime profile change is narrowly source-bound; no
other source is admitted by it. No Orange testing.
# Guard arm profile (2026-09-11)

The exact guard-kasc-hd-4x3-walk-sheet-v1.png source now has independent
front/left/back/right hand landmarks. Its coat hem and belt stay above the
.77–.795 leg blend. No image assets or binding rules change. Runtime source
profile count is now 88; this is coverage, not an overall completion percentage.

`guard-rig-native-clear.log` exercises the real VASC renderer with an injected
independent NPC pose in the private Gen2 house fixture. All four directions,
12 composite cells, hand preservation, mesh surfaces/phases/flat/relief,
independent actor geometry and Classic/HD-off motion exclusion pass. It is
not an autonomous physical guard-walking or population-rebinding test. A
discarded source-restoration assertion incorrectly treated the synthetic
pose as part of world.npcs; the corrected scope is explicit in the final log.
Original-sprite restoration for actual population actors remains covered by
the existing engine/binding regression suite, which passes in
`guard-rig-regression.log`. Four unobstructed native screenshots are preserved.

The first screenshot overlapped a follower Pokémon with the injected guard;
the corrected fixture separates them. No source-rim fix was inferred from
that overlap. The coverage CSV was stale by ten earlier profiles and is now
synchronized with all 88 literal source entries (also counted by the Lua
profile test). The explicitly rejected old cap-Youngster is marked as such,
instead of being prioritized from its obsolete inventory references.
# Junior female trainer arm profile (2026-09-11)

The exact jr-trainer-female-kasc-hd-4x3-walk-sheet-v1.png source now has four
manually reviewed hand-end landmarks. Skin-component centroids were unsuitable
because the front/rear components include the entire forearms and the side
hands were missed. The .77–.80 leg blend keeps the vest and upper shorts stable.
No source PNGs or NPC binding rules were changed. Arm-profile coverage is 89
exact sources; this does not imply complete idle/blink or gait coverage.

`jr-trainer-rig-native.log` passes the independent injected-NPC renderer check
in the private Gen2 house fixture: four directions, twelve composite cells,
protected hands, all sampled mesh phases/flat/relief and independent actor
meshes. Classic/HD-off revokes its Natural motion. This reuses the guard QA
driver; its GUARD_NATIVE_FALLBACK_PASS label refers to the selected junior
source in this run. Four screenshots were inspected. As with the guard, this
is renderer-pose evidence, not autonomous map-NPC walking/population rebinding.
`jr-trainer-rig-regression.log` records the full existing regression run.

The authored repeated front/rear lead-foot pose still needs separate review;
this change supplies arm motion, not corrected step art. The girl, rocker and
Silph worker sources inspected in the same batch were not admitted: their
bag, guitar case or belt tools need separate deformation/occlusion protection.
# Hero lead-foot corrections and longer native walks (2026-09-11)

Source review found repeated lead-foot poses in the exact hero sheets. Enable
the existing reflected second lower step only for Blue front/back, Red back,
Gold front and Kris front/back (six cells total). Their upper bodies remain
unchanged. Blue's NPC alternate is a separate profile and does not inherit this
flag. Source PNGs, side views and Classic/Vanilla source selection are untouched.
Arm-profile count remains 89; this change repairs existing hero gait cells.

The enlarged GPU comparisons hero-step-mirror-{blue,red,gold,kris}.png show
opposite lead-foot phases with the same upper bodies. Per-cell logs prove
unselected cells retain exact RGBA and upper regions in selected cells remain
unchanged. The current untouched Silver control retains all twelve cells:
hero-step-unchanged-silver.log. The earlier Red default-parity result predates
this intentional Red-back change and is historical, not current all-cell parity.
The Silver reflected-back experiment was not accepted or enabled; Green's bag
overlap and Silver's back-view pose need further review.

integrated-hero-two-step.lua drives actual player input far enough to reach the
second step, instead of changing direction after one step. Each of the six
heroes completes two passes through all four directions with all three motion
columns observed. Gen1/Gen2 logs pass source submission (zero old-proxy draws),
camera-follow checks and Classic/Vanilla projection exclusion/restoration.
The Gen1 fixture initially hit furniture, so it now selects a real walkable
three-cell lane from the map's collision/warp data; no gameplay collision is
modified. Logs: hero-two-step-gen1.log and hero-two-step-gen2.log. Both exit 0.

The full regression runner passes in hero-step-profile-regression.log. The
six-source cell/mesh/cache checks also pass in hero-step-cell-regression.log.
verify_rig_cells.lua now distinguishes intentionally reflected lower pixels
from untouched regions; it still requires changed lower coverage and pixel
parity outside the blend, plus neutral-hand guards where applicable.

These are static visual comparisons plus native mechanical/source/camera
evidence, not a claim of perfect continuous optical motion at every frame rate.
All six were tested, but only the four named heroes receive new corrections.
Both Johto seated women, their head layers, the guest's basket and general
catalog/idle/performance completion remain open. No Orange environment used.
# Silver back-view opposite step (2026-09-11)

Silver's second back-view authored pose is too close to neutral for a simple
reflection to produce a clear opposite lead foot. His exact back-view rig row
now combines mirrorSecondStep with reuseFirstStep: displayed column 2 samples
the first walking lower body, reflected around the registered source/target
centres. Its vertical alignment uses that sampled cell's bounds. Neutral upper
body and target-cell caching remain unchanged. No other profile uses this flag.

The static enlarged comparison opposite-first-step-silver.png was inspected:
the two back-view phases now show opposite feet with stable jacket/hair. Actual
production GPU tests compare against the renderer immediately before this
change: step-sampler-compat.log verifies all 71 unaffected cells across the six
heroes are byte-identical; only Silver back column 2 changes, with 25,740 upper
pixels still identical. The previous Silver all-cell parity result is now
historical and superseded by this explicit one-cell change.

silver-opposite-step-native.log passes the longer Gen2 actual-input fixture
for Gold/Kris/Silver, all four directions and all motion columns, zero old-proxy
submissions, camera follow and Classic/Vanilla projection gating/restoration.
The full regression suite passes in silver-opposite-step-regression.log. Both
processes exited 0. Tests are functional/GPU evidence plus static visual review;
they do not constitute universal frame-rate/performance or continuous optical
motion acceptance. Green's bag/step issue and the Johto seated/head/guest work
remain unfinished. Arm-profile coverage remains 89. No Orange access.
# Green back-view bag and step correction (2026-09-11)

The authored second back-view step moves Green's bag to the other side. Her
exact rear rig row now starts its leg blend below the bag (.825–.845) and uses
the reflected first lower-step pose for the opposite foot. Per-direction
legWindow overrides the profile default; all other rows retain the existing
blend. The static upper texture, including bag, stays neutral across steps.
This is not a new restriction on existing arm-mesh deformation.

green-bag-step-green.png was visually inspected: the bag stays on viewer-left
and the two feet alternate underneath it. green-bag-compat.log compares both
renderer AND profile snapshots from immediately before the change against the
current runtime. All 70 unaffected hero cells are byte-identical. The two rear
walking cells retain 31,020 upper-region pixels each, equal to the neutral
texture. No sprite images were edited. Source-profile coverage remains 89.

green-bag-step-native.log passes longer actual-input Gen1 walks for Red, Green
and Blue, every direction and all columns, camera follow, zero old-proxy draws
and Classic/Vanilla projection gates. An earlier run stopped short of a second
step late in Blue's pass; the cause was not captured then and did not recur on
the diagnostic rerun. Preserve green-bag-step-blocked-lane.log; do not describe
this as a fixed gameplay collision bug. Diagnostics now report collision/lock
state if that fixture obstruction recurs.

The full regression suite passes in green-bag-step-regression.log. All-six
cell/mesh/cache tests pass in green-bag-cell-regression.log. The old-reference
cell verifier now checks explicitly delayed blends against the neutral upper
texture and still requires changed lower coverage. Both final native processes
and the GPU comparison exited 0. General performance and continuous optical
motion acceptance remain open, as do the Johto seated women/head layers and
guest basket. No Orange environment was accessed.

## Bruno / Hartwig — 2026-09-11

Quellenspezifische Handbereiche, dezente Gewichtsverlagerung und abwechselnde Schritte vorn/hinten ergänzt. Der Hosenübergang wurde nach vergrößerter Sichtprüfung weicher gesetzt. Beide nativen Generationen einschließlich separatem Classic-/HD-aus-/Natürlich-Wechsel pro Figur und der vollständige Human-Motion-Runner bestehen. Die 198 Atlasquellen / 2376 Bilder / 9504 Geometrien bestehen weiter die Katalogprüfung. Keine Rastergrafik verändert. Seitliche Laufkadenz noch nicht vollständig optisch abgenommen; keine neue Blink- oder Sitzfreigabe. Details: martial-leaders/README.md im Prüfpaket.

## Schritt-/Armphase — 2026-09-11

Die natürlichen Fußbilder sind jetzt um ihre jeweiligen Armschwungspitzen zentriert. Zuvor lagen ihre Zeitfenster vier Bewegungseinheiten zu spät. Distanzperiode, Stop-/Wiederanlaufhüllkurve, Positionsprojektion und native Spiellogik bleiben unverändert. Der neue Phasentest und der vollständige Runner bestehen. Echte Eingabeläufe prüfen alle sechs Helden in ihrer jeweiligen Generation, vier Richtungen, Kameraprojektion, Classic/Vanilla und keine ursprünglichen Proxy-Texturen während der geprüften Natural-Zeichenaufrufe. Details und Grenzen: gait-phase/README.md im Paket. Ähnliche seitliche Quellbilder sind damit noch nicht gelöst; keine allgemeine Performancefreigabe.

## Bruno / Hartwig: Idle-Blinzeln — 2026-09-11

Zwei exakte v1-Augenprofile für vorn/links/rechts mit geschützten schrägen Brauen. Korrigierte Lidbereiche verhindern Hartwigs zunächst sichtbare dunkle Wangenflecken. Vergrößerte Produktionsgalerie und beide nativen Renderer geprüft; Bewegung öffnet Augen, Classic/HD aus setzt pro Figur zurück. Alle bisherigen 23 Quellen liefern in 276 GPU-Vergleichen unveränderte RGBA-Pixel. Der volle Runner besteht. Keine Raster- oder Shaderänderung. Details und Grenzen: martial-blink/README.md im Paket.

## Halbtransparente Kopfränder — 2026-09-11

Bruno und Hartwig erhalten eine quellenspezifische Randfarbkorrektur: Graue halbtransparente Randpixel übernehmen die Farbe einer angrenzenden dunklen Kontur. Alpha, deckende Bildteile und Kleidung bleiben erhalten. Die bisherige Youngster-Korrektur bleibt pixelgleich. Vergrößerte Kopfansichten aller vier Richtungen geprüft; GPU-Vergleich bestätigt Rig-/Blink-Übereinstimmung und 276 unveränderte Ausgaben der bisherigen 23 Blinkquellen. Beide nativen Generationen mit Classic/HD-aus-Rückkehr und der volle Runner bestehen. Details: martial-rim/README.md im Prüfpaket. Kein Nachweis, dass damit alle gemeldeten Striche behoben sind. Umfang bleibt 94 Arm- und 25 Blinkquellen.

## Tatsächlich belegten Rig-Bildspeicher begrenzen — 2026-09-11

Die bisherige 24-Quellen-LRU verursachte bei 40 unterschiedlichen Figuren ständige Wiederaufbauten: 1200 Quellen-, Bild- und Geometrieaufbauten in 30 Idle-Durchläufen. Quellenmetadaten und Geometrien sind jetzt jeweils auf 128 begrenzt; erzeugte Einzelbilder haben eine eigene LRU mit 10.692.000 Pixeln (rund 40,8 MiB RGBA8 ohne Treiberkosten). Originaltexturen sind darin nicht enthalten; mehr Quellenplätze können mehr Originaltextur-Referenzen halten. Im Idle bleiben 40 Figuren nach dem ersten Aufbau warm. Bei 40 echten Atlasquellen und 30 Bewegungsbildern sinken die Aufbauten von 1200 auf 120 Bild- und 40 Quellen-/Geometrieaufbauten, bei 30 pixelgleichen Gesamtbildern. Das belegt weniger Wiederholungsarbeit, keine pauschale FPS-Steigerung.

Die Budgetprüfung überschreitet Quellen-, Geometrie- und Pixelgrenzen und kontrolliert Speicherfreigabe, Neuaufbau und idempotentes Aufräumen. Voller Runner bestanden. Alle sechs Helden bestehen den nativen Eingabetest in ihrer jeweiligen Generation samt Classic/Vanilla. Der erste Gen2-Lauf wurde von einem Ambient-Vulpix blockiert und zählt als fehlgeschlagen; der private Wiederholungstreiber schaltet Town Pokémon aus und lässt die eigentliche Kollision unverändert. Details: rig-source-budget/README.md im Prüfpaket. Die übrigen langen Einzelbilder und der vollständige Charakterumfang bleiben offen.

Erweiterter GPU-Test: 150 pixelgleiche Gesamtbilder über vier Richtungen und Rückkehr zur ersten, einschließlich tatsächlicher LRU-Freigabe und Neuaufbau. 600 statt 6000 Bildaufbauten, 40 statt 6000 Quellenaufbauten; Pixelgrenze eingehalten. Siehe rig-source-budget/gpu-evict-rebuild.log.

## Melanie / Will — 2026-09-11

Quellenspezifische Armprofile ergänzt, vorn/hinten abwechselnde Schritte. Melanies verdeckte hintere Arme verziehen die Haare nicht. Wills Hosen-/Frackübergang nach Sichtprüfung höher gesetzt. Beide nativen Generationen, Classic/HD-aus-Wechsel je Figur und voller Runner bestehen. Keine Rasteränderung; seitliche Quellschritte noch nicht vollständig optisch abgenommen. Details einschließlich anfänglichem Prüftreiberfehler: elite-four-rig/README.md. Armquellen jetzt 96/198, Blinkquellen unverändert 25.

## Melanie / Will: Augen und Maske — 2026-09-11

Beide exakten v1-Quellen blinzeln vorn/seitlich. Wills Lider bleiben in geprüften achtpunktigen Maskenöffnungen; separate Hautfarbpunkte verhindern schwarze Füllflächen. GPU-Test sichert unveränderte Maskenpixel außerhalb der Öffnungen, Alpha und geschlossene Iris. Die bisherigen 25 Blinkquellen bleiben in 300 GPU-Vergleichen pixelgleich. Beide nativen Generationen, Bewegung/Classic/HD-aus-Abbruch, Gen2 mit maximaler 3D-Tiefe und voller Runner bestehen. Details: elite-four-blink/README.md. Blinkumfang jetzt 27 Quellen, Armumfang weiterhin 96/198.

## Koga: zwei getrennte Quellen — 2026-09-11

Kanto- und Johto-Grafik haben eigene Hand- und Augenprofile. Johtos Kniesymbol bleibt auf dem ursprünglichen Bein; seine wiederholten Schrittbilder sind noch offen. Tiefer gesetzte schräge Lidkanten erhalten die kräftigen Brauen. Beide nativen Renderer mit Bewegung/Classic/HD-aus-Rückkehr und der volle Runner bestehen. 324 GPU-Ausgaben der bisherigen 27 Blinkquellen bleiben pixelgleich. Keine Raster- oder Shaderänderung. Details: koga-rig/README.md und koga-blink/README.md. Stand: 98 Armquellen / 198, 29 Blinkquellen.

## Lorelei / Agathes Stock — 2026-09-11

Loreleis Hand-/Armprofil und Rockübergang geprüft; beide nativen Renderer mit Classic-/HD-aus-Rückkehr und voller Runner bestehen. Agathes Kandidat wurde entfernt: Der Stock wird im zweiten Quellschritt kürzer oder verschwindet hinten; eine festgehaltene Hand behebt das nicht. Grafikreparatur bleibt offen. Keine Rasteränderung, kein neues Blinzeln. Details: kanto-elite-rig/README.md. Umfang jetzt 99/198 Armquellen und 29 Blinkquellen.

## Erneute vollständige Frame-Prüfung — 99 Armquellen / 29 Blinkquellen

Vier private native Läufe in Red/Crystal, Classic/Natürlich im Stehen/Laufen, zusätzlich umgekehrte Testreihenfolge. Die erweiterten Treiber prüfen die aktive Kartenquelle und den Bewegungszustand nach dem Zeichnen. Classic hat keinen Natural-Zustand, Natural in allen geprüften Bildern; tatsächliche Gehbewegung belegt. Alle Prozesse Exit 0. In den umgekehrten Läufen hatten 30 Red- und 31 Kris-Blinzelbilder maximal 17,45/17,48 ms. Kein Frame über 25 ms in deren ausgewerteten Fenstern; dies ist keine allgemeine Ruckelfreiheitsfreigabe. Die Normalreihenfolge zeigte weiterhin Idle-Ausreißer bis 64,43 ms bei Red und 44,94 ms bei Kris, überwiegend in Present. Desktoplast nicht isoliert; keine Ursachenbehauptung aus Call-Walltimes. Kein Produktionscode geändert. Raw-CSV, Rollenprüfungen, Analyseskript und Quellhashes: whole-frame-99-review/ im Prüfpaket. Sitz-/Kopfdrehungsabnahme und voller Charakterumfang bleiben offen.

### Kai/Bugsy — 100 Armquellen, 30 Blinkquellen

Exakte v1-Handenden ohne Knieverformung, dezente Gewichtsverlagerung, Beine mit weichem Übergang und abwechselndem Vorder-/Rückenschritt ergänzt. Augen vorn und seitlich blinzeln über den unveränderten Shader. GPU-Galerien und native Gen2-Blinkansicht visuell geprüft; Gen1/Gen2 mit eigenen Arm- und Blinkläufen samt Classic-/HD-aus-/Natürlich-Rückkehr bestanden. Voller Runner bestanden. Keine Rasteränderung, kein Orange. Seitliche Quellkadenz noch offen, keine Arena-Storyprüfung behauptet. Details: bugsy-rig/README.md im Prüfpaket.

### Kai: echtes Arenaobjekt und Dialoggrenze

AZALEA_GYM_obj_1 erhält bei exakt eigenem Script-/Textfenster ruhiges Atmen und Blinzeln im bestehenden Acting-Piloten. Nativer Arena-Dialog besteht mit 2088 Bildern ohne Zustandsverlust, Classic-/HD-Rückkehr und ohne Belebung unbeteiligter Figuren. Echter Kampfbeginn sperrt Dialog-Idle in30 Bildern. Dieser Kampflauf fällt wegen einer bereits in19039d6c fehlenden BattleBillboard.orientation-Funktion auf den nativen Hintergrund zurück; keine 3D-Kampffreigabe daraus ableiten. Voller Runner samt neuer Kampf-/Fremdtext-/Objektslot-Tests bestanden. Details: bugsy-scene/README.md. Keine neue Kopfpose oder Rasteränderung, kein Orange.

### Gen2-Kampfübergang: fehlende Kartenrotation repariert

BattleBillboard.orientation ergänzt: aufrechte Legacy-Ausrichtung bleibt gleich; erhöhte Court-Ansichten richten Karten zur Kamera aus, ohne den Fußpunkt zu verschieben. Geometrietest und voller Human-Motion-Runner bestehen. Echter Kai-Kampf erreicht nach regulärem Dialog das Kampfmenü,120 Bilder mit 3D-Canvas und zwei Karten mit Modell/Textur; kein vorheriger orientation-Kameraabbruch. Visuell geprüft, keine vollständige Kampfrunde/Arena-Freigabe. Drei fehlerhafte Testtreiber-Versuche bleiben dokumentiert. Paket nun57 Laufzeitdateien mit getesteter Rücknahme. Details: battle-card-orientation/README.md. Kein Orange, keine Liveinstallation.

### Seitliche Laufquellen:396 Reihen untersucht

Alle198 Atlasquellen numerisch geprüft; zwei LOVE-Quellgalerien mit sechs Helden/Kai/häufigem NPC visuell verglichen. Hohe Silhouettenähnlichkeit ist nur eine Suchhilfe, keine Fehlerfreigabe. Zwölf Helden-Seitenreihen sind für anatomisch wechselnde Nah-/Fernbeinposen priorisiert. Ein eingebauter image_gen-Versuch wurde verworfen (RGB ohne Alpha, geänderte Atlasgeometrie/übrige Zellen, keine brauchbare Gegenphase). Kein Produktionsasset und kein Runtime-Code geändert. Reproduzierbarer Algorithmus,396-Zeilen-CSV,198 Quellhashes, Galerie, Reparaturanforderung und exakter Prompt: side-gait-source-audit/ im Prüfpaket. Stand100 Arme/30 Blinzeln bleibt; natürlicher seitlicher Lauf weiterhin offen.

### Jens/Morty und Bianka/Whitney — 102 Arm-/32 Blinkquellen

Exakte v1-Handregionen, dezente Gewichtsverlagerung, geprüfte Körperübergänge und abwechselnde Vorder-/Rückenschritte ergänzt. Idle-Augen vorn/seitlich über unveränderten Shader. Automatischer Morty-Augenprobe verwechselt Blondhaar mit Gesicht und wurde manuell korrigiert. GPU-Galerien und native Gen2-Ansichten visuell geprüft; vier native Gen1-/Gen2-Arm-/Blinkläufe samt per-Rolle-Classic-/HD-Rückkehr und voller Runner bestanden. Seitenkadenz und Story-/Dialogfreigaben weiterhin offen. Keine Rasteränderung, kein Orange. Details: morty-whitney/README.md im Prüfpaket.

### Dialog-Idle: alte Fenster nach Bewegung nicht wiederbeleben

Bei beobachteter Bewegung/Scriptbewegung, Entfrieren, Positionswechsel oder fremdem Top-Fenster verfällt jetzt die bisherige Fensterfreigabe. Zurückkehren in denselben Zustand reaktiviert sie nicht; ein neuer Textaufruf des weiterhin validierten VM-Scripts darf eine neue Freigabe erteilen. Unabhängig davon, welcher NPC zuerst geprüft wird. Zwei negative Vorher-Tests reproduzieren die Lücke; endgültiger voller Runner und echter Kai-Dialog mit2188 Bildern bestehen samt Classic/HD-Rückkehr. Keine Erweiterung des NPC-Piloten, keine Grafikänderung. Details: dialogue-window-revocation/README.md im Prüfpaket.

### Alle32 Augenquellen: Körper- und Randkontinuität im GPU-Test

Neuer portabler human_blink_body_runner vergleicht384 echte Rig-/Lid-Ausgaben und14.256.000 Pixel. Alpha, opake Nicht-Augen-RGB und RGB×Alpha an halbtransparenten Rändern bleiben innerhalb1.1/255 gleich; keine zusätzlichen Rig-Mesh-/Composite-Aufbauten beim Augenwechsel. Voller Schluss zeichnet Augen, offene Augen geben Rig-Textur frei. Finaler GPU-Lauf Exit0; anfängliche zu strenge .15-Sichtbarkeitsforderung bei geschütztem Brunos Augenrand als Testfehler dokumentiert. Keine Runtime-Änderung und keine Aussage über Kopf-/Sitzüberlagerungen oder doppelte Draw-Submissions. Details: blink-body-all/README.md.

### Registrierte Drehungen: beobachtete Startansicht

HumanActing übergibt die aktuelle NPC-Ausrichtung an HumanTurn. Neue Übernahmen starten aus einer passenden beobachteten from/to-Ansicht; ohne solche Information direkt im angeforderten Ziel. Spätere Zielwechsel bleiben weich.8 GPU-Erstausgaben von Eich/Blau stimmen mit der jeweiligen Quelle überein; voller Runner, Endpunkt-Blinzeln und echte Gras-/Laborsequenz bis Starterwahl samt Classic/HD-Rückkehr bestehen. Keine Grafik-/Flowänderung und keine pauschale Geisterbild-/Kopfdrehungsfreigabe. Details: turn-initial-view/README.md im Prüfpaket.

### Jasmin/Jasmine —103 Arm-/33 Blinkquellen

Exakte v1-Hand- und Augenregionen ergänzt; Kleid/Zöpfe bleiben im neutralen Oberkörper. Vier-Richtungs-Armgallerie und Augen offen/halb/geschlossen visuell geprüft. Vier native Gen1-/Gen2-Arm-/Blinkläufe samt per-Rolle-Fallback und vollständiger Runner bestehen. GPU-Körperkontinuität jetzt33 Quellen/396 Ausgaben/14.701.500 Pixel. Keine Rasteränderung und keine Leuchtturm-/Arena-Storyfreigabe. Seitliche Beinkadenz bleibt offen. Details: jasmine/README.md im Prüfpaket.

### Sandra und Norbert —105 Arm-/35 Blinkquellen

Exakte Sandra-v2-/Norbert-v1-Handprofile und Augenansichten ergänzt. Sandras Umhang verdeckt die hinteren Arme; dort keine Armverformung, Füße bleiben aktiv. Erster Lidkantenversuch wegen sichtbarer Doppellinie verworfen, normale Kante visuell geprüft. Vier native Gen1-/Gen2-Arm-/Blinkläufe, Fallback pro Rolle, voller Runner und GPU-Körpervergleich35 Quellen/420 Ausgaben/15.592.500 Pixel bestehen. Quellen unverändert. Keine Storyfreigabe; seitliche Kadenz weiterhin offen. Details: clair-pryce/README.md im Prüfpaket.

### Norbert: echter Arena-Dialog und Kampfgrenze

Exakte Freigabe MAHOGANY_GYM/Pryce-v1/index1 ergänzt, nachdem die Vorher-Probe fehlendes Dialog-Idle zeigte. Tatsächliche NPC-Interaktion:2147 Textbilder ohne fehlende Motion, sichtbares Blinzeln/Atmen, keine Zuschauer-/Spielerübertragung, Classic und HD-Rückkehr bestehen. Separater Dialog→Kampf-Lauf beendet die Dialogberechtigung. Voller Runner besteht; Intro zeigt weißen Hintergrund der klassischen Trainerkarte und bleibt optisch offen. Kein Eisrätsel-/Komplettkampf-Test, keine neue Kopfpose. Details: pryce-scene/README.md im Prüfpaket.

### Native Gen2-Trainerfront: weißen Hintergrund in 3D entfernen

Fehlender optionaler nativeCaptureScreen-Adapter in Gen2TrainerArt ergänzt. Nur generierte56×56-Nativfronten: mit dem Bildrand verbundenes deckendes Weiß transparent, eingeschlossene helle Flächen erhalten; Originalscreen/-textur bleiben für Vanilla bestehen. Cache begrenzt8 Quellen, GPU-Zustand/Fallback geprüft. Echter Norbert-Dialog→Kampf und vorher/nachher Sichtprüfung bestehen; weißer Rahmen entfernt. Keine allgemeine Trainerkontur- oder Komplettkampffreigabe. Details: trainer-intro-alpha/README.md.58 Payload-Dateien.

### Rot als NPC:106 Armquellen

NPC-v2 erhält ein exaktes alternatives Profil unabhängig von der Spielerkarte. Vier-Richtungs-Galerie, native Gen1/Gen2-Quell-/Fallback-Prüfung und voller Runner bestehen. Silberberg-Kandidat wegen sichtbarer abgetrennter roter Unterfuß-Komponenten aus Runtime entfernt; genaue Komponentenkoordinaten/Alphas dokumentiert. Keine Raster- oder Augenänderung;35 Blinkquellen. Details: red-npc/README.md im Prüfpaket.

### Rot NPC-v2:36 Augenquellen

Eigenes prozedurales Alternativprofil zur gepackten Spielerkarten-Maske. Erste Kontur wegen Kappenrand-Strichen verworfen; finale Aperturen vorn/rechts halten den Rand unverändert und schließen ohne verbleibenden weißen Augenrand. GPU-Galerie/native Gen2-Sichtprüfung, Gen1/Gen2-Fallback und Körpervergleich36 Quellen/432 Ausgaben/16.038.000 Pixel bestehen. Cachewechsel Spieler/NPC/Spieler nun auch für Red geprüft. Keine Rasteränderung, keine Silberberg- oder Storyfreigabe. Details: red-npc-blink/README.md.

### Gold und Krista als NPC — 108 Arm-/38 Augenquellen

Separate v1-Arm- und Augenprofile für die NPC-Karten ergänzt; Spielerprofile bleiben unabhängig. Vier-Richtungs- und Blinkgalerien sowie native Gen1-/Gen2-Läufe für beide Rollen bestehen einschließlich Bewegung, Öffnen der Augen und Classic-/HD-Rückkehr. GPU-Körpervergleich: 38 Quellen, 456 Ausgaben, 16.929.000 Pixel. Voller Runner bestätigt 108 zugelassene Armquellen und den unveränderten Katalog mit 198 Atlanten. Keine Rasteränderung und keine tatsächliche Linkraum-/Copycat-/Trainerhaus-Freigabe; Seitenkadenz bleibt offen. Details: gold-kris-npc/README.md im Prüfpaket.

### Blau in der Johto-Arena — quellgenaue Strichbereinigung, 109/39

Die exakte Johto-Arenakarte von Blau besitzt jetzt separate Arm- und Augenprofile. Abgetrennte orange Quellpixel unter Front-/Rückfüßen werden ausschließlich im Natural-Sampling entfernt; der Körperanker endet an der geprüften Schuhkante. Die PNG bleibt bytegleich, Classic/HD-aus zeigen den bisherigen Standard. Arm-/Blinkgalerien, native Gen1-/Gen2-Läufe, voller 198-Atlas-Runner, separater Randtest und GPU-Körpervergleich für 39 Quellen/468 Ausgaben/17.374.500 Pixel bestehen.

Die tatsächlichen Gen2-Objekte in der Vertania-Arena und auf der Zinnoberinsel bestehen außerdem mit ihren echten Script-/Textfenstern. Blau dreht den Körper nach unten zum direkt unter ihm stehenden Spieler. Im Dialog bleiben Gehschritt, Armstride und Gewichtsverlagerung aus; Blinzeln und Atmung laufen in 2.383 beziehungsweise 1.448 geprüften Textbildern weiter. Classic beendet Natural sofort, und eine anschließende Rückkehr aktiviert keinen veralteten Dialogzustand. Das ist eine Freigabe der beiden Dialogdarstellungen bis zum aktiven Textfenster, keine vollständige Arena-, Kampf- oder Storyfreigabe. Details: blue-johto-gym/README.md im Prüfpaket.

### Rocket-Agentin, Schwimmerin und Twins — 116 Arm-/45 Augenquellen

Exakte Armprofile für drei Basiskarten sowie je zwei Gen2-Paletten von Schwimmerin und Twins ergänzt. Handschuhe, Gürtel, Badeanzugkanten, Hände und Bündchen bleiben geschützt; die Schwimmerin verwendet richtungsspezifische Übergänge unterhalb des Badeanzugs. Schwimmerin und Twins blinzeln vorn und seitlich auf sechs exakten Quellen. Ein optisch fehlerhafter Rocket-Blinzelkandidat mit großen Hautflächen wurde vollständig entfernt und per Negativtest gesperrt. Arm-/Blinkgalerien, getrennte native Gen1-/Gen2-Läufe, der volle Runner und der GPU-Körpervergleich mit 45 Quellen/540 Ausgaben/20.047.500 Pixel bestehen. Alle sieben Quell-PNGs bleiben bytegleich. Coverage-Liste und 116 Runtime-Pfade stimmen überein; 81 Quellen bleiben offen, eine runtime-seitig abgelehnt. Seitliche Quellkadenz und tatsächliche Storyszenen bleiben offen. Details: female-common/README.md im Prüfpaket.

### Fishing Guru, Sage und Gambler — 123 Arm-/49 Augenquellen

Sieben exakte Armquellen ergänzt: Fishing Guru und Sage Gen2 jeweils als Basis
und zwei Paletten, dazu Gambler. Hände, Ärmel, Kleidung und Accessoires bleiben
in den geprüften Übergängen zusammenhängend. Fishing Guru blinzelt auf drei
exakten Quellen, Gambler auf seiner Basis. Die Augen öffnen bei Bewegung wieder.
Ein Pokéfan-Female-Armkandidat wurde nach Sichtprüfung vollständig entfernt,
weil Korbteile sichtbar mitwanderten und zerfielen; ein Negativtest verhindert
eine versehentliche Zulassung. Sage und Pokéfan erhalten in diesem Schritt kein
Augenprofil, solange ihre Quellgesichter nicht eindeutig beziehungsweise bewusst
für die bereits geschlossenen Augen entworfen sind.

Arm-/Blinkgalerien, native Gen1-/Gen2-Läufe samt Rollen-Fallback, voller Runner
und GPU-Körpervergleich mit 49 Quellen/588 Ausgaben/21.829.500 Pixel bestehen.
Alle sieben Quell-PNGs bleiben bytegleich. Coverage-Liste und Runtime stimmen
mit 123 zugelassenen, 74 offenen und einer runtime-seitig abgelehnten Quelle
überein. Die nativen Läufe verwenden synthetisch eingesetzte Testfiguren; echte
Storyszenen und natürliche seitliche A/B-Quellkadenz bleiben offen. Details:
frequent-residents/README.md im Prüfpaket.

### Neuborkia: beide Frauen sitzen und drehen den Kopf — 123/50

Mutter und Besucherin in PLAYERS_HOUSE_1F verwenden auf ihren echten
Stuhlpositionen ein Laufzeit-Sitzmesh aus den bytegleichen Seitenkarten. Beide
Körper bleiben zum Tisch ausgerichtet; Knie und Füße werden gebogen, der Korb
der Besucherin bleibt außerhalb der Beinverformung zusammenhängend. Im direkt
eigenen Dialog wendet ausschließlich der Kopf zur Frontansicht und wechselt bei
geschlossenem Auge, sodass keine zweite Ganzkörperkarte aufblitzt. Mutter
blinzelt vorn/seitlich; die Besucherin seitlich im Idle und lächelt im Dialog
mit ihren bereits geschlossenen Frontaugen.

Zwei native echte Dialogläufe bestehen einschließlich Classic, HD aus und
Natural-Rückkehr ohne alten Dialogzustand. Natural zeichnet nur 165×225-
Sitzkarten, Classic nur die vollständigen 495×900-Atlanten. Voller Runner und
GPU-Körpervergleich mit 50 Quellen/596 Fällen/22.126.500 Pixel bestehen. Das
neue Pokéfan-Augenprofil ist ausschließlich `seatedOnly`; das verworfene
Armprofil bleibt gesperrt. Andere Sitzmöbel, versetzte Storypositionen und der
allgemeine Restumfang bleiben offen. Details: johto-seats/README.md.

### Häufige Bewohner II — 143 Arm-/59 Augenquellen

Balding Guy, Brunette Girl, Game Boy Kid, Granny, Guitarist Gen2, Middle Aged
Man, Pharmacist Gen2 und Receptionist Gen2 besitzen 20 neue exakte Armquellen
einschließlich alpha-identischer Paletten. Der Gitarrenarm bleibt fest; Haare,
Röcke, Kittel und Taschen werden nicht in den Armschwung gezogen. Getrennte
Rückansichtsschatten bei Apotheker und Rezeptionistin werden ausschließlich im
Natural-Sampling unterhalb der echten Schuhkante entfernt. Original-PNGs,
Classic und HD aus bleiben unverändert.

Game Boy Kid, Middle Aged Man und Receptionist Gen2 blinzeln vorn und seitlich
auf neun exakten Quellen. Galerie, native Gen1-/Gen2-Läufe, Rollen-Fallback,
Variantenregeln, voller Runner und GPU-Körpervergleich mit 59 Quellen, 704
Fällen und 26.136.000 Pixel bestehen. Brillen und stark haarverdeckte Augen
wurden nicht pauschal freigegeben. Die nativen Figuren sind synthetisch in
privaten Innenräumen eingesetzt; tatsächliche Storyszenen bleiben offen.
Details: remaining-common/README.md.

### Häufig genutzte Bewohner — 149 Arm-/65 Augenquellen

Link Receptionist, Channeler, Psychic, Silph Worker Male, Picnicker Gen2 und
Little Girl besitzen exakte v1-Armprofile. Alle sechs blinzeln vorn und in
beiden Seitenansichten; die Rückansicht bleibt quellgetreu. Haare, Hüte,
Taschen, Röcke und Jacken bleiben in der Vier-Richtungs-Abnahme
zusammenhängend. Es wurden keine Quell-PNGs verändert.

Galerie, native Gen1-/Gen2-Läufe, Bewegung öffnet die Augen, Rollen-Fallback,
voller Runner und GPU-Körpervergleich mit 65 Quellen, 776 Fällen und
28.809.000 Pixeln bestehen. Das Inventar enthält jetzt 149 geprüfte, 48 offene
und eine runtime-seitig abgelehnte Quelle. Die Figuren wurden für diesen Block
synthetisch in privaten Innenräumen eingesetzt; tatsächliche Storyskripte und
die natürliche seitliche Quellkadenz bleiben offen. Details:
high-usage-residents/README.md im Prüfpaket.
