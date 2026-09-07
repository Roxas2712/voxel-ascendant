-- Gold/Silver official render_pipelines bridge.
--
-- Newer Gen1Recomp builds give Gold the same engine-owned drawWorld pipeline
-- seam that Gen 1 already had.  Older Gold builds (including some Android
-- packages) still rely on render.compose instead.  Registering this provider is
-- therefore deliberately additive: current builds render the voxel world from
-- World:drawPipeline, while GoldComposeBridge remains the fallback for hosts
-- where the drawWorld half is not consumed.
local first, second = ...
local mod, VoxelBridge
if second == nil and type(first) == "table" and first.mod then
  mod, VoxelBridge = first.mod, first.VoxelBridge
else
  mod, VoxelBridge = first, second
end

local Bridge = {
  id = "stadium2_gold_voxel",
  registered = false,
  runtimeInstalled = false,
  runtimeActive = false,
  game = nil,
  frames = 0,
  renderedFrames = 0,
  fallbackFrames = 0,
  lastError = nil,
  lastStatus = nil,
  renderReceipt = nil,
  renderSerial = 0,
  selectorComposeFallback = false,
  selectorDetected = false,
}

local function optionOn()
  if VoxelBridge and type(VoxelBridge.voxelModeEnabled) == "function" then
    local ok, yes = pcall(VoxelBridge.voxelModeEnabled)
    if ok then return yes and true or false end
  end
  local opts = mod and mod.options
  if not (opts and type(opts.get) == "function") then return true end
  local ok, value = pcall(opts.get, opts, "voxel3d")
  if not ok or value == nil then return true end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function resolveGame(value)
  if type(value) == "table" then
    if value.world or value.stack then return value end
    if type(value.game) == "table" then return value.game end
  end
  return Bridge.game
end

local function resolveWorld(ctx)
  local world = ctx and ctx.state
  if type(world) == "table" and world.map then return world end

  local game = Bridge.game
  world = game and game.world
  if type(world) == "table" and world.map then return world end

  local api = mod and mod.world
  if api and type(api.overworld) == "function" then
    local ok, value = pcall(api.overworld, api)
    if ok and type(value) == "table" and value.map then return value end
  end
  return nil
end

-- GoldVoxelBridge was originally fed render.compose metrics.  Translate the
-- official drawWorld context without mutating the engine's table.  In
-- particular force the output canvas to the logical window dimensions the
-- pipeline compositor expects; render.compose separately handles HiDPI scaling
-- when the older fallback path is used.
local function voxelContext(ctx)
  local w = tonumber(ctx and ctx.width)
  local h = tonumber(ctx and ctx.height)
  if not (w and h and w > 0 and h > 0) then
    local G = love and love.graphics
    if G and type(G.getDimensions) == "function" then w, h = G.getDimensions() end
  end
  w, h = tonumber(w) or 1, tonumber(h) or 1
  return {
    generation = 2,
    ww = w, wh = h,
    pw = w, ph = h,
    vw = tonumber(ctx and ctx.vw),
    vh = tonumber(ctx and ctx.vh),
    scale = tonumber(ctx and ctx.scale),
    cam = ctx and ctx.cam,
    state = ctx and ctx.state,
    level = ctx and ctx.level,
    drawFx = ctx and ctx.drawFx,
    fx = ctx and ctx.fx,
  }
end

local function frameToken(ctx)
  if type(ctx) ~= "table" then return nil end
  for _, key in ipairs({ "frameToken", "frameId", "renderFrame", "frame", "tick" }) do
    local value = ctx[key]
    if type(value) == "number" or type(value) == "string" then
      return key .. ":" .. tostring(value)
    end
  end
  return nil
end

local function monotonicTime()
  local timer = love and love.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok then return tonumber(value) end
  end
  return nil
end

local function available()
  -- Keep this gate intentionally cheap.  GoldVoxelBridge performs the actual
  -- depth/shader capability check and returns nil on unsupported hardware, at
  -- which point Pipelines falls back to native 2D for that frame.
  return optionOn()
