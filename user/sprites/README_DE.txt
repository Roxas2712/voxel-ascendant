VOXEL ASCENDANT 2.0.1 - SPRITES LOKAL ERSETZEN (DEUTSCH)
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
- Grafiken nur weitergeben, wenn die erforderlichen Rechte vorliegen.
