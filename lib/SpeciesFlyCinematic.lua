-- VASC integrated Species Fly Cinematic.
--
-- Internal Gen-1 presentation module for Red, Blue and Yellow. VASC remains
-- the owner of the voxel renderer; this module composes the owned `voxel` pass and
-- replaces only the generic FLY bird while that pipeline is active.

local V = ...

local KantoAscendantCompat = V.require("KantoAscendantCompat")

local SpeciesFlyCinematic = {
  VERSION = "0.4.3",
}

local installed = false

function SpeciesFlyCinematic.install()
  local mod = V.mod
  if installed then
    local exports = mod.exports and mod.exports.speciesCinematics
    return true, exports and exports.fly
  end
  local GameVersion = require("src.core.GameVersion")
  local edition = GameVersion.get()
  if edition ~= "red" and edition ~= "blue" and edition ~= "yellow" then
    mod.log:info("VASC Species Fly Cinematic: nur für Rot, Blau und Gelb")
    return false, "unsupported-edition"
  end

  local Game = require("src.core.Game")
  local OverworldState = require("src.world.OverworldController")
  local Screens = require("src.ui.Screens")
  local Stats = require("src.pokemon.Stats")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")

  local PIPELINE_ID = "voxel"
  local SHEET_DIR = "assets/species_cinematics/directional"
  local SHEET_COLUMNS = 4
  local SHEET_ROWS = 4
  local CELL = 32
  local NATIONAL_DEX_MAX = 386
  local GOROCHU_DEX = 1026
  local DEPARTURE_FRAMES = 96
  local LANDING_FRAMES = 96
  local FIELD_KIT_LANDING_FRAMES = 60
  local FIELD_KIT_JETPACK = {
    species = "FIELD_KIT_JETPACK",
    fieldKitJetpack = true,
  }
  local pendingByWorld = setmetatable({}, { __mode = "k" })
  local fieldKitByWorld = setmetatable({}, { __mode = "k" })
  local waitingForNativeByWorld = setmetatable({}, { __mode = "k" })
  local activeByWorld = setmetatable({}, { __mode = "k" })
  local imageCache = {}
  local quadCache = setmetatable({}, { __mode = "k" })
  local lastImageError = {}
  local voxelLevel = 0

  -- Mod logs are diagnostic, never part of the flight state machine. Keep a
  -- third-party logger implementation from turning a recoverable asset error
  -- into a broken render pipeline of its own.
  local function safeLog(level, fmt, ...)
    local logger = mod and mod.log
    local writer = logger and logger[level]
    if type(writer) == "function" then pcall(writer, logger, fmt, ...) end
  end

  local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
  end

  local function smooth(v)
    v = clamp(v, 0, 1)
    return v * v * (3 - 2 * v)
  end

  local function lerp(a, b, t)
    return a + (b - a) * t
  end

  local function pokemonDef(mon)
    local species = type(mon) == "table" and mon.species or nil
    return species and Game.data and Game.data.pokemon
      and Game.data.pokemon[species] or nil
  end

  local function speciesDex(mon)
    if type(mon) ~= "table" then return nil end
    local def = pokemonDef(mon)
    if type(def) ~= "table" then return nil end
    -- Kanto Ascendant uses private runtime slots for a subset of extended
    -- species. For example an internal #261 can actually be National-Dex
    -- #424. Once a definition exposes a source/national identity it is the
    -- only safe artwork key; falling through to def.dex would draw the wrong
    -- Pokemon. Hoenn's private #32xx slots resolve the same way to #252-386.
    local artworkDex
    if def.sourceDex ~= nil then
      artworkDex = def.sourceDex
    elseif def.nationalDex ~= nil then
      artworkDex = def.nationalDex
    elseif def.dexNumber ~= nil then
      artworkDex = def.dexNumber
    else
      -- `id` and the fields stored on a party instance are runtime identities,
      -- not guaranteed National-Dex numbers. Definitions are authoritative;
      -- an unknown definition therefore declines the cinematic completely.
      artworkDex = def.dex ~= nil and def.dex or def.number
    end
    local dex = tonumber(artworkDex)
    if not dex or dex ~= math.floor(dex) then return nil end
    if mon.species == "GOROCHU" and dex == GOROCHU_DEX then return dex end
    if dex < 1 or dex > NATIONAL_DEX_MAX then return nil end
    return dex
  end

  local function hasType(def, wanted)
    for _, id in ipairs(type(def) == "table" and def.types or {}) do
      if id == wanted then return true end
    end
    return false
  end

  local function knowsMove(mon, wanted)
    for _, move in ipairs(type(mon) == "table" and mon.moves or {}) do
      local id = type(move) == "table" and move.id or move
      if id == wanted then return true end
    end
    return false
  end

  local WINGED = {
    [6] = true, [12] = true, [15] = true,
    [16] = true, [17] = true, [18] = true,
    [21] = true, [22] = true, [41] = true,
    [42] = true, [49] = true, [83] = true,
    [123] = true, [142] = true, [144] = true,
    [145] = true, [146] = true, [149] = true,
  }

  -- The directional sheets already encode the visible size difference
  -- between species inside each cell: Pidgey occupies far fewer pixels than
  -- Charizard, while seven giants intentionally use cells above 32px.
  -- Keeping each texture at its authored scale avoids nearest-neighbour
  -- shimmer. Height only decides whether the trainer rides or is carried.
  local function flightProfile(mon)
    local def = pokemonDef(mon) or {}
    local entry = def.dexEntry or {}
    local metres = tonumber(entry.heightM)
    if not metres then
      local inches = (tonumber(entry.heightFt) or 0) * 12
        + (tonumber(entry.heightIn) or 0)
      if inches > 0 then metres = inches * 0.0254 end
    end
    metres = metres or 1

    local dex = speciesDex(mon)
    local mode = metres >= 1.4 and "mount" or "carry"
    local overrides = {
      [6] = { mode = "mount", seatX = -2, seatLift = 18,
              shadowRadius = 14 }, -- Charizard
      [18] = { mode = "mount", seatX = -1, seatLift = 16,
               shadowRadius = 13 },
      [84] = { mode = "carry" }, [85] = { mode = "carry" },
      [130] = { mode = "mount", seatX = -2, seatLift = 17,
                shadowRadius = 15 },
      [142] = { mode = "mount", seatX = -1, seatLift = 17,
                shadowRadius = 15 },
      [149] = { mode = "mount", seatX = -1, seatLift = 18,
                shadowRadius = 15 },
      [249] = { mode = "mount", seatX = -2, seatLift = 27,
                shadowRadius = 20 }, -- Lugia
      [250] = { mode = "mount", seatX = -2, seatLift = 27,
                shadowRadius = 20 }, -- Ho-Oh
      [330] = { mode = "mount", seatX = -1, seatLift = 19,
                shadowRadius = 15 }, -- Flygon
      [334] = { mode = "mount", seatX = -1, seatLift = 18,
                shadowRadius = 14 }, -- Altaria
      [357] = { mode = "mount", seatX = -1, seatLift = 20,
                shadowRadius = 16 }, -- Tropius
      [373] = { mode = "mount", seatX = -1, seatLift = 20,
                shadowRadius = 16 }, -- Salamence
      [380] = { mode = "mount", seatX = -1, seatLift = 18,
                shadowRadius = 14 }, -- Latias
      [381] = { mode = "mount", seatX = -1, seatLift = 18,
                shadowRadius = 14 }, -- Latios
      [384] = { mode = "mount", seatX = -2, seatLift = 28,
                shadowRadius = 20 }, -- Rayquaza
    }
    local tuned = overrides[dex] or {}
    local resolvedMode = tuned.mode or mode
    local winged = WINGED[dex] == true or hasType(def, "FLYING")
    local eventId = type(mon) == "table"
      and type(mon.eventDistribution) == "table"
      and mon.eventDistribution.id or nil
    local departureMode
    local balloonFamily = dex == 25 or dex == 26
      or (dex == GOROCHU_DEX and mon.species == "GOROCHU")
    if balloonFamily and (knowsMove(mon, "FLY")
        or (dex == 25 and eventId == "flying_pikachu")) then
      departureMode = "balloon_rig"
    elseif dex == 84 or dex == 85 then
      departureMode = "runner_mount"
    elseif dex == 151 then
      departureMode = "psychic_float"
    elseif dex == 130 or dex == 384 then
      departureMode = "sky_swim"
    elseif resolvedMode == "mount" then
      departureMode = "back_mount"
    elseif winged then
      departureMode = "tow_handle"
    else
      departureMode = "tow_handle"
    end
    return {
      mode = resolvedMode,
      departureMode = departureMode,
      monScale = 1,
      riderScale = 1,
      seatX = tuned.seatX or -1,
      seatLift = tuned.seatLift or 17,
      carryX = 11,
      carryDrop = 6,
      shadowRadius = tuned.shadowRadius
        or (resolvedMode == "mount" and 13 or 9),
      winged = winged,
    }
  end

  local function fieldKitProfile()
    return {
      mode = "carry",
      departureMode = "trainer_jetpack",
      monScale = 0,
      riderScale = 1,
      shadowRadius = 10,
      winged = false,
    }
  end

  local function isShiny(mon)
    if type(mon) ~= "table" then return false end
    if mon.shiny == true or mon.isShiny == true then return true end
    local ok, shiny = pcall(Stats.isShiny, mon.dvs)
    return ok and shiny == true
  end

  local function spriteRel(mon)
    local dex = speciesDex(mon)
    if not dex then return nil end
    return string.format("%s/%03d-%s.png", SHEET_DIR, dex,
      isShiny(mon) and "shiny" or "normal")
  end

  -- Other direct FLY surfaces can call ow:flyTo() without opening the native
  -- party submenu. Unless the dedicated FIELD KIT marker below is present,
  -- use the first actual FLY user (the same party order used by partyKnows).
  local function firstFlyUser()
    local party = Game.save and Game.save.party
    if type(party) ~= "table" then return nil end
    for _, mon in ipairs(party) do
      if knowsMove(mon, "FLY") then return mon end
    end
    return nil
  end

  local function voxelActive()
    local ok, level = pcall(Pipelines.level, PIPELINE_ID)
    voxelLevel = ok and (tonumber(level) or 0) or 0
    if voxelLevel <= 0 then return false end
    -- A renderer that threw once is retired by Gen1Recomp for the rest of
    -- the session, but its persisted level remains non-zero. In that state
    -- the voxel update/draw callbacks (and therefore our timeout) will never
    -- run again. Refuse to arm, or synchronously fail open, whenever the
    -- engine exposes that stronger eligibility signal.
    if type(Pipelines.eligible) == "function" then
      local eligibleOk, eligible = pcall(Pipelines.eligible, PIPELINE_ID)
      if not eligibleOk or eligible ~= true then return false end
    end
    return true
  end

  local quadsFor

  local function imageUsable(image)
    if image == nil or type(image.getDimensions) ~= "function" then
      return false
    end
    local ok, width, height = pcall(image.getDimensions, image)
    return ok and type(width) == "number" and type(height) == "number"
      and width > 0 and height > 0
  end

  local function evictImage(rel, image)
    local cached = rel and imageCache[rel] or nil
    if cached then quadCache[cached] = nil end
    if image then quadCache[image] = nil end
    if rel and (image == nil or cached == image) then imageCache[rel] = nil end
  end

  local function reportImageError(rel, reason)
    reason = tostring(reason or "unknown image error")
    if lastImageError[rel] == reason then return end
    lastImageError[rel] = reason
    safeLog("error", "Fly-Cinematic-Sprite %s fehlgeschlagen: %s",
      tostring(rel), reason)
  end

  local function loadImage(mon)
    local rel = spriteRel(mon)
    if not rel then return nil end
    local cached = imageCache[rel]
    if cached ~= nil then
      if imageUsable(cached) then return cached, rel end
      evictImage(rel, cached)
      reportImageError(rel, "cached image became unavailable; retrying")
    end
    local ok, image = pcall(function()
      local path = mod.assets:path(rel)
      local loaded = assert(love.graphics.newImage(path))
      local width, height = loaded:getDimensions()
      local directional = width == height
        and width >= 128 and width <= 256
        and width % SHEET_COLUMNS == 0
      local sixPose = speciesDex(mon) == GOROCHU_DEX
        and mon.species == "GOROCHU" and width == 16 and height == 96
      if not directional and not sixPose then
        error("incompatible cinematic sprite sheet")
      end
      if loaded.setFilter then loaded:setFilter("nearest", "nearest") end
      -- Construct every quad while still inside the fail-open boundary. A
      -- decoder or graphics backend rejecting the layout must leave native
      -- FLY untouched instead of arming a cinematic that fails on first draw.
      quadsFor(loaded)
      return loaded
    end)
    if not ok or not image then
      -- Never retain a negative cache entry. GPU resources can be invalidated
      -- during a resize/hot reload, and even a packaged image decode may fail
      -- transiently. The next FLY therefore receives one clean retry.
      reportImageError(rel, ok and "image loader returned nil" or image)
      return nil
    end
    lastImageError[rel] = nil
    imageCache[rel] = image
    return image, rel
  end

  quadsFor = function(image)
    local cached = quadCache[image]
    if cached then return cached end
    local iw, ih = image:getDimensions()
    local layout = {
      quads = {}, cell = CELL, drawScale = 1, footPad = 4,
      mirrorRows = {},
    }
    if iw == 16 and ih == 96 then
      -- Gorochu ships as Gen1Recomp's six-pose walker: down/up/side still,
      -- then down/up/side walk. Expand it logically into the cinematic's
      -- four-direction/four-column contract and render it at exact 2x nearest
      -- scale. The authored side pose faces left, so mirror only the right row.
      local frames = {
        [0] = { 0, 3, 0, 3 },
        [1] = { 2, 5, 2, 5 },
        [2] = { 2, 5, 2, 5 },
        [3] = { 1, 4, 1, 4 },
      }
      layout.cell, layout.drawScale, layout.footPad = 16, 2, 2
      layout.mirrorRows[2] = true
      for row = 0, SHEET_ROWS - 1 do
        layout.quads[row] = {}
        for col = 0, SHEET_COLUMNS - 1 do
          local frame = frames[row][col + 1]
          layout.quads[row][col] = love.graphics.newQuad(0, frame * 16,
            16, 16, iw, ih)
        end
      end
    else
      -- Most sheets use 32px cells. A handful of genuinely large species
      -- (Steelix, Wailord, Lugia, Ho-Oh and the weather trio) deliberately
      -- author 36px, 41px or 64px cells in the same verified 4x4 layout.
      local cell = iw / SHEET_COLUMNS
      layout.cell = cell
      layout.footPad = math.max(2, math.floor(cell / 8 + 0.5))
      for row = 0, SHEET_ROWS - 1 do
        layout.quads[row] = {}
        for col = 0, SHEET_COLUMNS - 1 do
          layout.quads[row][col] = love.graphics.newQuad(col * cell,
            row * cell, cell, cell, iw, ih)
        end
      end
    end
    quadCache[image] = layout
    return layout
  end

  local function releaseLandingLock(ow, shot)
    local player = shot and (shot.lockPlayer or (ow and ow.player))
    if shot and shot.ownsLandingLock and player then
      -- FLY's native postcondition is always an unlocked player. Newer
      -- phase/t engines deliberately keep the lock through flyArrive, so a
      -- snapshot taken at the warp boundary would incorrectly restore true.
      player.inputLocked = false
      shot.ownsLandingLock = false
    end
  end

  local function releaseTravelLock(ow, shot)
    local player = shot and (shot.lockPlayer or (ow and ow.player))
    if shot and shot.ownsTravelLock and player then
      player.inputLocked = false
      shot.ownsTravelLock = false
    end
  end

  local function finishNativeDeparture(ow)
    local anim = ow and ow.flyAnim
    if type(anim) ~= "table" then return end
    if tonumber(anim.frames) then
      -- Legacy numeric countdown controller.
      anim.frames = 1
    elseif anim.phase ~= nil and tonumber(anim.t) then
      -- Gen1Recomp >=0.1.90 phase controller. A deliberately oversized
      -- final-path timer lets the original update execute its own warp branch
      -- on the very next tick without copying engine internals into this mod.
      anim.phase = "path2"
      anim.t = math.huge
    end
  end

  local function releaseDepartureHold(ow, shot)
    if shot and shot.phase == "departure" and ow and ow.flyAnim then
      -- Let the native controller finish its regular FLY transition on the
      -- next logic tick. This is also the fail-safe path if VASC disappears
      -- or its overlay callback errors while the cinematic is being held.
      finishNativeDeparture(ow)
    end
  end

  -- Gen1Recomp 0.2.36 resumes the destination map theme in the final tick of
  -- its native `flyArrive` controller.  VASC deliberately consumes that
  -- controller because the species/jetpack landing owns the visible swoop;
  -- consuming it must also assume its non-visual music postcondition.  Only a
  -- controller we actually removed is eligible, and only after the native
  -- Transition has reached the selected destination, so a departure abort
  -- continues through the untouched engine path without a duplicate play.
  local function restoreOwnedArrivalMusic(ow, shot)
    if not (ow and shot and shot.consumedNativeArrival
        and not shot.mapMusicRestored and not ow.transitioning) then
      return false
    end
    local mapId = ow.map and ow.map.id
    if not mapId or (shot.destinationMap and mapId ~= shot.destinationMap) then
      return false
    end
    local okMusic, Music = pcall(require, "src.core.Music")
    if not (okMusic and type(Music) == "table"
        and type(Music.playMap) == "function") then
      safeLog("warn", "Fly-Landung konnte Kartenmusik nicht übernehmen")
      return false
    end
    local okPlay, reason = pcall(Music.playMap, Game.data, mapId,
      Game.save and Game.save.onBike,
      ow.player and ow.player.surfing, nil)
    if not okPlay then
      safeLog("warn", "Fly-Landung konnte Kartenmusik nicht starten: %s",
        tostring(reason))
      return false
    end
    shot.mapMusicRestored = true
    return true
  end

  local function abort(ow)
    local shot = ow and activeByWorld[ow]
    restoreOwnedArrivalMusic(ow, shot)
    releaseDepartureHold(ow, shot)
    releaseLandingLock(ow, shot)
    releaseTravelLock(ow, shot)
    if ow then
      waitingForNativeByWorld[ow] = nil
      activeByWorld[ow] = nil
    end
  end

  local function beginDeparture(ow, mon)
    local fieldKitJetpack = mon == FIELD_KIT_JETPACK
      or (type(mon) == "table" and mon.fieldKitJetpack == true)
    local image, rel, profile
    if fieldKitJetpack then
      profile = fieldKitProfile()
    else
      image, rel = loadImage(mon)
      if not image then return false end
      profile = flightProfile(mon)
    end
    -- The engine's FLY countdown runs on fixed logic ticks and is therefore
    -- accelerated by game speed. Keep it one tick short of the native warp;
    -- the update bridge below holds it there until every cinematic beat has
    -- actually reached a rendered VASC overlay frame.
    if ow.flyAnim and tonumber(ow.flyAnim.frames) then
      ow.flyAnim.frames = 2
    elseif ow.flyAnim and ow.flyAnim.phase ~= nil then
      ow.flyAnim.phase, ow.flyAnim.t = "flap", 0
    end
    activeByWorld[ow] = {
      phase = "departure",
      frame = 0,
      waitFrames = 0,
      departureDone = false,
      mon = mon,
      profile = profile,
      image = image,
      rel = rel,
      originMap = ow.map and ow.map.id,
      destinationMap = ow.flyDest and ow.flyDest.map,
    }
    return true
  end

  local function beginLanding(ow, shot)
    shot.phase = "landing"
    shot.frame = 0
    shot.renderedSinceUpdate = nil
    shot.waitFrames = 0
    -- Newer engines arm their own generic flyArrive at the warp midpoint and
    -- release input when it finishes. The custom landing replaces that whole
    -- presentation, so consume it and own one unambiguous lock until frame 96.
    if ow.flyArrive then shot.consumedNativeArrival = true end
    ow.flyArrive = nil
    ow.playerHidden = false
    shot.ownsTravelLock = false
    if ow.player then
      shot.lockPlayer = ow.player
      ow.player.inputLocked = true
      shot.ownsLandingLock = true
    end
  end

  local function updateShot(ow, dt)
    local shot = activeByWorld[ow]
    if not shot then return end
    if voxelLevel <= 0 then abort(ow) return end

    if shot.phase == "departure" then
      if not ow.flyAnim then
        shot.phase = "travel"
        shot.frame = 0
        shot.renderedSinceUpdate = nil
        shot.waitFrames = 0
        if ow.transitioning then
          shot.sawTransition = true
        else
          local mapId = ow.map and ow.map.id
          if shot.nativeWarpStarted and mapId == shot.destinationMap then
            -- At high game speed the entire native transition can begin and
            -- end between two display frames. This also covers same-map FLY,
            -- where comparing only against originMap can never detect it.
            beginLanding(ow, shot)
          end
        end
        return
      end

      local frames = math.max(0, tonumber(dt) or 0) * 60
      shot.waitFrames = (shot.waitFrames or 0) + frames
      if shot.renderedSinceUpdate then
        shot.renderedSinceUpdate = nil
        shot.waitFrames = 0
        if not shot.departureDone then
          -- A long display hitch must not skip the entire pickup in one
          -- visible frame. Three animation frames still allow a 20 FPS
          -- renderer to play the sequence at its intended real-time speed.
          shot.frame = math.min(DEPARTURE_FRAMES,
            shot.frame + math.min(frames, 3))
          if shot.frame >= DEPARTURE_FRAMES then
            shot.departureDone = true
            finishNativeDeparture(ow)
          end
        end
      end
      -- Do not hold the player's input forever if VASC permanently stops
      -- producing an overlay. abort() releases the native transition.
      if shot.waitFrames >= 600 then abort(ow) end
      return
    end

    if shot.phase == "travel" then
      shot.waitFrames = (shot.waitFrames or 0)
        + math.max(0, tonumber(dt) or 0) * 60
      local mapId = ow.map and ow.map.id
      if ow.transitioning then
        shot.sawTransition = true
      elseif shot.sawTransition or (mapId and mapId ~= shot.originMap)
          or (shot.nativeWarpStarted and mapId == shot.destinationMap) then
        beginLanding(ow, shot)
      end
      if shot.phase == "travel" and shot.waitFrames >= 600 then abort(ow) end
      return
    end

    if shot.phase == "landing" then
      local frames = math.max(0, tonumber(dt) or 0) * 60
      shot.waitFrames = (shot.waitFrames or 0) + frames
      if shot.renderedSinceUpdate then
        shot.renderedSinceUpdate = nil
        shot.waitFrames = 0
        shot.frame = shot.frame + frames
      end
      -- Never leave input locked forever if a renderer stops invoking its
      -- overlay callback. A regular landing resets this guard every frame.
      if shot.waitFrames >= 600 then abort(ow) return end
      local landingFrames = shot.profile
          and shot.profile.departureMode == "trainer_jetpack"
        and FIELD_KIT_LANDING_FRAMES or LANDING_FRAMES
      if shot.frame >= landingFrames then abort(ow) end
    end
  end

  local ROW_DOWN, ROW_LEFT, ROW_RIGHT, ROW_UP = 0, 1, 2, 3

  local function drawPokemon(image, row, col, centerX, footY, scale,
                             alpha, tint)
    if not image or scale <= 0 or (alpha or 1) <= 0 then return end
    local layout = quadsFor(image)
    local rows = layout.quads
    local quad = rows[row] and rows[row][col] or rows[ROW_DOWN][0]
    local cell = layout.cell
    local authoredScale = scale * layout.drawScale
    local mirror = layout.mirrorRows[row] == true
    local drawScaleX = mirror and -authoredScale or authoredScale
    local drawX = centerX - cell * 0.5 * authoredScale
    if mirror then drawX = centerX + cell * 0.5 * authoredScale end
    tint = tint or { 1, 1, 1 }
    love.graphics.setColor(tint[1], tint[2], tint[3], alpha or 1)
    love.graphics.draw(image, quad,
      math.floor(drawX + 0.5),
      -- Match SpriteRenderer's native foot pivot: the authored pixels end
      -- four world pixels above the projected ground point.
      math.floor(footY - (cell + layout.footPad) * authoredScale + 0.5),
      0, drawScaleX, authoredScale)
  end

  local PLAYER_STAND = { down = 0, up = 1, left = 2, right = 2 }

  local function drawPlayer(player, footX, footY, scale, facingOverride,
                            alpha, paletteColors)
    if not player or type(player.pose) ~= "function" then return false end
    local sprite, _, _, facing = player:pose()
    -- flyTo() dismounts immediately in save state, while Player.onBike is
    -- synchronized on the following overworld tick. A display frame can land
    -- in between those two operations, so prefer the same character's live
    -- walking renderer during that one-frame seam instead of flashing their
    -- bicycle sheet as the cinematic begins.
    if player.onBike and player.sprite then sprite = player.sprite end
    if not sprite or type(sprite.resolveImage) ~= "function" then
      return false
    end
    facing = facingOverride or facing or "down"
    local image = sprite:resolveImage()
    local frame = PLAYER_STAND[facing] or 0
    local quad = sprite.frames and (sprite.frames[frame] or sprite.frames[0])
    if not image or not quad then return false end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    local x = footX - 8 * scale
    local y = footY - 20 * scale
    local sx = scale
    if facing == "right" then x, sx = x + 16 * scale, -scale end
    -- Kanto Ascendant swaps the live Player renderer when Red, Blue or Green
    -- is selected. Palette-indexed walkers still need the map shader, while
    -- its optional Crystal character sheets are authored true-colour and must
    -- pass through untouched, exactly like VASC's regular entity path.
    local trueColor = type(sprite.def) == "table"
      and sprite.def.trueColor == true
    local shader = paletteColors and not trueColor
      and PaletteFX.shader() or nil
    if shader then
      PaletteFX.sendColors(shader, paletteColors)
      love.graphics.setShader(shader)
    end
    love.graphics.draw(image, quad, math.floor(x + 0.5),
      math.floor(y + 0.5), 0, sx, scale)
    if shader then love.graphics.setShader() end
    return true
  end

  local BALL_PIXELS = {
    "..KKK..",
    ".KRRRK.",
    "KRRRRRK",
    "KKKWKKK",
    "KWWWWWK",
    ".KWWWK.",
    "..KKK..",
  }

  local function drawBall(x, y, scale, alpha)
    local g = love.graphics
    local unit = math.max(1, math.floor(scale * 0.42 + 0.5))
    local ox = math.floor(x - 3.5 * unit + 0.5)
    local oy = math.floor(y - 3.5 * unit + 0.5)
    local colors = {
      K = { 0.06, 0.07, 0.08 },
      R = { 0.92, 0.12, 0.12 },
      W = { 0.98, 0.98, 0.91 },
    }
    for row, pixels in ipairs(BALL_PIXELS) do
      for col = 1, #pixels do
        local key = pixels:sub(col, col)
        local color = colors[key]
        if color then
          g.setColor(color[1], color[2], color[3], alpha or 1)
          g.rectangle("fill", ox + (col - 1) * unit,
            oy + (row - 1) * unit, unit, unit)
        end
      end
    end
  end

  local SPARK_DIRECTIONS = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -0.72, -0.72 }, { 0.72, -0.72 },
    { -0.72, 0.72 }, { 0.72, 0.72 },
  }

  local function drawSparkles(x, y, radius, alpha, progress, color)
    if alpha <= 0 then return end
    local g = love.graphics
    color = color or { 1, 0.88, 0.28 }
    local unit = math.max(1, math.floor(radius * 0.09 + 0.5))
    progress = clamp(progress or 0, 0, 1)
    for i, direction in ipairs(SPARK_DIRECTIONS) do
      local stagger = ((i - 1) % 3) * 0.08
      local travel = clamp(progress - stagger, 0, 1)
      local distance = radius * (0.22 + 0.78 * travel)
      local px = math.floor(x + direction[1] * distance + 0.5)
      local py = math.floor(y + direction[2] * distance + 0.5)
      local a = alpha * (1 - travel * 0.34)
      g.setColor(color[1], color[2], color[3], a)
      if i <= 4 then
        g.rectangle("fill", px - unit, py, unit * 3, unit)
        g.rectangle("fill", px, py - unit, unit, unit * 3)
      else
        g.rectangle("fill", px, py, unit, unit)
      end
    end
  end

  local function drawShadow(x, y, radius, scale, alpha)
    love.graphics.setColor(0.03, 0.08, 0.09, 0.30 * (alpha or 1))
    love.graphics.ellipse("fill", x, y, radius * scale, 2.4 * scale)
  end

  local function drawPixelLine(x1, y1, x2, y2, scale, color, alpha)
    local unit = math.max(1, math.floor(scale + 0.5))
    local distance = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
    local steps = math.max(1, math.ceil(distance / unit))
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    for step = 0, steps do
      local t = step / steps
      love.graphics.rectangle("fill",
        math.floor(lerp(x1, x2, t) + 0.5),
        math.floor(lerp(y1, y2, t) + 0.5), unit, unit)
    end
  end

  -- FIELD KIT hardware deliberately uses its own small Gen-1 palette. The
  -- steel twin tanks remain readable beside the 16px trainer, while the two
  -- separated exhaust plumes make the lift source unmistakable in motion.
  local JETPACK_DARK = { 0.12, 0.16, 0.20 }
  local JETPACK_STEEL = { 0.64, 0.72, 0.78 }
  local JETPACK_HIGHLIGHT = { 0.86, 0.92, 0.92 }
  local JETPACK_BLUE = { 0.18, 0.42, 0.62 }
  local JETPACK_ORANGE = { 0.96, 0.35, 0.05 }
  local JETPACK_YELLOW = { 1.00, 0.88, 0.18 }

  local function drawJetpackRect(x, y, w, h, scale, color, alpha)
    if (alpha or 1) <= 0 or w <= 0 or h <= 0 then return end
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.rectangle("fill", math.floor(x + 0.5),
      math.floor(y + 0.5), math.max(1, math.floor(w * scale + 0.5)),
      math.max(1, math.floor(h * scale + 0.5)))
  end

  local function drawJetpackBody(riderX, riderFootY, scale, deploy, alpha)
    deploy = clamp(deploy or 0, 0, 1)
    alpha = alpha or 1
    if deploy <= 0.05 or alpha <= 0 then return end
    local extension = smooth(deploy)
    local top = riderFootY - (8 + 9 * extension) * scale
    local tankHeight = 5 + 7 * extension

    -- Central red-orange FIELD KIT housing. It sits behind Red; the tanks and
    -- their highlights intentionally protrude by two pixels on either side.
    drawJetpackRect(riderX - 6 * scale, top + 2 * scale,
      12, tankHeight, scale, JETPACK_DARK, alpha)
    drawJetpackRect(riderX - 4 * scale, top + 3 * scale,
      8, math.max(2, tankHeight - 2), scale, JETPACK_ORANGE, alpha)
    drawJetpackRect(riderX - scale, top + 4 * scale,
      2, math.max(1, tankHeight - 4), scale, JETPACK_YELLOW, alpha)

    for _, side in ipairs({ -1, 1 }) do
      local tankX = riderX + side * 7 * scale
      drawJetpackRect(tankX - 3 * scale, top, 6, tankHeight,
        scale, JETPACK_DARK, alpha)
      drawJetpackRect(tankX - 2 * scale, top + scale, 4,
        math.max(2, tankHeight - 2), scale, JETPACK_STEEL, alpha)
      drawJetpackRect(tankX - scale, top + 2 * scale, 1,
        math.max(1, tankHeight - 4), scale, JETPACK_HIGHLIGHT, alpha)
      drawJetpackRect(tankX + scale, top + 2 * scale, 1,
        math.max(1, tankHeight - 4), scale, JETPACK_BLUE, alpha)
      drawJetpackRect(tankX - 2 * scale, top - 2 * scale, 4, 2,
        scale, JETPACK_DARK, alpha)
      drawJetpackRect(tankX - 2 * scale,
        top + tankHeight * scale, 4, 3, scale, JETPACK_DARK, alpha)
    end
  end

  local function drawJetpackExhaust(riderX, riderFootY, scale, thrust,
                                    pulse, alpha)
    thrust = clamp(thrust or 0, 0, 1)
    alpha = alpha or 1
    if thrust <= 0.03 or alpha <= 0 then return end
    local flicker = math.floor((math.sin(pulse or 0) + 1) * 1.5 + 0.5)
    local flame = 4 + math.floor(thrust * 7 + 0.5) + flicker
    local nozzleY = riderFootY - 3 * scale
    for _, side in ipairs({ -1, 1 }) do
      local nozzleX = riderX + side * 7 * scale
      drawJetpackRect(nozzleX - 2 * scale, nozzleY, 4, 3,
        scale, JETPACK_DARK, alpha)
      drawJetpackRect(nozzleX - 1.5 * scale, riderFootY - scale,
        3, flame, scale, JETPACK_ORANGE, alpha)
      drawJetpackRect(nozzleX - 0.5 * scale, riderFootY,
        1, math.max(2, flame - 3), scale, JETPACK_YELLOW, alpha)
      drawJetpackRect(nozzleX - 0.5 * scale, riderFootY,
        1, math.max(1, math.floor((flame - 4) * 0.45)), scale,
        JETPACK_HIGHLIGHT, alpha)
    end
  end

  local function drawJetpackStraps(riderX, riderFootY, scale, deploy, alpha)
    deploy = clamp(deploy or 0, 0, 1)
    alpha = (alpha or 1) * deploy
    if deploy <= 0.05 or alpha <= 0 then return end
    -- Straps are drawn after Red so the pack reads as worn, never as a sprite
    -- hovering behind or grabbing the trainer by the neck.
    drawPixelLine(riderX - 5 * scale, riderFootY - 16 * scale,
      riderX - 6 * scale, riderFootY - 8 * scale, scale,
      JETPACK_DARK, alpha)
    drawPixelLine(riderX + 5 * scale, riderFootY - 16 * scale,
      riderX + 6 * scale, riderFootY - 8 * scale, scale,
      JETPACK_DARK, alpha)
    drawPixelLine(riderX - 4 * scale, riderFootY - 15 * scale,
      riderX - 5 * scale, riderFootY - 9 * scale, scale,
      JETPACK_ORANGE, alpha)
    drawPixelLine(riderX + 4 * scale, riderFootY - 15 * scale,
      riderX + 5 * scale, riderFootY - 9 * scale, scale,
      JETPACK_ORANGE, alpha)
    drawJetpackRect(riderX - 7 * scale, riderFootY - 8 * scale,
      14, 3, scale, JETPACK_DARK, alpha)
    drawJetpackRect(riderX - 6 * scale, riderFootY - 7 * scale,
      12, 1, scale, JETPACK_ORANGE, alpha)
  end

  local function drawJetpackDust(groundX, groundY, scale, progress, alpha)
    progress = clamp(progress or 0, 0, 1)
    alpha = alpha or 1
    if alpha <= 0.02 then return end
    local colors = { { 0.78, 0.72, 0.62 }, { 0.55, 0.51, 0.44 } }
    local unit = math.max(1, math.floor(scale + 0.5))
    for i = 1, 8 do
      local side = i % 2 == 0 and 1 or -1
      local lane = math.floor((i - 1) / 2)
      local spread = (4 + lane * 3 + progress * 12) * scale
      local rise = ((lane + i) % 3) * scale
      local color = colors[(i % 2) + 1]
      love.graphics.setColor(color[1], color[2], color[3],
        alpha * (0.9 - progress * 0.42))
      love.graphics.rectangle("fill",
        math.floor(groundX + side * spread + 0.5),
        math.floor(groundY - rise + 0.5),
        unit * (lane == 3 and 2 or 1), unit)
    end
  end

  local BALLOON_PATTERNS = {
    {
      ".K.",
      "KCK",
      "KCK",
      ".K.",
      ".K.",
    },
    {
      ".KKK.",
      "KCCCK",
      "KCHCK",
      ".KCK.",
      "..K..",
    },
    {
      "..KKK..",
      ".KCCCK.",
      "KCHCCCK",
      "KCCCCCK",
      ".KCCCK.",
      "..KCK..",
      "...K...",
    },
  }

  local BALLOON_COLORS = {
    { 0.92, 0.16, 0.18 }, { 0.47, 0.43, 0.70 },
    { 0.05, 0.62, 0.52 }, { 0.05, 0.57, 0.75 },
    { 0.88, 0.36, 0.70 }, { 0.92, 0.43, 0.08 },
  }

  local function drawPixelBalloon(centerX, topY, scale, color, alpha, stage)
    local pattern = BALLOON_PATTERNS[clamp(stage, 1, 3)]
    local unit = math.max(1, math.floor(scale + 0.5))
    local width = #pattern[1] * unit
    local ox = math.floor(centerX - width * 0.5 + 0.5)
    local oy = math.floor(topY + 0.5)
    local colors = {
      K = { 0.10, 0.09, 0.16 }, C = color,
      H = { 1, 0.96, 0.78 },
    }
    for row, pixels in ipairs(pattern) do
      for col = 1, #pixels do
        local c = colors[pixels:sub(col, col)]
        if c then
          love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
          love.graphics.rectangle("fill", ox + (col - 1) * unit,
            oy + (row - 1) * unit, unit, unit)
        end
      end
    end
    return oy + #pattern * unit
  end

  local function drawBalloonRig(monX, monFootY, scale, inflate, sway, alpha)
    inflate = clamp(inflate or 0, 0, 1)
    alpha = alpha or 1
    if inflate <= 0 or alpha <= 0 then return end
    local hubX, hubY = monX, monFootY - 20 * scale
    local offsets = {
      { -10, -27 }, { 0, -33 }, { 10, -26 },
      { -4, -22 }, { 8, -19 }, { 2, -17 },
    }
    local knots = {}
    for i, offset in ipairs(offsets) do
      local localInflate = clamp(inflate * 1.45 - (i - 1) * 0.09, 0, 1)
      if localInflate > 0 then
        local stage = localInflate < 0.34 and 1
          or (localInflate < 0.72 and 2 or 3)
        local reach = smooth(localInflate)
        local drift = math.sin((sway or 0) + i * 1.17)
          * 1.5 * scale * reach
        local centerX = hubX + offset[1] * scale * reach + drift
        local topY = hubY + offset[2] * scale * reach
        local knotY = topY + (stage == 1 and 5
          or (stage == 2 and 5 or 7)) * math.max(1, math.floor(scale + 0.5))
        knots[#knots + 1] = { centerX, knotY }
      end
    end
    local stringColor = { 0.24, 0.20, 0.28 }
    for _, knot in ipairs(knots) do
      drawPixelLine(knot[1], knot[2], hubX, hubY, scale,
        stringColor, 0.82 * alpha)
    end
    -- Two suspension points lead into Pikachu's waist harness, matching the
    -- characteristic Flying Pikachu silhouette instead of dangling him from
    -- a single invisible point.
    drawPixelLine(hubX, hubY, monX - 6 * scale,
      monFootY - 10 * scale, scale, stringColor, 0.9 * alpha)
    drawPixelLine(hubX, hubY, monX + 6 * scale,
      monFootY - 10 * scale, scale, stringColor, 0.9 * alpha)
    for i, offset in ipairs(offsets) do
      local localInflate = clamp(inflate * 1.45 - (i - 1) * 0.09, 0, 1)
      if localInflate > 0 then
        local stage = localInflate < 0.34 and 1
          or (localInflate < 0.72 and 2 or 3)
        local reach = smooth(localInflate)
        local drift = math.sin((sway or 0) + i * 1.17)
          * 1.5 * scale * reach
        drawPixelBalloon(hubX + offset[1] * scale * reach + drift,
          hubY + offset[2] * scale * reach, scale,
          BALLOON_COLORS[i], alpha, stage)
      end
    end
  end

  local function drawBalloonHarness(monX, monFootY, scale, alpha)
    local dark = { 0.20, 0.11, 0.06 }
    local orange = { 0.94, 0.43, 0.05 }
    local y = monFootY - 9 * scale
    drawPixelLine(monX - 7 * scale, y - scale,
      monX + 7 * scale, y + scale, scale, dark, alpha)
    drawPixelLine(monX - 6 * scale, y - scale,
      monX + 6 * scale, y, scale, orange, alpha)
  end

  local function drawBalloonTowBand(monX, monFootY, riderX, riderFootY,
                                    scale, alpha)
    local fromX, fromY = monX - 7 * scale, monFootY - 9 * scale
    -- The down-facing 16px trainer's visible right hand sits five pixels to
    -- the right of the foot pivot and ten above it. Anchoring at the sprite
    -- centre would read as another cap/collar grab.
    local handX, handY = riderX + 5 * scale,
      riderFootY - 10 * scale
    -- A dark one-pixel outline and orange inner pixel make the tow band
    -- readable against both VASC sky and terrain at the native pixel scale.
    drawPixelLine(fromX, fromY + scale, handX, handY + scale,
      scale, { 0.18, 0.10, 0.06 }, alpha)
    drawPixelLine(fromX, fromY, handX, handY,
      scale, { 0.94, 0.43, 0.05 }, alpha)
  end

  local function drawTowHandle(monX, monFootY, riderX, riderFootY,
                               scale, alpha)
    local handX, handY = riderX, riderFootY - 14 * scale
    drawPixelLine(monX, monFootY - 5 * scale, handX, handY,
      scale, { 0.26, 0.20, 0.14 }, 0.9 * (alpha or 1))
    love.graphics.setColor(0.18, 0.11, 0.07, alpha or 1)
    love.graphics.rectangle("fill", math.floor(handX - 4 * scale + 0.5),
      math.floor(handY + 0.5), math.max(2, math.floor(8 * scale + 0.5)),
      math.max(1, math.floor(scale + 0.5)))
  end

  local function drawPsychicAura(x, y, scale, progress, alpha)
    local colors = { { 1, 0.42, 0.78 }, { 0.42, 0.92, 1 } }
    local unit = math.max(1, math.floor(scale + 0.5))
    for i = 1, 12 do
      local angle = (i - 1) / 12 * math.pi * 2 + progress * math.pi * 2
      local radiusX = (13 + 3 * math.sin(progress * math.pi)) * scale
      local radiusY = 19 * scale
      local color = colors[(i % 2) + 1]
      love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
      love.graphics.rectangle("fill",
        math.floor(x + math.cos(angle) * radiusX + 0.5),
        math.floor(y + math.sin(angle) * radiusY + 0.5), unit, unit)
    end
  end

  local function drawRunDust(x, y, scale, progress, alpha)
    local unit = math.max(1, math.floor(scale + 0.5))
    for i = 1, 5 do
      local lag = ((i - 1) * 5 + progress * 18) % 22
      love.graphics.setColor(0.72, 0.61, 0.42,
        (alpha or 1) * (1 - lag / 24))
      love.graphics.rectangle("fill", math.floor(x + lag * scale + 0.5),
        math.floor(y - (i % 2) * 2 * scale + 0.5), unit, unit)
    end
  end

  local RECALL_MOTES = {
    { -10, -8 }, { 7, -10 }, { -5, 2 }, { 10, 4 },
    { 0, -14 }, { -11, 7 }, { 4, 8 }, { 12, -3 },
  }

  local function drawRecallPixels(ballX, ballY, monX, monY, scale, progress)
    local g = love.graphics
    local unit = math.max(1, math.floor(scale * 0.48 + 0.5))
    for step = 2, 10 do
      local t = step / 11
      local x = math.floor(lerp(ballX, monX, t) + 0.5)
      local y = math.floor(lerp(ballY, monY, t) + 0.5)
      g.setColor(1, 0.64 + t * 0.30, 0.56, 0.24 + 0.34 * progress)
      g.rectangle("fill", x, y, unit, unit)
    end
    for i, offset in ipairs(RECALL_MOTES) do
      local travel = clamp(progress * 1.35 - (i - 1) * 0.055, 0, 1)
      local x = lerp(monX + offset[1] * scale, ballX, travel)
      local y = lerp(monY + offset[2] * scale, ballY, travel)
      local size = (i % 3 == 0) and unit * 2 or unit
      g.setColor(1, 0.84, 0.54, 0.94 * (1 - travel * 0.35))
      g.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5),
        size, size)
    end
  end

  local function riderPose(monX, monFootY, profile, scale, airborne)
    local riderScale = scale * profile.riderScale
    if profile.departureMode == "balloon_rig" then
      return monX - 22 * scale, monFootY + 22 * scale, riderScale
    end
    if profile.departureMode == "psychic_float" then
      return monX - 21 * scale, monFootY - 2 * scale, riderScale
    end
    if profile.departureMode == "back_mount"
        or profile.departureMode == "runner_mount"
        or profile.departureMode == "sky_swim" then
      return monX + profile.seatX * scale,
        monFootY - profile.seatLift * scale, riderScale
    end
    if profile.mode == "carry" then
      return monX + profile.carryX * scale,
        monFootY + lerp(-2, profile.carryDrop, airborne or 0) * scale,
        riderScale
    end
    return monX + profile.seatX * scale,
      monFootY - profile.seatLift * scale, riderScale
  end

  local function cubic(a, b, c, d, t)
    local u = 1 - t
    return u * u * u * a + 3 * u * u * t * b
      + 3 * u * t * t * c + t * t * t * d
  end

  local function arcHeight(t)
    if t <= 0 or t >= 1 then return 0 end
    return math.sin(t * math.pi)
  end

  local function cycleColumn(frame, cadence)
    return math.floor(math.max(0, frame) / cadence) % SHEET_COLUMNS
  end

  local function overlayWidth(ctx, displayScale, footX)
    if love.graphics.getCanvas then
      local canvas = love.graphics.getCanvas()
      if canvas and type(canvas.getWidth) == "function" then
        local ok, width = pcall(canvas.getWidth, canvas)
        if ok and tonumber(width) then return width end
      end
    end
    if ctx and tonumber(ctx.width) then
      local factor = 1
      if tonumber(ctx.scale) and ctx.scale > 0 then
        factor = displayScale / ctx.scale
      end
      return ctx.width * factor
    end
    return math.max(footX * 2, 160 * displayScale)
  end

  local function drawCinematic(ow, project, scale, ctx)
    local shot = activeByWorld[ow]
    if not shot or (shot.phase ~= "departure" and shot.phase ~= "landing") then
      return false
    end
    local p = ow.player
    if not p then return false end
    local footX, footY = project(p.px + 8, p.py + 16)
    if not footX then return false end
    scale = tonumber(scale) or 1
    local profile = shot.profile or flightProfile(shot.mon)
    shot.profile = profile
    local paletteColors = ctx and type(ctx.spriteColors) == "function"
      and ctx.spriteColors() or nil
    local playerDrawn = false
    local function drawLivePlayer(...)
      if drawPlayer(...) then playerDrawn = true end
    end

    love.graphics.push("all")
    local ok, drawError = pcall(function()
      local f = shot.frame or 0
      local monScale = scale * profile.monScale
      local baseMonX = footX + 22 * scale
      local baseMonY = footY

      if shot.phase == "departure" then
        local throw = smooth(f / 10)
        local summon = smooth((f - 10) / 8)
        local launch = smooth((f - 72) / 24)
        local mode = profile.departureMode or "tow_handle"
        local monX, monY = baseMonX, baseMonY
        local riderX, riderY, riderScale = footX, footY, scale
        local riderFacing = "right"
        local playerBehind = false
        local trainerDeploy, trainerThrust, trainerLift = 0, 0, 0
        local row = f < 28 and ROW_DOWN or ROW_LEFT
        local cadence = f < 36 and 7 or 5
        local col = f < 28 and 0 or cycleColumn(f - 28, cadence)

        if mode == "trainer_jetpack" then
          -- FIELD KIT FLY has no selected or summoned Pokemon. Red unfolds the
          -- kit's twin-tank jetpack, ignites both nozzles, rises vertically and
          -- then leaves along the same safe 96-frame flight arc.
          trainerDeploy = smooth(f / 18)
          trainerThrust = smooth((f - 24) / 12)
          trainerLift = smooth((f - 38) / 34)
          riderX = footX
          riderY = footY - 44 * scale * trainerLift
          if f >= 72 then
            riderX = cubic(footX, footX - 2 * scale,
              footX - 43 * scale, -40 * scale, launch)
            riderY = cubic(footY - 44 * scale, footY - 52 * scale,
              footY - 71 * scale, footY - 76 * scale, launch)
          end
          monX, monY = riderX, riderY
          riderFacing = f < 24 and "up" or "down"
          playerBehind = true
        elseif mode == "back_mount" or mode == "runner_mount"
            or mode == "sky_swim" then
          -- Red performs an unambiguous running jump in front of the still
          -- Pokemon. Frame 58 is the exact authored seat contact; only then
          -- do both sprites compress, beat their wings and leave as one pair.
          local jumpRaw = clamp((f - 36) / 22, 0, 1)
          local jump = smooth(jumpRaw)
          local seatX, seatY, seatScale =
            riderPose(baseMonX, baseMonY, profile, scale, 0)
          riderX = lerp(footX, seatX, jump)
          riderY = lerp(footY, seatY, jump)
            - math.sin(jumpRaw * math.pi) * 14 * scale
          riderScale = lerp(scale, seatScale, jump)
          riderFacing = f < 52 and "right" or "left"
          playerBehind = f >= 52

          if f >= 58 and f < 66 then
            local compression = (f - 58) / 8
            monY = baseMonY + math.sin(compression * math.pi) * 2 * scale
          elseif f >= 66 and f < 72 then
            local wingbeat = (f - 66) / 6
            monY = baseMonY - math.sin(wingbeat * math.pi) * 3 * scale
          end
          if f >= 72 then
            monX = cubic(baseMonX, baseMonX - 2 * scale,
              footX - 43 * scale, -40 * scale, launch)
            local exitY = mode == "runner_mount"
              and footY - 44 * scale or footY - 76 * scale
            monY = cubic(baseMonY, footY - 28 * scale,
              exitY + 7 * scale, exitY, launch)
            if mode == "sky_swim" then
              monY = monY + math.sin(launch * math.pi * 3)
                * 3 * scale * (1 - launch)
            end
          end
          if f >= 58 then
            riderX, riderY, riderScale =
              riderPose(monX, monY, profile, scale, 0)
          end
          if mode == "runner_mount" and f >= 24 then
            drawRunDust(monX + 8 * scale, baseMonY, scale,
              f / 12, summon * (1 - launch))
          end
        elseif mode == "balloon_rig" then
          local inflate = smooth((f - 18) / 22)
          local tension = smooth((f - 40) / 12)
          local contactMonX, contactMonY = footX + 22 * scale,
            footY - 22 * scale
          local liftMonX, liftMonY = footX + 24 * scale,
            footY - 48 * scale
          monX = lerp(baseMonX, contactMonX, tension)
          monY = lerp(baseMonY, contactMonY, tension)
          riderFacing = f < 52 and "right" or "down"
          row = f < 72 and ROW_DOWN or ROW_LEFT
          col = f < 72 and cycleColumn(f - 28, 8)
            or cycleColumn(f - 72, 5)
          if f >= 52 and f < 72 then
            local lift = smooth((f - 52) / 20)
            monX = lerp(contactMonX, liftMonX, lift)
            monY = lerp(contactMonY, liftMonY, lift)
            riderX, riderY, riderScale =
              riderPose(monX, monY, profile, scale, 0)
            playerBehind = true
          elseif f >= 72 then
            monX = cubic(liftMonX, liftMonX - 2 * scale,
              footX - 43 * scale, -40 * scale, launch)
            monY = cubic(liftMonY, liftMonY - 8 * scale,
              footY - 71 * scale, footY - 76 * scale, launch)
            riderX, riderY, riderScale =
              riderPose(monX, monY, profile, scale, 0)
            playerBehind = true
          end
          drawBalloonRig(monX, monY, scale, inflate, f / 7,
            summon * (1 - launch * 0.08))
        elseif mode == "psychic_float" then
          local levitateRaw = clamp((f - 36) / 22, 0, 1)
          local levitate = smooth(levitateRaw)
          riderX = footX
          riderY = lerp(footY, footY - 26 * scale, levitate)
          monX = lerp(baseMonX, footX + 21 * scale, levitate)
          monY = lerp(baseMonY, footY - 24 * scale, levitate)
          riderFacing = f < 48 and "right" or "left"
          playerBehind = true
          if f >= 72 then
            local startMonX, startMonY = footX + 21 * scale,
              footY - 24 * scale
            monX = cubic(startMonX, startMonX - 2 * scale,
              footX - 38 * scale, -40 * scale, launch)
            monY = cubic(startMonY, startMonY - 18 * scale,
              footY - 70 * scale, footY - 76 * scale, launch)
            riderX = monX - 21 * scale
            riderY = monY - 2 * scale
          end
          drawPsychicAura(riderX, riderY - 10 * scale, scale,
            f / 42, summon * (1 - launch * 0.2))
        else
          -- Small birds tow Red with a visible line and hand grip. The
          -- Pokemon is deliberately separated from his head by 30 pixels,
          -- preventing the former collar/cap-grab silhouette.
          local approach = smooth((f - 28) / 12)
          local contactMonX, contactMonY = footX + 2 * scale,
            footY - 30 * scale
          local liftMonX, liftMonY = footX + 4 * scale,
            footY - 52 * scale
          monX = lerp(baseMonX, contactMonX, approach)
          monY = lerp(baseMonY, contactMonY, approach)
          if f >= 40 then
            local lift = smooth((f - 40) / 18)
            monX = lerp(contactMonX, liftMonX, lift)
            monY = lerp(contactMonY, liftMonY, lift)
            riderX, riderY = monX - 2 * scale, monY + 30 * scale
            riderFacing = "down"
            playerBehind = true
          end
          if f >= 72 then
            monX = cubic(liftMonX, liftMonX - 2 * scale,
              footX - 43 * scale, -40 * scale, launch)
            monY = cubic(liftMonY, liftMonY - 8 * scale,
              footY - 70 * scale, footY - 76 * scale, launch)
            riderX, riderY = monX - 2 * scale, monY + 30 * scale
          end
        end

        if mode == "trainer_jetpack" then
          drawShadow(footX, footY + scale,
            profile.shadowRadius * (1 - trainerLift * 0.45), scale,
            0.8 * (1 - trainerLift))
        else
          drawShadow(baseMonX, baseMonY + scale,
            profile.shadowRadius * (1 - launch * 0.45), scale,
            summon * (1 - launch))
        end

        if mode == "trainer_jetpack" then
          local dustProgress = smooth((f - 24) / 34)
          local dustAlpha = trainerThrust * (1 - trainerLift)
            * (1 - launch)
          drawJetpackDust(footX, footY + scale, scale,
            dustProgress, dustAlpha)
          drawJetpackExhaust(riderX, riderY, scale, trainerThrust,
            f / 2, 1)
          drawJetpackBody(riderX, riderY, scale, trainerDeploy, 1)
        end

        if playerBehind then
          drawLivePlayer(p, riderX, riderY, riderScale, riderFacing, 1,
            paletteColors)
        end
        if summon > 0 then
          drawPokemon(shot.image, row, col, monX, monY, monScale, summon)
        end
        if mode == "balloon_rig" and summon > 0 then
          drawBalloonHarness(monX, monY, scale,
            summon * (1 - launch * 0.08))
          if f >= 30 then
            drawBalloonTowBand(monX, monY, riderX, riderY, scale,
              summon * smooth((f - 30) / 10) * (1 - launch * 0.08))
          end
        elseif mode == "trainer_jetpack" then
          drawJetpackStraps(riderX, riderY, scale, trainerDeploy, 1)
        end
        if not playerBehind then
          drawLivePlayer(p, riderX, riderY, riderScale, riderFacing, 1,
            paletteColors)
        end
        if mode == "tow_handle" and f >= 40 then
          drawTowHandle(monX, monY, riderX, riderY, scale,
            summon * (1 - launch * 0.1))
        end

        if mode ~= "trainer_jetpack" then
          local handX, handY = footX + 3 * scale, footY - 14 * scale
          local impactX, impactY = baseMonX - 8 * scale,
            baseMonY - 18 * scale
          local ballX = lerp(handX, impactX, throw)
          local ballY = lerp(handY, impactY, throw)
            - arcHeight(throw) * 9 * scale
          if f < 14 then
            drawBall(ballX, ballY, scale,
              1 - smooth((f - 11) / 3))
          end
          if f >= 8 and f < 27 then
            local sparkleProgress = smooth((f - 8) / 19)
            drawSparkles(impactX, impactY, 12 * scale,
              1 - smooth((f - 17) / 10), sparkleProgress)
          end
        end
      else
        local trainerJetpack = profile.departureMode == "trainer_jetpack"
        if trainerJetpack then
          local arrive = smooth(f / 30)
          local width = overlayWidth(ctx, scale, footX)
          local anchorX = cubic(width + 40 * scale, width - 8 * scale,
            footX + 40 * scale, footX, arrive)
          local anchorY = cubic(footY - 72 * scale, footY - 70 * scale,
            footY - 38 * scale, footY, arrive)
          if f >= 30 then anchorX, anchorY = footX, footY end
          local deploy = 1 - smooth((f - 38) / 14)
          local thrust = 1 - smooth((f - 24) / 18)
          local dustAlpha = smooth((f - 18) / 10)
            * (1 - smooth((f - 42) / 10))
          drawShadow(footX, footY + scale, profile.shadowRadius, scale, arrive)
          drawJetpackDust(footX, footY + scale, scale,
            smooth((f - 18) / 30), dustAlpha)
          drawJetpackExhaust(anchorX, anchorY, scale, thrust, f / 2, arrive)
          drawJetpackBody(anchorX, anchorY, scale, deploy, arrive)
          drawLivePlayer(p, anchorX, anchorY, scale,
            f < 30 and "left" or "down", 1, paletteColors)
          drawJetpackStraps(anchorX, anchorY, scale, deploy, arrive)
        else
        local arrive = smooth(f / 30)
        local settle = smooth((f - 30) / 10)
        local dismount = smooth((f - 40) / 20)
        local throw = smooth((f - 68) / 10)
        local recall = smooth((f - 78) / 10)
        local ballReturn = smooth((f - 88) / 8)
        local width = overlayWidth(ctx, scale, footX)
        local startX = width + 40 * scale
        local balloonTow = profile.departureMode == "balloon_rig"
        local arrivalFootY = balloonTow
          and baseMonY - 22 * scale or baseMonY
        local monX = cubic(startX, width - 8 * scale,
          baseMonX + 40 * scale, baseMonX, arrive)
        local monY = cubic(footY - 72 * scale, footY - 70 * scale,
          footY - 38 * scale, arrivalFootY, arrive)
        if balloonTow then
          if f >= 30 and f < 40 then
            monY = arrivalFootY
              - math.sin(settle * math.pi) * 2 * scale
          elseif f >= 40 and f < 60 then
            monX = baseMonX
            monY = lerp(arrivalFootY, baseMonY,
              smooth((f - 40) / 20))
          elseif f >= 60 then
            monX, monY = baseMonX, baseMonY
          end
        elseif f >= 30 and f < 40 then
          monY = baseMonY - math.sin(settle * math.pi) * 2 * scale
        elseif f >= 40 then
          monX, monY = baseMonX, baseMonY
        end

        drawShadow(baseMonX, baseMonY + scale,
          profile.shadowRadius, scale, arrive * (1 - recall))

        if profile.departureMode == "balloon_rig" then
          -- Keep the complete rig attached throughout arrival and Red's
          -- dismount. The balloons only deflate after he is safely grounded,
          -- then vanish before the regular Pokeball recall begins.
          local rigInflate = 1 - smooth((f - 60) / 18)
          drawBalloonRig(monX, monY, scale, rigInflate, f / 7,
            arrive * (1 - recall))
        elseif profile.departureMode == "psychic_float" then
          local auraX, auraY = riderPose(monX, monY, profile, scale, 0)
          drawPsychicAura(auraX, auraY - 10 * scale, scale, f / 42,
            arrive * (1 - smooth((f - 52) / 16)))
        elseif profile.departureMode == "runner_mount" and f < 36 then
          drawRunDust(monX + 8 * scale, baseMonY, scale, f / 12,
            arrive * (1 - smooth((f - 26) / 10)))
        end

        local airborne = f < 30 and (1 - arrive) or 0
        local riderX, riderY, riderScale =
          riderPose(monX, monY, profile, scale, airborne)
        if balloonTow and f >= 40 then
          drawLivePlayer(p, footX, footY, scale,
            f < 60 and "right" or "down", 1, paletteColors)
        elseif f < 40 then
          drawLivePlayer(p, riderX, riderY, riderScale, "left", 1,
            paletteColors)
        elseif f < 60 then
          local groundRiderX, groundRiderY, groundRiderScale =
            riderPose(baseMonX, baseMonY, profile, scale, 0)
          drawLivePlayer(p, lerp(groundRiderX, footX, dismount),
            lerp(groundRiderY, footY, dismount)
              - math.sin(dismount * math.pi) * 14 * scale,
            lerp(groundRiderScale, scale, dismount),
            dismount < 0.78 and "left" or "down", 1, paletteColors)
        else
          drawLivePlayer(p, footX, footY, scale,
            f < 95 and "right" or "down", 1, paletteColors)
        end

        local row = f < 35 and ROW_LEFT or ROW_DOWN
        local col = f < 35 and cycleColumn(f, profile.winged and 6 or 8) or 0
        local bodyAlpha = 1 - recall
        local tint = recall > 0 and { 1, 0.72, 0.62 } or nil
        drawPokemon(shot.image, row, col, monX, monY,
          monScale, bodyAlpha, tint)
        if profile.departureMode == "balloon_rig" and bodyAlpha > 0 then
          if f < 40 then
            drawBalloonTowBand(monX, monY, riderX, riderY, scale,
              bodyAlpha * arrive)
          end
          local harnessAlpha = bodyAlpha
            * (1 - smooth((f - 60) / 18))
          drawBalloonHarness(monX, monY, scale, harnessAlpha)
        end

        if f >= 68 then
          local handX, handY = footX + 3 * scale, footY - 14 * scale
          local impactX, impactY = baseMonX - 8 * scale,
            baseMonY - 18 * scale
          local ballX = lerp(handX, impactX, throw)
          local ballY = lerp(handY, impactY, throw)
            - arcHeight(throw) * 9 * scale
          if f >= 88 then
            ballX = lerp(impactX, handX, ballReturn)
            ballY = lerp(impactY, handY, ballReturn)
              - arcHeight(ballReturn) * 7 * scale
          end
          if recall > 0 and f < 89 then
            drawRecallPixels(impactX, impactY, baseMonX,
              baseMonY - 16 * scale, scale, recall)
          end
          drawBall(ballX, ballY, scale, 1)
        end
        end
      end
    end)

    love.graphics.pop()
    if not ok then error(drawError, 0) end
    return playerDrawn
  end

  -- Keep Gen1Recomp's native `action="fly"` branch as the sole owner of
  -- Badge and outside-map legality. The submenu hook remembers only which
  -- party member owns that exact row. A TownMap is accepted only after the
  -- native PartyMenu has popped itself and pushed its fly-mode map; cancelling
  -- or refusing FLY therefore never arms a later flight.
  local partyFlySelectionByGame = setmetatable({}, { __mode = "k" })
  local partyFlyBridge
  do
    local unpackValues = table.unpack or unpack
    local function packValues(...)
      return { n = select("#", ...), ... }
    end

    partyFlyBridge = Screens.__vascSpeciesFlyPartyBridge
    if not partyFlyBridge then
      partyFlyBridge = { original = Screens.push }
      Screens.__vascSpeciesFlyPartyBridge = partyFlyBridge
      Screens.push = function(game, screenId, ...)
        local provider = partyFlyBridge.provider
        local selection = provider and provider.takeSelection(
          game, screenId, select(1, ...)) or nil
        local screen = partyFlyBridge.original(game, screenId, ...)
        provider = partyFlyBridge.provider
        if provider and selection then
          provider.wrapTownMap(game, screen, selection)
        end
        return screen
      end
    end

    local previousProvider = partyFlyBridge.provider
    if previousProvider and previousProvider.cleanup then
      pcall(previousProvider.cleanup)
    end
    partyFlyBridge.provider = {
      takeSelection = function(game, screenId, opts)
        if type(game) ~= "table" then return nil end
        local selection = partyFlySelectionByGame[game]
        partyFlySelectionByGame[game] = nil
        if not selection or screenId ~= "TownMap"
            or type(opts) ~= "table" or opts.fly ~= true then
          return nil
        end
        local menu, row = selection.menu, selection.row
        local current = type(menu) == "table"
          and type(menu.subItems) == "table"
          and menu.subItems[menu.subIndex] or nil
        if menu.game ~= game or current ~= row or row.action ~= "fly" then
          return nil
        end
        local stack = game.stack
        if stack and type(stack.top) == "function" and stack:top() == menu then
          return nil
        end
        return selection
      end,
      wrapTownMap = function(game, townMap, selection)
        if not (type(townMap) == "table"
            and townMap.screenId == "TownMap" and townMap.fly == true
            and type(townMap.onFly) == "function") then return false end
        if townMap.__vascSpeciesFlyPartySelection then return true end
        townMap.__vascSpeciesFlyPartySelection = true
        local originalOnFly = townMap.onFly
        local selected = selection.mon
        townMap.onFly = function(mapId, ...)
          local ow = game and game.overworld
          local provider = partyFlyBridge.provider
          if ow and provider then provider.arm(ow, selected) end
          local results = packValues(pcall(originalOnFly, mapId, ...))
          provider = partyFlyBridge.provider
          if ow and provider then provider.clear(ow, selected) end
          if not results[1] then error(results[2], 0) end
          return unpackValues(results, 2, results.n)
        end
        return true
      end,
      arm = function(ow, mon)
        if type(ow) == "table" and type(mon) == "table" then
          pendingByWorld[ow] = mon
        end
      end,
      clear = function(ow, mon)
        if pendingByWorld[ow] == mon then pendingByWorld[ow] = nil end
      end,
      cleanup = function()
        for game in pairs(partyFlySelectionByGame) do
          partyFlySelectionByGame[game] = nil
        end
      end,
    }
  end

  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(game) == "table" then partyFlySelectionByGame[game] = nil end
    if type(out) ~= "table" or (ctx and ctx.battle)
        or type(game) ~= "table" then return out end
    local stack = game.stack
    local menu = stack and type(stack.top) == "function" and stack:top() or nil
    if type(menu) ~= "table" then return out end
    for _, item in ipairs(out) do
      if type(item) == "table" and item.action == "fly" then
        partyFlySelectionByGame[game] = {
          mon = mon,
          menu = menu,
          row = item,
        }
        break
      end
    end
    return out
  end)

  -- Kanto Ascendant deliberately exposes its FIELD KIT controller. Bridge
  -- those public entry points instead of guessing from a flyTo() call stack:
  -- the concrete TownMap instance is tagged only after FIELD KIT chose FLY,
  -- and its onFly is wrapped only after the player confirms a destination.
  local fieldKitBridge
  do
    local fieldTech = KantoAscendantCompat.fieldTech(mod)
    if type(fieldTech) == "table" and type(fieldTech.open) == "function"
        and type(fieldTech.activate) == "function"
        and type(fieldTech.useFieldMove) == "function" then
      local unpackValues = table.unpack or unpack
      local function packValues(...)
        return { n = select("#", ...), ... }
      end

      fieldKitBridge = fieldTech.__vascSpeciesFlyFieldKitBridge
      if not fieldKitBridge then
        fieldKitBridge = {
          open = fieldTech.open,
          activate = fieldTech.activate,
          useFieldMove = fieldTech.useFieldMove,
        }
        fieldTech.__vascSpeciesFlyFieldKitBridge = fieldKitBridge

        fieldTech.open = function(game, ...)
          local results = packValues(fieldKitBridge.open(game, ...))
          local provider = fieldKitBridge.provider
          if provider then provider.wrapFieldKitMenu(game) end
          return unpackValues(results, 1, results.n)
        end
        fieldTech.activate = function(game, moveId, ...)
          local results = packValues(fieldKitBridge.activate(game, moveId, ...))
          local provider = fieldKitBridge.provider
          if provider and moveId == "FLY" and results[1] == true then
            provider.wrapTownMap(game)
          end
          return unpackValues(results, 1, results.n)
        end
        fieldTech.useFieldMove = function(game, moveId, ...)
          local results = packValues(
            fieldKitBridge.useFieldMove(game, moveId, ...))
          local provider = fieldKitBridge.provider
          if provider and moveId == "FLY" and results[1] == true then
            provider.wrapTownMap(game)
          end
          return unpackValues(results, 1, results.n)
        end
      end

      local function wrapTownMap(game)
        local stack = game and game.stack
        local townMap = stack and type(stack.top) == "function"
          and stack:top() or nil
        if not (type(townMap) == "table" and townMap.screenId == "TownMap"
            and townMap.fly == true and type(townMap.onFly) == "function") then
          return false
        end
        if townMap.__vascSpeciesFlyFieldKit then return true end
        townMap.__vascSpeciesFlyFieldKit = true
        local originalOnFly = townMap.onFly
        townMap.onFly = function(mapId, ...)
          local ow = game and game.overworld
          local provider = fieldKitBridge.provider
          if ow and provider then provider.arm(ow) end
          local results = packValues(pcall(originalOnFly, mapId, ...))
          if ow and provider then provider.clear(ow) end
          if not results[1] then error(results[2], 0) end
          return unpackValues(results, 2, results.n)
        end
        return true
      end

      fieldKitBridge.provider = {
        arm = function(ow) fieldKitByWorld[ow] = true end,
        clear = function(ow)
          if fieldKitByWorld[ow] then fieldKitByWorld[ow] = nil end
        end,
        wrapTownMap = wrapTownMap,
        wrapFieldKitMenu = function(game)
          local stack = game and game.stack
          local menu = stack and type(stack.top) == "function"
            and stack:top() or nil
          if not (type(menu) == "table" and type(menu.items) == "table"
              and type(menu.onChoose) == "function") then return false end
          local hasFly = false
          for _, item in ipairs(menu.items) do
            if item and item.toolId == "FIELD:FLY" then
              hasFly = true
              break
            end
          end
          if not hasFly then return false end
          if menu.__vascSpeciesFlyFieldKitMenu then return true end
          menu.__vascSpeciesFlyFieldKitMenu = true
          local originalChoose = menu.onChoose
          menu.onChoose = function(item, ...)
            local results = packValues(originalChoose(item, ...))
            if item and item.value == "FLY" then wrapTownMap(game) end
            return unpackValues(results, 1, results.n)
          end
          return true
        end,
      }
    end
  end

  -- A hot-reload-safe class bridge: only one wrapper is installed, while its
  -- current provider is replaced when this mod is reloaded.
  local bridge = OverworldState.__vascSpeciesFlyBridge
  if not bridge then
    bridge = { original = OverworldState.flyTo, scheduleAware = true }
    OverworldState.__vascSpeciesFlyBridge = bridge
    OverworldState.flyTo = function(self, mapId)
      local provider = bridge.provider
      local mon = provider and provider.takePending(self) or nil
      bridge.original(self, mapId)
      if provider and mon then provider.schedule(self, mon) end
    end
  end
  local previousProvider = bridge.provider
  if previousProvider and previousProvider.cleanup then
    -- F5 hot reload re-runs this chunk while keeping the current world and
    -- player object alive. Release an old landing input lock (or a held
    -- departure) before its weak state table becomes unreachable.
    pcall(previousProvider.cleanup)
  end
  bridge.provider = {
    takePending = function(ow)
      local mon = pendingByWorld[ow]
      pendingByWorld[ow] = nil
      local fieldKit = fieldKitByWorld[ow]
      fieldKitByWorld[ow] = nil
      if not voxelActive() then
        waitingForNativeByWorld[ow] = nil
        return nil
      end
      mon = mon or (fieldKit and FIELD_KIT_JETPACK) or firstFlyUser()
      -- An older VASC flyTo bridge can survive an F5 reload and still invoke
      -- `begin` only when flyAnim exists immediately. Stage before the engine
      -- call only for that legacy wrapper; the schedule-aware wrapper below
      -- validates native acceptance after flyTo returns.
      if bridge.scheduleAware ~= true then
        waitingForNativeByWorld[ow] = mon
      end
      return mon
    end,
    begin = function(ow, mon)
      waitingForNativeByWorld[ow] = nil
      return beginDeparture(ow, mon)
    end,
    schedule = function(ow, mon)
      waitingForNativeByWorld[ow] = nil
      if not mon then return false end
      if ow.flyAnim then return beginDeparture(ow, mon) end
      -- Gen1Recomp 0.2.32 begins FLY with StopMusic/flyFade and creates the
      -- native flyAnim only from a later Overworld update. Keep the exact
      -- selected Pokemon across that engine-owned lead-in; an invalid
      -- destination creates none of these states and therefore cannot leave
      -- a request armed for a later flight.
      if ow.flyFade or ow.flyDest then
        waitingForNativeByWorld[ow] = mon
        return true
      end
      return false
    end,
    cleanup = function()
      local worlds = {}
      for ow in pairs(activeByWorld) do worlds[#worlds + 1] = ow end
      for ow in pairs(waitingForNativeByWorld) do
        waitingForNativeByWorld[ow] = nil
      end
      for _, ow in ipairs(worlds) do abort(ow) end
    end,
  }

  -- The native controller counts FLY on fixed logic steps. Fast-forward may
  -- execute dozens of those steps between two rendered frames, so keep its
  -- transition at one remaining tick while the visible departure is active.
  -- Like the flyTo bridge, this wrapper is installed only once and receives
  -- the newest provider after a hot reload.
  local updateBridge = OverworldState.__vascSpeciesFlyUpdateBridge
  if not updateBridge then
    updateBridge = { original = OverworldState.update }
    OverworldState.__vascSpeciesFlyUpdateBridge = updateBridge
    local unpackValues = table.unpack or unpack
    local function packValues(...)
      return { n = select("#", ...), ... }
    end
    OverworldState.update = function(self, ...)
      local provider = updateBridge.provider
      if provider then provider.beforeNativeUpdate(self) end

      local heldAnim, heldPhase, heldT
      if provider and provider.holdDeparture(self)
          and type(self.flyAnim) == "table" then
        heldAnim = self.flyAnim
        if tonumber(heldAnim.frames) then
          heldAnim.frames = 2
        elseif heldAnim.phase ~= nil and tonumber(heldAnim.t) then
          -- The supported phase/t controller has no numeric countdown.
          -- Run its update against an inert negative flap timer, then restore
          -- the exact presentation state so even 100 fixed ticks cannot burn
          -- through the departure between two rendered frames.
          heldPhase, heldT = heldAnim.phase, heldAnim.t
          heldAnim.phase, heldAnim.t = "flap", -1000000000
        end
      end
      local hadFlyAnim = self.flyAnim ~= nil
      local results = packValues(pcall(updateBridge.original, self, ...))
      if heldAnim and self.flyAnim == heldAnim and heldPhase ~= nil then
        heldAnim.phase, heldAnim.t = heldPhase, heldT
      end
      if not results[1] then
        -- The hold above temporarily edits the native controller. Restore a
        -- controller an exceptional engine tick may already have detached,
        -- then fail open before propagating the engine-owned error.
        if heldAnim and self.flyAnim == nil then self.flyAnim = heldAnim end
        if provider then provider.abort(self) end
        error(results[2], 0)
      end
      if provider and hadFlyAnim and self.flyAnim == nil then
        provider.markNativeWarp(self)
      end
      if provider then provider.afterNativeUpdate(self) end
      return unpackValues(results, 2, results.n)
    end
  end
  updateBridge.provider = {
    abort = abort,
    holdDeparture = function(ow)
      local shot = activeByWorld[ow]
      return shot and shot.phase == "departure"
        and shot.departureDone ~= true
    end,
    beforeNativeUpdate = function(ow)
      local shot = activeByWorld[ow]
      if not shot then return end
      -- Pipelines.level() stays non-zero after Gen1Recomp marks VASC broken.
      -- Since a broken pipeline can no longer tick updateShot's ten-second
      -- watchdog, release every native hold/input lock from the always-live
      -- Overworld update instead.
      if not voxelActive() then
        abort(ow)
        return
      end
      if shot.nativeWarpStarted and ow.flyArrive then
        -- At high speed Transition and its midpoint can complete before the
        -- render pipeline runs. Consume the native arrival on the first
        -- subsequent Overworld tick, before it can unlock or draw its bird.
        shot.consumedNativeArrival = true
        ow.flyArrive = nil
        ow.playerHidden = false
      end
      if (shot.ownsTravelLock or shot.ownsLandingLock) and ow.player then
        ow.player.inputLocked = true
      end
    end,
    markNativeWarp = function(ow)
      local shot = activeByWorld[ow]
      if shot and shot.phase == "departure" then
        shot.nativeWarpStarted = true
        if ow.player and not shot.ownsTravelLock then
          -- Native FLY unlocks the player immediately before it pushes the
          -- Transition. At high speed that Transition can also finish in the
          -- same display frame, leaving several movement ticks before the
          -- render pipeline gets a turn. Re-lock at this exact logic boundary
          -- and hand ownership to the landing cinematic later.
          shot.lockPlayer = ow.player
          ow.player.inputLocked = true
          shot.ownsTravelLock = true
        end
      end
    end,
    afterNativeUpdate = function(ow)
      local waiting = waitingForNativeByWorld[ow]
      if waiting then
        if ow.flyAnim then
          waitingForNativeByWorld[ow] = nil
          -- The renderer may have been disabled or retired during the native
          -- music fade. Revalidate at the ownership boundary and otherwise
          -- leave the just-created native bird completely untouched.
          if voxelActive() then beginDeparture(ow, waiting) end
        elseif not ow.flyFade and not ow.flyDest then
          -- A native controller that declined/cancelled the request must not
          -- donate this Pokemon to some later unrelated programmatic FLY.
          waitingForNativeByWorld[ow] = nil
        end
      end
      local shot = activeByWorld[ow]
      if shot and (shot.ownsTravelLock or shot.ownsLandingLock)
          and ow.player then
        ow.player.inputLocked = true
      end
    end,
  }

  local registry = mod.content and mod.content.render_pipelines
  local voxel = registry and registry:get(PIPELINE_ID)
  if type(voxel) ~= "table" or type(voxel.drawWorld) ~= "function" then
    bridge.provider = nil
    updateBridge.provider = nil
    if fieldKitBridge then fieldKitBridge.provider = nil end
    mod.log:error("VASC-Pipeline 'voxel' nicht gefunden")
    return false, "voxel-pipeline-unavailable"
  end

  local baseUpdate = voxel.update
  local baseDrawWorld = voxel.drawWorld
  registry:patch(PIPELINE_ID, {
    update = function(dt, level)
      voxelLevel = tonumber(level) or 0
      local ow = Game and Game.overworld
      if baseUpdate then
        local ok, updateError = pcall(baseUpdate, dt, level)
        if not ok then
          if ow then abort(ow) end
          error(updateError, 0)
        end
      end
      if ow then
        local ok, updateError = pcall(updateShot, ow, dt)
        if not ok then
          abort(ow)
          safeLog("error", "Fly-Cinematic-Update fehlgeschlagen: %s",
            tostring(updateError))
        end
      end
    end,

    drawWorld = function(ctx)
      local ow = ctx and ctx.state
      local shot = ow and activeByWorld[ow]
      if not shot then return baseDrawWorld(ctx) end

      local realFlyAnim = ow.flyAnim
      local realFlyArrive = ow.flyArrive
      -- Keep VASC from drawing the ordinary standing player during the
      -- covered travel/fade as well as during landing. The overlay wrapper
      -- removes this synthetic marker before native field FX are evaluated,
      -- so it never resurrects the generic bird.
      local synthetic = shot.phase ~= "departure" and realFlyAnim == nil
      if synthetic then
        ow.flyAnim = { frames = DEPARTURE_FRAMES, cinematicOnly = true }
      end

      local originalDrawFx = ctx.drawFx
      local callbackInvoked = false
      local customDrawClaimed = false
      local customDrawFailed = false
      ctx.drawFx = function(project, displayScale)
        callbackInvoked = true
        local held, heldArrive = ow.flyAnim, ow.flyArrive
        -- Suppress both generations of Gen1Recomp's generic bird state. The
        -- custom cinematic owns departure as well as destination arrival.
        ow.flyAnim, ow.flyArrive = nil, nil
        local okNative, nativeError = pcall(originalDrawFx, project, displayScale)
        ow.flyAnim, ow.flyArrive = held, heldArrive
        if not okNative then error(nativeError, 0) end
        local okCustom, result = pcall(drawCinematic, ow, project,
          displayScale, ctx)
        if not okCustom then
          customDrawFailed = true
          evictImage(shot.rel, shot.image)
          abort(ow)
          safeLog("error",
            "Fly-Cinematic-Zeichnung für %s fehlgeschlagen: %s",
            tostring(shot.rel or shot.mon and shot.mon.species or "FIELD KIT"),
            tostring(result))
        else
          customDrawClaimed = result == true
        end
      end

      local ok, canvas = pcall(baseDrawWorld, ctx)
      ctx.drawFx = originalDrawFx
      ow.flyAnim = realFlyAnim
      ow.flyArrive = realFlyArrive
      if not ok then
        abort(ow)
        error(canvas, 0)
      end
      local needsCustomClaim = shot.phase == "departure"
        or shot.phase == "landing"
      if canvas ~= nil and needsCustomClaim and not customDrawClaimed then
        shot.drawFailOpenFrames = (shot.drawFailOpenFrames or 0) + 1
        if not customDrawFailed and shot.drawFailOpenFrames == 1 then
          safeLog("warn",
            "vasc.gen1.fly.draw-claim-fail-open/v1 reason=%s action=native-2d-frame-retry",
            callbackInvoked and "live-player-unavailable"
              or "overlay-callback-not-invoked")
        end
        return nil
      end
      if canvas ~= nil and customDrawClaimed then
        shot.drawFailOpenFrames = 0
        shot.renderedSinceUpdate = true
      end
      return canvas
    end,
  })

  mod.exports.speciesCinematics = mod.exports.speciesCinematics or {
    apiVersion = 1,
  }
  local public = {
    active = true,
    version = SpeciesFlyCinematic.VERSION,
    abort = abort,
  }
  public.status = function(ow)
    local shot = ow and activeByWorld[ow]
    return shot and { phase = shot.phase, frame = shot.frame,
                      species = shot.mon and shot.mon.species,
                      mode = shot.profile and shot.profile.departureMode }
      or nil
  end
  mod.exports.speciesCinematics.fly = public
  installed = true
  mod.log:info("VASC Species Fly Cinematic für Pokémon %s geladen", edition)
  return true, public
end

return SpeciesFlyCinematic
