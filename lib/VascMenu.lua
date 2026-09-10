-- Voxel Ascendant's complete in-game control centre.
--
-- VASC owns this whole screen and ships the KASC FireRed presentation locally:
-- title rail, paper palette, gold cursor row, six-row budget, help popup and
-- scrolling. KASC may collect VASC's public Start-menu descriptor, but opening
-- it always enters this same self-contained tree; no KASC UI module is wired
-- into VASC's settings implementation.

local V = ...
local VascMenu = {}

local KASC_IDS = { "kanto_ascendant", "trainer_rematch" }

local ROOT_HELP = {
  en = table.concat({
    "Voxel Ascendant's complete settings hub. Open a section with A. In a ",
    "settings page, A advances a value and Left/Right changes it in either ",
    "direction. START or SELECT explains the highlighted row. HELP repeats ",
    "this guide. Every value is saved immediately.",
  }),
  de = table.concat({
    "Die vollständige Voxel-Ascendant-Zentrale. Öffne einen Bereich mit A. ",
    "Auf einer Einstellungsseite schaltet A weiter; Links/Rechts ändert in ",
    "beide Richtungen. START oder SELECT erklärt die markierte Zeile. HILFE ",
    "wiederholt diese Anleitung. Jede Änderung wird sofort gespeichert.",
  }),
}

local SETTING_HELP_DE = {
  deviceProfile = "Wähle ein dauerhaftes Geräteprofil. AUTO erkennt die "
    .. "Plattform; einzelne Änderungen wechseln sicher auf CUSTOM.",
  sky = "Outdoor-Himmel über Kanto. FULL zeichnet den tageszeitabhängigen "
    .. "Himmel, FLAT nur die günstige Horizontfarbe, OFF keinen VASC-Himmel.",
  clouds = "Pixelwolken im Outdoor-Himmel. Farbe und Dichte folgen Tageszeit "
    .. "und Wetter; für schwächere Geräte separat abschaltbar.",
  skyEvents = "Seltene, weltfest verankerte Himmelsereignisse wie Regenbogen "
    .. "und Flug-Pokémon. FULL, Teilmodi und OFF bleiben unabhängig wählbar.",
  weather = "VASC-Wetter für Außenkarten und Outdoor-Kämpfe. AUTO nutzt "
    .. "kartenübergreifende Vier-Minuten-Fronten und vier Fronten je Saison; "
    .. "direkte Modi dienen Auswahl und Tests.",
  weatherMusic = "Gebiets- und wetterabhängige Gen-I-Musik für zwölf "
    .. "geprüfte Themenfamilien einschließlich Fahrrad. Klarer Tag sowie "
    .. "nicht registrierte Themen bleiben bei der normalen Spiel-/KASC-Musik; "
    .. "Kampf, Story, SURF und Jingles haben immer Vorrang.",
  weatherTweak = "Optionale Details über dem VASC-Wetter. Normaler Regen "
    .. "bleibt unberührt. SUBTLE oder FULL ergänzen Sturmblätter, regionale "
    .. "Böen, Schnee-Hagel, Nebel-Gischt, Staub, Asche, seltene Meteore, "
    .. "Oberflächennachwirkung und sichere Umgebungsgeräusche.",
  scenery = "Kartenabhängige Nahkulisse und ferne Kanto-Panoramen draußen "
    .. "sowie Felsabschlüsse in Höhlen. OFF blendet beides aus.",
  preload = "Bereitet aktuelle und verbundene Karten im Hintergrund vor, "
    .. "damit der erste Voxel-Wechsel und Kartenwechsel schneller erscheinen.",
  grid = "Ein-Pixel-Gitter entlang der Kanten aller Voxel in der Oberwelt.",
  terrainHeights = "Visuelle Geländehöhen: FLAT ist der sichere Standard "
    .. "und hält Boden sowie Ledge-/Heckentrennungen vollständig eben. "
    .. "WORLD führt klar eingefasste "
    .. "Plateaus über direkte Kartenübergänge fort und hebt angrenzende "
    .. "Felsen/Poller mit an; entfernte Wege bleiben flach. LOCAL nutzt die "
    .. "bisherige begrenzte Kartenlogik. Echte Treppen und Bauwerke bleiben "
    .. "in allen Modi erhalten.",
  battleGrid = "Voxel-Kanten im 3D-Kampf. Unabhängig vom Oberwelt-Gitter.",
  shadows = "Objekt-, Figuren-, Wolken- und Flugschatten gemäß VASC-Regeln. "
    .. "Auf schwächeren Mobilgeräten kann OFF Leistung sparen.",
  curve = "Biegt die ferne Welt wie bei Animal Crossing nach unten, ohne HUD "
    .. "oder Pixelgrafik als Bildschirmfilter zu verformen.",
  water = "Wasserreflexionen: FULL mit Umgebung, SKY nur Himmel/Sonne/Mond "
    .. "bei deutlich geringeren Kosten, OFF ohne Reflexionspass.",
  battles = "3D-Kämpfe mit nativen Gen-I-Bildern: MAP auf echter Umgebung, "
    .. "ARENA auf geprüftem Feld, DISCS auf zwei Plattformen oder OFF.",
  arenaArt = "ARENA-Hintergrund: stabil gemischtes VASC+FRLG, nur VASC oder "
    .. "FRLG-like. Ungepaarte Karten behalten immer ihr passendes VASC-Motiv.",
  diskArt = "DISCS-Oberfläche: VASC+FRLG, VASC oder ortsbezogenes FRLG-like. "
    .. "Nicht freigegebene Orte fallen sicher auf VASC zurück.",
  qol_ui_skin = "Darstellung der nativen Spielmenüs, Dialoge und Auswahlboxen: "
    .. "ORAS GLASS oder das unveränderte GAME DEFAULT. Eigene KASC-, VASC-, "
    .. "FRLG-, PC- und Kampfoberflächen werden nie überzeichnet; die Tasche "
    .. "besitzt direkt darunter eine getrennte, sichere Auswahl.",
  vascMenuSkin = "Darstellung ausschließlich dieser VASC/KASC-Einstellungszentrale: "
    .. "ORAS FULLSCREEN nutzt standardmäßig die breite Glasansicht mit dauerhaft "
    .. "sichtbarer Zeilenhilfe. Die bisherige 160x144-Oberfläche bleibt nur "
    .. "intern als Notfall-Fallback erhalten und ist nicht mehr auswählbar. "
    .. "Tasche, PC, Box und gewöhnliche Spielmenüs bleiben davon unberührt.",
  qol_bag_skin = "Darstellung der Tasche: GAME/KASC behält den exakten Spiel-, "
    .. "Useful-Bag- oder KASC-Zeichenbesitzer und ist der sichere Standard. "
    .. "D/P ORAS WIDE und FRLG ORAS WIDE nutzen eine echte 512x288-Aufteilung "
    .. "mit breiter Liste und dauerhaft sichtbarer Beschreibung. Die kompakten "
    .. "Renderer bleiben ausschließlich interne Fallbacks und sind nicht mehr "
    .. "als Benutzeroption auswählbar. "
    .. "Items, Fächer, Eingabe, Sortierung und Aktionen bleiben unverändert.",
  qol_bag_color = "Akzentfarbe eines gewählten VASC-ORAS-Taschenstils. AUTO "
    .. "folgt ausschließlich KASCs öffentlicher RED/BLUE/GREEN-Figur; ohne "
    .. "gültigen Beleg bleibt Rot. Goldmaterial und Konturen bleiben original.",
  qol_bag_body = "Getrennte Körper-/Editionsfarbe eines gewählten VASC-ORAS-"
    .. "Taschenstils. AUTO folgt der Spiel-Edition, ORAS behält die Quellfarben. "
    .. "GAME/KASC und sämtliche Taschenlogik bleiben unberührt.",
  qol_bag_form = "Form eines gewählten VASC-ORAS-Taschenstils. AUTO nutzt für "
    .. "KASC GREEN den Henkel und für RED/BLUE die runde Normalform. Form und "
    .. "Akzent sind voneinander unabhängig.",
  pokemonUiSkin = "Gemeinsamer Wunsch für boxartige Pokémon-Oberflächen. "
    .. "ASC BOX wird nur wirksam, wenn ein vollständiger Provider für die "
    .. "jeweilige Oberfläche registriert ist; sonst bleibt GAME DEFAULT aktiv.",
  pokemonUiPcBox = "Darstellung der normalen PC-Box: GLOBAL folgen oder einen "
    .. "vollständig registrierten Skin wählen. Ablage, Entnahme, Freilassen "
    .. "und Boxwechsel bleiben Regeln des Spiels.",
  pokemonUiLegacyBank = "Darstellung der KASC-Vermächtnisbank: GLOBAL folgen, "
    .. "einen vollständigen Provider oder GAME DEFAULT wählen. Mehrfachauswahl "
    .. "über Boxen, Kapazitätswarnung, Übertragung und Dex bleiben KASC-Logik.",
  pokemonUiPartyMenu = "Darstellung der normalen Teamansicht über die "
    .. "unveränderte POKéMON-Zeile im Startmenü: neue breite ASC BOX, "
    .. "zeichnungsreines ORAS GLASS oder exaktes GAME DEFAULT. Teamaktionen, "
    .. "Feldattacken, Zielauswahl und Rückkehr ins Startmenü bleiben Spiel-/KASC-Logik.",
  pokemonUiBattleParty = "Nur die Team-/Wechselauswahl im Kampf. Diese Zeile "
    .. "ändert niemals HP-/Statuskarten oder Kampfkommandos; ORAS-Kampf-HUD "
    .. "und ASC-Box-Teamansicht dürfen gleichzeitig aktiv sein.",
  pokedexStyle = "Darstellung des Gen-I-Pokédex: VASC WIDESCREEN öffnet den "
    .. "integrierten 512x288-ModernDex; GAME DEFAULT stellt die exakten "
    .. "nativen Pokédex- und Datenseiten wieder her. Spielstand, Gesehen-/"
    .. "Gefangen-Bits, Rufe, forceOwned-Vorschauen und Startmenü-Rückkehr "
    .. "bleiben immer beim Spiel. Jeder Darstellungsfehler fällt nativ zurück.",
  modernDexSpriteSource = "Bildquelle ausschließlich im ModernDex: KASC "
    .. "CRYSTAL (AUTO) nutzt KASCs öffentlichen Crystal-Provider mit sicherem "
    .. "Rückfall, ACTIVE folgt dem aktiven Sprite-Stil und GAME ORIGINAL dem "
    .. "Cartridge-Bild. Kampf, Team, Box und Oberwelt werden nicht verändert.",
  ascBoxDensity = "Raster des VASC-eigenen ASC-BOX-Skins. 5 X 4 zeigt die "
    .. "echten zwanzig Gen-I-Plätze mit größeren Bildern; 6 X 5 zeigt das "
    .. "dichtere ORAS-Raster und sperrt Plätze oberhalb der Host-Kapazität.",
  battleHudStyle = "VASC bietet die vollständige ORAS-Kampf-HUD oder die "
    .. "lesbare Standard-HUD auch zusammen mit KASC. KASC kann Mega- und "
    .. "Komfortdaten liefern; nur ein ausdrücklicher HUD-Claim übernimmt.",
  hud_language = "Sprache der VASC-ORAS-HUD. AUTO folgt Universal German "
    .. "beziehungsweise der aktiven Spielsprache.",
  hud_scale = "Skaliert die komplette ORAS-Auswahl proportional, ohne "
    .. "einzelne Knöpfe künstlich zu strecken.",
  oras_status_glass = "Stärke nur der Glasfläche hinter ORAS-Statuskarten. "
    .. "Schrift, KP-/EP-Balken, Symbole und Editionsrahmen bleiben unverändert.",
  oras_text_glass = "Stärke nur der Glasfläche hinter der Kampf-Textbox. "
    .. "Text, Cursor und Editionsrahmen bleiben unverändert lesbar.",
  status_anchor = "Verankert die Statuskarten außerhalb oder oberhalb der "
    .. "Pokémon beziehungsweise in den Bildschirmecken.",
  player_hud_x = "Horizontale Feinverschiebung der eigenen ORAS-Statuskarte.",
  player_hud_y = "Vertikale Feinverschiebung der eigenen ORAS-Statuskarte.",
  enemy_hud_x = "Horizontale Feinverschiebung der gegnerischen ORAS-Statuskarte.",
  enemy_hud_y = "Vertikale Feinverschiebung der gegnerischen ORAS-Statuskarte.",
  wild_dvs = "Zeigt im wilden Kampf die fünf Gen-I-DVs in der ORAS-Statuskarte.",
  battleHudPosition = "Position der lesbaren Kampf-HUD. AUTO nutzt breite "
    .. "Ränder im Querformat und oben/unten auf Hochformat-Handys.",
  battleHudScale = "Größe der Kampf-HUD unabhängig von Arena und Kamera. "
    .. "AUTO nutzt im Handy-Hochformat klare 100 %, quer kompakte 75 % "
    .. "und am Desktop die KASC-Größe.",
  battleHudAlpha = "Transparenz der lesbaren Glasflächen hinter Status, "
    .. "Kampfauswahl und Textfenster.",
  battleHudGender = "Zeigt das Gen-II-Geschlecht im eigenen Statusfeld. "
    .. "VASC leitet es aus dem vorhandenen Angriffs-DV ab und speichert kein "
    .. "neues Geschlecht am Pokémon.",
  battleHudExp = "Zeigt den EP-Fortschritt schwarz oder blau direkt an der "
    .. "Spieler-HUD. Mit KASC bedient die Zeile dessen passende QoL-Option, "
    .. "während VASC Position und Skalierung der HUD bestimmt.",
  battleHudCaught = "Markiert bereits gefangene wilde Gegner rot oder grau. "
    .. "Das Symbol steckt in derselben Gegner-HUD und kann nicht mehr allein "
    .. "in der Bildmitte stehen bleiben.",
  battleCameraDistance = "Startdistanz für MAP und DISCS: 1X nah, 2X mittel, "
    .. "3X weit. Q/E, Rad oder Pinch können im Kampf weiter zoomen.",
  arenaCamera = "STADIUM führt die Kamera in echter Voxel-Welt durch "
    .. "Intros, Nahaufnahmen, Schulteransichten und einen langsamen 360°-Orbit. "
    .. "Lange Ruhebilder, begrenzte Drehgeschwindigkeit und geprüfte Wege um "
    .. "Bäume, Wände und Häuser vermeiden hektische oder clipende Fahrten. In "
    .. "engen Räumen wählt VASC einmal den besten freien Blick auf beide "
    .. "Pokémon und hält diesen Kameraplatz für den ganzen Kampf statisch. "
    .. "Eine gemalte ARENA-Kulisse bleibt optisch fest, damit die Pokémon "
    .. "darin nicht wachsen oder schrumpfen. 3X behält die bisherige "
    .. "statische Kamera.",
  trainerBack = "Nur mit STANDARD-HUD in MAP oder DISCS: Der native "
    .. "2D-Trainer-Rückensprite bleibt mit den Füßen auf der Textbox. ARENA "
    .. "und andere HUDs verwenden immer eine volle stehende Frontgrafik.",
  battleBack = "Mit STANDARD-HUD in MAP darf die native 2D-Rückengrafik auf "
    .. "der Textbox bleiben. DISCS, ARENA und andere HUDs verwenden nur eine "
    .. "ausdrücklich bestätigte Vollkörper-Rückansicht, sonst sicher FRONT.",
  battleMusicMode = "Optionale getrennte Musikpakete. ORIGINAL behält Spiel/"
    .. "KASC; VASC selbst liefert und lädt keine Musik aus dem Netz.",
  daytime = "Outdoor-Tageszeit: DAY, NIGHT, DUSK, DAWN oder AUTO mit langen "
    .. "Tag-/Nachtphasen und kurzen Übergängen.",
  aa = "Kantenglättung der 3D-Welt per Supersampling. 2X/4X kosten deutlich "
    .. "mehr GPU-Leistung; Menüs und Kampftext bleiben scharf.",
}

