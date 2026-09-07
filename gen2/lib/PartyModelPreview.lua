-- Animated Stadium 2 model preview for the custom Gold party screen.
--
-- This is presentation-only.  It owns one StadiumMon attached to the live
-- PartyMenu instance, renders that mon into a small transparent Voxel3D scene,
-- and hands the canvas back to GoldSubmenuBattleStyle.  Party selection,
-- switching, field moves, items and stats remain entirely engine-owned.
--
-- The preview deliberately asks StadiumMon for allowStatic=true: if a Stadium
-- 2 pack has a valid mesh but no trusted idle clip, the party screen should
-- still show the real 3D Pokemon in its bind pose rather than dropping back to
-- an empty preview.  Battles keep their stricter animated-model gate.
local V = ...

local Voxel3D = V.require("Voxel3D")
local StadiumMon = V.require("StadiumMon")
local StadiumPack = V.require("StadiumPack")

local Preview = {
  renders = 0,
  failures = 0,
}

local function modelsEnabled()
  if type(V.modelsEnabled) == "function" then
    local ok, value = pcall(V.modelsEnabled)
    if ok then return value ~= false end
  end
  local mod = V.mod
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "stadium3dSprites")
  if not ok or value == nil then return false end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function nowSeconds()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, value = pcall(love.timer.getTime)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return os.clock()
end

local function clamp(value, lo, hi)
  value = tonumber(value) or lo
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function dexFor(screen, mon)
  if type(mon) ~= "table" or mon.isEgg then return nil end
  local species = mon.species or mon.id or mon.name
  if tonumber(species) then return tonumber(species) end
  local game = screen and screen.game
  local pokemon = game and game.data and game.data.pokemon
  local def = pokemon and pokemon[species]
  return def and tonumber(def.dex or def.index) or nil
end

local function stateFor(screen)
  if type(screen) ~= "table" then return nil end
  local state = screen._stadium2PartyPreview
  if state then return state end
  local ok, actor = pcall(StadiumMon.new, "party-preview")
  if not ok or type(actor) ~= "table" then return nil end
  state = {
    actor = actor,
    dex = nil,
    available = false,
    turn = 0,
    lastClock = nowSeconds(),
    lastAttempt = -math.huge,
    lastError = nil,
  }
  screen._stadium2PartyPreview = state
  return state
end

local function resetActor(state)
  if not (state and state.actor) then return end
  pcall(state.actor.setSpecies, state.actor, nil, true)
  state.dex = nil
  state.available = false
end

local function ensureSpecies(screen, mon)
  local state = stateFor(screen)
  if not state then return nil, nil end
  local dex = dexFor(screen, mon)
  if not dex then
    resetActor(state)
    return state, nil
  end

  local now = nowSeconds()
  local retry = state.dex == dex and not state.available
    and (now - (state.lastAttempt or -math.huge)) >= 1.5
  if state.dex ~= dex or retry then
    if retry then pcall(state.actor.setSpecies, state.actor, nil, true) end
    state.dex = dex
    state.lastAttempt = now
    local ok, ready = pcall(state.actor.setSpecies, state.actor, dex, true)
    state.available = ok and ready == true and state.actor.rig ~= nil
    state.lastError = ok and nil or tostring(ready)
    state.lastClock = now
    state.turn = 0
  end
  return state, dex
end

local function restoreCanvas(G, previous)
  if previous ~= nil then
    pcall(G.setCanvas, previous)
  else
    pcall(G.setCanvas)
  end
end

