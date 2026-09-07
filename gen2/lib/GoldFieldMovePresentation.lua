-- Gold/Silver/Crystal field-move presentation for the voxel renderer.
--
-- Gen2Recomp remains the sole owner of SURF/FLY eligibility, state, movement,
-- music, callbacks and warps.  This module observes the successful native
-- calls, remembers the exact user only for the lifetime of that World, and
-- decorates GoldVoxelBridge's ephemeral render state.  No save or engine
-- object is rewritten.
local V = ...

local M = {
  installed = false,
  lastError = nil,
  surfFrames = 0,
  flyFrames = 0,
  fieldKitFrames = 0,
  fieldKitFlyFrames = 0,
  nativeFlyDrawsSuppressed = 0,
}

local unpackValues = table.unpack or unpack
local bridge
local GoldFlyCinematic
local lastFlyCinematicWarning
local rendererCache = setmetatable({}, { __mode = "k" })

local OPTION_KEYS = {
  surf = "speciesSurfPresentation",
  fieldKit = "fieldKitPresentation",
  fly = "speciesFlyPresentation",
}
local OPTION_DEFAULTS = {
  speciesSurfPresentation = "vasc",
  fieldKitPresentation = false,
  speciesFlyPresentation = "vasc",
}

local function pack(...)
  return { n = select("#", ...), ... }
end

local function safeWarn(fmt, ...)
  local log = V and V.mod and V.mod.log
  if log and type(log.warn) == "function" then
    pcall(log.warn, log, fmt, ...)
  end
end

-- Species Surf and Fly keep the established VASC replacement by default;
-- Field Kit/Jetski is the one opt-in presentation. Keeping the defaults beside
-- the runtime gate makes older launchers deterministic before option rows are
-- published and lets later option changes apply without rewrapping World.
local function optionEnabled(key)
  local default = OPTION_DEFAULTS[key]
  local fallback = default == true or default == "vasc"
  local options = V and V.mod and V.mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  if value == "vanilla" or value == "off" or value == false or value == 0
      or value == "0" or value == "false" then return false end
  return value == "vasc" or value == true or value == 1 or value == "1"
    or value == "true" or value == "on"
end

local function configured()
  return {
    speciesSurfPresentation = optionEnabled(OPTION_KEYS.surf),
    fieldKitPresentation = optionEnabled(OPTION_KEYS.fieldKit),
    speciesFlyPresentation = optionEnabled(OPTION_KEYS.fly),
  }
end

local function voxelEnabled()
  return optionEnabled("voxel3d")
end

local function clearSurf(world)
  if bridge and bridge.surf then bridge.surf[world] = nil end
  rendererCache[world] = nil
end

local function clearFly(world)
  if bridge and bridge.fly then bridge.fly[world] = nil end
end

local function shiny(mon)
  if type(mon) ~= "table" then return false end
  if mon.shiny == true or mon.isShiny == true then return true end
  local okStats, Stats = pcall(require, "src.pokemon.Stats")
  if okStats and Stats and type(Stats.isShiny) == "function" then
    local ok, value = pcall(Stats.isShiny, mon.dvs)
    if ok then return value == true end
  end
  return false
end

local function pokemonDef(world, mon)
  local species = type(mon) == "table" and mon.species or nil
  local data = world and world.game and world.game.data
  return species and data and data.pokemon and data.pokemon[species] or nil
end

local function dexFor(world, mon)
  local def = pokemonDef(world, mon)
  if type(def) ~= "table" then return nil end
  local value = def.sourceDex or def.nationalDex or def.dexNumber
    or def.dex or def.number or def.index
  local dex = tonumber(value)
  if not dex or dex ~= math.floor(dex) or dex < 1 or dex > 386 then return nil end
  return dex
end

local function imagePath(rel)
  local assets = V and V.mod and V.mod.assets
  if assets and type(assets.path) == "function" then
    local ok, path = pcall(assets.path, assets, rel)
    if ok and type(path) == "string" then return path end
  end
  return rel
end