local PIPELINE_HELP_DE = {
  ["pipeline:voxel"] = "Wähle die Voxel-Kameraleiter: OFF, Orbitansichten, "
    .. "Ego-, Verfolgeransicht oder das vollständige FULL-Preset.",
  ["pipeline:tiltshift"] = "Miniatur-Tiefenunschärfe nur auf der Voxelwelt; "
    .. "Menüs, Kampftext und HUD bleiben scharf.",
}

local SECTION_DEFS = {
  world = {
    title = "VIEW + WORLD",
    help = {
      en = "Camera and voxel-world presentation. VOXEL and T-SHIFT are the "
        .. "same saved render-pipeline controls shown in Game Options.",
      de = "Kamera und Darstellung der Voxelwelt. VOXEL und T-SHIFT sind "
        .. "dieselben gespeicherten Renderoptionen wie in den Spieloptionen.",
    },
    keys = {
      grid=true, terrainHeights=true, curve=true, water=true,
    },
    pipelines = { ["pipeline:voxel"]=true, ["pipeline:tiltshift"]=true },
  },
  weather = {
    title = "WEATHER + SCENERY",
    help = {
      en = "Time, VASC weather, sky events and map-aware scenery share one "
        .. "resolved outdoor state, including supported staged battles.",
      de = "Tageszeit, VASC-Wetter, Himmelsereignisse und Kartenkulisse "
        .. "nutzen denselben Outdoor-Zustand, auch in unterstützten Kämpfen.",
    },
    keys = {
      daytime=true, weather=true, weatherMusic=true, weatherTweak=true,
      sky=true, clouds=true, skyEvents=true,
      scenery=true,
    },
  },
  battle = {
    title = "BATTLE",
    help = {
      en = "Choose the 3D stage, arena or disk art, camera, readable HUD and "
        .. "battle music. BATTLE LAYOUT saves separate actor and fallback-HUD "
        .. "position/size corrections for every sprite role.",
      de = "Wähle 3D-Feld, Arena-/Disk-Grafik, Kamera, lesbare HUD und "
        .. "Kampfmusik. KAMPF-LAYOUT speichert getrennte Positions-/Größenkorrekturen "
        .. "für jede Figuren- und Fallback-HUD-Rolle.",
    },
    keys = {
      battles=true, arenaArt=true, diskArt=true, battleGrid=true,
      battleHudStyle=true,
      hud_language=true, hud_scale=true,
      oras_status_glass=true, oras_text_glass=true, status_anchor=true,
      player_hud_x=true, player_hud_y=true,
      enemy_hud_x=true, enemy_hud_y=true, wild_dvs=true,
      battleHudPosition=true,
      battleHudScale=true, battleHudAlpha=true, battleHudGender=true,
      battleHudExp=true, battleHudCaught=true, battleCameraDistance=true,
      arenaCamera=true, battleMusicMode=true,
    },
    actions = {
      { label="BATTLE LAYOUT", screen="VascBattleLayout",
        help={
          en="Adjust and save X, Y and size for each front/back/Mega/trainer sprite and each VASC fallback-HUD zone.",
          de="X, Y und Größe je Front-/Rück-/Mega-/Trainer-Sprite und VASC-Fallback-HUD-Bereich einstellen und speichern.",
        } },
      { label="MOVE ANIMATIONS", action="animations" },
    },
  },
  pokemon = {
    title = "POKéMON + MODELS",
    help = {
      en = "Choose Pokémon models and front/rear battle art, import Stadium 2 or open the sprite guide. "
        .. "Party, PC, Legacy Bank, Bag and menu skins live together in "
        .. "SKINS & OVERLAYS.",
      de = "Wähle Pokémon-Modelle und Front-/Rückengrafiken, importiere Stadium 2 oder öffne die Sprite-Anleitung. "
        .. "Team-, PC-, Bank-, Taschen- und Menüskins liegen gemeinsam unter "
        .. "SKINS & OVERLAYS.",
    },
    keys = {
      trainerBack=true, battleBack=true, modernDexSpriteSource=true,
      pokemonModelSkin=true,
    },
    actions = {
      { label="SPRITE GUIDE", screen="VascUserSpritesHelp",
        help={
          en="Open the installed naming, size, baseline and fallback guide.",
          de="Öffne die installierte Anleitung zu Namen, Größen, Fußlinie und Rückfall.",
      } },
      { label="POKEMON HD DOWNLOADS", screen="VascPokemonHdDownloads",
        help={en="Download optional Pokemon HD packages by generation. HD characters remain installed.",
          de="Optionale Pokemon-HD-Pakete pro Generation laden. HD-Charaktere bleiben installiert."} },
      { label="STADIUM 2 ROM", action="stadiumRom",
        help={
          en="Choose your own Stadium 2 ROM to build the local Pokémon model pack. Requires a compatible host file picker; no ROM data is included.",
          de="Wähle deine eigene Stadium-2-ROM für das lokale Pokémon-Modellpaket. Erfordert einen kompatiblen Host-Dateidialog; keine ROM-Daten enthalten.",
        } },
    },
  },
  skins = {
    title = "SKINS & OVERLAYS",
    help = {
      en = "Choose normal Start-party and battle-party skins separately, "
        .. "then select PC, Legacy Bank, Bag and ordinary menu presentation. "
        .. "GAME DEFAULT always yields to the exact native/KASC owner.",
      de = "Wähle normale Start-Team- und Kampf-Team-Skins getrennt, danach "
        .. "PC, Vermächtnisbank, Tasche und gewöhnliche Menüs. GAME DEFAULT "
        .. "überlässt die Darstellung exakt dem Spiel beziehungsweise KASC.",
    },
    keys = {
      vascMenuSkin=true,
      pokedexStyle=true,
      pokemonUiPartyMenu=true,
      pokemonUiBattleParty=true,
      pokemonUiSkin=true, pokemonUiPcBox=true,
      pokemonUiLegacyBank=true, ascBoxDensity=true,
      qol_ui_skin=true, qol_bag_skin=true,
      qol_bag_color=true, qol_bag_body=true, qol_bag_form=true,
    },
  },
  wilds = {
    title = "WILDS + FOLLOWERS",
    help = {
      en = "VASC remains independent from Wilds and follower mods. Their own "
        .. "rows stay in Game Options; VASC only renders registered sprites safely.",
      de = "VASC bleibt von Wilds- und Follower-Mods unabhängig. Deren eigene "
        .. "Zeilen bleiben in den Spieloptionen; VASC rendert registrierte Sprites sicher.",
    },
    keys = {},
    actions = {
      { label="MOD OPTIONS", screen="OptionsMenu",
        help={
          en="Open all Game and mod-owned Wilds/follower options without coupling them to VASC.",
          de="Öffnet alle spiel- und modeigenen Wilds-/Follower-Optionen ohne Kopplung an VASC.",
        } },
      { label="COMPATIBILITY", action="info",
        help={
          en="Installed companions keep ownership of behavior and saves. VASC accepts only public sprite/render contracts.",
          de="Installierte Begleiter behalten Verhalten und Speicherstände. VASC nutzt nur öffentliche Sprite-/Render-Verträge.",
        } },
    },
  },
  performance = {
    title = "PERFORMANCE",
    help = {
      en = "Hardware and render-cost controls. AUTO chooses a safe device "
        .. "profile; changing a managed row preserves it as CUSTOM.",
      de = "Hardware- und Renderkosten. AUTO wählt ein sicheres Geräteprofil; "
        .. "eine Einzeländerung wird als CUSTOM bewahrt.",
    },
    keys = {
      deviceProfile=true, preload=true, shadows=true, aa=true,
    },
  },
  user = {
    title = "USER CONTENT",
    help = {
      en = "Choose exactly one content profile: KASC through a public receipt, "
        .. "VASC DEFAULT, RETRO through a public receipt, or CUSTOM from a "
        .. "verified named preset / documented folders. Missing slots fall back safely.",
      de = "Wähle genau ein Inhaltsprofil: KASC über einen öffentlichen Beleg, "
        .. "VASC DEFAULT, RETRO über einen öffentlichen Beleg oder CUSTOM aus "
        .. "einem geprüften Preset / dokumentierten Ordnern. Fehlende Plätze fallen sicher zurück.",
    },
    keys = {},
    actions = {
      { label="CONTENT SOURCE", action="contentProfile",
        settingKey="contentProfile.requested" },
      { label="PRESET & SCOPE", screen="VascContentStatus",
        help={
          en="Show the active game/generation scope, verified preset, fallback and one-step VASC DEFAULT control.",
          de="Zeigt Spiel-/Generations-Scope, geprüftes Preset, Rückfall und den direkten Weg zu VASC DEFAULT.",
        } },
      { label="CUSTOM MUSIC", screen="VascUserMusic",
        help={
          en="Configure user-owned music used only by the CUSTOM profile.",
          de="Eigene Musik konfigurieren, die nur das CUSTOM-Profil nutzt.",
        } },
      { label="CUSTOM SPRITES", screen="VascUserSprites",
        help={
          en="Inspect and rescan documented PNG overrides used only by CUSTOM.",
          de="Dokumentierte PNG-Ersetzungen für CUSTOM prüfen und neu einlesen.",
        } },
    },
  },
  advanced = {
    title = "ADVANCED",
    help = {
      en = "Open the complete Game/mod option list, repeat the START guide or "
        .. "check this installed VASC build. No hidden KASC dependency is used.",
      de = "Öffne alle Spiel-/Modoptionen, wiederhole die START-Hilfe oder "
        .. "prüfe den VASC-Build. Es gibt keine versteckte KASC-Abhängigkeit.",
    },
    keys = {},
    actions = {
      { label="ALL GAME OPTIONS", screen="OptionsMenu",
        help={
          en="Open the complete engine list, including rows owned by other enabled mods.",
          de="Öffnet die vollständige Engine-Liste einschließlich Zeilen anderer aktiver Mods.",
        } },
      { label="START GUIDE", action="rootHelp" },
      { label="RC DIAGNOSTICS", screen="VascDiagnostics",
        help={
          en="Enter the private maintainer code for deep QA controls. Support logging is always active.",
          de="Privaten Maintainer-Code für tiefe QA-Funktionen eingeben. Das Support-Log ist immer aktiv.",
        } },
      { label="VERSION", action="version" },
    },
  },
}

