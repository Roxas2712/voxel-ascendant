VOXEL ASCENDANT 2.0.12 - SPRITES LOKAL ERSETZEN (DEUTSCH)
=======================================================

VASC liefert keine Austausch-Sprites aus. Es stellt nur eine lokale,
fehlertolerante Schnittstelle bereit: Eine gueltige Datei kann den letzten von
Spiel/KASC gewaehlten Sprite ersetzen. Fehlt sie, ist sie ungueltig, deaktiviert
oder geloescht, wird automatisch wieder der Original-/KASC-Sprite verwendet.

SCHNELLSTART
------------
1. Spiel vor dem Kopieren oder Umbenennen schliessen.
2. Den installierten VASC-Ordner und dort user/sprites/ oeffnen.
3. Jede PNG exakt benennen und in den passenden Unterordner kopieren.
4. Spiel starten: VASC -> USER SPRITES -> RESCAN PNG FILES.
5. CUSTOM SPRITES einschalten.
6. README + INDEX zeigt IDs des aktuell geladenen Spiels, von KASC und von
   anderen kompatiblen Mods.

Akzeptiert werden echte PNG-Dateien von 1x1 bis 4096x4096 Pixeln. Nutze eine
transparente Flaeche und dieselbe Fuss-/Grundlinie wie beim ersetzten Sprite.
VASC baut die Grafik nicht um. Bei animierten Oberwelt-Sheets muessen Groesse,
Frame-Raster, Richtungsreihenfolge und transparente Raender dem Original
entsprechen, sonst werden Bewegungsbilder abgeschnitten oder verschoben.

CANVAS, GROESSE UND BODENANKER
------------------------------
Es gibt absichtlich keine allgemeine 16x16- oder 32x32-Pflicht. Uebernimm
Canvas-Groesse und transparente Raender exakt von der finalen Spiel-/KASC-
Grafik, die ersetzt wird. Ein Crystal-HD-Trainer darf daher deutlich groesser
sein als ein nativer Gen-I-Trainer; beide sind gueltig.

Fuer Kampf-Front- und Rueckenbilder gilt:
- alle sichtbaren Pixel muessen innerhalb des PNG-Canvas liegen;
- transparenten Freiraum oberhalb der Figur lassen, nicht unter den Fuessen;
- beide Fuesse/tiefsten Kontaktpixel auf eine klare letzte sichtbare Zeile;
- keinen Boden, Schlagschatten, weissen Hintergrund oder Vorab-Skew malen;
- Front und Rueckenbild in glaubwuerdiger gemeinsamer Groesse halten.

VASC misst die sichtbaren Alpha-Grenzen, behaelt die physische Quellgroesse und
setzt die tiefste sichtbare Zeile auf den geprueften Kampfboden. So versinken
native, Retro- und KASC-HD-Grafiken weder auf MAP-Terrain noch in ARENA-Bildern
oder DISCS. Bei sehr grossen Pokemon darf die MAP-/DISCS-Kamera auf 1X fuer
diesen Kampf etwas weiter werden, damit die komplette Silhouette sichtbar
bleibt; die gespeicherte Kamerawahl wird nicht veraendert.

POKEMON
-------
Kampf-, Dex-, Team-Icon- und Oberwelt-Ziele nutzen kanonische Grossbuchstaben:
  pokemon/front/PIKACHU.png
  pokemon/back/PIKACHU.png
  pokemon/dex/PIKACHU.png
  pokemon/icons/PIKACHU.png
  pokemon/overworld/PIKACHU.png

Formen werden vor der Basisart geprueft. Beispiele:
  pokemon/front/CHARIZARD_MEGA_X.png
  pokemon/front/CHARIZARD_MEGA_Y.png
  pokemon/front/MEWTWO_MEGA_Y.png
  pokemon/front/VENUSAUR_MEGA.png
  pokemon/front/PIKACHU_SHINY.png
  pokemon/front/UNOWN_A.png

KASC kann intern CHARIZARD als Art behalten und CHARIZARD_X nur im Live-Zustand
melden. VASC prueft dann CHARIZARD_MEGA_X, danach CHARIZARD_X und zuletzt
CHARIZARD. Megas mit einer Form nutzen <SPECIES>_MEGA. Shiny-Dateien werden als
<FORM>_SHINY vor der normalen Form gesucht. So bleibt die Basisdatei die sichere
Rueckfallebene fuer fehlende Sonderformen.

SPIELER UND TRAINER IM KAMPF
----------------------------
Spielerpositionen:
  player/battle_front.png
  player/battle_back.png
Allgemeine Rueckfaelle:
  player/front.png
  player/back.png

Gegnerische Trainerportraets nutzen ihre kanonische Klassen-ID:
  trainers/OPP_RIVAL2.png
  trainers/OPP_BROCK.png
  trainers/OPP_ROCKET.png
  trainers/OPP_LORELEI.png
  trainers/OPP_BRUNO.png
  trainers/OPP_AGATHA.png
  trainers/OPP_LANCE.png

