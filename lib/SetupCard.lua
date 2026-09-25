-- Your Look / Dein Look v3: draft-only setup; existing settings retain ownership.
local V=...
local L=V.require('SetupLocale').text
local M={VERSION=3};local Screen={isOpaque=true};Screen.__index=Screen
local ID='VOXEL_ASCENDANT'
local finishKeys={'apo_living_follower_animation','apo_pokemon_card_style','apo_voxel_pokemon_finish','apo_actor_voxel_grid','apo_actor_voxel_cubes','apo_atmospheric_sprite_shading'}
local function copy(t)local o={};for k,v in pairs(t or {})do o[k]=type(v)=='table' and copy(v) or v end;return o end
local function restoreTable(target,snapshot)
 for k in pairs(target)do if snapshot[k]==nil then target[k]=nil end end
 for k,v in pairs(snapshot)do if type(v)=='table'and type(target[k])=='table'then restoreTable(target[k],v)else target[k]=type(v)=='table'and copy(v)or v end end
end
local function trvalue(v)if v==true then return L("On",'An') elseif v==false then return L("Off",'Aus') else return tostring(v)end end
local function json()return V.require('CobblemonJson')end
local function storageName(game)return 'dein-look/v1' end
function M.receipt(game)
 local d=V.mod.storage:read(game,storageName(game));return type(d)=='table' and d or {}
end
local function persist(self,done)
 local d={version=M.VERSION,done=done==true,page=self.page,draft=self.draft,kasc=self.kasc,wilds=self.wilds}
 local ok,written,err=pcall(V.mod.storage.write,V.mod.storage,self.game,storageName(self.game),d)
 if not ok or written~=true then
  self.message=L('Could not save setup. Keep this screen open and retry: ','Einrichtung konnte nicht gespeichert werden. Hier bleiben und erneut versuchen: ')..tostring(ok and err or written)
  return false
 end
 return true
