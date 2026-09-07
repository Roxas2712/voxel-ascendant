# Ascendant Pokémon Overworld 0.4.0-rc.32

Eigenständige Overworld-Mod für **Pokémon Rot/Blau/Gelb und
Gold/Silber/Kristall** auf Gen1Recomp. Sie stellt einen frei wählbaren,
animierten Party-Begleiter und GO-HD-Laufatlanten für **#001–411**
bereit und veröffentlicht einen gemeinsamen Charakter-Provider für die
Basisfiguren sowie öffentlich gemeldete KASC-, JASC- und VASC-Charaktere.

Das Projekt ist eine eigenständige Implementierung. Das Repository
`porygonal-overworld-characters` diente nur als Funktionsreferenz; sein
Quellcode und seine nicht frei veröffentlichten Produktionsmodelle wurden
nicht übernommen.

## RC32: Kanto-Animationskarten, Integrationsstand

- Alle 151 Kanto-Arten haben getrennte GO-Idle- und Lauf-/Flugkarten aus geprüften
  Original-Bewegungsclips.
  Das sind 304 Normal-/Shiny-Einträge; Pikachu enthält zusätzlich
  den originalen männlichen und weiblichen Schwanz. Nicht geprüfte explizite
  Geschlechtsvarianten behalten ihre bisherige korrekte Quelle.
- Je Zustand gibt es acht, bei ausgewählten schnellen Bewegungen sechzehn
  zeitlich verteilte Posen in vier Richtungen.
  Körperteile bewegen sich durch die Original-Skelettanimation, nicht durch
  Wackeln einer starren Gesamtkarte. Original-Clipzeiten, gemeinsamer Maßstab
  und Bodenanker bleiben erhalten. Auch Stadt-, Wild- und Innenraum-Pokémon
  nutzen diese Karten, wenn für ihren Kontext GO gewählt ist.
- Gluraks Körpergröße und Flug wurden im Spiel vom Nutzer abgenommen. Für die
  151 aufgenommenen Kanto-Arten wurden Normal und Shiny zusätzlich im echten
  Spiel als Begleiter auf durchlaufende Idle-/Bewegungsphasen geprüft.
  Das ist keine pauschale visuelle Freigabe jedes Blickwinkels, jeder Karte,
  aller Einstellungen oder aller 411 Arten.
- Optionaler Kartenstil: **Original / Feine Kontur / Anime dezent / Comic Kontur**.
  Anime kombiniert eine dünne dunkle Außenlinie mit sanften
  Helligkeitsstufen; die Eigenfarben bleiben erhalten. Dies ist ein
  Karten-Shader, kein neu hinzugefügtes dreidimensionales Modell. Der Stil
  ist standardmäßig aus, greift nur auf glatten GO-Karten und verändert
  weder PokeMMO, das Würfelraster noch das bereits abgenommene Feurigel.
  Bei aktivem Stil werden neutrale Kartenfarben verwendet; der vorherige
  Szenen-Shaderzustand wird danach wiederhergestellt.
- **Comic Kontur** ist ein zusätzlicher Opt-in: dunklere, etwas kräftigere
  Außenlinie und klarere Schattenstufen. Die RGB-Verhältnisse und damit
  Farbton/Sättigung bleiben erhalten; es wird kein Weiß beigemischt.
  Glurak und Pikachu wurden damit in Normal/Shiny live angesehen.
  Körperform, Größe und Animation ändern sich nicht. Der Effekt erzeugt
  keine Chibi-Proportionen und rekonstruiert keine 3D-Lichtnormalen.
- **PIKACHU AUF KOPF**, standardmäßig aus: gelegentliche visuelle Einlage bei
  aktiven HD-Menschen und animiertem GO-HD-Pikachu. Nach 24–42 Sekunden
  geeigneter Overworld-Zeit springt es hoch, bleibt etwa drei Sekunden und
  springt zurück. Abbruch bei Menüs/Dialogen, Kartenwechsel, Teleport,
  Radfahren, Surfen oder deaktivierten HD-Animationen. Nur Darstellung;
  Kollisions- und Bewegungskoordinaten bleiben beim Besitzer. Die gewählte
  Charakteridentität und Pokémon-Größe werden nicht verändert. Kein neuer
  Sitz-Clip: die vorhandene Idle-Animation läuft während des Tragens weiter.
