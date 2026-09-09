-- One saved schema for both generations. APO source keys remain private to
-- its adapter; battle model keys are deliberately never written here.
local M = { PREFIX="apo_" }
local rows = {
  {"enabled", "OVERWORLD CARD", "OVERWORLD-CARD", "pokemon", true,
    "Enable the integrated APO RC32 snapshot. Changing this master switch requires a game reload.",
    "Integrierten APO-RC32-Stand aktivieren. Dieser Hauptschalter benötigt einen Spielneustart."},
  {"hd_walking_sprites", "HD PEOPLE", "HD-MENSCHEN", "pokemon", true,
    "Use bundled HD player/NPC artwork. Requires OVERWORLD CARD enabled at game start; after enabling that master switch, reload the game. Pokemon downloads and model sources do not control HD people. Character selection stays with the game, KASC or JASC."},
  {"pokemon_model_source", "OVERWORLD MODELS", "OVERWORLD-MODELLE", "pokemon", "auto",
    "Overworld only: Stadium 2 models, Full HD render sprites, then original sprites. Explicit MMO context choices take precedence. Battle models are unchanged.", nil,
    {{"AUTO: MODELS > FULL HD", "auto"}, {"STADIUM 2 > SPRITES", "stadium_only"}, {"FULL HD > MODELS", "go_first"}, {"FULL HD SPRITES", "go_only"}, {"SPRITES ONLY", "sprite_only"}}},
  {"hd_pokemon_followers", "HD FOLLOWERS", "HD-BEGLEITER", "wilds", true, "Replace follower artwork only; the existing provider keeps selection and movement."},
  {"follower_sprite_source", "FOLLOWER SOURCE", "BEGLEITER-QUELLE", "pokemon", "hd", "Follow model priority, prefer Stadium 2, or force Full HD/MMO sprites for followers. Missing assets keep a safe source. Stadium requires the existing overworld model switch and a usable imported model."},
  {"hd_pokemon_grass", "HD WILD POKEMON", "HD-WILDE POKEMON", "wilds", true, "Replace existing grass/cave Pokemon artwork without changing spawns or encounters."},
  {"grass_pokemon_sprite_source", "WILD SOURCE", "WILD-QUELLE", "pokemon", "hd", "Independent source for grass/cave Pokemon: global priority, Stadium 2 with sprite fallback, Full HD or MMO."},
  {"hd_pokemon_city", "HD TOWN POKEMON", "HD-STADT-POKEMON", "wilds", true, "Replace identified town and indoor Pokemon artwork, not their story or behaviour."},
  {"city_pokemon_sprite_source", "TOWN SOURCE", "STADT-QUELLE", "pokemon", "hd", "Independent source for fixed town/indoor Pokemon: global priority, Stadium 2 with sprite fallback, Full HD or MMO."},
  {"hd_pokemon_wilds_towns", "HD AMBIENT POKEMON", "HD-AMBIENT-POKEMON", "wilds", true, "Replace peaceful Wilds town Pokemon artwork. Wilds keeps ownership of spawning and behaviour."},
  {"wilds_town_pokemon_sprite_source", "AMBIENT SOURCE", "AMBIENT-QUELLE", "pokemon", "hd", "Independent source for peaceful Wilds town Pokemon: global priority, Stadium 2 with sprite fallback, Full HD or MMO."},
  {"living_follower_animation", "POKEMON ANIMATION", "POKEMON-ANIMATION", "pokemon", true, "Play downloaded walk, flight and idle frames. Download Kanto stages under POKEMON HD DOWNLOADS, then restart. Missing species retain MMO/original fallbacks."},
  {"pikachu_head_ride", "PIKACHU HEAD RIDE", "PIKACHU AUF DEM KOPF", "wilds", false, "Let an identified Pikachu follower briefly ride on the player's head. Visual only; menus, riding, surfing and map changes cancel it.", "Ein erkannter Pikachu-Begleiter sitzt kurz auf dem Kopf. Nur Darstellung; Menüs, Rad, Surfen und Kartenwechsel brechen ab."},
  {"pokemon_card_style", "FULL HD STYLE", "FULL-HD-STIL", "pokemon", "off", "Optional contour/cel shading for supported Full HD sprites. Does not alter MMO sprites, Stadium models or voxel-grid figures.", nil,
    {{"ORIGINAL", "off"}, {"FINE OUTLINE", "outline"}, {"SUBTLE ANIME", "anime"}, {"COMIC OUTLINE", "comic"}}},
  {"actor_voxel_grid", "ACTOR VOXEL GRID", "FIGUREN-VOXELRASTER", "pokemon", "off", "Voxel grid for people, Pokemon or both. Independent of terrain and battle grids.", nil,
    {{"OFF", "off"}, {"PEOPLE", "characters"}, {"POKEMON", "pokemon"}, {"BOTH", "both"}}},
  {"actor_voxel_cubes", "ACTOR VOXEL DEPTH", "FIGUREN-VOXELTIEFE", "pokemon", "off", "Depth of enabled actor voxel grids. No effect when the actor grid is off.", nil,
    {{"FLAT SLICES", "off"}, {"SUBTLE", "subtle"}, {"MEDIUM", "balanced"}, {"STRONG", "strong"}, {"EXTREME", "extreme"}}},
  {"voxel_character_finish", "PEOPLE RELIEF", "MENSCHEN-RELIEF", "pokemon", true, "Use VASC's HD character relief. Does not choose or replace the player identity."},
  {"voxel_pokemon_finish", "POKEMON RELIEF", "POKEMON-RELIEF", "pokemon", true, "Apply the supplied relief treatment to compatible Pokemon render sprites."},
  {"dynamic_follower_spacing", "FOLLOWER SPACING", "BEGLEITERABSTAND", "wilds", true, "Size-dependent visible spacing along the walked path. Does not change logical movement or collision."},
  {"pokemon_collision_mode", "POKEMON COLLISION", "POKEMON-KOLLISION", "wilds", "normal", "Normal or passable for compatible Pokemon only. Saved SOFT is blocked without owner yielding support and keeps solid collision. Story actors, humans and protected Wilds are untouched.", "Normal oder durchlaufbar nur für kompatible Pokémon. Gespeichertes WEICH ist ohne Ausweich-Schnittstelle gesperrt und blockiert weiter. Story, Menschen und geschützte Wilds bleiben unverändert.",
    {{"NORMAL", "normal"}, {"PASSABLE", "passable"}}},
  {"atmospheric_sprite_shading", "ACTOR SCENE LIGHT", "FIGUREN-SZENENLICHT", "weather", false, "Tint supported HD figures with VASC time and weather. OFF preserves their authored colours. Panorama lighting is independent."},
}
local sourceChoices = {{"FOLLOW MODEL PRIORITY", "hd"}, {"STADIUM 2 > FULL HD", "stadium2"}, {"FULL HD SPRITES", "full_hd"}, {"MMO SPRITES", "pokemmo"}}
-- Translate only presentation text; option ids, defaults and provider priority
-- remain identical in both languages and both generations.
local descriptionsDe = {
  hd_walking_sprites="Mitgelieferte HD-Grafiken für Spieler und Menschen nutzen. OVERWORLD-CARD muss beim Spielstart AN sein; nach Aktivierung dieses Hauptschalters das Spiel neu laden. Pokémon-Downloads und Modellquellen steuern HD-Menschen nicht. Die Charakterauswahl bleibt beim Spiel, KASC oder JASC.",
  pokemon_model_source="Nur Oberwelt: Stadium-2-Modelle, Full-HD-Sprites, dann Originalgrafiken. Ausdrückliche MMO-Auswahl hat Vorrang. Kampfmodelle bleiben unverändert.",
  hd_pokemon_followers="Nur Begleitergrafiken ersetzen. Auswahl und Bewegung bleiben beim bisherigen Anbieter.",
  follower_sprite_source="Modellreihenfolge nutzen, Stadium 2 bevorzugen oder Full-HD-/MMO-Sprites wählen. Fehlende Grafiken nutzen Ersatz. Stadium benötigt aktivierte Oberweltmodelle und einen nutzbaren Modellimport.",
  hd_pokemon_grass="Grafiken vorhandener Gras- und Höhlen-Pokémon ersetzen. Begegnungen und Erzeugung bleiben unverändert.",
  grass_pokemon_sprite_source="Eigene Quelle für Gras- und Höhlen-Pokémon: Modellreihenfolge, Stadium 2 mit Sprite-Ersatz, Full HD oder MMO.",
  hd_pokemon_city="Grafiken erkannter Stadt- und Gebäude-Pokémon ersetzen. Geschichte und Verhalten bleiben unverändert.",
  city_pokemon_sprite_source="Eigene Quelle für feste Stadt- und Gebäude-Pokémon: Modellreihenfolge, Stadium 2 mit Sprite-Ersatz, Full HD oder MMO.",
  hd_pokemon_wilds_towns="Grafiken friedlicher Wilds-Stadt-Pokémon ersetzen. Wilds steuert weiterhin Erzeugung und Verhalten.",
  wilds_town_pokemon_sprite_source="Eigene Quelle für friedliche Wilds-Stadt-Pokémon: Modellreihenfolge, Stadium 2 mit Sprite-Ersatz, Full HD oder MMO.",
  living_follower_animation="Geladene Lauf-, Flug- und Ruheanimationen abspielen. Kanto-Pakete unter POKéMON-HD-DOWNLOADS laden, danach neu starten. Fehlende Arten nutzen MMO- oder Originalgrafiken.",
  pokemon_card_style="Optionale Konturen für unterstützte Full-HD-Sprites. MMO-Sprites, Stadium-Modelle und Voxel-Figuren bleiben unverändert.",
  actor_voxel_grid="Voxelraster für Menschen, Pokémon oder beide. Unabhängig vom Gelände- und Kampfraster.",
  actor_voxel_cubes="Tiefe aktivierter Figuren-Voxelraster. Ohne aktives Figurenraster keine Wirkung.",
  voxel_character_finish="VASC-HD-Relief für Menschen nutzen. Die Spieleridentität bleibt unverändert.",
  voxel_pokemon_finish="Mitgeliefertes Relief auf kompatible Pokémon-Sprites anwenden.",
  dynamic_follower_spacing="Sichtbarer Abstand entlang des Laufwegs abhängig von der Größe. Logische Bewegung und Kollision bleiben unverändert.",
  atmospheric_sprite_shading="Unterstützte HD-Figuren an Tageszeit und Wetter anpassen. AUS erhält die Originalfarben. Panoramabeleuchtung ist unabhängig.",
}
local valuesDe = {
  OFF="AUS", ON="AN", ["FOLLOW MODEL PRIORITY"]="MODELLREIHENFOLGE",
  ["AUTO: MODELS > FULL HD"]="AUTO: MODELLE > FULL HD",
  ["STADIUM 2 > SPRITES"]="STADIUM 2 > SPRITES",
  ["FULL HD > MODELS"]="FULL HD > MODELLE", ["SPRITES ONLY"]="NUR SPRITES",
  ["FINE OUTLINE"]="FEINE KONTUR", ["SUBTLE ANIME"]="DEZENTES ANIME",
  ["COMIC OUTLINE"]="COMIC-KONTUR", PEOPLE="MENSCHEN", BOTH="BEIDE",
  ["FLAT SLICES"]="FLACHE SCHICHTEN", SUBTLE="DEZENT", MEDIUM="MITTEL",
  STRONG="STARK", EXTREME="EXTREM", PASSABLE="DURCHLAUFBAR",
}
local function german(mod)
  if not (mod and mod.find) then return false end
  local ok, handle = pcall(mod.find, mod, "translation-german-universal")
  if not ok or not handle then ok, handle = pcall(mod.find, "translation-german-universal") end
  return ok and handle and handle.exports and handle.exports.bootLanguage == "de"
