-- Gold/Silver voxel renderer provider for the official render.compose hook.
--
-- Gold does not run Gen-1 drawWorld pipelines.  This module therefore owns no
-- engine method and registers no pipeline.  It only prepares the embedded
-- Dramatic Shapes renderer and exposes renderFrame(world, ctx); GoldComposeBridge
-- calls that from the engine's supported whole-window compose seam.
local mod = ...

local Bridge = {
  installed = false,
  active = false,
  lastError = nil,
  framesAttempted = 0,
  frames3d = 0,
  framesPending = 0,
  framesFailed = 0,
  mapId = nil,
  extraEntitiesProvider = nil,
  extraEntitiesMerged = 0,
  syncBuildMapId = nil,
  syncBuilds = 0,
  syncBuildFailures = 0,
  asyncBuildFrames = 0,
  asyncBuildStartedAt = nil,
  asyncBuildReadyMs = nil,
  mapTransitionSerial = 0,
  mapTransitionResets = 0,
  mapGeometryInvalidations = 0,
  mapLifecycleReason = nil,
  mapLifecycleError = nil,
  meshPendingFrames = 0,
  pendingWarpMapId = nil,
  pendingWarpRequestedMapId = nil,
  warpPrefetches = 0,
  warpPrefetchReady = 0,
  warpPrefetchFailures = 0,
  openWorld = false,
  openWorldMaps = 0,
  openWorldDirectMaps = 0,
  openWorldGraphBuilds = 0,
  openWorldFallbacks = 0,
  openWorldOverlapRejects = 0,
  openWorldGraphRoot = nil,
  openWorldGraphError = nil,
  openWorldDepth = 1,
  openWorldZoom = 1,
  cameraMode = "full",
  cameraLevel = 1,
  cameraHotkeyCycles = 0,
  cameraHotkeyPollCycles = 0,
  f6Down = false,
  vDown = false,
  cameraSliderInstalled = false,
  cameraSliderTouches = 0,
  cameraSliderChanges = 0,
  cameraInputInstalled = false,
  cameraInputError = nil,
  pinchZoomInstalled = false,
  pinchZoomError = nil,
  cameraMovementInstalled = false,
  cameraMovementError = nil,
  cameraOverride = nil,
  cameraProvider = "stadium",
  -- The transition may be a separate widescreen state which bypasses the
  -- compose owner. Keep the last *successfully presented free-roam* voxel
  -- frame and its exact owner receipt so that state can freeze it once. A raw
  -- canvas without the matching World/Map/camera receipt is never eligible.
  lastPresentedFrame = nil,
  -- A map replacement may need a few cooperative mesher slices. Keep the
  -- last complete voxel canvas as a visual bridge for exactly that pending
  -- interval; exposing Gold's native map for one frame is a visible 3D->2D
  -- flash and is never an honest representation of the selected mode.
  mapTransitionHold = nil,
  mapTransitionHoldFrames = 0,
  transitionSnapshotSerial = 0,
  transitionSnapshots = 0,
  transitionBackgroundFrames = 0,
  transitionBackgroundFallbacks = 0,
  transitionBackgroundLastReason = nil,
  externalCameraLevel = nil,
  externalCameraLabel = nil,
  selectorDetected = false,
  residencyReleased = true,
  game = nil,
  lastTickTime = nil,
}

-- Minimal Dramatic-Shape module namespace.  Deliberately does not execute the
-- Gen-1 pipeline/input installer from the original Dramaless package.
local V = { mod = mod, path = mod.path }
-- Renderer-owned sibling modules (most importantly OverworldBattle) use this
-- reference to attach the exact free-roam state to RC diagnostics. It avoids a
-- second GoldVoxelBridge instance and cannot drift from the live renderer.
V.goldBridge = Bridge
local modules, dataFiles = {}, {}
local ShortcutToast = nil
local unpackValues = table.unpack or unpack

local function packValues(...)
  return { n = select("#", ...), ... }
end

local function chunkFor(rel)
  local source, readErr = mod:read(rel)
  if type(source) ~= "string" then
    error(("VASC4J: missing %s: %s")
      :format(rel, tostring(readErr)), 0)
  end
  if source:sub(1, 3) == "\239\187\191" then source = source:sub(4) end
  local loadcode = loadstring or load
  local chunk, err = loadcode(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("VASC4J: %s did not compile: %s")
      :format(rel, tostring(err)), 0)
  end
  return chunk
end

function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
  modules[name] = value
  return value
end

function V.data(name)
  local hit = dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

Bridge.lib = V

local Voxel, Voxel3D, VoxelScene, ChunkMesher, FirstPerson, CamControl, GoldCameraControls
local CurrentMapWarmup, NeighborWarmup, OpenWorldStreaming
local OverworldBattle, OverworldCapture, GoldColorAtlas
local DayNight, Sky, SkyEvents, Weather, AmbientAudio
local AntiAlias
local GoldFieldMovePresentation, SpeciesFishingCinematic
local GoldMap = nil
local neighborMapCache = {}
local neighborWarmupState = {}
local openWorldGraphCache = {
  rootId = nil, maps = nil, maxDepth = nil, specs = nil,
}
local mapGeometrySignatures = {}
local mapGeometryDirty = {}
local logOnce

local function optionEnabled()
  local ok, value = pcall(mod.options.get, mod.options, "voxel3d")
  if not ok or value == nil then return true end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

-- Independent model switches. Neither disables the voxel world, 3D terrain,
-- buildings, trees, grass, props, weather, cameras or OPEN WORLD residency.
-- Pokemon geometry and the human-player Character Selector skin are separate
-- layers so either can fall back to Gold's 2D card while the other stays 3D.
local function modelOptionEnabled(key, default)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return default ~= false end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return default ~= false end
  return not (value == false or value == 0 or value == "0"
    or value == "false" or value == "off")
end

local function modelsEnabled()
  if not modelOptionEnabled("stadium3dSprites", false) then return false end
  local ok, provider = pcall(V.require, "PokemonModelProvider")
  if not ok or type(provider) ~= "table"
      or type(provider.modelsEnabled) ~= "function" then
    return false
  end
  local called, enabled = pcall(provider.modelsEnabled)
  return called and enabled == true
end

local function playerModelsEnabled()
  return modelOptionEnabled("player3dModel", true)
end

V.modelsEnabled = modelsEnabled
V.playerModelsEnabled = playerModelsEnabled
Bridge.modelsEnabled = modelsEnabled
Bridge.playerModelsEnabled = playerModelsEnabled

local function toggleValue(value, default)
  if value == nil then return default and true or false end
  if value == true or value == 1 or value == "1" then return true end
  if value == false or value == 0 or value == "0" then return false end
  if type(value) == "string" then
    value = value:lower()
    if value == "true" or value == "on" or value == "yes" then return true end
    if value == "false" or value == "off" or value == "no" then return false end
  end
  return default and true or false
end

local function optionOpenWorld()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "openWorld")
  if not ok then return false end
  return toggleValue(value, false)
end

local function configuredVoxelModeEnabled()
  return optionEnabled() or optionOpenWorld()
end

local function voxelModeEnabled()
  -- OPEN WORLD is defined as the full 3D world. It therefore keeps the voxel
  -- provider and its camera controls alive even if the independent legacy
  -- voxel3d option is false in an older save.
  -- A map replacement may briefly restore the public pipeline to OFF after
  -- the player's choice was read. During that bounded hand-off the pre-warp
  -- choice remains authoritative. A real user OFF command cancels this latch.
  return configuredVoxelModeEnabled()
    or Bridge.pendingPipelineRestoreEnabled == true
end

Bridge.voxelModeEnabled = voxelModeEnabled
Bridge.configuredVoxelModeEnabled = configuredVoxelModeEnabled

local Diagnostics = nil
local function diagnostic(event, fields)
  if Diagnostics and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function positiveDimensions(w, h)
  w, h = tonumber(w), tonumber(h)
  if not (w and h and w > 0 and h > 0) then return nil, nil end
  return math.floor(w + 0.5), math.floor(h + 0.5)
end

local function canvasDimensions(canvas)
  if canvas == nil then return nil, nil end
  local ok, w, h = pcall(function()
    if type(canvas.getDimensions) ~= "function" then return nil, nil end
    return canvas:getDimensions()
  end)
  if not ok then return nil, nil end
  return positiveDimensions(w, h)
end

local function currentDrawableDimensions()
  if type(Bridge.renderDimensions) == "function" then
    local ok, w, h = pcall(Bridge.renderDimensions)
    if ok then
      w, h = positiveDimensions(w, h)
      if w then return w, h end
    end
  end
  local graphics = love and love.graphics
  if graphics and type(graphics.getDimensions) == "function" then
    local ok, w, h = pcall(graphics.getDimensions)
    if ok then return positiveDimensions(w, h) end
  end
  return nil, nil
end

local function frameDimensions(frame)
  if type(frame) ~= "table" then return nil, nil end
  local w, h = positiveDimensions(frame.canvasWidth, frame.canvasHeight)
  if w then return w, h end
  return canvasDimensions(frame.canvas)
end