end

local function drawWorld(ctx)
  Bridge.frames = Bridge.frames + 1
  Bridge.renderReceipt = nil
  if not optionOn() then
    Bridge.lastStatus = "disabled"
    Bridge.fallbackFrames = Bridge.fallbackFrames + 1
    return nil
  end
  if not (VoxelBridge and type(VoxelBridge.renderFrame) == "function") then
    Bridge.lastError = "Gold voxel provider is unavailable"
    Bridge.lastStatus = "failed"
    Bridge.fallbackFrames = Bridge.fallbackFrames + 1
    return nil
  end

  local world = resolveWorld(ctx)
  if not world then
    Bridge.lastError = "Gold world is unavailable"
    Bridge.lastStatus = "pending"
    Bridge.fallbackFrames = Bridge.fallbackFrames + 1
    return nil
  end

  if type(VoxelBridge.setGame) == "function" then
    pcall(VoxelBridge.setGame, (world and world.game) or Bridge.game)
  end

  local ok, canvas, err, status = pcall(
    VoxelBridge.renderFrame, world, voxelContext(ctx))
  if not ok then
    Bridge.lastError = tostring(canvas)
    Bridge.lastStatus = "failed"
    Bridge.fallbackFrames = Bridge.fallbackFrames + 1
    return nil
  end
  Bridge.lastStatus = status or (canvas and "rendered" or "pending")
  if not canvas then
    Bridge.lastError = err and tostring(err) or nil
    Bridge.fallbackFrames = Bridge.fallbackFrames + 1
    return nil
  end

  Bridge.renderedFrames = Bridge.renderedFrames + 1
  Bridge.lastError = nil
  -- A scene-bound receipt prevents a successful drawWorld call from suppressing
  -- an unrelated later compose (menus, battle transitions or another world).
  Bridge.renderSerial = Bridge.renderSerial + 1
  Bridge.renderReceipt = {
    serial = Bridge.renderSerial,
    token = frameToken(ctx),
    world = world,
    createdAt = monotonicTime(),
    consumed = false,
  }
  return canvas
end

local function pipelineModule()
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if ok and type(Pipelines) == "table" then return Pipelines end
  return nil
end

local function selectorNeedsCompose(Pipelines)
  -- Gen1Recomp permits only one active drawWorld pipeline. red_3d_player uses
  -- its public `voxel` pipeline levels for ZOOM/1ST/3RD and skin selection
  -- integration. Activating our own drawWorld record would therefore switch
  -- that pipeline OFF. When the selector is installed, deliberately keep our
  -- drawWorld record OFF and let GoldComposeBridge own the final world instead;
  -- OverworldStadium still calls the selector's red3dPlayerRenderer:drawVoxel,
  -- so selected player skins render inside the Stadium voxel scene.
  local found = false
  if mod and type(mod.find) == "function" then
    local okFind, selector = pcall(mod.find, "red_3d_player")
    found = okFind and selector ~= nil
  end
  if not found and Pipelines and type(Pipelines.get) == "function" then
    local okGet, def = pcall(Pipelines.get, "voxel")
    if okGet and type(def) == "table" then
      local owner = tostring(def.owner or def.modId or def.mod or def.source or ""):lower()
      local id = tostring(def.id or ""):lower()
      found = owner:find("red_3d_player", 1, true) ~= nil
        or id:find("red_3d_player", 1, true) ~= nil
    end
  end
  Bridge.selectorDetected = found
  return found
end