- Neue Animationsatlanten werden beim Packen weder verkleinert noch erneut
  farbkorrigiert. Nur gerade benötigte Kartenpaare werden geladen. Die
  bisherigen Basiskarten bleiben als Lade-Fallback erhalten. Große Modelle,
  Einzelbilder und Arbeitsdateien kommen nicht ins ZIP.
- Halbtransparente Flügel/Rauch werden in getrennten Alpha-Durchgängen
  gezeichnet. Taubsi, Zubat, Golbat, Nebulak, Garados und Dratini haben
  gezielt überprüfte Körpermaße; Flügel, Rauch und lange Schwänze bestimmen
  nicht die Körperhöhe. Normal und Shiny verwenden dieselben Größen.
- Die sechs vorhandenen Hauptfiguren sind für Fahrrad, Absteigen, Angeln
  und Gehen unter KASC beziehungsweise JASC geprüft. Es gibt keine neu
  gezeichneten Surf-Karten; dafür bleibt die originale Besitzer-Pose erhalten.
- RC30 und das abgenommene Feurigel bleiben als Rückfall erhalten. Gebaut
  wird ausschließlich **Ascendant Pokémon Overworld**, nicht VASC/KASC/JASC.

## RC30: Feurigel-Farb- und Feuerkarten

- Für Feurigel sind neue GO-Karten für Normal/Shiny × Feuer an/aus enthalten.
  Die Körperfarbe verwendet die vollständige Original-Materialbeleuchtung;
  vorhandene Original-Feuerteile werden in ausgefahrener Stellung gerendert.
- Die Karten behalten einen gemeinsamen Maßstab und Fußanker. Im Stand
  wechselt Feuer ruhig an/aus; beim Gehen bleibt es an. Das ist eine
  komponierte APO-Präsentationsanimation aus Körperposen und Original-
  Feuerteilen, kein unverändert übernommener vollständiger GO-Laufclip.
- Explizit gewählte PokeMMO-Karten bleiben PokeMMO. Nur die geprüften
  GO-Feurigel-Varianten verwenden die neuen Feuerkarten. Fehlt eine Hälfte
  des Paars, bleibt die fehlerhafte alte GO-Quelle gesperrt.
- Die vier Zusatzatlanten und zwei nativen Streifen benötigen zusammen
  weniger als 1 MB. Andere Arten und die ursprünglichen GO-Lieferungen
  werden dadurch nicht umgeschrieben. Der Import verändert VASC/KASC/JASC nicht.
- Dies ist **keine globale visuelle Freigabe aller 411 Arten**. Quellenfehler
  und fehlende bzw. unzureichende Bewegungen bleiben im Sichtprüfbericht
  dokumentiert. Live-Abnahme wird separat protokolliert.

## Quellen- und Eigentumsgrenzen (seit RC29)

- Feurigels gelieferte GO-Karten enthalten keine korrekt gerenderte
  Flammenlage. Ohne das vollständige neue Kartenpaar verwendet Dex 155
  deshalb die animierten PokeMMO-Karten, auch bei `GO ONLY`.
  Das gilt für Normal und Shiny in allen Pokémon-Kontexten. Das Sitzungslog
  nennt dafür `invalid_go_asset_fallback_pokemmo`; die fehlerhaften
  Quellatlanten bleiben zur Diagnose erhalten.
- Nach einem Renderer-Neuaufbau durch den Follower- oder Stadt-Pokémon-
  Provider verbindet APO die gewählte Karte erneut mit dem tatsächlich
  verwendeten Renderer. Die Quellenmeldung bestätigt erst danach die Bindung.