-- Keep the mobile probe optional on every platform.  The Gen-1 entry point
-- installs this helper itself, while Gen 2 reaches the bridge directly; the
-- three calls in renderFrame must therefore never assume a global created by
-- another generation's bootstrap.  An unguarded call here retired Gold's
-- otherwise healthy drawWorld pipeline and left Crystal permanently in 2D.
local MobileDiagnostic = V and V.mod and V.mod._vascMobileDiagnostic or nil
local function mobileDiagnostic(name, ...)
  local fn = MobileDiagnostic and MobileDiagnostic[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

function Bridge.setDiagnostics(value)
  Diagnostics = type(value) == "table" and value or nil
  return Diagnostics ~= nil
end

local function selectorPipelineLevel()
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not ok or type(Pipelines) ~= "table"
      or type(Pipelines.level) ~= "function" then return nil end
  local okLevel, level = pcall(Pipelines.level, "voxel")
  return okLevel and tonumber(level) or nil
end

local function applyOpenWorldMode(enabled)
  enabled = toggleValue(enabled, false)
  if Bridge.openWorld == enabled then return false end
  -- The mode switch only changes residency. Never replace the current voxel
  -- scene: clear the lightweight graph/adapted-map caches and let the next
  -- normal VoxelScene frame rebuild the neighbour set around the SAME current
  -- map/entities/terrain renderer. This is the key v0.2.46 rule that keeps all
  -- Stadium models, trees, grass, props and voxel geometry alive in both modes.
  neighborMapCache = {}
  openWorldGraphCache = {
    rootId = nil, maps = nil, maxDepth = nil, specs = nil,
  }
  Bridge.openWorld = enabled
  Bridge.openWorldGraphError = nil
  if not enabled then
    Bridge.openWorldMaps = 0
    if V then V.goldOpenWorldMaps = {} end
  end
  return true
end

Bridge.optionOpenWorld = optionOpenWorld
Bridge._applyOpenWorldMode = applyOpenWorldMode

local CAMERA_ORDER = {
  "full", "angle15", "angle35", "angle50", "angle75", "first", "third",
}
local CAMERA_NEXT = {}
for i, mode in ipairs(CAMERA_ORDER) do
  CAMERA_NEXT[mode] = CAMERA_ORDER[i % #CAMERA_ORDER + 1]
end
local CAMERA_QUICK = { "full", "third", "first" }

local function platformName()
  -- Current Gen1Recomp sandboxes throw when mod code dereferences
  -- love.system at all. Prefer the engine-owned Platform seam and keep the
  -- old direct LÖVE fallback entirely inside pcall for older hosts.
  local okNative, nativeOS = pcall(function()
    local system = love and love.system
    return system and system.getOS and system.getOS()
  end)
  if okNative and (nativeOS == "iOS" or nativeOS == "Android") then
    return nativeOS
  end
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  if okPlatform and type(Platform) == "table" and type(Platform.detect) == "function" then
    local okDetect, info = pcall(Platform.detect)
    if okDetect and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  if okNative and type(nativeOS) == "string" then return nativeOS end
  return "Unknown"
end

local function isAndroid()
  return platformName():lower() == "android"
end

Bridge.isAndroid = isAndroid

local function normalizeCameraMode(value)
  value = type(value) == "string" and value:lower() or value
  if value == "third" or value == "third_person" or value == "3rd" then
    return "third"
  elseif value == "first" or value == "first_person" or value == "1st" then
    return "first"
  elseif value == "15" or value == "angle15" then
    return "angle15"
  elseif value == "35" or value == "angle35" then
    return "angle35"
  elseif value == "50" or value == "angle50" then
    return "angle50"
  elseif value == "75" or value == "angle75" then
    return "angle75"
  end
  -- `diorama` was the pre-ladder VASC4J value. It represented VoxelState's
  -- FULL rung, so old saves migrate without losing their view.
  return "full"
end

local function optionCameraControl()
  local ok, value = pcall(mod.options.get, mod.options, "cameraControl")
  value = ok and type(value) == "string" and value:lower() or "stadium"
  if value == "stadium" or value == "selector" then return value end
  return "auto"
end

local function selectorDetected()
  if not (mod and type(mod.find) == "function") then return false end
  local ok, selector = pcall(mod.find, "red_3d_player")
  return ok and selector ~= nil
end

local function externalCameraEnabled()
  local control = optionCameraControl()
  local detected = selectorDetected()
  Bridge.selectorDetected = detected
  -- VASC4J owns its camera unless the user explicitly selects CHARACTER
  -- SELECTOR. Older saves may still contain AUTO; treating that value as
  -- local ownership makes the visible VOXEL VIEW row deterministic instead
  -- of silently replacing it with red_3d_player's previous pipeline rung.
  return control == "selector" and detected
end

-- 3D Character Selector v3.x changes the engine's public `voxel` pipeline
-- level to select its ZOOM / 1ST / 3RD modes.  This standalone Gold renderer
-- has its own private VoxelState, so without this bridge it would overwrite
-- that choice every frame.  Read the public pipeline label instead of hard-
-- coding rung numbers: upstream voxel mods are free to move the 1ST/3RD rungs.
local function selectorCameraMode()
  if not externalCameraEnabled() then return nil end
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not ok or type(Pipelines) ~= "table" then return nil end
  if type(Pipelines.get) == "function" and not Pipelines.get("voxel") then
    return nil
  end
  if type(Pipelines.level) ~= "function" then return nil end
  local level = Pipelines.level("voxel")
  local label = type(Pipelines.levelLabel) == "function"
    and Pipelines.levelLabel("voxel", level) or tostring(level)
  local upper = tostring(label or ""):upper()
  local mode
  if upper:find("3RD", 1, true) or upper:find("THIRD", 1, true) then
    mode = "third"
  elseif upper:find("1ST", 1, true) or upper:find("FIRST", 1, true) then
    mode = "first"
  elseif upper:find("75", 1, true) then
    mode = "angle75"
  elseif upper:find("50", 1, true) then
    mode = "angle50"
  elseif upper:find("35", 1, true) then
    mode = "angle35"
  elseif upper:find("15", 1, true) then
    mode = "angle15"
  else
    -- Character Selector's ordinary ZOOM/orbit state maps to this mod's
    -- diorama camera.  The voxel world remains enabled even if the external
    -- pipeline reports OFF for a transient frame during a mode change.
    mode = "full"
  end
  Bridge.externalCameraLevel = level
  Bridge.externalCameraLabel = label
  Bridge.cameraProvider = "red_3d_player"
  return mode
end

-- Shared with FirstPerson/GoldCameraControls.  They still mirror camera input
-- for this renderer, but must pass it through and must not rewrite movement
-- while the Character Selector owns the public camera state.
V.externalCameraOwner = externalCameraEnabled
V.externalCameraPassthrough = externalCameraEnabled

local function optionDioramaTilt()
  -- v0.2.54: Gold's own OPTIONS -> TILT row is the authoritative diorama
  -- camera pitch. The engine stores it as levels OFF/15/35/50 in
  -- game.options.tilt. Previously this mod had a separate DIORAMA TILT option,
  -- which meant changing the real OPTIONS row only warped/zoomed the native
  -- presentation while our voxel camera kept its old pitch. Mirror the native
  -- row directly into the real 3D camera instead.
  local game = Bridge.game
  local native = game and (game.options or (game.save and game.save.options))
  if type(native) == "table" and native.tilt ~= nil then
    local level = math.floor(tonumber(native.tilt) or 0)
    if level < 0 then level = 0 elseif level > 3 then level = 3 end
    -- Gold's native TILT defaults to OFF (level 0) on a fresh install.
    -- While the voxel renderer is explicitly enabled, treating that as a
    -- literal 0-degree voxel camera makes the real 3D terrain appear flat/2D.
    -- OFF therefore means "use the voxel diorama default"; the three explicit
    -- Gold tilt rungs still map 1:1 to 15/35/50 degrees. Turning 3D VOXEL
    -- WORLD off remains the actual way to return to Gold's native 2D world.
    local angles = { 35, 15, 35, 50 }
    return angles[level + 1]
  end

  -- Backward-compatible fallback for a frame before Game2 is bound, or for an
  -- older experimental host. Existing saves that still contain dioramaTilt
  -- continue to get a sensible camera until the native options table arrives.
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, "dioramaTilt")
    value = ok and tonumber(value) or nil
    if value == 0 or value == 15 or value == 35 or value == 50 or value == 75 then
      return value
    end
  end
  return 35
end

local function optionCameraMode()
  local control = optionCameraControl()
  -- An explicit in-world slider/F6 choice must not be undone one frame later
  -- by AUTO observing red_3d_player's previous public pipeline rung.  Keep the
  -- user's live choice authoritative in AUTO/STADIUM mode.  Choosing CAMERA
  -- CONTROL = CHARACTER SELECTOR explicitly hands ownership back and ignores
  -- this latch, so the compatibility path remains available on demand.
  if control ~= "selector" and Bridge.cameraOverride then
    Bridge.cameraProvider = "stadium-user"
    return normalizeCameraMode(Bridge.cameraOverride)
  end
  local external = selectorCameraMode()
  if external then return external end
  Bridge.cameraProvider = "stadium"
  Bridge.externalCameraLevel = nil
  Bridge.externalCameraLabel = nil
  local ok, value = pcall(mod.options.get, mod.options, "cameraMode")
  if not ok then return "full" end
  return normalizeCameraMode(value)
end

local function cameraLevelForMode(mode)
  mode = normalizeCameraMode(mode)
  if mode == "third" then return (Voxel and Voxel.TP_LEVEL) or 7 end
  if mode == "first" then return (Voxel and Voxel.FP_LEVEL) or 6 end
  if mode == "angle75" then return 5 end
  if mode == "angle50" then return 4 end
  if mode == "angle35" then return 3 end
  if mode == "angle15" then return 2 end
  return (Voxel and Voxel.FULL_LEVEL) or 1
end

Bridge.cameraLevelForMode = cameraLevelForMode
Bridge.normalizeCameraMode = normalizeCameraMode

local function selectorLevelForMode(mode)
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not ok or type(Pipelines) ~= "table"
     or type(Pipelines.levelLabels) ~= "function" then return nil end
  local labels = Pipelines.levelLabels("voxel")
  if type(labels) ~= "table" then return nil end
  mode = normalizeCameraMode(mode)
  local fallback = nil
  for i, label in ipairs(labels) do
    local upper = tostring(label or ""):upper()
    local level = i - 1
    local first = upper:find("1ST", 1, true) or upper:find("FIRST", 1, true)
    local third = upper:find("3RD", 1, true) or upper:find("THIRD", 1, true)
    if mode == "first" and first then return level end
    if mode == "third" and third then return level end
    if mode ~= "first" and mode ~= "third" and level > 0 and not first and not third then
      local wanted = ({ full="FULL", angle15="15", angle35="35",
                        angle50="50", angle75="75" })[mode]
      if wanted and upper:find(wanted, 1, true) then return level end
      if mode == "full" and (upper:find("ZOOM", 1, true)
         or upper:find("ORBIT", 1, true) or upper:find("FULL", 1, true)) then
        return level
      end
      fallback = fallback or level
    end
  end
  return fallback
end

local function setSelectorCameraMode(mode)
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not ok or type(Pipelines) ~= "table"
     or type(Pipelines.setLevel) ~= "function" then return false end
  local level = selectorLevelForMode(mode)
  if level == nil then return false end
  local okSet = pcall(Pipelines.setLevel, "voxel", level)
  if not okSet then return false end
  local game = Bridge.game
  if game and game.options and type(Pipelines.syncOptions) == "function" then
    pcall(Pipelines.syncOptions, game.options)
  end
  Bridge.externalCameraLevel = level
  Bridge.cameraProvider = "red_3d_player"
  return true
end

local function setCameraMode(mode, persist)
  mode = normalizeCameraMode(mode)
  Bridge.cameraOverride = mode
  if persist and mod.options and type(mod.options.set) == "function" then
    local ok, result = pcall(mod.options.set, mod.options, "cameraMode", mode)
    if ok and result ~= false then
      -- The public option bucket now owns the value; clear the temporary
      -- override so later Mod Manager changes can be observed normally.
      Bridge.cameraOverride = nil
    end
  end
  Bridge.cameraMode = mode
  Bridge.cameraLevel = cameraLevelForMode(mode)
  return mode
end

function Bridge.selectCameraMode(mode, persist, explicitControl)
  mode = normalizeCameraMode(mode)
  local control = optionCameraControl()

  -- A real user choice made during the short post-warp recovery window must
  -- win immediately.  Otherwise the recovery latch would keep writing the
  -- pre-warp rung for a few more frames and make the camera selector look as
  -- if it ignored the new input.
  Bridge.pendingPipelineRestoreMode = nil
  Bridge.pendingPipelineRestoreFrames = nil
  Bridge.pendingPipelineRestoreEnabled = nil
  Bridge.pendingPipelineRestoreStableFrames = nil

  -- CAMERA CONTROL = CHARACTER SELECTOR is the one mode where the external
  -- public voxel rung is deliberately authoritative.  Everywhere else an
  -- explicit slider/F6 action is a direct command to this renderer.  We still
  -- mirror the requested rung to red_3d_player when possible, but keep a local
  -- latch so AUTO cannot bounce DIORAMA straight back to the old 1ST/3RD rung.
  if control == "selector" and externalCameraEnabled() then
    if setSelectorCameraMode(mode) then
      Bridge.cameraOverride = nil
      Bridge.cameraMode = mode
      Bridge.cameraLevel = cameraLevelForMode(mode)
      return mode
    end
  end

  local result = setCameraMode(mode, persist ~= false)
  if explicitControl then
    Bridge.cameraOverride = mode
    if selectorDetected() then pcall(setSelectorCameraMode, mode) end
    Bridge.cameraProvider = "stadium-user"
  end
  return result
end

-- Called from both VASC's own option row and the engine Mod Manager's
-- `mod.options_changed` event. Engine/public-pipeline churn during a warp does
-- not emit that event, so an actual user OFF can cancel recovery without
-- letting a transient map reset masquerade as user intent.
function Bridge.handleUserVoxelOption(value)
  local enabled = toggleValue(value, false)
  if not enabled then
    Bridge.pendingPipelineRestoreMode = nil
    Bridge.pendingPipelineRestoreFrames = nil
    Bridge.pendingPipelineRestoreEnabled = nil
    Bridge.pendingPipelineRestoreStableFrames = nil
    Bridge.pendingPipelineRestoreAttemptLogged = nil
    Bridge.pendingWarpVoxelActive = nil
    Bridge.pendingWarpCameraMode = nil
  end
  diagnostic("gen2-voxel-user-switch", {
    enabled=enabled, map=Bridge.currentMapId or Bridge.mapId,
    camera=normalizeCameraMode(Bridge.cameraMode or optionCameraMode()),
    pipeline=selectorPipelineLevel(),
  })
  Bridge.active = enabled or optionOpenWorld()
  return Bridge.active
end

function Bridge.cycleCameraMode(persist)
  local current = optionCameraMode()
  return Bridge.selectCameraMode(CAMERA_NEXT[current] or CAMERA_ORDER[1],
    persist ~= false, true)
end

local function frameDt()
  local fallback = 1 / 60
  if not (love and love.timer and type(love.timer.getTime) == "function") then
    return fallback
  end
  local ok, now = pcall(love.timer.getTime)
  now = ok and tonumber(now) or nil
  if not now then return fallback end
  local prev = Bridge.lastTickTime
  Bridge.lastTickTime = now
  if not prev then return fallback end
  return math.max(1 / 240, math.min(1 / 15, now - prev))
end

local function monotonicTime()
  if love and love.timer and type(love.timer.getTime) == "function" then
    local ok, now = pcall(love.timer.getTime)
    if ok then return tonumber(now) end
  end
  return nil
end

local function stackTop(game)
  local stack = game and game.stack
  if not (stack and type(stack.top) == "function") then return nil end
  local ok, top = pcall(stack.top, stack)
  if ok then return top end
  return nil
end

local function goldFreeRoam(game)
  local world = game and game.world
  if not (type(world) == "table" and world.map ~= nil) then return false end
  local top = stackTop(game)
  return top == nil or (type(top) == "table" and top._stadiumCaptureOverlay == true)
end

local function fireCameraHotkey(game, fromPoll)
  -- Keep the capture rig stable for the duration of a throw. F6 resumes as
  -- soon as the transparent capture state leaves the stack.
  local top = stackTop(game)
  if top and top._stadiumCaptureOverlay == true then return false end
  if isAndroid() or not voxelModeEnabled() or not goldFreeRoam(game) then
    return false
  end
  local mode = Bridge.cycleCameraMode(true)
  Bridge.cameraHotkeyCycles = Bridge.cameraHotkeyCycles + 1
  if fromPoll then
    Bridge.cameraHotkeyPollCycles = Bridge.cameraHotkeyPollCycles + 1
  end
  local log = mod.log
  if log and type(log.info) == "function" then
    pcall(log.info, log, "Gold voxel camera: %s", tostring(mode))
  end
  if ShortcutToast and type(ShortcutToast.notify) == "function" then
    pcall(ShortcutToast.notify, "VOXEL VIEW", tostring(mode):upper())
  end
  return true
end

local function notifyHostHotkey(game, key)
  if not (ShortcutToast and type(ShortcutToast.notify) == "function") then return end
  local options = game and game.options or {}
  local title, value
  if key == "1" then
    title, value = "GAME SPEED", tostring(options.speed or 1) .. "X"
  elseif key == "2" then
    title, value = "COLOR", tostring(options.color or "GBC"):upper()
  elseif key == "3" then
    title, value = "TILT", tonumber(options.tilt) == 0
      and "OFF" or ("LEVEL " .. tostring(options.tilt))
  elseif key == "4" or key == "-" or key == "kp-"
      or key == "=" or key == "kp+" then
    title, value = "WORLD ZOOM", tostring(options.zoom or "AUTO")
  end
  if title then pcall(ShortcutToast.notify, title, value) end
end

-- F6 and V have two independent paths on desktop. The normal Game2 key callback is
-- lowest latency, while the frame poll below survives another mod replacing or
-- swallowing that callback later in the load order.  Both share one latch so a
-- single physical press can never advance two camera modes.
local function pollCameraHotkey(game)
  if isAndroid() or not (love and love.keyboard
      and type(love.keyboard.isDown) == "function") then
    Bridge.f6Down = false
    Bridge.vDown = false
    return false
  end
  local okF6, f6Down = pcall(love.keyboard.isDown, "f6")
  local okV, vDown = pcall(love.keyboard.isDown, "v")
  f6Down = okF6 and f6Down and true or false
  vDown = okV and vDown and true or false
  local pressed = (f6Down and not Bridge.f6Down)
    or (vDown and not Bridge.vDown)
  Bridge.f6Down, Bridge.vDown = f6Down, vDown
  if pressed then
    return fireCameraHotkey(game, true)
  end
  return false
end

local function installCameraHotkey(game)
  if type(game) ~= "table" then return false end
  if Bridge._hotkeyGame == game then return true end
  if Bridge._hotkeyGame ~= nil then return false end

  local inner = game.keypressed
  game.keypressed = function(self, key, ...)
    if key == "f6" or key == "v" then
      -- Mark the poll latch even if the key was pressed over a menu/battle.
      -- Re-entering free roam while the key is still held must not create a
      -- delayed camera switch.
      if key == "f6" then Bridge.f6Down = true else Bridge.vDown = true end
      if fireCameraHotkey(self, false) then return end
    end
    if inner then
      local results = packValues(inner(self, key, ...))
      notifyHostHotkey(self, key)
      return unpackValues(results, 1, results.n)
    end
  end
  Bridge._hotkeyGame = game
  return true
end

Bridge.pollCameraHotkey = pollCameraHotkey

function Bridge.setShortcutToast(toast)
  if toast ~= nil and type(toast) ~= "table" then return false end
  ShortcutToast = toast
  return true
end

local function cameraSliderRect()
  local G = love and love.graphics
  if not (G and type(G.getDimensions) == "function") then return nil end
  local ww, wh = G.getDimensions()
  if not (ww and wh and ww > 0 and wh > 0) then return nil end
  local w = math.max(250, math.min(380, ww * 0.42))
  local h = 70
  return (ww - w) * 0.5, 12, w, h
end

local function optionCameraSlider()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "cameraSlider")
  if not ok or value == nil then return true end
  return value ~= false
end

local function cameraSliderVisible(game)
  return isAndroid() and voxelModeEnabled() and optionCameraSlider()
     and goldFreeRoam(game or Bridge.game)
end

local function sliderModeAt(x)
  local sx, sy, sw = cameraSliderRect()
  if not sx then return nil end
  local pad = 28
  local left, right = sx + pad, sx + sw - pad
  local t = math.max(0, math.min(1, (x - left) / math.max(1, right - left)))
  local index = math.floor(t * 2 + 0.5) + 1
  return CAMERA_QUICK[math.max(1, math.min(3, index))]
end

local function touchInsideSlider(x, y)
  local sx, sy, sw, sh = cameraSliderRect()
  if not sx then return false end
  return x >= sx - 10 and x <= sx + sw + 10
     and y >= sy - 10 and y <= sy + sh + 12
end

local function installCameraSlider(game)
  if not isAndroid() then return true end
  if type(game) ~= "table" then return false end
  if Bridge._sliderGame == game then return true end
  if Bridge._sliderGame ~= nil then return false end

  local held = {}
  local function apply(x)
    local mode = sliderModeAt(x)
    if not mode then return end
    if optionCameraMode() ~= mode then
      Bridge.selectCameraMode(mode, true, true)
      Bridge.cameraSliderChanges = Bridge.cameraSliderChanges + 1
    end
  end

  do
    local inner = game.touchpressed
    game.touchpressed = function(self, id, x, y, ...)
      if cameraSliderVisible(self) and touchInsideSlider(x, y) then
        held[id] = true
        Bridge.cameraSliderTouches = Bridge.cameraSliderTouches + 1
        apply(x)
        return
      end
      if inner then return inner(self, id, x, y, ...) end
    end
  end

  do
    local inner = game.touchmoved
    game.touchmoved = function(self, id, x, y, ...)
      if held[id] then
        apply(x)
        return
      end
      if inner then return inner(self, id, x, y, ...) end
    end
  end

  do
    local inner = game.touchreleased
    game.touchreleased = function(self, id, x, y, ...)
      if held[id] then
        held[id] = nil
        apply(x)
        return
      end
      if inner then return inner(self, id, x, y, ...) end
    end
  end

  local innerFocus = game.focus
  game.focus = function(self, focused, ...)
    if not focused then held = {} end
    if innerFocus then return innerFocus(self, focused, ...) end
  end

  Bridge._sliderGame = game
  Bridge.cameraSliderInstalled = true
  return true
end


-- Android fallback: poll the live LOVE touch table every render frame.
-- Some Android builds route touches through the engine's overlay/pointer chain
-- in a way that can bypass a late instance-method wrapper. Polling is the
-- authoritative fallback because it observes the physical contacts directly.
local function updateCameraSliderTouches(game)
  if not cameraSliderVisible(game) then
    Bridge._sliderPollId = nil
    return false
  end
  local T = love and love.touch
  if not (T and type(T.getTouches) == "function" and type(T.getPosition) == "function") then
    return false
  end

  local okIds, ids = pcall(T.getTouches)
  if not okIds or type(ids) ~= "table" then return false end

  local active = Bridge._sliderPollId
  if active ~= nil then
    local found = false
    for _, id in ipairs(ids) do
      if id == active then
        found = true
        local okPos, x, y = pcall(T.getPosition, id)
        if okPos and type(x) == "number" and type(y) == "number" then
          local mode = sliderModeAt(x)
          if mode and optionCameraMode() ~= mode then
            Bridge.selectCameraMode(mode, true, true)
            Bridge.cameraSliderChanges = Bridge.cameraSliderChanges + 1
          end
        end
        break
      end
    end
    if not found then Bridge._sliderPollId = nil end
    return found
  end

  -- Capture only a touch that is currently inside the visible slider.  The
  -- virtual GB controls live at the bottom of the screen, so this never steals
  -- their contacts; touches elsewhere remain normal game/look/pinch input.
  for _, id in ipairs(ids) do
    local okPos, x, y = pcall(T.getPosition, id)
    if okPos and type(x) == "number" and type(y) == "number"
       and touchInsideSlider(x, y) then
      Bridge._sliderPollId = id
      Bridge.cameraSliderTouches = Bridge.cameraSliderTouches + 1
      local mode = sliderModeAt(x)
      if mode and optionCameraMode() ~= mode then
        Bridge.selectCameraMode(mode, true, true)
        Bridge.cameraSliderChanges = Bridge.cameraSliderChanges + 1
      end
      return true
    end
  end
  return false