ROT, BLAU, GRUEN, RIVALEN UND KASC-GRAFIKEN
-------------------------------------------
VASC fragt zuerst Spiel und optionale Mods nach ihrer final ausgewaehlten
Grafik. Ohne lokale Ersetzung behalten Rot, Blau, Gruen, Rivalen, normale
Trainer und die Top Vier deshalb ihre native oder von KASC gewaehlte Grafik.
VASC kopiert keinen KASC-Code und benoetigt KASC nicht.

POSITION UND GROESSE DIREKT IN VASC SPEICHERN
---------------------------------------------
Oeffne VOXEL ASCENDANT -> BATTLE -> BATTLE LAYOUT. Das ist eine normale
VASC-Laufzeitfunktion; der getrennte Desktop-Layouteditor ist optional. Zuerst
TARGET waehlen, danach X, Y und SIZE einstellen. Eigene Speicherziele gibt es
fuer Spieler-Front, moderne Spieler-Rueckseite, alte halbe Rueckseite, Mega,
Gegner-Pokemon, Spieler-Trainer vorne/hinten, Gegner-Trainer, beide Statusfelder,
beide Teamreihen sowie Befehls- und Textbereich. RESET ONE setzt nur das
gewaehlte Ziel zurueck. RESET ALL stellt die gepruefte Automatik mit
0 / 0 / 100% fuer alle Ziele wieder her.

Die Werte greifen erst nach der Auswahl des finalen Sprite-Anbieters. Sie
veraendern keine PNG und niemals eine KASC-Option oder -Datei. Fuer kleine
persoenliche Korrekturen sind sie geeignet; bei der Pruefung von transparentem
Canvas und Fusslinie sollten zunaechst die Standardwerte verwendet werden.

Die beiden player/-Dateien oben sind globale Ersetzungen der finalen
Spielergrafik. Sie sind kein Rot/Blau/Gruen-Waehler: player/battle_front.png
ersetzt die vom aktuellen Spiel-/KASC-Aufbau ausgewaehlte Spielerfigur.
Gegner lassen sich einzeln ueber trainers/<KLASSEN_ID>.png ersetzen.

Zur Abnahme jeden wichtigen Trainer in allen aktiven Kampfarten ansehen:
  MAP   - Fuesse auf begehbarem Terrain, vollstaendige Figur.
  DISCS - Fuesse auf der projizierten Disk, nie auf der Hintergrundfarbe.
  ARENA - Fuesse auf der komponierten Vordergrundlinie, nichts abgeschnitten.

TRAINER BACK einmal OFF und ON pruefen. OFF stellt die finale Frontgrafik in
die 3D-Szene; ON stellt den echten klassischen Wurf-Rueckensprite auf denselben
geprueften 3D-Spieler-Bodenanker. Er bleibt dadurch vom Gegner getrennt und
kann ihn in ARENA/Hochformat nicht mehr verdecken. Das sind
Darstellungsoptionen, keine anderen Dateiformate.

POKEMON-FRONT/RUECKEN UND MEGA-FORMEN
-------------------------------------
Jedes eigene Kampf-Pokemon in beiden Darstellungen pruefen:
- PKMN BACK OFF: Beide Pokemon stehen auf geprueften Welt-/Arena-/Disk-Ankern.
- PKMN BACK ON: Das echte Rueckenbild steht auf demselben geprueften 3D-Anker
  und nutzt dieselbe physische Groessenobergrenze wie die Frontansicht; der
  Gegner bleibt auf seinem eigenen Anker. Kein Rueckenbild kehrt in den
  uebergrossen unteren Slot zurueck.

Dies mit einer normal grossen Art, einer sehr grossen Art und jeder gelieferten
Mega-Form testen. Mega-Dateinamen folgen der oben dokumentierten Formsuche.
Fehlt eine Mega-Datei, reicht VASC die animierte finale Spiel-/KASC-Grafik
durch, statt eine leere Karte oder unpassende Ersatzgrafik zu zeigen.

OBERWELT-SHEETS EINSCHLIESSLICH KASC-ZUSTAENDEN
------------------------------------------------
Lesbare registrierte Sprite-IDs haben Vorrang:
  overworld/SPRITE_RED.png
  overworld/SPRITE_RED_BIKE.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_WALK.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_BIKE.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_FISH.png

Damit lassen sich KASC-spezifische Fahrrad-, Angel-, Surf-, Lauf- und andere
Zustaende aendern, ohne KASC selbst anzufassen. Fuer alte/anonyme Sheets gibt
es zusaetzlich einen stabilen Source-Key-Dateinamen. README + INDEX zeigt fuer
den aktuell geladenen Mod-Stapel die lesbaren Ziele und Source-Rueckfaelle.