- Die in APO paketierten und bei aktiver GO-Quelle gezeichneten
  hochauflösenden Pokémon sind die **GO-HD-Renderkarten** dieser Mod. Es
  handelt sich um aus dem gelieferten Pokémon-GO-Material erzeugte
  transparente Laufatlanten, nicht um Pokémon-Stadium- oder Pokémon-Stadium-
  2-Modelle. Eine Stadium-2-Darstellung kann ausschließlich als davon
  getrennte, öffentlich gemeldete VASC-Quelle ausgewählt werden.
- GO-HD-Atlanten werden in VASCs schräger 3D-Kamera linear und mit
  anisotroper Filterung abgetastet. Das verhindert grobe Pixelstufen, ohne
  die Quelldateien oder die PokeMMO-Pixelsprites umzubauen.
- Bei ausgeschalteten `ATMOSPHÄRISCHEN FIGUREN` läuft der Figurendurchgang mit
  neutralem Weiß-Tint; der zuvor aktive VASC-Shaderzustand wird danach exakt
  wiederhergestellt. Nur die kompakten GO-Kopien im Releasepaket erhalten
  zusätzlich eine konservative Farb-, Kontrast- und Helligkeitskorrektur.
  Die eingecheckten Quellatlanten und ihre Alphakanäle bleiben unverändert.
- Flugfähige Pokémon mit dem Profil `airborne-wing-flap-v1` erhalten im Stand
  und beim Nachziehen einen sichtbaren Schwebezustand und durchlaufen ihre
  vorhandenen A/B-Flügelposen. Das animiert die gelieferten Renderkarten;
  es behauptet kein nachträglich erzeugtes 3D-Skelett.
- VASCs generischer Follower-Akteur darf seine technische Kennung
  `WILDS_FOLLOWER_MON` behalten. Für die Darstellung wertet APO nun die
  konkrete Party-Referenz sowie veröffentlichte Spezies- und Nationaldex-
  Metadaten aus und reicht die aufgelöste Identität an Karte, Bewegung,
  Skalierung und Diagnose weiter.
- KASC beziehungsweise JASC bleibt Eigentümer der gewählten Spieleridentität.
  APO kennzeichnet nur seinen ausgetauschten Laufatlas separat über
  `ascendantWalkingSpriteOwner`; `ascendantCharacterOwner` wird nicht mehr
  von APO übernommen. Damit bleiben insbesondere Casey/Grün in Gen 1 sowie
  Kris beziehungsweise Ethan in Gen 2 unter ihrem richtigen Provider.
- RC29 wird ausschließlich als eigenständiges
  `Ascendant-Pokemon-Overworld`-Paket gebaut. Die Projekte und Dateien von
  VASC, KASC und JASC gehören nicht zu diesem Paket und werden von seinem
  Build nicht verändert.

## Aktueller Funktionsumfang

- Gen 1: Rot, Blau und Gelb.
- Gen 2: Gold, Silber und Kristall über die öffentliche Gen2Compat-Schicht.
- Pokémon #001–251, normal und schillernd, jeweils an Land und untergetaucht.
- Der bestehende GO-HD-Fallbackbestand reicht bis #411. Außerhalb der neu
  aufgenommenen Kanto-Animationen ist dies keine pauschale Qualitäts- oder
  Originalanimationsfreigabe. Fehlt dort eine exakte Shiny-Variante, kann der
  bisherige Fallback die normale HD-Variante liefern; dieser Restbestand wird
  nicht als neue geprüfte Shiny-Animation ausgegeben.
- Auswahl des Begleiters über das Party-Untermenü `FOLGEN` / `FOLLOWER`.
- Standalone-Betrieb ohne KASC, JASC oder VASC.
- Saubere Ein-Eigentümer-Regel: Eine vorhandene KASC-/JASC-/Follower-Mod
  bleibt zuständig; diese Mod registriert dann keinen zweiten Begleiter. Hat
  KASC/JASC einen öffentlichen Follower-Sprite-Resolver, wird dieser reversibel
  mit den HD-Atlanten beliefert und fällt bei `AUS` auf seine eigenen Grafiken
  zurück. Die Identität bleibt beim Provider; nur der von APO gelieferte Atlas
  trägt APO als Laufgrafik-Eigentümer.