function Bridge.sync(gameOrEvent)
  Bridge.game = resolveGame(gameOrEvent) or Bridge.game
  local Pipelines = pipelineModule()
  if not (Pipelines and type(Pipelines.get) == "function"
      and type(Pipelines.setLevel) == "function") then
    Bridge.runtimeInstalled = false
    Bridge.runtimeActive = false
    return false, "engine drawWorld pipelines unavailable"
  end
  local def = Pipelines.get(Bridge.id)
  if type(def) ~= "table" or type(def.drawWorld) ~= "function" then
    Bridge.runtimeInstalled = false
    Bridge.runtimeActive = false
    return false, "Gold voxel drawWorld pipeline not present in merged registry"
  end

  Bridge.runtimeInstalled = true

  -- Preserve Character Selector's own world-pipeline state. The compose path
  -- is not a competing drawWorld pipeline, so both its selector/camera ladder
  -- and our voxel/Stadium presentation can coexist there.
  if selectorNeedsCompose(Pipelines) then
    pcall(Pipelines.setLevel, Bridge.id, 0)
    Bridge.runtimeActive = false
    Bridge.selectorComposeFallback = true
    Bridge.lastError = nil
    return true, false
  end
  Bridge.selectorComposeFallback = false

  local wanted = optionOn() and 1 or 0
  local ok, level = pcall(Pipelines.setLevel, Bridge.id, wanted)
  if not ok then
    Bridge.runtimeActive = false
    Bridge.lastError = tostring(level)
    return false, Bridge.lastError
  end
  Bridge.runtimeActive = tonumber(level) and tonumber(level) > 0 or false
  return true, Bridge.runtimeActive
end

function Bridge.consumeRenderedFrame(ctx, world)
  local receipt = Bridge.renderReceipt
  Bridge.renderReceipt = nil
  if type(receipt) ~= "table" or receipt.consumed then return false end
  if world ~= nil and receipt.world ~= nil and receipt.world ~= world then return false end
  local composeToken = frameToken(ctx)
  if composeToken and receipt.token and composeToken ~= receipt.token then return false end
  local now, created = monotonicTime(), tonumber(receipt.createdAt)
  if now and created and (now - created < 0 or now - created > 0.25) then return false end
  receipt.consumed = true
  Bridge.lastConsumedSerial = receipt.serial
  return true
end

function Bridge.install()
  if Bridge.registered then return true end
  local content = mod and mod.content
  local registry = content and content.render_pipelines
  if not (registry and type(registry.register) == "function") then
    -- Older engines can still use GoldComposeBridge.  This is deliberately a
    -- non-fatal "not installed" result, not a reason to take the mod down.
    return false, "render_pipelines registry is unavailable"
  end

  local ok, err = pcall(registry.register, registry, Bridge.id, {
    label = "STADIUM 2 VOXEL WORLD",
    levels = { "OFF", "ON" },
    priority = 1100,
    available = available,
    drawWorld = drawWorld,
  })
  if not ok then return false, tostring(err) end
  Bridge.registered = true

  if mod.events and type(mod.events.on) == "function" then
    pcall(mod.events.on, mod.events, "game.ready", function(ev)
      Bridge.sync(ev)
    end)
    pcall(mod.events.on, mod.events, "map.entered", function(ev)
      Bridge.sync(ev)
    end)
    pcall(mod.events.on, mod.events, "mod.options_changed", function(ev)
      if type(ev) ~= "table" then return end
      if ev.mod ~= nil and ev.mod ~= mod.id then return end
      if ev.key == "voxel3d" or ev.key == "openWorld" then Bridge.sync() end
    end)
  end

  return true
end

function Bridge.status()
  return {
    id = Bridge.id,
    registered = Bridge.registered,
    runtimeInstalled = Bridge.runtimeInstalled,
    runtimeActive = Bridge.runtimeActive,
    frames = Bridge.frames,
    renderedFrames = Bridge.renderedFrames,
    fallbackFrames = Bridge.fallbackFrames,
    lastError = Bridge.lastError,
    lastStatus = Bridge.lastStatus,
    selectorDetected = Bridge.selectorDetected,
    selectorComposeFallback = Bridge.selectorComposeFallback,
    renderSerial = Bridge.renderSerial,
    lastConsumedSerial = Bridge.lastConsumedSerial,
  }
end

Bridge._drawWorld = drawWorld
Bridge._available = available
Bridge._voxelContext = voxelContext
Bridge._frameToken = frameToken
return Bridge