end
M.isGerman = german
function M.schema(mod)
  local out, de = {}, german(mod)
  for _, r in ipairs(rows) do
    local choices = r[8] or (r[5]=="hd" and sourceChoices or nil)
    if choices then
      local copy = {}
      for i, choice in ipairs(choices) do
        copy[i] = {de and (valuesDe[choice[1]] or choice[1]) or choice[1], choice[2]}
      end
      choices = copy
    end
    out[#out+1] = {key=M.PREFIX..r[1], label=de and r[3] or r[2],
      type=type(r[5])=="boolean" and "toggle" or "choice", default=r[5],
      choices=choices,
      description=de and (r[7] or descriptionsDe[r[1]] or r[6]) or r[6]}
  end
  return out
end
function M.section(key)
  for _, r in ipairs(rows) do if key==M.PREFIX..r[1] then return r[4] end end
end
local collisionKey=M.PREFIX.."pokemon_collision_mode"
local pokemonRefreshKeys={apo_hd_pokemon_followers=true,apo_hd_pokemon_grass=true,
  apo_hd_pokemon_city=true,apo_hd_pokemon_wilds_towns=true,
  apo_pokemon_model_source=true,apo_follower_sprite_source=true,
  apo_grass_pokemon_sprite_source=true,apo_city_pokemon_sprite_source=true,
  apo_wilds_town_pokemon_sprite_source=true}