local function loadExactImage(g, rel)
  local path = imagePath(rel)
  -- Absolute/symlinked RC paths are not consistently resolved by every LOVE
  -- host.  Decode uniquely named FileData first so one species can never
  -- inherit a previously decoded atlas through the host path cache.
  local file = io and io.open and io.open(path, "rb") or nil
  if file and love and love.filesystem
      and type(love.filesystem.newFileData) == "function" then
    local bytes = file:read("*a")
    file:close()
    local safeName = rel:gsub("[^%w%._%-]", "_")
    local okData, data = pcall(love.filesystem.newFileData, bytes, safeName)
    if okData and data then
      local okImage, image = pcall(g.newImage, data)
      if okImage and image then return image, path end
    end
  elseif file then
    file:close()
  end
  local okImage, image = pcall(g.newImage, path)
  if okImage and image then return image, path end
  return nil, path
end

local function newCanvas(w, h)
  local g = love and love.graphics
  if not (g and type(g.newCanvas) == "function") then return nil end
  local ok, canvas = pcall(g.newCanvas, w, h, { dpiscale = 1 })
  if not ok then ok, canvas = pcall(g.newCanvas, w, h) end
  if not (ok and canvas) then return nil end
  if type(canvas.setFilter) == "function" then canvas:setFilter("nearest", "nearest") end
  return canvas
end

local function normalTrainerRenderer(world)
  if not (world and world.player and world.sprites) then return nil end
  local okMoves, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  if not okMoves then return nil end
  local gender
  if type(world.playerGender) == "function" then
    local ok, value = pcall(world.playerGender, world)
    if ok then gender = value end
  end
  local name = type(FieldMoves.playerSprite) == "function"
    and FieldMoves.playerSprite(gender) or nil
  local def = name and world.sprites[name] or nil
  if not (def and type(def.image) == "string") then return nil end

  local okRenderer, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
  if not (okRenderer and SpriteRenderer and type(SpriteRenderer.new) == "function") then
    return nil
  end
  local okNew, renderer = pcall(SpriteRenderer.new, def, "vasc-gen2-surf")
  if not (okNew and renderer) then return nil end
  if type(world.applySpritePalette) == "function" then
    pcall(world.applySpritePalette, world, {
      sprite = renderer, spriteDef = def,
    })
  end
  return renderer
end

local COMPOSITE_CELL = 64
local COMPOSITE_HEIGHT = COMPOSITE_CELL * 6
local POSE_DIRECTION = {
  [0] = "down", [1] = "up", [2] = "left",
  [3] = "down", [4] = "up", [5] = "left",
}
-- Gen2's six-frame walker contract authors LEFT once and mirrors that frame
-- for RIGHT in VoxelScene.frameFor. drawJetski therefore has four visible
-- headings even though only three source headings occupy the vertical sheet.
local ATLAS_ROW = { down = 0, left = 1, right = 2, up = 3 }

local function compositePose(frame)
  frame = math.max(0, math.min(5, math.floor(tonumber(frame) or 0)))
  local direction = POSE_DIRECTION[frame]
  return direction, ATLAS_ROW[direction] or 0, frame % 3
end

function M._compositePoseForTests(frame)
  return compositePose(frame)
end

local function setColor(g, r, gg, b, a)
  g.setColor(r, gg, b, a == nil and 1 or a)
end

