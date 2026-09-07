-- VASC Kanto Fly Map Widescreen.
--
-- This companion owns one presentation-only screen. It reads the game's
-- existing current-map and visited-map state, but never writes map data,
-- collision, warps, story flags, Fly destinations or VASC internals.

return function(mod)
  local SCREEN_ID = "VascKantoFlyMapWidescreen"
  local IMAGE_PATH = "assets/maps/kanto_fly_map_wide.png"
  local ZOOM_IMAGE_PATH = "assets/maps/kanto_fly_map_wide_zoom.png"
  local UI_WIDTH, UI_HEIGHT = 576, 324
  local MAP_WIDTH, MAP_HEIGHT = 576, 324
  local MAP_VIEW_WIDTH = 432
  -- The source-exact Kanto art occupies 1401 of the 1820 master pixels and
  -- the lower crop changes its vertical mapping slightly. Separate scales
  -- keep every established marker on the same city after the 16:9 reframe.
  local MAP_COORD_SCALE_X = 2.770
  local MAP_COORD_SCALE_Y = 2.781

  local function requestedMode()
    local resolver = mod.kantoFlyMapMode
    if type(resolver) == "function" then
      local ok, value = pcall(resolver)
      if ok and value == "widescreen" then return "widescreen" end
    end
    return "cartridge"
  end

  local function findMod(id)
    if type(mod.find) ~= "function" then return nil end
    local ok, handle = pcall(mod.find, id)
    return ok and handle or nil
  end

  local function activeLanguage()
    local universal = findMod("translation-german-universal")
    local bootLanguage = universal and universal.exports
      and universal.exports.bootLanguage
    if bootLanguage == "de" or bootLanguage == "en" then
      return bootLanguage
    end
    local ascendant = findMod("kanto_ascendant")
    local language = ascendant and ascendant.exports
      and ascendant.exports.language
    if type(language) == "function" then
      local ok, value = pcall(language)
      if ok and value == "de" then return "de" end
    end
    for _, id in ipairs({ "deutsch", "deutsch-blau", "deutsch-gelb" }) do
      if findMod(id) then return "de" end
    end
    return "en"
  end

  local function locationLabel(location, language)
    return language == "de" and location.labelDe or location.label
  end

  local function locationDescription(location, language)
    return language == "de" and location.descriptionDe
      or location.description
  end

  local LOCATIONS = {
    {
      id = "pallet", label = "PALLET TOWN", labelDe = "ALABASTIA",
      x = 29, y = 86,
      description = "A quiet southern starting point between forest and sea.",
      descriptionDe = "Ein ruhiger Ausgangspunkt im Süden zwischen Wald und Meer.",
      highlight = "Professor Oak's laboratory and the beginning of every Kanto journey.",
      highlightDe = "Professor Eichs Labor und der Beginn jedes Kanto-Abenteuers.",
      maps = { "PALLET_TOWN", "REDS_HOUSE_1F", "REDS_HOUSE_2F",
               "BLUES_HOUSE", "OAKS_LAB", "ROUTE_1" },
    },
    {
      id = "viridian", label = "VIRIDIAN CITY", labelDe = "VERTANIA CITY",
      x = 23, y = 64,
      description = "The western gateway, with Route 2 and the deep forest.",
      descriptionDe = "Das westliche Tor mit Route 2 und dem tiefen Vertania-Wald.",
      highlight = "A green city with a Pokémon Academy and the forest road north.",
      highlightDe = "Eine grüne Stadt mit Pokémon-Schule und dem Waldweg im Norden.",
      badge = "EARTHBADGE", gymOpenFlag = "EVENT_VIRIDIAN_GYM_OPEN",
      maps = { "VIRIDIAN_CITY", "VIRIDIAN_GYM", "ROUTE_2",
               "VIRIDIAN_FOREST", "VIRIDIAN_FOREST_NORTH_GATE",
               "VIRIDIAN_FOREST_SOUTH_GATE" },
    },
    {
      id = "pewter", label = "PEWTER CITY", labelDe = "MARMORIA CITY",
      x = 31, y = 22,
      description = "A stone city at the foot of Kanto's northern mountains.",
      descriptionDe = "Eine steinerne Stadt am Fuß von Kantos Nordgebirge.",
      highlight = "Famous for its museum, Rock Gym and the road to Mt. Moon.",
      highlightDe = "Berühmt für Museum, Gesteins-Arena und den Weg zum Mondberg.",
      badge = "BOULDERBADGE",
      maps = { "PEWTER_CITY", "PEWTER_GYM", "MUSEUM_1F", "MUSEUM_2F",
               "ROUTE_3" },
    },
    {
      id = "cerulean", label = "CERULEAN CITY", labelDe = "AZURIA CITY",
      x = 92, y = 20,
      description = "Lakes, bridges and mountain approaches meet in the north.",
      descriptionDe = "Seen, Brücken und Bergpfade treffen sich im Norden.",
      highlight = "The Water Gym, Nugget Bridge and the path to Bill's cottage.",
      highlightDe = "Wasser-Arena, Nugget-Brücke und der Weg zu Bills Küstenhaus.",
      badge = "CASCADEBADGE",
      maps = { "CERULEAN_CITY", "CERULEAN_GYM", "ROUTE_4", "ROUTE_5",
               "ROUTE_9", "ROUTE_24", "ROUTE_25", "MT_MOON_1F",
               "MT_MOON_B1F", "MT_MOON_B2F", "CERULEAN_CAVE_1F",
               "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F" },
    },
    {
      id = "celadon", label = "CELADON CITY", labelDe = "PRISMANIA CITY",
      x = 64, y = 40,
      description = "Kanto's garden city and western commercial center.",
      descriptionDe = "Kantos Gartenstadt und westliches Einkaufszentrum.",
      highlight = "Known for its department store, gardens and lively Game Corner.",
      highlightDe = "Bekannt für Kaufhaus, Gärten und die lebhafte Spielhalle.",
      badge = "RAINBOWBADGE",
      maps = { "CELADON_CITY", "CELADON_GYM", "GAME_CORNER", "ROUTE_7",
               "ROUTE_16", "ROCKET_HIDEOUT_B1F", "ROCKET_HIDEOUT_B2F",
               "ROCKET_HIDEOUT_B3F", "ROCKET_HIDEOUT_B4F" },
    },
    {
      id = "saffron", label = "SAFFRON CITY", labelDe = "SAFFRONIA CITY",
      x = 92, y = 41,
      description = "The central metropolis and hub of Kanto's road network.",
      descriptionDe = "Die zentrale Metropole und Knotenpunkt des Straßennetzes.",
      highlight = "Silph Co., two fighting halls and four guarded city gates.",
      highlightDe = "Silph Co., zwei Kampfhallen und vier bewachte Stadttore.",
      badge = "MARSHBADGE",
      maps = { "SAFFRON_CITY", "SAFFRON_GYM", "FIGHTING_DOJO", "ROUTE_6",
               "SILPH_CO_2F", "SILPH_CO_3F", "SILPH_CO_4F",
               "SILPH_CO_5F", "SILPH_CO_6F", "SILPH_CO_7F",
               "SILPH_CO_8F", "SILPH_CO_9F", "SILPH_CO_10F",
               "SILPH_CO_11F" },
    },
    {
      id = "lavender", label = "LAVENDER TOWN", labelDe = "LAVANDIA",
      x = 132, y = 38,
      description = "A quiet eastern town beneath the memorial tower.",
      descriptionDe = "Ein stiller Ort im Osten unterhalb des Pokémon-Turms.",
      highlight = "The Pokémon Tower and the long pier road south to Fuchsia.",
      highlightDe = "Der Pokémon-Turm und der lange Stegweg nach Fuchsania.",
      maps = { "LAVENDER_TOWN", "ROUTE_8", "ROUTE_10", "ROUTE_12",
               "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F", "POKEMON_TOWER_2F",
               "POKEMON_TOWER_3F", "POKEMON_TOWER_4F", "POKEMON_TOWER_5F",
               "POKEMON_TOWER_6F", "POKEMON_TOWER_7F" },
    },
    {
      id = "vermilion", label = "VERMILION CITY", labelDe = "ORANIA CITY",
      x = 94, y = 61,
      description = "A bright southern harbor linked to the S.S. Anne.",
      descriptionDe = "Eine helle Hafenstadt mit Verbindung zur M.S. Anne.",
      highlight = "Kanto's great harbor, the Thunder Gym and Diglett's Cave.",
      highlightDe = "Kantos großer Hafen, die Elektro-Arena und der Digda-Tunnel.",
      badge = "THUNDERBADGE",
      maps = { "VERMILION_CITY", "VERMILION_GYM", "VERMILION_DOCK",
               "ROUTE_11", "DIGLETTS_CAVE", "SS_ANNE_1F_ROOMS",
               "SS_ANNE_2F", "SS_ANNE_2F_ROOMS", "SS_ANNE_B1F_ROOMS",
               "SS_ANNE_BOW" },
    },
    {
      id = "fuchsia", label = "FUCHSIA CITY", labelDe = "FUCHSANIA CITY",
      x = 82, y = 96,
      description = "Southern woodland, the Safari Zone and Cycling Road.",
      descriptionDe = "Südliche Wälder, Safari-Zone und Radweg.",
      highlight = "Safari Zone, Poison Gym and the meeting point of two coast roads.",
      highlightDe = "Safari-Zone, Gift-Arena und Treffpunkt zweier Küstenrouten.",
      badge = "SOULBADGE",
      maps = { "FUCHSIA_CITY", "FUCHSIA_GYM", "ROUTE_13", "ROUTE_14",
               "ROUTE_15", "ROUTE_17", "ROUTE_18", "SAFARI_ZONE_CENTER",
               "SAFARI_ZONE_EAST", "SAFARI_ZONE_NORTH", "SAFARI_ZONE_WEST" },
    },
    {
      id = "seafoam", label = "SEAFOAM ISLANDS",
      labelDe = "SEESCHAUMINSELN", x = 63, y = 106,
      description = "A cold island chain between Fuchsia and Cinnabar.",
      descriptionDe = "Eine kalte Inselkette zwischen Fuchsania und Zinnober.",
      highlight = "A cold cave maze shaped by currents, rocks and sea passages.",
      highlightDe = "Ein kaltes Höhlenlabyrinth aus Strömungen, Felsen und Meerwegen.",
      maps = { "ROUTE_19", "ROUTE_20", "SEAFOAM_ISLANDS_1F",
               "SEAFOAM_ISLANDS_B1F", "SEAFOAM_ISLANDS_B2F",
               "SEAFOAM_ISLANDS_B3F", "SEAFOAM_ISLANDS_B4F" },
    },
    {
      id = "cinnabar", label = "CINNABAR ISLAND",
      labelDe = "ZINNOBERINSEL", x = 39, y = 108,
      description = "The volcanic island at Kanto's south-western sea lane.",
      descriptionDe = "Die Vulkaninsel an Kantos südwestlicher Seeroute.",
      highlight = "Pokémon Lab, Fire Gym and an old mansion beside the town.",
      highlightDe = "Pokémon-Labor, Feuer-Arena und eine alte Villa am Stadtrand.",
      badge = "VOLCANOBADGE",
      maps = { "CINNABAR_ISLAND", "CINNABAR_GYM", "ROUTE_21",
               "POKEMON_MANSION_1F", "POKEMON_MANSION_2F",
               "POKEMON_MANSION_3F", "POKEMON_MANSION_B1F" },
    },
    {
      id = "indigo", label = "INDIGO PLATEAU",
      labelDe = "INDIGO PLATEAU", x = 4, y = 18,
      description = "A remote high plateau beyond Kanto's western mountain road.",
      descriptionDe = "Ein fernes Hochplateau hinter Kantos westlicher Bergstraße.",
      highlight = "A rugged cave road and the great plateau above the mountains.",
      highlightDe = "Ein rauer Höhlenweg und das große Plateau über den Bergen.",
      maps = { "ROUTE_22", "ROUTE_23", "INDIGO_PLATEAU",
               "VICTORY_ROAD_1F", "VICTORY_ROAD_2F", "VICTORY_ROAD_3F",
               "LORELEIS_ROOM", "BRUNOS_ROOM", "AGATHAS_ROOM",
               "LANCES_ROOM", "CHAMPIONS_ROOM" },
    },
  }

  local LOCATION_BY_MAP = {}
  for index, location in ipairs(LOCATIONS) do
    for _, mapId in ipairs(location.maps) do LOCATION_BY_MAP[mapId] = index end
  end

  local function currentMapId(game)
    local map = game and game.overworld and game.overworld.map
    return map and (map.id or map.def and map.def.id) or nil
  end

  local function currentLocationIndex(game)
    return LOCATION_BY_MAP[currentMapId(game)]
  end

  local function isVisited(game, location)
    local visited = game and game.save and game.save.visited or {}
    for _, mapId in ipairs(location.maps) do
      if visited[mapId] then return true end
    end
    return false
  end

  local function nearestInDirection(index, dx, dy)
    local current = LOCATIONS[index]
    local best, bestScore
    for candidate, location in ipairs(LOCATIONS) do
      if candidate ~= index then
        local ddx, ddy = location.x - current.x, location.y - current.y
        local forward = ddx * dx + ddy * dy
        if forward > 0 then
          local side = math.abs(ddx * dy) + math.abs(ddy * dx)
          local score = forward + side * 2.5
          if not best or score < bestScore then
            best, bestScore = candidate, score
          end
        end
      end
    end
    return best or index
  end

  -- Mirror the engine's Fly eligibility contract. The module never invents
  -- a landing point: map id, visit state, fly warp and outdoor/Plateau gate
  -- all come from the active game data, and the existing onFly callback still
  -- performs the actual move and its final validation.
  local function flyTargetsFor(game)
    local field = game and game.data and game.data.field or {}
    local visited = game and game.save and game.save.visited or {}
    local maps = game and game.data and game.data.maps or {}
    local flyWarps = field.flyWarps or {}
    local okMap, Map = pcall(require, "src.world.Map")
    local targets, seen, unsupported = {}, {}, false
    for _, mapId in ipairs(field.flyOrder or {}) do
      local def = maps[mapId]
      local outdoor = def and okMap and Map
        and (Map.isOutdoor(def) or def.tileset == "PLATEAU")
      if visited[mapId] and flyWarps[mapId] and outdoor and not seen[mapId] then
        seen[mapId] = true
        local locationIndex = LOCATION_BY_MAP[mapId]
        if locationIndex then
          targets[#targets + 1] = {
            mapId = mapId,
            locationIndex = locationIndex,
          }
        else
          -- A companion may add a real destination outside this Kanto image.
          -- Falling back to the builtin picker preserves that destination;
          -- silently hiding it would make the presentation alter gameplay.
          unsupported = true
        end
      end
    end
    return targets, unsupported
  end

  local function nearestFlyTarget(targets, currentIndex, dx, dy)
    local currentTarget = targets[currentIndex]
    local current = currentTarget and LOCATIONS[currentTarget.locationIndex]
    if not current then return currentIndex end
    local best, bestScore
    for candidateIndex, target in ipairs(targets) do
      if candidateIndex ~= currentIndex then
        local location = LOCATIONS[target.locationIndex]
        local ddx, ddy = location.x - current.x, location.y - current.y
        local forward = ddx * dx + ddy * dy
        if forward > 0 then
          local side = math.abs(ddx * dy) + math.abs(ddy * dx)
          local score = forward + side * 2.5
          if not best or score < bestScore then
            best, bestScore = candidateIndex, score
          end
        end
      end
    end
    return best or currentIndex
  end

  local function loadMapImage(path)
    path = path or IMAGE_PATH
    local assets = mod.assets
    if assets and type(assets.image) == "function" then
      local ok, image = pcall(assets.image, assets, path)
      if ok and image then
        if type(image.setFilter) == "function" then
          pcall(image.setFilter, image, "linear", "linear")
        end
        return image
      end
    end
    if love and love.graphics and type(love.graphics.newImage) == "function"
       and type(mod.path) == "string" then
      local ok, image = pcall(love.graphics.newImage,
                              mod.path .. "/" .. path)
      if ok then
        if image and type(image.setFilter) == "function" then
          pcall(image.setFilter, image, "linear", "linear")
        end
        return image
      end
    end
    return nil
  end

  -- Public Pokédex seam: consumers receive the exact packaged overview
  -- texture and marker coordinates in that texture's pixel space.  Encounter
  -- ownership stays with the game data; this module only maps encounter map
  -- ids onto its established Kanto locations.
  local function encounterHasSpecies(encounter, species)
    if type(encounter) ~= "table" then return false end
    for _, group in pairs(encounter) do
      if type(group) == "table" then
        for _, slot in ipairs(group.slots or {}) do
          if slot.species == species then return true end
        end
      end
    end
    return false
  end

  local function pokedexAreaFor(game, species)
    local markers, marked = {}, {}
    local encounters = game and game.data and game.data.encounters or {}
    for mapId, encounter in pairs(encounters) do
      local locationIndex = LOCATION_BY_MAP[mapId]
      if locationIndex and not marked[locationIndex]
          and encounterHasSpecies(encounter, species) then
        marked[locationIndex] = true
        local location = LOCATIONS[locationIndex]
        markers[#markers + 1] = {
          id = location.id,
          label = locationLabel(location, activeLanguage()),
          x = location.x * MAP_COORD_SCALE_X,
          y = location.y * MAP_COORD_SCALE_Y,
          locationIndex = locationIndex,
        }
      end
    end
    table.sort(markers, function(a, b)
      return a.locationIndex < b.locationIndex
    end)
    return {
      image = loadMapImage(IMAGE_PATH),
      width = MAP_WIDTH,
      height = MAP_HEIGHT,
      markers = markers,
      species = species,
      source = "vasc_kanto_fly_map_widescreen",
    }
  end

  local MapScreen = {}
  MapScreen.__index = MapScreen
  MapScreen.isOpaque = true

  function MapScreen:uiSize()
    return UI_WIDTH, UI_HEIGHT
  end

  -- The 576x324 surface is a real widescreen composition, not a high-
  -- resolution classic canvas. Ask the engine's final UI compositor for its
  -- aspect-preserving fractional fit so a 1024x768 window presents it as
  -- 1024x576 instead of leaving the integer-scale 576x324 island centred in
  -- black. SafeWideScreen delegates this marker only while this renderer is
  -- active; the native TownMap and compact 288x240 rescue stay unchanged.
  function MapScreen:wantsFillScale()
    return true
  end

  function MapScreen.new(game, opts)
    opts = opts or {}
    local language = activeLanguage()
    local current = currentLocationIndex(game)
    local targets = opts.flyTargets
    local flySelection = 1
    if targets then
      for index, target in ipairs(targets) do
        if target.locationIndex == current then flySelection = index break end
      end
    end
    return setmetatable({
      game = game,
      selected = targets and targets[flySelection].locationIndex or current or 1,
      current = current,
      image = loadMapImage(IMAGE_PATH),
      zoomImage = loadMapImage(ZOOM_IMAGE_PATH),
      language = language,
      pulse = 0,
      zoomed = false,
      viewZoom = 1,
      targetZoom = 1,
      mapX = 0,
      mapY = 0,
      targetMapX = 0,
      targetMapY = 0,
      autoZoomDelay = 0.75,
      -- Only the actual Fly picker performs the short ORAS-style opening
      -- zoom. The ordinary Town Map is a stable overview until A is pressed.
      autoZoomPending = targets ~= nil,
      fly = targets ~= nil,
      flyTargets = targets,
      flySelection = flySelection,
      onFly = opts.onFly,
      __vascKantoMap = true,
      __ascendantGlobalUiSkinSkip = true,
    }, MapScreen)
  end

  function MapScreen:sgbPalettes()
    local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
    if ok and PaletteFX and type(PaletteFX.trueColorZone) == "function" then
      return { PaletteFX.trueColorZone(0, 0,
        UI_WIDTH / 8 - 1, UI_HEIGHT / 8 - 1) }
    end
  end

  local function sound(game, id)
    local ok, Sound = pcall(require, "src.core.Sound")
    if ok and Sound and type(Sound.play) == "function" then
      pcall(Sound.play, game.data, id)
    end
  end

  function MapScreen:move(dx, dy)
    if self.fly then
      local nextIndex = nearestFlyTarget(
        self.flyTargets, self.flySelection, dx, dy)
      if nextIndex ~= self.flySelection then
        self.flySelection = nextIndex
        self.selected = self.flyTargets[nextIndex].locationIndex
        -- Keep overview navigation in overview. In detail view this refreshes
        -- the camera target so it follows the newly selected destination.
        if self.zoomed then self:setZoom(true) end
        sound(self.game, "Tink")
      end
      return
    end
    local nextIndex = nearestInDirection(self.selected, dx, dy)
    if nextIndex ~= self.selected then
      self.selected = nextIndex
      if self.zoomed then self:setZoom(true) end
      sound(self.game, "Tink")
    end
  end

  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end

  function MapScreen:setZoom(enabled)
    self.zoomed = enabled == true
    self.targetZoom = self.zoomed and 2 or 1
    self.autoZoomPending = false
    if self.zoomed then
      local location = LOCATIONS[self.selected]
      local markerX = location.x * MAP_COORD_SCALE_X
      local markerY = location.y * MAP_COORD_SCALE_Y
      self.targetMapX = clamp(MAP_VIEW_WIDTH / 2 - markerX * 2,
                              MAP_VIEW_WIDTH - MAP_WIDTH * 2, 0)
      self.targetMapY = clamp(UI_HEIGHT / 2 - markerY * 2,
                              UI_HEIGHT - MAP_HEIGHT * 2, 0)
    else
      self.targetMapX, self.targetMapY = 0, 0
    end
  end

  local function approach(current, target, amount)
    if math.abs(target - current) < 0.001 then return target end
    return current + (target - current) * amount
  end

  -- The engine text box can display two lines at once. Automatic wrapping of
  -- a longer paragraph creates a scrolling multi-line page, which is too easy
  -- to skip. Build explicit two-line pages instead, conservatively below the
  -- 18-cell engine limit so this remains stable with both language fonts.
  local function wrapInfoLines(value)
    local lines, line = {}, ""
    for word in tostring(value or ""):gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + #word + 1 <= 16 then
        line = line .. " " .. word
      else
        lines[#lines + 1] = line
        line = word
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if #lines == 0 then lines[1] = "..." end
    return lines
  end

  local function appendTwoLinePages(pages, lines, firstIndex)
    local index = firstIndex or 1
    while index <= #lines do
      local page = lines[index]
      if lines[index + 1] then page = page .. "\n" .. lines[index + 1] end
      pages[#pages + 1] = page
      index = index + 2
    end
  end

  local function ownsBadge(game, badge)
    local inventory = game and game.save and game.save.inventory or {}
    return badge and inventory[badge] and true or false
  end

  local function hasFlag(game, flag)
    local flags = game and game.save and game.save.flags or {}
    return flag and flags[flag] and true or false
  end

  local function locationHighlight(selected, language, game)
    local highlight = language == "de" and selected.highlightDe
      or selected.highlight
    if not selected.badge then return highlight end

    local gymState
    if ownsBadge(game, selected.badge) then
      gymState = language == "de" and "Die Arena ist geschafft."
        or "The Gym challenge is complete."
    elseif selected.gymOpenFlag and not hasFlag(game, selected.gymOpenFlag) then
      gymState = language == "de" and "Die Arena ist derzeit geschlossen."
        or "The Gym is currently closed."
    else
      gymState = language == "de" and "Die Arena ist noch offen."
        or "The Gym challenge is still open."
    end
    return highlight .. " " .. gymState
  end

  local function formatLocationInfo(selected, language, game)
    local visited = isVisited(game, selected)
    local here = LOCATIONS[currentLocationIndex(game)] == selected
    local status
    if here then
      status = language == "de" and "DU BIST HIER" or "YOU ARE HERE"
    elseif visited then
      status = language == "de" and "ENTDECKT" or "DISCOVERED"
    else
      status = language == "de" and "UNERKUNDET" or "UNEXPLORED"
    end
    local pages = { locationLabel(selected, language) .. "\n" .. status }

    appendTwoLinePages(pages,
      wrapInfoLines(locationDescription(selected, language)))

    if visited or here then
      local highlightTitle = language == "de" and "ORTSINFO" or "LOCAL INFO"
      local highlightLines = wrapInfoLines(
        locationHighlight(selected, language, game))
      pages[#pages + 1] = highlightTitle .. "\n" .. highlightLines[1]
      appendTwoLinePages(pages, highlightLines, 2)
    else
      pages[#pages + 1] = language == "de"
        and "MEHR INFOS\nNACH DEM BESUCH" or "MORE INFO\nAFTER YOUR VISIT"
    end
    return table.concat(pages, "\f")
  end

  function MapScreen:showSelectedInfo()
    local TextBox = require("src.render.TextBox")
    local selected = LOCATIONS[self.selected]
    local text = formatLocationInfo(selected, self.language, self.game)
    local box = TextBox.new(self.game, text)
    -- A stock TextBox has no uiSize() and therefore switches the renderer
    -- back to 160x144 while it is on top. Keep the exact Widescreen canvas and
    -- place the two-line pages entirely inside the eastern ocean rail. Even
    -- while reading city information, no part of Kanto is covered.
    box.uiSize = function() return UI_WIDTH, UI_HEIGHT end
    box.boxTx, box.boxTy, box.boxTw, box.boxTh = 54, 11, 18, 8
    box.textX = (box.boxTx + 1) * 8
    box.line1Y = (box.boxTy + 2) * 8
    box.line2Y = (box.boxTy + 4) * 8
    box.__ascendantGlobalUiSkinSkip = true
    self.game.stack:push(box)
  end

  function MapScreen:update(dt)
    local elapsed = tonumber(dt) or 0
    -- Input must reflect the state that was visible when the button was
    -- pressed. If the automatic timer expires in this exact frame, that must
    -- never turn a user's first A into an accidental immediate flight.
    local inputZoomed = self.zoomed
    self.pulse = (self.pulse + elapsed) % 1
    if self.autoZoomPending then
      self.autoZoomDelay = self.autoZoomDelay - elapsed
      if self.autoZoomDelay <= 0 then self:setZoom(true) end
    end
    local ease = clamp(elapsed * 9, 0, 1)
    self.viewZoom = approach(self.viewZoom, self.targetZoom, ease)
    self.mapX = approach(self.mapX, self.targetMapX, ease)
    self.mapY = approach(self.mapY, self.targetMapY, ease)
    local input = self.game and self.game.input
    if not (input and type(input.wasPressed) == "function") then return end
    if input:wasPressed("b") then
      sound(self.game, "Press_AB")
      if inputZoomed then
        self:setZoom(false)
      else
        self.game.stack:pop()
      end
    elseif input:wasPressed("up") then self:move(0, -1)
    elseif input:wasPressed("down") then self:move(0, 1)
    elseif input:wasPressed("left") then self:move(-1, 0)
    elseif input:wasPressed("right") then self:move(1, 0)
    elseif input:wasPressed("select") then
      sound(self.game, "Press_AB")
      -- Preserve the view the player actually pressed SELECT on. This also
      -- cancels an opening auto-zoom that expired in the same input frame.
      if not inputZoomed then self:setZoom(false) end
      self:showSelectedInfo()
    elseif input:wasPressed("a") then
      sound(self.game, "Press_AB")
      if not inputZoomed then
        self:setZoom(true)
        return
      end
      if self.fly then
        local target = self.flyTargets[self.flySelection]
        self.game.stack:pop()
        if target and type(self.onFly) == "function" then
          self.onFly(target.mapId)
        end
        return
      end
      self:showSelectedInfo()
    end
  end

  local function setColor(g, r, green, b, a)
    g.setColor(r, green, b, a or 1)
  end

  local function fallbackMap(g)
    setColor(g, 0.08, 0.42, 0.65)
    g.rectangle("fill", 0, 0, MAP_WIDTH, MAP_HEIGHT)
    setColor(g, 0.32, 0.66, 0.31)
    g.polygon("fill", 29, 56, 209, 45, 266, 92, 250, 173,
              196, 214, 86, 203, 29, 157)
    setColor(g, 0.73, 0.65, 0.42)
    g.line(54, 77, 131, 70, 148, 103, 182, 144, 119, 164, 86, 158)
  end

  -- A clean 5x7 alphabet replaces the former 3x5 draft. Diagonal letters
  -- (especially N, M, W and R) now keep their actual silhouettes instead of
  -- collapsing into nearly solid blocks after the window upscale.
  local CLEAR_GLYPHS = {
    A={"01110","10001","10001","11111","10001","10001","10001"},
    B={"11110","10001","10001","11110","10001","10001","11110"},
    C={"01111","10000","10000","10000","10000","10000","01111"},
    D={"11110","10001","10001","10001","10001","10001","11110"},
    E={"11111","10000","10000","11110","10000","10000","11111"},
    F={"11111","10000","10000","11110","10000","10000","10000"},
    G={"01111","10000","10000","10111","10001","10001","01111"},
    H={"10001","10001","10001","11111","10001","10001","10001"},
    I={"11111","00100","00100","00100","00100","00100","11111"},
    J={"00111","00010","00010","00010","10010","10010","01100"},
    K={"10001","10010","10100","11000","10100","10010","10001"},
    L={"10000","10000","10000","10000","10000","10000","11111"},
    M={"10001","11011","10101","10101","10001","10001","10001"},
    N={"10001","11001","11001","10101","10011","10011","10001"},
    O={"01110","10001","10001","10001","10001","10001","01110"},
    P={"11110","10001","10001","11110","10000","10000","10000"},
    Q={"01110","10001","10001","10001","10101","10010","01101"},
    R={"11110","10001","10001","11110","10100","10010","10001"},
    S={"01111","10000","10000","01110","00001","00001","11110"},
    T={"11111","00100","00100","00100","00100","00100","00100"},
    U={"10001","10001","10001","10001","10001","10001","01110"},
    V={"10001","10001","10001","10001","10001","01010","00100"},
    W={"10001","10001","10001","10101","10101","11011","10001"},
    X={"10001","10001","01010","00100","01010","10001","10001"},
    Y={"10001","10001","01010","00100","00100","00100","00100"},
    Z={"11111","00001","00010","00100","01000","10000","11111"},
    ["."]={"00000","00000","00000","00000","00000","00110","00110"},
    ["-"]={"00000","00000","00000","11111","00000","00000","00000"},
    ["?"]={"01110","10001","00001","00010","00100","00000","00100"},
    [" "]={"00000","00000","00000","00000","00000","00000","00000"},
  }

  local function clearTextWidth(text, scale)
    scale = scale or 2
    return math.max(0, #tostring(text or "") * 6 * scale - scale)
  end

  local function centeredClearX(text, left, width, scale)
    return left + math.floor((width - clearTextWidth(text, scale)) / 2)
  end

  local function fitClear(value, width, scale)
    value = tostring(value or ""):upper()
    while #value > 1 and clearTextWidth(value, scale) > width do
      value = value:sub(1, -2)
    end
    return value
  end

  local function drawClearText(g, text, x, y, color, scale)
    text, scale = tostring(text or ""):upper(), scale or 2
    setColor(g, color[1], color[2], color[3], color[4] or 1)
    local pen = x
    for index = 1, #text do
      local glyph = CLEAR_GLYPHS[text:sub(index, index)] or CLEAR_GLYPHS["?"]
      for row = 1, 7 do
        for column = 1, 5 do
          if glyph[row]:sub(column, column) == "1" then
            g.rectangle("fill", pen + (column - 1) * scale,
                        y + (row - 1) * scale, scale, scale)
          end
        end
      end
      pen = pen + 6 * scale
    end
  end

  local function drawClearTextShadow(g, text, x, y, color, scale)
    local shadow = {0.01, 0.025, 0.035, 0.92}
    drawClearText(g, text, x - 1, y, shadow, scale)
    drawClearText(g, text, x + 1, y, shadow, scale)
    drawClearText(g, text, x, y - 1, shadow, scale)
    drawClearText(g, text, x, y + 1, shadow, scale)
    drawClearText(g, text, x, y, color, scale)
  end

  -- Borderless Crystal Glass for the always-visible map chrome. It keeps the
  -- artwork readable beneath the controls.
  local function crystalPanel(g, x, y, width, height, pale)
    if pale then
      setColor(g, 0.88, 0.96, 1, 0.43)
    else
      setColor(g, 0.01, 0.04, 0.07, 0.25)
    end
    g.rectangle("fill", x, y, width, height, 7, 7)
  end

  -- Prefer VASC's published ORAS-glass controller so the Fly picker follows
  -- the installed skin exactly. The local painter is an API/back-end fallback
  -- with the same surface, cyan edge and one-pixel top reflection.
  local function glassPanel(g, x, y, width, height, dark)
    local vascHandle = findMod("VOXEL_ASCENDANT")
    local skin = vascHandle and vascHandle.exports
      and vascHandle.exports.orasUiSkin
    local controller = type(skin) == "table" and skin.controller or nil
    if controller and type(controller.drawOrasBox) == "function"
        and x % 8 == 0 and y % 8 == 0
        and width % 8 == 0 and height % 8 == 0 then
      local ok, drawn = pcall(controller.drawOrasBox, nil,
        x / 8, y / 8, width / 8, height / 8, dark == true)
      if ok and drawn then return true end
    end

    if type(g.setLineWidth) == "function" then g.setLineWidth(1) end
    if dark then
      setColor(g, 0.01, 0.05, 0.08, 0.78)
      g.rectangle("fill", x, y, width, height, 4, 4)
      setColor(g, 0, 0, 0, 0.24)
      g.rectangle("fill", x + 3, y + math.max(0, height - 3),
                  math.max(0, width - 6), 1, 2, 2)
    else
      setColor(g, 0.005, 0.02, 0.03, 0.94)
      g.rectangle("fill", x, y, width, height, 4, 4)
      setColor(g, 0.94, 0.985, 1, 0.90)
      g.rectangle("fill", x + 1, y + 1,
                  math.max(0, width - 2), math.max(0, height - 2), 3, 3)
    end
    setColor(g, 0.04, 0.80, 0.97, 0.98)
    g.rectangle("line", x + 0.5, y + 0.5,
                math.max(0, width - 1), math.max(0, height - 1), 4, 4)
    setColor(g, 0.53, 0.94, 1, 0.46)
    g.rectangle("line", x + 1.5, y + 1.5,
                math.max(0, width - 3), math.max(0, height - 3), 3, 3)
    setColor(g, 0.66, 0.97, 1, 0.62)
    g.rectangle("fill", x + 7, y + 3, math.max(0, width - 14), 1)
    return true
  end

  local function choicePanel(g, x, y, width, height, selected)
    glassPanel(g, x, y, width, height, nil)
    if selected then
      setColor(g, 0.04, 0.80, 0.97, 1)
      g.rectangle("line", x - 0.5, y - 0.5, width + 1, height + 1, 4, 4)
      g.polygon("fill", x - 6, y + 4, x - 2, y + 8, x - 6, y + 12)
    end
  end

  local function drawMapTexture(g, image, mapX, mapY, zoom, alpha)
    if not image then return false end
    local width, height = image:getDimensions()
    setColor(g, 1, 1, 1, alpha or 1)
    g.draw(image, mapX, mapY, 0,
      (MAP_WIDTH / width) * zoom, (MAP_HEIGHT / height) * zoom)
    return true
  end

  local function drawLocationPin(g, x, y, color, selected)
    local size = selected and 8 or 5
    local centerY = y - size
    setColor(g, 0.015, 0.06, 0.09, 0.92)
    g.polygon("fill", x - size - 2, centerY,
              x + size + 2, centerY, x, y + 3)
    g.circle("fill", x, centerY, size + 2)
    setColor(g, color[1], color[2], color[3], color[4] or 1)
    g.polygon("fill", x - size, centerY, x + size, centerY, x, y + 1)
    g.circle("fill", x, centerY, size)
    setColor(g, 0.94, 0.99, 1, selected and 1 or 0.90)
    g.circle("fill", x, centerY, selected and 3 or 2)
  end

  local function drawPlayerPin(g, x, y, selected)
    local centerY = y - 9
    setColor(g, 0.015, 0.06, 0.09, 0.96)
    g.polygon("fill", x - 11, centerY, x + 11, centerY, x, y + 4)
    g.circle("fill", x, centerY, 12)
    setColor(g, 0.18, 0.88, 1, 1)
    g.polygon("fill", x - 9, centerY, x + 9, centerY, x, y + 1)
    g.circle("fill", x, centerY, 9.5)
    setColor(g, 0.96, 0.995, 1, 1)
    g.circle("fill", x, centerY, 6.5)
    -- A proper head-and-shoulders silhouette distinguishes the player from
    -- every destination pin even when colors are viewed in monochrome.
    setColor(g, 0.02, 0.12, 0.18, 1)
    g.circle("fill", x, centerY - 2.2, 2.1)
    g.rectangle("fill", x - 3.5, centerY + 0.5, 7, 4, 2, 2)
    if selected then
      if type(g.setLineWidth) == "function" then g.setLineWidth(2) end
      setColor(g, 0.97, 0.25, 0.29, 1)
      g.circle("line", x, centerY, 13.5)
      if type(g.setLineWidth) == "function" then g.setLineWidth(1) end
    end
  end

  function MapScreen:draw()
    local g = love.graphics
    setColor(g, 0.05, 0.16, 0.29)
    g.rectangle("fill", 0, 0, UI_WIDTH, UI_HEIGHT)

    if self.image then
      drawMapTexture(g, self.image, self.mapX, self.mapY, self.viewZoom, 1)
      -- Blend in the dedicated 1152x648 detail texture during the camera
      -- move. At final 2x view one texture pixel maps to one screen pixel.
      local detailAlpha = clamp((self.viewZoom - 1) * 2, 0, 1)
      if self.zoomImage and detailAlpha > 0 then
        drawMapTexture(g, self.zoomImage, self.mapX, self.mapY,
                       self.viewZoom, detailAlpha)
      end
    else
      fallbackMap(g)
    end

    local available = {}
    for _, target in ipairs(self.flyTargets or {}) do
      available[target.locationIndex] = true
    end

    local playerX, playerY
    for index, location in ipairs(LOCATIONS) do
      local x = self.mapX + location.x * MAP_COORD_SCALE_X * self.viewZoom
      local y = self.mapY + location.y * MAP_COORD_SCALE_Y * self.viewZoom
      if x >= -16 and x <= MAP_VIEW_WIDTH + 16
          and y >= -24 and y <= UI_HEIGHT + 16 then
      local selectedHere = index == self.selected
      local bob = selectedHere and (self.pulse < 0.5 and 0 or 2) or 0
      if index == self.current then
        playerX, playerY = x, y - 9
        drawPlayerPin(g, x, y - bob, selectedHere)
      else
        local color
        if selectedHere then
          color = {0.97, 0.25, 0.29, 1}
        elseif self.fly and available[index] then
          color = {0.12, 0.88, 0.28, 1}
        elseif not self.fly and isVisited(self.game, location) then
          color = {0.23, 0.82, 0.48, 1}
        else
          color = {0.31, 0.36, 0.39, 0.88}
        end
        drawLocationPin(g, x, y - bob, color, selectedHere)
      end
      end
    end

    if playerX and playerY then
      local playerLabel = self.language == "de" and "DU" or "YOU"
      local labelWidth = clearTextWidth(playerLabel, 1)
      local labelX = playerX + 12
      if labelX + labelWidth > MAP_VIEW_WIDTH - 4 then
        labelX = playerX - labelWidth - 12
      end
      drawClearTextShadow(g, playerLabel, labelX, playerY - 4,
        {0.35, 0.94, 1}, 1)
      self.__lastPlayerLabel = playerLabel
    else
      self.__lastPlayerLabel = nil
    end

    local selected = LOCATIONS[self.selected]

    -- The gained eastern ocean carries all chrome. Kanto itself stays clear.
    local sideX, sideWidth = 432, 136
    local innerX, innerWidth = 440, 120
    crystalPanel(g, sideX, 8, sideWidth, 308, false)
    local destinationWord
    if self.fly then
      destinationWord = self.language == "de" and "FLUGZIEL" or "FLY DEST."
    else
      destinationWord = self.language == "de" and "KANTO-KARTE" or "KANTO MAP"
    end
    drawClearTextShadow(g, destinationWord,
      centeredClearX(destinationWord, innerX, innerWidth, 1), 16,
      {0.42, 0.94, 1}, 1)
    local selectedName = tostring(locationLabel(selected, self.language)):upper()
    local titleA, titleB = selectedName, nil
    if clearTextWidth(selectedName, 2) > innerWidth then
      titleA, titleB = selectedName:match("^(.+)%s+(%S+)$")
      if not titleA then titleA = selectedName end
    end
    local titleScale = (clearTextWidth(titleA, 2) <= innerWidth
      and (not titleB or clearTextWidth(titleB, 2) <= innerWidth)) and 2 or 1
    local titleY = titleB and 42 or 50
    drawClearTextShadow(g, titleA,
      centeredClearX(titleA, innerX, innerWidth, titleScale), titleY,
      {1, 1, 1}, titleScale)
    if titleB then
      drawClearTextShadow(g, titleB,
        centeredClearX(titleB, innerX, innerWidth, titleScale),
        titleY + titleScale * 9, {1, 1, 1}, titleScale)
    end
    self.__lastLocationLabel = selectedName
    self.__lastDestinationWord = destinationWord

    crystalPanel(g, innerX, 218, innerWidth, 30, true)
    local action
    if not self.zoomed then
      action = "ZOOM"
    elseif self.language == "de" then
      action = self.fly and "FLUG" or "INFO"
    else
      action = self.fly and "FLY" or "INFO"
    end
    local actionText = "A " .. action
    drawClearTextShadow(g, actionText,
      centeredClearX(actionText, innerX, innerWidth, 2), 226,
      {0.04, 0.10, 0.12}, 2)
    self.__lastActionLabel = actionText
    local selectWord = "SELECT"
    local mapWord = "INFO"
    drawClearTextShadow(g, selectWord,
      centeredClearX(selectWord, innerX, innerWidth, 2), 256,
      {1, 1, 1}, 2)
    drawClearTextShadow(g, mapWord,
      centeredClearX(mapWord, innerX, innerWidth, 2), 273,
      {1, 1, 1}, 2)
    self.__lastZoomLabel = mapWord
    crystalPanel(g, innerX, 290, innerWidth, 26, true)
    local backText = self.language == "de" and "B ZURUECK" or "B BACK"
    drawClearTextShadow(g, backText,
      centeredClearX(backText, innerX, innerWidth, 2),
      296, {0.04, 0.10, 0.12}, 2)

    setColor(g, 1, 1, 1)
  end

  local function nativeMap(game, opts)
    return require("src.ui.TownMap").new(game, opts)
  end

  local function compactMap(game, opts, nativeOpts)
    local factory = mod.kantoFlyMapFallbackFactory
    if type(factory) == "function" then
      local ok, screen = pcall(factory, game, opts)
      if ok and type(screen) == "table" then
        screen.__vascKantoMapFallback = "compact-288x240"
        return screen, "compact"
      end
    end
    return nativeMap(game, nativeOpts), "native"
  end

  -- Keep the stack object stable if the wide renderer fails after creation.
  -- All gameplay input remains owned by the active screen; only presentation
  -- swaps first to the retired compact renderer and finally to the engine.
  local SafeWideScreen = {}
  SafeWideScreen.__index = function(self, key)
    local method = SafeWideScreen[key]
    if method ~= nil then return method end
    local active = rawget(self, "_active")
    if active ~= nil then return active[key] end
    return nil
  end
  SafeWideScreen.__newindex = function(self, key, value)
    if key == "_active" or key == "_stage"
        or key == "_semanticOpts" or key == "_nativeOpts"
        or key == "_game" then
      rawset(self, key, value)
      return
    end
    local active = rawget(self, "_active")
    if active then active[key] = value else rawset(self, key, value) end
  end

  function SafeWideScreen:_activateFallback()
    local screen, stage = compactMap(
      self._game,
      self._semanticOpts,
      self._nativeOpts)
    rawset(self, "_active", screen)
    rawset(self, "_stage", stage)
    return screen
  end

  function SafeWideScreen:_activateNative()
    local ok, screen = pcall(nativeMap, self._game, self._nativeOpts)
    if not ok or type(screen) ~= "table" then return nil end
    rawset(self, "_active", screen)
    rawset(self, "_stage", "native")
    return screen
  end

  function SafeWideScreen:_call(name, ...)
    -- One invocation may need both rescue rungs. In particular, a missing
    -- Widescreen asset constructs the compact screen immediately; if that
    -- renderer later fails, the same stack object must still reach TownMap.
    for _ = 1, 3 do
      local active = self._active
      local fn = active and active[name]
      if type(fn) ~= "function" then return nil end
      local ok, a, b, c = pcall(fn, active, ...)
      if ok then return a, b, c end
      if self._stage == "wide" then
        if not self:_activateFallback() then return nil end
      elseif self._stage == "compact" then
        if not self:_activateNative() then return nil end
      else
        return nil
      end
    end
    return nil
  end

  for _, method in ipairs({
    "uiSize", "wantsFillScale", "sgbPalettes", "move", "setZoom",
    "showSelectedInfo", "update", "draw",
  }) do
    SafeWideScreen[method] = function(self, ...)
      return self:_call(method, ...)
    end
  end

  local function safeWideMap(game, opts, nativeOpts)
    local ok, screen = pcall(MapScreen.new, game, opts)
    local stage = "wide"
    if not ok or type(screen) ~= "table" or not screen.image
        or not screen.zoomImage then
      screen, stage = compactMap(game, opts, nativeOpts)
    end
    return setmetatable({
      _active = screen,
      _stage = stage,
      _game = game,
      _semanticOpts = opts,
      _nativeOpts = nativeOpts,
    }, SafeWideScreen)
  end

  local function insertBeforeSave(items, item)
    if mod.ui and type(mod.ui.insertBefore) == "function" then
      return mod.ui.insertBefore(items, "SAVE", item)
    end
    local index = #items + 1
    for i, existing in ipairs(items) do
      if existing and (existing.id == "SAVE" or existing.label == "SAVE") then
        index = i
        break
      end
    end
    table.insert(items, index, item)
    return items
  end

  local vasc = type(mod.find) == "function" and mod.find("VOXEL_ASCENDANT")
  local exports = vasc and vasc.exports
  if type(exports) ~= "table"
     or type(exports.capabilities) ~= "table"
     or exports.capabilities.voxelWorld ~= true then
    if mod.log and type(mod.log.error) == "function" then
      mod.log:error("VASC Kanto Fly Map needs an active Voxel Ascendant runtime")
    end
    mod.exports.active = false
    return
  end

  local screens = mod.content and mod.content.screens
  if not (screens and type(screens.register) == "function") then
    mod.exports.active = false
    return
  end
  -- Replace ordinary Town Map viewing and Fly selection with the same Kanto
  -- artwork. The regular engine Pokédex route keeps its native fallback;
  -- widescreen Dex companions can use the provider exported below.
  screens:register("TownMap", {
    new = function(game, opts)
      opts = type(opts) == "table" and opts or {}
      if requestedMode() ~= "widescreen" or opts.nestSpecies then
        return nativeMap(game, opts)
      end
      if opts.fly == true then
        local targets, unsupported = flyTargetsFor(game)
        if unsupported or #targets == 0 then
          return nativeMap(game, opts)
        end
        return safeWideMap(game, {
          flyTargets = targets,
          onFly = opts.onFly,
        }, opts)
      end
      return safeWideMap(game, {}, opts)
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local menuLabel = activeLanguage() == "de" and "KANTO-KARTE"
      or "KANTO MAP"
    return insertBeforeSave(out, {
      id = "vasc_kanto_fly_map_widescreen",
      label = menuLabel,
      ascendantMenu = true,
      ascendantLabel = menuLabel,
      ascendantOrder = 4,
      onSelect = function() mod.ui.push(game, "TownMap") end,
    })
  end, 112)

  mod.exports.apiVersion = 1
  mod.exports.active = true
  mod.exports.supportedEditions = { "red", "blue", "yellow" }
  -- TownMap is the only public entry so the CARTRIDGE/WIDESCREEN owner choice
  -- cannot be bypassed by pushing a renderer-specific screen id.
  mod.exports.screenId = "TownMap"
  mod.exports.rendererScreenId = SCREEN_ID
  mod.exports.rendererInternalOnly = true
  mod.exports.fontGrid = "5x7"
  mod.exports.playerMarker = "person-label"
  mod.exports.controls = "two-step-a-b-select-info"
  mod.exports.townMapReplacement = true
  mod.exports.layout = "widescreen-576x324"
  mod.exports.markerStyle = "map-pins"
  mod.exports.publicModes = { "cartridge", "widescreen" }
  mod.exports.fallbackMode = "internal-compact-288x240-only"
  mod.exports.locations = LOCATIONS
  mod.exports.locationForMap = function(mapId)
    return LOCATIONS[LOCATION_BY_MAP[mapId]]
  end
  mod.exports.nearestInDirection = nearestInDirection
  mod.exports.flyTargetsFor = flyTargetsFor
  mod.exports.formatLocationInfo = function(location, language, game)
    return formatLocationInfo(location, language == "de" and "de" or "en",
      game or {})
  end
  mod.exports.pokedexAreaProvider = {
    apiVersion = 1,
    resolve = function(game, species)
      if requestedMode() ~= "widescreen" then return nil end
      local result = pokedexAreaFor(game, species)
      if not result.image then return nil end
      return result
    end,
  }
end