local hdKeys={apo_living_follower_animation=true,apo_pokemon_card_style=true,
  apo_voxel_pokemon_finish=true,apo_pikachu_head_ride=true}
local function hdReady(mod)
  local api=mod and mod.exports and mod.exports.pokemonHdContent
  if not api then return false end
  local ok,ready=pcall(api.ready);return ok and ready==true
end
local function collisionSpec(mod)
  for _,spec in ipairs(M.schema(mod)) do if spec.key==collisionKey then return spec end end
end
function M.managerExtras(mod)
  local spec=collisionSpec(mod)
  spec.visible_if={key=collisionKey,equals="soft"}
  spec.choices={{german(mod) and "WEICH: GESPERRT" or "SOFT: BLOCKED","soft"},
    {"NORMAL","normal"},{german(mod) and "DURCHLAUFBAR" or "PASSABLE","passable"}}
  return {spec}
end
function M.managerSchema(mod)
  local schema=M.schema(mod)
  for _,spec in ipairs(schema) do
    if spec.key==collisionKey then spec.visible_if={key=collisionKey,not_equals="soft"} end
  end
  schema[#schema+1]=M.managerExtras(mod)[1]
  return schema
end
-- Native VASC pages always have a two-stop ladder. Preserve the stored SOFT
-- intent and display its blocked state, but never cycle back into it.
function M.decorateSetting(mod, setting)
  if (setting.key == "apo_hd_walking_sprites" or pokemonRefreshKeys[setting.key])
      and not setting._apoLivePeople then
    -- VASC's own ModSetting writes do not emit the Manager's option event.
    -- Refresh bound people and Pokemon sources immediately, while still.
    local original = setting.setIndex
    setting.setIndex = function(self, index, game, silent)
      local value = original(self, index, game, silent)
      local api = mod.exports and mod.exports.overworldPokemon
      local walking = api and (pokemonRefreshKeys[self.key]
        and api.pokemonWorldSprites or api.walkingSprites)
      if walking and type(walking.refresh) == "function" then
        walking.refresh(game)
      end
      return value
    end
    setting._apoLivePeople = true
  end
  if german(mod) then
    for i, label in ipairs(setting.labels or {}) do
      setting.labels[i] = valuesDe[label] or label
    end
  end
  if hdKeys[setting.key]then
    local original=setting.row
    setting.row=function(self)
      local row=original(self);local value,step=row.value,row.step
      row.muted=not hdReady(mod)
      row.value=function(...)
        if not hdReady(mod)then return german(mod) and "DOWNLOAD FEHLT" or "DOWNLOAD REQUIRED"end
        return value(...)
      end
      row.step=function(...)
        if not hdReady(mod)then return false end
        return step(...)
      end
      return row
    end
  elseif setting.key=="apo_pokemon_model_source" or setting.key:match("^apo_.+sprite_source$")then
    -- Keep AUTO/MMO/Stadium selectable; only the explicit missing-HD stops
    -- are unavailable. A saved preference is retained for the next restart.
    local original=setting.allows
    setting.allows=function(self,i)
      local v=self.values[i]
      if not hdReady(mod) and (v=="full_hd" or v=="go_only" or v=="go_first")then return false end
      return original(self,i)
    end
  end
  if setting.key~=collisionKey then return setting end
  setting.values,setting.labels={"normal","passable"},{"NORMAL",german(mod) and "DURCHLAUFBAR" or "PASSABLE"}
  setting.defaultIndex,setting.index=1,nil
  local originalRow=setting.row
  setting.row=function(self)
    local row=originalRow(self)
    local value=row.value
    row.value=function(...)
      local ok,stored=pcall(mod.options.get,mod.options,collisionKey)
      if ok and stored=="soft" then return german(mod) and "WEICH: GESPERRT" or "SOFT: BLOCKED" end
      return value(...)
    end
    return row
  end
  setting.schema=function(_,help)
    local spec=collisionSpec(mod);spec.help=help
    spec.visible_if={key=collisionKey,not_equals="soft"}
    return spec
  end
  return setting
end
function M.addKeys(sections)
  for _, r in ipairs(rows) do
    local section=sections[r[4]]
    if section then section.keys=section.keys or {}; section.keys[M.PREFIX..r[1]]=true end
  end
end
function M.entries(mod, ModSetting)
  local entries={}
  for _, spec in ipairs(M.schema(mod)) do
    local values, labels={}, {}
    if spec.type=="toggle" then values,labels={false,true},{"OFF","ON"}
    else for _, choice in ipairs(spec.choices) do values[#values+1]=choice[2]; labels[#labels+1]=choice[1] end end
    entries[#entries+1]={M.decorateSetting(mod,ModSetting.new(spec.key,spec.label,values,labels,spec.default)),spec.description,full=true}
  end
  return entries
end
return M