- KASC-Figuren (einschließlich Rot, Blau und Grün) und JASC-Figuren
  (Gold, Kris und Silber) werden aus ihren **öffentlichen** Providern gelesen.
- Die Spielerautorität ist strikt nach Generation getrennt: In Gen 1 kann JASC
  Rot niemals durch Kris ersetzen; in Gen 2 kann KASC Gold/Kris/Silber niemals
  durch eine Kanto-Auswahl überschreiben.
- Der Voxel-Renderer trifft keine zweite Charakterauswahl mehr und liest dafür
  insbesondere keinen editionsübergreifend gespeicherten `preview_character`-
  Wert. Damit kann ein alter Kris-Vorschaustand Rot in Gen 1 nicht überschreiben.
- Wenn KASC/JASC den Renderer einer bekannten Hauptfigur nach einem Kartenereignis
  neu erstellt, verbindet VASC dessen generationsspezifische Sprite-ID erneut
  mit dem festen freigegebenen HD-Atlas. Dadurch erscheint der Spieler nicht
  als riesig hochskalierter 16x16-Laufstreifen. Unbekannte NPCs bleiben davon
  ausdrücklich ausgeschlossen und verwenden weiterhin flaches Vanilla-2D.
- Mit `HD-MENSCHEN` werden alle verfügbaren freigegebenen menschlichen
  4x3-Walker instanzgenau eingebunden. Blau ersetzt dabei auch den normalen Rivalen;
  KASC-Spieler-, Rivalen- und Drittrollen folgen der jeweils aktiven
  KASC-Identität. `AUS` setzt jede lebende Figur auf genau ihren zuvor aktiven
  Vanilla-/Provider-Renderer zurück.
- Gen 2 erhält zusätzlich 62 alpha- und posengleiche Farbvarianten für 31
  häufig wiederkehrende NPC-Klassen. Die Auswahl ist pro Kartenobjekt stabil;
  direkte Wiederholungen derselben Klasse werden auf einer Karte rotiert.
- `FIGUREN-VOXELRASTER` ist kein aufgemaltes Linienmuster: belegte Bereiche
  der transparenten Figur werden in getrennte flache 3D-Würfel mit dunklen
  Fugen zerlegt. Menschen und Pokémon bleiben separat schaltbar.
- In Gen 1 werden Youngster und Käfersammler trotz ihrer gemeinsam benutzten
  Cartridge-Sprite-ID anhand der konkreten Karten-/Trainerzeile getrennt. Der
  Youngster besitzt drei glatzköpfige Kleidungspaletten, der Käfersammler seine
  eigene Basis plus zwei Kleidungspaletten. Ist die Klasse nicht eindeutig,
  bleibt die originale 2D-Figur statt einer falschen HD-Identität sichtbar.
- Dynamisch von KASC/JASC erzeugte Personen erhalten dieselbe Zuordnung über
  ihre veröffentlichte Spriteklasse, auch wenn sie keine feste Vanilla-
  Kartenkoordinate besitzen. Fehlt ein freigegebener HD-Atlas, bleibt bewusst
  die originale flache 2D-Sprite sichtbar; es wird kein humanoider 3D-Ersatz
  synthetisiert. Der Gen-1-Youngster ist bewusst von der HD-Ersetzung
  ausgeschlossen und behält damit seine Vanilla-Glatze; das stilfremde
  Käfersammler-Testbild wird nicht verwendet.
- Rot, Blau, Grün, Gold, Kris und Silber besitzen jeweils produktive,
  transparente 3x4-Atlanten für Fahrrad und Angeln. Sie werden über
  `mod.exports.characterActions` veröffentlicht; die Aktionsauslösung und
  Zeitsteuerung bleibt Eigentum des Spiels beziehungsweise Charakter-Providers.