local DEFAULT_SECTION_ORDER = {
  "world", "weather", "battle", "skins", "pokemon",
  "wilds", "performance", "user", "advanced",
}

-- Kept as a stable public/manual-QA receipt.  Older tests and standalone
-- builds can still page through this summary even when KASC's guided popup is
-- unavailable.
local PAGES = {
  { title="VIEW + WORLD", "VOXEL CAMERA, GRID,", "CURVE AND WATER", "LIVE IN THIS PAGE." },
  { title="WEATHER + SCENERY", "TIME, WEATHER, SKY,", "EVENTS AND SCENERY", "SHARE ONE OUTDOOR STATE." },
  { title="BATTLE", "STAGE, ART, CAMERA,", "HUD, MUSIC AND MOVES", "LIVE IN THIS PAGE." },
  { title="SKINS & OVERLAYS", "START TEAM, BATTLE TEAM,", "PC, BANK, BAG AND MENUS", "STAY INDEPENDENT." },
  { title="POKéMON + MODELS", "SPRITE PACKS AND", "FRONT/BACK PLACEMENT", "LIVE IN THIS PAGE." },
  { title="WILDS + FOLLOWERS", "INDEPENDENT MODS KEEP", "THEIR OWN OPTIONS.", "VASC USES PUBLIC HOOKS." },
  { title="PERFORMANCE", "DEVICE, PRELOAD,", "SHADOWS AND AA", "LIVE IN THIS PAGE." },
  { title="USER CONTENT", "OWN MUSIC AND PNGS", "ARE FAIL-OPEN AND", "NEVER DELETE ORIGINALS." },
  { title="ADVANCED", "ALL GAME OPTIONS,", "VERSION AND GUIDE", "REMAIN REACHABLE." },
  { title="CONTROLS", "A: OPEN / NEXT VALUE", "LEFT/RIGHT: CHANGE VALUE", "START/SELECT: ROW HELP" },
}

local config = { settings = {} }
local localUiByMod = setmetatable({}, { __mode="k" })
local menuSkinBridgeByMod = setmetatable({}, { __mode="k" })
local animationReceipt
local restoreAll

local function diagnosticsConfigured()
  local diagnostics = config and config.diagnostics
  return type(diagnostics) == "table"
    and diagnostics.CODE ~= nil and diagnostics.FILE ~= nil
    and type(diagnostics.enabled) == "function"
    and type(diagnostics.setEnabled) == "function"
    and type(diagnostics.write) == "function"
end

local function configuredMenuSkin(mod)
  local setting = config and config.menuSkinSetting
  if type(setting) == "table" and type(setting.get) == "function" then
    local ok, value = pcall(setting.get, setting)
    if ok and value ~= nil then return value end
  end
  local configured = config and config.menuSkin
  if type(configured) == "function" then
    local ok, value = pcall(configured, mod)
    if ok and value ~= nil then return value end
  elseif configured ~= nil then
    return configured
  end
  -- A regular ModSetting entry is enough; callers do not need a second
  -- private skin channel merely to let this renderer observe it live.
  for _, entry in ipairs(config and config.settings or {}) do
    local candidate = type(entry) == "table" and entry[1] or nil
    if candidate and candidate.key == "vascMenuSkin"
        and type(candidate.get) == "function" then
      local ok, value = pcall(candidate.get, candidate)
      if ok and value ~= nil then return value end
    end
  end
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, "vascMenuSkin")
    if ok and value ~= nil then return value end
  end
  return "oras_fullscreen"
end

local function activeSections()
  return type(config.sections) == "table" and config.sections or SECTION_DEFS
end

local function activeSectionOrder()
  return type(config.sectionOrder) == "table"
         and config.sectionOrder or DEFAULT_SECTION_ORDER
end

-- The universal translation package can deliberately boot in either German
-- or English, so its mere presence is not a language verdict.  Its public
-- boot receipt is the process-wide authority; the optional dependency in the
-- manifest guarantees that the receipt exists before VASC builds its menu.
local function universalBootLanguage(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, "translation-german-universal")
  local exports = ok and type(handle) == "table" and handle.exports or nil
  local language = type(exports) == "table" and exports.bootLanguage or nil
  if language == "de" or language == "en" then return language end
  return nil
end

local function languageCode(mod)
  local configured = config and config.language
  if type(configured) == "function" then
    local ok, value = pcall(configured, mod)
    if ok and (value == "de" or value == "en") then return value end
  elseif configured == "de" or configured == "en" then
    return configured
  end

  local universal = universalBootLanguage(mod)
  if universal then return universal end

  -- Match the actual language of the loaded game data, not a private VASC or
  -- KASC preference. This is the same public translation-mod convention used
  -- by Gen1Recomp translations, but implemented locally so VASC stays autark.
  local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
  local version = okVersion and type(GameVersion) == "table"
                  and type(GameVersion.get) == "function"
                  and GameVersion.get() or "red"
  local expected = {
    red="deutsch", blue="deutsch-blau", yellow="deutsch-gelb",
  }
  local id = expected[version]
  if not id or type(mod) ~= "table" or type(mod.find) ~= "function" then
    return "en"
  end
  local okFind, handle = pcall(mod.find, id)
  return okFind and handle ~= nil and "de" or "en"
end

-- VASC owns these presentation strings. Keep internal setting keys and action
-- ids stable, but never leak their English developer labels into a German
-- Universal-German session.
local UI_LABEL_DE = {
  ["POKEMON HD DOWNLOADS"]="POKéMON-HD-DOWNLOADS",
  ["VIEW + WORLD"]="SICHT + WELT",
  ["WEATHER + SCENERY"]="WETTER + KULISSE",
  ["BATTLE"]="KAMPF",
  ["SKINS & OVERLAYS"]="DESIGN + HUD",
  ["POKéMON + MODELS"]="POKéMON + MODELLE",
  ["WILDS + FOLLOWERS"]="WILDE + BEGLEITER",
  ["PERFORMANCE"]="LEISTUNG",
  ["USER CONTENT"]="EIGENE INHALTE",
  ["ADVANCED"]="ERWEITERT",
  ["CONTROLS"]="STEUERUNG",
  ["BATTLE LAYOUT"]="KAMPF-LAYOUT",
  ["MOVE ANIMATIONS"]="ATTACKEN-ANIM.",
  ["SPRITE GUIDE"]="SPRITE-ANLEIT.",
  ["MOD OPTIONS"]="MOD-OPTIONEN",
  ["COMPATIBILITY"]="KOMPATIBILITÄT",
  ["CONTENT SOURCE"]="INHALTSQUELLE",
  ["PRESET & SCOPE"]="VORLAGE + UMFANG",
  ["CUSTOM MUSIC"]="EIGENE MUSIK",
  ["CUSTOM SPRITES"]="EIGENE SPRITES",
  ["ALL GAME OPTIONS"]="ALLE OPTIONEN",
  ["START GUIDE"]="START-ANLEITUNG",
  ["SUPPORT LOG"]="FEHLERPROTOKOLL",
  ["RC DIAGNOSTICS"]="RC-DIAGNOSE",
  ["NO SETTINGS"]="KEINE EINSTELLUNG",
  ["HELP"]="HILFE",
  ["OPEN"]="ÖFFNEN",
  ["PENDING"]="AUSSTEHEND",
  ["DONE"]="FERTIG",
  ["CURRENT LOG"]="AKTUELLES LOG",
  ["MARK REPRO"]="REPRO MARKIEREN",
  ["DELETE LOGS"]="LOGS LÖSCHEN",
  ["APPLY"]="ANWENDEN",
}

local SETTING_LABEL_DE = {
  deviceProfile="GERÄTEPROFIL", sky="HIMMEL", clouds="WOLKEN",
  skyEvents="HIMMELSEREIGNIS", weather="WETTER",
  weatherMusic="WETTERMUSIK", weatherTweak="WETTER-EFFEKTE",
  scenery="KULISSE", preload="VORLADEN", grid="VOXEL-GITTER",
  terrainHeights="GELÄNDEHÖHEN", battleGrid="KAMPF-GITTER",
  shadows="SCHATTEN", curve="WELTKRÜMMUNG", water="WASSER",
  battles="3D-KÄMPFE", arenaArt="ARENA-GRAFIK",
  diskArt="DISK-GRAFIK", qol_ui_skin="MENÜ-DESIGN",
  vascMenuSkin="VASC-MENÜ-DESIGN", qol_bag_skin="TASCHEN-DESIGN",
  qol_bag_color="TASCHEN-AKZENT", qol_bag_body="TASCHEN-FARBE",
  qol_bag_form="TASCHEN-FORM", pokemonUiSkin="POKéMON-DESIGN",
  pokemonUiPcBox="PC-BOX-DESIGN",
  pokemonUiLegacyBank="BANK-DESIGN",
  pokemonUiPartyMenu="TEAM-DESIGN",
  pokemonUiBattleParty="KAMPFTEAM-DESIGN",
  pokedexStyle="POKéDEX-DESIGN",
  modernDexSpriteSource="DEX-BILDQUELLE", ascBoxDensity="BOX-DICHTE",
  battleHudStyle="KAMPF-HUD", hud_language="HUD-SPRACHE",
  hud_scale="HUD-GRÖSSE", oras_status_glass="STATUS-GLAS",
  oras_text_glass="TEXT-GLAS", status_anchor="STATUS-POSITION",
  player_hud_x="EIGENE HUD X", player_hud_y="EIGENE HUD Y",
  enemy_hud_x="GEGNER-HUD X", enemy_hud_y="GEGNER-HUD Y",
  wild_dvs="WILDE DVS", battleHudPosition="KAMPF-HUD-POS.",
  battleHudScale="KAMPF-HUD-GRÖSSE", battleHudAlpha="KAMPF-HUD-DECKUNG",
  battleHudGender="HUD-GESCHLECHT", battleHudExp="HUD-EP",
  battleHudCaught="GEFANGEN-SYMBOL", battleCameraDistance="KAMERA-ABSTAND",
  arenaCamera="ARENA-KAMERA", trainerBack="TRAINER-RÜCKSEITE",
  battleBack="POKéMON-RÜCKSEITE", battleMusicMode="KAMPFMUSIK",
  daytime="TAGESZEIT", aa="KANTENGLÄTTUNG",
}

local VALUE_DE = {
  AUTO="AUTOM.", FULL="VOLL", OFF="AUS", ON="AN", OPEN="ÖFFNEN",
  PENDING="AUSSTEHEND", DONE="FERTIG", DEFAULT="STANDARD",
  ["GAME DEFAULT"]="SPIEL-STANDARD", ["VASC DEFAULT"]="VASC-STANDARD",
  DAY="TAG", NIGHT="NACHT", DUSK="ABEND", DAWN="MORGEN",
  CLEAR="KLAR", CUSTOM="EIGEN", NONE="KEINE", LOW="NIEDRIG",
  HIGH="HOCH", NORMAL="NORMAL", FRONT="VORNE", BACK="HINTEN",
  LEFT="LINKS", RIGHT="RECHTS", CENTER="MITTE",
  WORLD="WELT", LOCAL="ÖRTLICH", FLAT="FLACH", WIDE="BREIT",
  ["ORAS GLASS"]="ORAS-GLAS", ["ASC BOX"]="ASC-BOX",
  ["GAME/KASC"]="SPIEL/KASC", ACTIVE="AKTIV", BEGIN="START",
  END="ENDE", FAILED="FEHLER", LOCKED="GESPERRT",
  OUTSIDE="AUSSEN", ABOVE="OBEN", CORNERS="ECKEN",
  ENGLISH="ENGLISCH", RAIN="REGEN", SNOW="SCHNEE", FOG="NEBEL",
  STORM="STURM", HEAT="HITZE", RAINBOW="REGENBOGEN",
  FLYERS="FLIEGER", SKY="HIMMEL", LIGHT="LEICHT",
  BALANCED="AUSGEWOGEN", SHUFFLE="ZUFALL", BLACK="SCHWARZ",
  BLUE="BLAU", GREY="GRAU", RED="ROT", FRAME="RAHMEN",
  GREEN="GRÜN", YELLOW="GELB", SILVER="SILBER", HANDLE="HENKEL",
  EDGES="RÄNDER", STACK="GESTAPELT", ["2D BACK"]="2D HINTEN",
  ["VASC WIDESCREEN"]="VASC-BREITBILD",
  ["ACTIVE SPRITE STYLE"]="AKTIVER SPRITE-STIL",
  ["GAME ORIGINAL"]="SPIEL-ORIGINAL",
  ["KASC CRYSTAL (AUTO)"]="KASC CRYSTAL (AUTOM.)",
  ["5 X 4 DETAIL"]="5 X 4 GROSS",
  ["SMART / STADIUM"]="DYNAMISCH / STADIUM",
}