SPIEL/KASC WIEDERHERSTELLEN
---------------------------
- CUSTOM SPRITES OFF ignoriert alle lokalen Sprite-Dateien.
- BACK TO GAME / KASC waehlt zusaetzlich den VASC-Basis-Spritepaketmodus.
- ALL TO GAME/KASC im VASC-Hauptmenue setzt Musik und Sprites gemeinsam zurueck.

Kein Reset loescht Dateien. Eigene Sprites sind standardmaessig AUS. KASC ist
damit geschuetzt und bleibt immer die normale Rueckfallebene.

WO LIEGT DER INSTALLIERTE ORDNER?
--------------------------------
An das aktive Speicherverzeichnis des Spiels anhaengen:
  mods/VOXEL_ASCENDANT/user/sprites/

Windows:
  %APPDATA%\LOVE\pokemon-love2d\mods\VOXEL_ASCENDANT\user\sprites\

macOS:
  ~/Library/Application Support/LOVE/pokemon-love2d/mods/
  VOXEL_ASCENDANT/user/sprites/

Linux:
  ~/.local/share/love/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/

iPhone/iPad:
  Dateien -> Auf meinem iPhone -> gen1recomp++ -> mods -> VOXEL_ASCENDANT ->
  user -> sprites
  Aktuelle iOS-Builds zeigen Documents direkt; pokemon-love2d nicht anfuegen.

Android:
  Interner Speicher/Android/data/com.theboisclub.pokemonred/files/save/
  pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/
  Moderne Android-Versionen verstecken Android/data teilweise. Nutze USB oder
  einen Dateimanager mit Zugriff auf das externe App-Verzeichnis. Root ist
  nicht erforderlich.

Nintendo Switch:
  sdmc:/switch/gen1recomp/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/

Xbox Dev Mode:
  Gen1Recomp/LocalState/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/
  LocalState wird ueber das Xbox Device Portal erreicht.

Portable Desktop-Builds koennen den mods/-Ordner neben der Programmdatei
verwenden. Bearbeite die im Launcher als installiert angezeigte Kopie. Die
START-Hilfe von VASC nennt ebenfalls die Plattformpfade.

UPDATES UND FEHLERSUCHE
-----------------------
- Vor einem kompletten VASC-Update VOXEL_ASCENDANT/user/ sichern.
- Namen werden auf A-Z, 0-9, Unterstrich und Bindestrich kanonisiert.
- Nach Kopieren, Umbenennen oder Loeschen immer RESCAN ausfuehren.
- Wird eine Grafik abgelehnt, als echte PNG neu exportieren.
- Bei falscher Groesse, Blickrichtung oder Animation Canvas, transparenten
  Rand und Frame-Aufteilung mit der konkreten Spiel-/KASC-Quelle vergleichen.
- Versinkt eine Figur, transparente Zeilen unter den Fuessen entfernen und
  pruefen, ob Schatten-/Bodenpixel unter die vorgesehene Sohle reichen.
- Ist eine Figur zu klein/gross, mit dem final gewaehlten nativen/KASC-Canvas
  vergleichen, nicht mit einer skalierten Discord-/Browser-Vorschau.
- Ist ein Trainer unsichtbar, CUSTOM SPRITES testweise ausschalten. Erscheint
  die Spiel-/KASC-Rueckfallebene, sind lokaler Name oder PNG falsch; sonst
  Kampfart, Trainerklasse und TRAINER BACK notieren.
- Fehlt ein Pokemon-Rueckenbild, pokemon/back/<ART>.png und PKMN BACK ON
  pruefen. Frontdateien ersetzen die gewaehlte Rueckenbildquelle nicht.
- Nach geaenderten Canvas-Raendern auf iPhone/Android Hoch- und Querformat
  testen; Drehen aendert die HUD-Position, nicht den Fussanker.
- Grafiken nur weitergeben, wenn die erforderlichen Rechte vorliegen.

RC-ABNAHMELISTE
---------------
[ ] Native/Retro-Frontgrafiken in MAP, DISCS und mehreren ARENAs
[ ] Native/Retro-Pokemon-Rueckenbilder mit PKMN BACK ON
[ ] Finale KASC-Front- und Rueckenbilder (wenn KASC installiert ist)
[ ] Rot, Blau, Gruen und Rivalen mit TRAINER BACK OFF
[ ] Trainer-Wurf-Rueckenbild mit TRAINER BACK ON
[ ] Normaler Trainer, Arenaleiter und alle vier Top-Vier-Klassen
[ ] Gesunde, besiegte und leere Team-Pokebaelle bleiben lesbar
[ ] Grosse Pokemon und Megas komplett bei 1X/2X/3X und ARENA-Kamera
[ ] Keine Fuesse unter Terrain/Disk/Arenaboden; kein Kopf-/Fluegel-Crop
[ ] HUD/Text bei 35-80% Transparenz in Hoch- und Querformat lesbar