- Die menschlichen R/B/Y- und G/S/C-Kartenobjekte sind instanzgenau
  inventarisiert: 719 Gen-1- und 1.123 Gen-2-Instanzen verweisen auf 126
  paketierte, transparente Produktionsatlanten unter
  `assets/characters/npcs/`. Der öffentliche Zugriff erfolgt über
  `mod.exports.npcCatalog`; der reproduzierbare Bericht steht in
  `production/NPC-COVERAGE.md`.
- Von den 126 NPC-Atlanten und fünf Hauptfiguren-Atlanten sind in Gen 1 derzeit
  130 freigegebene Laufzeit-Atlanten aktiv; nur der Youngster fällt dort bis
  zu einer passenden Glatzen-Neufassung auf Vanilla zurück. VASC erhält
  für aktive HD-Figuren parallel immer den
  vollständigen transparenten 4x3-HD-Atlas mit allen vier Kardinalrichtungen
  und allen drei Laufphasen.
- Die 822 Pokémon-Atlanten werden parallel in native 16x96-Laufstreifen
  übersetzt. In VASC werden stattdessen alle zwölf gelieferten HD-Zellen
  verwendet. Die Größenklasse folgt der metrischen Gold-Pokédexhöhe:
  bis 0,7 m klein, bis 1,4 m mittel, darüber groß. Verbindliche sichtbare
  Zielhöhen sind nach dem freigegebenen Overworld-Faktor 1,35 genau
  **9,45 / 15,525 / 21,6 Welteinheiten**. Sowohl VASC als auch der native
  Wilds-/SpriteRenderer verwenden dieselbe Tabelle und verankern die Füße
  beziehungsweise Pfoten weiterhin an der Bodenlinie. Dummisel ist bewusst
  artbezogen als klein eingestuft, weil seine Pokédex-Angabe die Körperlänge
  statt einer aufrechten Höhe beschreibt.
- Die Pokémon-Darstellung ist nach Einsatzort getrennt live schaltbar:
  `HD-BEGLEITER`, `HD-WILDE MONS`, `HD-STADT-MONS` und `HD-WILDS-ORTE`.
  Sie ersetzt nur die Grafik bereits vorhandener Entitäten. Wilds/KASC/JASC
  behalten Spawn, Auswahl, Bewegung, Kampf und Besitz. Bei Abschaltung fällt
  jeder Bereich auf genau seinen bisherigen Vanilla-/Provider-Look zurück.
- `DYNAMISCHER BEGLEITERABSTAND` vergrößert ausschließlich den sichtbaren
  Abstand entlang der wirklich gelaufenen, begehbaren Spur. Die
  größenabhängigen Mindestabstände der Mittelpunkte sind klein 24, mittel 32
  und groß 42 Pixel; mehrere Begleiter werden hintereinander auf derselben
  Spur angeordnet. An Ecken wird nicht geradlinig durch Zäune oder Wände
  verlängert. Ist nach Spawn oder Kartenwechsel noch nicht genug Verlauf
  vorhanden, bleibt ein Begleiter auf seiner gültigen logischen Zelle und
  nimmt den vollen Abstand mit den nächsten Schritten ein. Logische Zelle,
  Wegfindung und Kollision bleiben unverändert.
- `LEBENDIGE BEGLEITER` ergänzt eine dezente Atembewegung, verwendet beim
  sichtbaren Nachziehen sicher die A/B-Laufphasen und lässt Pokémon mit klar
  sichtbaren Flügeln ihre vorhandenen A/B-Flügelposen langsam auch im Stand
  nutzen. Das Flugprofil hält sie dabei erkennbar über der Bodenlinie und
  ergänzt eine ruhige Schwebewegung. Pikachu besitzt für Normal und Shiny
  einen source-exakten Closed-Eye-Sidecar; alle anderen Varianten nutzen nur
  Atem-/Idle-Bewegung.
  Augen und Lider werden niemals synthetisch erzeugt.