local function drawJetski(g, y, direction, moving)
  local side = direction == "left" or direction == "right"
  setColor(g, 0.78, 0.94, 1, 0.74)
  if side then
    g.rectangle("fill", moving and 0 or 2, y + 13.25,
      moving and 16 or 12, moving and 0.75 or 0.5)
    setColor(g, 0.03, 0.16, 0.25, 1)
    g.rectangle("fill", 1, y + 9, 14, 3.75)
    g.rectangle("fill", 1, y + 7.5, 4.5, 2.25)
    g.rectangle("fill", 5, y + 12.5, 8.5, 1)
    setColor(g, 0.12, 0.61, 0.78, 1)
    g.rectangle("fill", 1.75, y + 9, 11.75, 0.75)
    setColor(g, 0.91, 0.20, 0.16, 1)
    g.rectangle("fill", 4.25, y + 11.25, 7.5, 0.5)
    setColor(g, 0.05, 0.08, 0.11, 1)
    g.rectangle("fill", 7, y + 7, 6, 1.75)
    g.rectangle("fill", 5, y + 5.25, 0.75, 3.75)
    g.rectangle("fill", 3.5, y + 5, 3.25, 0.5)
  else
    local wakeY = direction == "up" and y + 14 or y + 4
    g.rectangle("fill", moving and 5 or 6, wakeY, moving and 6 or 4, 0.75)
    setColor(g, 0.03, 0.16, 0.25, 1)
    g.rectangle("fill", 5, y + 7, 6, 6.5)
    g.rectangle("fill", 4, y + 9.5, 8, 3.25)
    g.rectangle("fill", 5.75, y + 6.25, 4.5, 1.5)
    setColor(g, 0.12, 0.61, 0.78, 1)
    g.rectangle("fill", 5.5, y + 8, 5, 4.5)
    setColor(g, 0.91, 0.20, 0.16, 1)
    g.rectangle("fill", 4.75, y + 11.25, 6.5, 0.6)
    setColor(g, 0.05, 0.08, 0.11, 1)
    g.rectangle("fill", 7.625, y + 5.25, 0.75, 3.25)
    g.rectangle("fill", 5.5, y + 5, 5, 0.5)
  end
end

-- Compact trainer jetpack authored in the same 16px composite card as the
-- Gen-2 player.  It is deliberately presentation-only: the native Fly state,
-- warp and callbacks still come from World:startFlyAnim/World:flyTo.
local function drawJetpack(g, y, direction, moving)
  local side = direction == "left" or direction == "right"
  local pulse = moving and 1 or 0
  local function tank(tankX, width)
    setColor(g, 0.04, 0.08, 0.12, 1)
    g.rectangle("fill", tankX, y + 3.5, width, 8.5)
    setColor(g, 0.66, 0.76, 0.82, 1)
    g.rectangle("fill", tankX + 0.5, y + 4, width - 1, 6.25)
    setColor(g, 0.14, 0.42, 0.63, 1)
    g.rectangle("fill", tankX + 0.75, y + 5, width - 1.5, 3.75)
    setColor(g, 0.94, 0.31, 0.06, 1)
    g.rectangle("fill", tankX + 0.5, y + 10, width - 1, 2)
    setColor(g, 1.00, 0.78, 0.12, 0.98)
    g.rectangle("fill", tankX + 0.75, y + 12,
      math.max(1, width - 1.5), 2.5 + pulse)
    setColor(g, 0.72, 0.90, 1.00, 0.92)
    g.rectangle("fill", tankX + 1, y + 14 + pulse,
      math.max(0.75, width - 2), 1.5)
  end
  if side then
    tank(direction == "left" and 11.25 or 1.75, 3.25)
  else
    tank(1.25, 3.25)
    tank(11.5, 3.25)
    setColor(g, 0.04, 0.08, 0.12, 1)
    g.rectangle("fill", 4, y + 6.25, 8, 1)
    g.rectangle("fill", 4, y + 9.5, 8, 1)
  end
end

-- The composite canvas is four times denser than its eventual 16x16 world
-- billboard. Values here are therefore logical Gen-2 pixels, not canvas
-- pixels. In particular, a 0.54 FLY rider becomes only 8.64 world pixels tall
-- beside 16px NPC cards. Keep both rider and mount inside one bounded card,
-- but author the rider at the same physical height as every nearby trainer.
local function actorLayout(kind, fieldKit, direction)
  if fieldKit then
    if kind == "fly" then
      return {
        monTarget = 0,
        trainerScale = 0.82,
        trainerX = direction == "left" and 1.2 or 3.0,
        trainerYOffset = 0.25,
      }
    end
    return {
      monTarget = 0,
      trainerScale = 0.72,
      trainerX = direction == "left" and 2.2 or 4.3,
      trainerYOffset = 1,
    }
  end
  if kind == "fly" then
    return {
      monTarget = 16,
      trainerScale = 0.58,
      trainerX = direction == "left" and 5.6 or 5.2,
      trainerYOffset = 3.2,
    }
  end
  return {
    monTarget = 14.5,
    trainerScale = 0.64,
    trainerX = 5.3,
    trainerYOffset = 1.5,
  }
end