end
local common=L("Change later: F3 opens VASC quick help. All options are available in the main VASC menu; KASC options are in the main KASC menu. You can reopen Your Look at any time.",'Später ändern: F3 öffnet die VASC-Schnellhilfe. Alle Optionen findest du im großen VASC-Menü; KASC-eigene Optionen im großen KASC-Menü. „Dein Look“ lässt sich erneut öffnen.')
local sourceChoices={{L("Original / game",'Original / Spiel'),'classic'},{L("MMO sprites",'MMO-Sprites'),'pokemmo'},{'Full HD','full_hd'},{'Stadium 2','stadium2'},{'Cobblemon','cobblemon'}}
local sourceHelp={classic=L("Keeps the existing game graphics. The active game or KASC provider determines the exact sprite style.",'Die vorhandene Spielgrafik bleibt erhalten. Der aktive Spiel-/KASC-Anbieter bestimmt den genauen Sprite-Look.'),pokemmo=L("MMO-style pixel art. Requires the matching sprite pack; missing species use an available fallback.",'Pixelgrafiken im MMO-Stil. Das passende Spritepaket muss vorhanden sein; fehlende Arten verwenden eine verfügbare Ersatzgrafik.'),full_hd=L("Detailed sprite artwork, not freely rotating 3D models. Animations require the matching HD packs.",'Detailreiche Spritegrafiken, keine frei drehbaren 3D-Modelle. Animationen benötigen die passenden HD-Pakete.'),stadium2=L("Actual Stadium 2 models. Requires a working local ROM import. Missing models and Shiny variants use fallback graphics.",'Echte Stadium-2-Modelle. Erfordert einen nutzbaren lokalen ROM-Import. Fehlende Modelle und Shiny-Varianten nutzen Ersatzgrafiken.'),cobblemon=L("Block-style 3D Pokémon with animations from the bundled Cobblemon pack. Availability depends on species and variant.",'Blockartige 3D-Pokémon mit Animationen aus dem mitgelieferten Cobblemon-Paket. Verfügbarkeit hängt von Art und Variante ab.')}
function M.new(game,settings,opts)
 local self=setmetatable({game=game,page=1,index=1,time=0,draft={},initial={},settings={},pages={},species=2,confirmed={},opts=opts or {}},Screen)
 self.kasc=game.mods and game.mods.exports and game.mods.exports.kanto_ascendant~=nil
 self.wilds=self.kasc or game.mods and game.mods.exports and game.mods.exports.overworld_wild_spawns~=nil
 for _,row in ipairs(settings or {})do local s=row[1];if s and s.key and type(s.values)=="table" and #s.values>0 then self.settings[s.key]=s;self.initial[s.key]=s:get();self.draft[s.key]=s:get()end end
 self.preview=V.require('SetupPreview').new(game)
 local function page(id,title,description,rows,kind)
  self.pages[#self.pages+1]={id=id,title=title,description=description,rows=rows or {},kind=kind};return self.pages[#self.pages]
 end
 local function row(key,label,help,choices)
  if not self.settings[key] then return {label=label,help=L("Not available in this version.",'In dieser Version nicht verfügbar.'),disabled=true}end
  local s=self.settings[key];local c=choices or {};if not choices then for i,v in ipairs(s.values)do c[#c+1]={V.require('SetupLocale').choice(s.labels[i] or trvalue(v)),v}end end
  return {key=key,label=label,help=help,choices=c}
 end
 local function custom(key,label,help,choices,default)
  self.draft[key]=default;return {key=key,label=label,help=help,choices=choices}
 end
 page('welcome',L("Your adventure. Your look.",'Dein Abenteuer. Dein Look.'),L("Step by step: characters, Pokémon, Pokédex, battles and the world. Choose on the left; see previews and explanations on the right. Everything stays a draft until you apply it.",'Schritt für Schritt: Figuren, Pokémon, Pokédex, Kampf und Spielwelt. Links wählst du, rechts siehst du Vorschau und Erklärung. Bis zum Abschluss bleibt alles ein Entwurf.'),{
  {label=L("Start setup",'Einrichtung beginnen'),action='next',help=L("Walk through all active areas. Your existing settings are preselected.",'Alle aktiven Bereiche gemeinsam durchgehen. Bestehende Einstellungen sind vorausgewählt.')},
  {label=L("Keep current settings",'Aktuelle Einstellungen behalten'),action='keep',help=L("Finishes setup without changing graphics. Reopen it any time in the main VASC menu.",'Beendet die Einrichtung ohne Grafikänderung. Später jederzeit im großen VASC-Menü erneut öffnen.')},
  {label=L("Later / save draft",'Später / Entwurf speichern'),action='later',help=L("Resume later from the Ascendant menu. No graphics settings are applied.",'Später im Ascendant-Menü an dieser Stelle fortsetzen. Es werden keine Grafikoptionen übernommen.')}},'welcome')
 page('people',L("Which character style do you prefer?",'Welchen Figuren-Look magst du?'),L("For your player and NPCs. This live version uses one shared character style. Your KASC identity and clothing stay the same.",'Für Spielfigur und NPCs. Diese Live-Version verwendet einen gemeinsamen Figurenstil. Deine in KASC gewählte Identität und Kleidung bleiben erhalten.'),{
  row('apo_enabled',L("Overworld graphics Card",'Oberwelt-Grafik-Card'),L("Main switch for the integrated character and Pokémon presentation. Changing this switch requires a game restart.",'Hauptschalter für die integrierte Figuren- und Pokémon-Darstellung. Nach Änderung dieses Hauptschalters muss das Spiel neu gestartet werden.')),
  row('apo_hd_walking_sprites',L("HD characters",'HD-Figuren'),L("Off: original 2D without dialogue poses. On: HD or Voxel HD from the next choice, with dialogue poses enabled automatically.",'Aus: Original-2D ohne Dialogposen. An: HD oder Voxel-HD aus der folgenden Auswahl, mit automatisch aktiven Dialogposen.')),
  row('apo_human_art_style',L("Art style",'Grafikstil'),L("HD uses drawn characters; Voxel uses the installed character pack. Characters without Voxel artwork keep their HD graphics.",'HD nutzt die gezeichneten Figuren; Voxel nutzt das vorhandene Figurenpaket. Einzelne Figuren ohne Voxel-Grafik behalten ihre HD-Grafik.')),
  row('apo_card_animation_mode',L("Movement",'Bewegung'),L("Natural: new walking and idle movement. Classic: previous Card animation. This setting is shared by the Cards.",'Natürlich: neuer Gang und Ruhebewegungen. Klassisch: bisherige Kartenanimation. Diese Einstellung gilt gemeinsam für die Karten.')),
  row('voxelCharacterCardEnabled',L("Allow Voxel character style",'Voxel-Look für Figuren erlauben'),L("On: Voxel becomes available as an art style. The look needs both HD characters ON and VOXEL selected. Off: uses HD instead. Identity, clothing and gameplay stay the same.",'An: Du kannst oben bei Grafikstil „Voxel“ wählen. Erst mit HD-Figuren AN und Grafikstil VOXEL wird der Look sichtbar. Aus: Statt Voxel wird HD verwendet. Identität, Kleidung und Spielabläufe bleiben erhalten.'),{{L("On: Voxel available",'An: Voxel auswählbar'),true},{L("Off: HD instead of Voxel",'Aus: HD statt Voxel'),false}}),
  row('apo_voxel_character_finish',L("HD characters: surface depth (relief)",'HD-Figuren: plastische Tiefe (Relief)'),L("On: HD artwork sits on four gently curved surfaces for added depth. Off: a flat image. This is not a full 3D model. Voxel characters are unaffected: their look is already painted in. This preview does not show the effect.",'An: Die HD-Grafik liegt auf vier leicht gewölbten Flächen und kann plastischer wirken. Aus: flache Bildfläche. Kein vollständiges 3D-Modell. Bei Voxel-Figuren ohne Wirkung: Ihr Look ist bereits eingezeichnet. Diese Vorschau zeigt den Effekt nicht.'),{{L("On: gently curved",'An: leicht gewölbt'),true},{L("Off: flat image",'Aus: flache Bildfläche'),false}}),
  {label=L("Dialogue poses: automatic for your style",'Dialogposen: automatisch zum Figurenstil'),help=L("Automatically on for HD and Voxel HD; off for original 2D. Characters with dialogue animations use their conversation poses. Others keep their normal appearance.",'Bei HD und Voxel-HD automatisch an; bei Original-2D aus. Figuren mit vorhandenen Dialoganimationen nutzen ihre Gesprächsposen. Figuren ohne passende Animation behalten ihre normale Darstellung.')}},'people')
 page('base',L("Your shared Pokémon style",'Dein Pokémon-Grundstil'),L("Choose a base style and the areas it should apply to. Followers, wild Pokémon, towns and Wilds towns remain individually adjustable. Battles and the Pokédex are separate.",'Wähle einen Grundstil und die Bereiche, die ihn erhalten sollen. Begleiter, Wildnis, Städte und Wilds-Städte bleiben einzeln anpassbar. Kampf und Pokédex sind separat.'),{
  custom('_base',L("Base style",'Grundstil'),L("Choose the look first. Below, each area shows its current draft and target. Only included areas change when you apply the preset.",'Wähle zuerst den Look. Darunter siehst du je Bereich den bisherigen Entwurf und das Ziel. Nur einbezogene Bereiche werden beim Vorbelegen geändert.'),sourceChoices,'cobblemon'),
  {label=L("Preset selected areas",'Ausgewählte Bereiche vorbelegen'),action='base',help=L("Applies the base style only to the included areas below. Other areas keep their drafts. Battles and the Pokédex remain independent.",'Überträgt den Grundstil nur auf die unten einbezogenen Bereiche. Nicht gewählte Bereiche behalten ihren Entwurf. Kampf und Pokédex bleiben unabhängig.')}},'pokemon')
 self.contexts={{'follower',L("Your follower",'Dein Begleiter'),L("The Pokémon following you. Its selection and movement are still controlled by the follower provider.",'Das Pokémon, das dir folgt. Auswahl und Bewegung bestimmt weiterhin der Begleiter-Anbieter.'),'apo_follower_sprite_source','apo_hd_pokemon_followers'},
 {'wild',L("Wild Pokémon",'Wilde Pokémon'),L("Visible Pokémon in grass and caves. Changes their graphics, not spawn rates or encounter rules.",'Sichtbare Pokémon in Gras und Höhlen. Diese Auswahl verändert ihre Grafik, nicht Häufigkeit oder Begegnungsregeln.'),'apo_grass_pokemon_sprite_source','apo_hd_pokemon_grass'},
 {'town',L("Town and indoor Pokémon",'Stadt- und Gebäude-Pokémon'),L("Fixed Pokémon in houses or towns, for example. Story and behaviour stay the same.",'Fest platzierte Pokémon, beispielsweise in Häusern oder Städten. Story und Verhalten bleiben erhalten.'),'apo_city_pokemon_sprite_source','apo_hd_pokemon_city'}}
 if self.wilds then self.contexts[#self.contexts+1]={'wildstown',L("Wilds town Pokémon",'Wilds-Stadt-Pokémon'),L("Peaceful town Pokémon spawned by Wilds. This is separate from fixed town Pokémon.",'Friedliche, von Wilds erzeugte Stadt-Pokémon. Dies ist eine eigene Auswahl neben den fest platzierten Stadt-Pokémon.'),'apo_wilds_town_pokemon_sprite_source','apo_hd_pokemon_wilds_towns'}end
 for _,c in ipairs(self.contexts)do
  self.draft['_include_'..c[1]]=true
  local style=self.draft[c[5]]==false and 'classic' or self.draft[c[4]]
  if style=='hd' then style='inherit' end
  local choices=copy(sourceChoices);table.insert(choices,1,{L("Keep model priority",'Modellreihenfolge beibehalten'),'inherit'})
  local r=custom('_'..c[1], L("Art style",'Grafikstil'),c[3],choices,style or 'inherit');r.context=c
  page(c[1],c[2],c[3],{r},'pokemon')
 end
 page('finish',L("Optional refinements",'Optionale Feineinstellungen'),L("Not required to get started: keep existing values or open details. These effects change supported sprites; true 3D models have their own surfaces.",'Für den Einstieg nicht nötig: vorhandene Werte behalten oder Details öffnen. Diese Effekte verändern unterstützte Sprites; echte 3D-Modelle haben eigene Oberflächen.'),{
  row('apo_living_follower_animation',L("Animations",'Animationen'),L("Plays available walking, flying and idle animations. Does not download missing animation packs.",'Spielt vorhandene Lauf-, Flug- und Ruheanimationen. Fehlende Animationspakete werden dadurch nicht heruntergeladen.')),
  row('apo_pokemon_card_style',L("HD outlines",'HD-Konturen'),L("Outlines for supported Full HD sprites only. No effect on MMO sprites or true 3D models.",'Konturen nur für unterstützte Full-HD-Sprites. Keine Wirkung auf MMO-Sprites oder echte 3D-Modelle.')),
  row('apo_voxel_pokemon_finish',L("Sprite relief",'Sprite-Relief'),L("Gently curves compatible Pokémon sprite surfaces to add depth. Off: flat artwork. Not a full 3D model; no effect on Cobblemon. Check it in the world comparison.",'Wölbt kompatible Pokémon-Spriteflächen leicht und lässt sie plastischer wirken. Aus: flache Grafik. Kein vollständiges 3D-Modell; keine Wirkung auf Cobblemon. Im Weltvergleich prüfen.')),
  row('apo_actor_voxel_grid',L("Character voxel grid",'Figuren-Voxelraster'),L("Breaks supported sprite characters into a visible block grid. Choose humans, Pokémon or both. May change fine detail. Independent of artwork source, trees and buildings. Check it in the world comparison.",'Zerlegt unterstützte Spritefiguren in ein sichtbares Blockraster. Wähle Menschen, Pokémon oder beide. Kann feine Bilddetails verändern. Keine neue Grafikquelle und unabhängig von Bäumen oder Gebäuden. Im Weltvergleich prüfen.')),
  row('apo_actor_voxel_cubes',L("Voxel depth",'Voxel-Tiefe'),L("Depth of the character grid. Only applies when the grid is enabled.",'Tiefe des Figurenrasters. Wirkt nur, wenn das Raster eingeschaltet ist.')),
  row('apo_atmospheric_sprite_shading',L("Character scene shading",'Figuren-Szenenlicht'),L("Adapts supported HD characters to the time of day and weather. Turn off if colours look wrong.",'Passt unterstützte HD-Figuren an Tageszeit und Wetter an. Bei verfälschten Farben ausschalten.'))},'pokemon')
 page('dex',L("Pokémon in the Pokédex",'Pokémon im Pokédex'),L("The Pokédex has its own image source. This does not change followers or battles. Applies to the modern VASC Pokédex.",'Der Pokédex erhält eine eigene Bildquelle. Diese Wahl verändert weder Begleiter noch Kampf. Die Bildquelle gilt für den modernen VASC-Pokédex.'),{
  row('pokedexStyle',L("Pokédex view",'Pokédex-Ansicht'),L("VASC: wide, modern Pokédex. Game default: the view provided by the game or KASC, using its own settings.",'VASC: breiter moderner Pokédex. Spielstandard: die vom Spiel oder KASC bereitgestellte Ansicht; deren eigene Einstellungen gelten.'),{{L("Modern VASC Pokédex",'Moderner VASC-Pokédex'),'modern'},{L("Game default / KASC",'Spielstandard / KASC'),'game'}}),
  row('modernDexSpriteSource',L("Pokémon images in the VASC Dex",'Pokémon-Bilder im VASC-Dex'),L("Crystal: KASC Crystal graphics. Active style: existing sprite provider. Original: game graphics. HD: animated images from an installed HD pack. Missing images use an available fallback.",'Crystal: KASCs Crystal-Grafiken. Aktiver Stil: vorhandener Sprite-Anbieter. Original: Spielgrafik. HD: animierte HD-Bilder mit installiertem Paket. Fehlende Bilder nutzen den verfügbaren Ersatz.'),{{L("Crystal sprites (KASC)",'Crystal-Sprites (KASC)'),'kasc_crystal'},{L("Active sprite style",'Aktiver Sprite-Stil'),'active'},{L("Original game graphics",'Originale Spielgrafik'),'game'},{L("Animated HD",'HD animiert'),'hd'}})},'dex')
 local stage=V.require('OverworldBattle').setting.key
 page('battle',L("Which battle style do you prefer?",'Welchen Kampfstil bevorzugst du?'),L("The battle setting and Pokémon models are independent. Your overworld choice does not change this page.",'Kampfkulisse und Pokémon-Modelle sind unabhängig. Deine Oberwelt-Auswahl verändert diese Seite nicht.'),{
  row(stage,L("Battle setting",'Kampfkulisse'),L("MAP: battle on nearby world terrain. ARENA: a designed arena matching the location. DISCS: two platforms. TERRARIUM: a separate diorama. Classic: the original battle view.",'MAP: Kampf auf nahegelegenem Weltgelände. ARENA: gestaltete, ortsbezogene Arena. DISCS: zwei Plattformen. TERRARIUM: eigenständige Diorama-Kulisse. Klassisch: ursprüngliche Kampfansicht.'),{{L("MAP – in the game world",'MAP – in der Spielwelt'),true},{'Arena','arena'},{L("Discs – platforms",'Discs – Plattformen'),'flatB'},{'Terrarium','terarrium'},{L("Classic battle",'Klassischer Kampf'),false}}),
  row('pokemonModelSkin',L("Pokémon in battle",'Pokémon im Kampf'),L("AUTO: existing provider. CRYSTAL: Crystal graphics. STADIUM: imported models. COBBLEMON: bundled 3D models. 3D models require a supported spatial battle setting.",'AUTO: vorhandener Anbieter. CRYSTAL: Crystal-Darstellung. STADIUM: importierte Modelle. COBBLEMON: enthaltene 3D-Modelle. 3D-Modelle benötigen einen unterstützten räumlichen Kampfstil.')),
  row('battleHdSprites',L("HD battle sprites",'HD-Kampfsprites'),L("Starts battles with available animated HD sprites. Missing variants use fallbacks. 3D model choices are managed separately.",'Startet Kämpfe mit verfügbaren animierten HD-Sprites. Fehlende Varianten nutzen Ersatz. 3D-Modellwahl hat ihre eigene Zuständigkeit.')),
  row(V.require('OverworldBattle').arenaArtSetting.key,L("Arena artwork",'Arena-Grafiken'),L("VASC, FRLG-inspired or a mixture. Not every map has both variants.",'VASC, FRLG-artig oder eine Mischung. Nicht jede Karte besitzt beide Varianten.')),
  row(V.require('OverworldBattle').diskArtSetting.key,L("Platform artwork",'Plattform-Grafiken'),L("Artwork family for DISCS. Does not affect MAP or other settings.",'Grafikfamilie für DISCS. Wirkt nicht auf MAP oder die anderen Kulissen.'))},'battle')
 page('battle_detail',L("Camera, HUD and Terrarium",'Kamera, HUD und Terarrium'),L("Refine the battle presentation. Terrarium controls only apply to the Terrarium battle style.",'Gestalte die Kampfdarstellung genauer. Die Terarrium-Regler wirken nur bei gewähltem Terarrium-Kampfstil.'),{
  row('arenaCamera',L("Battle camera",'Kampfkamera'),L("Static camera or Smart/Stadium camera. Applies to supported battle scenes.",'Statische Kamera oder Smart-/Stadium-Kamera. Die Wahl wirkt in den unterstützten Kampfszenen.')),
  row('battleHudStyle',L("Battle HUD",'Kampf-HUD'),L("ORAS uses the extended HUD; Standard uses the classic presentation.",'ORAS zeigt das erweiterte HUD; Standard verwendet die klassische Darstellung.')),
  row('battleBack',L("Pokémon view",'Pokémon-Ansicht'),L("Front or back view for supported battle presentations.",'Vorder- oder Rückansicht für unterstützte Kampfdarstellungen.')),
  row('terarriumBackground',L("Terrarium background",'Terarrium-Hintergrund'),L("Automatic background based on the ball, or a fixed diorama environment.",'Automatisch zur Ballwahl oder eine feste Diorama-Umgebung.')),
  row('terarriumDome',L("Terrarium dome",'Terarrium-Kuppel'),L("No dome, or a transparent/coloured dome.",'Keine Kuppel oder transparente/farbige Kuppel.')),
  row('terarriumBehindRed',L("Terrarium camera",'Terarrium-Kamera'),L("From the side or behind the trainer.",'Seitlich oder hinter dem Trainer.'))},'battle')
 page('world',L("How should your world look?",'Wie soll deine Welt aussehen?'),L("World profiles only change the world options described here. Your character, Pokémon and battle choices stay the same.",'Die Weltprofile verändern ausschließlich die hier beschriebenen Weltoptionen. Deine Figuren-, Pokémon- und Kampfwahl bleibt erhalten.'),{
  custom('_world',L("World profile",'Weltprofil'),L("Keep: retain your custom values. Full Voxel: nature, buildings and Voxel scenery. Voxel nature: nature with original buildings, without a panorama or with bitmap scenery.",'Beibehalten: individuelle Werte erhalten. Full Voxel: Natur, Gebäude und Voxel-Ferne. Voxel-Natur: Natur mit ursprünglichen Gebäuden; ohne Panorama oder mit Bitmap-Ferne.'),{{L("Custom / keep current",'Benutzerdefiniert / beibehalten'),'keep'},{'Full Voxel Experience','full'},{L("Voxel nature without panorama",'Voxel-Natur ohne Panorama'),'nature'},{L("Voxel nature with bitmap panorama",'Voxel-Natur mit Bitmap-Panorama'),'bitmap'}},'keep'),
  row('outdoorTrees',L("Trees",'Bäume'),L("Regional Voxel trees and forest canopies. Paths and obstacles keep their gameplay behaviour.",'Regionale Voxel-Bäume und Waldkronen. Wege und Hindernisse bleiben spielerisch erhalten.')),
  row('outdoorGround',L("Ground",'Boden'),L("Natural ground materials. Grass and water remain recognisable.",'Natürliche Bodenmaterialien. Gras und Wasser bleiben erkennbar.')),
  row('outdoorStone',L("Rocks and fences",'Felsen und Zäune'),L("Voxel rocks, hedges and posts.",'Voxel-Felsen, Hecken und Pfosten.')),
  row('palletBuildings',L("Buildings",'Gebäude'),L("Supported Voxel buildings with their original entrances.",'Unterstützte Voxel-Gebäude mit ihren ursprünglichen Eingängen.')),
  row('outdoorHorizon',L("Distant scenery / panorama",'Ferne / Panorama'),L("VOXEL: spatial scenery. BITMAP: painted backdrop. OFF: no extra outdoor scenery. Interiors have their own rules.",'VOXEL: räumliche Ferne. BITMAP: gezeichnete Kulisse. OFF: keine zusätzliche Außenkulisse. Innenräume besitzen eigene Regeln.')),
  {label=L("View world profile for 10 seconds",'Weltprofil 10 Sekunden ansehen'),action='worldpreview',help=L("Temporarily shows your draft in the current game scene. Returns automatically after ten seconds.",'Zeigt den Entwurf vorübergehend in der aktuellen Spielszene. Automatische Rückkehr nach zehn Sekunden.')}},'world')
 page('device',L("Graphics for your device",'Grafik passend zu deinem Gerät'),L("The device description is a starting point. Resolution, load and graphics drivers matter. Detailed does not automatically enable potentially troublesome lighting.",'Die Gerätebeschreibung ist eine Orientierung. Entscheidend sind Auflösung, Auslastung und Grafiktreiber. „Detailreich“ schaltet problematische Lichteffekte nicht automatisch ein.'),{
  custom('_quality',L("Graphics profile",'Grafikprofil'),L("Economy: 720P, no shadows, simple water. Balanced: 1080P, shadows, simple water. Detailed: native resolution, shadows and full water reflections. Anti-aliasing stays off and is available separately. Strong lights stay off.",'Schonend: 720P, Schatten aus, einfaches Wasser. Ausgewogen: 1080P, Schatten an, einfaches Wasser. Detailreich: native Auflösung, Schatten und volle Wasserreflexionen. Kantenglättung bleibt aus; separat wählbar. Starke Lichter werden nicht aktiviert.'),{{L("Keep current values",'Aktuelle Werte behalten'),'keep'},{L("Economy",'Schonend'),'low'},{L("Balanced",'Ausgewogen'),'balanced'},{L("Detailed",'Detailreich'),'high'}},'keep'),
  row('sceneResolution',L("3D resolution",'3D-Auflösung'),L("720P limits rendering resolution for weaker devices. 1080P is a useful starting point. NATIVE uses the window resolution and may cost much more on Retina displays.",'720P begrenzt die Renderauflösung für schwächere Geräte. 1080P ist ein guter Ausgangspunkt. NATIVE nutzt die Fensterauflösung und kann auf Retina-Geräten erheblich teurer sein.')),
  row('aa',L("Anti-aliasing",'Kantenglättung'),L("2X or 4X renders extra pixels to smooth edges. Use OFF when GPU headroom is low.",'2X oder 4X rendert zusätzliche Bildpunkte für glattere Kanten. Bei wenig GPU-Reserve auf OFF stellen.')),
  row('shadows',L("Shadows",'Schatten'),L("An additional rendering pass. Turn off if shadows stutter or look wrong.",'Zusätzlicher Renderdurchlauf. Bei Ruckeln oder fehlerhaften Schatten ausschalten.')),
  row('water',L("Water reflections",'Wasserreflexionen'),L("SKY reflects the sky at lower cost. FULL adds reflections of the surroundings and needs more GPU power. OFF disables reflections.",'SKY spiegelt den Himmel mit geringerem Aufwand. FULL ergänzt Umgebungsspiegelungen und benötigt mehr GPU-Leistung. OFF deaktiviert Reflexionen.'))},'device')
 page('lighting',L("Check strong lighting effects",'Starke Lichteffekte prüfen'),L("Start with these off. The live version has separate world and battle controls. Good FPS do not guarantee correct lighting.",'Empfehlung zum Einstieg: aus. Die Live-Version hat getrennte Regler für Welt und Kampf. Gute FPS garantieren keine fehlerfreie Beleuchtung.'),{
  row('localLights',L("Dynamic world lighting",'Dynamisches Weltlicht'),L("Sun, moon, window light and local sources. Turn off if you see flickering, black surfaces or excessive brightness.",'Sonne, Mond, Fensterlicht und lokale Lichtquellen. Bei Flackern, schwarzen Flächen oder Überstrahlung ausschalten.')),
  row('battleLights',L("Dynamic battle lighting",'Dynamisches Kampflicht'),L("Lighting in supported MAP/ARENA battles. Independent of world lighting. Other battle styles may use different lighting rules.",'Licht auf unterstützten MAP-/ARENA-Kämpfen. Unabhängig vom Weltlicht. Andere Kampfmodi können eigene Lichtregeln haben.')),
  row('terarriumLighting',L("Terrarium lighting",'Terarrium-Licht'),L("Separate lighting control for the Terrarium battle style. Not checked by the world lighting test.",'Eigener Lichtregler für den Terarrium-Kampfstil. Wird durch den Weltlicht-Test nicht geprüft.')),
  row('palletWindowLights',L("Windows and lamps",'Fenster und Lampen'),L("Warm windows and sign lamps on supported buildings.",'Warme Fenster und Schilderlampen an unterstützten Gebäuden.')),
  {label=L("Safe recommendation: strong lights off",'Sichere Empfehlung: starke Lichter aus'),action='safe',help=L("Disables dynamic world and battle lighting in the draft. Other visual styles stay the same.",'Deaktiviert dynamisches Welt- und Kampflicht im Entwurf. Andere Grafikstile bleiben erhalten.')},
  {label=L("Compare world lighting: 2 × 5 seconds",'Weltlicht 2 × 5 Sekunden vergleichen'),action='benchmark',help=L("Temporary test of the current scene with your draft: first off, then on. Returns automatically. No permanent changes. Battle lighting needs a separate battle test.",'Temporärer Test der aktuellen Spielszene mit deinem Entwurf: erst aus, dann an. Kehrt automatisch zurück. Keine dauerhafte Änderung. Kampflicht muss separat im Kampf geprüft werden.')},
  custom('_visual',L("Visual check",'Sichtprüfung'),L("After comparing: did you see flickering, black surfaces or excessive brightness? Visual faults recommend OFF regardless of FPS.",'Nach dem Vergleich: Waren Flackern, schwarze Flächen oder Überstrahlung sichtbar? Bildfehler führen unabhängig von FPS zur Empfehlung AUS.'),{{L("Not checked yet",'Noch nicht geprüft'),'unknown'},{L("No visual faults seen",'Keine Bildfehler gesehen'),'ok'},{L("Visual faults seen",'Bildfehler gesehen'),'bad'}},'unknown')},'lighting')
 page('summary',L("Your look is ready",'Dein Look ist bereit'),L("Review your choices. Select an area with Up/Down and reopen it with A. Only Apply all saves the settings together.",'Prüfe deine Auswahl. Mit Hoch/Runter einen Bereich wählen und mit A erneut öffnen. Erst „Alles übernehmen“ speichert die Einstellungen gemeinsam.'),{},'summary')
 self.stageKey=stage
 self.optional={};local compact={};local contexts={}
 for _,pg in ipairs(self.pages)do
  if pg.id=='base' or pg.id=='finish' or pg.id=='battle_detail' then self.optional[pg.id]=pg
  elseif pg.rows[1] and pg.rows[1].context then
   local r=pg.rows[1];r.label=pg.title;contexts[#contexts+1]=r
  else compact[#compact+1]=pg end
 end
 self.pages=compact
 table.insert(self.pages,3,{id='pokemon',title=L("Pokémon in your world",'Pokémon in deiner Spielwelt'),description=L("Choose a look for each area. Downloads and imports appear directly below it. A shared base style and surface effects are optional. Crystal sprites are available for battles and the Pokédex.",'Wähle den Look je Bereich. Downloads oder Importe stehen direkt darunter. Ein gemeinsamer Grundstil und Oberflächeneffekte sind optional. Crystal-Kampfsprites wählst du bei Kampf und Pokédex.'),rows=contexts,kind='pokemon'})
 local people=self.pages[2];self.optional.people={id='people_detail',title=L("Optional character details",'Optionale Figurendetails'),description=L("You have chosen your character style. These details are optional; dialogue poses automatically follow HD or Voxel HD.",'Den Figurenstil hast du bereits gewählt. Diese Details sind optional; Dialogposen folgen automatisch HD oder Voxel-HD.'),kind='people',rows={people.rows[4],people.rows[6]}}
 people.rows={custom('_people',L("Character style",'Figurenstil'),L("Original 2D: classic game graphics, no dialogue poses. HD: drawn characters with dialogue poses. Voxel HD: existing artwork in a block style, also with dialogue poses. Identity and clothing stay the same.",'Original-2D: klassische Spielgrafik, Dialogposen aus. HD: gezeichnete Figuren mit Dialogposen. Voxel-HD: vorhandene Grafiken im Block-Look, ebenfalls mit Dialogposen. Identität und Kleidung bleiben erhalten.'),{{L("Original 2D",'Original-2D'),'classic'},{'HD','hd'},{L("Voxel HD",'Voxel-HD'),'voxel'}},self.draft.apo_hd_walking_sprites==false and 'classic' or self.draft.voxelCharacterCardEnabled~=false and self.draft.apo_human_art_style=='voxel' and 'voxel' or 'hd'),{label=L("Dialogue poses follow the style automatically",'Dialogposen folgen automatisch dem Stil'),help=L("HD and Voxel HD: automatically on. Original 2D: off. Requires available dialogue animations; characters without them keep their normal presentation.",'HD und Voxel-HD: automatisch an. Original-2D: aus. Benötigt passende vorhandene Gesprächsanimationen; Figuren ohne Animation behalten ihre normale Darstellung.')},{label=L("Optional character details",'Optionale Figurendetails'),action='optional',target='people'}}
 for _,pg in ipairs(self.pages)do
  if pg.id=='pokemon' then
   pg.rows[#pg.rows+1]={label=L("Optional: choose a shared base style",'Optional: gemeinsamen Grundstil vorgeben'),action='optional',target='base',help=L("A shortcut for several overworld areas. Choose exactly which areas receive the preset; battles and the Pokédex stay separate.",'Eine Abkürzung für mehrere Oberwelt-Bereiche. Du bestimmst einzeln, welche Bereiche vorbelegt werden; Kampf und Pokédex bleiben separat.')}
   pg.rows[#pg.rows+1]={label=L("Optional surface effects",'Optionale Oberflächeneffekte'),action='optional',target='finish',help=L("For further adjustments: outlines, relief, grid and animations, with a comparison in the actual world.",'Nur wenn du weiter anpassen möchtest: Konturen, Relief, Raster und Animationen mit einem Vergleich in der echten Welt.')}
  elseif pg.id=='battle' then
   self.optional.battleArt={id='battle_art',title=L("Optional battle details",'Optionale Kampfdetails'),description=L("Only details matching your battle setting appear. You can keep the existing values.",'Es erscheinen nur Details, die zur gewählten Kampfkulisse passen. Du kannst die vorhandenen Werte unverändert lassen.'),kind='battle',rows={pg.rows[4],pg.rows[5]}}
   local bs=self.draft.battleSpriteStyle or 'current'
   if bs=='current' then bs=self.draft.battleHdSprites and 'hd' or self.draft.pokemonModelSkin~='auto' and self.draft.pokemonModelSkin or 'current' end
   pg.rows={pg.rows[1],custom('_battleGraphics',L("Pokémon graphics type",'Pokémon-Grafiktyp'),L("One graphics type for new battles: Original, Crystal and animated HD use sprites. Stadium and Cobblemon are true 3D models and need a spatial battle setting. The guide adjusts related switches together.",'Ein Grafiktyp für neue Kämpfe: Original, Crystal oder animiertes HD sind Sprites. Stadium und Cobblemon sind echte 3D-Modelle und benötigen eine räumliche Kampfkulisse. Der Assistent setzt zugehörige Schalter gemeinsam.'),{{L("Keep current selection",'Aktuelle Auswahl behalten'),'current'},{L("Original sprites",'Original-Sprites'),'original'},{L("Crystal sprites",'Crystal-Sprites'),'crystal'},{L("Animated HD",'HD animiert'),'hd'},{'Stadium 2','stadium2'},{'Cobblemon','cobblemon'}},bs),{label=L("Optional battle details",'Optionale Kampfdetails'),action='optional',target='battleArt',help=L("Open camera, HUD and background options that match the selected setting. Not required to get started.",'Nur zur gewählten Kulisse passende Kamera-, HUD- und Hintergrundoptionen öffnen. Für den Einstieg nicht nötig.')}}
  elseif pg.id=='world' or pg.id=='device' or pg.id=='lighting' then
   local all=pg.rows;self.optional[pg.id..'_detail']={id=pg.id..'_detail',title=L("Optional ",'Optionale ')..(pg.id=='world' and L("world details",'Weltdetails') or pg.id=='device' and L("graphics details",'Grafikdetails') or L("lighting details",'Lichtdetails')),description=L("You can keep existing detail values. Basic setup does not require these individual switches.",'Vorhandene Detailwerte können bleiben. Die Grundeinrichtung benötigt diese Einzelschalter nicht.'),kind=pg.kind,rows={}}
   if pg.id=='world' then pg.rows={all[1],all[#all]};for i=2,#all-1 do table.insert(self.optional.world_detail.rows,all[i])end
   elseif pg.id=='device' then pg.rows={all[1]};for i=2,#all do table.insert(self.optional.device_detail.rows,all[i])end
   else pg.rows={all[5],all[6],all[7]};for i=1,4 do table.insert(self.optional.lighting_detail.rows,all[i])end end
   pg.rows[#pg.rows+1]={label=L("Open optional details",'Optionale Details öffnen'),action='optional',target=pg.id..'_detail',help=L("Additional individual controls with explanations. You can keep existing values.",'Zusätzliche einzelne Regler mit Erklärung. Du kannst die vorhandenen Werte behalten.')}
  end
 end
 -- Start with the device; advanced camera controls stay in the full menu.
 for i,pg in ipairs(self.pages)do if pg.id=='device' then
  table.remove(self.pages,i);table.insert(self.pages,2,pg)
  pg.title=L("What device are you playing on?",'Auf welchem Gerät spielst du?')
  pg.description=L("Choose a safe starting point first. The profile prepares graphics and effects; then you choose your look. The device category is guidance, not a performance test.",'Wähle zuerst einen sicheren Startpunkt. Das Profil bereitet Grafik und Effekte vor; danach bestimmst du den Look. Die Geräteklasse ist eine Orientierung, kein Leistungstest.')
  pg.rows={custom('_device',L("Your device / starting profile",'Dein Gerät / Startprofil'),L("Mobile / economy: 720p, no shadows, simple water. Notebook / handheld: 1080p, simple reflections. Gaming PC: native resolution and full reflections. All start with strong lights and anti-aliasing off, and a steady battle camera.",'Mobil / sparsam: 720p, keine Schatten, einfaches Wasser. Notebook / Handheld: 1080p, einfache Reflexionen. Gaming-PC: native Auflösung und volle Reflexionen. Alle starten ohne starke Lichter, ohne Kantenglättung und mit ruhiger Kampfkamera.'),{{L("Please select a device",'Bitte Gerät auswählen'),'choose'},{L("Mobile / older device / save battery",'Mobil / älteres Gerät / Akku sparen'),'mobile'},{L("Notebook / handheld / integrated GPU",'Notebook / Handheld / integrierte Grafik'),'integrated'},{L("Gaming PC / powerful dedicated GPU",'Gaming-PC / starke separate GPU'),'desktop'},{L("Unsure: choose a safe start",'Unsicher: sicheren Start wählen'),'safe'},{L("Keep existing graphics settings",'Vorhandene Grafikwerte behalten'),'keep'}},'choose')}
  break
 end end
 for _,pg in ipairs(self.pages)do if pg.id=='battle'then table.remove(pg.rows,#pg.rows)end end

 for _,pg in ipairs(self.pages)do if pg.id=='lighting'then
  pg.title=L("Graphics check · about two minutes",'Grafikcheck · etwa zwei Minuten')
  pg.description=L("Repeated ON/OFF comparisons separate effect cost from timing noise. Image checks run separately. Clear recommendations are preselected; unclear results keep your choices.",'Wiederholte AN/AUS-Vergleiche trennen Effektkosten von Schwankungen. Die Bildprüfung läuft separat. Klare Empfehlungen werden vorausgewählt; bei unklaren Ergebnissen bleibt deine Auswahl.')
  pg.rows={{label=L("Start graphics check · 2 minutes",'Grafikcheck starten · 2 Minuten'),action='benchmark',help=L("Tests resolution, shadows, reflections, anti-aliasing and three lighting types in temporary test worlds, then combines effects for a stress test. Your save is preserved. Measurement pauses in the background.",'Prüft Auflösung, Schatten, Reflexionen, Kantenglättung und drei Lichtarten in temporären Testwelten. Danach gemeinsamer Belastungstest. Dein Spielstand bleibt erhalten. Im Hintergrund pausiert die Messung.')},
   {label=L("Preselect recommendations again",'Empfehlungen erneut vorauswählen'),action='recommend',help=L("Copies tested recommendations into the draft. Reported visual faults use the simple or off variant for that effect. Unclear evidence keeps your choice.",'Setzt die geprüften Empfehlungen in den Entwurf. Gemeldete Bildfehler wählen für diesen Effekt AUS oder die einfache Variante. Unklare Messungen behalten deine Auswahl.')},
   {label=L("Override / graphics details",'Bewusst abweichen / Grafikdetails'),action='optional',target='graphics_override',help=L("Optional: adjust recommended values individually. Measurements remain visible for guidance; your choices take priority until you apply recommendations again.",'Optional: empfohlene Werte einzeln ändern. Die Messung bleibt als Orientierung sichtbar; diese Auswahl hat Vorrang bis du erneut Empfehlungen anwendest.')}}
 end end
 self.optional.graphics_override={id='graphics_override',title=L("Override the recommendations",'Bewusst von der Empfehlung abweichen'),description=L("These choices apply to your draft. Change only what matters to you. You can return to the recommendations if problems occur.",'Die Auswahl gilt für deinen Entwurf. Ändere nur, was dir wichtig ist. Bei Problemen kannst du jederzeit zu den Empfehlungen zurückkehren.'),kind='lighting',rows={}}
 for _,key in ipairs({'sceneResolution','shadows','aa','water','localLights','battleLights','terarriumLighting'})do
  local help={sceneResolution=L("3D scene resolution. Fewer pixels reduce GPU load. A different resolution requires a new graphics check.",'Auflösung der 3D-Szene. Weniger Pixel entlasten die GPU. Eine andere Auflösung benötigt einen neuen Grafikcheck.'),shadows=L("Extra shadows from characters and surroundings. An additional rendering pass costs performance.",'Zusätzliche Schatten von Figuren und Umgebung. Ein weiterer Renderdurchlauf kostet Leistung.'),aa=L("Extra rendering pixels smooth edges, using more memory and processing. This control may have no technical effect on mobile.",'Zusätzliche Renderpixel glätten Kanten; hoher Speicher- und Rechenbedarf. Mobil kann dieser Regler technisch ohne Wirkung bleiben.'),water=L("SKY: simple sky reflection. FULL: also reflects the scene; needs visible water and more performance.",'SKY: einfache Himmelsspiegelung. FULL: spiegelt zusätzlich die Szene, benötigt sichtbares Wasser und mehr Leistung.'),localLights=L("Dynamic world lighting. Turn off if surfaces flicker or disappear.",'Dynamische Beleuchtung der Welt. Bei Flackern oder verschwindenden Flächen ausschalten.'),battleLights=L("Dynamic lighting for MAP and Arena. Other settings use different lighting rules.",'Dynamische Beleuchtung für MAP und Arena. Andere Kulissen verwenden andere Lichtregeln.'),terarriumLighting=L("Separate Terrarium lighting. Only affects this battle setting.",'Eigene Beleuchtung für Terrarium. Hat nur bei dieser Kampfkulisse eine Wirkung.')}
  local labels={sceneResolution=L("3D resolution",'3D-Auflösung'),shadows=L("Shadows",'Schatten'),aa=L("Anti-aliasing",'Kantenglättung'),water=L("Water reflections",'Wasserreflexionen'),localLights=L("World lighting",'Weltlicht'),battleLights=L("Battle lighting",'Kampflicht'),terarriumLighting=L("Terrarium lighting",'Terrarium-Licht')}
  table.insert(self.optional.graphics_override.rows,row(key,labels[key],help[key]))
 end
 -- Add after the compact-page rewrite so this remains a first-class setup step.
 local controls={id='battle_controls',kind='battle_controls',title=L('Battle buttons: your choice','Kampfbuttons: deine Wahl'),description=L('Auto saves space at the bottom edge and shows complete buttons when raised. You can also choose a fixed shape. Changes stay a draft until Apply.','Auto spart am unteren Bildrand Platz und zeigt angehobene Buttons vollständig. Du kannst auch eine feste Form wählen. Erst Übernehmen speichert.'),rows={
  row('battle_controls_shape',L('Button shape','Buttonform'),L('Auto: cut at the screen bottom, complete above it, including touch spacing. Original: always cut. Complete ORAS: always whole. Glass: transparent panels. Fixed choices are never overridden.','Auto: am Bildrand angeschnitten, darüber vollständig, auch bei Touch-Abständen. Original: immer angeschnitten. Vollständiges ORAS: immer ganz. Glas: transparente Flächen. Feste Formen werden nie übersteuert.'),{{L('Auto: follow position','Auto: passend zur Position'),'auto'},{L('Original edge-cut','Original angeschnitten'),'original'},{L('Complete ORAS (opt in)','Vollständiges ORAS (bewusst wählen)'),'round'},{L('Glass','Glas'),'glass'}}),
  row('battle_controls_scale',L('Button size','Buttongröße'),L('Scales battle buttons and move selection. Shape stays as selected.','Skaliert Kampfbuttons und Attackenauswahl. Die gewählte Form bleibt erhalten.')),
  row('battle_controls_x',L('Horizontal position','Horizontale Position'),L('Move the buttons left or right. Zero centres the group.','Verschiebt die Buttons nach links oder rechts. Null zentriert die Gruppe.')),
  row('battle_controls_y',L('Lift above lower edge','Über unteren Rand anheben'),L('Zero keeps the original bottom dock. Increase only if you want buttons further inside the picture. Touch controls and safe areas still reserve space.','Null behält den ursprünglichen unteren Rand bei. Nur erhöhen, wenn die Buttons weiter ins Bild sollen. Touch-Steuerung und Sicherheitsabstände reservieren weiterhin Platz.')),
  {label=L('Restore original edge layout','Originales Randlayout wiederherstellen'),action='controlsDefault',help=L('Resets only button shape, size and position in this draft. Apply to save.','Setzt nur Form, Größe und Position der Buttons in diesem Entwurf zurück. Zum Speichern übernehmen.')}
 }}
 for i,pg in ipairs(self.pages)do if pg.id=='battle'then table.insert(self.pages,i+1,controls);break end end
 local saved=M.receipt(game)
 local interrupted=V.mod.storage:read(game,'dein-look/light-test')
 if saved.version==M.VERSION and not saved.done and type(saved.draft)=='table' then
  for k,v in pairs(saved.draft)do
   local valid=type(v)==type(self.draft[k]) and (type(v)~='number' or (v==v and v~=math.huge and v~=-math.huge))
   local setting=self.settings[k]
   if setting then valid=false;for _,candidate in ipairs(setting.values)do if candidate==v then valid=true;break end end end
   if valid then self.draft[k]=v end
  end
  local page=tonumber(saved.page)
  if not page or page~=page or page==math.huge or page==-math.huge then page=1 end
  self.page=math.max(1,math.min(#self.pages,math.floor(page)))
 end
 if type(interrupted)=='table' and interrupted.pending then for _,e in ipairs(V.require('SetupEffects').rules.effects)do self.draft[e.key]=e.off end;self.message=L("The last graphics check was interrupted. Safe effect values are preselected; please test again.",'Der letzte Grafikcheck wurde unterbrochen. Sichere Effektwerte vorausgewählt; bitte erneut prüfen.')end
 if saved.done and self.kasc and not saved.kasc then for i,p in ipairs(self.pages)do if p.id=='pokemon'then self.page=i end end;self.message=L("KASC is now active. Review the additional Wilds town area.",'KASC ist jetzt aktiv. Prüfe den zusätzlichen Wilds-Stadt-Bereich.')end
 self.effects=V.require('SetupEffects').new(game,self.draft);self.performance=self.effects.performance
 self:refreshPreview();return self
end
function Screen:uiSize()if self.trial then return 160,144 end;return 640,400 end
function Screen:wantsFillScale()return true end
function Screen:drawsWidescreen()return true end
function Screen:sgbPalettes()return {{colors=false,x=0,y=0,w=640,h=400}}end
function Screen:current()return self.subpage or self.pages[self.page]end
function Screen:rowVisible(r,p)
 local mode=self.draft[self.stageKey]
 if r.key=='modernDexSpriteSource' then return self.draft.pokedexStyle=='modern' end
 if p.id=='battle_art' then
  if r.key=='terarriumBackground' or r.key=='terarriumDome' or r.key=='terarriumBehindRed' then return mode=='terarrium' end
  if r.key=='arenaCamera' then return mode==true or mode=='arena' end
  if r.key==V.require('OverworldBattle').arenaArtSetting.key then return mode=='arena' end
  if r.key==V.require('OverworldBattle').diskArtSetting.key then return mode=='flatB' end
  if r.key=='battleBack' then return mode~=false and mode~='terarrium' end
 end
 return true
end
function Screen:rows()
 local p=self:current();if p.kind~='summary' then
 local out={}
 if p.id=='finish' and not self.detailsOpen then
  out[#out+1]={label=L("Keep existing values and continue",'Vorhandene Werte behalten und weiter'),action='next',help=L("No extra adjustment needed. You can change these details later in the VASC menu.",'Keine zusätzliche Anpassung erforderlich. Du kannst diese Details später jederzeit im VASC-Menü ändern.')}
  out[#out+1]={label=L("Open optional details",'Optionale Details öffnen'),action='details',help=L("Explain animations, outlines, sprite relief, block grid and scene lighting individually, then compare them in the actual game world.",'Animationen, Konturen, Sprite-Relief, Blockraster und Szenenlicht einzeln erklären und anschließend in der echten Spielwelt vergleichen.')}
 else
  for _,r in ipairs(p.rows)do
   if self:rowVisible(r,p) then
   if r.action~='base' then out[#out+1]=r end
   if r.key=='_base' or r.context or r.key=='_battleGraphics' or r.key=='pokemonModelSkin' or r.key=='modernDexSpriteSource' then
    local source=self.draft[r.key];local acquire=self:acquisition(source)
    if acquire then out[#out+1]=acquire end
   end
   end
  end
  if p.id=='base' then
   for _,c in ipairs(self.contexts)do
    local current=self:sourceLabel(self.draft['_'..c[1]]);local target=self:sourceLabel(self.draft._base)
    out[#out+1]={key='_include_'..c[1],label=c[2],choices={{L("Include",'Einbeziehen'),true},{L("Keep",'Beibehalten'),false}},help=L("Current draft: ",'Bisheriger Entwurf: ')..current..L(". Target: ",'. Ziel: ')..target..L(". This area is preset only when Include is selected.",'. Nur bei „Einbeziehen“ wird dieser Bereich vorbelegt.'),scopeBefore=current,scopeAfter=target}
   end
   out[#out+1]=p.rows[2]
  elseif p.id=='finish' then
   out[#out+1]={label=L("Compare current / draft in the world",'Bisher / Entwurf in der Welt vergleichen'),action='detailtest',help=L("Ten seconds in the current scene: five with existing details, five with your draft. Same graphics sources and camera. Returns automatically without saving options. The effect needs matching visible characters to be assessed.",'Zehn Sekunden in der aktuellen Szene: fünf mit bisherigen Detailwerten, fünf mit deinem Entwurf. Gleiche Grafikquellen und Kamera. Danach automatisch zurück; Optionen werden nicht gespeichert. Ohne passende sichtbare Figuren kann der Effekt nicht beurteilt werden.')}
   out[#out+1]={label=L("Discard detail changes",'Detailänderungen verwerfen'),action='detailreset',help=L("Resets only these optional details to their values when setup opened.",'Setzt nur diese optionalen Detailwerte auf den Stand beim Öffnen zurück.')}
  end
 end
 if p.id=='lighting' and self.effects then
  local E=V.require('SetupEffects');local request=E.retest(self.effects,self.draft)
  out[#out+1]={label=request.duration>0 and string.format(L('Retest unclear results · %d s','Unklare Ergebnisse nachtesten · %d s'),request.duration)or L('No timing retest needed','Kein Messungs-Nachtest nötig'),action='retest',disabled=request.duration==0,help=L('Repeats only inconclusive measurements. Pending visual reviews are handled per effect below. World changes include a new combination check.','Wiederholt nur unklare Messungen. Offene Sichtprüfungen bewertest du darunter je Effekt. Bei Welt-Effekten wird auch die Kombination erneut geprüft.')}
  for _,e in ipairs(E.rules.effects)do
   local state,why=E.status(self.effects,e.id,self.draft)
   local names={uncertain=L('Unclear: keep choice','Unklar: Auswahl behalten'),recommended=L("Recommended",'Empfohlen'),review=L("Visual check pending",'Sichtprüfung offen'),off=L("Off recommended",'Aus empfohlen'),untested=L("Not tested",'Nicht geprüft'),['needs-test']=L("Test pending",'Test offen'),caution=L("Start cautiously",'Vorsichtig starten'),blocked=L("Unavailable",'Nicht verfügbar'),['not-applicable']=L("No effect here",'Hier ohne Wirkung')}
   out[#out+1]={label=e.label..': '..(names[state]or state),help=why..L(" Draft: ",' Entwurf: ')..trvalue(self.draft[e.key])..'.',effect=e.id,action='effect'}
  end
  out[#out+1]={label=L('Combined effects · review / retest','Effekte gemeinsam · prüfen / nachtesten'),effect='combined',action='effect',help=L('The combined check has its own image report. A fault here is not assigned to every individual effect.','Der gemeinsame Test hat eine eigene Bildbewertung. Ein Fehler hier wird nicht allen Einzeleffekten zugeschrieben.')}
 end
 if p.kind~='welcome' then out[#out+1]={label=self.subpage and L("Back to overview",'Zurück zur Übersicht') or L("Continue to the next area",'Weiter zum nächsten Bereich'),action='next',help=L("Confirms this area and continues. Your choices are still a draft.",'Bestätigt diesen Bereich und führt dich weiter. Deine Auswahl ist weiterhin nur ein Entwurf.')};out[#out+1]={label=L("Save draft / later",'Entwurf speichern / später'),action='later',help=L("Pauses setup without changing graphics.",'Unterbricht die Einrichtung ohne Grafikänderung.')}end;return out end
 local rows={}
 for i=2,#self.pages-1 do local pg=self.pages[i];local labels={}
  for _,r in ipairs(pg.rows)do if r.key then labels[#labels+1]=r.label..': '..self:label(r)end end
  rows[#rows+1]={label=pg.title,help=table.concat(labels,' · '),action='jump',target=i}
 end
 rows[#rows+1]={label=L("Apply all and play",'Alles übernehmen und spielen'),help=L("Saves this draft to the demo's actual VASC settings. Changing the overworld Card main switch requires a game restart.",'Speichert diesen Entwurf in den echten VASC-Einstellungen der Demo. Änderung am Hauptschalter der Oberwelt-Card benötigt einen Spielneustart.'),action='apply'}
 rows[#rows+1]={label=L("Save draft and resume later",'Entwurf speichern und später fortsetzen'),action='later',help=L("Graphics settings stay unchanged.",'Grafikeinstellungen bleiben unverändert.')}
 return rows
end
function Screen:inheritedSource()
 local v=self.draft.apo_pokemon_model_source
 return v=='cobblemon' and 'cobblemon' or v=='stadium_only' and 'stadium2' or 'full_hd'
end
function Screen:sourceLabel(source)
 for _,c in ipairs(sourceChoices)do if c[2]==source then return c[1]end end
 return ({inherit=L("Model priority",'Modellreihenfolge'),hd=L("Animated HD",'HD animiert'),kasc_crystal='Crystal',crystal='Crystal',active=L("Active style",'Aktiver Stil'),game=L("Game graphics",'Spielgrafik')})[source] or tostring(source)
end
function Screen:acquisition(source)
 if source=='inherit' then source=self:inheritedSource()end
 if source=='cobblemon' then
  local ok,content=pcall(V.require,'CobblemonContent')
  local dex=({1,25,6,133})[self.species]or 25
  local checked,available=false,false
  if ok and type(content.available)=='function'then checked,available=pcall(content.available,dex,'normal')end
  return {source='cobblemon',label=checked and available and L('Cobblemon: example model available','Cobblemon: Beispielmodell verfügbar') or L('Cobblemon: example model unavailable','Cobblemon: Beispielmodell nicht verfügbar'),
   help=L('Current VASC builds include prepared Cobblemon models. No separate installation or download is needed. This status checks the selected example. If its preview fails, check the package and model loading; unsupported variants use fallback graphics.','Neue VASC-Versionen enthalten vorbereitete Cobblemon-Modelle. Kein zusätzlicher Download und keine Einrichtung nötig. Der Status prüft das gewählte Beispiel. Fehlt dessen Vorschau, Paket und Modell-Laden prüfen; nicht unterstützte Varianten nutzen Ersatzgrafiken.')}
 end
 local labels={stadium2=L("Import your Stadium 2 ROM",'Eigene Stadium-2-ROM importieren'),stadium1=L("Manage Stadium content / import",'Stadium-Inhalte / Import verwalten'),full_hd=L("Download HD packs",'HD-Pakete herunterladen'),hd=L("Download HD packs",'HD-Pakete herunterladen'),pokemmo=L("Download MMO sprite pack",'MMO-Spritepaket herunterladen'),crystal=L("Download Crystal pack",'Crystal-Paket herunterladen'),kasc_crystal=L("Download Crystal pack",'Crystal-Paket herunterladen')}
 if not labels[source]then return end
 return {label=labels[source],action=source=='stadium2' and 'rom' or 'content',source=source,help=source=='stadium2' and L("Opens the existing importer for your own Stadium 2 ROM directly. Your setup draft is preserved. Return here after importing or cancelling.",'Öffnet direkt den vorhandenen Import für deine eigene Stadium-2-ROM. Dein Setup-Entwurf bleibt erhalten. Nach Import oder Abbruch kehrst du hierher zurück.') or L("Opens the existing pack manager for this style. It shows available and missing packs. Your draft is preserved; installation may require a game restart.",'Öffnet die vorhandene Paketverwaltung für diesen Grafikstil. Dort siehst du verfügbare und fehlende Pakete. Dein Entwurf bleibt erhalten; nach Installation kann ein Spielneustart nötig sein.')}
end
function Screen:openAcquisition(r)
 if r.source=='cobblemon'then self.message=self:acquisition('cobblemon').help;return end
 if not persist(self,false) then return false end
 self.returnFromContent=true
 if r.action=='rom' then
  local rom=M.rom
  if not rom or not rom.choose then self.message=L("The Stadium importer is unavailable on this host.",'Der Stadium-Import ist auf diesem Host nicht verfügbar.');return end
  local ok,result=pcall(rom.choose,self.game);self.importPolling=ok and result~=false
  self.message=self.importPolling and L("Stadium importer opened. Choose your own ROM file; your draft is preserved.",'Stadium-Import geöffnet. Eigenen ROM-Datensatz auswählen; der Entwurf bleibt erhalten.') or L("Import not started or cancelled. Your draft is preserved.",'Import nicht gestartet oder abgebrochen. Der Entwurf bleibt erhalten.')
 else
  V.mod.ui.push(self.game,'VascPokemonHdDownloads')
  local menu=self.game.stack:top()
  if menu and menu.openFamily then
   local family=({full_hd='pokemon-hd-3d',hd='pokemon-hd-3d',pokemmo='pokemon-overworld-mmo',crystal='pokemon-crystal',kasc_crystal='pokemon-crystal'})[r.source]
   if family then menu:openFamily(family)end
  end
 end
end
function Screen:label(r)
 for _,c in ipairs(r.choices or {})do if c[2]==self.draft[r.key]then return c[1]end end
 return r.key and trvalue(self.draft[r.key]) or ''
end
function Screen:stageContext(c,source)
 self.draft['_'..c[1]]=source
 if source=='classic' then self.draft[c[5]]=false else self.draft[c[5]]=true;self.draft[c[4]]=source=='inherit' and 'hd' or source end
end
function Screen:step(dir)
 local r=self:rows()[self.index];if not r or not r.choices or r.disabled then return end
 local idx=1;for i,c in ipairs(r.choices)do if c[2]==self.draft[r.key]then idx=i end end
 local count=#r.choices
 for _=1,count do
  idx=(idx-1+dir)%count+1;local value=r.choices[idx][2];local allowed=true
  local s=self.settings[r.key]
  if s and r.key~='modernDexSpriteSource' then for j,v in ipairs(s.values)do if v==value and s.allows and not s:allows(j) then allowed=false end end end
  if allowed then self.draft[r.key]=value;break end
 end
 if r.key=='_device' and self.draft._device=='keep' then
  for _,k in ipairs({'sceneResolution','shadows','water','aa','localLights','battleLights','terarriumLighting','arenaCamera','deviceProfile'})do if self.settings[k]then self.draft[k]=self.initial[k]end end
 elseif r.key=='_device' and self.draft._device~='choose' and self.draft._device~='keep' then
  local kind=self.draft._device;local low=kind=='mobile' or kind=='safe';local high=kind=='desktop'
  self.draft.sceneResolution=low and 'economy' or high and 'native' or 'balanced'
  self.draft.shadows=not low;self.draft.water=high and 'full' or 'sky';self.draft.aa=0
  self.draft.localLights=false;self.draft.battleLights=false;self.draft.terarriumLighting=false
  self.draft.arenaCamera='fixed3x';if self.settings.deviceProfile then self.draft.deviceProfile='custom' end
  self.dependencyNotice=L("Starting profile prepared in the draft. Strong lights stay off; choose your look next.",'Startprofil im Entwurf vorbereitet. Starke Lichter bleiben aus; deinen Look wählst du anschließend.')
 elseif r.key=='_people' then
  self.draft.apo_hd_walking_sprites=self.draft._people~='classic'
  if self.draft._people~='classic' then self.draft.apo_enabled=true;self.draft.apo_human_art_style=self.draft._people;self.draft.voxelCharacterCardEnabled=self.draft._people=='voxel' end
 elseif r.key=='_battleGraphics' and self.draft._battleGraphics=='current' then
  for _,k in ipairs({'battleSpriteStyle','battleHdSprites','pokemonModelSkin'})do self.draft[k]=self.initial[k]end
 elseif r.key=='_battleGraphics' and self.draft._battleGraphics~='current' then
  local style=self.draft._battleGraphics;self.draft.battleSpriteStyle=style;self.draft.battleHdSprites=style=='hd'
  self.draft.pokemonModelSkin=(style=='stadium2' or style=='cobblemon') and style or 'crystal'
  if (style=='stadium2' or style=='cobblemon') and self.draft[self.stageKey]==false then self.draft[self.stageKey]='arena';self.dependencyNotice=L("Arena was selected as a spatial battle setting for the 3D model.",'Für das 3D-Modell wurde Arena als räumliche Kampfkulisse gewählt.')end
 elseif r.key==self.stageKey and self.draft[self.stageKey]==false and (self.draft._battleGraphics=='stadium2' or self.draft._battleGraphics=='cobblemon') then
  self.draft._battleGraphics='crystal';self.draft.battleSpriteStyle='crystal';self.draft.pokemonModelSkin='crystal';self.draft.battleHdSprites=false;self.dependencyNotice=L("Classic battle view: Crystal sprites replace the 3D models.",'Klassische Kampfansicht: Crystal-Sprites ersetzen die 3D-Modelle.')
 end
 if r.context then self:stageContext(r.context,self.draft[r.key])end
 if r.key=='_world' then
  local mode=self.draft._world
  if mode=='keep' then for _,k in ipairs({'outdoorTrees','outdoorGround','outdoorStone','palletSurrounds','palletBuildings','outdoorHorizon','scenery'})do self.draft[k]=self.initial[k]end
  else for _,k in ipairs({'outdoorTrees','outdoorGround','outdoorStone','palletSurrounds'})do if self.settings[k]then self.draft[k]=true end end
   self.draft.palletBuildings=mode=='full';self.draft.outdoorHorizon=mode=='full' and 'voxel' or mode=='bitmap' and 'bitmap' or 'off'
   local h=V.require('HorizonWall').setting.key;self.draft[h]='full'
  end
 elseif r.key=='_quality' and self.draft._quality~='keep' then
  self.draft.shadows=self.draft._quality~='low';self.draft.water=self.draft._quality=='high' and 'full' or 'sky';self.draft.sceneResolution=self.draft._quality=='low' and 'economy' or self.draft._quality=='high' and 'native' or 'balanced';self.draft.aa=0
 end
 self.message=self.dependencyNotice;self.dependencyNotice=nil;self:refreshPreview();persist(self,false)
end
function Screen:refreshPreview()
 if self.settings.apo_human_acting_pilot then self.draft.apo_human_acting_pilot=self.draft.apo_hd_walking_sprites~=false end
 local p=self:current();if p.kind=='battle_controls'then return end;local source='cobblemon';local selected=self:rows()[self.index]
 if p.kind=='people' then source=self.draft.apo_hd_walking_sprites==false and 'classic' or self.draft.apo_human_art_style
 if source=='voxel' and self.draft.voxelCharacterCardEnabled==false then source='hd' end
 elseif p.kind=='dex' then source=({kasc_crystal='crystal',active='active',game='classic',hd='full_hd'})[self.draft.modernDexSpriteSource]
 elseif p.kind=='battle' then source=self.draft._battleGraphics or self.draft.pokemonModelSkin;if source=='hd'then source='full_hd' elseif source=='original'then source='classic' end;if source=='auto' or source=='current' or source=='stadium1' then source=self.draft.battleHdSprites and 'full_hd' or 'classic' end
 elseif p.id=='pokemon' and selected and selected.context then source=self.draft[selected.key]
 elseif selected and selected.source then source=selected.source
 else source=self.draft['_'..p.id] or self.draft._base or 'cobblemon' end
 if source=='inherit' then source=self:inheritedSource() end
 local dex=({1,25,6,133})[self.species]
 local ok,err=pcall(self.preview.set,self.preview,source,dex,p.kind=='people')
 if not ok then self.preview.error=L("Preview unavailable: ",'Vorschau nicht verfügbar: ')..tostring(err) end
end
function Screen:drawControlsPreview(x,y,w,h)
 local exports=self.game.mods and self.game.mods.exports
 local hud=exports and exports.VOXEL_ASCENDANT and exports.VOXEL_ASCENDANT.orasBattleHud
 if not (hud and hud.controlsPreview)then return false end
 local canvas,err=hud.controlsPreview(self.draft)
 if not canvas then self.message=L('Button preview unavailable: ','Buttonvorschau nicht verfügbar: ')..tostring(err);return false end
 local fit=math.min(w/canvas:getWidth(),h/canvas:getHeight())
 local G=love.graphics;G.setColor(1,1,1,1);G.draw(canvas,x+(w-canvas:getWidth()*fit)/2,y,0,fit,fit)
 return true
end
function Screen:next()
 if self:current().id=='device' and self.draft._device=='choose' then self.message=L("Please select a device, choose a safe start or explicitly keep existing graphics settings.",'Bitte wähle ein Gerät, den sicheren Start oder ausdrücklich „Vorhandene Grafikwerte behalten“.');return end
 if self.subpage then self.subpage=nil;self.index=1;self:refreshPreview();persist(self,false);return end
 self.confirmed[self:current().id]=true
 self.page=math.min(#self.pages,self.page+1);self.index=1;self:refreshPreview();persist(self,false)
end
function Screen:apply()
 if self.draft._device=='choose' then self.message=L("Please choose a starting profile on the device page first, or keep existing graphics settings.",'Bitte zuerst auf der Geräteseite ein Startprofil wählen oder vorhandene Grafikwerte behalten.');self.page=2;self.subpage=nil;self.index=1;return false end
 if self.settings.apo_human_acting_pilot then self.draft.apo_human_acting_pilot=self.draft.apo_hd_walking_sprites~=false end
 self.message=nil
 -- Validate the complete transaction before any owner is written.
 for k,s in pairs(self.settings)do
  local v=self.draft[k];local valid=v==self.initial[k]
  for i,x in ipairs(s.values)do if x==v then valid=not s.allows or s:allows(i) or v==self.initial[k] end end
  if not valid then self.message=L("Unavailable: ",'Nicht verfügbar: ')..k..L(". Please check your selection.",'. Bitte Auswahl prüfen.');return false end
 end
 local game=self.game;local oldWrite=game.writeOptions;local old={};local written={};local callbacks={};local attemptedWrite=false
 for k,s in pairs(self.settings)do old[k]=s:get()end
 game.writeOptions=function()end
 local ok,err=pcall(function()
  for k,s in pairs(self.settings)do if self.draft[k]~=s:get()then
   written[#written+1]=k
   local result=s:setValue(self.draft[k],game,true)
   assert(result==self.draft[k],L("Setting was not applied: ",'Einstellung nicht übernommen: ')..k)
  end end
  for _,k in ipairs(written)do local setting=self.settings[k];if setting.change then callbacks[#callbacks+1]=k;setting.change(game,self.draft[k],setting.index)end end
  if oldWrite then attemptedWrite=true;local yes,why=oldWrite(game);assert(yes~=false,why or 'options_write_failed')end
  assert(persist(self,true),self.message)
 end)
 local restored=true
 if not ok then
  -- Restore values before notifying owners, including changes made by a
  -- callback. One failing rollback must never strand writeOptions disabled.
  for k,s in pairs(self.settings)do
   local yes=pcall(function()if s:get()~=old[k]then assert(s:setValue(old[k],game,true)==old[k])end end)
   restored=restored and yes
  end
  for i=#callbacks,1,-1 do local k=callbacks[i];local s=self.settings[k]
   local yes=pcall(s.change,game,old[k],s.index);restored=restored and yes
  end
 end
 game.writeOptions=oldWrite
 if not ok then
  if attemptedWrite and oldWrite then local yes,result=pcall(oldWrite,game);restored=restored and yes and result~=false end
  self.message=L("Apply cancelled: ",'Übernehmen abgebrochen: ')..tostring(err)
  if not restored then self.message=self.message..L(' Restoration could not be fully confirmed.',' Wiederherstellung konnte nicht vollständig bestätigt werden.')end
  return false
 end
 self.applied=true;game.stack:pop();return true
end
function Screen:choose()
 local r=self:rows()[self.index];if not r or r.disabled then return end
 self.message=nil
 if r.choices then self:step(1);return end
 if r.action=='next' then self:next()
 elseif r.action=='keep' then if persist(self,true)then self.game.stack:pop()end
 elseif r.action=='later' then self:pause()
 elseif r.action=='controlsDefault' then
  for k,v in pairs({battle_controls_shape='auto',battle_controls_scale=1,battle_controls_x=0,battle_controls_y=0})do if self.settings[k]then self.draft[k]=v end end
  self:refreshPreview();persist(self,false)
 elseif r.action=='base' then
  local names={};for _,c in ipairs(self.contexts)do if self.draft['_include_'..c[1]]then self:stageContext(c,self.draft._base);names[#names+1]=c[2]end end
  self.message=#names>0 and (L("Draft preset: ",'Entwurf vorbelegt: ')..table.concat(names,', ')..L(". Battles and the Pokédex stay unchanged.",'. Kampf und Pokédex bleiben unverändert.')) or L("No area selected. Nothing changed.",'Kein Bereich ausgewählt. Es wurde nichts verändert.');persist(self,false)
 elseif r.action=='rom' or r.action=='content' then self:openAcquisition(r)
 elseif r.action=='optional' then
  self.subpage=self.optional[r.target];self.index=1;self.detailsOpen=r.target=='finish'
  if r.target=='battleArt' then
   local target=self.optional.battleArt;if not target.extended then for _,v in ipairs(self.optional.battle_detail.rows)do target.rows[#target.rows+1]=v end;target.extended=true end
  end
  self:refreshPreview()
 elseif r.action=='details' then self.detailsOpen=true;self.index=1
 elseif r.action=='detailreset' then for _,k in ipairs(finishKeys)do self.draft[k]=self.initial[k]end;self.message=L("Optional detail values reset.",'Optionale Detailwerte zurückgesetzt.');persist(self,false)
 elseif r.action=='detailtest' then self:startBenchmark(true);if self.trial then self.trial.details=true;for _,k in ipairs(finishKeys)do if self.settings[k]then self.settings[k]:setValue(self.trial.old[k],self.game,true)end end end
 elseif r.action=='safe' then self.draft.localLights=false;self.draft.battleLights=false;self.draft.terarriumLighting=false;self.message=L("Recommendation applied to draft: world, battle and Terrarium lighting OFF.",'Empfehlung im Entwurf übernommen: Welt-, Kampf- und Terarrium-Licht AUS.')
 elseif r.action=='recommend' then self:applyRecommendations()
 elseif r.action=='effect'then self:openEffect(r.effect)
 elseif r.action=='visual'then
  local E=V.require('SetupEffects')
  if E.visual(self.effects,self:current().effect,r.value)then
   local id=self:current().effect;self:applyRecommendations(id=='combined'and {}or {[id]=true})
   self.message=L('Image report saved for this test only. Other effect choices are unchanged.','Bildbewertung nur für diesen Test gespeichert. Andere Effektauswahlen bleiben unverändert.')
  else self.message=L('Run this test before reviewing its image.','Diesen Test zuerst ausführen und danach sein Bild beurteilen.')end
 elseif r.action=='retest'then
  local request=V.require('SetupEffects').retest(self.effects,self.draft,r.effect)
  if request.duration>0 then self:startBenchmark(false,request)else self.message=L('No inconclusive timing measurements. Review pending images per effect.','Keine unklaren Zeitmessungen. Offene Bilder je Effekt beurteilen.')end
 elseif r.action=='benchmark' then self:startBenchmark()
 elseif r.action=='worldpreview' then self:startBenchmark(true)
 elseif r.action=='jump' then self.page=r.target;self.index=1;self:refreshPreview()
 elseif r.action=='apply' then self:apply()end
end
function Screen:openEffect(id)
 local E=V.require('SetupEffects');local title=L('Combined effects','Effekte gemeinsam');local request=E.retest(self.effects,self.draft,id)
 for _,e in ipairs(E.rules.effects)do if e.id==id then title=e.label end end
 self.subpage={id='effect_'..id,kind='effect',effect=id,title=title,
 description=L('Performance, visual quality and the combined test are assessed separately. Image reports apply only to this test.','Leistung, Bildqualität und gemeinsamer Test werden getrennt bewertet. Bildmeldungen gelten nur für diesen Test.'),rows={
 {label=L('No visual faults seen','Keine Bildfehler gesehen'),action='visual',value='ok',help=L('Confirm only after watching this effect in the test. Automatic analysis cannot guarantee a correct image.','Erst bestätigen, wenn du diesen Effekt im Test beobachtet hast. Automatische Analyse garantiert kein fehlerfreies Bild.')},
 {label=L('Flickering / missing surfaces here','Hier Flackern / fehlende Flächen'),action='visual',value='bad',help=L('Reports a fault for this effect only. It recommends the simple or off variant here, leaving other effects alone. For the combined test, the cause remains unassigned.','Meldet einen Fehler nur für diesen Effekt. Hier wird die einfache Variante oder AUS empfohlen; andere Effekte bleiben erhalten. Beim gemeinsamen Test bleibt die Ursache offen.')},
 {label=L('Clear this visual assessment','Diese Bildbewertung zurücksetzen'),action='visual',value='unknown',help=L('Returns only this image review to pending. Timing results remain.','Setzt nur diese Sichtprüfung auf offen. Die Zeitmessungen bleiben erhalten.')},
 {label=request.duration>0 and string.format(L('Retest this part · %d s','Diesen Teil nachtesten · %d s'),request.duration)or L('Not available with this setting','Bei dieser Einstellung nicht verfügbar'),disabled=request.duration==0,action='retest',effect=id,help=request.duration==0 and self.effects.compatibility[id]and self.effects.compatibility[id].reason or L('Repeats OFF / ON / ON / OFF. Other measurements and image reports remain. A world effect also reruns the combined check.','Wiederholt AUS / AN / AN / AUS. Andere Messungen und Bildbewertungen bleiben erhalten. Ein Welt-Effekt prüft auch die Kombination erneut.')},
 }};self.index=1;self.message=nil
end
function Screen:startBenchmark(worldOnly,request)
 if worldOnly and self:current().kind=='world' and not V.require('HorizonWall').isOutdoorMap(self.game.overworld and self.game.overworld.map) then self.message=L("The world profile must be checked outdoors. Save your draft, leave the building and reopen Your Look via F3. Nature and panoramas are not visible indoors.",'Das Weltprofil muss draußen geprüft werden. Entwurf speichern, ein Gebäude verlassen und „Dein Look“ über F3 erneut öffnen. Drinnen sind Natur und Panorama nicht sichtbar.');return end
 if not self.game.overworld or not self.game.overworld.map then self.message=L("Comparison requires a loaded game world.",'Vergleich nur in einer geladenen Spielwelt möglich.');return end
 if self.effects then V.require('SetupEffects').refresh(self.effects,self.draft)end
 local g=self.game;local P=require('src.render.Pipelines')
 local previousPipeline=P.level('voxel');local previousTilt=P.level('tilt');local previousTiltshift=P.level('tiltshift')
 local oldOptions=copy(g.save.options);local oldWrite=g.writeOptions;local old={};for k,s in pairs(self.settings)do old[k]=s:get()end
 g.writeOptions=function()end
 if previousPipeline==0 then P.setLevel('voxel',3)end
 V.require('VoxelState').setLevel(P.level('voxel'))
 self.trial={request=request,originalOptions=oldOptions,elapsed=0,pipeline=previousPipeline,tilt=previousTilt,tiltshift=previousTiltshift,worldOnly=worldOnly,phase=1,samples={{},{}},old=old,writer=oldWrite,last=love.timer.getTime()}
 -- Only memory changes; suppress option-file writes for the whole timed trial.
 V.mod.storage:write(g,'dein-look/light-test',{pending=true})
 for k,s in pairs(self.settings)do if self.draft[k]~=old[k]then s:setValue(self.draft[k],g,true)end end
 if not worldOnly then self.settings.localLights:setValue(false,g,true)end
 self.isOpaque=false
 if worldOnly then self.trial.originalViewStates=g.stack.states;g.stack.states={g.overworld,self}end
 if not worldOnly then
  local ok,err=pcall(V.require('SetupBenchmark').start,self)
  if not ok then self:stopBenchmark(true);self.message=L("Could not start the graphics check: ",'Grafikcheck konnte nicht starten: ')..tostring(err)end
 end
end
function Screen:stopBenchmark(cancelled)
 local t=self.trial;if not t then return end
 if t.full then V.require('SetupBenchmark').restore(self)end
 if t.originalViewStates then self.game.stack.states=t.originalViewStates end
 local P=require('src.render.Pipelines');P.setLevel('voxel',t.pipeline);P.setLevel('tilt',t.tilt);P.setLevel('tiltshift',t.tiltshift);V.require('VoxelState').setLevel(t.pipeline)
 for k,v in pairs(t.old)do self.settings[k]:setValue(v,self.game,true)end
 restoreTable(self.game.save.options,t.originalOptions)
 self.game.writeOptions=t.writer;self.isOpaque=true;self.trial=nil
 V.mod.storage:delete(self.game,'dein-look/light-test')
 if t.full then
  if not cancelled then V.require('SetupBenchmark').complete(self,t)else if t.priorEffects then self.effects=t.priorEffects;self.performance=t.priorPerformance end;self.message=L("Graphics check cancelled. Save and settings restored; partial measurements produce no recommendations.",'Grafikcheck abgebrochen. Spielstand und Einstellungen wiederhergestellt; keine Empfehlung aus Teilmessungen.')end
  return
 end
 if t.details and not cancelled then self.message=L("Comparison finished: existing details first, then the draft. Only visible supported characters can be assessed. Previous settings restored.",'Vergleich beendet: zuerst bisherige Details, danach Entwurf. Nur sichtbare unterstützte Figuren sind beurteilbar. Bisherige Einstellungen wiederhergestellt.');return end
 if cancelled or t.worldOnly then self.message=L("Comparison finished. Previous settings restored.",'Vergleich beendet. Bisherige Einstellungen wiederhergestellt.');return end
 local function p95(a)table.sort(a);return a[math.max(1,math.ceil(#a*.95))] or 0 end
 self.benchmark={valid=t.valid~=false,off=p95(t.samples[1]),on=p95(t.samples[2]),samples={#t.samples[1],#t.samples[2]}}
 self.message=string.format(L("95%% frame time: OFF %.1f ms · ON %.1f ms. Choose your visual assessment next.",'95%%-Framezeit: AUS %.1f ms · AN %.1f ms. Anschließend Sichtprüfung wählen.'),self.benchmark.off*1000,self.benchmark.on*1000)
end
function Screen:applyRecommendations(scope)
 local E=V.require('SetupEffects');local tested=self.effects and next(self.effects.results)~=nil
 if not tested then self.message=L("No complete measurement yet. Your starting profile is preserved.",'Noch keine vollständige Messung. Das gewählte Startprofil bleibt erhalten.');return end
 local uncertain=false
 for _,e in ipairs(E.rules.effects)do
  if not scope or scope[e.id]then
  local state=E.status(self.effects,e.id,self.draft)
  local record=self.effects.results[e.id]
  local visualNeeded=e.scene~='world' or e.id=='world_light' or record and record.imageSuspect
  if state=='off'or state=='blocked'then self.draft[e.key]=e.off
  elseif state=='recommended'or (state=='review'and not visualNeeded)then self.draft[e.key]=e.on
  elseif state=='uncertain'or state=='untested'then uncertain=true end
  end
  -- Unclear results, pending visual checks and irrelevant controls retain
  -- the user's draft. A test is not permission to erase an existing choice.
 end
 if uncertain then
  self.message=L('Some results are inconclusive. Your choices were kept there; only clear recommendations were applied. Test again with other demanding apps closed.','Einige Ergebnisse sind unklar. Dort bleibt deine Auswahl erhalten; nur klare Empfehlungen wurden übernommen. Mit geschlossenen rechenintensiven Apps erneut testen.')
  persist(self,false);return
 end
 if self.performance and self.performance.level<=2 and self.draft.sceneResolution=='native'then
  -- Keep the tested resolution: offer a retest at reduced resolution, never
  -- present a changed resolution as measured evidence.
  self.message=L("Recommendations preselected. Low headroom: choose 720p in graphics details and test again.",'Empfehlungen vorausgewählt. Wenig Reserve: unter Grafikdetails 720p wählen und erneut testen.')
 else self.message=L("Recommendations preselected in the draft. Review the image to include tested lighting. Overrides are available in graphics details.",'Empfehlungen im Entwurf vorausgewählt. Bitte das Bild beurteilen; danach wird auch geprüftes Licht berücksichtigt. Abweichungen sind unter Grafikdetails möglich.')end
 persist(self,false)
end
function Screen:recommendation()
 if not self.effects or not next(self.effects.results)then return L("Your starting profile is ready. The graphics check adds measured effect recommendations.",'Dein Startprofil ist vorbereitet. Der Grafikcheck ergänzt gemessene Empfehlungen für Effekte.')end
 V.require('SetupEffects').refresh(self.effects,self.draft)
 if not next(self.effects.results)then return L("Configuration changed: test again for matching recommendations.",'Konfiguration geändert: für passende Empfehlungen bitte erneut testen.')end
 if self.effects.combination and self.effects.combination.verdict~='pass'then return L('The combined result is inconclusive or costly. World choices are kept; review the individual results and test again.','Die Kombination ist unklar oder aufwendig. Deine Welt-Auswahl bleibt erhalten; Einzelergebnisse ansehen und erneut testen.')end
 for _,e in ipairs(V.require('SetupEffects').rules.effects)do local state=V.require('SetupEffects').status(self.effects,e.id,self.draft);if state=='uncertain'or state=='untested'then return L('Some comparisons are inconclusive. Existing choices are kept; another check is needed.','Einige Vergleiche sind unklar. Bestehende Auswahlen bleiben erhalten; bitte erneut prüfen.')end end
 return L('Open each effect to review performance, image quality and the combined check separately.','Öffne die einzelnen Effekte: Leistung, Bildqualität und gemeinsamer Test sind getrennt aufgeführt.')
end
function Screen:update(dt)
 self.time=self.time+dt;local input=self.game.input
 if self.importPolling and M.rom and M.rom.value then
  local ok,value=pcall(M.rom.value,self.game)
  if ok and value~=self.importValue then self.importValue=value;self.preview.key=nil;self:refreshPreview()end
  if self.game.stack:top()~=self then return end
 end
 if self.returnFromContent then self.returnFromContent=nil;self.preview.key=nil;self:refreshPreview()end
 if self.trial then
  if self.trial.full then V.require('SetupBenchmark').update(self);return end
  local t=self.trial;local now=love.timer.getTime();local delta=now-t.last;t.last=now;t.elapsed=t.elapsed+delta
  local localtime=t.elapsed-(t.phase-1)*5
  if not V.require('LocalLights').available() or not require('src.render.Pipelines').eligible('voxel') then t.valid=false end
  if localtime>1 and delta>0 and delta<1 then table.insert(t.samples[t.phase],delta)end
  if input:wasPressed('b')then self:stopBenchmark(true)
  elseif t.elapsed>=10 then self:stopBenchmark(false)
  elseif t.details and t.elapsed>=5 and t.phase==1 then t.phase=2;for _,k in ipairs(finishKeys)do if self.settings[k]then self.settings[k]:setValue(self.draft[k],self.game,true)end end
  elseif not t.worldOnly and t.elapsed>=5 and t.phase==1 then t.phase=2;self.settings.localLights:setValue(true,self.game,true)end
  return
 end
 local ok,err=pcall(self.preview.update,self.preview,math.min(dt,.1));if not ok then self.preview.error=tostring(err)end
 local rows=self:rows();local n=#rows
 if input:wasPressed('up')then self.index=(self.index-2)%n+1;self.message=nil;self:refreshPreview()
 elseif input:wasPressed('down')then self.index=self.index%n+1;self.message=nil;self:refreshPreview()
 elseif input:wasPressed('left')then self:step(-1)
 elseif input:wasPressed('right')then self:step(1)
 elseif input:wasPressed('a')then self:choose()
 elseif input:wasPressed('start')then if self.page==#self.pages then self.index=#rows-1 else self:next()end
 elseif input:wasPressed('select')then self.species=self.species%4+1;self:refreshPreview()
 elseif input:wasPressed('b')then
  if self.subpage then self.subpage=nil;self.index=1;self:refreshPreview()
  elseif self.page>1 then self.page=self.page-1;self.index=1;self:refreshPreview();persist(self,false)
  else self:pause()end
 end
end
function Screen:pause()if not persist(self,false)then return false end;self.game.stack:pop();return true end
function Screen:pointer(p)
 if p.phase~='pressed' then return true end
 if p.button and p.button~=1 then return true end
 local g=self.physical;if not g then return true end
 local x,y=(p.x-g.x)/g.scale,(p.y-g.y)/g.scale
 if self.trial then self:stopBenchmark(true);return true end
 if g.portrait then
  for _,hit in ipairs(g.hits)do if x>=hit.x and x<=hit.x+hit.w and y>=hit.y and y<=hit.y+hit.h then hit.action();break end end
  return true
 end
 if y>=684 and y<=736 then
  if x>=38 and x<=188 then if self.subpage then self.subpage=nil else self.page=math.max(1,self.page-1)end;self.index=1;self:refreshPreview()
  elseif x>=201 and x<=391 then self:pause()
  elseif x>=879 and x<=1061 then if self.page==#self.pages then self:apply()else self:next()end end
 elseif x>=36 and x<=507 and y>=232 and y<610 then
  local start=math.max(1,self.index-5);local i=start+math.floor((y-232)/63)
  if self:rows()[i]then self.index=i;self.message=nil;self:refreshPreview();self:choose()end
 elseif x>=541 and x<=1076 and y>=220 and y<=514 then self.species=self.species%4+1;self:refreshPreview()end
 return true
end
function Screen:exit()self:stopBenchmark(true);self.preview:release()end
local fonts={}
local paintScale=1
local function text(t,x,y,w,size,color)
 local G=love.graphics;local px=math.max(12,math.floor((size or 20)*paintScale+.5))
 if not fonts[px]then fonts[px]=G.newFont(px)end
 G.push('all');G.translate(x,y);G.scale(1/paintScale,1/paintScale);G.setFont(fonts[px]);G.setColor(color or {1,1,1,1});G.printf(t or '',0,0,w*paintScale,'left');G.pop()
end
local function panel(x,y,w,h,fill,line)
 local G=love.graphics;G.setColor(fill);G.rectangle('fill',x,y,w,h,9)
 if line then G.setColor(line);G.setLineWidth(1.2);G.rectangle('line',x+.6,y+.6,w-1.2,h-1.2,9)end
end
-- The engine UI canvas is capped at 640 px. Text is deliberately drawn after
-- that compositor at physical window resolution, as the F3 panel is.
function Screen:draw()end
function Screen:drawPhysical()
 if not self.trial and self.effects then V.require('SetupEffects').refresh(self.effects,self.draft);self.performance=self.effects.performance end
 local width,height=love.graphics.getDimensions()
 if not self.trial and width<height then return V.require('SetupPortrait').draw(self,sourceHelp) end
 local G=love.graphics;G.push('all');G.setCanvas();G.origin();G.setShader();G.setScissor();G.setDepthMode();G.setColor(1,1,1,1)
 local ww,wh=G.getDimensions();paintScale=math.min(ww/1100,wh/760)
 local ox,oy=(ww-1100*paintScale)/2,(wh-760*paintScale)/2
 local accent,id=V.require('EditionAccent').color(self.editionPreview)
 local ink={.95,.97,1,1};local muted={.74,.81,.9,1}
 local tinted={.07+accent[1]*.14,.09+accent[2]*.14,.14+accent[3]*.14,1}
 local highlight={.82+accent[1]*.18,.82+accent[2]*.18,.82+accent[3]*.18,1}
 self.physical={scale=paintScale,x=ox,y=oy}
 if not self.trial then G.setColor(.025,.045,.085,1);G.rectangle('fill',0,0,ww,wh)end
 G.translate(ox,oy);G.scale(paintScale,paintScale)
 if self.trial then
  panel(24,20,1052,128,{.025,.045,.085,.95},accent)
  if self.trial.full then
   local t=self.trial;local phase=t.plan[t.phase]
   text(t.paused and L("Graphics check paused · activate window",'Grafikcheck pausiert · Fenster aktivieren') or (phase and phase.label or L("Evaluating",'Auswertung')),44,36,1004,29)
   text(string.format(L("%d / %d seconds · %d / %d test phases. X or click: cancel.",'%d / %d Sekunden · %d / %d Prüfphasen. X oder Klick: abbrechen.'),math.min(t.duration,math.floor(t.elapsed)),t.duration,math.min(#t.plan,t.phase),#t.plan),44,78,1004,21,muted)
   text(L("Look for flickering, missing ground and black surfaces.",'Achte auf Flackern, fehlende Böden und schwarze Flächen.'),44,110,1004,19,muted)
   G.pop();return
  end
  text(self.trial.details and (L("Detail comparison · ",'Detailvergleich · ')..(self.trial.phase==1 and L('CURRENT','BISHER') or L('DRAFT','ENTWURF'))) or self.trial.worldOnly and L("Your world profile · live preview",'Dein Weltprofil · Live-Vorschau') or L("Lighting comparison · ",'Lichtvergleich · ')..(self.trial.phase==1 and L("OFF",'AUS') or L("ON",'AN')),44,36,1004,30)
  text(L("Returning in ",'Rückkehr in ')..math.max(0,math.ceil(10-self.trial.elapsed))..L(" seconds. ",' Sekunden. ')..(self.trial.details and L("Compare the visible characters and surfaces.",'Vergleiche die sichtbaren Figuren und Oberflächen.') or self.trial.worldOnly and L("Compare nature, buildings and distant scenery.",'Vergleiche Natur, Gebäude und Ferne.') or L("Look for flickering, black surfaces and excessive brightness.",'Achte auf Flackern, schwarze Flächen und Überstrahlung.'))..L(" X or click: cancel.",' X oder Klick: abbrechen.'),44,81,1000,22,muted)
  G.pop();return
 end
 G.setColor(accent);G.rectangle('fill',0,0,5,760);G.rectangle('fill',1097,0,3,760)
 panel(24,20,1052,58,tinted,accent)
 local names={red=L('RED','ROT'),blue=L('BLUE','BLAU'),yellow=L('YELLOW','GELB'),gold='GOLD',silver=L('SILVER','SILBER'),crystal=L('CRYSTAL','KRISTALL'),shared='VASC'}
 text(L("VASC / KASC  ·  YOUR LOOK",'VASC / KASC  ·  DEIN LOOK'),44,35,690,23)
 text((names[id] or 'VASC')..'  ·  '..self.page..' / '..#self.pages,850,39,205,18,highlight)
 local p=self:current();local summary=p.kind=='summary';local rows=self:rows()
 text(p.title,30,97,1040,30)
 text(p.description,30,145,1040,20,muted)
 panel(24,220,495,410,{.06,.12,.21,.92},accent)
 local start=math.max(1,self.index-5)
 for i=start,math.min(#rows,start+5)do
  local r=rows[i];local y=232+(i-start)*63;local selected=i==self.index
  panel(36,y,471,56,selected and tinted or {.045,.085,.145,1},selected and accent or nil)
  if selected then G.setColor(accent);G.rectangle('fill',36,y+8,4,40)end
  text(r.label,50,y+6,440,r.key and 19 or 20,r.disabled and {.5,.56,.64,1} or ink)
  if r.key then text(r.scopeBefore and ((self.draft[r.key] and L("Yes: ",'Ja: ') or L("No: ",'Nein: '))..r.scopeBefore..' > '..(self.draft[r.key] and r.scopeAfter or L('keep','beibehalten'))) or '<  '..self:label(r)..'  >',50,y+31,440,17,highlight)end
 end
 text(string.format(L("Selection %d of %d · More rows with Up / Down",'Auswahl %d von %d · Weitere Zeilen mit Hoch / Runter'),self.index,#rows),30,642,493,17,muted)
 local scene
 if p.kind=='world' or p.kind=='battle' and not (rows[self.index] and (rows[self.index].key=='_battleGraphics' or rows[self.index].key=='pokemonModelSkin' or rows[self.index].action=='rom' or rows[self.index].action=='content')) then
  local mode=self.draft[self.stageKey]
  local name=p.kind=='world' and 'world-'..(self.draft.outdoorHorizon or 'voxel') or 'battle-'..(mode==true and 'map' or mode==false and 'classic' or tostring(mode))
  self.sceneImages=self.sceneImages or {}
  if self.sceneImages[name]==nil then local ok,img=pcall(require('src.render.Assets').image,V.mod.assets:path('assets/setup-demo/'..name..'.png'));self.sceneImages[name]=ok and img or false end
  scene=self.sceneImages[name]
 end
 panel(541,220,535,294,{.045,.085,.145,1},accent)
 if p.kind=='welcome' then
  text(L("Set it up once, at your own pace.",'Einmal sauber einrichten.'),561,244,493,27,highlight)
  text(L("Compare characters and Pokémon.\nChoose your battle and world style.\nAdjust graphics and lighting.\n\nEverything stays a draft until Apply.",'Figuren und Pokémon vergleichen.\nDen bevorzugten Kampf- und Weltstil wählen.\nGrafik und Licht passend einstellen.\n\nBis „Übernehmen“ bleibt alles ein Entwurf.'),561,292,489,22)
 elseif p.kind=='effect'then
  local d=V.require('SetupEffects').details(self.effects,p.effect,self.draft)
  text(L('Performance: ','Leistung: ')..d.performance,561,240,489,20,ink)
  text(L('Image: ','Bild: ')..d.visual,561,290,489,20,ink)
  text(L('Combination: ','Kombination: ')..d.combined,561,340,489,20,ink)
  local r=d.record
  if r and r.off and r.on then text(string.format(L('Median OFF %.1f ms / ON %.1f ms','Median AUS %.1f ms / AN %.1f ms'),r.off*1000,r.on*1000),561,391,489,18,muted)end
  if r and r.coverage then
   local c=r.coverage;local names={['night-windows']=L('Night / window lights','Nacht / Fensterlicht'),['rain-water']=L('Rain / water','Regen / Wasser'),['moving-battle']=L('Battle / camera movement','Kampf / Kamerabewegung'),['day-nature']=L('Day / nature','Tag / Natur')}
   text((names[c.scenario]or c.scenario)..string.format(L(' · %d local lights',' · %d lokale Lichter'),c.lights or 0),561,432,489,18,muted)
   text(c.scenario=='moving-battle'and (c.moving and L('Camera movement observed','Kamerabewegung nachgewiesen')or L('Movement not observed: retest','Bewegung nicht nachgewiesen: nachtesten'))or c.scenario=='rain-water'and (c.rain and c.water and L('Rain and water pass observed','Regen und Wasserdurchlauf nachgewiesen')or p.effect=='combined'and c.rain and r.candidates and not r.candidates.reflections and L('Rain observed; full reflection not included','Regen nachgewiesen; volle Spiegelung nicht dabei')or L('Scene coverage incomplete','Szenenabdeckung unvollständig'))or '',561,469,489,17,muted)
  end
 elseif summary or p.kind=='device' or p.kind=='lighting' then
  if not summary then
   local renderer,version,vendor,device=G.getRendererInfo()
   text(L("Your device",'Dein Gerät'),561,240,493,24,highlight)
   text(tostring(device)..' · '..love.system.getOS(),561,281,489,19,muted)
  else text(L("You can change your choices later.",'Deine Auswahl bleibt änderbar.'),561,242,489,26,highlight)end
  text(p.kind=='device' and L("The graphics check tests resolution and effects next. Its recommendations are preselected in your draft.",'Der Grafikcheck prüft anschließend Auflösung und Effekte. Seine Empfehlungen stehen automatisch im Entwurf.') or self:recommendation(),561,summary and 294 or 326,489,22)
  if self.performance then
   text(string.format(self.performance.lowerBound and L("At least level %d / 6 · %s",'Mindestens Stufe %d / 6 · %s')or L("Level %d / 6 · %s",'Stufe %d / 6 · %s'),self.performance.level,V.require('SetupBenchmark').tiers[self.performance.level] or self.performance.label),561,420,489,24,highlight)
   text(string.format(L("VASC · %s · frame time %.1f ms",'VASC · %s · Bildzeit %.1f ms'),({economy='720p',balanced='1080p',native=L("Native",'Nativ')})[self.performance.resolution]or L("current resolution",'aktuelle Auflösung'),self.performance.renderMs),561,459,489,17,muted)
  elseif p.kind~='device' then text(L("Six levels: Weak to High-End.\nUnstable checks do not assign a rating.",'Sechs Stufen: Schwach bis High-End.\nBei instabilem Test keine Einstufung.'),561,430,489,19,muted)end
 elseif p.kind=='battle_controls' then
  self:drawControlsPreview(554,230,509,252)
  text(L('Layout preview · touch spacing can differ','Layoutvorschau · Touch-Abstände können abweichen'),558,486,505,16,muted)
 elseif scene then
  local iw,ih=scene:getDimensions();local scale=math.min(509/iw,252/ih);G.setColor(1,1,1,1);G.draw(scene,554+(509-iw*scale)/2,230,0,scale,scale)
  text(L("Actual demo capture · example setting",'Echte Demo-Aufnahme · Kulisse als Beispiel'),558,486,505,16,muted)
 else
  self.preview:draw(548,226,521,254)
  text((self.preview.human and (rows[self.index] and rows[self.index].key=='apo_voxel_character_finish' and L("Source artwork without relief",'Quellgrafik ohne Relief') or L("Character style example: Red",'Figuren-Stilbeispiel: Red')) or ({L("Bulbasaur",'Bisasam'),'Pikachu',L("Charizard",'Glurak'),L("Eevee",'Evoli')})[self.species])..L(" · Click / Tab: change example",' · Klick / Tab: Beispiel wechseln'),558,486,505,16,muted)
 end
 local r=rows[self.index];local help=r and r.help or ''
 if r and r.context then help=sourceHelp[self.draft[r.key]] or L("Keeps the existing global model priority.",'Behält die vorhandene globale Modellreihenfolge bei.')end
 if self.message then help=self.message
 elseif self.preview.error and not scene and (p.kind=='pokemon' or p.kind=='people' or p.kind=='dex' or p.kind=='battle') then help=help..'\n'..self.preview.error end
 panel(541,530,535,134,{.06,.12,.21,.92},accent)
 -- Explanation remains white and large; edition colour is for borders/focus.
 local n=19;local probe=G.newFont(math.floor(n*paintScale));local _,wrapped=probe:getWrap(help,493*paintScale);probe:release()
 if #wrapped*n>113 then n=17 end
 text(help,560,542,496,n,self.message and {1,.84,.5,1} or ink)
 panel(24,684,1052,52,{.045,.085,.145,1},accent)
 for _,button in ipairs({{x=38,w=150,label=L("Back",'Zurück')},{x=201,w=190,label=L("Save for later",'Später speichern')},{x=879,w=182,label=summary and L("Apply",'Übernehmen') or L("Next",'Weiter')}})do
  panel(button.x,692,button.w,36,tinted,nil);text(button.label,button.x+13,698,button.w-20,19)
 end
 text(L("F3 · main VASC menu · main KASC menu",'F3 · großes VASC-Menü · großes KASC-Menü'),416,702,451,17,muted)
 text(L("Arrows: select   Enter: choose   Esc: next   X: back   Tab: example",'Pfeile: Auswahl   Enter: Wählen   Esc: Weiter   X: Zurück   Tab: Beispiel'),30,744,1040,15,muted)
 G.pop()
end
function M.install(mod,config)
 local settings=config.settings;M.rom=config.stadiumRomMenu
 local Game=require('src.core.Game');local baseDraw=Game.draw
 -- The engine asks the gamepad overlay before input.pointer. This screen
 -- covers that overlay, so its own touch buttons must receive the press.
 -- Leave the player's touch layout and visibility preferences untouched.
 local baseTouch=Game.touchpressed
 function Game:touchpressed(id,x,y,dx,dy,pressure)
  local top=self.stack:top()
  if getmetatable(top)==Screen then return top:pointer{phase='pressed',source='touch',id=id,x=x,y=y,pressure=pressure} end
  if baseTouch then return baseTouch(self,id,x,y,dx,dy,pressure)end
 end
 function Game:draw(...)
  local top=self.stack:top()
  if getmetatable(top)==Screen and top.trial then
   -- Render exactly the normal world viewport; a setup UI surface changes
   -- the engine's world dimensions even when its background is transparent.
   local states=self.stack.states;local index=#states;table.remove(states,index)
   local started=love.timer.getTime();if top.trial.full then V.require('SetupBenchmark').frame(top,started)end;local E=V.require('SetupEffects');E.resetFrame()
   local ok,err=pcall(baseDraw,self,...);table.insert(states,index,top)
   if not ok then
    if top.trial.full then top:stopBenchmark(true);top.message=L("Graphics error during the test. Cancelled and previous settings restored.",'Grafikfehler im Test. Abgebrochen und bisherige Einstellungen wiederhergestellt.');return top:drawPhysical()end
    error(err)
   end
   if top.trial.full then local measured,why=pcall(V.require('SetupBenchmark').capture,top,started);if not measured then top.trial.error=tostring(why)end end
   top:drawPhysical()
  else
   baseDraw(self,...)
   top=self.stack:top();if getmetatable(top)==Screen then top:drawPhysical()end
  end
 end
 mod.hooks:wrap('input.pointer',function(nextPointer,game,p)
  local top=game.stack:top();if getmetatable(top)==Screen then return top:pointer(p)end
  return nextPointer(game,p)
 end,2000010)
 local fallbackPrompts
 local function prompts()
  local content=mod.exports.ascendantContent
  if content and content.startupPrompts then return content.startupPrompts end
  if not fallbackPrompts then fallbackPrompts=V.require('StartupPrompts').new(mod.cache)end
  return fallbackPrompts
 end
 mod.content.screens:register('VascSetup',{new=function(game,opts)
  local screen=M.new(game,settings,opts)
  if not prompts():mark('setup') and mod.log then mod.log:warn('Could not persist the one-time setup introduction')end
  return screen
 end})
 local seen=setmetatable({},{__mode='k'})
 mod.hooks:wrap('core.update',function(nextUpdate,game,dt)
  local result=nextUpdate(game,dt)
  if not (mod.exports.setupCard and mod.exports.setupCard.suspended) and game and game.save and game.overworld and game.stack:top()==game.overworld and not seen[game.save] then
   local receipt=M.receipt(game)
   if prompts():due('setup',receipt.version~=nil) then
    local content=mod.exports.ascendantContent
    if content and not content.onboardingShown and not content.promptDisabled
      and prompts():due('downloads') then
     content.offerRequested=true
     mod.ui.push(game,'VascPokemonHdOffer');return result
    end
    seen[game.save]=true;mod.ui.push(game,'VascSetup')
   else seen[game.save]=true end
  end
  return result
 end)
 mod.exports.setupCard={title=function()return L('YOUR LOOK','DEIN LOOK')end,description=function()return L('Set up characters, Pokémon, battles, world and lighting with previews.','Figuren, Pokémon, Kampf, Welt und Licht mit Vorschau einrichten.')end,schema='vasc/dein-look/v3',open=function(game)return mod.ui.push(game,'VascSetup')end,new=function(game,opts)return M.new(game,settings,opts)end}
end
M.Screen=Screen
return M