- `ATMOSPHÄRISCHE FIGUREN` bindet ausschließlich die neuen HD-Menschen und
  HD-Pokémon mit einer wärmeren, kontrastreicheren Lichtmodulation in VASCs
  vorhandene Sonnen-, Schatten-, Wetter- und Tageszeitbeleuchtung ein. `AUS`
  entfernt den zusätzlichen Tageszeit-Tint aus dem Figurendurchgang und zeigt
  die neutralen Paketfarben; danach wird VASCs vorheriger Shaderzustand
  vollständig wiederhergestellt.
- `FIGUREN-VOXEL-FINISH` und `POKEMON-VOXEL-FINISH` schalten die leicht
  facettierten, beleuchteten VASC-Reliefs für Menschen und Pokémon getrennt.
  Ohne VASC bleiben beide wirkungslos und die native 2D-Darstellung stabil.
- `POKEMON-MODELLQUELLE` bietet `AUTO`, `NUR POKÉMON STADIUM 2`,
  `GO-HD-RENDERKARTEN ZUERST`, `NUR GO-HD-RENDERKARTEN` und `NUR 2D-SPRITES`.
  Mit **Pokémon Stadium 2** ist ausschließlich VASCs konkrete
  Pokémon-Stadium-2-Quelle gemeint; die vom Nutzer gelieferten
  **GO-HD-Renderkarten**, die in den Overworld-Szenen als hochauflösende
  Pokémon sichtbar sind, sind eine davon unabhängige Pokémon-GO-Quelle.
  `AUTO` verwendet für #001–251 gemäß der gewünschten Priorität zuerst
  Pokémon Stadium 2, danach die GO-HD-Renderkarte und zuletzt die normale
  2D-Sprite. Die Auswahl wird von dieser eigenständigen Mod verwaltet; keine
  Voxel-Ascendant-Datei wird dafür geändert.
- `FIGUREN-VOXELRASTER` ist unabhängig vom Relief-Finish und lässt sich auf
  Menschen, Pokémon, beide oder niemanden anwenden. Das Raster bleibt an der
  jeweiligen Figur verankert und verändert weder VASCs Terrain- noch
  Kampfraster.
- Eine explizite Auswahl der GO-HD-Renderkarten oder der
  `POKEMMO PIXEL-ANIMIERT`-Quelle unterdrückt an der betreffenden Entität den
  zusätzlichen Pokémon-Stadium-2-Körper von VASC, sobald die konkrete Karte
  samt Spezies-/Dex-Identität tatsächlich aufgelöst wurde. Dadurch erscheinen
  nie zugleich die gewählte Karte und das Stadium-2-Modell; bei noch fehlender
  Identität bleibt der bisherige Providerkörper erhalten, statt unsichtbar zu
  werden. Ausgeschaltete Bereiche bleiben vollständig bei der Darstellung
  ihres bisherigen Besitzers oder Providers.
- Vorbereiteter `ascendant.card/v1`-Descriptor für Pokémon und Charaktere.

Der Charakter-Provider übernimmt keine fremde Story-, Bewegungs- oder
Auswahllogik. Er ersetzt ausschließlich den lokalen Renderer einer bereits
vom Spiel beziehungsweise KASC/JASC erzeugten Figur. Ein vorhandener
`red_3d_player`-Provider bleibt für seine echten Spielermodelle zuständig.

## Installation

1. Gen1Recomp **0.2.24 oder neuer, aber vor 0.3.0** verwenden.
2. Nur ein ausdrücklich freigegebenes APO-Paket über den Mod-Manager installieren.
   Das große versiegelte Übergabe-ZIP ist Arbeitsmaterial für die abgestimmte
   Aufteilung, keine Empfehlung für den bereits speicherknappen Vollimport.
3. Die Mod aktivieren und Rot/Blau/Gelb oder Gold/Silber/Kristall starten.
4. Im Party-Menü ein gesundes Pokémon auswählen und `FOLGEN` wählen.
5. Unter den Mod-Optionen Menschen, Begleiter, wilde Pokémon, feste
   Stadt-Pokémon und Wilds-Stadt-Pokémon getrennt einstellen. Die beiden
   Voxel-Finish-Schalter, atmosphärische Figurenbeleuchtung und der dynamische
   Begleiterabstand, die lebendigen Pokémon und die Pokémon-Kollision sind
   ebenfalls unabhängig. Die Wirkung hängt vom jeweiligen Besitzer und Renderer
   ab; geschützte Story-/Wilds-Akteure werden nicht übergangen.