function M._actorLayoutForTests(kind, fieldKit, direction)
  return actorLayout(kind == "fly" and "fly" or "surf",
    fieldKit == true, direction or "down")
end

local function buildActorRenderer(world, mon, fieldKit, kind)
  local g = love and love.graphics
  if not (g and g.draw and g.newQuad and g.push and g.pop and g.setCanvas
      and g.clear and g.origin and g.scale and g.rectangle) then
    return nil, "graphics unavailable"
  end
  local trainer = normalTrainerRenderer(world)
  if not (trainer and trainer.def and trainer.frames
      and type(trainer.resolveImage) == "function") then
    return nil, "normal Gen-2 trainer renderer unavailable"
  end
  local okTrainer, trainerImage = pcall(trainer.resolveImage, trainer)
  if not (okTrainer and trainerImage) then return nil, "trainer image unavailable" end

  local monImage, monCell, monW, monH, monSourcePath
  if not fieldKit then
    local dex = dexFor(world, mon)
    if not dex then return nil, "exact field actor has no artwork dex" end
    local rel = string.format("assets/species_cinematics/directional/%03d-%s.png",
      dex, shiny(mon) and "shiny" or "normal")
    local image, loadedPath = loadExactImage(g, rel)
    if not (image and type(image.getDimensions) == "function") then
      return nil, "directional field-actor artwork unavailable"
    end
    if type(image.setFilter) == "function" then image:setFilter("nearest", "nearest") end
    monW, monH = image:getDimensions()
    if monW ~= monH or monW % 4 ~= 0 then return nil, "invalid field-actor atlas" end
    monImage, monCell, monSourcePath = image, monW / 4, loadedPath
  end

  local canvas = newCanvas(COMPOSITE_CELL, COMPOSITE_HEIGHT)
  if not canvas then return nil, "field-actor composite canvas unavailable" end
  local oldCanvas = type(g.getCanvas) == "function" and g.getCanvas() or nil
  local pushed = false
  local ok, err = pcall(function()
    g.push("all")
    pushed = true
    g.setCanvas(canvas)
    if g.setScissor then g.setScissor() end
    g.clear(0, 0, 0, 0)
    if g.setShader then g.setShader() end
    if g.setBlendMode then g.setBlendMode("alpha") end
    g.origin()
    g.scale(COMPOSITE_CELL / 16, COMPOSITE_CELL / 16)

    for frame = 0, 5 do
      local y = frame * 16
      local direction, row, trainerStand = compositePose(frame)
      local moving = frame >= 3
      local layout = actorLayout(kind, fieldKit, direction)
      local trainerFrame = trainer.frames[trainerStand] or trainer.frames[0]
      local function drawTrainer()
        if trainerFrame then
          setColor(g, 1, 1, 1, 1)
          g.draw(trainerImage, trainerFrame,
            layout.trainerX, y + layout.trainerYOffset, 0,
            layout.trainerScale, layout.trainerScale)
        end
      end
      if g.setScissor then
        g.setScissor(0, frame * COMPOSITE_CELL,
          COMPOSITE_CELL, COMPOSITE_CELL)
      end

      if fieldKit then
        if kind == "fly" then
          drawJetpack(g, y, direction, moving)
        else
          drawJetski(g, y, direction, moving)
        end
      else
        -- While surfing, the trainer is the rear rider and the Pokemon is
        -- the foreground mount/tow partner. Fly keeps its established order.
        if kind ~= "fly" then drawTrainer() end
        if kind ~= "fly" then
          setColor(g, 0.80, 0.95, 1, 0.72)
          g.rectangle("fill", moving and 0 or 2, y + 13.25,
            moving and 16 or 12, moving and 0.75 or 0.5)
        end
        local column = moving and 1 or 0
        local quad = g.newQuad(column * monCell, row * monCell,
          monCell, monCell, monW, monH)
        local target = layout.monTarget
        setColor(g, 1, 1, 1, 1)
        local actorY = kind == "fly" and (y + 14.5 - target)
          or (y + 15 - target)
        g.draw(monImage, quad, 8 - target / 2, actorY,
          0, target / monCell, target / monCell)
      end

      -- Water/mount motion lives in the composite. The trainer stays on the
      -- directional standing pose instead of walking in place while surfing.
      if fieldKit or kind == "fly" then drawTrainer() end
    end
    if g.setScissor then g.setScissor() end
  end)

  if oldCanvas then pcall(g.setCanvas, oldCanvas) else pcall(g.setCanvas) end
  if pushed then pcall(g.pop) end
  if not ok then return nil, tostring(err) end

  local renderer = {
    def = {
      image = trainer.def.image,
      frames = 6,
      walker = true,
      trueColor = true,
      sourceAtlas = monSourcePath,
      id = fieldKit and (kind == "fly" and "VASC_GEN2_FIELD_KIT_JETPACK"
          or "VASC_GEN2_FIELD_KIT_JETSKI")
        or (kind == "fly" and "VASC_GEN2_SPECIES_FLY_"
          or "VASC_GEN2_SPECIES_SURF_") .. tostring(mon.species),
    },
    image = canvas,
  }
  function renderer:resolveImage() return self.image end
  return renderer
