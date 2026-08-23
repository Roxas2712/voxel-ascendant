VOXEL ASCENDANT 2.0.1 - EIGENE MUSIK HINZUFUEGEN (DEUTSCH)
==========================================================

VASC liefert keine urheberrechtlich geschuetzte Austauschmusik aus. Diese
Ordner sind eine lokale, vom Benutzer kontrollierte Schnittstelle. Deine
Dateien bleiben in deiner eigenen Installation.

SCHNELLSTART
------------
1. Spiel vor dem Kopieren oder Umbenennen schliessen.
2. Den installierten VASC-Ordner und dort user/music/ oeffnen.
3. MP3-, OGG-, WAV- oder FLAC-Dateien in den passenden Kategorieordner legen.
4. Spiel starten und VASC -> USER MUSIC -> RESCAN FOLDERS oeffnen.
5. CUSTOM MUSIC einschalten.
6. In jeder Kategorie ORIGINAL, SHUFFLE oder eine bestimmte Datei waehlen.

SHUFFLE waehlt bei jedem passenden Kampf/Ereignis neu und vermeidet bei mehr
als einer gueltigen Datei eine direkte Wiederholung. Fehlt eine Datei, ist sie
ungueltig oder kann sie nicht dekodiert werden, bleibt automatisch die letzte
vom Spiel bzw. KASC gewaehlte Musik erhalten. Lautstaerke, Pause, Fortsetzen
und die Rueckkehr nach dem Kampf laufen ueber den normalen Musikplayer.

KATEGORIEORDNER
---------------
  wild/        normale Wild- und Safari-Kaempfe
  trainer/     normale Trainerkaempfe
  rival/       Rivalenkaempfe
  gym/         Arenaleiterkaempfe
  elite4/      Top-Vier-Kaempfe
  champion/    Champ-Kaempfe
  field/       Oberwelt- und Kartenmusik
  bike/        Fahrradmusik
  surf/        Surfermusik
  victory/     Siegesmusik nach Kaempfen
  evolution/   Entwicklung, Schlüpfen und Tauschentwicklung
  title/       Titelbildschirm
  halloffame/  Ruhmeshalle
  credits/     Abspann
  jingle/      kurze einmalige Signale
  scene/       Eich-Ansprache, Begegnungen und geskriptete Szenen

Dateinamen in Kategorieordnern sind nur die Anzeigenamen. Beispiele:
  wild/Johto Wild.mp3
  gym/Mein Arenathema.ogg
  field/Nacht Route.flac

EXAKTER AUSTAUSCH EINER SPIEL-/KASC-MUSIK
-----------------------------------------
Der Ordner replace/ ist die erweiterte Rueckfallebene fuer jede Musik ohne
eigene Kategorie. Die Datei muss exakt wie die aufgeloeste Song-ID heissen:
  replace/Music_WildBattle.mp3
  replace/<ORIGINAL_SONG_ID>.ogg

Gross-/Kleinschreibung kann geraeteabhaengig wichtig sein. Fuer eine exakte ID
sind nur Buchstaben, Ziffern, Unterstrich, Punkt und Bindestrich erlaubt. Eine
in der Kategorie ausgewaehlte Datei hat absichtlich Vorrang. Nach RESCAN zeigt
EXACT SONG REPLACEMENTS, welche Dateien VASC angenommen hat.

SPIEL-/KASC-STANDARD WIEDERHERSTELLEN
------------------------------------
- In einer einzelnen Kategorie ORIGINAL waehlen.
- BACK TO GAME / KASC in USER MUSIC setzt alle Musikkategorien und den
  optionalen VASC-Kampfmusikpaket-Waehler zurueck.
- ALL TO GAME/KASC im VASC-Hauptmenue setzt Musik und Sprites gemeinsam zurueck.

Dabei werden keine Dateien geloescht. Eigene Musik ist standardmaessig AUS;
eine frische Installation behaelt daher immer Spiel/KASC.

WO LIEGT DER INSTALLIERTE ORDNER?
--------------------------------
An das aktive Speicherverzeichnis des Spiels anhaengen:
  mods/VOXEL_ASCENDANT/user/music/

Windows:
  %APPDATA%\LOVE\pokemon-love2d\mods\VOXEL_ASCENDANT\user\music\

macOS:
  ~/Library/Application Support/LOVE/pokemon-love2d/mods/
  VOXEL_ASCENDANT/user/music/

Linux:
  ~/.local/share/love/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/

iPhone/iPad:
  Dateien -> Auf meinem iPhone -> gen1recomp++ -> mods -> VOXEL_ASCENDANT ->
  user -> music
  Aktuelle iOS-Builds zeigen den Documents-Ordner direkt; es gibt dort keinen
  zusaetzlichen pokemon-love2d-Unterordner.

Android:
  Interner Speicher/Android/data/com.theboisclub.pokemonred/files/save/
  pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/
  Moderne Android-Versionen verstecken Android/data teilweise. Nutze USB oder
  einen Dateimanager mit Zugriff auf das externe App-Verzeichnis. Root ist fuer
  VASC weder noetig noch empfohlen.

Nintendo Switch:
  sdmc:/switch/gen1recomp/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/

Xbox Dev Mode:
  Gen1Recomp/LocalState/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/
  LocalState wird ueber das Xbox Device Portal erreicht.

Portable Desktop-Builds koennen den mods/-Ordner neben der Programmdatei
verwenden. Bearbeite die Kopie, die der Launcher als installiert anzeigt. Die
START-Hilfe von VASC zeigt ebenfalls die Plattformpfade.

UPDATES UND FEHLERSUCHE
-----------------------
- Vor einem kompletten VASC-Update VOXEL_ASCENDANT/user/ sichern.
- Keine Unterordner in Kategorien anlegen; der Scan ist absichtlich einstufig.
- Eine umbenannte Endung konvertiert keine Musikdatei.
- Nach Kopieren, Umbenennen oder Loeschen immer RESCAN ausfuehren.
- Bei Problemen zuerst ORIGINAL waehlen; Spiel/KASC muss dann sofort greifen.
- Musik nur weitergeben, wenn die dafuer erforderlichen Rechte vorliegen.