local function uiLabel(mod, value)
  value = tostring(value or "")
  if languageCode(mod) ~= "de" then return value end
  return UI_LABEL_DE[value] or value
end

local function uiValue(mod, value)
  value = tostring(value or "")
  if languageCode(mod) ~= "de" then return value end
  local count = value:match("^(%d+) MOVES$")
  if count then return count .. " ATTACKEN" end
  return VALUE_DE[value] or value
end

local function localized(mod, value)
  if type(value) ~= "table" then return tostring(value or "") end
  local lang = languageCode(mod)
  return tostring(value[lang] or value.en or value.de or "")
end

local function helpTitle(mod, title)
  title = tostring(title or "VASC HELP")
  if languageCode(mod) ~= "de" then return title end
  if title:match("HILFE$") then return title end
  title = title:gsub(" HELP$", "")
  return uiLabel(mod, title) .. " HILFE"
end

local function settingHelp(mod, entry, key)
  if languageCode(mod) == "de" then
    return type(entry) == "table" and entry[3]
           or SETTING_HELP_DE[key]
           or type(entry) == "table" and entry[2]
           or "Diese gespeicherte Voxel-Ascendant-Einstellung ändern."
  end
  return type(entry) == "table" and entry[2]
         or "Change this saved Voxel Ascendant setting."
end

local function findAscendantUi(mod)
  if type(mod) ~= "table" or type(mod.find) ~= "function" then return nil end
  for _, id in ipairs(KASC_IDS) do
    local ok, handle = pcall(mod.find, id)
    local exports = ok and type(handle) == "table" and handle.exports or nil
    local ui = type(exports) == "table" and exports.ascendantUi or nil
    if type(ui) == "table" then return ui, handle, id end
  end
  return nil
end

local function standaloneUi(mod)
  if type(mod) ~= "table" then return nil end
  local cached = localUiByMod[mod]
  if cached then return cached end
  if type(V) ~= "table" or type(V.require) ~= "function" then return nil end
  local ok, style = pcall(V.require, "VascMenuStyle")
  if not ok or type(style) ~= "table" or type(style.new) ~= "function" then
    return nil
  end
  local styleOptions = {}
  for key, value in pairs(config.styleOptions or {}) do
    styleOptions[key] = value
  end
  styleOptions.skin = styleOptions.skin
    or function() return configuredMenuSkin(mod) end
  styleOptions.language = styleOptions.language
    or function() return languageCode(mod) end
  local okUi, ui = pcall(style.new, mod, styleOptions)
  if not okUi or type(ui) ~= "table" then return nil end
  localUiByMod[mod] = ui
  return ui
end

local function menuUi(mod)
  if type(config.ui) == "table" then
    if type(config.ui.setSkinResolver) == "function" then
      config.ui.setSkinResolver(function() return configuredMenuSkin(mod) end)
    end
    if type(config.ui.setLanguageResolver) == "function" then
      config.ui.setLanguageResolver(function() return languageCode(mod) end)
    end
    return config.ui
  end
  -- The local implementation is deliberately first even when KASC is active.
  -- That keeps VASC installable on its own and prevents a KASC update from
  -- changing VASC's labels, glyph fallbacks or contextual help. The exported
  -- KASC facade is only a fail-open rescue for an incomplete VASC install.
  local localUi = standaloneUi(mod)
  if localUi then return localUi end
  if config.preferExternalUi ~= false then return findAscendantUi(mod) end
  return nil
end

local function listFactory(mod)
  local ui = menuUi(mod)
  if ui and ui.ListMenu and type(ui.ListMenu.new) == "function" then
    return ui.ListMenu
  end
  return mod and mod.ui and mod.ui.ListMenu
end