Für Begleiter, Gras/Höhlen, Stadt/Innenräume und friedliche Wilds-Orte lässt
sich die Spritequelle jeweils unabhängig zwischen `ASCENDANT HD` und
`POKEMMO PIXEL-ANIMIERT` wechseln. Die PokeMMO-Quelle
enthält für Nationaldex #001–251 Normal-/Shiny-, Geschlechts- und Formvarianten.
Fehlt eine konkrete PokeMMO-Variante, verwendet die Mod automatisch das
zugehörige Ascendant-HD-Sheet. Der Quellenwechsel ändert niemals die zentrale
Größenklasse des Pokémon.

`MON-KOLLISION`: `NORMAL` übernimmt die Kollision des Besitzers. `FREI` macht
eindeutig erkannte Begleiter und kompatible Stadt-/Haus-Pokémon durchlaufbar.
Geschützte Wilds-/Ambient-/Story-Akteure behalten ihre Originalregeln, damit
Durchlaufen nicht versehentlich als Despawn-Befehl wirkt. Menschen, Trainer
und Grasbegegnungen werden nicht geändert.

Eine gespeicherte `WEICH`-Auswahl bleibt erhalten, ist ohne explizite
Besitzer-Schnittstelle jedoch als `WEICH: GESPERRT` sichtbar und blockiert weiter.
Sie wird nicht neu angeboten und nicht still auf einen anderen Wert umgestellt.
Die gewünschte einmalige Blockierung ist ohne diese Schnittstelle nicht verfügbar.
Für die native Gen-1-Begleiterkollision wird `FREI` nach dem Besitzer-Update
erneut gesetzt; Story-/Sprungzustände bleiben ausgenommen. Der zusätzliche
VASC-Fix gegen Herausschieben aus überlappenden Kollisionskörpern gehört VASC
und muss dort eingebaut sein; APO enthält oder verändert diese Datei nicht.

Die Mod schreibt ausschließlich die ausgewählte Party-Identität und den Slot
in ihren eigenen Save-Namespace `ascendant_pokemon_overworld`. Alte Spielstände
werden nicht migriert oder verändert.

## Kompatibilität

Die Ladepriorität 140 liegt nach den aktuellen VASC-, KASC- und JASC-
Providern. Optional erkannte IDs stehen in `manifest.json`. Fehlt ein
optionaler Provider, bleibt der Standalone-Betrieb aktiv. Die Diagnose ist
unter `mod.exports.runtime.health()` und der Charakterkatalog unter
`mod.exports.characters` verfügbar. Der Laufzeitstatus der Ersetzungen steht
unter `mod.exports.walkingSprites.health()` und
`mod.exports.pokemonWorldSprites.health()`. Der Abstand ist unter
`mod.exports.followerSpacing.health()` und die Kollisionspolitik unter
`mod.exports.pokemonCollision.health()` prüfbar.

Die Card wird noch nicht zur Laufzeit in VASC registriert: VASC 3.0 stellt
seinen externen Card-Host absichtlich nur lesbar bereit. Die spätere Einbindung
benötigt daher nur den offiziellen externen Registrierungspunkt, keinen Umbau
dieser Runtime. Details stehen in `docs/CARD_INTEGRATION_DE.md`.

## Veröffentlichungshinweis

Der Lua-Code dieses Projekts steht unter MIT. Die enthaltenen Community-
Followergrafiken sind davon ausgenommen und vorerst nur für die lokale/private
Verwendung vorgesehen. Vor einer öffentlichen Weitergabe müssen die Rechte
der einzelnen Art-Quellen geklärt werden; siehe `THIRD_PARTY_NOTICES.md`.