-- Render the selected party mon into a transparent canvas.
-- Returns canvas, info.  `info.available` distinguishes an imported/usable 3D
-- model from the text fallback the caller should draw.
function Preview.render(screen, mon, requestedW, requestedH, frameOpts)
  if not modelsEnabled() then
    Preview.release(screen)
    return nil, { dex = dexFor(screen, mon), available = false, disabled = true }
  end
  local state, dex = ensureSpecies(screen, mon)
  local info = {
    dex = dex,
    available = false,
    error = state and state.lastError or nil,
  }
  if not (state and dex and state.available and state.actor and state.actor.rig) then
    return nil, info
  end
  if type(Voxel3D.available) == "function" then
    local ok, available = pcall(Voxel3D.available)
    if not ok or available == false then return nil, info end
  end

  local G = love and love.graphics
  if not (G and type(G.getCanvas) == "function" and type(G.setCanvas) == "function") then
    return nil, info
  end

  frameOpts = type(frameOpts) == "table" and frameOpts or {}
  local osName = ""
  do
    local okOS, name = pcall(function()
      local sys = love and love.system
      return sys and type(sys.getOS) == "function" and sys.getOS() or ""
    end)
    if okOS and (name == "iOS" or name == "Android") then
      osName = tostring(name)
    end
    local okPlatform, Platform = pcall(require, "src.core.Platform")
    if osName == "" and okPlatform and type(Platform) == "table"
        and type(Platform.detect) == "function" then
      local okDetect, info = pcall(Platform.detect)
      if okDetect and type(info) == "table" then osName = tostring(info.os or "") end
    end
    if osName == "" then
      if okOS then osName = tostring(name or "") end
    end
  end
  -- Render a larger INTERNAL preview than the glass UI slot and scale the
  -- result down when compositing it. This is overscan, not a bigger menu box:
  -- animated wings/heads/tails have extra offscreen room before projection.
  local renderScale = clamp(frameOpts.renderScale or 1.42, 1.0, 2.0)
  local cap = osName == "Android" and 448 or 768
  local rw = math.floor(clamp((tonumber(requestedW) or 0) * renderScale, 176, cap) + 0.5)
  local rh = math.floor(clamp((tonumber(requestedH) or 0) * renderScale, 192, cap) + 0.5)

  local now = nowSeconds()
  local dt = clamp(now - (state.lastClock or now), 0, 1 / 15)
  state.lastClock = now
  state.turn = (state.turn or 0) + dt

  local actor = state.actor
  pcall(actor.update, actor, dt)

  local height = math.max(4, tonumber(actor:worldHeight()) or 12)
  local radius = math.max(1, tonumber(actor:worldRadius()) or height * 0.35)
  -- A slow showroom turn rather than an endless back-facing spin: the model
  -- is always readable while still visibly being a live 3D object.
  local yaw = math.sin(state.turn * 0.55) * 0.42
  local matrix = actor:matrix(0, 0, 0, math.sin(yaw), math.cos(yaw))
  if not matrix then return nil, info end

  -- Build/skin BEFORE choosing the camera so the fit can use the CURRENT
  -- animated pose.  v0.2.74 still framed from bind-pose worldHeight/radius,
  -- which misses raised wings, long tails and animation translation.
  local okBuild, built = pcall(actor.build, actor)
  if not okBuild or built ~= true then
    info.error = okBuild and "Stadium preview rig could not build" or tostring(built)
    return nil, info
  end

  local fov = math.rad(clamp(frameOpts.fovDeg or 31, 22, 42))
  local tanV = math.max(1e-4, math.tan(fov * 0.5))
  local aspect = math.max(0.15, rw / math.max(1, rh))
  -- Perspective horizontal half-angle obeys tan(h/2)=aspect*tan(v/2).
  -- The old camera divided BOTH height and width by tan(v/2), so portrait
  -- Pokédex canvases had a much narrower real horizontal FOV than the fit
  -- calculation believed and wide Pokémon were clipped at the sides.
  local tanH = math.max(1e-4, tanV * aspect)
  local cameraMargin = clamp(frameOpts.cameraMargin or 1.10, 1.02, 1.90)

  local focusX, focusY, focusZ = 0, height * 0.58, 0
  local halfX = radius * clamp(frameOpts.radiusExtent or 1.40, 1.10, 2.40)
  local halfY = height * clamp(frameOpts.heightExtent or 0.78, 0.60, 1.40)
  local halfZ = math.max(radius, height * 0.20)
  local usedPosedBounds = false

  local rig = actor.rig
  if rig and type(rig.posedBounds) == "function" then
    local okBounds, loX, loY, loZ, hiX, hiY, hiZ = pcall(rig.posedBounds, rig)
    local finite = okBounds
      and tonumber(loX) and tonumber(loY) and tonumber(loZ)
      and tonumber(hiX) and tonumber(hiY) and tonumber(hiZ)
    if finite and hiX >= loX and hiY >= loY and hiZ >= loZ then
      local model = actor.model or {}
      local modelH = math.max(1e-6, tonumber(model.height) or 1)
      local root = tonumber(model.rootScale) or 1
      if root <= 0 then root = 1 end
      local k = root * height / modelH * (tonumber(actor.scale) or 1)
      local floor = tonumber(model.floor) or 0
      local hoverCap = tonumber(actor.HOVER_CAP) or 0.18
      -- StadiumMon.HOVER_CAP is module-local; the authored hover is already
      -- small, so use the same 18%-of-height cap when that constant is not
      -- exported.  This only affects centering, never mesh scale.
      local hover = math.min(math.max(floor, 0), hoverCap * math.max(modelH, 0))
      local lift = (floor - hover) / root

      local rawCX = (loX + hiX) * 0.5
      local rawCY = (loY + hiY) * 0.5 - lift
      local rawCZ = (loZ + hiZ) * 0.5
      local rawHX = math.max(1e-4, (hiX - loX) * 0.5)
      local rawHY = math.max(1e-4, (hiY - loY) * 0.5)
      local rawHZ = math.max(1e-4, (hiZ - loZ) * 0.5)
      local cyaw, syaw = math.cos(yaw), math.sin(yaw)

      focusX = k * (cyaw * rawCX + syaw * rawCZ)
      focusY = k * rawCY
      focusZ = k * (-syaw * rawCX + cyaw * rawCZ)
      halfX = k * (math.abs(cyaw) * rawHX + math.abs(syaw) * rawHZ)
      halfY = k * rawHY
      halfZ = k * (math.abs(syaw) * rawHX + math.abs(cyaw) * rawHZ)

      local padX = clamp(frameOpts.horizontalPadding or 1.10, 1.0, 1.65)
      local padY = clamp(frameOpts.verticalPadding or 1.08, 1.0, 1.65)
      halfX = math.max(1, halfX * padX)
      halfY = math.max(1, halfY * padY)
      halfZ = math.max(0.5, halfZ)
      local focusBias = clamp(frameOpts.focusBias or 0.04, -0.35, 0.35)
      focusY = focusY + halfY * focusBias
      -- Once the aim is biased above/below centre, one side of the silhouette
      -- is farther from the new focus. Include that asymmetry in the fit.
      halfY = halfY * (1 + math.abs(focusBias))
      usedPosedBounds = true
    end
  end

  if not usedPosedBounds then
    -- Compatibility fallback for malformed/legacy rigs: still fix the core
    -- horizontal-FOV bug even when precise posed bounds are unavailable.
    focusY = height * clamp(frameOpts.focusY or 0.68, 0.35, 1.30)
  end

  -- A point at the FRONT of the model has less eye distance than its centre,
  -- so add the depth half-extent before the angular fit.  This keeps noses,
  -- wings and tails inside the viewport through the whole showroom turn.
  local angularDistance = math.max(halfY / tanV, halfX / tanH)
  local distance = math.max(halfZ + angularDistance * cameraMargin, 13)
  local camera = {
    eye = { focusX, focusY, focusZ + distance },
    focus = { focusX, focusY, focusZ },
    fov = fov,
    up = { 0, 1, 0 },
  }

  local previousCanvas
  local okPrev, value = pcall(G.getCanvas)
  if okPrev then previousCanvas = value end
  local sceneState = type(Voxel3D.captureSceneState) == "function"
    and Voxel3D.captureSceneState() or nil
  local previousCamera = Voxel3D.camera
  local previousTint = Voxel3D.tint

  -- Keep this pack hot while the selector is open.  In battle this prevents
  -- cycling through the party preview from evicting a model that is still
  -- standing on the battlefield; the battle's own keep() calls protect its
  -- two actors and this protects the third temporary actor.
  if StadiumPack and type(StadiumPack.keep) == "function" then
    pcall(StadiumPack.keep, dex)
  end

  local canvas = nil
  local pushed = false
  local okRender, err = pcall(function()
    G.push("all")
    pushed = true
    Voxel3D.camera = camera
    Voxel3D.tint = { 1, 1, 1 }
    if not Voxel3D.beginScene(rw, rh, 0, 0, rw, rh, nil, "party-preview") then
      error("Voxel3D preview scene unavailable")
    end
    Voxel3D.flatten(nil)
    Voxel3D.seams(false)
    Voxel3D.glass(false)
    Voxel3D.blend(nil)
    actor.rig:draw(matrix, nil)
    canvas = Voxel3D.endScene()
    if sceneState and type(Voxel3D.restoreSceneState) == "function" then
      Voxel3D.restoreSceneState(sceneState)
    else
      Voxel3D.camera = previousCamera
      Voxel3D.tint = previousTint
    end
    restoreCanvas(G, previousCanvas)
    G.pop()
    pushed = false
  end)

  -- A failed pcall can happen after beginScene bound its private target.  Put
  -- both LOVE's target and Voxel3D's private/public scene bookkeeping back.
  if not okRender then
    pcall(Voxel3D.endScene)
    if sceneState and type(Voxel3D.restoreSceneState) == "function" then
      pcall(Voxel3D.restoreSceneState, sceneState)
    else
      Voxel3D.camera = previousCamera
      Voxel3D.tint = previousTint
    end
    restoreCanvas(G, previousCanvas)
    if pushed then pcall(G.pop) end
    state.lastError = tostring(err)
    Preview.failures = Preview.failures + 1
    info.error = state.lastError
    return nil, info
  end

  if not canvas then return nil, info end
  state.lastError = nil
  Preview.renders = Preview.renders + 1
  info.available = true
  info.height = height
  info.radius = radius
  info.renderWidth = rw
  info.renderHeight = rh
  info.cameraDistance = distance
  info.aspect = aspect
  info.posedBounds = usedPosedBounds
  return canvas, info
end

function Preview.release(screen)
  local state = type(screen) == "table" and screen._stadium2PartyPreview or nil
  if not state then return end
  if state.actor and type(state.actor.release) == "function" then
    pcall(state.actor.release, state.actor)
  end
  screen._stadium2PartyPreview = nil
end

function Preview.status(screen)
  local state = type(screen) == "table" and screen._stadium2PartyPreview or nil
  return {
    renders = Preview.renders,
    failures = Preview.failures,
    dex = state and state.dex or nil,
    available = state and state.available or false,
    lastError = state and state.lastError or nil,
  }
end

return Preview