end

local function actorRenderer(world, mon, fieldKit, kind)
  if type(M._rendererFactoryForTests) == "function" then
    return M._rendererFactoryForTests(world, mon, fieldKit, kind)
  end
  kind = kind == "fly" and "fly" or "surf"
  local key = kind .. ":" .. (fieldKit and "FIELD_KIT"
    or (tostring(mon and mon.species) .. ":" .. tostring(shiny(mon))))
  local cached = rendererCache[world]
  if cached and cached.key == key then return cached.renderer end
  local renderer, err = buildActorRenderer(world, mon, fieldKit, kind)
  if not renderer then
    M.lastError = tostring(err)
    return nil
  end
  rendererCache[world] = { key = key, renderer = renderer }
  M.lastError = nil
  return renderer
end

local function proxyForSurf(world, renderer, record)
  local player = world.player
  local proxy = {
    __vascGen2SurfPresentation = true,
    -- VoxelScene uses this exact render-only proxy marker to retain the full
    -- rider/mount card while a selected 3RD camera recomputes its boom.
    __vascSpeciesSurfForceVisible = true,
    __vascGen2ExactFieldActor = true,
    __vascGen2FieldActorKind = record.fieldKit and "jetski" or "surf",
    __vascGen2FieldKitJetski = record.fieldKit == true,
    stadiumModel = false,
    pokemonModel = false,
  }
  setmetatable(proxy, { __index = player })
  function proxy:pose()
    local _, x, y, facing, phase, flip = player:pose()
    return renderer, x or player.px, y or player.py,
      facing or player.facing or "down", phase or 0, flip == true
  end
  return proxy
end