end

Bridge.updateCameraSliderTouches = updateCameraSliderTouches

-- v0.2.00 Android right-thumb look fallback. The camera-mode slider proved
-- that some Android builds do not reliably deliver late Game2 touch wrappers,
-- so camera look observes LOVE's physical touch table directly as well. Only a
-- free touch on the right side is claimed; overlay controls and the camera
-- slider are ignored. Two simultaneous FREE right-side touches are left alone
-- for pinch zoom. This feeds FirstPerson.lookBy, the same yaw/pitch used by
-- both the 1ST/3RD free-roam camera and Gold's live-overworld battle shot.
local function updateRightLookTouches(game, battleActive)
  if not isAndroid() or not voxelModeEnabled() then
    Bridge._rightLookPollId = nil
    Bridge._rightLookPollX, Bridge._rightLookPollY = nil, nil
    return false
  end

  local mode = optionCameraMode()
  if mode ~= "first" and mode ~= "third" then
    Bridge._rightLookPollId = nil
    Bridge._rightLookPollX, Bridge._rightLookPollY = nil, nil
    return false
  end

  -- In free roam require the world to be the active view. During a live-world
  -- battle the battle state is intentionally on the stack, so battleActive is
  -- the explicit permission for the same camera to keep steering.
  if not battleActive and not goldFreeRoam(game or Bridge.game) then
    Bridge._rightLookPollId = nil
    Bridge._rightLookPollX, Bridge._rightLookPollY = nil, nil
    return false
  end

  local T = love and love.touch
  local G = love and love.graphics
  if not (T and type(T.getTouches) == "function" and type(T.getPosition) == "function"
       and G and type(G.getDimensions) == "function") then
    return false
  end
  local okIds, ids = pcall(T.getTouches)
  if not okIds or type(ids) ~= "table" then return false end
  local ww, wh = G.getDimensions()

  local TouchControls = nil
  pcall(function() TouchControls = require("src.core.TouchControls") end)
  local function controlAt(x, y)
    if not (TouchControls and type(TouchControls.hitTest) == "function") then return nil end
    local ok, hit = pcall(TouchControls.hitTest, TouchControls, x, y)
    return ok and hit or nil
  end
  local function freeRight(id)
    local ok, x, y = pcall(T.getPosition, id)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x < ww * 0.45 then return nil end
    if cameraSliderVisible(game or Bridge.game) and touchInsideSlider(x, y) then return nil end
    if controlAt(x, y) then return nil end
    return x, y
  end

  local candidates = {}
  for _, id in ipairs(ids) do
    local x, y = freeRight(id)
    if x then candidates[#candidates + 1] = { id = id, x = x, y = y } end
  end

  -- Two free fingers on the look side are a pinch gesture, not a camera turn.
  if #candidates > 1 then
    Bridge._rightLookPollId = nil
    Bridge._rightLookPollX, Bridge._rightLookPollY = nil, nil
    return false
  end
  if #candidates == 0 then
    Bridge._rightLookPollId = nil
    Bridge._rightLookPollX, Bridge._rightLookPollY = nil, nil
    return false
  end

  local c = candidates[1]
  if Bridge._rightLookPollId ~= c.id then
    Bridge._rightLookPollId = c.id
    Bridge._rightLookPollX, Bridge._rightLookPollY = c.x, c.y
    return true
  end

  local px, py = Bridge._rightLookPollX or c.x, Bridge._rightLookPollY or c.y
  local dx, dy = c.x - px, c.y - py
  Bridge._rightLookPollX, Bridge._rightLookPollY = c.x, c.y
  if dx ~= 0 or dy ~= 0 then
    -- Match FirstPerson's mobile-shooter convention: drag right looks right,
    -- drag up looks up. Scale by actual screen dimensions so sensitivity is
    -- stable from phones to tablets.
    local yaw = -(dx / math.max(320, ww)) * (2.2 * math.pi)
    local pitch = (dy / math.max(240, wh)) * (2.2 * math.pi)
    if battleActive then
      local okCam, BattleCinematic = pcall(V.require, "BattleCinematic")
      if okCam and BattleCinematic and type(BattleCinematic.manualLook) == "function" then
        BattleCinematic.manualLook(yaw, pitch)
      else
        FirstPerson.lookBy(yaw, pitch)
      end
    else
      FirstPerson.lookBy(yaw, pitch)
    end
    Bridge.rightLookFrames = (Bridge.rightLookFrames or 0) + 1
  end
  return true
end

Bridge.updateRightLookTouches = updateRightLookTouches

-- Direct Android pinch poll for DIORAMA. The callback-based pinch recognizer
-- is kept for desktop/debug hosts, but real Android builds have already shown
-- that late Game2 touch wrappers are not reliable enough. This watches LOVE's
-- physical contacts directly and changes the continuous diorama camera distance.
local function updateDioramaPinchTouches(game)
  if not isAndroid() or not voxelModeEnabled() or optionCameraMode() ~= "diorama"
     or not goldFreeRoam(game or Bridge.game) then
    Bridge._dioramaPinchA, Bridge._dioramaPinchB = nil, nil
    Bridge._dioramaPinchGap = nil
    return false
  end
  local T, G = love and love.touch, love and love.graphics
  if not (T and type(T.getTouches) == "function" and type(T.getPosition) == "function"
       and G and type(G.getDimensions) == "function") then return false end
  local okIds, ids = pcall(T.getTouches)
  if not okIds or type(ids) ~= "table" then return false end
  local TouchControls = nil
  pcall(function() TouchControls = require("src.core.TouchControls") end)
  local function free(id)
    local ok, x, y = pcall(T.getPosition, id)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if cameraSliderVisible(game or Bridge.game) and touchInsideSlider(x, y) then return nil end
    if TouchControls and type(TouchControls.hitTest) == "function" then
      local okHit, hit = pcall(TouchControls.hitTest, TouchControls, x, y)
      if okHit and hit then return nil end
    end
    return { id=id, x=x, y=y }
  end
  local freeTouches = {}
  for _, id in ipairs(ids) do
    local c = free(id)
    if c then freeTouches[#freeTouches+1] = c end
  end
  if #freeTouches < 2 then
    Bridge._dioramaPinchA, Bridge._dioramaPinchB = nil, nil
    Bridge._dioramaPinchGap = nil
    return false
  end
  local a, b = freeTouches[1], freeTouches[2]
  local dx, dy = a.x-b.x, a.y-b.y
  local gap = math.sqrt(dx*dx + dy*dy)
  if gap < 16 then return false end
  if Bridge._dioramaPinchA ~= a.id or Bridge._dioramaPinchB ~= b.id
     or not Bridge._dioramaPinchGap then
    Bridge._dioramaPinchA, Bridge._dioramaPinchB = a.id, b.id
    Bridge._dioramaPinchGap = gap
    return true
  end
  local factor = gap / math.max(1, Bridge._dioramaPinchGap)
  Bridge._dioramaPinchGap = gap
  if math.abs(factor - 1) > 0.008 then
    local okZoom, DioramaZoom = pcall(V.require, "DioramaZoom")
    if okZoom and DioramaZoom and type(DioramaZoom.scaleBy) == "function" then
      DioramaZoom.scaleBy(1 / factor)
      Bridge.dioramaPinchFrames = (Bridge.dioramaPinchFrames or 0) + 1
      return true
    end
  end
  return false
end

Bridge.updateDioramaPinchTouches = updateDioramaPinchTouches

function Bridge.drawCameraSlider(ctx)
  local game = Bridge.game
  if not cameraSliderVisible(game) then return false end
  local G = love and love.graphics
  if not G then return false end
  local sx, sy, sw, sh = cameraSliderRect()
  if not sx then return false end
  local pad = 28
  local left, right = sx + pad, sx + sw - pad
  local trackY = sy + 38
  local mode = optionCameraMode()
  local idx = (mode == "third" and 2) or (mode == "first" and 3) or 1
  local thumbX = left + (idx - 1) * (right - left) / 2
  local labels = { "FULL", "3RD", "1ST" }

  local ok = pcall(function()
    G.push("all")
    G.origin()
    G.setBlendMode("alpha")
    G.setColor(0, 0, 0, 0.58)
    G.rectangle("fill", sx, sy, sw, sh, 12, 12)
    G.setColor(1, 1, 1, 0.20)
    G.rectangle("line", sx, sy, sw, sh, 12, 12)
    G.setColor(1, 1, 1, 0.45)
    G.setLineWidth(4)
    G.line(left, trackY, right, trackY)
    for i = 1, 3 do
      local px = left + (i - 1) * (right - left) / 2
      G.setColor(1, 1, 1, 0.72)
      G.circle("fill", px, trackY, 5)
    end
    G.setColor(1, 1, 1, 1)
    G.circle("fill", thumbX, trackY, 11)
    G.setColor(0, 0, 0, 0.82)
    G.circle("fill", thumbX, trackY, 5)

    local font = type(G.getFont) == "function" and G.getFont() or nil
    for i, label in ipairs(labels) do
      local px = left + (i - 1) * (right - left) / 2
      local tw = font and font:getWidth(label) or (#label * 6)
      G.setColor(1, 1, 1, i == idx and 1 or 0.68)
      G.print(label, math.floor(px - tw / 2), sy + 7)
    end
    G.pop()
  end)
  if not ok then pcall(G.pop) return false end
  return true
end

Bridge.cameraSliderVisible = cameraSliderVisible
Bridge.cameraSliderRect = cameraSliderRect

local function bindGame(game)
  if type(game) ~= "table" then return false end
  Bridge.game = game
  V.game = game
  installCameraHotkey(game)
  if FirstPerson and type(FirstPerson.install) == "function"
     and not Bridge.cameraInputInstalled then
    local ok, result, err = pcall(FirstPerson.install, game)
    if ok and result ~= false then
      Bridge.cameraInputInstalled = true
      Bridge.cameraInputError = nil
    else
      Bridge.cameraInputError = tostring(ok and err or result)
      logOnce("camera-input:" .. Bridge.cameraInputError, "warn",
        "Gold first/third-person camera input hooks unavailable: %s",
        Bridge.cameraInputError)
    end
  end
  -- Install the shared camera input owner AFTER FirstPerson, as CamControl's
  -- wraps are intentionally the outer layer. This activates two-finger pinch
  -- zoom on the voxel world without letting the same gesture also become a
  -- first/third-person look drag. It also keeps wheel/pad zoom routing in one
  -- place instead of adding a Gold-only touch implementation.
  if CamControl and type(CamControl.install) == "function"
     and not Bridge.pinchZoomInstalled then
    local ok, result, err = pcall(CamControl.install, game)
    if ok and result ~= false then
      Bridge.pinchZoomInstalled = true
      Bridge.pinchZoomError = nil
    else
      Bridge.pinchZoomError = tostring(ok and err or result)
      logOnce("pinch-zoom:" .. Bridge.pinchZoomError, "warn",
        "Gold voxel pinch-zoom hooks unavailable: %s",
        Bridge.pinchZoomError)
    end
  end

  if not Bridge.cameraSliderInstalled then
    local okSlider, sliderResult = pcall(installCameraSlider, game)
    if not okSlider or sliderResult == false then
      logOnce("camera-slider-install", "warn",
        "Gold Android camera-mode slider unavailable")
    end
  end

  if GoldCameraControls and type(GoldCameraControls.install) == "function"
     and not Bridge.cameraMovementInstalled then
    local ok, result, err = pcall(GoldCameraControls.install)
    if ok and result ~= false then
      Bridge.cameraMovementInstalled = true
      Bridge.cameraMovementError = nil
    else
      Bridge.cameraMovementError = tostring(ok and err or result)
      logOnce("camera-movement:" .. Bridge.cameraMovementError, "warn",
        "Gold camera-relative movement hook unavailable: %s",
        Bridge.cameraMovementError)
    end
  end
  return true
end

function Bridge.setGame(game)
  return bindGame(game)
end

logOnce = function(key, level, fmt, ...)
  Bridge._logged = Bridge._logged or {}
  if Bridge._logged[key] then return end
  Bridge._logged[key] = true
  local log = mod.log
  local fn = log and log[level]
  if type(fn) == "function" then pcall(fn, log, fmt, ...) end
end

local function geometrySignature(map, warmup)
  warmup = warmup or CurrentMapWarmup
  if warmup and type(warmup.geometrySignature) == "function" then
    local ok, signature = pcall(warmup.geometrySignature, map)
    if ok then return signature end
    return nil, tostring(signature)
  end
  return nil, "Gen-2 map geometry signature is unavailable"
end

-- Preserve a destination body prepared as a neighbour only when its complete
-- geometry contract still matches.  Crystal rebuilds a Map object for every
-- setMap and may run MAPCALLBACK_TILES before map.entered; object identity
-- alone would throw away valid connection warmups, while id alone can expose
-- a stale callback result.  The exact signature is the narrow middle ground.
local function rememberMapGeometry(map, mesher, warmup)
  if not (type(map) == "table" and map.id ~= nil) then
    return false, false, "invalid Gen-2 map lifecycle input"
  end
  mesher = mesher or ChunkMesher
  local signature, signatureErr = geometrySignature(map, warmup)
  if signature == nil then return false, false, signatureErr end

  local id = map.id
  local previous = mapGeometrySignatures[id]
  local cachedError = nil
  if mesher and type(mesher.lastError) == "function" then
    local okError, value = pcall(mesher.lastError, id)
    if not okError then
      return false, false, "Gen-2 map cache error probe failed for "
        .. tostring(id) .. ": " .. tostring(value)
    end
    cachedError = value
  end
  local stale = previous ~= nil and previous ~= signature
  local liveEdit = mapGeometryDirty[id] == true
  local mustRetry = cachedError ~= nil
  local invalidated = false
  if stale or liveEdit or mustRetry then
    if not (mesher and type(mesher.invalidate) == "function") then
      return false, false,
        "Gen-2 stale map cache cannot be invalidated for " .. tostring(id)
    end
    local okInvalidate, invalidateErr = pcall(mesher.invalidate, id)
    if not okInvalidate then
      return false, false, "Gen-2 map cache invalidation failed for "
        .. tostring(id) .. ": " .. tostring(invalidateErr)
    end
    invalidated = true
    Bridge.mapGeometryInvalidations =
      (tonumber(Bridge.mapGeometryInvalidations) or 0) + 1
  end
  mapGeometrySignatures[id] = signature
  mapGeometryDirty[id] = nil
  return true, invalidated, nil
end

local function markMapGeometryDirty(mapId)
  if mapId == nil then return false end
  mapGeometryDirty[mapId] = true
  return true
end

local function resetMapRoot(map, reason, force, deps)
  deps = type(deps) == "table" and deps or {}
  if not force and Bridge.currentMapRef == map then return false, false, nil end

  local mesher = deps.mesher or ChunkMesher
  local warmup = deps.currentWarmup or CurrentMapWarmup
  local neighborWarmup = deps.neighborWarmup or NeighborWarmup
  local geometryOK, invalidated, geometryErr = true, false, nil
  if map ~= nil then
    geometryOK, invalidated, geometryErr =
      rememberMapGeometry(map, mesher, warmup)
  end

  if warmup and type(warmup.reset) == "function" then
    pcall(warmup.reset, Bridge, map)
  else
    Bridge.syncBuildMapId = nil
    Bridge.syncBuildMapRef = nil
    Bridge.syncBuildAttemptMapId = nil
    Bridge.syncBuildAttemptMapRef = nil
    Bridge.asyncBuildFailedMapId = nil
  end
  if neighborWarmup and type(neighborWarmup.reset) == "function" then
    pcall(neighborWarmup.reset, neighborWarmupState)
  else
    neighborWarmupState = {}
  end

  -- Every root owns its own progressive adapter queue and graph coordinates.
  -- Retain GPU meshes through ChunkMesher's bounded live/previous policy, but
  -- never retain Lua records positioned relative to the map just left.
  neighborMapCache = {}
  openWorldGraphCache = {
    rootId = nil, maps = nil, maxDepth = nil, specs = nil,
  }
  V.goldNeighbors = {}
  V.goldOpenWorldMaps = {}
  Bridge.neighborWarmupPending = false
  Bridge.neighborDirectComplete = false
  Bridge.neighborWarmupError = nil
  Bridge.openWorldMaps = 0
  Bridge.openWorldDirectMaps = 0
  Bridge.openWorldGraphRoot = nil
  Bridge.openWorldGraphError = nil
  local previousFrame = Bridge.lastPresentedFrame
  if type(previousFrame) == "table" and previousFrame.canvas ~= nil
      and map ~= nil and Bridge.active == true and voxelModeEnabled() then
    local previousW, previousH = frameDimensions(previousFrame)
    Bridge.mapTransitionHold = {
      canvas = previousFrame.canvas,
      canvasWidth = previousW,
      canvasHeight = previousH,
      targetMap = map,
      targetMapId = map.id,
      frames = 0,
    }
  else
    Bridge.mapTransitionHold = nil
  end
  Bridge.currentOnlyPresentedMapId = nil
  Bridge.currentOnlyPresentedMapRef = nil
  Bridge.lastPresentedFrame = nil
  Bridge.currentMapRef = map
  Bridge.currentMapId = map and map.id or nil
  Bridge.mapId = Bridge.currentMapId
  Bridge.mapTransitionSerial = (tonumber(Bridge.mapTransitionSerial) or 0) + 1
  Bridge.mapTransitionResets = (tonumber(Bridge.mapTransitionResets) or 0) + 1
  Bridge.mapLifecycleReason = tostring(reason or "observed")
  if geometryOK then
    Bridge.mapLifecycleError = nil
  else
    Bridge.mapLifecycleError = tostring(geometryErr)
  end
  Bridge.lastError = nil

  if map and Bridge.pendingWarpMapId == map.id then
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    Bridge.warpPrefetchError = nil
  end
  return true, invalidated, geometryErr
end

-- Last complete 3D frame while the new root is still warming. Exact target
-- identity prevents a stale canvas surviving a second warp or a mode change.
function Bridge.transitionHoldCanvas(world)
  local hold = Bridge.mapTransitionHold
  local map = type(world) == "table" and world.map or nil
  if not (type(hold) == "table" and hold.canvas ~= nil and map ~= nil
      and hold.targetMap == map and hold.targetMapId == map.id
      and Bridge.active == true and voxelModeEnabled()) then
    Bridge.mapTransitionHold = nil
    return nil
  end
  local expectedW, expectedH = currentDrawableDimensions()
  local holdW, holdH = positiveDimensions(
    hold.canvasWidth, hold.canvasHeight)
  if not holdW then holdW, holdH = canvasDimensions(hold.canvas) end
  if expectedW and holdW
      and (expectedW ~= holdW or expectedH ~= holdH) then
    Bridge.mapTransitionHold = nil
    diagnostic("gen2-transition-hold-invalidated", {
      reason="drawable-dimensions-changed",
      fromWidth=holdW, fromHeight=holdH,
      toWidth=expectedW, toHeight=expectedH,
      map=map and map.id,
    })
    return nil
  end
  hold.frames = (tonumber(hold.frames) or 0) + 1
  Bridge.mapTransitionHoldFrames =
    (tonumber(Bridge.mapTransitionHoldFrames) or 0) + 1
  -- A normal warm-up is measured in frames, not seconds. Bound the bridge so
  -- a permanently broken renderer still reaches the ordinary native fallback.
  if hold.frames > 360 then
    Bridge.mapTransitionHold = nil
    return nil
  end
  return hold.canvas
end

function Bridge.onMapEntered(payload, deps)
  local wasVoxelActive = Bridge.pendingWarpVoxelActive == true
    or Bridge.active == true or configuredVoxelModeEnabled()
  -- optionCameraMode() is the authoritative *current* user view.  It already
  -- includes an explicit in-world override when present.  Bridge.cameraMode
  -- starts at FULL before the first rendered frame, so consulting that cached
  -- field first incorrectly replaced a saved 1ST/3RD choice during Crystal's
  -- boot map.entered event.
  local preservedMode = normalizeCameraMode(
    Bridge.pendingWarpCameraMode or optionCameraMode())
  local map = type(payload) == "table" and payload.map or nil
  local via = type(payload) == "table" and payload.via or nil
  if map == nil then
    local world = Bridge.game and Bridge.game.world
    local wanted = type(payload) == "table" and payload.mapId or nil
    if world and world.map and (wanted == nil or world.map.id == wanted) then
      map = world.map
    end
  end
  local ok, invalidated, err = resetMapRoot(map,
    via ~= nil and ("map.entered:" .. tostring(via)) or "map.entered", true,
    deps)
  if ok and wasVoxelActive then
    Bridge.pendingPipelineRestoreMode = preservedMode
    -- Map replacement and Character Selector do not complete in a guaranteed
    -- event order.  A one-shot set can succeed and then be overwritten by the
    -- selector's later map-root reset in the same frame.  Hold the exact
    -- pre-warp rung across a short rendered-frame window instead.
    -- Cold Crystal maps can legitimately spend longer than 30 frames in the
    -- cooperative mesher. End only after three rendered frames on the new map;
    -- this ceiling exists solely as a safety net.
    Bridge.pendingPipelineRestoreEnabled = true
    Bridge.pendingPipelineRestoreFrames = 360
    Bridge.pendingPipelineRestoreStableFrames = 0
    Bridge.pendingPipelineRestoreAttemptLogged = nil
    diagnostic("gen2-voxel-map-entered", {
      map=map and map.id, via=via, beforeActive=wasVoxelActive,
      configured=configuredVoxelModeEnabled(), camera=preservedMode,
      pipeline=selectorPipelineLevel(), reset=ok,
      invalidated=invalidated,
    })
  else
    diagnostic("gen2-voxel-map-entered", {
      map=map and map.id, via=via, beforeActive=wasVoxelActive,
      configured=configuredVoxelModeEnabled(), camera=preservedMode,
      pipeline=selectorPipelineLevel(), reset=ok, recovery=false,
      reason=err,
    })
  end
  Bridge.pendingWarpVoxelActive = nil
  Bridge.pendingWarpCameraMode = nil
  return ok, invalidated, err
end

local function ensurePlayerPose()
  -- Requiring the explicit Gen-2 class is intentional here: this is a Gen-2
  -- only package and VoxelScene consumes the entity pose contract directly.
  local okPlayer, Player = pcall(require, "src.world.gen2.Player")
  if not okPlayer or type(Player) ~= "table" then
    return false, tostring(Player or "Gen-2 Player unavailable")
  end
  if type(Player.pose) ~= "function" then
    function Player:pose()
      local y = self.py + (self.spriteYOffset or 0)
      return self.sprite, self.px, y, self.facing,
        (self.walkPhase and self:walkPhase()) or 0,
        self.stepFlip == true, false
    end
  end
  return true
end

-- Gold keys generated tilesets with engine constants such as
-- `TILESET_JOHTO`, while Dramatic Shapes' authored voxel profile predates
-- that cache vocabulary and is keyed as `TilesetJohto`.  The tileset object
-- itself is returned by World:atlasFor and can therefore carry the engine
-- key in `id`; passing that straight through makes every authored Gen-2
-- shape silently miss and fall back to generic solid boxes.
--
-- Translate only the engine's TILESET_* spelling.  Gen-1 ids (OVERWORLD,
-- FOREST, etc.) and already-canonical Gen-2 ids are returned unchanged.
local function profileTilesetId(raw)
  if type(raw) ~= "string" or raw:sub(1, 8) ~= "TILESET_" then
    return raw
  end
  local out = { "Tileset" }
  for word in raw:sub(9):gmatch("[^_]+") do
    local lower = word:lower()
    out[#out + 1] = lower:sub(1, 1):upper() .. lower:sub(2)
  end
  return table.concat(out)
end

-- Exposed for the headless compatibility probe; harmless to runtime callers.
Bridge.profileTilesetId = profileTilesetId

local function attachRenderer(world, map)
  if not (world and map and map.def) then
    return false, "Gold map/definition not ready"
  end
  if type(world.atlasFor) ~= "function" then
    return false, "Gold World:atlasFor is unavailable"
  end

  -- Voxel terrain UVs sample a TILESET ATLAS, not Gold's already-baked whole
  -- map canvas. Reuse World:atlasFor so roofs/asset overrides resolve through
  -- the exact same live Gen-2 path as vanilla Gold.
  local ok, atlas, tileset = pcall(world.atlasFor, world, map.def)
  if not ok then return false, "Gold atlasFor failed: " .. tostring(atlas) end
  if not atlas then return false, "Gold atlasFor returned no tileset atlas" end

  map.tileset = tileset or map.tileset

  -- IMPORTANT: map.def.tileset remains the engine key (for example
  -- TILESET_JOHTO); only the tileset record's presentation id is normalised
  -- for the voxel modules.  Gen1Recomp itself indexes world.tilesets by
  -- map.def.tileset, so changing this field does not disturb the engine's
  -- lookup, while TileShape/Structures/Buildings can finally find their
  -- authored Gen-2 profile rows.
  if map.tileset then
    local engineId = map.def.tileset or map.tileset.id
    local profileId = profileTilesetId(engineId)
    if profileId then
      map.tileset._stadiumEngineTilesetId =
        map.tileset._stadiumEngineTilesetId or map.tileset.id or engineId
      map.tileset.id = profileId
    end
  end

  map.renderer = map.renderer or {}
  map.renderer.data = (world.game and world.game.data) or map.renderer.data

  -- Gold's generated tileset sheet is intentionally four-shade source art.
  -- The native 2D renderer assigns one of eight GBC palettes PER 8x8 tile at
  -- draw/bake time. Voxel geometry samples the atlas directly, so feeding it
  -- World:atlasFor's raw sheet produces a correct-but-monochrome world. Bake
  -- that same Gen-2 PalMap into a private atlas before the voxel mesh sees it.
  if not GoldColorAtlas then
    local okColor, moduleOrErr = pcall(V.require, "GoldColorAtlas")
    if okColor and type(moduleOrErr) == "table" then
      GoldColorAtlas = moduleOrErr
    else
      logOnce("gold-color-module:" .. tostring(moduleOrErr), "warn",
        "Gold voxel GBC-color adapter unavailable; raw atlas fallback: %s",
        tostring(moduleOrErr))
    end
  end

  local image, pixels, colored, colorErr, colorKey = atlas, nil, false, nil, nil
  if GoldColorAtlas and type(GoldColorAtlas.forMap) == "function" then
    local okColor, a, b, c, d, e = pcall(GoldColorAtlas.forMap, world, map, atlas)
    if okColor then
      image, pixels, colored, colorErr, colorKey = a or atlas, b, c == true, d, e
    else
      colorErr = tostring(a)
    end
  end

  map.renderer.image = image or atlas
  map.renderer.gbcAtlas = colored == true
  map.renderer._stadiumAtlasData = colored and pixels or nil
  map.renderer._stadiumColorKey = colored and colorKey or nil
  map.renderer._stadiumGen2Color = colored == true
  if not colored and colorErr then
    logOnce("gold-color-fallback:" .. tostring(colorErr), "warn",
      "Gold voxel color atlas fell back to raw source art: %s", tostring(colorErr))
  end
  return true
end

-- Gold's native 2D renderer keeps connected areas as lightweight image records
-- (`{ id, ox, oy, image }`).  VoxelScene needs actual Map objects so it can
-- mesh the next area before the player crosses the seam.  v0.2.04 adapts the
-- DIRECT connection in each cardinal direction -- one whole map ahead -- and
-- keeps those maps warm as body-only neighbour meshes.  This is intentionally
-- a renderer-side adapter: Gold's own map transition/collision code remains the
-- authority and is never replaced.
local CARDINAL_CONNECTIONS = { "north", "south", "west", "east" }
local EDGE_URGENT_CELLS = 8

local function goldMapModule()
  if GoldMap then return GoldMap end
  local ok, Map = pcall(require, "src.world.gen2.Map")
  if ok and type(Map) == "table" and type(Map.new) == "function" then
    GoldMap = Map
    return GoldMap
  end
  return nil
end

local function nativeNeighborIndex(world)
  local native = {}
  for _, nb in ipairs(world and world.neighbors or {}) do
    if nb and nb.id then native[nb.id] = nb end
  end
  return native
end

local function connectionPlacement(sourceDef, targetDef, conn, dir, sourceOx, sourceOy)
  local offset = tonumber(conn and conn.offset) or 0
  sourceOx, sourceOy = tonumber(sourceOx) or 0, tonumber(sourceOy) or 0
  if dir == "north" then
    return sourceOx + offset * 32, sourceOy - targetDef.height * 32
  elseif dir == "south" then
    return sourceOx + offset * 32, sourceOy + sourceDef.height * 32
  elseif dir == "west" then
    return sourceOx - targetDef.width * 32, sourceOy + offset * 32
  else -- east
    return sourceOx + sourceDef.width * 32, sourceOy + offset * 32
  end
end

local function directNeighborSpecs(world)
  local root = world and world.map and world.map.def
  local maps = world and world.maps
  if not (root and maps) then return {} end

  local native = nativeNeighborIndex(world)
  local out, seen = {}, {}
  for _, dir in ipairs(CARDINAL_CONNECTIONS) do
    local conn = root.connections and root.connections[dir]
    local id = conn and (conn.mapId or conn.map)
    local def = id and maps[id] or nil
    if def and not seen[id] then
      seen[id] = true
      local n = native[id]
      local ox, oy = n and tonumber(n.ox), n and tonumber(n.oy)
      if not (ox and oy) then
        ox, oy = connectionPlacement(root, def, conn, dir, 0, 0)
      end
      out[#out + 1] = {
        id = id, dir = dir, ox = ox, oy = oy, native = n, depth = 1,
        parentId = world.map.id or root.id,
      }
    end
  end
  return out
end

local function neighborUrgent(world, dir)
  local p = world and world.player
  local def = world and world.map and world.map.def
  if not (p and def) then return false end
  local x, y = tonumber(p.cellX), tonumber(p.cellY)
  if not (x and y) then return false end
  local w, h = (tonumber(def.width) or 0) * 2, (tonumber(def.height) or 0) * 2
  if dir == "north" then return y <= EDGE_URGENT_CELLS end
  if dir == "south" then return y >= h - 1 - EDGE_URGENT_CELLS end
  if dir == "west" then return x <= EDGE_URGENT_CELLS end
  if dir == "east" then return x >= w - 1 - EDGE_URGENT_CELLS end
  return false
end

local function placementRect(def, ox, oy)
  if not def then return nil end
  ox, oy = tonumber(ox) or 0, tonumber(oy) or 0
  return {
    x1 = ox, y1 = oy,
    x2 = ox + (tonumber(def.width) or 0) * 32,
    y2 = oy + (tonumber(def.height) or 0) * 32,
  }
end

local function placementOverlap(a, b)
  if not (a and b) then return 0 end
  local w = math.min(a.x2, b.x2) - math.max(a.x1, b.x1)
  local h = math.min(a.y2, b.y2) - math.max(a.y1, b.y1)
  if w <= 0 or h <= 0 then return 0 end
  return w * h
end

local function overlapsPlaced(rect, placed, exceptId)
  for id, other in pairs(placed or {}) do
    if id ~= exceptId and placementOverlap(rect, other.rect) > 0 then
      return id, other
    end
  end
  return nil
end

-- OPEN WORLD walks only the camera policy's bounded number of cardinal rings
-- and solves those maps into one coordinate space rooted at the CURRENT map.
-- Doors, caves and buildings reached by warps are intentionally excluded: they
-- are not physically adjacent terrain and must not be glued into the outdoor
-- plane. Breadth-first order queues direct areas first, then the allowed farther
-- rings, so zooming out can grow smoothly without admitting the whole region.
local function allConnectedNeighborSpecs(world, maxDepth)
  local rootMap = world and world.map
  local root = rootMap and rootMap.def
  local maps = world and world.maps
  if not (rootMap and root and maps) then return {} end
  local rootId = rootMap.id or root.id
  maxDepth = math.max(1, math.floor(tonumber(maxDepth) or math.huge))

  if openWorldGraphCache.rootId == rootId
      and openWorldGraphCache.maps == maps
      and openWorldGraphCache.maxDepth == maxDepth
      and type(openWorldGraphCache.specs) == "table" then
    return openWorldGraphCache.specs
  end

  local native = nativeNeighborIndex(world)
  local out, seen = {}, { [rootId] = true }
  local placed = {
    [rootId] = { id = rootId, def = root, ox = 0, oy = 0,
      rect = placementRect(root, 0, 0) },
  }
  local queue = { { id = rootId, def = root, ox = 0, oy = 0, depth = 0 } }
  local head = 1
  while head <= #queue do
    local source = queue[head]
    head = head + 1
    if source.depth < maxDepth then
      for _, dir in ipairs(CARDINAL_CONNECTIONS) do
      local conn = source.def.connections and source.def.connections[dir]
      local id = conn and (conn.mapId or conn.map)
      local def = id and maps[id] or nil
      if def and not seen[id] then
        local ox, oy
        -- Gold's own neighbour builder is the coordinate authority whenever it
        -- already knows this map (it keeps more than the immediate ring warm).
        -- v0.2.45-v0.2.56 only trusted native offsets at depth 1, then solved
        -- deeper maps independently; on some connection loops that let a far
        -- map land on TOP of the current map. Collision stayed correct because
        -- Gold still owned movement, but the overlapping voxel mesh painted a
        -- different road/grass layout under the player: the "invisible road"
        -- failure reported in v0.2.56.
        local n = native[id]
        if n then ox, oy = tonumber(n.ox), tonumber(n.oy) end
        if not (ox and oy) then
          ox, oy = connectionPlacement(source.def, def, conn, dir,
                                       source.ox, source.oy)
        end

        local rect = placementRect(def, ox, oy)
        local clashId = overlapsPlaced(rect, placed, id)
        if clashId then
          -- Cardinally stitched map BODIES may touch at an edge but should not
          -- occupy the same world pixels. Skip an inconsistent placement rather
          -- than allowing a far map to visually overwrite the collision-authority
          -- current map. Leaving it unseen lets another graph path place it later.
          Bridge.openWorldOverlapRejects = (Bridge.openWorldOverlapRejects or 0) + 1
          if logOnce then
            logOnce(("open-world-overlap:%s:%s:%s"):format(tostring(rootId),
                tostring(id), tostring(clashId)), "warn",
              "OPEN WORLD skipped overlapping map placement %s over %s",
              tostring(id), tostring(clashId))
          end
        else
          local rec = {
            id = id, dir = dir, ox = ox, oy = oy, depth = source.depth + 1,
            parentId = source.id,
          }
          out[#out + 1] = rec
          seen[id] = true
          placed[id] = { id = id, def = def, ox = ox, oy = oy, rect = rect }
          queue[#queue + 1] = {
            id = id, def = def, ox = ox, oy = oy, depth = rec.depth,
          }
        end
      end
      end
    end
  end

  openWorldGraphCache = {
    rootId = rootId, maps = maps, maxDepth = maxDepth, specs = out,
  }
  Bridge.openWorldGraphBuilds = Bridge.openWorldGraphBuilds + 1
  Bridge.openWorldGraphRoot = rootId
  Bridge.openWorldGraphError = nil
  return out
end

-- Internal probes used by the release regression suite. They are intentionally
-- underscored and do not participate in the public mod API.
Bridge._allConnectedNeighborSpecs = allConnectedNeighborSpecs
Bridge._placementOverlap = placementOverlap

local function adaptedNeighborMap(world, id)
  local maps, tilesets = world and world.maps, world and world.tilesets
  local def = maps and maps[id]
  local sourceTileset = def and tilesets and tilesets[def.tileset]
  local Map = goldMapModule()
  if not (def and sourceTileset and Map) then
    return nil, "missing Gold neighbour map/tileset adapter data"
  end

  local hit = neighborMapCache[id]
  if not hit or hit.def ~= def or hit.sourceTileset ~= sourceTileset
      or hit.blocks ~= def.blocks then
    local ok, map = pcall(Map.new, def, sourceTileset)
    if not ok or type(map) ~= "table" then
      return nil, "Gold neighbour Map.new failed: " .. tostring(map)
    end
    hit = { map = map, def = def, sourceTileset = sourceTileset, blocks = def.blocks }
    neighborMapCache[id] = hit
  end

  local ok, err = attachRenderer(world, hit.map)
  if not ok then return nil, err end
  local geometryOK, _, geometryErr = rememberMapGeometry(hit.map)
  if not geometryOK then return nil, geometryErr end
  return hit.map
end

-- A Gen-2 warp announces its destination before the cartridge's existing
-- fade starts.  Warm exactly that destination's body mesh during the covered
-- frames.  This changes no map, collision, warp or transition state; if any
-- adapter/build step declines, the normal current-map async gate takes over on
-- arrival and Gold/Silver/Crystal keep drawing their native 2D frame meanwhile.
local function prewarmPendingWarp(world)
  local id = Bridge.pendingWarpMapId
  if not id or not (world and ChunkMesher) then return false end
  if world.map and world.map.id == id then
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    return false
  end
  if not (world.mapSetup or world.fade) then return false end

  local okMap, mapOrErr, adaptErr = pcall(adaptedNeighborMap, world, id)
  local map = okMap and mapOrErr or nil
  if not map then
    Bridge.warpPrefetchFailures = Bridge.warpPrefetchFailures + 1
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    Bridge.warpPrefetchError = tostring(okMap and adaptErr or mapOrErr)
    return false
  end

  local okRequest, requestErr = pcall(ChunkMesher.request,
    map, true, nil, true, 3)
  if not okRequest then
    Bridge.warpPrefetchFailures = Bridge.warpPrefetchFailures + 1
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    Bridge.warpPrefetchError = tostring(requestErr)
    return false
  end
  if Bridge.pendingWarpRequestedMapId ~= id then
    Bridge.pendingWarpRequestedMapId = id
    Bridge.warpPrefetches = Bridge.warpPrefetches + 1
  end
  local okPump, pumpErr = pcall(ChunkMesher.pump, true)
  if not okPump then
    Bridge.warpPrefetchFailures = Bridge.warpPrefetchFailures + 1
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    Bridge.warpPrefetchError = tostring(pumpErr)
    return false
  end
  if type(ChunkMesher.peek) == "function" and ChunkMesher.peek(map, true) then
    Bridge.warpPrefetchReady = Bridge.warpPrefetchReady + 1
    Bridge.pendingWarpMapId = nil
    Bridge.pendingWarpRequestedMapId = nil
    Bridge.warpPrefetchError = nil
    return true
  end
  -- A successful bounded pump was consumed even when the body needs another
  -- fade frame. The caller uses this receipt to avoid pumping the same main
  -- thread two or three times in one presentation frame.
  return true
end

local function adaptedNeighbors(world, limit)
  local openWorld = optionOpenWorld()
  -- Read the public option every rendered frame, then apply it as a residency
  -- mode change. v0.2.45 accidentally crashed below before this could produce
  -- a valid voxel state, which made ON/OFF look identical in game.
  applyOpenWorldMode(openWorld)

  local stream = OpenWorldStreaming
      and type(OpenWorldStreaming.status) == "function"
      and OpenWorldStreaming.status(openWorld, optionCameraMode())
    or { depth = 1, zoom = 1 }
  local maxDepth = math.max(1, math.floor(tonumber(stream.depth) or 1))
  Bridge.openWorldDepth = maxDepth
  Bridge.openWorldZoom = tonumber(stream.zoom) or 1

  local admissionLimit = math.min(1,
    math.max(0, math.floor(tonumber(limit) or 1)))
  local specs
  if openWorld and admissionLimit > 0 then
    local ok, result = pcall(allConnectedNeighborSpecs, world, maxDepth)
    if ok and type(result) == "table" then
      specs = result
      Bridge.openWorldGraphError = nil
    else
      Bridge.openWorldFallbacks = Bridge.openWorldFallbacks + 1
      Bridge.openWorldGraphError = tostring(result)
      specs = directNeighborSpecs(world)
      logOnce("open-world-graph:" .. tostring(result), "warn",
        "OPEN WORLD graph build failed; using direct-map streaming this frame: %s",
        tostring(result))
    end
  else
    -- The startup/body-only frame must remain bounded even with OPEN WORLD
    -- enabled. Discovering the complete region graph is renderer work too;
    -- defer it until the current BODY has actually reached the screen. The
    -- real cardinal connection table is still captured here, so the first
    -- background frame starts with every true immediate neighbour.
    specs = directNeighborSpecs(world)
  end

  local native = nativeNeighborIndex(world)
  local function build(spec)
    local map, err = adaptedNeighborMap(world, spec.id)
    if map then
      local depth = tonumber(spec.depth) or 1
      local rec = {
        id = spec.id, map = map, ox = spec.ox, oy = spec.oy, dir = spec.dir,
        depth = depth, parentId = spec.parentId,
        -- Only a directly connected destination near the player gets urgent
        -- build time. Far maps stay cooperative background jobs so OPEN WORLD
        -- never starves the terrain currently under the player.
        urgent = depth == 1 and neighborUrgent(world, spec.dir) or false,
      }
      if depth == 1 then
        local n = native[spec.id]
        if n then n.map = map end
      end
      return rec
    else
      return nil, err
    end
  end

  local beforeFailures = #(neighborWarmupState.failures or {})
  local out, byId, direct, directComplete, warmErr, allComplete =
    NeighborWarmup.advance(neighborWarmupState,
      world.map and world.map.id, world.maps, openWorld, specs, build,
      admissionLimit)
  for i = beforeFailures + 1, #(neighborWarmupState.failures or {}) do
    local failure = neighborWarmupState.failures[i]
    logOnce("neighbor-adapt:" .. tostring(failure.id) .. ":"
        .. tostring(failure.error), "warn",
      "Gold connected-map voxel adapter skipped %s: %s",
      tostring(failure.id), tostring(failure.error))
  end

  -- Urgency follows the live player's edge rather than the frame on which the
  -- adapter record happened to be admitted.
  for _, rec in ipairs(direct) do
    rec.urgent = neighborUrgent(world, rec.dir)
  end

  Bridge.openWorldMaps = openWorld and (#out + 1) or 0
  Bridge.openWorldDirectMaps = #direct
  Bridge.neighborWarmupPending = allComplete ~= true
  Bridge.neighborDirectComplete = directComplete == true
  Bridge.neighborWarmupError = warmErr
  return out, byId, direct, directComplete
end

local function adaptedGhosts(world, byId)
  local out = {}
  for _, g in ipairs(world and world.ghosts or {}) do
    local id = (g.map and g.map.id) or (g.npc and g.npc.mapId)
    local nb = id and byId[id]
    if nb and g.npc then
      out[#out + 1] = {
        npc = g.npc, map = nb.map, ox = nb.ox, oy = nb.oy, peers = g.peers,
      }
    end
  end
  return out
end

local function currentMasks(neighbors)
  local masks = {}
  for _, nb in ipairs(neighbors or {}) do
    -- OPEN WORLD carries far maps here too. Only first-ring maps can overlap
    -- the current map's border apron, so only they participate in mask tests.
    if (nb.depth == nil or nb.depth <= 1) and nb.map and nb.map.def then
      masks[#masks + 1] = {
        nb.ox, nb.oy,
        nb.ox + nb.map.def.width * 32,
        nb.oy + nb.map.def.height * 32,
      }
    end
  end
  return masks
end

local function mergedEntities(world)
  local out, seen = {}, {}
  local function add(e)
    if type(e) == "table" and not seen[e] then
      seen[e] = true
      out[#out + 1] = e
    end
  end

  -- VoxelScene expects all standing actors in state.entities.  Gold keeps the
  -- player and native NPCs separately, so include them explicitly rather than
  -- relying on the Gen-1 World.entities convention.
  add(world.player)
  if type(world.npcs) == "table" then
    for _, e in ipairs(world.npcs) do add(e) end
  end
  if type(world.entities) == "table" then
    for _, e in ipairs(world.entities) do add(e) end
  end

  Bridge.extraEntitiesMerged = 0
  local provider = Bridge.extraEntitiesProvider
  if type(provider) == "function" then
    local ok, extra = pcall(provider, world)
    if ok and type(extra) == "table" then
      local before = #out
      for _, e in ipairs(extra) do add(e) end
      Bridge.extraEntitiesMerged = #out - before
    elseif not ok then
      local err = "visible Wilds provider failed: " .. tostring(extra)
      Bridge.lastError = err
      logOnce("extra-entities:" .. tostring(extra), "warn",
        "Gold visible-Wilds voxel entity provider failed: %s", tostring(extra))
    end
  end
  return out
end

local function makeState(world, includeNeighbors)
  if not (world and world.map and world.camera and world.player) then
    return nil, "Gold world/map/player is not ready"
  end
  local attached, attachErr = attachRenderer(world, world.map)
  if not attached then return nil, attachErr end

  -- The first drawable frame spends no synchronous time constructing
  -- connected-map adapters. Once the current BODY has landed, renderFrame
  -- admits one complete neighbour per frame. Other internal consumers retain
  -- the same one-adapter bound when they omit this presentation-only flag.
  local neighborLimit = includeNeighbors == false and 0
    or 1
  local neighbors, byId, directNeighbors, directComplete =
    adaptedNeighbors(world, neighborLimit)
  -- Third-person collision only needs maps touching the current one. OPEN
  -- WORLD may render dozens of farther areas; scanning them per boom sample
  -- adds CPU cost without changing the collision result near the player.
  V.goldNeighbors = directNeighbors
  V.goldOpenWorldMaps = neighbors

  local state = {
    map = world.map,
    camera = world.camera,
    player = world.player,
    entities = mergedEntities(world),
    neighbors = neighbors,
    ghosts = adaptedGhosts(world, byId),
    flyAnim = world.flyAnim,
    -- Carry the true-directional renderer state with the exact live Gold world
    -- used to build this frame.  Do not make OverworldStadium rediscover the
    -- world through Game.overworld/StateStack: those facades can lag behind the
    -- first map and only become current after a connection transition.
    _stadiumFreeMoveActive = world._stadiumFreeMoveActive == true,
    _stadiumFreeVisualMoving = world._stadiumFreeVisualMoving == true,
    _stadiumFreeAnimDist = tonumber(world._stadiumFreeAnimDist) or 0,
    _stadiumOpenWorldNeighbors = Bridge.openWorld == true,
    _stadiumOpenWorldMapCount = Bridge.openWorldMaps,
    _stadiumOpenWorldDepth = Bridge.openWorldDepth,
    -- Until every direct seam has an adapted map and therefore an exact mask,
    -- only the body may be requested. This avoids exposing an unmasked FULL
    -- apron (including synthetic half-trees) as the first voxel image.
    _stadiumCurrentBodyOnly = includeNeighbors == false
      or directComplete ~= true,
  }
  if GoldFieldMovePresentation
      and type(GoldFieldMovePresentation.decorateState) == "function" then
    local okDecorate, decorated = pcall(
      GoldFieldMovePresentation.decorateState, world, state)
    if okDecorate and type(decorated) == "table" then
      state = decorated
    elseif not okDecorate then
      logOnce("gen2-field-presentation:" .. tostring(decorated), "warn",
        "Gen-2 field-move presentation failed open to native: %s",
        tostring(decorated))
    end
  end
  if SpeciesFishingCinematic
      and type(SpeciesFishingCinematic.decorateState) == "function" then
    local okDecorate, decorated = pcall(
      SpeciesFishingCinematic.decorateState, world, state)
    if okDecorate and type(decorated) == "table" then
      state = decorated
    elseif not okDecorate then
      logOnce("gen2-fishing-presentation:" .. tostring(decorated), "warn",
        "Gen-2 fishing presentation failed open to native: %s",
        tostring(decorated))
    end
  end
  return state
end

-- Sibling Gold-only modules (notably OverworldBattle) can request the same
-- adapted state the free-roam renderer uses, including normalized tileset ids.
V.goldStateForWorld = makeState

local function pixelDimensions(ctx)
  -- Voxel canvases are drawn in LÖVE coordinates. On Retina, pw/ph and
  -- getPixelDimensions() describe a backing buffer that can be twice the
  -- drawable width and height. Rendering there and shrinking into ww/wh
  -- wastes four times the fill rate, most visibly during live MAP battles.
  local pw, ph = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  local G = love.graphics
  if G.getDimensions then
    local ok, w, h = pcall(G.getDimensions)
    if ok and w and h and w > 0 and h > 0 then return w, h end
  end
  -- Compatibility fallback for an unusual host exposing only physical size.
  pw, ph = tonumber(ctx and ctx.pw), tonumber(ctx and ctx.ph)
  if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  if G.getPixelDimensions then return G.getPixelDimensions() end
  return 1, 1
end

-- Free roam and its frozen MAP battle must use one render-size policy.
Bridge.renderDimensions = pixelDimensions

local function viewDimensions(world, ctx)
  local vw, vh = tonumber(world and world.viewW), tonumber(world and world.viewH)
  if vw and vh and vw > 0 and vh > 0 then return vw, vh end

  local ww, wh = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  if not (ww and wh and ww > 0 and wh > 0) then
    ww, wh = love.graphics.getDimensions()
  end
  local scale = 1
  if world and type(world.zoomScale) == "function" then
    local ok, s = pcall(world.zoomScale, world)
    if ok and tonumber(s) and tonumber(s) > 0 then scale = tonumber(s) end
  end
  return math.max(1, math.ceil(ww / scale)), math.max(1, math.ceil(wh / scale))
end

-- Composite the engine's ordinary standing FX onto a successful voxel frame.
-- Gold's drawWorld contract already supplies this callback; the old bridge
-- forwarded it in ctx but never invoked it, so Fly hid the player and then
-- drew no replacement at all.  The projection is presentation-only and the
-- graphics target is restored even when a third-party FX callback throws.
local function drawEngineFieldFx(canvas, state, ctx)
  local ok = true
  if GoldFieldMovePresentation
      and type(GoldFieldMovePresentation.drawEngineFx) == "function" then
    ok = GoldFieldMovePresentation.drawEngineFx(
      canvas, state, ctx, VoxelScene, Voxel3D)
  end
  if SpeciesFishingCinematic
      and type(SpeciesFishingCinematic.drawEngineFx) == "function" then
    local fishingOK = SpeciesFishingCinematic.drawEngineFx(
      canvas, state, ctx, VoxelScene, Voxel3D)
    ok = fishingOK ~= false and ok
  end
  return ok
end

local function disableFishingPresentation(module, reason)
  if type(module) == "table" and type(module.deactivate) == "function" then
    pcall(module.deactivate, reason)
  end
  local family = mod and mod.exports and mod.exports.speciesCinematics
  if type(family) == "table" then family.fishing = nil end
  SpeciesFishingCinematic = nil
  Bridge.fishingPresentationInstalled = false
  Bridge.fishingPresentationError = tostring(reason or "Fishing install declined")
end

local function installFishingPresentation()
  local okFishing, fishingOrErr = pcall(V.require, "SpeciesFishingCinematic")
  if not (okFishing and type(fishingOrErr) == "table"
      and type(fishingOrErr.install) == "function"
      and type(fishingOrErr.decorateState) == "function"
      and type(fishingOrErr.drawEngineFx) == "function") then
    disableFishingPresentation(okFishing and fishingOrErr or nil,
      okFishing and "Fishing renderer contract is incomplete" or fishingOrErr)
    return false
  end
  local okInstall, installed, installErr = pcall(fishingOrErr.install)
  local public = mod and mod.exports and mod.exports.speciesCinematics
    and mod.exports.speciesCinematics.fishing or nil
  if not (okInstall and installed == true and type(public) == "table"
      and public.active == true and type(public.status) == "function") then
    disableFishingPresentation(fishingOrErr,
      okInstall and (installErr or "Fishing provider was not published")
        or installed)
    return false
  end
  SpeciesFishingCinematic = fishingOrErr
  Bridge.fishingPresentationInstalled = true
  Bridge.fishingPresentationError = nil
  return true
end

function Bridge.install()
  if Bridge.installed then return true, V end

  local poseOK, poseErr = ensurePlayerPose()
  if not poseOK then return false, poseErr end

  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(function()
    return V.require("VoxelState"), V.require("Voxel3D"),
      V.require("VoxelScene"), V.require("ChunkMesher"),
      V.require("FirstPerson"), V.require("CamControl"),
      V.require("GoldCameraControls"), V.require("Gen2MapWarmup"),
      V.require("Gen2NeighborWarmup"), V.require("OpenWorldStreaming"),
      V.require("AntiAlias")
  end)
  if not ok then return false, tostring(a) end
  Voxel, Voxel3D, VoxelScene, ChunkMesher, FirstPerson, CamControl, GoldCameraControls,
    CurrentMapWarmup, NeighborWarmup, OpenWorldStreaming =
      a, b, c, d, e, f, g, h, i, j
  AntiAlias = k

  -- Current VASC environment stack. These modules are part of the standalone
  -- package; keeping them optional here preserves the renderer's proven
  -- fail-closed startup contract on older Gen1Recomp hosts.
  pcall(function() DayNight = V.require("DayNight") end)
  pcall(function() Sky = V.require("Sky") end)
  pcall(function() SkyEvents = V.require("SkyEvents") end)
  pcall(function() Weather = V.require("Weather") end)
  pcall(function() AmbientAudio = V.require("AmbientAudio") end)

  -- Presentation-only Gen-2 SURF/FLY bridge.  Its wrappers delegate to the
  -- engine first and retain only the exact successful user in a weak table;
  -- rules, player state, callbacks, warps and saves remain engine-owned.
  local okField, fieldOrErr = pcall(V.require, "GoldFieldMovePresentation")
  if okField and type(fieldOrErr) == "table"
      and type(fieldOrErr.install) == "function" then
    local okInstall, installed, installErr = pcall(fieldOrErr.install)
    if okInstall and installed ~= false then
      GoldFieldMovePresentation = fieldOrErr
      Bridge.fieldMovePresentationInstalled = true
      Bridge.fieldMovePresentationError = nil
    else
      Bridge.fieldMovePresentationInstalled = false
      Bridge.fieldMovePresentationError = tostring(okInstall and installErr or installed)
    end
  else
    Bridge.fieldMovePresentationInstalled = false
    Bridge.fieldMovePresentationError = tostring(fieldOrErr)
  end

  if not (type(Voxel) == "table" and type(Voxel.setLevel) == "function") then
    return false, "VoxelState renderer is unavailable"
  end
  if not (type(Voxel3D) == "table" and type(Voxel3D.available) == "function") then
    return false, "Voxel3D renderer is unavailable"
  end
  if not (type(VoxelScene) == "table" and type(VoxelScene.render) == "function") then
    return false, "VoxelScene renderer is unavailable"
  end
  if not (type(AntiAlias) == "table"
      and type(AntiAlias.expand) == "function"
      and type(AntiAlias.resolve) == "function") then
    return false, "mobile render-scale compositor is unavailable"
  end
  if not (type(ChunkMesher) == "table" and type(ChunkMesher.pump) == "function"
       and type(ChunkMesher.request) == "function"
       and type(ChunkMesher.peek) == "function") then
    return false, "ChunkMesher renderer is unavailable"
  end
  if not (type(CurrentMapWarmup) == "table"
      and type(CurrentMapWarmup.advance) == "function") then
    return false, "Gen-2 current-map warmup policy is unavailable"
  end
  if not (type(NeighborWarmup) == "table"
      and type(NeighborWarmup.advance) == "function") then
    return false, "Gen-2 neighbour warmup policy is unavailable"
  end
  if not (type(OpenWorldStreaming) == "table"
      and type(OpenWorldStreaming.status) == "function") then
    return false, "Gen-2 open-world streaming-radius policy is unavailable"
  end

  if not (type(FirstPerson) == "table" and type(FirstPerson.update) == "function"
       and type(FirstPerson.install) == "function") then
    return false, "FirstPerson/ThirdPerson camera rig is unavailable"
  end
  if not (type(CamControl) == "table" and type(CamControl.install) == "function"
       and type(CamControl.pinchBy) == "function") then
    return false, "Voxel pinch-zoom controller is unavailable"
  end
  if not (type(GoldCameraControls) == "table"
       and type(GoldCameraControls.install) == "function") then
    return false, "Gold camera-relative movement adapter is unavailable"
  end

  -- Fishing is allowed to wrap World only after every renderer dependency
  -- needed by its decorate/draw consumer has passed the fatal install gate.
  -- From this point to Bridge.installed there are no further fatal returns;
  -- an optional Fishing failure is explicitly deactivated and stays native.
  installFishingPresentation()

  -- In-world battles are optional to the renderer's survival: install them
  -- through this same Gold module namespace, but never let a battle hook
  -- failure disable the proven free-roam voxel path.
  local okBattle, battleOrErr = pcall(V.require, "OverworldBattle")
  if okBattle and type(battleOrErr) == "table" then
    OverworldBattle = battleOrErr
    local okInstall, installErr = pcall(OverworldBattle.install)
    Bridge.battleInstalled = okInstall and installErr ~= false
    if not Bridge.battleInstalled then
      Bridge.battleError = tostring(installErr or "battle install declined")
    end
  else
    Bridge.battleInstalled = false
    Bridge.battleError = tostring(battleOrErr)
  end

  -- Optional in-world capture minigame.  Keep it isolated from renderer
  -- survival exactly like the battle presentation: a bad capture asset/hook
  -- may fall back to normal battles but must never disable the voxel world.
  local okCapture, captureOrErr = pcall(V.require, "OverworldCapture")
  if okCapture and type(captureOrErr) == "table" then
    OverworldCapture = captureOrErr
    Bridge.captureAvailable = true
    Bridge.captureError = nil
  else
    Bridge.captureAvailable = false
    Bridge.captureError = tostring(captureOrErr)
  end

  -- Mod Manager persists the option and emits this event live. The frame path
  -- still re-reads mod.options:get every time, but the event immediately drops
  -- the cached full-world graph so OFF cannot remain visually sticky for even
  -- one stale cache generation.
  if not Bridge.openWorldOptionListenerInstalled
      and mod and mod.events and type(mod.events.on) == "function" then
    local okListener = pcall(mod.events.on, mod.events, "mod.options_changed",
      function(payload)
        if type(payload) ~= "table" then return end
        if payload.mod ~= nil and payload.mod ~= mod.id then return end
        if payload.key == "openWorld" then
          applyOpenWorldMode(payload.value)
        elseif payload.key == "voxel3d" then
          Bridge.handleUserVoxelOption(payload.value)
        end
      end)
    Bridge.openWorldOptionListenerInstalled = okListener == true
  end

  if not Bridge.warpPrefetchListenerInstalled
      and mod and mod.events and type(mod.events.on) == "function" then
    local okListener = pcall(mod.events.on, mod.events, "player.warped",
      function(payload)
        local id = type(payload) == "table" and payload.toMap or nil
        if type(id) == "string" and id ~= "" and voxelModeEnabled() then
          Bridge.pendingWarpMapId = id
          Bridge.pendingWarpRequestedMapId = nil
          Bridge.warpPrefetchError = nil
          Bridge.pendingWarpVoxelActive = true
          Bridge.pendingWarpCameraMode = normalizeCameraMode(optionCameraMode())
          diagnostic("gen2-voxel-warp-start", {
            from=Bridge.currentMapId or Bridge.mapId, to=id,
            camera=Bridge.pendingWarpCameraMode,
            configured=configuredVoxelModeEnabled(),
            pipeline=selectorPipelineLevel(),
          })
        end
      end)
    Bridge.warpPrefetchListenerInstalled = okListener == true
  end

  -- Keep a live block edit smooth and mark that id as generation-dirty.  The
  -- stale mesh is still presented while refresh cooks; on the next setMap,
  -- Crystal restores the ROM block buffer before map.entered and the dirty
  -- receipt forces one clean rebuild even when those restored bytes equal the
  -- signature captured before CUT/WHIRLPOOL changed them.
  if not Bridge.blockRefreshListenerInstalled
      and mod and mod.events and type(mod.events.on) == "function" then
    local okListener = pcall(mod.events.on, mod.events, "world.block_replaced",
      function(payload)
        local id = type(payload) == "table" and payload.mapId or nil
        markMapGeometryDirty(id)
        if id ~= nil and ChunkMesher
            and type(ChunkMesher.refresh) == "function" then
          local okRefresh, refreshErr = pcall(ChunkMesher.refresh, id)
          if not okRefresh then
            Bridge.mapLifecycleError = "Gen-2 live map refresh failed for "
              .. tostring(id) .. ": " .. tostring(refreshErr)
          end
        end
      end)
    Bridge.blockRefreshListenerInstalled = okListener == true
  end

  Bridge.installed = true
  -- OPEN WORLD is a 3D residency mode, not a second flat renderer.  If it is
  -- enabled, keep the voxel provider alive even if an older save still has
  -- the independent 3D VOXEL WORLD toggle off.  Turning OPEN WORLD off again
  -- restores the ordinary voxel3d toggle's authority.
  Bridge.active = voxelModeEnabled()
  applyOpenWorldMode(optionOpenWorld())
  logOnce("installed", "info",
    "Gen-2 voxel renderer provider ready for Gold render.compose")
  return true, V
end

function Bridge.ensure()
  if not Bridge.installed then return Bridge.install() end
  return true, V
end

-- Leaving the voxel provider must be a real residency transition, not merely
-- a draw skip.  The former early return kept far OPEN WORLD meshes, coloured
-- atlases, horizon jobs and panorama GPU objects alive until another voxel
-- frame happened to reconcile them.  Release once on the active -> inactive
-- edge; every resource remains lazy and is rebuilt normally when 3D is enabled
-- again.
local function releaseInactiveResidency()
  if Bridge.residencyReleased == true then return false end

  local empty = {}
  if ChunkMesher and type(ChunkMesher.setLive) == "function" then
    pcall(ChunkMesher.setLive, empty, true)
  end

  local function optional(name)
    local ok, module = pcall(V.require, name)
    return ok and type(module) == "table" and module or nil
  end

  local terrain = optional("TerrainAtlas")
  if terrain and type(terrain.setLive) == "function" then
    pcall(terrain.setLive, empty)
  end

  GoldColorAtlas = GoldColorAtlas or optional("GoldColorAtlas")
  if GoldColorAtlas and type(GoldColorAtlas.setLive) == "function" then
    pcall(GoldColorAtlas.setLive, empty)
  end

  local panorama = optional("PanoramaBackdrop")
  if panorama and type(panorama.setEnabled) == "function" then
    pcall(panorama.setEnabled, false)
  end

  local horizon = optional("HorizonWall")
  if horizon and type(horizon.invalidate) == "function" then
    pcall(horizon.invalidate)
  end

  if NeighborWarmup and type(NeighborWarmup.reset) == "function" then
    pcall(NeighborWarmup.reset, neighborWarmupState)
  else
    neighborWarmupState = {}
  end
  neighborMapCache = {}
  openWorldGraphCache = {
    rootId = nil, maps = nil, maxDepth = nil, specs = nil,
  }
  V.goldNeighbors = {}
  V.goldOpenWorldMaps = {}
  Bridge.openWorldMaps = 0
  Bridge.openWorldDirectMaps = 0
  Bridge.neighborWarmupPending = false
  Bridge.neighborDirectComplete = false
  Bridge.currentOnlyPresentedMapId = nil
  Bridge.currentOnlyPresentedMapRef = nil
  Bridge.lastPresentedFrame = nil
  Bridge.residencyReleased = true
  return true
end

Bridge.releaseInactiveResidency = releaseInactiveResidency

local function transitionCameraModeNow()
  return normalizeCameraMode(Bridge.pendingPipelineRestoreMode or optionCameraMode())
end

local function transitionFrameMismatch(frame, world, expectedW, expectedH)
  if type(frame) ~= "table" or frame.canvas == nil then
    return "no-successful-free-roam-frame"
  end
  if type(world) ~= "table" or type(world.map) ~= "table" then
    return "world-or-map-unavailable"
  end
  if frame.world ~= world then return "world-receipt-mismatch" end
  if frame.map ~= world.map then return "map-receipt-mismatch" end
  if frame.mapId ~= world.map.id then return "map-id-receipt-mismatch" end
  if frame.mapTransitionSerial ~= Bridge.mapTransitionSerial then
    return "map-generation-receipt-mismatch"
  end
  local mode = transitionCameraModeNow()
  if frame.cameraMode ~= mode then return "camera-receipt-mismatch" end
  if Bridge.active ~= true or not voxelModeEnabled() then
    return "voxel-owner-inactive"
  end
  expectedW, expectedH = positiveDimensions(expectedW, expectedH)
  if expectedW then
    local frameW, frameH = frameDimensions(frame)
    if frameW and (frameW ~= expectedW or frameH ~= expectedH) then
      return "drawable-dimensions-changed"
    end
  end
  return nil
end

local function setTransitionFallback(reason)
  Bridge.transitionBackgroundLastReason = tostring(reason or "provider-declined")
  Bridge.transitionBackgroundFallbacks =
    (tonumber(Bridge.transitionBackgroundFallbacks) or 0) + 1
end

-- Return a draw callback exact to one already-presented free-roam frame. The
-- callback is invoked by Gen2BattleTransition while a graphics target is live;
-- it snapshots the source canvas once on its first call, then only re-blits the
-- frozen canvas. Any stale receipt or graphics failure declines and lets the
-- engine execute its unchanged native World:draw path.
function Bridge.transitionBackgroundProvider(world)
  local frame = Bridge.lastPresentedFrame
  local mismatch = transitionFrameMismatch(frame, world)
  if mismatch then
    setTransitionFallback(mismatch)
    return nil, nil, mismatch
  end

  Bridge.transitionSnapshotSerial =
    (tonumber(Bridge.transitionSnapshotSerial) or 0) + 1
  local receipt = {
    schema = "voxel-ascendant/gen2-transition-background/v1",
    owner = "provider",
    serial = Bridge.transitionSnapshotSerial,
    sourceFrame = frame.frameSerial,
    mapId = frame.mapId,
    mapTransitionSerial = frame.mapTransitionSerial,
    cameraMode = frame.cameraMode,
    cameraLevel = frame.cameraLevel,
    frozen = false,
    frames = 0,
  }
  local frozen = nil
  local frozenW, frozenH = nil, nil
  local declined = false

  local function decline(reason)
    if not declined then
      declined = true
      receipt.owner = "native"
      receipt.failureReason = tostring(reason or "provider-declined")
      setTransitionFallback(receipt.failureReason)
      diagnostic("gen2-transition-background", receipt)
    end
    return false
  end

  local function freeze(source, w, h)
    local G = love and love.graphics
    if not (G and type(G.newCanvas) == "function"
        and type(G.setCanvas) == "function" and type(G.draw) == "function") then
      return nil, "graphics-canvas-api-unavailable"
    end
    local sw, sh
    local okDimensions, dimA, dimB = pcall(function()
      return source:getDimensions()
    end)
    if okDimensions then sw, sh = tonumber(dimA), tonumber(dimB) end
    if not (sw and sh and sw > 0 and sh > 0) then
      return nil, "source-canvas-dimensions-unavailable"
    end
    w, h = math.max(1, math.floor(tonumber(w) or sw)),
      math.max(1, math.floor(tonumber(h) or sh))

    local okCanvas, canvas = pcall(G.newCanvas, w, h)
    if not okCanvas or not canvas then
      return nil, "transition-snapshot-allocation-failed: " .. tostring(canvas)
    end
    if type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end

    local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
    local pushed = type(G.push) == "function" and pcall(G.push, "all") or false
    local okDraw, drawErr = pcall(function()
      G.setCanvas(canvas)
      if type(G.origin) == "function" then G.origin() end
      if type(G.clear) == "function" then G.clear(0, 0, 0, 1) end
      if type(G.setColor) == "function" then G.setColor(1, 1, 1, 1) end
      G.draw(source, 0, 0, 0, w / sw, h / sh)
    end)
    if pushed and type(G.pop) == "function" then pcall(G.pop) end
    pcall(G.setCanvas, previous)
    if not okDraw then
      return nil, "transition-snapshot-draw-failed: " .. tostring(drawErr)
    end
    return canvas
  end

  local function provider(transition, w, h)
    if declined then return false end
    w, h = positiveDimensions(w, h)
    local stale = transitionFrameMismatch(frame, world, w, h)
    if stale then return decline(stale) end

    if frozen and w and frozenW
        and (w ~= frozenW or h ~= frozenH) then
      frozen = nil
      return decline("transition-snapshot-dimensions-changed")
    end

    if not frozen then
      local snapshot, snapshotErr = freeze(frame.canvas, w, h)
      if not snapshot then return decline(snapshotErr) end
      frozen = snapshot
      frozenW, frozenH = canvasDimensions(snapshot)
      if not frozenW then frozenW, frozenH = w, h end
      receipt.frozen = true
      receipt.canvasWidth, receipt.canvasHeight = frozenW, frozenH
      Bridge.transitionSnapshots =
        (tonumber(Bridge.transitionSnapshots) or 0) + 1
      diagnostic("gen2-transition-background", receipt)
    end

    local G = love and love.graphics
    if not (G and type(G.draw) == "function") then
      return decline("graphics-draw-api-unavailable")
    end
    local pushed = type(G.push) == "function" and pcall(G.push, "all") or false
    local okDraw, drawErr = pcall(function()
      if type(G.setColor) == "function" then G.setColor(1, 1, 1, 1) end
      G.draw(frozen, 0, 0)
    end)
    if pushed and type(G.pop) == "function" then pcall(G.pop) end
    if not okDraw then
      return decline("transition-background-draw-failed: " .. tostring(drawErr))
    end

    receipt.frames = receipt.frames + 1
    Bridge.transitionBackgroundFrames =
      (tonumber(Bridge.transitionBackgroundFrames) or 0) + 1
    Bridge.transitionBackgroundLastReason = nil
    if type(transition) == "table" then
      transition._vascTransitionBackgroundReceipt = receipt
    end
    return true
  end

  return provider, receipt, nil
end

function Bridge.renderFrame(world, ctx)
  Bridge.framesAttempted = Bridge.framesAttempted + 1

  -- Restore the public Character Selector rung BEFORE any provider can return
  -- its native-2D fallback.  Keep applying it for the bounded post-warp window:
  -- map.entered listeners run in no fixed cross-mod order, so the selector may
  -- legitimately reset its pipeline after our first successful write.  The
  -- user's own VASC voxel switch still has absolute authority and cancels the
  -- latch immediately when switched off.
  if Bridge.pendingPipelineRestoreMode then
    local mode = Bridge.pendingPipelineRestoreMode
    Bridge.cameraMode = mode
    Bridge.cameraLevel = cameraLevelForMode(mode)
    local selectorReady = selectorDetected()
    local selectorRestored = false
    if selectorReady then selectorRestored = setSelectorCameraMode(mode) == true end
    if not Bridge.pendingPipelineRestoreAttemptLogged then
      Bridge.pendingPipelineRestoreAttemptLogged = true
      diagnostic("gen2-voxel-restore-attempt", {
        map=Bridge.currentMapId or Bridge.mapId, camera=mode,
        configured=configuredVoxelModeEnabled(), selector=selectorReady,
        restored=selectorRestored, pipeline=selectorPipelineLevel(),
      })
    end
    Bridge.pendingPipelineRestoreFrames =
      (tonumber(Bridge.pendingPipelineRestoreFrames) or 1) - 1
    if Bridge.pendingPipelineRestoreFrames <= 0 then
      diagnostic("gen2-voxel-restore-timeout", {
        map=Bridge.currentMapId or Bridge.mapId, camera=mode,
        configured=configuredVoxelModeEnabled(), selector=selectorReady,
        pipeline=selectorPipelineLevel(), error=Bridge.lastError,
      })
      Bridge.pendingPipelineRestoreMode = nil
      Bridge.pendingPipelineRestoreFrames = nil
      Bridge.pendingPipelineRestoreEnabled = nil
      Bridge.pendingPipelineRestoreStableFrames = nil
      Bridge.pendingPipelineRestoreAttemptLogged = nil
    end
  end

  -- OPEN WORLD always means OPEN WORLD *VOXELS*.  v0.2.45/46 could leave the
  -- graph active while the voxel provider was disabled, which produced the
  -- huge stitched native-2D overview shown in the user's screenshot.
  Bridge.active = voxelModeEnabled()
  Bridge.mapId = world and world.map and world.map.id or nil

  -- Engine World uses this receipt to keep its native fallback canvases to the
  -- current seam ring while VASC supplies the wider 3D view.  It is deliberately
  -- false in pure native mode, whose viewport-based neighbour policy is left
  -- unchanged.
  if type(world) == "table" then
    local wasActive = world._vascVoxelProviderActive == true
    local isActive = Bridge.active == true
    world._vascVoxelProviderActive = isActive
    world._vascVoxelOpenWorld = optionOpenWorld()
    -- rebuildNeighbors is normally map/zoom driven.  Reconcile once on the
    -- provider-owner edge as well, otherwise enabling VASC on a stationary map
    -- could leave the old viewport-wide native canvas set resident indefinitely.
    if wasActive ~= isActive and type(world.rebuildNeighbors) == "function" then
      pcall(world.rebuildNeighbors, world)
    end
  end

  if not Bridge.active then
    if Bridge.installed then releaseInactiveResidency() end
    return nil, "voxel disabled", "disabled"
  end
  if not Bridge.installed then
    local ok, err = Bridge.install()
    if not ok then
      Bridge.framesFailed = Bridge.framesFailed + 1
      Bridge.lastError = tostring(err)
      return nil, Bridge.lastError, "failed"
    end
  end
  Bridge.residencyReleased = false

  -- map.entered is the primary generation boundary.  Also observe the live
  -- object here so an older host, a late install, or a listener failure cannot
  -- make a fresh same-id Map inherit the previous root's warmup/adapters.  A
  -- semantically identical prewarmed BODY survives through its geometry
  -- receipt; only stale geometry is invalidated.
  local liveMap = world and world.map or nil
  if liveMap ~= nil and Bridge.currentMapRef ~= liveMap then
    resetMapRoot(liveMap, "render-observed", false)
  end
  if liveMap ~= nil and Bridge.mapLifecycleError ~= nil then
    local lifecycleOK, _, lifecycleErr = rememberMapGeometry(liveMap)
    if lifecycleOK then
      Bridge.mapLifecycleError = nil
    else
      Bridge.mapLifecycleError = tostring(lifecycleErr)
      Bridge.framesFailed = Bridge.framesFailed + 1
      Bridge.lastError = Bridge.mapLifecycleError
      return nil, Bridge.lastError, "failed"
    end
  end
  Bridge.mapId = liveMap and liveMap.id or nil

  -- GoldComposeBridge supplies the live Game2 owner explicitly; current World
  -- objects also keep it as world.game. The camera modules use this instead of
  -- the Gen-1 singleton when deciding whether free roam is actually on top.
  bindGame((world and world.game) or Bridge.game)

  local okAvailable, available = pcall(Voxel3D.available)
  if not okAvailable or not available then
    local err = okAvailable and "Voxel3D reports graphics/depth support unavailable"
      or ("Voxel3D availability check failed: " .. tostring(available))
    Bridge.framesFailed = Bridge.framesFailed + 1
    Bridge.lastError = err
    logOnce("available:" .. err, "warn", "%s", err)
    return nil, err, "failed"
  end


  -- Spend the cartridge's already-covered door/warp frames on the announced
  -- destination.  The call is bounded by ChunkMesher's COVERED slice.
  local prefetchPumped = prewarmPendingWarp(world)

  local currentId = liveMap and liveMap.id
  local includeNeighbors = Bridge.currentOnlyPresentedMapId == currentId
    and Bridge.currentOnlyPresentedMapRef == liveMap
  local state, stateErr = makeState(world, includeNeighbors)
  if not state then
    Bridge.framesFailed = Bridge.framesFailed + 1
    Bridge.lastError = tostring(stateErr)
    return nil, Bridge.lastError, "failed"
  end

  -- Advance the CURRENT map through one bounded urgent slice.  Older builds
  -- called ChunkMesher.get here and froze the complete Gold/Silver/Crystal
  -- frame until a cold route finished.  The official native 2D world remains
  -- the honest fallback for the few frames before this atomic mesh lands.
  local now = monotonicTime()
  local mapReady, warmErr, warmStatus, mapPumped = CurrentMapWarmup.advance(
    ChunkMesher, state.map, currentMasks(state.neighbors), Bridge, false, now,
    state._stadiumCurrentBodyOnly == true)
  if not mapReady and warmStatus == "pending" then
    Bridge.framesPending = Bridge.framesPending + 1
    Bridge.meshPendingFrames = Bridge.meshPendingFrames + 1
    return nil, warmErr, "pending"
  elseif not mapReady then
    Bridge.framesFailed = Bridge.framesFailed + 1
    Bridge.lastError = tostring(warmErr)
    logOnce("prime-failed:" .. tostring(state.map.id) .. ":" .. Bridge.lastError,
      "error", "%s", Bridge.lastError)
    return nil, Bridge.lastError, "failed"
  end

  local ok, canvasOrErr = pcall(function()
    -- Poll Android touch contacts before resolving this frame's camera mode so
    -- a slider drag takes effect on the very same rendered frame.
    local liveGame = (world and world.game) or Bridge.game
    updateCameraSliderTouches(liveGame)
    updateDioramaPinchTouches(liveGame)
    updateRightLookTouches(liveGame, false)
    pollCameraHotkey(liveGame)
    -- The post-map latch is a temporary rendering owner, not a new user
    -- choice.  Read it directly instead of storing it in cameraOverride: the
    -- latter deliberately survives frames for an explicit slider/F6 command
    -- and previously left the boot-time FULL rung stuck there forever.
    local mode = Bridge.pendingPipelineRestoreMode or optionCameraMode()
    -- A capture begun from DIORAMA temporarily dives to the already-proven
    -- 3RD-person rig so the player can physically aim with mouse/right stick.
    -- The saved camera option is never changed; leaving the minigame returns
    -- to DIORAMA automatically on the next frame.
    local captureMode = nil
    if OverworldCapture and type(OverworldCapture.cameraOverride) == "function" then
      local okCaptureMode, value = pcall(OverworldCapture.cameraOverride)
      if okCaptureMode then captureMode = value end
    end
    local renderMode = captureMode or mode
    local level = cameraLevelForMode(renderMode)
    local dt = frameDt()
    Bridge.cameraMode, Bridge.cameraLevel = mode, level
    Bridge.captureCameraOverride = captureMode

    -- DIORAMA keeps the FULL preset semantics (so zoom still targets the
    -- diorama distance), but its pitch is independently configurable. This
    -- deliberately separates TILT from DioramaZoom: changing tilt rotates the
    -- camera; changing zoom only changes distance. FIRST/THIRD keep their own
    -- placed-camera rigs.
    if renderMode == "full" and type(Voxel.setFullAngle) == "function" then
      Voxel.setFullAngle(35)
    end
    Voxel.setLevel(level)
    if type(Voxel.update) == "function" then Voxel.update(dt, level) end
    if DayNight and type(DayNight.update) == "function" then DayNight.update(dt) end
    if Sky and type(Sky.update) == "function" then Sky.update(dt) end
    if SkyEvents and type(SkyEvents.update) == "function" then SkyEvents.update(dt) end
    if Weather and type(Weather.update) == "function" then
      Weather.update(dt, state.map)
    end
    if AmbientAudio and type(AmbientAudio.update) == "function" then
      AmbientAudio.update(dt)
    end
    if FirstPerson and type(FirstPerson.update) == "function" then
      FirstPerson.update(dt)
    end
    if OverworldCapture and type(OverworldCapture.afterCameraUpdate) == "function" then
      pcall(OverworldCapture.afterCameraUpdate)
    end
    local pw, ph = pixelDimensions(ctx)
    local rw, rh = AntiAlias.expand(pw, ph)
    local vw, vh = viewDimensions(world, ctx)
    -- Scene HUD pixels belong to the final output coordinate space, not the
    -- mobile/AA intermediate. Defer only when resolve changes dimensions.
    state._stadiumDeferSceneHud = rw ~= pw or rh ~= ph
    mobileDiagnostic("checkpoint", "gen2-mobile-render-size", {
      caller="AntiAlias.expand", context="world",
      width=pw, height=ph, renderWidth=rw, renderHeight=rh,
    })
    if type(VoxelScene.stageMobileScenery) == "function" then
      local okStage, staged, resource = pcall(
        VoxelScene.stageMobileScenery, state)
      if not okStage then
        mobileDiagnostic("fallback", "gen2-mobile-scenery-stage",
          tostring(staged), "core-retained", {
            caller="VoxelScene.stageMobileScenery", context="world",
          })
      elseif staged then
        mobileDiagnostic("checkpoint", "gen2-mobile-scenery-staged", {
          caller="VoxelScene.stageMobileScenery", context="world",
          resource=resource,
        })
      end
    end
    local canvas = VoxelScene.render(state, rw, rh, vw, vh, nil)
    if canvas then drawEngineFieldFx(canvas, state, ctx) end
    if canvas then canvas = AntiAlias.resolve(canvas, pw, ph, "world") end
    if canvas and state._stadiumDeferSceneHud
        and type(VoxelScene.drawSceneHud) == "function" then
      local hw, hh = pw, ph
      if type(canvas.getDimensions) == "function" then
        local okSize, cw, ch = pcall(canvas.getDimensions, canvas)
        if okSize and tonumber(cw) and tonumber(ch) then hw, hh = cw, ch end
      end
      VoxelScene.drawSceneHud(canvas, state, hw, hh, true)
    end
    -- Exactly one cooperative mesher slice per presented frame. The current
    -- gate or covered destination prefetch may already have spent it; otherwise
    -- advance the full apron/neighbours VoxelScene just requested.
    if not (prefetchPumped or mapPumped) then ChunkMesher.pump(false) end
    return canvas
  end)

  if not ok then
    Bridge.framesFailed = Bridge.framesFailed + 1
    Bridge.lastError = tostring(canvasOrErr)
    logOnce("render:" .. Bridge.lastError, "error",
      "Gold compose voxel frame failed; flat Gold + visible Wilds fallback will be used: %s",
      Bridge.lastError)
    return nil, Bridge.lastError, "failed"
  end

  if not canvasOrErr then
    local meshErr = type(ChunkMesher.lastError) == "function"
      and ChunkMesher.lastError(state.map.id) or nil
    if meshErr then
      Bridge.framesFailed = Bridge.framesFailed + 1
      Bridge.lastError = "Gen-2 voxel mesh failed after prime: " .. tostring(meshErr)
      logOnce("mesh-failed:" .. tostring(state.map.id) .. ":" .. Bridge.lastError,
        "error", "%s", Bridge.lastError)
      return nil, Bridge.lastError, "failed"
    end
    Bridge.framesPending = Bridge.framesPending + 1
    Bridge.meshPendingFrames = Bridge.meshPendingFrames + 1
    return nil, "voxel mesh pending", "pending"
  end

  Bridge.frames3d = Bridge.frames3d + 1
  if Bridge.pendingPipelineRestoreMode then
    Bridge.pendingPipelineRestoreStableFrames =
      (tonumber(Bridge.pendingPipelineRestoreStableFrames) or 0) + 1
    if Bridge.pendingPipelineRestoreStableFrames >= 3 then
      diagnostic("gen2-voxel-restore-complete", {
        map=state.map and state.map.id,
        camera=Bridge.pendingPipelineRestoreMode,
        configured=configuredVoxelModeEnabled(),
        pipeline=selectorPipelineLevel(), frames3d=Bridge.frames3d,
      })
      Bridge.pendingPipelineRestoreMode = nil
      Bridge.pendingPipelineRestoreFrames = nil
      Bridge.pendingPipelineRestoreEnabled = nil
      Bridge.pendingPipelineRestoreStableFrames = nil
      Bridge.pendingPipelineRestoreAttemptLogged = nil
    end
  end
  -- Only a successfully presented current BODY unlocks progressive neighbour
  -- adaptation. Pending/native fallback frames remain free of Map.new/atlas
  -- work, so the very first coherent voxel image cannot contain a half-built
  -- connected-map apron.
  Bridge.currentOnlyPresentedMapId = state.map.id
  Bridge.currentOnlyPresentedMapRef = state.map
  Bridge.lastError = nil
  -- Battle rendering owns a separate staged canvas. Never let it replace the
  -- encounter-site frame that the transition is entitled to freeze.
  local battleStaged = false
  if OverworldBattle and type(OverworldBattle.stage) == "function" then
    local okStage, arena = pcall(OverworldBattle.stage)
    battleStaged = okStage and arena ~= nil
  end
  if not battleStaged then
    local canvasW, canvasH = canvasDimensions(canvasOrErr)
    Bridge.lastPresentedFrame = {
      canvas = canvasOrErr,
      canvasWidth = canvasW or pw,
      canvasHeight = canvasH or ph,
      world = world,
      map = liveMap,
      mapId = liveMap and liveMap.id or nil,
      mapTransitionSerial = Bridge.mapTransitionSerial,
      cameraMode = Bridge.cameraMode,
      cameraLevel = Bridge.cameraLevel,
      frameSerial = Bridge.frames3d,
    }
    Bridge.mapTransitionHold = nil
  end
  return canvasOrErr, nil, "rendered"
end

function Bridge.failBattleToNative(screen, reason)
  if not (OverworldBattle
      and type(OverworldBattle.failToNative) == "function") then
    return false
  end
  local owner = screen
  if owner == nil and type(OverworldBattle.battle) == "function" then
    local okOwner, value = pcall(OverworldBattle.battle)
    if okOwner then owner = value end
  end
  if owner == nil then return false end
  local ok, latched = pcall(OverworldBattle.failToNative, owner, reason)
  if not ok then
    Bridge.battleError = tostring(reason or "Gen-2 battle update failed")
      .. "; native latch failed: " .. tostring(latched)
    return false
  end
  return latched == true
end

function Bridge.updateBattle(dt, expectedScreen)
  if not (OverworldBattle and type(OverworldBattle.update) == "function") then
    return false
  end
  local owner = expectedScreen
  if owner == nil and type(OverworldBattle.battle) == "function" then
    local okOwner, value = pcall(OverworldBattle.battle)
    if okOwner then owner = value end
  end
  -- Poll Android right-thumb look even though Gold's BattleState is on top.
  -- The live-world battle uses the same FirstPerson/ThirdPerson yaw/pitch as
  -- free roam, so steering here changes the camera the battle actually draws.
  local battleActive = false
  pcall(function() battleActive = OverworldBattle.shot() ~= nil or OverworldBattle.battle() ~= nil end)
  local touchCameraOwned = false
  if CamControl and type(CamControl.pollBattleTouches) == "function" then
    local okPinch, result = pcall(CamControl.pollBattleTouches, platformName())
    touchCameraOwned = okPinch and result == true
    -- A host touch API error must not abort rendering or latch a 2D battle.
    Bridge.battlePinchError = not okPinch and tostring(result) or nil
  end
  -- The shared phone poll owns both pinch and one-finger battle look. The
  -- older Android free-roam poll must not apply the same movement again.
  if not touchCameraOwned then updateRightLookTouches(Bridge.game, battleActive) end
  local ok, err = pcall(OverworldBattle.update, tonumber(dt) or (1 / 60))
  if not ok then
    Bridge.battleError = tostring(err)
    -- The compose caller passes the concrete stack-top BattleState. Snapshot
    -- ownership before update so even a partially-mutating failure cannot
    -- poison a replacement encounter that became active afterwards.
    Bridge.failBattleToNative(owner, err)
    return false, Bridge.battleError
  end
  Bridge.battleError = nil
  return true
end

-- A scripted/fast-forwarded Gold load can push BattleState before the first
-- physical draw reaches render.compose. Once that live compose heartbeat is
-- present, recover the already-pushed ordinary battle instead of leaving the
-- whole encounter on Crystal's native canvas. OverworldBattle.ensure keeps
-- special battles native and binds the exact screen to the recovered session.
function Bridge.ensureBattle(screen)
  if not (OverworldBattle and type(OverworldBattle.ensure) == "function") then
    return false
  end
  local ok, value = pcall(OverworldBattle.ensure, screen)
  if not ok then
    Bridge.battleError = tostring(value)
    return false
  end
  return value == true
end

function Bridge.setBattleCompositorReady(ready)
  if not (OverworldBattle
      and type(OverworldBattle.setGoldCompositorReady) == "function") then
    return false
  end
  local ok, value = pcall(OverworldBattle.setGoldCompositorReady, ready)
  return ok and value == true
end

function Bridge.battleShot()
  if not (OverworldBattle and type(OverworldBattle.shot) == "function") then
    return nil
  end
  local ok, shot = pcall(OverworldBattle.shot)
  return ok and shot or nil
end

function Bridge.battlePending(screen)
  if not (OverworldBattle and type(OverworldBattle.pending) == "function") then
    return false
  end
  local ok, pending = pcall(OverworldBattle.pending, screen)
  return ok and pending == true
end

function Bridge.isBattleScreen(screen)
  if not (OverworldBattle
      and type(OverworldBattle.isBattleScreen) == "function") then
    return false
  end
  local ok, yes = pcall(OverworldBattle.isBattleScreen, screen)
  return ok and yes == true
end

function Bridge.drawNativeBattleFallback(winW, winH)
  if not (OverworldBattle
      and type(OverworldBattle.drawGoldNativeFallback) == "function") then
    return false, "native Gen-2 battle fallback is unavailable"
  end
  return OverworldBattle.drawGoldNativeFallback(winW, winH)
end

function Bridge.battleScreen()
  if not (OverworldBattle and type(OverworldBattle.battle) == "function") then
    return nil
  end
  local ok, battle = pcall(OverworldBattle.battle)
  return ok and battle or nil
end

function Bridge.battleStage()
  if not (OverworldBattle and type(OverworldBattle.stage) == "function") then
    return nil
  end
  local ok, stage = pcall(OverworldBattle.stage)
  return ok and stage or nil
end

function Bridge.drawCaptureAnimation(screen, projection, targetW, targetH)
  if not (OverworldBattle
      and type(OverworldBattle.drawCaptureAnimation) == "function") then
    return false, "Gen-2 capture animation bridge unavailable"
  end
  return OverworldBattle.drawCaptureAnimation(
    screen, projection, targetW, targetH)
end

function Bridge.setExtraEntitiesProvider(fn)
  if fn ~= nil and type(fn) ~= "function" then
    return false, "extra entity provider must be a function or nil"
  end
  Bridge.extraEntitiesProvider = fn
  return true
end

function Bridge.status()
  return {
    installed = Bridge.installed,
    active = Bridge.active,
    mapId = Bridge.mapId,
    currentMapId = Bridge.currentMapId,
    currentMapPresented = Bridge.currentMapRef ~= nil
      and Bridge.currentOnlyPresentedMapRef == Bridge.currentMapRef,
    mapTransitionSerial = Bridge.mapTransitionSerial,
    mapTransitionResets = Bridge.mapTransitionResets,
    mapTransitionHold = Bridge.mapTransitionHold ~= nil,
    mapTransitionHoldFrames = Bridge.mapTransitionHoldFrames,
    mapGeometryInvalidations = Bridge.mapGeometryInvalidations,
    mapLifecycleReason = Bridge.mapLifecycleReason,
    mapLifecycleError = Bridge.mapLifecycleError,
    framesAttempted = Bridge.framesAttempted,
    frames3d = Bridge.frames3d,
    framesPending = Bridge.framesPending,
    framesFailed = Bridge.framesFailed,
    extraEntitiesProvider = type(Bridge.extraEntitiesProvider) == "function",
    extraEntitiesMerged = Bridge.extraEntitiesMerged,
    connectedMaps = V.goldNeighbors and #V.goldNeighbors or 0,
    openWorld = Bridge.openWorld == true,
    pokemonModels = modelsEnabled(),
    playerModel = playerModelsEnabled(),
    openWorldMaps = Bridge.openWorldMaps or 0,
    openWorldDirectMaps = Bridge.openWorldDirectMaps or 0,
    openWorldGraphBuilds = Bridge.openWorldGraphBuilds or 0,
    openWorldGraphRoot = Bridge.openWorldGraphRoot,
    openWorldGraphError = Bridge.openWorldGraphError,
    openWorldDepth = Bridge.openWorldDepth or 1,
    openWorldZoom = Bridge.openWorldZoom or 1,
    openWorldFallbacks = Bridge.openWorldFallbacks or 0,
    openWorldOverlapRejects = Bridge.openWorldOverlapRejects or 0,
    neighborWarmupPending = Bridge.neighborWarmupPending == true,
    neighborDirectComplete = Bridge.neighborDirectComplete == true,
    neighborWarmupError = Bridge.neighborWarmupError,
    openWorldLoadedMaps = (function()
      if not (Bridge.openWorld and ChunkMesher and type(ChunkMesher.peek) == "function") then
        return 0
      end
      local n = Bridge.mapId and 1 or 0
      for _, nb in ipairs((V and V.goldOpenWorldMaps) or {}) do
        if ChunkMesher.peek(nb.map, true) or ChunkMesher.peek(nb.map, false) then
          n = n + 1
        end
      end
      return n
    end)(),
    openWorldPendingBuilds = (ChunkMesher and type(ChunkMesher.pending) == "function")
      and ChunkMesher.pending() or 0,
    voxelDiskCache = (ChunkMesher and type(ChunkMesher.diskCacheStatus) == "function")
      and ChunkMesher.diskCacheStatus() or nil,
    syncBuildMapId = Bridge.syncBuildMapId,
    syncBuildAttemptMapId = Bridge.syncBuildAttemptMapId,
    syncBuildRetryAt = Bridge.syncBuildRetryAt,
    syncBuilds = Bridge.syncBuilds,
    syncBuildFailures = Bridge.syncBuildFailures,
    asyncBuildFrames = Bridge.asyncBuildFrames,
    asyncBuildReadyMs = Bridge.asyncBuildReadyMs,
    meshPendingFrames = Bridge.meshPendingFrames,
    pendingWarpMapId = Bridge.pendingWarpMapId,
    pendingWarpRequestedMapId = Bridge.pendingWarpRequestedMapId,
    warpPrefetches = Bridge.warpPrefetches,
    warpPrefetchReady = Bridge.warpPrefetchReady,
    warpPrefetchFailures = Bridge.warpPrefetchFailures,
    warpPrefetchError = Bridge.warpPrefetchError,
    cameraMode = Bridge.cameraMode,
    cameraLevel = Bridge.cameraLevel,
    configuredVoxel = configuredVoxelModeEnabled(),
    selectorPipelineLevel = selectorPipelineLevel(),
    pendingPipelineRestoreMode = Bridge.pendingPipelineRestoreMode,
    pendingPipelineRestoreFrames = Bridge.pendingPipelineRestoreFrames,
    pendingPipelineRestoreStableFrames = Bridge.pendingPipelineRestoreStableFrames,
    cameraProvider = Bridge.cameraProvider,
    transitionSnapshotSerial = Bridge.transitionSnapshotSerial,
    transitionSnapshots = Bridge.transitionSnapshots,
    transitionBackgroundFrames = Bridge.transitionBackgroundFrames,
    transitionBackgroundFallbacks = Bridge.transitionBackgroundFallbacks,
    transitionBackgroundLastReason = Bridge.transitionBackgroundLastReason,
    transitionBackgroundReceipt = Bridge.lastPresentedFrame and {
      mapId = Bridge.lastPresentedFrame.mapId,
      mapTransitionSerial = Bridge.lastPresentedFrame.mapTransitionSerial,
      cameraMode = Bridge.lastPresentedFrame.cameraMode,
      cameraLevel = Bridge.lastPresentedFrame.cameraLevel,
      frameSerial = Bridge.lastPresentedFrame.frameSerial,
    } or nil,
    transitionBattleReceipt = (function()
      if not (OverworldBattle
          and type(OverworldBattle.transitionBackgroundReceipt) == "function") then
        return nil
      end
      local ok, value = pcall(OverworldBattle.transitionBackgroundReceipt)
      return ok and value or nil
    end)(),
    selectorDetected = Bridge.selectorDetected,
    externalCameraLevel = Bridge.externalCameraLevel,
    externalCameraLabel = Bridge.externalCameraLabel,
    cameraInputInstalled = Bridge.cameraInputInstalled,
    cameraInputError = Bridge.cameraInputError,
    pinchZoomInstalled = Bridge.pinchZoomInstalled,
    pinchZoomError = Bridge.pinchZoomError,
    battlePinchChanges = CamControl and CamControl.pinchChanges or 0,
    battlePinchTarget = CamControl and CamControl.lastPinchTarget or nil,
    battlePinchError = Bridge.battlePinchError,
    cameraMovementInstalled = Bridge.cameraMovementInstalled,
    cameraMovementError = Bridge.cameraMovementError,
    cameraMovement = (GoldCameraControls and GoldCameraControls.status
      and GoldCameraControls.status()) or nil,
    cameraHotkeyCycles = Bridge.cameraHotkeyCycles,
    cameraHotkeyPollCycles = Bridge.cameraHotkeyPollCycles,
    f6Down = Bridge.f6Down,
    vDown = Bridge.vDown,
    cameraSliderInstalled = Bridge.cameraSliderInstalled,
    cameraSliderTouches = Bridge.cameraSliderTouches,
    cameraSliderChanges = Bridge.cameraSliderChanges,
    platform = platformName(),
    battleInstalled = Bridge.battleInstalled,
    battleError = Bridge.battleError,
    battleActive = Bridge.battleShot() ~= nil,
    fieldMovePresentationInstalled = Bridge.fieldMovePresentationInstalled,
    fieldMovePresentationError = Bridge.fieldMovePresentationError,
    fieldMovePresentation = (GoldFieldMovePresentation
      and type(GoldFieldMovePresentation.status) == "function"
      and GoldFieldMovePresentation.status()) or nil,
    fishingPresentationInstalled = Bridge.fishingPresentationInstalled,
    fishingPresentationError = Bridge.fishingPresentationError,
    fishingPresentation = (SpeciesFishingCinematic
      and type(SpeciesFishingCinematic.status) == "function"
      and SpeciesFishingCinematic.status(Bridge.game and Bridge.game.world)) or nil,
    captureAvailable = Bridge.captureAvailable,
    captureError = Bridge.captureError,
    captureCameraOverride = Bridge.captureCameraOverride,
    capture = (OverworldCapture and OverworldCapture.status
      and OverworldCapture.status()) or nil,
    meshError = (ChunkMesher and type(ChunkMesher.lastError) == "function"
      and Bridge.mapId and ChunkMesher.lastError(Bridge.mapId)) or nil,
    lastError = Bridge.lastError,
  }
end

-- Test/diagnostic accessors; no engine mutation.
Bridge._mergedEntities = mergedEntities
Bridge._adaptedNeighbors = adaptedNeighbors
Bridge._currentMasks = currentMasks
Bridge._makeState = makeState
Bridge._directNeighborSpecs = directNeighborSpecs
Bridge._allConnectedNeighborSpecs = allConnectedNeighborSpecs
Bridge._neighborUrgent = neighborUrgent
Bridge._selectorCameraMode = selectorCameraMode
Bridge._externalCameraEnabled = externalCameraEnabled
Bridge._optionCameraControl = optionCameraControl
Bridge._optionDioramaTilt = optionDioramaTilt
Bridge._mapGeometrySignature = geometrySignature
Bridge._rememberMapGeometry = rememberMapGeometry
Bridge._markMapGeometryDirty = markMapGeometryDirty
Bridge._resetMapRoot = resetMapRoot

return Bridge