local function wrapText(value, width)
  local lines = {}
  value = tostring(value or "")
  width = math.max(8, tonumber(width) or 19)
  for paragraph in (value .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + #word + 1 <= width then
        line = line .. " " .. word
      else
        lines[#lines + 1] = line
        line = word
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

local function fallbackHelp(mod, game, opts)
  opts = opts or {}
  local body = opts.body
  if not body and opts.page then
    local page = PAGES[math.max(1, math.min(#PAGES,
      math.floor(tonumber(opts.page) or 1)))]
    body = table.concat(page, "\n")
    opts.title = opts.title or page.title
  end
  local items = {}
  local skin = tostring(configuredMenuSkin(mod) or ""):lower()
  local wide = skin:find("oras", 1, true) ~= nil
  for _, line in ipairs(wrapText(body, wide and 52 or 18)) do
    items[#items + 1] = { label=line, help=body }
  end
  items[#items + 1] = {
    label=languageCode(mod) == "de" and "SCHLIESSEN" or "CLOSE",
    close=true, help=body,
  }
  local Factory = assert(listFactory(mod), "VASC list menu unavailable")
  return Factory.new(game, helpTitle(mod, opts.title or "VASC HELP"), items, {
    pageJump=true,
    ascendantLayout=true,
    footer=languageCode(mod) == "de" and "A/B: SCHLIESSEN" or "A/B: CLOSE",
    onChoose=function(item, menu)
      if item and item.close and menu and menu.close then menu:close() end
    end,
  })
end

local function showHelp(mod, game, title, body)
  title = helpTitle(mod, title)
  local ui = menuUi(mod)
  if ui and type(ui.showHelp) == "function" then
    return ui.showHelp(game, title, body)
  end
  return mod.ui.push(game, "VascHelp", { title=title, body=body })
end

local function currentItem(menu)
  return menu and menu.items and menu.items[menu.index or 1]
end

-- Cursor memory belongs to this one settings tree.  Keeping it below the
-- mod's options bucket makes it generation/save independent, while the weak
-- process cache keeps the feature useful in a test harness or an older Gen-2
-- host that has not exposed its persistent options table yet.
local NAVIGATION_KEY = "vascMenuNavigation"
local NAVIGATION_VERSION = 1
local navigationByGame = setmetatable({}, { __mode="k" })

local function cloneNavigationGraph(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = setmetatable({}, getmetatable(value))
  seen[value] = copy
  -- Concrete mod/Game tables are cache keys and must keep identity.  The
  -- navigation values below them are the mutable portion being isolated.
  for key, item in pairs(value) do
    copy[key] = cloneNavigationGraph(item, seen)
  end
  return copy
end

local function navigationModId(mod)
  return tostring(config.navigationModId
    or (mod and mod.id) or "VOXEL_ASCENDANT")
end

local function navigationBuckets(mod, game, create)
  local id, buckets, seen = navigationModId(mod), {}, {}
  local function addBucket(bucket)
    if type(bucket) == "table" and not seen[bucket] then
      seen[bucket] = true
      buckets[#buckets + 1] = bucket
    end
  end
  local function addOptions(options)
    if type(options) ~= "table" then return end
    if create then options.modOptions = options.modOptions or {} end
    local all = options.modOptions
    if type(all) ~= "table" then return end
    if create then all[id] = all[id] or {} end
    addBucket(all[id])
  end
  addOptions(game and game.save and game.save.options)
  addOptions(game and game.options)
  local loader = game and game.mods
  local function addLoader(owner)
    if type(owner) ~= "table" then return end
    if create then owner.modOptions = owner.modOptions or {} end
    local all = owner.modOptions
    if type(all) ~= "table" then return end
    if create then all[id] = all[id] or {} end
    addBucket(all[id])
  end
  addLoader(loader)
  addLoader(loader and loader.loader)
  return buckets
end

local function navigationState(mod, game)
  local cacheKey = type(mod) == "table" and mod or navigationModId(mod)
  local perMod = type(game) == "table" and navigationByGame[game] or nil
  if type(perMod) ~= "table" then
    perMod = setmetatable({}, { __mode="k" })
    if type(game) == "table" then navigationByGame[game] = perMod end
  end
  local cached = perMod[cacheKey]
  if type(cached) ~= "table" then
    for _, bucket in ipairs(navigationBuckets(mod, game, false)) do
      local candidate = bucket[NAVIGATION_KEY]
      if type(candidate) == "table" then cached = candidate break end
    end
  end
  if type(cached) ~= "table" then cached = {} end
  cached.version = NAVIGATION_VERSION
  cached.pages = type(cached.pages) == "table" and cached.pages or {}
  perMod[cacheKey] = cached
  -- All live owners see the same in-memory object. No disk write occurs here;
  -- a page transition/close (or a normal setting write) flushes it later.
  for _, bucket in ipairs(navigationBuckets(mod, game, true)) do
    bucket[NAVIGATION_KEY] = cached
  end
  return cached
end

-- RC QA runs real menu controllers against cloned save/options backings in the
-- same process as the loaded game.  Keep both VASC and KASC cursor caches on
-- isolated graphs for that interval, then restore the exact prior objects and
-- backing slots.  This deliberately private seam returns only a one-shot
-- cleanup; normal gameplay has no cache reset/mutation API.
local function beginQaNavigationIsolation(mod, game)
  if type(game) ~= "table" or type(mod) ~= "table" then
    return nil, "menu-or-game-owner-unavailable"
  end
  local buckets, bucketTokens = navigationBuckets(mod, game, false), {}
  for index, bucket in ipairs(buckets) do
    bucketTokens[index] = {
      bucket=bucket, present=rawget(bucket, NAVIGATION_KEY) ~= nil,
      value=rawget(bucket, NAVIGATION_KEY),
    }
  end

  local originalPerMod = navigationByGame[game]
  local isolatedPerMod = type(originalPerMod) == "table"
    and cloneNavigationGraph(originalPerMod)
    or setmetatable({}, { __mode="k" })
  local cacheKey = type(mod) == "table" and mod or navigationModId(mod)
  if type(isolatedPerMod[cacheKey]) ~= "table" then
    for _, token in ipairs(bucketTokens) do
      if type(token.value) == "table" then
        isolatedPerMod[cacheKey] = cloneNavigationGraph(token.value)
        break
      end
    end
  end
  navigationByGame[game] = isolatedPerMod

  local originalUi = localUiByMod[mod]
  local ui = originalUi or standaloneUi(mod)
  local styleCleanup, styleReceipt
  if ui and type(ui._qaBeginNavigationIsolation) == "function" then
    styleCleanup, styleReceipt = ui._qaBeginNavigationIsolation(game)
  end
  if type(styleCleanup) ~= "function" then
    navigationByGame[game] = originalPerMod
    if originalUi == nil and localUiByMod[mod] == ui then
      localUiByMod[mod] = nil
    end
    return nil, "kasc-navigation-isolation-unavailable"
  end

  local active = true
  return function()
    if not active then return true end
    active = false
    local okStyle, styleResult = pcall(styleCleanup)
    navigationByGame[game] = originalPerMod
    for _, token in ipairs(bucketTokens) do
      if token.present then
        rawset(token.bucket, NAVIGATION_KEY, token.value)
      else
        rawset(token.bucket, NAVIGATION_KEY, nil)
      end
    end
    if originalUi == nil and localUiByMod[mod] == ui then
      localUiByMod[mod] = nil
    else
      localUiByMod[mod] = originalUi
    end
    if not okStyle then return false, styleResult end
    if styleResult == false then return false, "kasc-cache-restore-failed" end
    return navigationByGame[game] == originalPerMod
  end, {
    schema="voxel-ascendant/qa-navigation-isolation/v1",
    vasc_original_present=originalPerMod ~= nil,
    kasc=styleReceipt,
  }
end

local function stableItemKey(item, index)
  if type(item) ~= "table" then return "index:" .. tostring(index or 1) end
  if item.settingKey then return "setting:" .. tostring(item.settingKey) end
  if item.section then return "section:" .. tostring(item.section) end
  if item.screen then return "screen:" .. tostring(item.screen) end
  if item.action then return "action:" .. tostring(item.action) end
  if item.value ~= nil then return "value:" .. tostring(item.value) end
  if item.id ~= nil then return "id:" .. tostring(item.id) end
  return "label:" .. tostring(item.label or index or "row")
end

local function clampNavigation(menu)
  local count = #(menu.items or {})
  menu.index = count > 0
    and math.max(1, math.min(math.floor(tonumber(menu.index) or 1), count))
    or 1
  local rows = math.max(1, math.floor(tonumber(menu.rows) or 1))
  local maxScroll = math.max(0, count - rows)
  menu.scroll = math.max(0,
    math.min(math.floor(tonumber(menu.scroll) or 0), maxScroll))
  if count > 0 and menu.index <= menu.scroll then
    menu.scroll = menu.index - 1
  elseif count > 0 and menu.index > menu.scroll + rows then
    menu.scroll = menu.index - rows
  end
end

local function rememberNavigation(menu)
  local state = menu and menu.__vascNavigation
  if not state then return false end
  clampNavigation(menu)
  local page = state.nav.pages[state.pageKey] or {}
  state.nav.pages[state.pageKey] = page
  local item = currentItem(menu)
  local key = stableItemKey(item, menu.index)
  local index = math.floor(tonumber(menu.index) or 1)
  local scroll = math.floor(tonumber(menu.scroll) or 0)
  if page.itemKey ~= key or page.index ~= index or page.scroll ~= scroll then
    page.itemKey, page.index, page.scroll = key, index, scroll
    state.dirty = true
  end
  return state.dirty
end

local function persistNavigation(menu)
  local state = menu and menu.__vascNavigation
  if not state or not state.dirty then return false end
  rememberNavigation(menu)
  local game = state.game
  local handled = false
  if type(config.persistNavigation) == "function" then
    local ok, result = pcall(config.persistNavigation, game, state.nav)
    handled = ok and result == true
  end
  if not handled and game and type(game.writeOptions) == "function" then
    handled = pcall(game.writeOptions, game)
  elseif not handled and game and type(game.persistOptions) == "function" then
    handled = pcall(game.persistOptions, game)
  end
  if handled then state.dirty = false end
  return handled
end

local function restoreNavigation(menu)
  local state = menu and menu.__vascNavigation
  local page = state and state.nav.pages[state.pageKey]
  if type(page) ~= "table" then clampNavigation(menu) return false end
  local found
  if type(page.itemKey) == "string" then
    for index, item in ipairs(menu.items or {}) do
      if stableItemKey(item, index) == page.itemKey then found = index break end
    end
  end
  menu.index = found or math.floor(tonumber(page.index) or menu.index or 1)
  menu.scroll = math.floor(tonumber(page.scroll) or menu.scroll or 0)
  clampNavigation(menu)
  return found ~= nil
end

local function attachNavigation(mod, game, menu, pageKey)
  if type(menu) ~= "table" then return menu end
  local nav = navigationState(mod, game)
  menu.__vascNavigation = {
    nav=nav, game=game, pageKey=tostring(pageKey or menu.title or "page"),
    dirty=false,
  }
  menu.__vascNavigationKey = menu.__vascNavigation.pageKey
  menu.__vascRememberNavigation = function(self)
    return rememberNavigation(self)
  end
  menu.__vascPersistNavigation = function(self)
    return persistNavigation(self)
  end
  restoreNavigation(menu)

  local function wrapChoice(owner, key)
    local original = owner and owner[key]
    if type(original) ~= "function" then return end
    local wrapper = function(item, active, ...)
      local target = type(active) == "table" and active or menu
      rememberNavigation(target)
      if key == "onChoose" and target.__vascNavigation.pageKey == "vasc_root"
          and item and item.section
          and target.__vascNavigation.nav.lastSection ~= item.section then
        target.__vascNavigation.nav.lastSection = item.section
        target.__vascNavigation.dirty = true
      end
      local a, b, c, d = original(item, active, ...)
      rememberNavigation(target)
      if not (item and item.descriptor) then
        persistNavigation(target)
      end
      return a, b, c, d
    end
    owner[key] = wrapper
  end
  wrapChoice(menu, "onChoose")
  wrapChoice(menu, "onSelectKey")
  if type(menu.opts) == "table" then
    wrapChoice(menu.opts, "onChoose")
    wrapChoice(menu.opts, "onSelectKey")
  end

  local baseClose = menu.close
  if type(baseClose) == "function" then
    menu.close = function(self, ...)
      rememberNavigation(self)
      persistNavigation(self)
      return baseClose(self, ...)
    end
  end

  local baseUpdate = menu.update
  if type(baseUpdate) == "function" then
    menu.update = function(self, ...)
      local input = self.game and self.game.input
      local leaving = input and type(input.wasPressed) == "function"
        and input:wasPressed("b") == true
      rememberNavigation(self)
      local a, b, c, d = baseUpdate(self, ...)
      rememberNavigation(self)
      if leaving then persistNavigation(self) end
      return a, b, c, d
    end
  end
  return menu
end

-- KASC's public guided lists assign contextual help to SELECT. VASC mirrors
-- the same callback on START because touch/controller players explicitly use
-- START as the discoverability key. Settings pages also use Left/Right for
-- reversible stepping while A remains the one-handed "next" action.
local function armControls(menu, opts)
  if type(menu) ~= "table" or type(menu.update) ~= "function" then return menu end
  opts = opts or {}
  local base = menu.update
  menu.update = function(self, ...)
    local input = self.game and self.game.input
    if input and type(input.wasPressed) == "function" then
      if input:wasPressed("start") then
        local item = currentItem(self)
        if self.onSelectKey then self.onSelectKey(item, self) end
        return
      end
      if opts.step then
        if input:wasPressed("left") then opts.step(currentItem(self), -1, self); return end
        if input:wasPressed("right") then opts.step(currentItem(self), 1, self); return end
      end
    end
    return base(self, ...)
  end
  return menu
end

local function guidedMenu(mod, game, spec)
  spec.helpTitle = helpTitle(mod, spec.helpTitle or spec.title)
  local ui = menuUi(mod)
  local menu
  if ui and type(ui.guidedList) == "function" then
    menu = ui.guidedList(game, spec)
  else
    local rows = {}
    for i, item in ipairs(spec.rows or {}) do rows[i] = item end
    rows[#rows + 1] = {
      label=uiLabel(mod, "HELP"), value="__vasc_help", help=spec.help,
    }
    local Factory = assert(listFactory(mod), "VASC list menu unavailable")
    local options = {}
    for key, value in pairs(spec.options or {}) do options[key] = value end
    options.ascendantLayout = true
    options.footer = spec.footer or "A:SELECT ST:HELP"
    local choose = spec.onChoose or options.onChoose
    options.onChoose = function(item, active)
      if item and item.value == "__vasc_help" then
        return showHelp(mod, game, spec.helpTitle or spec.title, spec.help)
      end
      if choose then return choose(item, active) end
    end
    options.onSelectKey = function(item)
      return showHelp(mod, game, item and item.label or spec.title,
        item and item.help or spec.help)
    end
    menu = Factory.new(game, spec.title, rows, options)
  end
  menu = armControls(menu, { step=spec.step })
  return attachNavigation(mod, game, menu, spec.key)
end

local function valueOf(row)
  if not row then return "" end
  if type(row.value) == "function" then
    local ok, value = pcall(row.value)
    if ok and value ~= nil then return tostring(value) end
  elseif row.value ~= nil then
    return tostring(row.value)
  end
  return tostring(row.right or "")
end

local function settingEntryForKey(key)
  for _, entry in ipairs(config.settings or {}) do
    local setting = type(entry) == "table" and entry[1] or nil
    if setting and setting.key == key then return entry end
  end
end

local function descriptorFor(entry)
  if type(entry) ~= "table" or type(entry[1]) ~= "table" then return nil end
  if type(entry.row) == "function" then return entry.row() end
  if type(entry[1].row) == "function" then return entry[1]:row() end
  return nil
end

local function appendSettingRows(out, section, mod)
  for _, entry in ipairs(config.settings or {}) do
    local setting = type(entry) == "table" and entry[1] or nil
    local visible = true
    if type(entry) == "table" and type(entry.when) == "function" then
      local ok, result = pcall(entry.when)
      visible = ok and result and true or false
    end
    if setting and section.keys[setting.key] and visible then
      local row = descriptorFor(entry)
      if row then
        out[#out + 1] = {
          label=languageCode(mod) == "de" and SETTING_LABEL_DE[setting.key]
            or row.label or setting.label or tostring(setting.key):upper(),
          right=uiValue(mod, valueOf(row)), help=settingHelp(mod, entry, setting.key),
          descriptor=row,
          muted=row.muted,
          settingKey=setting.key,
          presentationMod=mod,
        }
      end
    end
  end
end

local function appendPipelineRows(out, game, section, mod)
  if not section.pipelines then return end
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not ok or type(Pipelines.rows) ~= "function" then return end
  for _, row in ipairs(Pipelines.rows(game) or {}) do
    if section.pipelines[row.id] then
      local help
      if languageCode(mod) == "de" then
        help = config.pipelineHelpDe and config.pipelineHelpDe[row.id]
               or PIPELINE_HELP_DE[row.id]
               or "Diese gespeicherte VASC-Renderdarstellung ändern."
      else
        help = config.pipelineHelp and config.pipelineHelp[row.id]
               or "Change this saved Voxel Ascendant render pipeline."
      end
      out[#out + 1] = {
        label=row.label or row.id, right=uiValue(mod, valueOf(row)), help=help,
        descriptor=row, pipeline=true,
        presentationMod=mod,
      }
    end
  end
end

local function appendActionRows(out, section, mod, game)
  local actions = section.actions or {}
  if not diagnosticsConfigured() then
    local visible = {}
    for _, def in ipairs(actions) do
      if def.screen ~= "VascDiagnostics" then
        visible[#visible + 1] = def
      end
    end
    actions = visible
  end
  for _, def in ipairs(actions) do
    local item = {
      label=uiLabel(mod, def.label), action=def.action, screen=def.screen,
      settingKey=def.settingKey, help=localized(mod, def.help),
      right=def.right,
    }
    if def.action == "animations" then
      local status = animationReceipt and animationReceipt()
      item.right = uiValue(mod, status and status.right or "PENDING")
      item.help = localized(mod, status and status.help)
    elseif def.action == "contentProfile" then
      local ok, descriptor = false, nil
      if type(config.contentProfileRow) == "function" then
        ok, descriptor = pcall(config.contentProfileRow)
      end
      if ok and type(descriptor) == "table" then
        item.label = descriptor.label or item.label
        item.right = uiValue(mod, valueOf(descriptor))
        item.descriptor = descriptor
        item.help = languageCode(mod) == "de"
          and "KASC, VASC DEFAULT, RETRO oder CUSTOM als gemeinsame Sprite- und Musikquelle wählen."
          or "Choose KASC, VASC DEFAULT, RETRO or CUSTOM as the shared sprite and music source."
      else
        item.right = "VASC DEFAULT"
        item.action = "info"
        item.help = languageCode(mod) == "de"
          and "Der Inhaltsprofil-Controller ist in diesem Build nicht verfügbar."
          or "The content-profile controller is unavailable in this build."
      end
    elseif def.action == "spritePack" then
      local ok, descriptor = false, nil
      if type(config.spritePackRow) == "function" then
        ok, descriptor = pcall(config.spritePackRow)
      end
      if ok and type(descriptor) == "table" then
        item.label = descriptor.label or item.label
        item.right = uiValue(mod, valueOf(descriptor))
        item.descriptor = descriptor
        item.help = languageCode(mod) == "de"
          and "Wähle GAME/KASC oder ein separat installiertes, registriertes Sprite-Paket."
          or "Choose GAME/KASC or a separately installed registered sprite pack."
      else
        item.right = "GAME/KASC"
        item.action = "info"
        item.help = languageCode(mod) == "de"
          and "Kein getrennt registriertes Sprite-Paket ist verfügbar."
          or "No separately registered sprite pack is available."
      end
    elseif def.action == "version" then
      item.right = tostring(config.version or "UNKNOWN")
      item.help = languageCode(mod) == "de"
        and ("Installierter VASC-Build: " .. item.right .. ".")
        or ("Installed VASC build: " .. item.right .. ".")
    elseif def.action == "stadiumRom" then
      local rom = config.stadiumRomMenu
      local ok, value = false, nil
      if rom and type(rom.value) == "function" then
        ok, value = pcall(rom.value, game)
      end
      item.right = ok and tostring(value or "CHOOSE") or "UNAVAILABLE"
    elseif def.action == "rootHelp" then
      item.right = "START"
      item.help = localized(mod, ROOT_HELP)
    elseif def.screen then
      item.right = item.right or uiValue(mod, "OPEN")
    elseif def.action == "info" then
      item.right = item.right or "INFO"
    end
    if def.action ~= "stadiumRom" or config.stadiumRomMenu then
      out[#out + 1] = item
    end
  end
end

local function stepSetting(game, item, direction)
  local row = item and item.descriptor
  if not row or type(row.step) ~= "function" then return false end
  local ok, changed = pcall(row.step, game, direction or 1)
  if not ok or changed == false then return false end
  item.right = uiValue(item.presentationMod, valueOf(row))
  local diagnostics = config and config.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    diagnostics.write("menu-setting-change", {
      key=item.settingKey or row.id or item.label,
      value=item.right,
      direction=direction or 1,
    })
  end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return true
end

local function sectionRows(mod, game, section)
  local rows = {}
  appendPipelineRows(rows, game, section, mod)
  appendSettingRows(rows, section, mod)
  appendActionRows(rows, section, mod, game)
  if #rows == 0 then
    rows[1] = { label=uiLabel(mod, "NO SETTINGS"), right="N/A" }
  end
  return rows
end

-- A conditional row can change while this very page is open: moving 3D-BTL
-- from MAP to ARENA owns ARENA BG, and moving away removes it. Both the native
-- fallback and KASC guided lists read `items` every frame, so replace that
-- array in place while preserving their renderer-owned HELP row and cursor.
local function refreshConditionalRows(mod, menu, game, section, focusKey)
  if type(menu) ~= "table" or type(menu.items) ~= "table" then return false end
  local help
  for _, item in ipairs(menu.items) do
    if item and (item.value == "__vasc_help" or item.value == "__kasc_help") then
      help = item
      break
    end
  end
  local rows = sectionRows(mod, game, section)
  if help then rows[#rows + 1] = help end
  menu.items = rows
  menu.index = math.max(1, math.min(menu.index or 1, #rows))
  if focusKey then
    for i, item in ipairs(rows) do
      if item.settingKey == focusKey then menu.index = i break end
    end
  end
  clampNavigation(menu)
  if type(menu.__vascRememberNavigation) == "function" then
    menu:__vascRememberNavigation()
  end
  return true
end

local function newSettings(mod, game, opts)
  local sections = activeSections()
  local order = activeSectionOrder()
  local fallbackId = order[1] or "world"
  local id = opts and opts.section or fallbackId
  local section = sections[id] or sections[fallbackId] or SECTION_DEFS.world
  local rows = sectionRows(mod, game, section)
  local function change(item, direction, active)
    local changed = stepSetting(game, item, direction)
    if changed and item and (item.settingKey == "battles"
        or item.settingKey == "battleHudStyle") then
      refreshConditionalRows(mod, active, game, section, item.settingKey)
    end
    return changed
  end
  local function choose(item, active)
    if not item then return end
    if item.descriptor then return change(item, 1, active) end
    if item.screen then return mod.ui.push(game, item.screen) end
    if item.action == "stadiumRom" then
      local rom = config.stadiumRomMenu
      local ok, chosen = false, false
      if rom and type(rom.choose) == "function" then
        ok, chosen = pcall(rom.choose, game)
      end
      local valueOk, value = false, nil
      if rom and type(rom.value) == "function" then
        valueOk, value = pcall(rom.value, game)
      end
      item.right = valueOk and tostring(value or "CHOOSE") or "UNAVAILABLE"
      return ok and chosen ~= false
    end
    if item.action == "restore" then
      local done = restoreAll(game)
      item.right = done and (languageCode(mod) == "de" and "FERTIG" or "DONE")
                   or "N/A"
      return done
    end
    if item.action == "animations" then
      local latest = animationReceipt()
      item.right, item.help = uiValue(mod, latest.right), localized(mod, latest.help)
      return showHelp(mod, game, uiLabel(mod, "MOVE ANIMATIONS"), item.help)
    end
    if item.action == "rootHelp" then
      return showHelp(mod, game,
        languageCode(mod) == "de" and "VASC-START" or "VASC START HELP",
        localized(mod, ROOT_HELP))
    end
    if item.action == "version" or item.action == "info" then
      return showHelp(mod, game, item.label, item.help)
    end
  end
  local menu = guidedMenu(mod, game, {
    key="vasc_settings_" .. id,
    title=uiLabel(mod, section.title),
    helpTitle=uiLabel(mod, section.title) .. " HELP",
    help=localized(mod, section.help),
    rows=rows,
    footer=languageCode(mod) == "de"
      and "A:WAHL L/R:ÄNDERN ST/SEL:?"
      or "A:NEXT L/R:CHANGE ST/SEL:?",
    options={ pageJump=false, wrap=true },
    step=function(item, direction, active) return change(item, direction, active) end,
    onChoose=choose,
  })
  -- Native mobile file selection returns asynchronously. This page is not
  -- ModManagerState, whose poll wrapper normally consumes the picked ROM.
  -- The existing importer value() polls and attaches its build screen to the
  -- exact game owner; keep it live while this settings page is updating.
  local rom = config.stadiumRomMenu
  if id == "pokemon" and rom and type(rom.value) == "function"
      and menu and type(menu.update) == "function" then
    local update = menu.update
    function menu:update(...)
      local ok, value = pcall(rom.value, game)
      if ok then
        for _, item in ipairs(self.items or rows) do
          if item.action == "stadiumRom" then
            item.right = tostring(value or "CHOOSE")
          end
        end
      end
      return update(self, ...)
    end
  end
  return menu
end

-- Advanced composition remains a compact six-row page instead of exposing
-- three option rows for every sprite/HUD role in the general mod manager.
-- The controller owns persistence and classification; this menu only presents
-- its currently selected target using the same VASC-owned FireRed tree.
local function newBattleLayout(mod, game)
  local controller = config.battleLayout
  local language = languageCode(mod)
  local rows = controller and type(controller.menuRows) == "function"
    and controller.menuRows(language) or {
      { label="LAYOUT", right="N/A",
        help=language == "de"
          and "Die Kampf-Layoutsteuerung ist in diesem Build nicht verfügbar."
          or "Battle layout controls are unavailable in this build." },
    }
  local function refresh()
    if controller and type(controller.refreshRows) == "function" then
      controller.refreshRows(rows)
    end
  end
  local function change(item, direction)
    local changed = stepSetting(game, item, direction)
    if changed then refresh() end
    return changed
  end
  local function choose(item)
    if not item then return end
    if item.descriptor then return change(item, 1) end
    if not controller then return end
    local done = false
    if item.action == "layoutResetTarget"
        and type(controller.resetTarget) == "function" then
      done = controller.resetTarget(game)
    elseif item.action == "layoutResetAll"
        and type(controller.resetAll) == "function" then
      done = controller.resetAll(game)
    end
    if done then
      item.right = language == "de" and "FERTIG" or "DONE"
      refresh()
    end
    return done
  end
  local help = controller and type(controller.menuHelp) == "function"
    and controller.menuHelp(language)
    or (language == "de" and "Keine Layoutsteuerung verfügbar."
        or "No layout controls available.")
  refresh()
  return guidedMenu(mod, game, {
    key="vasc_battle_layout",
    title=uiLabel(mod, "BATTLE LAYOUT"),
    helpTitle=uiLabel(mod, "BATTLE LAYOUT") .. " HELP",
    help=help,
    rows=rows,
    footer=language == "de"
      and "A:WAHL L/R:ÄNDERN ST/SEL:?"
      or "A:NEXT L/R:CHANGE ST/SEL:?",
    options={ pageJump=false, wrap=true },
    step=change,
    onChoose=choose,
  })
end

local function mobileTraceStatus(mod)
  local mobileDiagnostic = config.mobileDiagnostic
  if type(mobileDiagnostic) ~= "table" and type(mod) == "table" then
    mobileDiagnostic = mod._vascMobileDiagnostic
  end
  if type(mobileDiagnostic) == "table" then
    local reader = type(mobileDiagnostic.report) == "function"
      and mobileDiagnostic.report or mobileDiagnostic.status
    if type(reader) == "function" then
      local ok, value = pcall(reader)
      if ok and type(value) == "table" then return value end
    end
  end
  return {
    build="VASC-RC12-M10-M11-CONVERGED-20260903",
    mode="UNAVAILABLE",
    source="THIS RUN",
    code="D00",
    generation="unknown",
    context="unavailable",
    checkpoint="mobile-trace-unavailable",
    caller="VascMenu",
    reason="status-api-unavailable",
    physicalPass=false,
  }
end

local function mobileTraceHelp(mod)
  local status = mobileTraceStatus(mod)
  local lines = {
    "SOURCE: " .. tostring(status.source or "THIS RUN"),
    "BUILD: " .. tostring(status.build or "unknown"),
    "MODE: " .. tostring(status.mode or "unknown"),
    "STATUS: " .. tostring(status.status or "unknown"),
    "PHASE: " .. tostring(status.phase or "unknown"),
    "CODE: " .. tostring(status.code or "D00"),
    "GEN: " .. tostring(status.generation or "unknown"),
    "CONTEXT: " .. tostring(status.context or "unknown"),
    "CHECKPOINT: " .. tostring(status.checkpoint or "unknown"),
    "CALLER: " .. tostring(status.caller or "unknown"),
    "REASON: " .. tostring(status.reason or "unknown"),
    "SEQ/OCC: " .. tostring(status.sequence or "-") .. "/"
      .. tostring(status.occurrence or "-"),
  }
  if status.firstFailureCode and status.firstFailureCode ~= "none" then
    lines[#lines + 1] = "FIRST FAILURE: "
      .. tostring(status.firstFailureCode) .. " / "
      .. tostring(status.firstFailureCheckpoint or "unknown")
  end
  if status.recoveryMode == true then
    lines[#lines + 1] = languageCode(mod) == "de"
      and "RECOVERY 2D: AKTIV (letzter Live-Lauf bleibt erhalten)"
      or "RECOVERY 2D: ACTIVE (last live run preserved)"
  end
  if tostring(status.code) == "D90" then
    lines[#lines + 1] = languageCode(mod) == "de"
      and "D90 ist kein physischer Sichtbarkeitsnachweis."
      or "D90 is not proof of physical visibility."
  end
  lines[#lines + 1] = languageCode(mod) == "de"
    and "BITTE DIESE SEITE FOTOGRAFIEREN."
    or "PLEASE PHOTOGRAPH THIS PAGE."
  return table.concat(lines, "\n")
end

local function newSupportLogs(mod, game)
  local diagnostics = config.diagnostics
  local language = languageCode(mod)
  local reproActive, deleteArmed = false, false

  local function status()
    if diagnostics and type(diagnostics.supportStatus) == "function" then
      local ok, value = pcall(diagnostics.supportStatus)
      if ok and type(value) == "table" then return value end
    end
    return {
      path=nil, readablePath=nil, recorderPath=nil,
      sessionId="unavailable", bytes=0, maxBytes=0,
      capped=false, alwaysOn=false, recording="FAILED",
      readableLog="UNAVAILABLE", export="UNAVAILABLE",
    }
  end

  local current = status()
  local rows = {
    {
      label=language == "de" and "AKTUELLES LOG" or "CURRENT LOG",
      action="supportPath",
      right=current.capped and "FULL"
        or (current.recording == "ACTIVE"
          and current.readableLog == "ACTIVE" and "VASC-LOGS" or "FAILED"),
      statusTone=(current.capped or current.recording ~= "ACTIVE"
          or current.readableLog ~= "ACTIVE")
        and "bad" or "good",
      help=language == "de"
        and "Zeigt die verifizierte lesbare .log-Datei im mod-eigenen VASC-Logs-Ordner, die Session-ID und die Speichergrenze."
        or "Show the verified readable .log file in the mod-private VASC-Logs folder, its session ID and size cap.",
    },
    {
      label=language == "de" and "REPRO MARKIEREN" or "MARK REPRO",
      action="supportRepro", right="BEGIN",
      help=language == "de"
        and "BEGIN/END setzt nur Marker im ohnehin laufenden Log; die Aufzeichnung wird nie ausgeschaltet."
        or "BEGIN/END only adds markers to the already running log; recording is never disabled.",
    },
    {
      label=language == "de" and "LOGS LÖSCHEN" or "DELETE LOGS",
      action="supportDelete", right="A=ARM",
      help=language == "de"
        and "Zweimal A löscht ausschließlich exakt erkannte VASC-Sessionlogs. Danach startet die Aufzeichnung sofort neu."
        or "Press A twice to delete only exact VASC session logs. Recording resumes immediately.",
    },
  }

  local function choose(item)
    if not item then return false end
    if item.action == "supportPath" then
      current = status()
      item.right = current.capped and "FULL"
        or (current.recording == "ACTIVE"
          and current.readableLog == "ACTIVE" and "VASC-LOGS" or "FAILED")
      item.statusTone = (current.capped or current.recording ~= "ACTIVE"
          or current.readableLog ~= "ACTIVE")
        and "bad" or "good"
      local body = table.concat({
        "FILE: " .. tostring(current.readablePath or current.path
          or "unavailable"),
        (language == "de" and "LESBAR: " or "READABLE: ")
          .. tostring(current.readableLog or "UNAVAILABLE")
          .. (current.readableError and (" / "
            .. tostring(current.readableError)) or ""),
        "RECORDER: " .. tostring(current.recorderPath or "unavailable"),
        "BACKEND: " .. tostring(current.backend or "unavailable"),
        "SESSION: " .. tostring(current.sessionId or "unavailable"),
        "SIZE: " .. tostring(current.bytes or 0) .. "/"
          .. tostring(current.maxBytes or 0),
        language == "de"
          and "ABLAGE: Mod-Ordner/VASC-Logs. Ein zusätzlicher Dateien-Export ist nicht erforderlich."
          or "LOCATION: mod folder/VASC-Logs. An additional Files export is not required.",
      }, "\n")
      return showHelp(mod, game,
        language == "de" and "FEHLERPROTOKOLL" or "SUPPORT LOG", body)
    end
    if item.action == "supportRepro" then
      if not (diagnostics and type(diagnostics.markRepro) == "function") then
        item.right = "N/A"
        return false
      end
      local state = reproActive and "end" or "begin"
      local ok, done = pcall(diagnostics.markRepro, state)
      if not ok or done == false then item.right = "FAILED" return false end
      reproActive = not reproActive
      item.right = reproActive and "END" or "BEGIN"
      return true
    end
    if item.action == "supportDelete" then
      if not deleteArmed then
        deleteArmed = true
        item.right = "A=CONFIRM"
        return true
      end
      deleteArmed = false
      local ok, done = false, false
      if diagnostics and type(diagnostics.deleteOwnLogs) == "function" then
        ok, done = pcall(diagnostics.deleteOwnLogs)
      end
      item.right = ok and done == true and "DONE" or "FAILED"
      return ok and done == true
    end
    return false
  end

  return guidedMenu(mod, game, {
    key="vasc_support_logs",
    title=language == "de" and "FEHLERPROTOKOLL" or "SUPPORT LOG",
    helpTitle=language == "de" and "FEHLERPROTOKOLL HILFE" or "SUPPORT LOG HELP",
    help=language == "de"
      and "VASC protokolliert jede Sitzung automatisch und begrenzt. Dieser Bildschirm schaltet Logging niemals ein oder aus."
      or "VASC records every session automatically with hard bounds. This screen never enables or disables logging.",
    rows=rows,
    footer=language == "de" and "A:WAHL START/SELECT:HILFE"
      or "A:CHOOSE START/SELECT:HELP",
    options={ pageJump=false, wrap=true },
    onChoose=choose,
  })
end

local function newPerformanceDiagnostics(mod, game)
  local diagnostics = config.diagnostics
  local monitor = config.performanceDiagnostics
  local language = languageCode(mod)
  if diagnostics and type(diagnostics.boot) == "function" then
    pcall(diagnostics.boot, game)
  end

  local function allowed()
    if not (diagnostics and type(diagnostics.enabled) == "function") then
      return false
    end
    local ok, enabled = pcall(diagnostics.enabled, game)
    return ok and enabled == true
  end

  local function measuredRows()
    if not allowed() then
      return {{ label="RC DIAGNOSTICS", right="LOCKED", statusTone="bad",
        help=language == "de" and "Zuerst den Maintainer-Code freischalten."
          or "Unlock the maintainer code first." }}
    end
    if not (monitor and type(monitor.rows) == "function") then
      return {{ label="PERFORMANCE", right="AUSGEFALLEN", statusTone="bad",
        help=language == "de" and "Der plattformübergreifende Monitor wurde nicht geladen."
          or "The cross-platform monitor did not load." }}
    end
    local ok, value = pcall(monitor.rows, language, diagnostics)
    if ok and type(value) == "table" then return value end
    return {{ label="PERFORMANCE", right="MESSFEHLER", statusTone="bad",
      help=tostring(value or "measurement failed") }}
  end

  local rows = measuredRows()
  rows[#rows + 1] = {
    label=language == "de" and "JETZT PROTOKOLLIEREN" or "LOG SNAPSHOT",
    action="performanceSnapshot", right="A=LOG",
    help=language == "de"
      and "Schreibt die aktuelle FPS-, Framezeit-, Speicher- und Renderer-Messung sofort in dieselbe laufende VASC-Logs-Session."
      or "Write current FPS, frame-time, memory and renderer measurements immediately into the same live VASC-Logs session.",
  }

  local function choose(item)
    if not item or item.action ~= "performanceSnapshot" then return false end
    if not allowed() or not (monitor
        and type(monitor.logSnapshot) == "function") then
      item.right, item.statusTone = "FAILED", "bad"
      return false
    end
    local ok, value = pcall(monitor.logSnapshot, diagnostics)
    item.right = ok and type(value) == "table" and "DONE" or "FAILED"
    item.statusTone = item.right == "DONE" and "good" or "bad"
    return item.right == "DONE"
  end

  local menu = guidedMenu(mod, game, {
    key="vasc_performance_diagnostics",
    title=language == "de" and "GERÄTE-MONITOR" or "DEVICE MONITOR",
    helpTitle=language == "de" and "GERÄTE-MONITOR HILFE"
      or "DEVICE MONITOR HELP",
    help=language == "de"
      and "Live-Messung für PC, iOS und Android. Rot markiert echte Ausfälle oder klar schlechte Messwerte. Es werden keine Grafikoptionen verändert."
      or "Live measurements for desktop, iOS and Android. Red marks real failures or clearly poor values. No graphics options are changed.",
    rows=rows,
    footer=language == "de" and "A:WAHL START/SELECT:HILFE"
      or "A:CHOOSE START/SELECT:HELP",
    options={ pageJump=true, wrap=true },
    onChoose=choose,
  })
  local baseUpdate = menu and menu.update
  local refreshCounter = 0
  if type(baseUpdate) == "function" then
    menu.update = function(self, ...)
      if monitor and type(monitor.observe) == "function" then
        pcall(monitor.observe)
      end
      refreshCounter = refreshCounter + 1
      if refreshCounter >= 15 and type(self.items) == "table" then
        refreshCounter = 0
        local fresh = measuredRows()
        for index, value in ipairs(fresh) do
          local target = self.items[index]
          if type(target) == "table" then
            target.label, target.right = value.label, value.right
            target.help, target.statusTone = value.help, value.statusTone
          end
        end
      end
      return baseUpdate(self, ...)
    end
  end
  return menu
end

-- Mobile trace/rearm live exclusively behind ADVANCED -> RC DIAGNOSTICS and
-- behind its four-wheel lock. The ordinary Voxel hub has no promotion flag,
-- and a forged/stale row still fails closed in choose(). The separate minimal
-- recovery marker remains always-on in Diagnostics; it is not exposed here.
local function supportSendRows(mod)
  return {
    {label=languageCode(mod)=="de" and "VASC-LOG SENDEN" or "SEND VASC LOG", action="sendVascSupport",
      help=languageCode(mod)=="de" and "VASC-Bericht mit verfügbaren Download-Fehlern senden. Vor dem Versand bestätigen."
        or "Send VASC evidence including available download errors. Confirm before sending."},
    {label=languageCode(mod)=="de" and "KASC-LOG SENDEN" or "SEND KASC LOG", action="sendKascSupport",
      help=languageCode(mod)=="de" and "KASC-Bericht mit verfügbaren Download-Fehlern senden. Vor dem Versand bestätigen."
        or "Send KASC evidence including available download errors. Confirm before sending."},
  }
end
local function openSupportSend(mod, game, item)
  local diagnostics=config.diagnostics
  local enabled=diagnostics and diagnostics.enabled and diagnostics.enabled(game)
  if not enabled then item.right="LOCKED";return false end
  local target=diagnostics
  if item.action=="sendKascSupport" then
    local ok,handle=pcall(function()return mod:find("kanto_ascendant")end)
    target=ok and handle and handle.exports and handle.exports.supportSessionLog or nil
  end
  if target and type(target.openSupportSend)=="function" then
    return target.openSupportSend(game,languageCode(mod)=="de")
  end
  return showHelp(mod,game,item.label,languageCode(mod)=="de"
    and "Der passende Mod mit Support-Versand ist nicht verfügbar."
    or "The matching mod with support sending is unavailable.")
end

local function newDiagnostics(mod, game)
  local diagnostics = config.diagnostics
  local mobileDiagnostic = config.mobileDiagnostic
  if type(mobileDiagnostic) ~= "table" and type(mod) == "table" then
    mobileDiagnostic = mod._vascMobileDiagnostic
  end
  local digits = { 0, 0, 0, 0 }
  local function unlocked()
    if not (diagnostics and type(diagnostics.enabled) == "function") then
      return false
    end
    local ok, enabled = pcall(diagnostics.enabled, game)
    return ok and enabled == true
  end
  local function performanceRow()
    return {
      label=languageCode(mod) == "de" and "GERÄTE-MONITOR"
        or "DEVICE MONITOR",
      action="performanceDiagnostics", right="LIVE",
      help=languageCode(mod) == "de"
        and "FPS, Framezeiten, Speicher, Renderer und VASC-Logs für PC, iOS und Android prüfen."
        or "Inspect FPS, frame times, memory, renderer and VASC-Logs on desktop, iOS and Android.",
    }
  end
  local function maintenanceRows()
    local trace = mobileTraceStatus(mod)
    local result = {
      {
        label="MOBILE TRACE", action="mobileTrace",
        right=tostring(trace.code or "D00"),
        help=languageCode(mod) == "de"
          and "Zeigt den aktuellen mobilen Voxel-Checkpoint. D90 ist kein physischer Sichtbarkeitsnachweis."
          or "Show the current mobile voxel checkpoint. D90 is not proof of physical visibility.",
      }
    }
    if trace.recoveryMode == true then
      result[#result + 1] = {
        label="REARM LIVE TEST", action="mobileTraceRearm", right="RESTART",
        help=languageCode(mod) == "de"
          and "Löscht nach A nur den unvollendeten Recovery-Marker. RECOVERY 2D bleibt bis zum Neustart aktiv."
          or "A clears only the unfinished recovery marker. RECOVERY 2D remains active until restart.",
      }
    end
    for _, row in ipairs(supportSendRows(mod)) do result[#result+1]=row end
    return result
  end
  local rows = {}
  if unlocked() then
    for _, row in ipairs(maintenanceRows()) do rows[#rows + 1] = row end
  end
  for index = 1, 4 do
    rows[#rows + 1] = {
      label="CODE " .. tostring(index), right="0",
      digit=index,
      help=languageCode(mod) == "de"
        and "Mit LINKS/RECHTS oder A diese Stelle ändern."
        or "Change this digit with LEFT/RIGHT or A.",
    }
  end
  local applyRow = {
    label="APPLY", action="diagnosticsApply", right="LOCKED",
    help=languageCode(mod) == "de"
      and "Code prüfen und das Diagnoseprotokoll aktivieren."
      or "Check the code and enable the diagnostic log.",
  }
  rows[#rows + 1] = applyRow
  if unlocked() then
    applyRow.right = "ACTIVE"
    rows[#rows + 1] = performanceRow()
  end
  local function revealMaintenance(activeMenu)
    if type(activeMenu) ~= "table" or type(activeMenu.items) ~= "table" then
      return false
    end
    for _, row in ipairs(activeMenu.items) do
      if row.action == "performanceDiagnostics"
          or row.action == "mobileTrace"
          or row.action == "mobileTraceRearm" then
        return false
      end
    end
    local additions = maintenanceRows()
    for index = #additions, 1, -1 do
      table.insert(activeMenu.items, 1, additions[index])
    end
    activeMenu.index = (tonumber(activeMenu.index) or 1) + #additions
    local hasPerformance = false
    local applyIndex
    for index, row in ipairs(activeMenu.items) do
      if row.action == "performanceDiagnostics" then hasPerformance = true end
      if row.action == "diagnosticsApply" then applyIndex = index end
    end
    if not hasPerformance and applyIndex then
      table.insert(activeMenu.items, applyIndex + 1, performanceRow())
    end
    clampNavigation(activeMenu)
    return #additions > 0
  end
  local function change(item, direction)
    if not (item and item.digit) then return false end
    local index = item.digit
    digits[index] = (digits[index] + (direction or 1)) % 10
    item.right = tostring(digits[index])
    return true
  end
  local function choose(item, activeMenu)
    if not item then return end
    if item.digit then return change(item, 1) end
    if item.action == "sendVascSupport" or item.action == "sendKascSupport" then
      return openSupportSend(mod, game, item)
    end
    if item.action == "performanceDiagnostics" then
      if not unlocked() then item.right = "LOCKED" return false end
      return mod.ui.push(game, "VascPerformanceDiagnostics")
    end
    if item.action == "mobileTrace" then
      if not unlocked() then item.right = "LOCKED" return false end
      local status = mobileTraceStatus(mod)
      item.right = tostring(status.code or "D00")
      return showHelp(mod, game, "MOBILE TRACE", mobileTraceHelp(mod))
    end
    if item.action == "mobileTraceRearm" then
      if not unlocked() then item.right = "LOCKED" return false end
      local ok, done, reason = false, false, "rearm-api-unavailable"
      if type(mobileDiagnostic) == "table"
          and type(mobileDiagnostic.rearm) == "function" then
        ok, done, reason = pcall(mobileDiagnostic.rearm)
      end
      item.right = ok and done == true and "ARMED" or "FAILED"
      local body = ok and done == true
        and (languageCode(mod) == "de"
          and "Live-Test ist neu scharf. App vollständig beenden und neu starten; bis dahin bleibt RECOVERY 2D aktiv."
          or "Live test rearmed. Fully quit and restart the app; RECOVERY 2D remains active until then.")
        or ((languageCode(mod) == "de" and "Neu schärfen fehlgeschlagen: "
          or "Rearm failed: ") .. tostring(reason or done))
      return showHelp(mod, game, "REARM LIVE TEST", body)
    end
    if item.action == "diagnosticsApply" then
      local entered = table.concat(digits)
      if diagnostics and entered == tostring(diagnostics.CODE)
          and type(diagnostics.setEnabled) == "function" then
        local ok, enabled = pcall(diagnostics.setEnabled, game, true)
        if ok and enabled == true and unlocked() then
          item.right = "ACTIVE"
          revealMaintenance(activeMenu)
          return showHelp(mod, game, "RC DIAGNOSTICS",
            languageCode(mod) == "de"
              and ("Aktiv. Datei: " .. tostring(diagnostics.FILE)
                .. " (VASC-Speicherordner).")
              or ("Active. File: " .. tostring(diagnostics.FILE)
                .. " (VASC storage directory)."))
        end
      end
      item.right = "DENIED"
      return false
    end
  end
  return guidedMenu(mod, game, {
    key="vasc_diagnostics", title="RC DIAGNOSTICS",
    helpTitle="RC DIAGNOSTICS HELP",
    help=languageCode(mod) == "de"
      and "Vierstelligen Maintainer-Code eingeben. Das Protokoll enthält nur VASC-Entscheidungen, keine Spielstände."
      or "Enter the four-digit maintainer code. The log contains VASC decisions, not save data.",
    rows=rows,
    footer=languageCode(mod) == "de"
      and "A:+1 L/R:ÄNDERN" or "A:+1 L/R:CHANGE",
    options={ pageJump=false, wrap=true },
    step=change, onChoose=choose,
  })
end

restoreAll = function(game)
  local okContent, content = pcall(function()
    return V and type(V.require) == "function" and V.require("LocalContent")
  end)
  if okContent and content and type(content.select) == "function" then
    local done = content.select("VASC_DEFAULT", game)
    return done == true
  end
  local okMusic, music = pcall(function()
    return V and type(V.require) == "function" and V.require("LocalMusic")
  end)
  local okSprites, sprites = pcall(function()
    return V and type(V.require) == "function" and V.require("LocalSprites")
  end)
  local musicDone = okMusic and music
    and type(music.backToDefault) == "function" and music.backToDefault(game)
  local spritesDone = okSprites and sprites
    and type(sprites.backToDefault) == "function" and sprites.backToDefault(game)
  return musicDone == true and spritesDone == true
end

animationReceipt = function()
  if type(config.animationStatus) ~= "function" then
    return {
      right="PENDING",
      help={
        en="Move animation status is not available yet.",
        de="Der Status der Attackenanimationen ist noch nicht verfügbar.",
      },
    }
  end
  local ok, status = pcall(config.animationStatus)
  if not ok or type(status) ~= "table" then
    return {
      right="PENDING",
      help={
        en="Move animation status is not available yet.",
        de="Der Status der Attackenanimationen ist noch nicht verfügbar.",
      },
    }
  end
  return status
end

local function newHub(mod, game)
  local rows = {}
  local sections = activeSections()
  for _, id in ipairs(activeSectionOrder()) do
    local section = sections[id]
    if type(section) == "table" then
      rows[#rows + 1] = {
        label=uiLabel(mod, section.title or tostring(id):upper()),
        section=id,
        help=localized(mod, section.help),
      }
    end
  end
  if #rows == 0 then
    rows[1] = { label=uiLabel(mod, "NO SETTINGS"),
      help=languageCode(mod) == "de" and "Keine VASC-Bereiche verfügbar."
        or "No VASC sections are available." }
  end
  rows[#rows + 1] = {
    label="Resets to Factory", factoryReset=true,
    help=languageCode(mod) == "de"
      and "VASC-Auslieferungswerte inklusive HD-Sprites wiederherstellen. Spielstände und Downloads bleiben erhalten. Deaktivierte Module benötigen einen Spielneustart."
      or "Restore shipped VASC settings including HD sprites. Saves and downloads are kept. Disabled modules require a game reload.",
  }
  local menu = guidedMenu(mod, game, {
    key="vasc_root",
    title="VOXEL ASCENDANT",
    helpTitle=languageCode(mod) == "de" and "VASC-START HELP"
      or "VASC START HELP",
    help=localized(mod, config.rootHelp or ROOT_HELP),
    rows=rows,
    footer=languageCode(mod) == "de"
      and "A:ÖFFNEN ST/SEL:HILFE" or "A:OPEN ST/SEL:HELP",
    options={ pageJump=true, wrap=true },
    onChoose=function(item)
      if not item then return end
      if item.factoryReset then
        local ok, result, reason = pcall(function()
          local source = assert(mod:read("shared/FactoryReset.lua"))
          local reset = assert((loadstring or load)(source, "@FactoryReset"))()
          return reset.apply(mod, game, config)
        end)
        local done = ok and result == true
        local message = done and (languageCode(mod) == "de"
          and "Auslieferungswerte wiederhergestellt. HD-Sprites sind eingeschaltet. Lade das Spiel neu, damit auch zuvor deaktivierte Module wieder starten. Spielstände und Downloads bleiben erhalten."
          or "Factory settings restored. HD sprites are enabled. Reload the game to restart previously disabled modules. Saves and downloads are kept.")
          or ("Reset failed: " .. tostring(ok and reason or result))
        return showHelp(mod, game, "Resets to Factory", message)
      end
      if item.section then
        return mod.ui.push(game, "VascSettings", { section=item.section })
      end
    end,
  })
  -- The guided list appends HELP; factory reset belongs below that row too.
  for i, item in ipairs(menu.items or {}) do
    if item.factoryReset then
      table.remove(menu.items, i)
      menu.items[#menu.items + 1] = item
      break
    end
  end
  -- The root needs the full 137 px row budget so both 17-glyph category
  -- names fit verbatim. VascMenuStyle moves only this cursor two pixels left.
  menu.__voxelAscendantRoot = true
  -- On a fresh opening, return directly to the last section the player
  -- actually entered.  The guard only fires while this new root is the top
  -- state; returning from a child page therefore never bounces straight back
  -- into it.  Disabling resumeLastSection keeps the remembered root focus but
  -- skips the automatic one-level return.
  local baseUpdate = menu.update
  if type(baseUpdate) == "function" then
    menu.update = function(self, ...)
      if not self.__vascResumeChecked then
        self.__vascResumeChecked = true
        local state = self.__vascNavigation
        local wanted = config.resumeLastSection ~= false and state
          and state.nav and state.nav.lastSection or nil
        local stack = self.game and self.game.stack
        local isTop = stack and type(stack.top) == "function"
          and stack:top() == self
        if wanted and isTop then
          for index, item in ipairs(self.items or {}) do
            if item.section == wanted then
              self.index = index
              clampNavigation(self)
              rememberNavigation(self)
              mod.ui.push(game, "VascSettings", { section=wanted })
              return true
            end
          end
        end
      end
      return baseUpdate(self, ...)
    end
  end
  return menu
end

function VascMenu.decorateActive(mod, screen)
  local ui = menuUi(mod)
  if ui and type(ui.decorate) == "function" then return ui.decorate(screen) end
  return screen
end

-- Public, generation-neutral bridge consumed by the optional KASC adapter.
-- It exposes presentation only: KASC continues to own its menu items, input,
-- callbacks, focus and scroll state. Ordinary game/Bag/PC lists never enter
-- this API because the caller must supply KASC's explicit focus-help marker.
function VascMenu.menuSkinBridge(mod)
  if type(mod) ~= "table" then return nil end
  local cached = menuSkinBridgeByMod[mod]
  if cached then return cached end
  local bridge = {
    schema="voxel-ascendant/kasc-menu-skin/v1",
    apiVersion=1,
  }
  function bridge.currentSkin()
    local ui = standaloneUi(mod)
    if ui and type(ui.currentSkin) == "function" then
      return ui.currentSkin()
    end
    return configuredMenuSkin(mod)
  end
  function bridge.decorateGuided(menu, provider, requestedRows)
    local ui = standaloneUi(mod)
    if not (ui and type(ui.bridgeFocusHelp) == "function") then
      return menu, false
    end
    return ui.bridgeFocusHelp(menu, provider, requestedRows), true
  end
  function bridge.showHelp(game, title, body)
    return showHelp(mod, game, title, body)
  end
  menuSkinBridgeByMod[mod] = bridge
  return bridge
end

function VascMenu.install(mod, opts)
  config = opts or config
  config.settings = config.settings or {}
  local screens = mod and mod.content and mod.content.screens
  if not screens or type(screens.register) ~= "function" then return false end
  screens:register("VascMenu", {
    new=function(game) return newHub(mod, game) end,
  })
  screens:register("VascPokemonHdDownloads", {
    new=function(game)
      local source=assert(mod:read("lib/HdContentMenu.lua"))
      local DownloadMenu=assert((loadstring or load)(source,"@HdContentMenu"))()
      return DownloadMenu.new(mod,game,guidedMenu,languageCode(mod)=="de")
    end,
  })
  screens:register("VascPokemonHdOffer", {
    new=function(game,spec)
      local source=assert(mod:read("lib/HdContentMenu.lua"))
      return assert((loadstring or load)(source,"@HdContentMenu"))().offer(mod,game,guidedMenu,languageCode(mod)=="de",spec)
    end,
  })
  screens:register("VascSettings", {
    new=function(game, screenOpts) return newSettings(mod, game, screenOpts) end,
  })
  screens:register("VascBattleLayout", {
    new=function(game) return newBattleLayout(mod, game) end,
  })
  screens:register("VascSupportLogs", {
    new=function(game) return newSupportLogs(mod, game) end,
  })
  screens:register("VascDiagnostics", {
    new=function(game) return newDiagnostics(mod, game) end,
  })
  screens:register("VascPerformanceDiagnostics", {
    new=function(game) return newPerformanceDiagnostics(mod, game) end,
  })
  screens:register("VascHelp", {
    new=function(game, helpOpts) return fallbackHelp(mod, game, helpOpts) end,
  })
  return true
end

VascMenu._newHub = newHub
VascMenu._newSettings = newSettings
VascMenu._newBattleLayout = newBattleLayout
VascMenu._newSupportLogs = newSupportLogs
VascMenu._newDiagnostics = newDiagnostics
VascMenu._newPerformanceDiagnostics = newPerformanceDiagnostics
VascMenu._findAscendantUi = findAscendantUi
VascMenu._standaloneUi = standaloneUi
VascMenu._stepSetting = stepSetting
VascMenu._refreshConditionalRows = refreshConditionalRows
VascMenu._settingEntryForKey = settingEntryForKey
VascMenu._configuredMenuSkin = configuredMenuSkin
VascMenu._stableItemKey = stableItemKey
VascMenu._navigationState = navigationState
VascMenu._rememberNavigation = rememberNavigation
VascMenu._persistNavigation = persistNavigation
VascMenu._qaBeginNavigationIsolation = beginQaNavigationIsolation
VascMenu.restoreAll = restoreAll
VascMenu.showHelp = showHelp
VascMenu.sections = SECTION_DEFS
VascMenu.pages = PAGES
VascMenu.NAVIGATION_KEY = NAVIGATION_KEY
VascMenu.MENU_SKIN_BRIDGE_SCHEMA = "voxel-ascendant/kasc-menu-skin/v1"

return VascMenu