local function replaceRenderPlayer(state, original, proxy)
  local out, replaced = {}, false
  for _, entity in ipairs(state.entities or {}) do
    if entity == original then
      if not replaced then out[#out + 1], replaced = proxy, true end
    else
      out[#out + 1] = entity
    end
  end
  if not replaced then table.insert(out, 1, proxy) end
  state.entities = out
  state.player = proxy
end

local function suppressRenderFollowers(state)
  local out = {}
  for _, entity in ipairs(state.entities or {}) do
    local follower = entity and (entity.wildsFollower == true
      or entity.isFollower == true or entity.follower == true
      or entity.pikachuFollower == true or entity.pokepcTrailer == true)
    if not follower then out[#out + 1] = entity end
  end
  state.entities = out
end

local function appendFlyProxy(world, state)
  if not optionEnabled(OPTION_KEYS.fly) then
    clearFly(world)
    return
  end
  local fa = world.flyAnim
  if not fa then return end
  local record = bridge and bridge.fly[world] or nil
  -- Only the exact user captured from the successful native call is allowed
  -- to replace the engine's Fly card. Inferring identity from BIRD/MONSTER or
  -- another generic host fallback is precisely how third person could switch
  -- to an unrelated Pokemon.
  local mon = record and record.mon or nil
  local fieldKit = record and record.fieldKit == true
  local species = mon and mon.species or nil
  if not species then return end
  local renderer = actorRenderer(world, mon, fieldKit, "fly")
  if not renderer then return end
  local player = world.player
  local proxy = {
    __vascGen2FlyPresentation = true,
    __vascGen2ExactFieldActor = true,
    __vascGen2FieldActorKind = fieldKit and "jetpack" or "fly",
    __vascGen2FieldKitJetpack = fieldKit,
    stadiumModel = false,
    pokemonModel = false,
    dramaticSkyRideMountSpecies = species,
    skyRideMountSpecies = species,
    species = species,
    px = fa.px, py = fa.py,
    cellX = math.floor((tonumber(fa.px) or 0) / 16),
    cellY = math.floor((tonumber(fa.py) or 0) / 16),
    facing = player and player.facing or "down",
  }
  function proxy:pose()
    return renderer,
      (tonumber(fa.px) or 0) + (tonumber(fa.xoff) or 0),
      (tonumber(fa.py) or 0) + (tonumber(fa.y) or 0),
      self.facing, math.floor((tonumber(fa.t) or 0) / 8) % 2, false
  end
  local entities = {}
  for _, entity in ipairs(state.entities or {}) do entities[#entities + 1] = entity end
  entities[#entities + 1] = proxy
  state.entities = entities
  state._vascGen2FlyProxy = true
  M.flyFrames = M.flyFrames + 1
  if fieldKit then M.fieldKitFlyFrames = M.fieldKitFlyFrames + 1 end
end

function M.decorateState(world, state)
  if not (world and state and world.player and bridge) then return state end
  state._vascGen2World = world
  local okMoves, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
  local surfing = okMoves and FieldMoves and type(FieldMoves.isSurfing) == "function"
    and FieldMoves.isSurfing(world.playerState)
  local heldSurf = bridge.surf[world]
  if heldSurf and not optionEnabled(
      heldSurf.fieldKit and OPTION_KEYS.fieldKit or OPTION_KEYS.surf) then
    clearSurf(world)
  end

  if surfing then
    local record = bridge.surf[world]
    -- An old/load-time SURF state has no exact user. Keep the engine's native
    -- card rather than guessing the first party member or inventing Field Kit.
    if record then
      record.pending = false
      state._vascGen2FieldPresentationKind = record.fieldKit
        and "fieldKit" or "surf"
      local renderer = actorRenderer(world, record.mon, record.fieldKit, "surf")
      if renderer then
        suppressRenderFollowers(state)
        local proxy = proxyForSurf(world, renderer, record)
        replaceRenderPlayer(state, world.player, proxy)
        M.surfFrames = M.surfFrames + 1
        if record.fieldKit then M.fieldKitFrames = M.fieldKitFrames + 1 end
      end
    end
  else
    local record = bridge.surf[world]
    -- World:runSurf owns a native text callback before it changes playerState.
    -- Retain the exact user through those text frames, then clear normally on
    -- the first genuine land frame after SURF has begun.
    if not (record and record.pending == true) then
      clearSurf(world)
    end
  end

  if world.flyAnim and optionEnabled(OPTION_KEYS.fly) then
    suppressRenderFollowers(state)
    local flyRecord = bridge.fly[world]
    state._vascGen2FieldPresentationKind = flyRecord
        and flyRecord.fieldKit == true and "fieldKitFly" or "fly"
    -- The first Johto bridge reduced Fly to one 16px composite billboard.
    -- That could move, but it could not show Kanto's actual choreography:
    -- ball throw, separate landing Pokemon, mount/carry, take-off, dismount
    -- and recall.  GoldFlyCinematic now owns the presentation overlay while
    -- Crystal's native flyAnim continues to own time, callbacks and warps.
    state._vascGen2FlyCinematic = flyRecord ~= nil
  else
    clearFly(world)
  end
  return state
end

-- Paint the engine-provided standing FX after a successful 3D frame.  Gold's
-- callback speaks flat world X/Z coordinates; Voxel3D.project additionally
-- needs the ground height, which is resolved from the same adapted map used by
-- the scene.  This function never changes animation timing or callbacks.
function M.drawEngineFx(canvas, state, ctx, VoxelScene, Voxel3D)
  if not (canvas and type(ctx) == "table" and type(ctx.drawFx) == "function") then
    return true
  end
  local kind = state and state._vascGen2FieldPresentationKind
  local enabled = kind == "surf" and optionEnabled(OPTION_KEYS.surf)
    or kind == "fieldKit" and optionEnabled(OPTION_KEYS.fieldKit)
    or kind == "fly" and optionEnabled(OPTION_KEYS.fly)
    or kind == "fieldKitFly" and optionEnabled(OPTION_KEYS.fieldKit)
  if not enabled then return true end
  if (kind == "fly" or kind == "fieldKitFly")
      and state and state._vascGen2FlyCinematic then
    local world = state._vascGen2World
    local record = world and bridge and bridge.fly and bridge.fly[world] or nil
    if GoldFlyCinematic and type(GoldFlyCinematic.draw) == "function" then
      local ok, value = pcall(GoldFlyCinematic.draw, world, record, canvas,
        ctx, VoxelScene, Voxel3D)
      if ok and value == true then
        M.flyFrames = M.flyFrames + 1
        if kind == "fieldKitFly" then
          M.fieldKitFlyFrames = M.fieldKitFlyFrames + 1
        end
        return true
      end
      local detail = value
      if ok and GoldFlyCinematic
          and type(GoldFlyCinematic.status) == "function" then
        local statusOK, status = pcall(GoldFlyCinematic.status)
        detail = statusOK and type(status) == "table" and status.lastError
          or detail
      end
      M.lastError = tostring(detail or (ok and "Fly cinematic declined" or value))
      if M.lastError ~= lastFlyCinematicWarning then
        lastFlyCinematicWarning = M.lastError
        safeWarn("Gen-2 Fly cinematic failed open: %s", M.lastError)
      end
    end
    -- Fail open to the native Gen-2 Fly drawing callback. Its icon was saved
    -- by the start wrapper and is restored by drawFlyAnim below.
  end
  local G = love and love.graphics
  if not (G and G.setCanvas and G.push and G.pop
      and Voxel3D and type(Voxel3D.project) == "function") then
    return false
  end

  local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
  local pushed = false
  local ok, err = pcall(function()
    G.push("all")
    pushed = true
    G.setCanvas(canvas)
    if type(G.origin) == "function" then G.origin() end
    if type(G.setShader) == "function" then G.setShader() end
    if type(G.setDepthMode) == "function" then G.setDepthMode() end
    if type(G.setBlendMode) == "function" then G.setBlendMode("alpha") end
    local function project(wx, wz)
      wx, wz = tonumber(wx), tonumber(wz)
      if not (wx and wz) then return nil end
      local ground = 0
      if VoxelScene and type(VoxelScene.groundAt) == "function"
          and state and state.map then
        local okGround, value = pcall(VoxelScene.groundAt, state.map,
          math.floor(wx / 16), math.floor(wz / 16))
        if okGround then ground = tonumber(value) or 0 end
      end
      return Voxel3D.project(wx, ground, wz)
    end
    ctx.drawFx(project, tonumber(ctx.scale) or 1)
  end)
  if pushed then pcall(G.pop) end
  if previous then pcall(G.setCanvas, previous) else pcall(G.setCanvas) end
  if not ok then
    M.lastError = tostring(err)
    safeWarn("Gen-2 voxel field FX failed open: %s", tostring(err))
    return false
  end
  return true
end

function M.install()
  if M.installed and bridge then return true end
  local okWorld, World = pcall(require, "src.world.gen2.World")
  if not (okWorld and type(World) == "table") then
    return false, "Gen-2 World class unavailable"
  end

  local okFly, flyOrErr = pcall(V.require, "GoldFlyCinematic")
  if okFly and type(flyOrErr) == "table"
      and type(flyOrErr.draw) == "function" then
    GoldFlyCinematic = flyOrErr
  else
    M.lastError = "GoldFlyCinematic unavailable: " .. tostring(flyOrErr)
    safeWarn("%s", M.lastError)
  end

  bridge = World.__vascGoldFieldMovePresentation
  if type(bridge) ~= "table" then
    bridge = {
      surf = setmetatable({}, { __mode = "k" }),
      fly = setmetatable({}, { __mode = "k" }),
      surfStartStep = World.surfStartStep,
      runSurf = World.runSurf,
      startFlyAnim = World.startFlyAnim,
      drawFlyAnim = World.drawFlyAnim,
    }
    if type(bridge.surfStartStep) == "function" then
      World.surfStartStep = function(world, mon, ...)
        local results = pack(bridge.surfStartStep(world, mon, ...))
        local key = mon == nil and OPTION_KEYS.fieldKit or OPTION_KEYS.surf
        if results[1] ~= false and results[1] ~= nil and optionEnabled(key) then
          bridge.surf[world] = { mon = mon, fieldKit = mon == nil }
        else
          clearSurf(world)
        end
        return unpackValues(results, 1, results.n)
      end
    end
    if type(bridge.runSurf) == "function" then
      World.runSurf = function(world, result, ...)
        local mon = type(result) == "table" and result.mon or nil
        local results = pack(bridge.runSurf(world, result, ...))
        if mon ~= nil then
          if optionEnabled(OPTION_KEYS.surf) then
            bridge.surf[world] = { mon = mon, fieldKit = false, pending = true }
          else
            clearSurf(world)
          end
        else
          local held = bridge.surf[world]
          if not (held and held.fieldKit == true
              and optionEnabled(OPTION_KEYS.fieldKit)) then
            clearSurf(world)
          end
        end
        return unpackValues(results, 1, results.n)
      end
    end
    if type(bridge.startFlyAnim) == "function" then
      World.startFlyAnim = function(world, phase, mon, onDone, ...)
        local results = pack(bridge.startFlyAnim(world, phase, mon, onDone, ...))
        if results[1] ~= false and results[1] ~= nil and world.flyAnim
            and optionEnabled(OPTION_KEYS.fly) then
          local record = {
            mon = mon,
            phase = phase,
            fieldKit = type(mon) == "table" and mon.fieldKitJetpack == true,
          }
          -- Keep Crystal's icon only as a recoverable 2D fallback.  The Gen-2
          -- world pipeline can retain a direct reference to the original
          -- draw closure, so merely wrapping drawFlyAnim is not sufficient to
          -- prevent PAL_OW_RED's generic blue icon from covering the exact
          -- VASC species card.  Animation timing uses no icon after setup.
          if voxelEnabled() and world.flyAnim.icon ~= nil then
            record.nativeIcon = world.flyAnim.icon
            world.flyAnim.icon = nil
          end
          bridge.fly[world] = record
        else
          clearFly(world)
        end
        return unpackValues(results, 1, results.n)
      end
    end
    if type(bridge.drawFlyAnim) == "function" then
      World.drawFlyAnim = function(world, ...)
        local record = bridge.fly[world]
        local presentationEnabled = record and voxelEnabled()
          and (record.fieldKit == true and optionEnabled(OPTION_KEYS.fieldKit)
            or record.fieldKit ~= true and optionEnabled(OPTION_KEYS.fly))
        -- GoldVoxelBridge already placed the exact species/jetpack composite
        -- in the 3D scene. Drawing Crystal's generic PAL_OW_RED Fly icon over
        -- it would obscure that actor (most visibly turning Charizard blue).
        if presentationEnabled then
          M.nativeFlyDrawsSuppressed = M.nativeFlyDrawsSuppressed + 1
          return
        end
        if record and record.nativeIcon and world.flyAnim
            and world.flyAnim.icon == nil then
          world.flyAnim.icon = record.nativeIcon
        end
        return bridge.drawFlyAnim(world, ...)
      end
    end
    World.__vascGoldFieldMovePresentation = bridge
  end

  M.installed = true
  return true
end

function M.status()
  local config = configured()
  return {
    installed = M.installed,
    active = config.speciesSurfPresentation
      or config.fieldKitPresentation or config.speciesFlyPresentation,
    configured = config,
    lastError = M.lastError,
    surfFrames = M.surfFrames,
    flyFrames = M.flyFrames,
    fieldKitFrames = M.fieldKitFrames,
    fieldKitFlyFrames = M.fieldKitFlyFrames,
    nativeFlyDrawsSuppressed = M.nativeFlyDrawsSuppressed,
    flyCinematic = GoldFlyCinematic
      and type(GoldFlyCinematic.status) == "function"
      and GoldFlyCinematic.status() or nil,
  }
end

M.configured = configured

return M
