-- Ascendant ORAS Battle HUD v0.5.0-vasc.1
-- Integrated compact HUD for Voxel Ascendant staged battles. VASC remains the
-- autonomous default owner; an optional Kanto Ascendant provider can claim the
-- public replacement slot without becoming a package dependency. Derived from
-- Floating Battle HUD v0.7.18 under the MIT License; see THIRD_PARTY_NOTICES.md.
--
-- v0.3 is the visual reset: the frosted cards are gone. The HUD is built
-- around x8 transparent battleplate art inspired by Gen I's original battle
-- furniture, while the live information remains code-driven. Each deployed
-- Pokemon supplies one exact alpha-ink head receipt; its complete status-card
-- rectangle follows that semantic owner's current head/hull with a fixed
-- clearance behind and above the visible Pokemon.

return function(mod, Bundle)
Bundle = type(Bundle) == "table" and Bundle or {}
local INTEGRATED_KASC = mod.id == "kanto_ascendant"
local INTEGRATED_VASC = mod.id == "VOXEL_ASCENDANT"
                     or mod.id == "voxel_ascendant"
local activeRuntimeGame = nil

-- Dramatic Shape, PotatoVoxel and Voxel Ascendant expose the same public
-- companion-module seam. Probe the known manifest ids and adapt to the HUD
-- integration owned by whichever host is installed.
local HOST_IDS = {
  "DRAMATIC_SHAPE",
  "POTATO_VOXEL",
  "POTATO_VOXEL_MOD",
  "potato_voxel",
  "VOXEL_ASCENDANT",
  "voxel_ascendant",
}
local ds, hostId = nil, nil
-- VASC loads this same factory only after its public library has been
-- exported. Do not depend on a loader returning the current mod from find();
-- the self-host path is explicit and keeps a standalone VASC package robust.
if INTEGRATED_VASC and mod.exports and mod.exports.lib then
  ds, hostId = mod, mod.id
elseif mod.find then
  for _, id in ipairs(HOST_IDS) do
    local hit = mod.find(id)
    if hit and hit.exports and hit.exports.lib then
      ds, hostId = hit, id
      break
    end
  end
end
if not (ds and ds.exports and ds.exports.lib) then
  mod.exports.ascendantBattleHud = {
    apiVersion = 1,
    available = false,
    supports = { MAP=true, ARENA=true, DISCS=true },
  }
  mod.log:info("KASC ORAS Battle HUD: no staged HUD host; native HUD retained")
  return
end

local V = ds.exports.lib
local OverworldBattle = V.require("OverworldBattle")
local BattleCam = V.require("BattleCam")
local BattleHudExtras = nil
do
  local ok, value = pcall(V.require, "BattleHudExtras")
  if ok and type(value) == "table" then BattleHudExtras = value end
end
-- Diagnostics belongs to the VASC bootstrap, not to this independently
-- loadable HUD factory. Resolve it through the renderer library and retain a
-- no-op writer when an older/custom host does not expose that optional module.
-- Presentation and battle flow must never depend on logging being available.
local Diagnostics = { write=function() return false end }
do
  local ok, value = pcall(V.require, "Diagnostics")
  if ok and type(value) == "table" and type(value.write) == "function" then
    Diagnostics = value
  end
end
-- The public companion facade intentionally hides the monitor. The bundled
-- HUD receives only a report callback; no diagnostics settings or storage
-- capabilities need to become public just to acknowledge the first frame.
local reportPerformanceHud = type(Bundle.ReportHud) == "function"
  and Bundle.ReportHud or nil
if not reportPerformanceHud then
  local ok, value = pcall(V.require, "PerformanceDiagnostics")
  if ok and type(value) == "table"
      and type(value.reportHud) == "function" then
    reportPerformanceHud = value.reportHud
  end
end
local EditionAccent = ds.exports.editionAccent
-- The bundled VASC HUD is installed from inside the renderer owner, but all
-- ordinary reads still go through the same public facade as companions.  RC11
-- deliberately withholds both mutable provider setters from that facade, so
-- main_gen1 supplies only this one bounded default-slot registration
-- capability to its own factory.  It is never exported or available to KASC.
local registerBundledProvider = INTEGRATED_VASC
  and Bundle.RegisterDefaultBattleHudProvider or nil
local hostProviderAvailable =
  type(registerBundledProvider) == "function"
  or type(OverworldBattle.setBattleHudProvider) == "function"

-- Ascendant advertises its renderer identity through exports.renderer even when a
-- packaging fork uses a different manifest id. Prefer that stable public identity.
local rendererId = ds.exports and ds.exports.renderer and ds.exports.renderer.id or nil
local isAscendantHost = hostId == "VOXEL_ASCENDANT"
                     or hostId == "voxel_ascendant"
                     or rendererId == "VOXEL_ASCENDANT"

-- Voxel Ascendant intentionally withholds its legacy cross-canvas HUD compositor
-- on iOS: Gen1Recomp presents the world canvas inverted there. This companion does
-- not request that unsafe compositor. It masks the owner's already-reserved native
-- surfaces and draws only through drawHudPanels using the same private pre-flip.
local function detectedOS()
  -- Current mobile hosts expose LÖVE through a sandbox proxy and may advertise
  -- an OS X compatibility Platform. Presentation follows the native renderer,
  -- so prefer love.system and retain love._os as the sandbox-safe fallback.
  local runtime = love
  local function member(owner, key)
    if type(owner) ~= "table" then return nil end
    local okValue, value = pcall(function() return owner[key] end)
    if okValue then return value end
    return nil
  end
  local system = member(runtime, "system")
  local getOS = member(system, "getOS")
  local nativeOS = nil
  if type(getOS) == "function" then
    local okNative, value = pcall(getOS)
    if okNative and type(value) == "string" and value ~= "" then
      nativeOS = value
      if value == "iOS" or value == "Android" then return value end
    end
  end
  local ok, Platform = pcall(require, "src.core.Platform")
  if ok and type(Platform) == "table" and type(Platform.detect) == "function" then
    local detected, info = pcall(Platform.detect)
    if detected and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  local osName = member(runtime, "_os")
  if type(osName) == "string" and osName ~= "" then return osName end
  return nativeOS
end

local PLATFORM_OS = detectedOS()
local hostFloatingAvailable = not isAscendantHost
  or type(OverworldBattle.drawHudPanels) == "function"

-- Legacy Dramatic Shape alone exposes the donor BattleHud/textRects composite we
-- reuse for unreplaced phases. Ascendant may also advertise snapHUDs off iOS, but
-- its public facade deliberately does not expose BattleHud and its active path is
-- drawHudPanels, so never classify it as Dramatic Shape from snapHUDs alone.
local BattleHud = nil
if not isAscendantHost and type(OverworldBattle.snapHUDs) == "function" then
  local ok, value = pcall(V.require, "BattleHud")
  if ok then BattleHud = value end
end

-- Private engine modules: manifest requests engine_internals.
local BattleState = require("src.battle.BattleState")
local Game = require("src.core.Game")
local Font = require("src.render.Font")
local ListMenu = require("src.ui.ListMenu")
local Growth = require("src.pokemon.Growth")
do
  local ok, value = pcall(require, "src.core.TouchControls")
  if ok and type(value) == "table" then Bundle.TouchControls = value end
end
if not (type(Bundle.MessageLayout) == "table"
    and type(Bundle.MessageLayout.layout) == "function") then
  Bundle.MessageLayout = V.require("OrasBattleMessageLayout")
end
if not (type(Bundle.MessageLayout) == "table"
    and type(Bundle.MessageLayout.layout) == "function") then
  error("ASCENDANT_BATTLE_HUD_REVIEW: message layout bundle missing", 0)
end

local g = love.graphics
local FloatingHud = {}

-- Translate the platform safe rectangle into the staged HUD viewport. Desktop
-- normally returns zero insets; phones keep controls above the home indicator,
-- notch or display cut-out even when the world canvas is scaled separately.
function FloatingHud.safeInsets(shot)
  if not (shot and love and love.window
      and type(love.window.getSafeArea) == "function"
      and g and type(g.getDimensions) == "function") then
    return 0, 0, 0, 0
  end
  local okWindow, windowW, windowH = pcall(g.getDimensions)
  local okSafe, x, y, width, height = pcall(love.window.getSafeArea)
  if not (okWindow and okSafe and tonumber(windowW) and tonumber(windowH)
      and windowW > 0 and windowH > 0 and tonumber(x) and tonumber(y)
      and tonumber(width) and tonumber(height) and width > 0 and height > 0) then
    return 0, 0, 0, 0
  end
  local sx = (tonumber(shot.pw) or windowW) / windowW
  local sy = (tonumber(shot.ph) or windowH) / windowH
  return math.max(0, x * sx), math.max(0, y * sy),
         math.max(0, (windowW - x - width) * sx),
         math.max(0, (windowH - y - height) * sy)
end

-- Gen I's SE_WAVY_SCREEN (used by Psychic, Night Shade and Psywave) scrolls
-- the complete BG tilemap one scanline at a time. In a staged voxel battle the
-- world and this mod's floating plates live in shot.canvas instead, so the
-- engine's original pass has almost nothing left to bend. Reapply the same
-- eight-step offset pattern to the staged canvas while that semantic effect is
-- active. The move's OAM sprites are still drawn later by BattleState and stay
-- unwarped, matching the original BG-vs-OBJ split.
local SCENE_WAVE_SHADER_SOURCE = [[
  uniform float wavePhase;
  uniform float rowScale;
  uniform float rowOrigin;
  uniform vec2 canvasSize;

  float waveOffset(float index) {
    float i = mod(index + 1024.0, 32.0);
    if (i < 5.0) return 0.0;
    if (i < 8.0) return 1.0;
    if (i < 13.0) return 2.0;
    if (i < 16.0) return 1.0;
    if (i < 21.0) return 0.0;
    if (i < 24.0) return -1.0;
    if (i < 29.0) return -2.0;
    return -1.0;
  }

  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float logicalRow = floor((tc.y * canvasSize.y - rowOrigin)
                             / max(1.0, rowScale));
    float dx = waveOffset(logicalRow + wavePhase) * rowScale;
    float sourceX = tc.x * canvasSize.x - dx;
    if (sourceX < 0.0 || sourceX >= canvasSize.x) discard;
    return Texel(tex, vec2(sourceX / canvasSize.x, tc.y)) * color;
  }
]]

local sceneWaveShader = nil
local sceneWaveShaderUnavailable = false
local sceneWaveCanvas = nil
local sceneWaveW, sceneWaveH = nil, nil
local sceneWaveWarned = false

local function getSceneWaveShader()
  if sceneWaveShaderUnavailable then return nil end
  if sceneWaveShader then return sceneWaveShader end
  local ok, shader = pcall(g.newShader, SCENE_WAVE_SHADER_SOURCE)
  if not (ok and shader) then
    sceneWaveShaderUnavailable = true
    if not sceneWaveWarned then
      sceneWaveWarned = true
      mod.log:warn("floating battle scene wave unavailable: %s",
                   tostring(shader))
    end
    return nil
  end
  sceneWaveShader = shader
  return shader
end

local function getSceneWaveCanvas(w, h)
  if sceneWaveCanvas and sceneWaveW == w and sceneWaveH == h then
    return sceneWaveCanvas
  end
  local ok, canvas = pcall(g.newCanvas, w, h, { dpiscale = 1 })
  if not (ok and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest")
  sceneWaveCanvas, sceneWaveW, sceneWaveH = canvas, w, h
  return canvas
end

local function applySceneWave(battle, shot)
  local wavy = battle and battle.fx and battle.fx.wavy
  local target = shot and shot.canvas
  if not (wavy and target and PLATFORM_OS ~= "iOS") then return false end
  if battle._floatingBattleSceneWaveFrame == battle.frame
      and battle._floatingBattleSceneWaveTarget == target then
    return true
  end

  local shader = getSceneWaveShader()
  local width, height = target:getWidth(), target:getHeight()
  local copy = shader and getSceneWaveCanvas(width, height) or nil
  if not copy then return false end

  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()
  local prevR, prevG, prevB, prevA = g.getColor()
  g.push("all")
  local ok, err = pcall(function()
    g.origin()
    g.setScissor()
    -- First take a stable snapshot. Sampling from the canvas currently being
    -- written is undefined on several LOVE backends, especially Android.
    g.setCanvas(copy)
    g.setShader()
    g.setBlendMode("replace", "premultiplied")
    g.clear(0, 0, 0, 0)
    g.setColor(1, 1, 1, 1)
    g.draw(target, 0, 0)

    -- Draw the shifted snapshot over the original. Discarded edge pixels leave
    -- the unshifted world visible instead of creating black side slivers.
    g.setCanvas(target)
    g.setBlendMode("alpha")
    g.setShader(shader)
    shader:send("wavePhase", tonumber(wavy.phase) or 0)
    shader:send("rowScale", math.max(1, tonumber(shot.scale) or 1))
    shader:send("rowOrigin", tonumber(shot.ly) or 0)
    shader:send("canvasSize", { width, height })
    g.setColor(1, 1, 1, 1)
    g.draw(copy, 0, 0)
  end)
  g.pop()

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(prevR, prevG, prevB, prevA)
  if not ok then error(err, 0) end

  battle._floatingBattleSceneWaveFrame = battle.frame
  battle._floatingBattleSceneWaveTarget = target
  return true
end

-- One accessor for the three host families. Dramatic Shape / PotatoVoxel attach
-- their current staged shot directly to BattleState; Ascendant uses its own field
-- and also exposes OverworldBattle.shot(). Keeping this translation here prevents
-- host-specific names from leaking through every pushed menu/foreground path.
local function battleShot(battle)
  if not hostFloatingAvailable then return nil end
  if battle then
    local direct = battle.voxelAscendantShot or battle.dramaticShapeShot
    if direct and direct.canvas then return direct end
  end
  if OverworldBattle and type(OverworldBattle.shot) == "function" then
    local ok, shot = pcall(OverworldBattle.shot)
    if ok and shot and shot.canvas then return shot end
  end
  return nil
end

-- The engine font sheet is black-on-transparent. LOVE tinting multiplies RGB,
-- so setting white cannot turn those black pixels white. Draw the exact same
-- glyphs through a mask shader instead: source alpha supplies the shape and
-- `ink` supplies the requested colour.
local TEXT_MASK_SHADER_SOURCE = [[
  uniform vec4 ink;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 src = Texel(tex, tc);
    return vec4(ink.rgb, ink.a * src.a * color.a);
  }
]]

local textMaskShader = nil
local function getTextMaskShader()
  if textMaskShader == false then return nil end
  if textMaskShader then return textMaskShader end
  local ok, shader = pcall(g.newShader, TEXT_MASK_SHADER_SOURCE)
  textMaskShader = (ok and shader) or false
  return textMaskShader or nil
end

-- ---------------------------------------------------------------------------
-- User-facing options
-- ---------------------------------------------------------------------------

if not INTEGRATED_KASC and not INTEGRATED_VASC then mod.options:define({
  {
    key = "hud_language",
    type = "choice",
    label = "HUD LANGUAGE",
    default = "auto",
    choices = {
      { "AUTO",    "auto" },
      { "DEUTSCH", "de" },
      { "ENGLISH", "en" },
    },
  },
  {
    key = "hud_scale",
    type = "choice",
    label = "HUD SIZE",
    default = 0.9,
    choices = {
      { "75%",  0.75 },
      { "90%",  0.9 },
      { "100%", 1.0 },
      { "125%", 1.25 },
      { "150%", 1.5 },
      { "200%", 2.0 },
    },
  },
  {
    key = "status_anchor",
    type = "choice",
    label = "STATUS ANCHOR",
    default = "outside",
    choices = {
      { "OUTSIDE POKEMON", "outside" },
      { "ABOVE POKEMON",   "above" },
      { "SCREEN CORNERS",  "corners" },
    },
  },
  {
    key = "player_hud_x",
    type = "choice",
    label = "PLAYER HUD X",
    default = 0,
    choices = {
      { "-80", -80 }, { "-40", -40 }, { "0", 0 },
      { "+40", 40 }, { "+80", 80 },
    },
  },
  {
    key = "player_hud_y",
    type = "choice",
    label = "PLAYER HUD Y",
    default = 0,
    choices = {
      { "-80", -80 }, { "-40", -40 }, { "0", 0 },
      { "+40", 40 }, { "+80", 80 },
    },
  },
  {
    key = "enemy_hud_x",
    type = "choice",
    label = "ENEMY HUD X",
    default = 0,
    choices = {
      { "-80", -80 }, { "-40", -40 }, { "0", 0 },
      { "+40", 40 }, { "+80", 80 },
    },
  },
  {
    key = "enemy_hud_y",
    type = "choice",
    label = "ENEMY HUD Y",
    default = 0,
    choices = {
      { "-80", -80 }, { "-40", -40 }, { "0", 0 },
      { "+40", 40 }, { "+80", 80 },
    },
  },
  {
    key = "wild_dvs",
    type = "toggle",
    label = "WILD DVs",
    default = false,
  },
}) end

-- Keep the two major presentation layers independently switchable. This is
-- intentionally queried at draw/update time rather than cached at startup so a
-- launcher that applies mod options live can hand ownership back to another UI
-- mod without requiring separate compatibility builds.
local function optionChoice(key, fallback)
  -- The in-game VASC/KASC pages write the active save immediately, while the
  -- launcher-facing mod.options reader may still describe the boot value.
  -- Prefer the live VASC bucket so ORAS -> STANDARD -> ORAS takes effect in
  -- the same process; then fail open to the ordinary options API.
  local game = activeRuntimeGame
  if not game and mod.world then game = mod.world.game end
  local okSaved, saved = pcall(function()
    local options = game and game.save and game.save.options
    local buckets = options and options.modOptions
    if type(buckets) ~= "table" then return nil end
    local own = type(mod.id) == "string" and buckets[mod.id] or nil
    return type(own) == "table" and own[key] or nil
  end)
  if okSaved and saved ~= nil then return tostring(saved) end
  local ok, value = pcall(function() return mod.options:get(key) end)
  if not ok or value == nil then return fallback end
  return tostring(value)
end

local function optionEnabled(key, fallback)
  local value = optionChoice(key, fallback == true)
  if type(value) == "boolean" then return value end
  value = tostring(value):lower()
  return value == "true" or value == "1" or value == "on"
      or value == "yes"
end

function FloatingHud.wildDVsEnabled()
  return optionEnabled("wild_dvs", false)
end

local function glassStrength(key, fallback)
  local value = tonumber(optionChoice(key, tostring(fallback))) or fallback
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

-- Public, side-effect-free probes keep visual QA honest: card/message geometry
-- never depends on these values, and tests can prove that only backing pixels
-- change. A value of 100% means the previously reviewed authored alpha rather
-- than forcing every layer opaque.
function FloatingHud.statusGlassStrength()
  return glassStrength("oras_status_glass", 0.75)
end

function FloatingHud.textGlassStrength()
  return glassStrength("oras_text_glass", 0.65)
end

local function hudStyle()
  -- v0.3 intentionally has one coherent visual language. Stale v0.2 launcher
  -- settings are ignored so an old FRLG selection cannot resurrect a half-
  -- implemented layout after updating the standalone mod.
  return "oras"
end

local function battleHudEnabled(battle)
  -- VASC is a permanent autonomous fallback. A compatible KASC HUD occupies
  -- OverworldBattle's higher-priority public provider slot; an exclusive KASC
  -- STANDARD choice suppresses this default in the compositor itself. Mere
  -- KASC installation must not remove VASC's only readable HUD.
  --
  -- Once a concrete staged battle begins, its STANDARD/ORAS decision belongs
  -- to the immutable presentation plan beside mode and back-sprite policy.
  -- Reading the live option each frame let one menu edit build impossible
  -- hybrids (ORAS HUD + classic back slot, or native HUD + front-only scene).
  if isAscendantHost
      and type(OverworldBattle.presentationPlan) == "function" then
    local okPlan, plan = pcall(OverworldBattle.presentationPlan, battle)
    if okPlan and type(plan) == "table" and plan.standardHud ~= nil then
      return plan.standardHud ~= true
    end
    -- A concrete foreign/recycled BattleState must never fall through to the
    -- current menu option while another encounter owns the staged session.
    -- Without an exact plan there is no VASC draw receipt, so keep that screen
    -- native. Nil remains the deliberate pre-battle/settings query.
    if battle ~= nil then return false end
  end
  local key = INTEGRATED_VASC and "battleHudStyle" or "battle_hud_style"
  return optionChoice(key, "oras"):lower() ~= "standard"
end

local function companionHandle(id)
  if type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, id)
  return ok and type(handle) == "table" and handle or nil
end

local function companionExports(id)
  local handle = companionHandle(id)
  return handle and type(handle.exports) == "table" and handle.exports or nil
end

-- Kanto Ascendant 6.5+ uses its public package id; the original 6.0 release
-- shipped under trainer_rematch. Prefer the current identity while keeping the
-- standalone HUD usable with existing 6.0 installations.
local function kascExports()
  if INTEGRATED_KASC then return mod.exports end
  return companionExports("kanto_ascendant")
      or companionExports("trainer_rematch")
end

local function kascHandle()
  if INTEGRATED_KASC then return mod end
  return companionHandle("kanto_ascendant")
      or companionHandle("trainer_rematch")
end

local function kascOptionEnabled(key)
  local handle = kascHandle()
  local options = handle and handle.options or nil
  if type(options) ~= "table" or type(options.get) ~= "function" then
    return true
  end
  local ok, value = pcall(options.get, options, key)
  return not ok or value ~= false
end

local function hudLanguage()
  local chosen = optionChoice("hud_language", "auto"):lower()
  if chosen == "de" or chosen == "en" then return chosen end
  -- Universal German owns the language of the base game and is therefore the
  -- authoritative AUTO source. Older KASC builds return EN from their own
  -- AUTO resolver because they only know the retired deutsch* package ids.
  local translation = companionExports("translation-german-universal")
  if translation and (translation.bootLanguage == "de"
      or translation.bootLanguage == "en") then
    return translation.bootLanguage
  end
  local kasc = kascExports()
  if kasc and type(kasc.language) == "function" then
    local ok, language = pcall(kasc.language)
    if ok and (language == "de" or language == "en") then return language end
  end
  return "en"
end

local HUD_THEMES = {
  float = {
    plate={1,1,1}, text={1,1,1}, shadow={0,0,0}, accent={0.25,0.78,1.0},
  },
  oras = {
    plate={0.07,0.18,0.25}, text={0.94,0.99,1.0},
    shadow={0.01,0.03,0.06}, accent={0.28,0.88,1.0},
  },
}

local function hudTheme()
  return HUD_THEMES[hudStyle()] or HUD_THEMES.oras
end

local function editionAccentColor()
  if type(EditionAccent) == "table"
      and type(EditionAccent.color) == "function" then
    local ok, value, id = pcall(EditionAccent.color)
    if ok and type(value) == "table" then return value, id or "shared" end
  end
  return { 0.04, 0.80, 0.97, 1 }, "shared"
end

function FloatingHud.editionAccent()
  return editionAccentColor()
end

-- One thin outer signal carries the active edition. The ORAS fills, typography,
-- HP/EXP colours and interaction states stay common across both generations.
local function drawEditionCardBorder(kind, x, y, width, height, radius, lineWidth)
  if hudStyle() ~= "oras" then return false end
  local accent = editionAccentColor()
  g.setColor(accent[1], accent[2], accent[3], accent[4] or 1)
  g.setLineWidth(lineWidth or 1)
  if kind == "status" then
    g.polygon("line",
      x + 1, y + 1, x + width - 6, y + 1,
      x + width - 12, y + height - 3, x, y + height - 3)
  else
    g.rectangle("line", x, y, width, height, radius or 0, radius or 0)
  end
  g.setLineWidth(1)
  return true
end

local function floatingStatusHudEnabled(battle)
  return hostFloatingAvailable and battleHudEnabled(battle)
end

local function floatingCommandsEnabled(battle)
  return hostFloatingAvailable and battleHudEnabled(battle)
end

local HUD_SCALE_CHOICES = {
  [0.75] = true, [0.9] = true, [1.0] = true,
  [1.25] = true, [1.5] = true, [2.0] = true,
}

local function floatingHudScale()
  local ok, value = pcall(function() return mod.options:get("hud_scale") end)
  value = ok and tonumber(value) or 0.9
  if not HUD_SCALE_CHOICES[value] then return 0.9 end
  return value
end

-- ---------------------------------------------------------------------------
-- Asset convention
-- ---------------------------------------------------------------------------

-- All authored HUD art is exported at x8. One logical HUD pixel therefore
-- corresponds to eight source pixels, regardless of the window/UI scale.
FloatingHud.ASSET_SCALE = 1 / 8
FloatingHud.SHADOW_PX = 2       -- shadow offset in final framebuffer pixels
-- Expand the hard pixel shadow around its offset silhouette without moving it farther
-- from the white HUD. 0 = original single copy; 1 is the recommended default; 2 is
-- a chunkier outline if the HUD is being viewed at a large window scale.
FloatingHud.SHADOW_GROW_PX = 3
FloatingHud.MAX_SCALE = 3
FloatingHud.MARGIN = 4

-- Compact defaults. Status cards remain readable at native pixel scale but take
-- substantially less arena space; the larger selection surfaces keep slightly
-- more room for translated names, PP and touch-safe engine input.
FloatingHud.STATUS_SCALE = 1.53
-- The ORAS controls are authored proportionally and then allowed to shrink as
-- one group on narrow portrait screens. Roomy viewports receive the requested
-- 150% presentation without stretching any source image in one axis.
FloatingHud.CONTROL_SCALE = 1.50
FloatingHud.DOCK_HEIGHT_SHARE = 0.31
-- A bottom command surface may grow with the user's HUD scale, but an
-- ultrawide framebuffer must never turn its transparent layout plane into a
-- near-full-width camera obstacle. 720 logical pixels comfortably contains
-- the authored ORAS cluster including Mega while leaving the battle visible.
FloatingHud.DOCK_MAX_LOGICAL_WIDTH = 720
-- Localised FIGHT sprites have deliberately different cropped source bounds
-- (for example the German art is 67x20 while English is 69x32). They still
-- occupy one authored design box so a shorter word cannot become much larger.
FloatingHud.ORAS_FIGHT_DESIGN_W = 69
FloatingHud.ORAS_FIGHT_DESIGN_H = 32

-- Overall HUD size is now a platform-independent user option. v0.7.1 used a
-- hard-coded mobile x1.20 multiplier; the same seam is generalized so desktop,
-- handheld and mobile users can choose one consistent scale from the mod menu.

-- Camera-distance response. Dramatic Shape reports how wide the Pokemon's
-- overworld cell projects on screen (`playerSpan` / `enemySpan`). A full-size
-- Gen-I front sprite is authored around a 56px slot, so span / 56 is a useful
-- approximation of the Pokemon's own apparent scale. Clamp it so the HUD keeps
-- breathing with perspective without ever becoming unreadably tiny or huge.
FloatingHud.REFERENCE_SPAN = 56
FloatingHud.DISTANCE_SCALE_MIN = 0.68
FloatingHud.DISTANCE_SCALE_MAX = 1.32
FloatingHud.CAMERA_CENTER_OFFSET = 0.12

-- Very small 2D Z-roll driven only by Dramatic Shape camera yaw. Zoom no longer
-- contributes to orientation; it is reserved exclusively for distance scaling.
FloatingHud.MAX_ROTATION_DEG = 3.0

-- Faux Y-axis perspective. At full camera travel the near vertical edge is
-- PERSPECTIVE_DEPTH taller than neutral and the far edge the same amount
-- shorter. The whole plane also narrows slightly, like a card yawed away from
-- the viewer. Set PERSPECTIVE_DEPTH = 0 to return to the flat v0.4.1 HUD.
FloatingHud.PERSPECTIVE_DEPTH = -0.20
FloatingHud.PERSPECTIVE_WIDTH_SQUEEZE = 0.06
-- Subdivide the projected card so texture interpolation does not reveal LOVE's
-- underlying two-triangle split on strongly skewed quads.
FloatingHud.PERSPECTIVE_GRID_X = 12
FloatingHud.PERSPECTIVE_GRID_Y = 6
FloatingHud.CANVAS_PAD = 5
-- Render the intermediate HUD texture at higher resolution, then project it
-- back to the same on-screen size. This preserves the aligned logical layout
-- while giving the perspective mesh substantially more texels to work with.
FloatingHud.CANVAS_RENDER_SCALE = 4

local PLATE_ASSETS = {
  enemy = "assets/hud/battleplate_enemy.png",
  player = "assets/hud/battleplate_player.png",
}

local STATUS_ASSETS = {
  SLP = "assets/hud/status_sleep.png",
  PSN = "assets/hud/status_poison.png",
  BRN = "assets/hud/status_burn.png",
  PAR = "assets/hud/status_paralysis.png",
  FRZ = "assets/hud/status_frozen.png",
}

local STATUS_FALLBACK = {
  SLP = "SLP",
  PSN = "PSN",
  BRN = "BRN",
  PAR = "PAR",
  FRZ = "FRZ",
}

local CAUGHT_ASSET = "assets/hud/caught.png"

-- Floating battle-flow furniture. These follow the exact same x8 white-mask
-- convention as the Pokemon nameplates.
local MESSAGE_PLATE_ASSET = "assets/hud/battle_message_plate.png"
local MESSAGE_CURSOR_ASSET = "assets/hud/battle_message_cursor.png"
local COMMAND_PLATE_ASSET = "assets/hud/battle_command_plate.png"
local COMMAND_SELECTOR_ASSET = "assets/hud/battle_command_selector.png"
local FIGHT_PLATE_ASSET = "assets/hud/fight_command_plate.png"
local FIGHT_DIVIDER_ASSET = "assets/hud/fight_command_divider.png"
local MEGA_TRANSFORMATION_ASSET = "assets/hud/oras/mega_transformation.png"
local MEGA_TRANSFORMATION_SOUND = "assets/audio/mega-evolution.mp3"
local FIGHT_CATEGORY_ASSETS = {
  -- The authored PHYSICAL/STATUS glyph files are intentionally crossed here:
  -- the visual symbols in the supplied assets were opposite to their filenames.
  PHYSICAL = "assets/hud/fight_kind_status.png",
  SPECIAL  = "assets/hud/fight_kind_special.png",
  STATUS   = "assets/hud/fight_kind_physical.png",
}
local TRAINER_BALL_ASSETS = {
  alive    = "assets/hud/battleplate_ball.png",
  active   = "assets/hud/battleplate_ball_active.png",
  defeated = "assets/hud/battleplate_ball_defeated.png",
  empty    = "assets/hud/battleplate_ball_empty.png",
}
-- Optional dedicated move-learning support. Until select_command_plate.png is
-- authored, the renderer intentionally falls back to the normal FIGHT plate.
local SELECT_PLATE_ASSET = "assets/hud/select_command_plate.png"
local PKMN_PLATE_ASSET = "assets/hud/pkmn_command_plate.png"
local PKMN_ICON_FOLDER = "assets/hud/pkmn_icons/"

local images = {}

local function assetImage(path)
  if images[path] ~= nil then return images[path] or nil end
  local ok, img = pcall(function() return mod.assets:image(path) end)
  if ok and img then
    if path == MEGA_TRANSFORMATION_ASSET then
      -- This one image is scaled and rotated as a full-screen effect. Linear
      -- sampling keeps its curved energy shell clean on phones and 4K output;
      -- the deliberately pixel-authored HUD furniture remains nearest-filtered.
      pcall(img.setFilter, img, "linear", "linear")
    else
      pcall(img.setFilter, img, "nearest", "nearest")
    end
    images[path] = img
    return img
  end
  images[path] = false
  return nil
end

local function plateImage(side)
  return assetImage(PLATE_ASSETS[side])
end

local function plateSize(side)
  return side == "player" and 178 or 162,
         side == "player" and 58 or 45
end

local function assetLogicalSize(path)
  local img = assetImage(path)
  if not img then return nil, nil end
  local w, h = img:getDimensions()
  return w * FloatingHud.ASSET_SCALE, h * FloatingHud.ASSET_SCALE
end

FloatingHud.STYLE_PANEL_SIZES = {
  oras = {
    command = { 320, 156 },
    fight = { 480, 222 },
    learn = { 480, 192 },
    message = { 288, 64 },
    pkmn = { 320, 112 },
  },
}

function FloatingHud.styleAsset(key)
  local localized = {
    bag=true, fight=true, mega=true, move=true,
    pokemon=true, hp=true, run=true,
  }
  local prefix = localized[key] and (hudLanguage() .. "_") or ""
  return assetImage("assets/hud/oras/" .. prefix .. key .. ".png")
end

function FloatingHud.panelLogicalSize(kind)
  local style = hudStyle()
  local configured = FloatingHud.STYLE_PANEL_SIZES[style]
  if configured and configured[kind] then
    return configured[kind][1], configured[kind][2]
  end
  local paths = {
    command=COMMAND_PLATE_ASSET, fight=FIGHT_PLATE_ASSET,
    message=MESSAGE_PLATE_ASSET, pkmn=PKMN_PLATE_ASSET,
  }
  if kind == "learn" then
    local img = assetImage(SELECT_PLATE_ASSET) or assetImage(FIGHT_PLATE_ASSET)
    if not img then return nil, nil end
    return img:getWidth() * FloatingHud.ASSET_SCALE,
           img:getHeight() * FloatingHud.ASSET_SCALE
  end
  return assetLogicalSize(paths[kind])
end

function FloatingHud.statusAssetsReady()
  return FloatingHud.styleAsset("hp") ~= nil
end

function FloatingHud.commandAssetsReady()
  return FloatingHud.styleAsset("bag") ~= nil
     and FloatingHud.styleAsset("fight") ~= nil
     and FloatingHud.styleAsset("pokemon") ~= nil
     and FloatingHud.styleAsset("run") ~= nil
     and FloatingHud.styleAsset("move") ~= nil
end

local function selectPlateImage()
  return assetImage(SELECT_PLATE_ASSET) or assetImage(FIGHT_PLATE_ASSET)
end

local function selectPlateLogicalSize()
  local img = selectPlateImage()
  if not img then return nil, nil end
  local w, h = img:getDimensions()
  return w * FloatingHud.ASSET_SCALE, h * FloatingHud.ASSET_SCALE
end

-- ---------------------------------------------------------------------------
-- Layout map, in logical HUD pixels
-- ---------------------------------------------------------------------------
--
-- The x8 battleplates are ~105.4 x 63.4 logical pixels. These coordinates are
-- deliberately centralized: after a screenshot, tuning is just moving numbers
-- here rather than touching drawing code.

FloatingHud.LAYOUT = {
  enemy = {
    name       = { x = 13.0,  y = 1.0 },
    gender     = { x = 88.0,  y = 1.0 },
    status     = { x = 5.0,  y = 11.5 },
    level      = { x = 64.5, y = 9.5, scale = 1.15 }, -- digits only; :L is in plate
    caught     = { x = 97.0, y = 8.8 },
    hpFill     = { x = 33.5, y = 23.25, w = 61.25, h = 2.50 },
    hpNumbers  = { right = 97.0, y = 28.5 },
    dvs        = { y = 48.5, scale = 0.75 },
  },

  player = {
    name       = { x = 13.0,  y = 1.0 },
    gender     = { x = 88.0,  y = 1.0 },
    status     = { x = 7.0,  y = 11.5 },
    level      = { x = 60.0, y = 9.5, scale = 1.15 }, -- digits only; :L is in plate
    hpFill     = { x = 29.5, y = 23.25, w = 61.25, h = 2.50 },
    hpNumbers  = { right = 93.5, y = 28.5 },
    -- Blue EXP rides on top of the battleplate's lower support line.
    expFill    = { x = 5.5, y = 41.9, w = 84.0, h = 2.5 },
  },
}

-- Compatibility fallback for hosts that expose only projected feet. VASC's
-- reviewed path uses the exact rendered alpha-ink head receipt instead.
FloatingHud.HEAD_LIFT = {
  enemy = 1.05,
  player = 1.05,
}
FloatingHud.EXTRA_RISE = 18
FloatingHud.GAP = 5

-- PotatoVoxel projects the staged mons a little differently from Dramatic Shape.
-- These offsets move ONLY our floating nameplates on PotatoVoxel, without touching
-- the camera, Pokemon, or Dramatic Shape placement. Values are logical HUD pixels:
-- positive = DOWN, negative = UP.
FloatingHud.POTATO_ENEMY_Y_OFFSET = 0
FloatingHud.POTATO_PLAYER_Y_OFFSET = 0

-- Battle-message plate. It is anchored between the two projected Pokemon and
-- pushed toward the lower/front part of the battlefield. Unlike the status
-- plates it deliberately keeps a strong authored perspective even when the
-- camera is near its neutral angle.
FloatingHud.MESSAGE = {
  xOffset = 10.0,
  yOffset = 35.0,
  scale = 1.00,

  textX = 13.0,
  line1Y = 11.0,
  line2Y = 35.0,
  textScale = 1.18,
  -- Gen1Recomp remains the page/typewriter/CONT authority. ORAS only reflows
  -- the currently revealed engine rows inside its physically wider plate.
  -- Four regular rows fit at the authored scale; exceptionally long localized
  -- pages may step down to 72% before the provider fails open to native text.
  textRightPadding = 24.0,
  textTop = 7.0,
  textBottom = 7.0,
  textLineGap = 2.0,
  textMinScale = 0.72,

  cursorRight = 9.0,
  cursorBottom = 6.0,

  -- The host camera only traverses part of its theoretical orbit range in normal
  -- play. Amplify only the movement around the authored neutral point so the
  -- message plane actually reaches its intended perspective extremes.
  cameraSignalGain = 2.50,
  -- Much wider response than v0.6.1: the authored bias no longer saturates the
  -- plane through most of the host camera's reachable orbit.
  cameraInfluence = 0.80,
  perspectiveBias = -0.28,
  baseRotationDeg = -7.0,
  cameraRotationDeg = 2.0,
  perspectiveDepth = 0.32,
  perspectiveWidthSqueeze = 0.12,

  -- A gentler second-axis response driven by BattleCam.pitch (0 = the rig's
  -- low authored seat, 1 = the camera raised to its vertical stop). Positive
  -- values below control the amount only; drawMessagePanel intentionally flips
  -- the pitch sign so raising the camera makes the plate face UP toward it rather
  -- than visually lying down into the battlefield.
  pitchSignalGain = 1.00,
  pitchInfluence = 0.35,
  pitchPerspectiveDepth = 0.16,
  pitchHeightSqueeze = 0.05,
}

-- YES / NO battle-choice overlay. It deliberately has no authored plate: the two
-- words float just above the message box and inherit the exact same camera
-- orientation. Selection is communicated by scale rather than a cursor.
FloatingHud.CHOICE = {
  -- A taller plane so YES / NO can sit vertically while retaining the message
  -- plate's exact perspective transform. The plane remains right-anchored to the
  -- message box, so increasing its size grows mainly up/left rather than drifting.
  logicalW = 64.0,
  logicalH = 54.0,
  rightOffset = -2.0, -- positive = farther right
  aboveGap = 2.0,     -- distance above the message plate

  -- Text is positioned by CENTER rather than top-left. That makes the selected
  -- option zoom in place instead of visibly walking down/right as its scale grows.
  centerX = 32.0,
  yesCenterY = 15.0,
  noCenterY = 40.0,

  selectedScale = 2.20,
  idleScale = 1.20,
}

-- Voluntary PKMN selection opens PartyMenu's native SWITCH / STATS / CANCEL
-- submenu. The native PartyMenu remains the input/callback authority; this block
-- only gives that hidden submenu the same floating, scale-to-select language as
-- YES / NO. It is kept separate so tuning it never changes the battle prompt.
FloatingHud.PARTY_CHOICE = {
  logicalW = 96.0,
  logicalH = 78.0,
  rightOffset = -2.0,
  aboveGap = 2.0,

  centerX = 48.0,
  firstCenterY = 14.0,
  rowStep = 25.0,

  selectedScale = 1.65,
  idleScale = 1.05,
}


-- Main four-command plate. Its bottom edge follows the player's projected feet
-- and it sits immediately to the player's left. It uses the exact same camera
-- yaw signal, roll and faux perspective settings as the Pokemon nameplates.
FloatingHud.COMMAND = {
  xGap = 11.0,
  yOffset = 0.0,
  scale = 0.78,

  selectorX = 9.0,
  selectorYOffset = -1.0,
  textX = 20.0,
  firstY = 13.0,
  rowStep = 22.0,

  labels = { "FIGHT", "PKMN", "ITEM", "RUN" },
}

-- Move-selection furniture. The authored plate already contains the large
-- vertical FIGHT word/support, so code only supplies the live move names,
-- selector and one coloured type glyph per row.
FloatingHud.FIGHT = {
  xGap = 18.0,
  yOffset = 22.0,
  -- Moves every dynamic FIGHT element together without moving the authored plate.
  -- Negative = up, positive = down.
  contentYOffset = -10.0,

  -- Extra transparent render room above the authored FIGHT plate. This expands
  -- only the offscreen canvas, so descriptions can grow upward without clipping
  -- while the plate keeps its exact projected position and scale.
  canvasTopPad = 12.0,

  -- The updated authored plate is wider/taller so the list can show PP totals
  -- and a compact move-detail header without shrinking the main battle scene.
  scale = 0.78,
  listScale = 1.07,
  listAnchorX = 0.0,
  listAnchorY = 0.0,

  selectorX = 43.0,
  selectorYOffset = 0.0,
  typeX = 55.0,
  typeYOffset = 0.0,
  typeW = 4.0,
  typeH = 7.0,
  textX = 65.0,
  ppRight = 216.0,
  ppScale = 1.0,
  ppYOffset = -1.0,
  firstY = 49.0,
  rowStep = 17.0,

  -- Short divider from the revised mockup. It deliberately stops before the
  -- numeric stat cluster instead of spanning the complete detail header.
  dividerX = 55.0,
  dividerY = 30.0,
  dividerScale = 1.0,

  -- Descriptions are left-anchored and bottom-anchored: one-line descriptions
  -- sit close to the divider while longer text grows upward, as in the mockup.
  descX = 54.0,
  descBottomY = 13.0,
  descWidth = 170.0,
  descScale = 0.78,
  descLineStep = 9.0,
  descMaxLines = 3,

  -- Accuracy is right-aligned immediately before the % glyph. The category icon
  -- owns the middle slot and power grows rightward from a fixed left margin.
  statsY = 25.0,
  statsScale = 1.0,
  statsAccPercentX = 225.0, -- NUMERO DE % >
  statsAccGap = 1.0, -- ESPACIO DE % >
  statsCategoryX = 158.0, -- CATEGORÍA
  statsCategoryY = 24.0,
  statsCategoryScale = 1.0,
  statsPowerX = 170.0, -- NUMERO DE PODER
}

-- Move-learning replacement picker. It deliberately mirrors FIGHT so the same
-- widened text/PP/details treatment also applies while choosing a move to forget.
-- Drop assets/hud/select_command_plate.png into the mod later and it will be used
-- automatically without changing code or the normal FIGHT plate.
FloatingHud.LEARN = {
  xGap = 18.0,
  yOffset = 22.0,
  -- Moves every dynamic FIGHT element together without moving the authored plate.
  -- Negative = up, positive = down.
  contentYOffset = -5.0,

  -- The updated authored plate is wider/taller so the list can show PP totals
  -- and a compact move-detail header without shrinking the main battle scene.
  scale = 0.78,
  listScale = 1.0,
  listAnchorX = 0.0,
  listAnchorY = 0.0,

  selectorX = 43.0,
  selectorYOffset = 0.0,
  typeX = 55.0,
  typeYOffset = 0.0,
  typeW = 4.0,
  typeH = 7.0,
  textX = 65.0,
  ppRight = 216.0,
  ppScale = 1.0,
  ppYOffset = -1.0,
  firstY = 49.0,
  rowStep = 17.0,

  -- Short divider from the revised mockup. It deliberately stops before the
  -- numeric stat cluster instead of spanning the complete detail header.
  dividerX = 55.0,
  dividerY = 30.0,
  dividerScale = 1.0,

  -- Descriptions are left-anchored and bottom-anchored: one-line descriptions
  -- sit close to the divider while longer text grows upward, as in the mockup.
  descX = 54.0,
  descBottomY = 13.0,
  descWidth = 165.0,
  descScale = 0.78,
  descLineStep = 9.0,
  descMaxLines = 3,

  -- Accuracy is right-aligned immediately before the % glyph. The category icon
  -- owns the middle slot and power grows rightward from a fixed left margin.
  statsY = 25.0,
  statsScale = 1.0,
  statsAccPercentX = 207.0, -- NUMERO DE % >
  statsAccGap = 1.0, -- ESPACIO DE % >
  statsCategoryX = 136.0, -- CATEGORÍA
  statsCategoryY = 24.0,
  statsCategoryScale = 1.0,
  statsPowerX = 148.0, -- NUMERO DE PODER
}

-- Battle-party overlay. The plate is authored at x8, while optional species icon
-- sheets are native 16x32 two-frame menu art. Drop them into pkmn_icons using the
-- engine species id (e.g. GYARADOS.png). Missing custom art falls back to the
-- engine PartyMenu icon renderer, so this screen is testable before the full set
-- is copied in.
FloatingHud.PKMN = {
  xGap = 14.0,
  yOffset = -10.0,
  scale = 0.80,

  selectorX = 55.0,
  selectorYOffset = -1.0,
  iconX = 63.0,
  textX = 82.0,
  hpX = 82.0,
  hpW = 72.0,
  firstY = 10.0,
  rowStep = 17.0,

  -- One icon frame every N battle frames. 18 = ~0.3 s at 60 fps, intentionally
  -- much calmer than the reference mod's fast alternating menu animation.
  iconFrameTicks = 18,
}

-- Complete Gen-I type palette for the ORAS move cards.
FloatingHud.MOVE_TYPE_COLORS = {
  FIGHTING = { 0xD7 / 255, 0x00 / 255, 0x96 / 255, 1 },
  FLYING   = { 0x79 / 255, 0x9B / 255, 0xFF / 255, 1 },
  NORMAL   = { 0xB6 / 255, 0xC0 / 255, 0xC9 / 255, 1 },
  ELECTRIC = { 0xEA / 255, 0xCD / 255, 0x43 / 255, 1 },
  POISON   = { 0x85 / 255, 0x64 / 255, 0xCD / 255, 1 },
  FIRE     = { 0xFF / 255, 0x42 / 255, 0x00 / 255, 1 },
  BUG      = { 0x96 / 255, 0xAB / 255, 0x32 / 255, 1 },
  DRAGON   = { 0x25 / 255, 0x59 / 255, 0xA4 / 255, 1 },
  GHOST    = { 0x68 / 255, 0x61 / 255, 0xA7 / 255, 1 },
  GRASS    = { 0x3E / 255, 0xCA / 255, 0x21 / 255, 1 },
  ROCK     = { 0xC7 / 255, 0xAB / 255, 0x95 / 255, 1 },
  GROUND   = { 0xBD / 255, 0x74 / 255, 0x3F / 255, 1 },
  ICE      = { 0xA8 / 255, 0xDB / 255, 0xCA / 255, 1 },
  WATER    = { 0x44 / 255, 0xBA / 255, 0xFF / 255, 1 },
  PSYCHIC  = { 0xFF / 255, 0x7B / 255, 0xCA / 255, 1 },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function textWidth(s)
  s = tostring(s or "")
  local ok, w = pcall(Font.width, s)
  return (ok and tonumber(w)) or (#s * 8)
end

local function splitBattleMessageText(text, revealedEnd)
  text = tostring(text or "")
  local out, raw = {}, {}
  local pos = 1
  while true do
    local a, b = text:find("[\n\v]", pos)
    local line = a and text:sub(pos, a - 1) or text:sub(pos)
    raw[#raw + 1] = line
    local ranges = {}
    -- ROM controls are not ink, even when another fragment follows them.
    -- Keep their original byte positions so typewriter counts cannot reveal
    -- later text early, or expose a partially revealed control token.
    for _, pattern in ipairs({ "{PROMPT}", "<PROMPT>", "%[PROMPT%]",
        "%s+PROMPT%s*$", "^PROMPT%s*$" }) do
      local cursor = 1
      while true do
        local first, last = line:find(pattern, cursor)
        if not first then break end
        ranges[#ranges + 1] = { first, last }
        cursor = last + 1
      end
    end
    table.sort(ranges, function(left, right) return left[1] < right[1] end)
    local pieces, cursor = {}, 1
    local limit = math.min(#line, revealedEnd or #line)
    for _, range in ipairs(ranges) do
      if cursor <= limit and range[1] > cursor then
        pieces[#pieces + 1] = line:sub(cursor, math.min(limit, range[1] - 1))
      end
      cursor = math.max(cursor, range[2] + 1)
    end
    if cursor <= limit then pieces[#pieces + 1] = line:sub(cursor, limit) end
    local clean = table.concat(pieces)
    local final = ranges[#ranges]
    if final and line:sub(final[2] + 1):match("^%s*$") then
      clean = clean:gsub("%s+$", "")
    end
    out[#out + 1] = clean
    if not a then break end
    pos = b + 1
  end
  return out, raw
end

local function revealedGlyphText(source, count)
  source = tostring(source or "")
  count = math.max(0, tonumber(count) or 0)
  if count == 0 then return "" end
  local ok, spans = pcall(Font.split, source)
  local last = ok and type(spans) == "table" and spans[count] or nil
  local limit = ok and type(spans) == "table"
    and (count >= #spans and #source or (last and last.to or 0)) or count
  return splitBattleMessageText(source, limit)[1] or ""
end

-- Gen1Recomp already owns the typewriter/CONT state in battle.shown. Reuse that
-- rolling two-line window instead of inventing a second message state machine.
local function visibleBattleMessageLines(battle)
  if not battle then return {} end

  local shown = battle.shown
  local source = battle.current and battle.current.text or nil
  if battle.current
      and battle._floatingBattleMessageItem ~= battle.current then
    battle._floatingBattleMessageItem = battle.current
    battle._floatingBattleMessageLines = nil
    battle._floatingBattleMessageFullLines = nil
  end
  if shown and source and #shown > 0 then
    local _, rawLines = splitBattleMessageText(source)
    local lineIndex = math.max(1, tonumber(battle.lineIndex) or 1)
    local firstSource = math.max(1, lineIndex - #shown + 1)
    local complete = battle.msgWaiting or battle.msgPrompt or battle.msgHold
                     or (battle.current and battle.current.done)
    local out, fullOut = {}, {}

    for visibleIndex, codes in ipairs(shown) do
      local sourceIndex = firstSource + visibleIndex - 1
      local nativeLine = battle.lines and battle.lines[sourceIndex]
      local rawLine = type(nativeLine) == "table" and nativeLine.text
      if type(rawLine) ~= "string" then rawLine = rawLines[sourceIndex] or "" end
      -- Newer engines remove ROM controls before counting their glyphs.
      -- Prefer that exact prepared line; older engines retain raw glyphs.
      local full = splitBattleMessageText(rawLine)[1] or ""
      -- splitBattleMessageText has already removed page control markers,
      -- before both glyph slicing and the complete-page hold cache.
      fullOut[#fullOut + 1] = full
      if complete then
        out[#out + 1] = full
      else
        out[#out + 1] = revealedGlyphText(rawLine, #(codes or {}))
      end
    end

    -- Gen1Recomp clears `current` in the same update that starts msgHold.
    -- There is therefore no guaranteed draw frame where both the authoritative
    -- source and the completed hold flag exist together. Keep the complete
    -- source page separately from the typewriter receipt, so the animation
    -- hold cannot freeze the last partially revealed glyph (for example
    -- "BLIZZAR" instead of "BLIZZARD!").
    battle._floatingBattleMessageFullLines = fullOut
    battle._floatingBattleMessageLines = out
    return out
  end

  -- Animations can keep the previous page visible after current is cleared.
  if battle.msgHold and battle._floatingBattleMessageFullLines then
    battle._floatingBattleMessageLines =
      battle._floatingBattleMessageFullLines
  end
  return battle._floatingBattleMessageLines or {}
end

local function visibleTextBoxMessageLines(box)
  if not box then return {} end
  local full = nil
  if type(box.visibleText) == "function" then
    local ok, value = pcall(box.visibleText, box)
    if ok and type(value) == "table" then full = value end
  end
  if not full then return {} end

  local shown = type(box.shown) == "table" and box.shown or {}
  local out = {}
  for i = 1, math.min(2, #full) do
    local codes = shown[i]
    local lines, rawLines = splitBattleMessageText(full[i] or "")
    local line = lines[1] or ""
    if type(codes) == "table" then
      out[#out + 1] = revealedGlyphText(rawLines[1] or "", #codes)
    else
      out[#out + 1] = line
    end
  end
  return out
end

-- Return the first physical pixel row occupied by START/SELECT. TouchControls
-- owns orientation-specific positions and safe-area clamping, so querying its
-- live layout also keeps custom player layouts authoritative. The conversion
-- matters on Retina/mobile hosts where the staged battle canvas and LÖVE's
-- logical window do not share dimensions.
function FloatingHud.touchStartSelectTop(shot)
  local controls = TouchControls
    or (type(Bundle) == "table" and Bundle.TouchControls)
  if not (shot and controls and type(controls.layout) == "function")
      or not (PLATFORM_OS == "iOS" or PLATFORM_OS == "Android") then
    return nil
  end
  if type(controls.visible) == "function" then
    local okVisible, visible = pcall(controls.visible, controls)
    if okVisible and visible ~= true then return nil end
  end
  local okLayout, layout = pcall(controls.layout, controls)
  if not (okLayout and type(layout) == "table") then return nil end
  local windowW, windowH = shot.pw, shot.ph
  if g and type(g.getDimensions) == "function" then
    local okDimensions, w, h = pcall(g.getDimensions)
    if okDimensions and tonumber(w) and tonumber(h) and w > 0 and h > 0 then
      windowW, windowH = w, h
    end
  end
  local sy = (tonumber(shot.ph) or windowH) / windowH
  local top = nil
  for _, name in ipairs({ "select", "start" }) do
    local zone = layout[name]
    if type(zone) == "table" and tonumber(zone.cy) and tonumber(zone.w) then
      -- draw() uses a 0.58w backing circle; the label extends below it and
      -- therefore cannot reduce this top edge.
      local candidate = (zone.cy - zone.w * 0.58) * sy
      top = top and math.min(top, candidate) or candidate
    end
  end
  return top
end

local function battleMessageActive(battle)
  if not (battle and battle.phase == "messages") then return false end
  return battle.current ~= nil
      or battle.msgHold
      or battle.msgWaiting
      or battle.msgPrompt
      or #(battle.shown or {}) > 0
end

local function moveDefinition(battle, move)
  if not (battle and battle.data and battle.data.moves and move) then return nil end
  local id = type(move) == "table" and (move.id or move.moveId or move.move) or move
  return id and battle.data.moves[id] or nil
end

local function moveDisplayName(battle, move)
  local def = moveDefinition(battle, move)
  local name = def and def.name
  if not name and type(move) == "table" then
    name = move.name or move.id or move.moveId or move.move
  end
  return tostring(name or "---"):upper()
end

local function moveTypeKey(battle, move)
  local def = moveDefinition(battle, move)
  local t = def and (def.type or def.moveType or def.damageType) or nil
  if type(t) == "table" then t = t.name or t.id end
  local key = tostring(t or "NORMAL"):upper()
  key = key:gsub("[%s_%-]+TYPE$", ""):gsub("[%s_%-]+", "")
  if key == "FIGHT" then key = "FIGHTING" end
  if key == "LIGHTNING" then key = "ELECTRIC" end
  if key == "LEAF" then key = "GRASS" end
  return key
end

local function moveTypeColor(battle, move)
  local key = moveTypeKey(battle, move)
  return FloatingHud.MOVE_TYPE_COLORS[key]
      or FloatingHud.MOVE_TYPE_COLORS.NORMAL
end

local function shownHP(battler)
  if not (battler and battler.mon) then return 0, 1 end
  local hp = battler.shownHP
  if hp == nil then hp = battler.mon.hp or 0 end
  local actual = battler.mon.hp or 0
  if hp > actual then hp = math.ceil(hp) else hp = math.floor(hp) end
  local maxHP = math.max(1, battler.mon.stats and battler.mon.stats.hp or 1)
  return clamp(hp, 0, maxHP), maxHP
end

local function expRatio(battle, battler)
  local mon = battler and battler.mon
  if not (battle and mon) then return 0 end
  local def = battle.data and battle.data.pokemon and battle.data.pokemon[mon.species]
  if not def then return 0 end

  local cap = (battle.data.constants and battle.data.constants.levelCap) or 100
  local level = mon.level or 1
  if level >= cap then return 1 end

  local rates = battle.data.growth_rates
  local from = Growth.expForLevel(def.growthRate, level, rates)
  local to = Growth.expForLevel(def.growthRate, level + 1, rates)
  if to <= from then return 0 end
  return clamp(((mon.exp or from) - from) / (to - from), 0, 1)
end

local function uiScale(shot)
  local s = tonumber(shot and shot.scale) or 1
  local base = clamp(math.floor(s * 0.5 + 0.5), 1, FloatingHud.MAX_SCALE)
  return base * floatingHudScale()
end

local function distanceScale(shot, side)
  local span = tonumber(shot and shot[side .. "Span"]) or FloatingHud.REFERENCE_SPAN
  local ratio = span / FloatingHud.REFERENCE_SPAN
  return clamp(ratio, FloatingHud.DISTANCE_SCALE_MIN,
                      FloatingHud.DISTANCE_SCALE_MAX)
end

-- Camera-only orientation signal. Unlike projected Pokemon displacement, this
-- does NOT change when the player merely zooms the lens. It follows the same
-- yaw Dramatic Shape uses for the battle camera: manual orbit plus its tiny
-- automatic drift. 0 is the authored camera angle; magnitude grows as the
-- camera swings toward side-on.
local function cameraYawSignal()
  local arena = OverworldBattle.arena and OverworldBattle.arena() or nil
  local range = 1

  if arena and BattleCam and BattleCam.orbitRange then
    local ok, r = pcall(BattleCam.orbitRange, arena)
    if ok and tonumber(r) and r > 1e-6 then
      range = r
    end
  end

  local orbit = clamp(tonumber(BattleCam and BattleCam.orbit) or 0, 0, 1)
  local yaw = -orbit * range

  -- Dramatic Shape's own slow +/-2 degree camera drift.
  if BattleCam and not BattleCam.still
     and tonumber(BattleCam.PAN_PERIOD)
     and BattleCam.PAN_PERIOD > 0 then

    local t = tonumber(BattleCam.t) or 0
    local drift = (tonumber(BattleCam.PAN_YAW) or 0)
                  * math.sin(2 * math.pi * t / BattleCam.PAN_PERIOD)

    yaw = yaw + drift
  end

  local signal = yaw / math.max(range, 1e-6)
  signal = signal + FloatingHud.CAMERA_CENTER_OFFSET

  return clamp(signal, -1, 1)
end

-- Vertical camera steering is already normalized by both voxel hosts: 0 is the
-- authored low seat and 1 is the raised/top stop. Unlike yaw there is no
-- automatic pitch drift, so this signal is intentionally simple and independent
-- from zoom.
local function cameraPitchSignal()
  return clamp(tonumber(BattleCam and BattleCam.pitch) or 0, 0, 1)
end

local function hudRotation()
  return math.rad((FloatingHud.MAX_ROTATION_DEG or 0) * cameraYawSignal())
end

local function wildBattle(battle)
  return battle and (battle.kind == "wild" or battle.kind == "safari")
end

local function hudGenderEnabled()
  if BattleHudExtras and type(BattleHudExtras.genderEnabled) == "function" then
    local ok, enabled = pcall(BattleHudExtras.genderEnabled)
    if ok then return enabled == true end
  end
  return true
end

local function hudExpChoice(battle)
  if BattleHudExtras and type(BattleHudExtras.expChoice) == "function" then
    local ok, value = pcall(BattleHudExtras.expChoice,
      battle and battle.game or nil)
    if ok and (value == "off" or value == "black" or value == "blue") then
      return value
    end
  end
  return "blue"
end

local function hudCaughtChoice(battle)
  if BattleHudExtras and type(BattleHudExtras.caughtChoice) == "function" then
    local ok, value = pcall(BattleHudExtras.caughtChoice,
      battle and battle.game or nil)
    if ok and (value == "off" or value == "grey" or value == "red") then
      return value
    end
  end
  return "red"
end

local function showWildDVs(battle, side, battler)
  return side == "enemy"
     and wildBattle(battle)
     and battler and battler.mon and battler.mon.dvs
     -- The in-game Ascendant page writes this option into the live save
     -- bucket. Reading mod.options here kept the boot-time value until the
     -- next restart, which made the visible toggle appear to do nothing.
     and FloatingHud.wildDVsEnabled()
end

local function caughtSpecies(battle, side, battler)
  if side ~= "enemy" or not wildBattle(battle) or not (battler and battler.mon) then
    return false
  end
  if hudCaughtChoice(battle) == "off" then return false end
  local dex = battle.game and battle.game.save and battle.game.save.pokedex
  return (dex and dex.owned and dex.owned[battler.mon.species]) and true or false
end

local function shinyPokemon(battle, battler)
  local mon = battler and battler.mon
  if not mon or not kascOptionEnabled("shiny_effects") then return false end
  local kasc = kascExports()
  local service = kasc and kasc.shinySystem or nil
  if type(service) == "table" and type(service.isShiny) == "function" then
    local ok, shiny = pcall(service.isShiny, mon)
    if ok then return shiny == true end
  end
  return mon.shiny == true
end

function FloatingHud.statusMarkerKinds(battle, side, battler)
  local kinds = {}
  if caughtSpecies(battle, side, battler) then
    kinds[#kinds + 1] = "caught"
  end
  if shinyPokemon(battle, battler) then kinds[#kinds + 1] = "shiny" end
  local mon = battler and battler.mon
  if mon and mon.eventDistribution and kascOptionEnabled("event_rosette") then
    kinds[#kinds + 1] = "event"
  end
  return kinds
end

local function hpDV(dvs)
  if not dvs then return nil end
  local atk, def, spd, spc = dvs.attack, dvs.defense, dvs.speed, dvs.special
  if atk == nil or def == nil or spd == nil or spc == nil then return nil end
  return (atk % 2) * 8 + (def % 2) * 4 + (spd % 2) * 2 + (spc % 2)
end

local function dvText(mon)
  local dvs = mon and mon.dvs
  local hp = hpDV(dvs)
  if hp == nil then return nil end
  return string.format("%02d/%02d/%02d/%02d/%02d",
                       hp, dvs.attack, dvs.defense, dvs.speed, dvs.special)
end

local function fitText(text, maxWidth)
  text = tostring(text or "")
  if textWidth(text) <= maxWidth then return text end
  local suffix = "."
  while #text > 0 and textWidth(text .. suffix) > maxWidth do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local function genderSymbol(battle, mon)
  if not hudGenderEnabled() then return nil end
  if BattleHudExtras
      and type(BattleHudExtras.presentationGenderSymbol) == "function" then
    local ok, symbol = pcall(BattleHudExtras.presentationGenderSymbol,
      mon, battle)
    if ok and (symbol == "♂" or symbol == "♀") then return symbol end
  end
  local kasc = kascExports()
  local gender = kasc and kasc.pokemonGender
  if gender and type(gender.symbol) == "function" then
    local ok, symbol = pcall(gender.symbol, mon, battle and battle.game or battle)
    if ok and (symbol == "♂" or symbol == "♀") then return symbol end
  end
  local raw = tostring(mon and (mon.gender or mon.sex) or ""):lower()
  if raw == "male" or raw == "m" then return "♂" end
  if raw == "female" or raw == "f" then return "♀" end
  return nil
end

local function megaProfileFor(battle, battler, side)
  -- VASC supplies presentation only. Mega appears exclusively when the
  -- optional KASC public service confirms this exact active Pokemon and the
  -- activation capability; VASC-only play therefore remains fail-closed.
  if hudStyle() ~= "oras" or side ~= "player"
      or not (battle and battler and battler.mon) then return nil end
  if battle.kind == "link" or battle.ascendantNoMega == true
      or battle._ascMegaPlayerUsed or battler.mon.isEgg
      or battler.mon._ascMegaForm or battler._ascMegaForm then return nil end
  local kasc = kascExports()
  local mega = kasc and kasc.megaEvolution
  if not mega then return nil end
  if type(mega.canActivate) == "function" then
    local ok, ready, _, profile = pcall(
      mega.canActivate, battle, battler, side)
    return ok and ready == true and type(profile) == "table" and profile or nil
  end
  if not (type(mega.profileFor) == "function"
      and type(mega.available) == "function") then return nil end
  local availableOk, available = pcall(mega.available, battle.game)
  if not availableOk or available ~= true then return nil end
  local ok, profile = pcall(mega.profileFor, battler.mon, false)
  if not ok or type(profile) ~= "table" then return nil end
  -- Mirror KASC activate(): ordinary Megas and Rayquaza require the ring;
  -- Primal Reversion profiles explicitly set requiresRing=false, while the
  -- secret Basalt form is exempt in KASC itself. Fail closed if a required
  -- readiness API is absent, so every visible control is genuinely usable.
  if profile.requiresRing ~= false and not profile.secret then
    if type(mega.hasRing) ~= "function" then return nil end
    local ringOk, hasRing = pcall(mega.hasRing)
    if not ringOk or hasRing ~= true then return nil end
  end
  return profile
end

do
local MEGA_FX_DURATION = 5.04
local MEGA_FX_FLASH_AT = 2.62
local MEGA_FX_FLASH_END = 2.82
local MEGA_FX_SPHERE_AT = 0.82
local MEGA_FX_SYMBOL_END = 1.00
local megaSoundSource = nil
local megaSoundUnavailable = false
local megaFxImage = nil
local megaFxGeometry = nil

local function smooth01(value)
  value = clamp(tonumber(value) or 0, 0, 1)
  return value * value * (3 - 2 * value)
end

function FloatingHud.clearMegaArmed(battle)
  if not battle then return end
  battle._ascendantBattleHudMegaArmed = nil
  battle._ascendantBattleHudMegaArmedMon = nil
  battle._ascendantBattleHudMegaArmedProfile = nil
end

-- A battle object can survive long enough for the next encounter on some
-- engine/compatibility paths.  Mega form observation is deliberately stored
-- on that object, so it must be retired with the HUD provider as well: an old
-- observed form must never turn the next real transformation into an
-- unchanged-form baseline and suppress its presentation.
function FloatingHud.clearMegaPresentation(battle)
  if not battle then return end
  FloatingHud.clearMegaArmed(battle)
  battle._ascendantBattleHudMegaObservedForms = nil
  battle._ascendantBattleHudMegaTransformation = nil
  battle._ascendantBattleHudMegaFocus = nil
  battle._ascendantBattleHudMoveMegaFocus = nil
  battle._ascendantBattleHudMegaChoice = nil
end

function FloatingHud.megaArmed(battle)
  if not (battle and battle._ascendantBattleHudMegaArmed == true) then
    return false
  end
  local mon = battle.player and battle.player.mon or nil
  if not mon or battle._ascendantBattleHudMegaArmedMon ~= mon
      or not megaProfileFor(battle, battle.player, "player") then
    FloatingHud.clearMegaArmed(battle)
    return false
  end
  return true
end

local function megaFormChoices(battle)
  local battler = battle and battle.player or nil
  local mon = battler and battler.mon or nil
  if not mon then return {} end
  local kasc = kascExports()
  local mega = kasc and kasc.megaEvolution
  if mega and type(mega.formChoicesFor) == "function" then
    local ok, choices = pcall(mega.formChoicesFor, mon, false)
    if ok and type(choices) == "table" then
      local out = {}
      for _, profile in ipairs(choices) do
        if type(profile) == "table" and profile.id then
          out[#out + 1] = profile
        end
      end
      if #out > 0 then return out end
    end
  end
  local profile = megaProfileFor(battle, battler, "player")
  return profile and { profile } or {}
end

function FloatingHud.armMegaProfile(battle, profileId)
  local profile = nil
  for _, candidate in ipairs(megaFormChoices(battle)) do
    if profileId == nil or candidate.id == profileId then
      profile = candidate
      break
    end
  end
  if not (battle and battle.player and battle.player.mon and profile) then
    FloatingHud.clearMegaArmed(battle)
    return false, "unavailable"
  end
  battle._ascendantBattleHudMegaArmed = true
  battle._ascendantBattleHudMegaArmedMon = battle.player.mon
  battle._ascendantBattleHudMegaArmedProfile = profile.id
  battle.moveSwapIndex = nil
  Diagnostics.write("battle-mega-form-selected", {
    species=battle.player.mon.species or "unknown", form=profile.id,
  })
  return true, "armed"
end

function FloatingHud.openMegaFormChoice(battle)
  if not (battle and battle.player and battle.player.mon) then
    return false, "unavailable"
  end
  if battle._ascendantBattleHudMegaChoice then return true, "choosing" end
  local choices = megaFormChoices(battle)
  if #choices <= 1 then
    return FloatingHud.armMegaProfile(battle,
      choices[1] and choices[1].id or nil)
  end
  if not (battle.game and battle.game.stack
      and type(battle.game.stack.push) == "function") then
    return false, "stack_unavailable"
  end

  local rows = {}
  for _, profile in ipairs(choices) do
    rows[#rows + 1] = {
      label = profile.label or profile.id:gsub("_", " "),
      right = profile.id:match("_([XY])$") or nil,
      value = profile.id,
      species = profile.species,
    }
  end
  local menu
  menu = ListMenu.new(battle.game,
    hudLanguage() == "de" and "MEGA-FORM WÄHLEN" or "CHOOSE MEGA FORM",
    rows, {
      wrap = true,
      onCancel = function()
        battle._ascendantBattleHudMegaChoice = nil
      end,
      onChoose = function(item, current)
        if current and type(current.close) == "function" then current:close() end
        battle._ascendantBattleHudMegaChoice = nil
        local kasc = kascExports()
        local mega = kasc and kasc.megaEvolution
        if mega and type(mega.setPreferredForm) == "function" then
          pcall(mega.setPreferredForm,
            item and item.species or (battle.player and battle.player.mon
              and battle.player.mon.species or nil),
            item and item.value)
        end
        FloatingHud.armMegaProfile(battle, item and item.value)
      end,
    })
  battle._ascendantBattleHudMegaChoice = menu
  battle.game.stack:push(menu)
  return true, "choosing"
end

-- Arming is intentionally HUD-local. KASC's exported activate() consumes the
-- once-per-battle transformation immediately, so it is called only after a
-- usable attack has been confirmed. Pressing MEGA again simply disarms it and
-- never leaves the move picker.
function FloatingHud.toggleMegaArmed(battle)
  if not megaProfileFor(battle, battle and battle.player, "player") then
    FloatingHud.clearMegaArmed(battle)
    return false, "unavailable"
  end
  if FloatingHud.megaArmed(battle) then
    FloatingHud.clearMegaArmed(battle)
    return false, "disarmed"
  end
  -- A single available form arms immediately. Species owning several form
  -- stones open an in-battle picker first; the chosen profile is then pinned
  -- through attack confirmation and companion activation.
  return FloatingHud.openMegaFormChoice(battle)
end

local function megaSfxVolume(battle)
  local options = battle and battle.game and battle.game.save
              and battle.game.save.options or nil
  local level = options and tonumber(options.sfxVol) or 7
  return clamp(level / 7, 0, 1)
end

local function playMegaTransformationSound(battle)
  if megaSoundUnavailable or not (love and love.audio
      and type(love.audio.newSource) == "function") then return false end
  if not megaSoundSource then
    local ok, source = pcall(
      love.audio.newSource, mod.assets:path(MEGA_TRANSFORMATION_SOUND), "static")
    if not (ok and source) then
      megaSoundUnavailable = true
      mod.log:warn("MEGA transformation sound unavailable: %s", tostring(source))
      return false
    end
    megaSoundSource = source
  end
  pcall(megaSoundSource.stop, megaSoundSource)
  pcall(megaSoundSource.setVolume, megaSoundSource, megaSfxVolume(battle))
  local ok = pcall(megaSoundSource.play, megaSoundSource)
  return ok
end

local function currentMegaOwnerForm(battle, side)
  local battler = battle and battle[side] or nil
  local mon = battler and battler.mon or nil
  local form = battler and battler._ascMegaForm or nil
  if form == nil and mon then form = mon._ascMegaForm end
  return battler, mon, form
end

local function megaTransformationOwnerCurrent(battle, fx)
  if not (battle and type(fx) == "table"
      and (fx.side == "player" or fx.side == "enemy")) then
    return false
  end
  local battler = battle[fx.side]
  return battler ~= nil and battler.mon ~= nil
     and fx.battler == battler and fx.mon == battler.mon
end

local function retireMegaTransformationIfOwnerChanged(battle)
  local fx = battle and battle._ascendantBattleHudMegaTransformation
  if not fx or megaTransformationOwnerCurrent(battle, fx) then return false end
  battle._ascendantBattleHudMegaTransformation = nil
  return true
end

function FloatingHud.startMegaTransformation(battle, side)
  if not battle then return false end
  side = side == "enemy" and "enemy" or "player"
  local battler, mon, form = currentMegaOwnerForm(battle, side)
  if not (battler and mon) then return false end
  local observed = battle._ascendantBattleHudMegaObservedForms
  if type(observed) == "table" then
    observed[side] = { battler=battler, mon=mon, form=form }
  end
  battle._ascendantBattleHudMegaTransformation = {
    side = side,
    battler = battler,
    mon = mon,
    form = form,
    elapsed = 0,
    duration = MEGA_FX_DURATION,
  }
  Diagnostics.write("battle-mega-presentation-start", {
    side=side, form=form or "unknown", duration=MEGA_FX_DURATION,
  })
  playMegaTransformationSound(battle)
  return true
end

-- KASC retains two public activation paths which do not originate in VASC's
-- move picker: classic SELECT and automatic opponent Mega. Observe the actual
-- same-battler form edge so both receive the VASC presentation. The first
-- seen state and a newly switched-in owner are baselines, never animations.
function FloatingHud.observeMegaFormTransitions(battle)
  if not battle then return false end
  local observed = battle._ascendantBattleHudMegaObservedForms
  if type(observed) ~= "table" then
    observed = {}
    battle._ascendantBattleHudMegaObservedForms = observed
    for _, side in ipairs({ "player", "enemy" }) do
      local battler, mon, form = currentMegaOwnerForm(battle, side)
      observed[side] = { battler=battler, mon=mon, form=form }
    end
    return false
  end

  local started = false
  for _, side in ipairs({ "player", "enemy" }) do
    local battler, mon, form = currentMegaOwnerForm(battle, side)
    local old = observed[side]
    local sameOwner = type(old) == "table"
      and old.battler == battler and old.mon == mon
    local formChanged = sameOwner and old.form ~= form
    if not sameOwner then
      local active = battle._ascendantBattleHudMegaTransformation
      if active and active.side == side then
        retireMegaTransformationIfOwnerChanged(battle)
      end
      observed[side] = { battler=battler, mon=mon, form=form }
    elseif formChanged and (form == nil or form == false or form == "") then
      observed[side] = { battler=battler, mon=mon, form=form }
    elseif formChanged then
      local active = battle._ascendantBattleHudMegaTransformation
      if not active or active.side == side then
        observed[side] = { battler=battler, mon=mon, form=form }
        if not active then
          FloatingHud.startMegaTransformation(battle, side)
          started = true
        end
      end
    end
  end
  return started
end

function FloatingHud.advanceMegaTransformation(battle, dt)
  local fx = battle and battle._ascendantBattleHudMegaTransformation
  if not fx then return false end
  if retireMegaTransformationIfOwnerChanged(battle) then return false end
  local step = tonumber(dt)
  if not step or step <= 0 or step > 0.25 then step = 1 / 60 end
  -- Fast-forward runs this fixed-step battle hook multiple times per rendered
  -- frame. The effect is presentation, so keep its authored real-time duration
  -- instead of accelerating it with battle logic.
  local speed = 1
  local game = battle and battle.game
  if game and type(game.logicSpeed) == "function" then
    local ok, value = pcall(game.logicSpeed, game)
    if ok then speed = tonumber(value) or 1 end
  end
  step = step / math.max(1, speed)
  fx.elapsed = (tonumber(fx.elapsed) or 0) + step
  if fx.elapsed >= (tonumber(fx.duration) or MEGA_FX_DURATION) then
    Diagnostics.write("battle-mega-presentation-complete", {
      side=fx.side or "unknown", form=fx.form or "unknown",
      elapsed=fx.elapsed,
    })
    battle._ascendantBattleHudMegaTransformation = nil
    return false
  end
  return true
end

local function ensureMegaFxGeometry()
  local image = assetImage(MEGA_TRANSFORMATION_ASSET)
  if not image then return nil end
  if megaFxImage == image and megaFxGeometry then return megaFxGeometry end

  local iw, ih = image:getDimensions()
  local cx, cy = iw * 0.576, ih * 0.495
  local cropX = math.floor(iw * 0.205)
  local mainQuad = g.newQuad(cropX, 0, iw - cropX, ih, iw, ih)
  local symbolY = math.floor(ih * 0.14)
  -- Stop the standalone sigil exactly where the sphere crop begins. The
  -- approved atlas elements touch, so a percentage-based width otherwise
  -- pulls a visible strip of the sphere into the screen-centred sigil.
  local symbolW = cropX
  local symbolH = math.floor(ih * 0.56)
  local symbolQuad = g.newQuad(0, symbolY, symbolW, symbolH, iw, ih)
  megaFxImage = image
  megaFxGeometry = {
    image = image,
    iw = iw, ih = ih,
    cx = cx, cy = cy,
    cropX = cropX,
    mainQuad = mainQuad,
    symbolQuad = symbolQuad,
    symbolW = symbolW,
    symbolH = symbolH,
    symbolY = symbolY,
  }
  return megaFxGeometry
end

-- Paint the effect in shot.canvas after the host has drawn the battler, but
-- before our status cards and controls. It therefore follows the projected
-- Pokémon on every viewport while never covering menu text or touch targets.
function FloatingHud.drawMegaTransformation(battle, shot)
  local fx = battle and battle._ascendantBattleHudMegaTransformation
  if fx and retireMegaTransformationIfOwnerChanged(battle) then return false end
  local geometry = fx and shot and ensureMegaFxGeometry() or nil
  local side = fx and fx.side or "player"
  local pos = shot and shot[side] or nil
  if not (geometry and pos) then return false end

  local elapsed = tonumber(fx.elapsed) or 0
  local s = tonumber(shot.scale) or 1
  local span = tonumber(shot[side .. "Span"]) or FloatingHud.REFERENCE_SPAN
  local footX = (tonumber(shot.lx) or 0) + (tonumber(pos[1]) or 0) * s
  local footY = (tonumber(shot.ly) or 0) + (tonumber(pos[2]) or 0) * s
  local viewportMin = math.max(1, math.min(tonumber(shot.pw) or 320,
                                               tonumber(shot.ph) or 240))
  local diameter = clamp(span * s * 2.35, viewportMin * 0.22,
                         viewportMin * 0.48)
  local centerX = footX
  local centerY = footY - math.max(span * s * 0.76, diameter * 0.34)

  -- Size and seat the shell from the exact alpha hull of the same rendered
  -- battler. `sideSpan` describes the arena slot, not the species/form: using
  -- it made a small Raichu and a large Charizard receive almost the same egg.
  -- Keep the old mark-based formula only for the first transition frame where
  -- the renderer has not published an actor receipt yet.
  local visual = FloatingHud.exactActorVisual(battle, shot, side)
  local hull = visual and visual.hull or nil
  if type(hull) == "table" and tonumber(hull[1]) and tonumber(hull[2])
      and tonumber(hull[3]) and tonumber(hull[4])
      and hull[3] > 0 and hull[4] > 0 then
    local actorSpan = math.max(hull[3], hull[4])
    diameter = clamp(actorSpan * 1.18, viewportMin * 0.12,
                     viewportMin * 0.58)
    centerX = hull[1] + hull[3] * 0.5
    centerY = hull[2] + hull[4] * 0.5
  end
  local baseScale = diameter / (geometry.iw * 0.61)
  local screenCenterX = (tonumber(shot.pw) or 320) * 0.5
  local screenCenterY = (tonumber(shot.ph) or 240) * 0.5

  g.push("all")
  g.setShader()
  g.setBlendMode("alpha")

  -- KASC has already applied the form at this point. Once phase two begins,
  -- cover that battler with the supplied opaque iridescent sphere; no
  -- generated ellipse, outline, ring or shard may alter the approved art.
  -- The uniform, unrotated draw is also what keeps the source circle round.
  if elapsed >= MEGA_FX_SPHERE_AT and elapsed < MEGA_FX_FLASH_AT then
    g.setColor(1, 1, 1, 1)
    g.draw(geometry.image, geometry.mainQuad, centerX, centerY,
           0, baseScale, baseScale,
           geometry.cx - geometry.cropX, geometry.cy)
  end

  -- Phase one: a fully opaque world matte prevents the already-active Mega
  -- form from leaking through any of the independent 2D, arena or voxel
  -- renderers. Status cards and controls are drawn after this scene layer, so
  -- HP and input feedback remain live. As the real sphere arrives, the matte
  -- crossfades away beneath the standalone screen-centred sigil.
  if elapsed < MEGA_FX_SYMBOL_END then
    local p = smooth01(elapsed / MEGA_FX_SYMBOL_END)
    local matteAlpha = 1
    if elapsed >= MEGA_FX_SPHERE_AT then
      matteAlpha = 1 - smooth01((elapsed - MEGA_FX_SPHERE_AT)
        / (MEGA_FX_SYMBOL_END - MEGA_FX_SPHERE_AT))
    end
    g.setColor(0.005, 0.012, 0.026, clamp(matteAlpha, 0, 1))
    g.rectangle("fill", 0, 0,
                tonumber(shot.pw) or 320, tonumber(shot.ph) or 240)
    local alpha = p < 0.72 and 1
      or smooth01((1 - p) / 0.28)
    local targetH = viewportMin * 0.30
    local symbolScale = (targetH / geometry.symbolH)
                      * (0.72 + 0.28 * smooth01(math.min(1, p * 2)))
    g.setColor(1, 1, 1, clamp(alpha, 0, 1))
    g.draw(geometry.image, geometry.symbolQuad,
           screenCenterX, screenCenterY, 0,
           symbolScale, symbolScale,
           geometry.symbolW * 0.5, geometry.symbolH * 0.5)
  end

  -- Phase two: one short full-scene white flash replaces the sphere. As it
  -- falls away the already-present Mega sprite is revealed behind it.
  if elapsed >= MEGA_FX_FLASH_AT and elapsed < MEGA_FX_FLASH_END then
    local p = (elapsed - MEGA_FX_FLASH_AT)
              / (MEGA_FX_FLASH_END - MEGA_FX_FLASH_AT)
    -- Keep the first half of the intentionally short cue fully white.  An
    -- additive fade from the first frame was technically present, but on a
    -- bright battle backdrop its captured midpoint was almost
    -- indistinguishable from the uncovered Mega form.  A brief opaque hold
    -- makes the authored reveal readable, then the remaining frames fade
    -- cleanly back to the live scene.
    local hold = 0.55
    local alpha = p <= hold and 1
      or 1 - smooth01((p - hold) / (1 - hold))
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, clamp(alpha, 0, 1))
    g.rectangle("fill", 0, 0,
                tonumber(shot.pw) or 320, tonumber(shot.ph) or 240)
  end

  g.pop()
  return true
end

-- Commit the armed transformation and the selected move as one transaction.
-- KASC owns form/stat changes; this HUD only schedules presentation immediately
-- after KASC's apply action, then resolves the same move the player confirmed.
function FloatingHud.commitMegaMove(battle, moveIndex)
  if not FloatingHud.megaArmed(battle) then return false, "not_armed" end
  local moves = battle.player and battle.player.curMoves or {}
  local index = clamp(math.floor(tonumber(moveIndex) or 1), 1, 4)
  local move = moves[index]
  if not move or battle.player.disabledSlot == index
      or (tonumber(move.pp) or 0) <= 0 or battle.moveSwapIndex then
    return false, "move_unusable"
  end

  local kasc = kascExports()
  local mega = kasc and kasc.megaEvolution
  if not (mega and type(mega.activate) == "function") then
    FloatingHud.clearMegaArmed(battle)
    return false, "unavailable"
  end
  -- Remember where KASC starts appending its activation rows. Its public
  -- activate() queues the form application instead of changing the battler in
  -- this call. Attaching our reveal to that exact row prevents a one-frame
  -- leak where the already transformed sprite could be drawn before the
  -- supplied sphere masks it.
  local queueStart = type(battle.queue) == "table" and #battle.queue or nil
  local requestedProfile = battle._ascendantBattleHudMegaArmedProfile
  FloatingHud.clearMegaArmed(battle)
  local ok, activated, reason = pcall(
    mega.activate, battle, battle.player, "player", requestedProfile)
  if not ok then
    mod.log:warn("ORAS MEGA activation failed: %s", tostring(activated))
    return false, activated
  end
  if activated ~= true then return false, reason end
  Diagnostics.write("battle-mega-form-request", {
    species=battle.player and battle.player.mon
      and battle.player.mon.species or "unknown",
    form=requestedProfile or "provider-default",
  })

  battle.moveSwapIndex = nil
  battle._ascendantBattleHudMoveMegaFocus = nil
  battle._ascendantBattleHudMoveBackFocus = nil
  if type(battle.act) == "function" then
    local presentationAttached = false
    if queueStart and type(battle.queue) == "table" then
      for i = #battle.queue, queueStart + 1, -1 do
        local row = battle.queue[i]
        if type(row) == "table" and type(row.fn) == "function" then
          local applyMegaForm = row.fn
          row.fn = function(...)
            applyMegaForm(...)
            FloatingHud.startMegaTransformation(battle, "player")
          end
          presentationAttached = true
          break
        end
      end
    end
    -- Older/custom Mega providers may apply immediately instead of exposing a
    -- queued function row. They keep the established fail-open action order.
    if not presentationAttached then
      battle:act(function()
        FloatingHud.startMegaTransformation(battle, "player")
      end)
    end
    -- The Mega reveal is presentation time, while resolveTurn mutates battle
    -- state immediately (including damage/faint rows). Hold that transaction
    -- behind a one-frame queue barrier until the authored effect really ends;
    -- polling the live effect also stays correct under fast-forward, where a
    -- fixed frame count and real-time animation deliberately run at different
    -- rates.
    local function resolveSelectedMove()
      if battle.player and battle.player.mon
          and (tonumber(battle.player.mon.hp) or 0) > 0 then
        battle:resolveTurn(move)
      end
    end
    if type(battle.queue) == "table"
        and type(battle.actNext) == "function" then
      local barrierChecks = 0
      local function resolveAfterMegaPresentation()
        barrierChecks = barrierChecks + 1
        if battle._ascendantBattleHudMegaTransformation
            and barrierChecks < 1800 then
          battle.nextInsert = (battle.nextInsert or 0) + 1
          table.insert(battle.queue, battle.nextInsert, { wait=1 })
          battle:actNext(resolveAfterMegaPresentation)
          return
        end
        if barrierChecks >= 1800
            and battle._ascendantBattleHudMegaTransformation then
          mod.log:warn(
            "ORAS MEGA presentation barrier timed out; resolving turn")
        end
        Diagnostics.write("battle-mega-turn-release", {
          checks=barrierChecks, move=move.id or "unknown",
          timedOut=barrierChecks >= 1800,
        })
        resolveSelectedMove()
      end
      battle:act(resolveAfterMegaPresentation)
    else
      -- A few older/custom KASC hosts expose act() but no inspectable queue or
      -- actNext(). Preserve their established ordering without indexing nil or
      -- swallowing the attack; only the optional presentation barrier is lost.
      battle:act(resolveSelectedMove)
    end
  else
    -- Very old/custom battle implementations without a queue still transform
    -- safely; do not swallow the chosen attack in that compatibility case.
    return false, "queue_unavailable"
  end
  return true
end
end -- isolated MEGA state/effect closure; keeps Lua 5.1's local limit healthy

local function toWorld(rect, shot)
  local s = shot.scale
  return {
    shot.lx + rect[1] * s,
    shot.ly + rect[2] * s,
    rect[3] * s,
    rect[4] * s,
  }
end

-- Each semantic battle side owns one card whose seat is derived from that
-- owner's exact current rendered head and alpha hull. STADIUM/manual camera
-- motion therefore moves the card with the Pokemon without changing semantic
-- ownership, latch generation or payload identity.
FloatingHud.OWNER_ATTACHMENT = {
  player={ x=-3, y=-2 },
  enemy={ x=3, y=-2 },
}

function FloatingHud.ownerAnchorFor(shot, side)
  local visual = type(shot and shot.actorVisuals) == "table"
                 and shot.actorVisuals[side] or nil
  local head = type(visual) == "table" and visual.head or nil
  if not (type(head) == "table" and tonumber(head.x)
      and tonumber(head.y)) then return nil end
  return { x=head.x, y=head.y, source="exact-rendered-ink-head" }
end

function FloatingHud.projectOwnerStatusRect(shot, side)
  local anchor = FloatingHud.ownerAnchorFor(shot, side)
  local visual = type(shot and shot.actorVisuals) == "table"
                 and shot.actorVisuals[side] or nil
  local hull = type(visual) == "table" and visual.hull or nil
  local logicalW, logicalH = plateSize(side)
  if not (anchor and logicalW and logicalH
      and tonumber(shot.pw) and tonumber(shot.ph)) then return nil end

  local baseScale = uiScale(shot)
  -- Status scale is viewport/UI-owned. Position is render-frame-owned below,
  -- so camera perspective keeps a deterministic head-relative clearance.
  local drawScale = baseScale * (FloatingHud.STATUS_SCALE or 1)
  -- A 4:3 framebuffer is height-rich but comparatively narrow.  Letting one
  -- status card consume the old 48% width cap made two head-derived cards
  -- mathematically impossible to keep disjoint even at the widest safe lens.
  -- Wide player windows normally remain below this cap, so their authored
  -- scale is unchanged; compact/4:3 screens instead retain enough horizontal
  -- room for both owner cards and both actor hulls.
  local widthShare = shot.pw < shot.ph and 0.44 or 0.30
  drawScale = math.min(drawScale,
                       (shot.pw * widthShare) / logicalW,
                       (shot.ph * 0.30) / logicalH)
  drawScale = math.max(0.46, drawScale)

  local w, h = logicalW * drawScale, logicalH * drawScale
  local clearance = math.max(10,
    (FloatingHud.GAP or 0) * drawScale
      + (FloatingHud.EXTRA_RISE or 0) * baseScale * .35)
  local offset = FloatingHud.OWNER_ATTACHMENT[side]
                 or FloatingHud.OWNER_ATTACHMENT.player
  local sideGap = math.max(8, (FloatingHud.GAP or 0) * baseScale)
  local hullX = type(hull) == "table" and tonumber(hull[1]) or nil
  local hullY = type(hull) == "table" and tonumber(hull[2]) or nil
  local hullW = type(hull) == "table" and tonumber(hull[3]) or nil
  local hullH = type(hull) == "table" and tonumber(hull[4]) or nil
  if not (hullX and hullY and hullW and hullH and hullW > 0 and hullH > 0) then
    hullX, hullY, hullW, hullH = anchor.x, anchor.y, 0, 0
  end

  local mode = optionChoice("status_anchor", "outside"):lower()
  if mode ~= "above" and mode ~= "corners" then mode = "outside" end
  -- Prefer the side behind the head in landscape. In portrait it consumes
  -- most of the narrow axis, so
  -- SMART can satisfy it only by pulling the battle camera dramatically away
  -- (and can still reject the owner frame). Keep the same semantic owner and
  -- rearward bias there, but lift the default seat diagonally above the head.
  -- Explicit ABOVE/CORNERS choices remain untouched.
  local mobilePortraitOutside = mode == "outside" and shot.pw < shot.ph
  local insetLeft, insetTop, insetRight, insetBottom =
    FloatingHud.safeInsets(shot)
  local margin = math.max(8,
    math.floor(math.min(shot.pw, shot.ph) * .012))
  local minX, minY = (insetLeft or 0) + margin,
                     (insetTop or 0) + margin
  local maxX = math.max(minX,
    shot.pw - (insetRight or 0) - margin - w)
  local maxY = math.max(minY,
    shot.ph - (insetBottom or 0) - margin - h)

  -- OUTSIDE is the battle default: player sprites
  -- face right, so the rear of their head is left; enemy sprites face left,
  -- so the rear is right. The card's lower edge stays a fixed clearance above
  -- the exact rendered head. Ownership remains semantic even when a Stadium
  -- orbit makes the projections cross.
  local x
  local y
  if mode == "corners" then
    x = side == "player" and minX or maxX
    y = minY
  elseif mode == "above" then
    x = anchor.x - w * .5
    y = hullY - h - clearance
  elseif mobilePortraitOutside then
    x = anchor.x - w * (side == "player" and .82 or .18)
      + (offset.x or 0) * baseScale
    y = hullY - h - clearance + (offset.y or 0) * baseScale
  elseif side == "player" then
    x = anchor.x - sideGap - w + (offset.x or 0) * baseScale
    y = anchor.y - h - clearance + (offset.y or 0) * baseScale
  else
    x = anchor.x + sideGap + (offset.x or 0) * baseScale
    y = anchor.y - h - clearance + (offset.y or 0) * baseScale
  end
  if mode ~= "outside" then
    x = x + (offset.x or 0) * baseScale
    y = y + (offset.y or 0) * baseScale
  end

  local prefix = side == "enemy" and "enemy" or "player"
  x = x + (tonumber(optionChoice(prefix .. "_hud_x", 0)) or 0) * baseScale
  y = y + (tonumber(optionChoice(prefix .. "_hud_y", 0)) or 0) * baseScale

  local potatoHost = not isAscendantHost
                  and type(OverworldBattle.snapHUDs) ~= "function"
                  and type(OverworldBattle.drawHudPanels) == "function"
  if potatoHost then
    local yOffset = side == "enemy"
      and (FloatingHud.POTATO_ENEMY_Y_OFFSET or 0)
       or (FloatingHud.POTATO_PLAYER_Y_OFFSET or 0)
    y = y + yOffset * baseScale
  end

  -- Keep the head-relative seat inside the physical safe area. A fixed
  -- bitmap ground anchor cannot move sideways with camera recovery, so an
  -- overflowing card must be bounded here. The same frame still rejects any
  -- resulting actor/card collision below; no safety gate is disabled.
  x, y = clamp(x, minX, maxX), clamp(y, minY, maxY)
  local padding = math.max(8,
    math.floor(math.min(shot.pw, shot.ph) * .012))
  local function hitsActor(px, py)
    for _, actorSide in ipairs({ "player", "enemy" }) do
      local actor = type(shot.actorVisuals) == "table"
                    and shot.actorVisuals[actorSide] or nil
      local actorHull = type(actor) == "table" and actor.hull or nil
      if type(actorHull) == "table" and tonumber(actorHull[1])
          and tonumber(actorHull[2]) and tonumber(actorHull[3])
          and tonumber(actorHull[4])
          and FloatingHud.rectanglesHit(
            { px, py, w, h }, actorHull, padding) then
        return true
      end
    end
    return false
  end
  if (mode ~= "outside" or mobilePortraitOutside) and hitsActor(x, y) then
    local cornerX = side == "player" and minX or maxX
    local candidates = {
      { cornerX, minY },
      { clamp(anchor.x - w * .5, minX, maxX),
        clamp(hullY - h - clearance, minY, maxY) },
      { cornerX, maxY },
    }
    for _, candidate in ipairs(candidates) do
      if not hitsActor(candidate[1], candidate[2]) then
        x, y = candidate[1], candidate[2]
        break
      end
    end
  end

  return { x, y, w, h }, drawScale, logicalW, logicalH, anchor
end

FloatingHud.statusAttachmentStates = setmetatable({}, { __mode="k" })

function FloatingHud.statusViewportKey(shot)
  if not (shot and tonumber(shot.pw) and tonumber(shot.ph)) then return nil end
  local left, top, right, bottom = FloatingHud.safeInsets(shot)
  return table.concat({
    tostring(shot.pw), tostring(shot.ph),
    tostring(left or 0), tostring(top or 0),
    tostring(right or 0), tostring(bottom or 0),
    ("%.5f"):format(uiScale(shot)),
    ("%.5f"):format(tonumber(FloatingHud.STATUS_SCALE) or 1),
    tostring(optionChoice("status_anchor", "outside")):lower(),
    tostring(optionChoice("player_hud_x", 0)),
    tostring(optionChoice("player_hud_y", 0)),
    tostring(optionChoice("enemy_hud_x", 0)),
    tostring(optionChoice("enemy_hud_y", 0)),
  }, "|")
end

function FloatingHud.exactActorVisual(battle, shot, side)
  local visual = type(shot and shot.actorVisuals) == "table"
                 and shot.actorVisuals[side] or nil
  local battler = battle and battle[side] or nil
  local mon = battler and battler.mon or nil
  if not (battler ~= nil and mon ~= nil and type(visual) == "table"
      and visual.schema == "voxel-ascendant/actor-render/v1"
      and visual.side == side and visual.battler == battler
      and visual.mon == mon and visual.renderToken == shot.renderToken
      and type(visual.modelKey) == "string" and visual.modelKey ~= ""
      and visual.textureToken ~= nil and visual.canvas ~= nil
      and tonumber(visual.viewportW) == tonumber(shot.pw)
      and tonumber(visual.viewportH) == tonumber(shot.ph)
      and type(visual.head) == "table" and tonumber(visual.head.x)
      and tonumber(visual.head.y)) then return nil end
  return visual
end

function FloatingHud.statusIdentityMismatch(slot, visual)
  if not slot then return "slot" end
  if not visual then return "visual" end
  if slot.battler == nil or visual.battler == nil then return "battler" end
  if slot.mon == nil or visual.mon == nil then return "mon" end
  if slot.battler ~= visual.battler then return "battler" end
  if slot.mon ~= visual.mon then return "mon" end
  if slot.modelKey ~= visual.modelKey then return "modelKey" end
  if slot.textureToken ~= visual.textureToken then return "textureToken" end
  if slot.canvas ~= visual.canvas then return "canvas" end
  if slot.view ~= visual.view then return "view" end
  return nil
end

function FloatingHud.sameStatusIdentity(slot, visual)
  return FloatingHud.statusIdentityMismatch(slot, visual) == nil
end

-- Attack/damage blink frames intentionally omit a model visual while the
-- semantic battler remains unchanged. The last exact head-relative seat may
-- survive only that exact owner gap; a real switch presents a different
-- battler/mon and must wait for a fresh exact actor receipt.
function FloatingHud.statusSlotMatchesLiveOwner(slot, battle, side)
  local battler = battle and battle[side] or nil
  return type(slot) == "table" and slot.side == side
     and battler ~= nil and slot.battler == battler
     and slot.mon == battler.mon
end

function FloatingHud.statusSlotsForPresentation(
    battle, proposal, playerLive, enemyLive)
  if not (proposal and proposal.battle == battle
      and proposal.complete == true) then return nil end
  if battle then battle._ascendantHudRetainedStatusLogged = nil end
  return proposal.slots
end

function FloatingHud.statusSlotFromVisual(shot, side, visual)
  local rect, _, _, _, anchor = FloatingHud.projectOwnerStatusRect(shot, side)
  if not (rect and anchor and visual) then return nil end
  return {
    side=side, battler=visual.battler, mon=visual.mon,
    modelKey=visual.modelKey, textureToken=visual.textureToken,
    inkIdentity=visual.inkIdentity, canvas=visual.canvas, view=visual.view,
    rect={ rect[1], rect[2], rect[3], rect[4] },
    anchor={ x=anchor.x, y=anchor.y, source=anchor.source },
    visualHull=visual.hull,
  }
end

-- A status card is attached to the semantic battler/mon owner, not to one
-- animation frame or render canvas. Every exact frame reprojects the reviewed
-- behind-head/above-head offset from the current visible hull. Generation and
-- serial ownership remain stable; a real battler/mon replacement still takes
-- the ordinary acquisition path.
function FloatingHud.refreshStatusSlot(old, visual, shot, side)
  if not (old and visual and old.battler ~= nil and old.mon ~= nil
      and visual.battler ~= nil and visual.mon ~= nil
      and old.battler == visual.battler
      and old.mon == visual.mon and type(old.rect) == "table"
      and type(old.anchor) == "table") then return nil end
  return FloatingHud.statusSlotFromVisual(
    shot, side or old.side, visual)
end

function FloatingHud.rectanglesHit(a, b, padding)
  padding = tonumber(padding) or 0
  return a[1] < b[1] + b[3] + padding
     and a[1] + a[3] + padding > b[1]
     and a[2] < b[2] + b[4] + padding
     and a[2] + a[4] + padding > b[2]
end

-- Head-projected slots re-run this exact evaluator. Safe-area, actor-hull,
-- peer-card and reserved-band collisions remain authoritative and suppress an
-- unsafe presentation frame.
function FloatingHud.statusLatchFrameSafe(shot, slots, reserved)
  if not (shot and tonumber(shot.pw) and tonumber(shot.ph)) then
    return false, "viewport-unavailable"
  end
  local insetLeft, insetTop, insetRight, insetBottom =
    FloatingHud.safeInsets(shot)
  local padding = math.max(8, math.floor(math.min(shot.pw, shot.ph) * .012))
  local present = {}
  for _, side in ipairs({ "player", "enemy" }) do
    local slot = slots[side]
    local rect = slot and slot.rect
    if rect then
      if rect[1] < (insetLeft or 0)
          or rect[2] < (insetTop or 0)
          or rect[1] + rect[3] > shot.pw - (insetRight or 0)
          or rect[2] + rect[4] > shot.ph - (insetBottom or 0) then
        return false, side .. "-status-outside-safe-frame"
      end
      for _, actorSide in ipairs({ "player", "enemy" }) do
        local visual = type(shot.actorVisuals) == "table"
          and shot.actorVisuals[actorSide] or nil
        local hull = visual and visual.hull
        if type(hull) == "table"
            and FloatingHud.rectanglesHit(rect, hull, padding) then
          return false, side .. "-status-over-" .. actorSide .. "-actor"
        end
      end
      for _, blocked in ipairs(reserved or {}) do
        if type(blocked) == "table"
            and FloatingHud.rectanglesHit(rect, blocked, padding) then
          return false, side .. "-status-over-reserved-hud"
        end
      end
      present[#present + 1] = rect
    end
  end
  if #present == 2 then
    if FloatingHud.rectanglesHit(present[1], present[2], padding) then
      return false, "status-card-overlap"
    end
  end
  return true
end

function FloatingHud.proposeStatusLatch(
    battle, shot, playerLive, enemyLive, reserved)
  local state = battle and FloatingHud.statusAttachmentStates[battle] or nil
  local key = FloatingHud.statusViewportKey(shot)
  local viewportChanged = state and state.viewportKey ~= key or false
  local initial = not state or state.initialized ~= true
  local atomic = initial or viewportChanged
  local slots, changed, receiptRefresh, pending, mismatch = {}, {}, {}, {}, {}
  local live = { player=playerLive == true, enemy=enemyLive == true }

  -- A viewport change reacquires an already established pair atomically so it
  -- cannot expose mixed old/new screen generations.  Initial battle lifecycle
  -- frames are different: trainer intros may have no live billboard and wild
  -- send-out may have one, so each exact first owner can latch independently.
  if atomic and not initial and not (battle and battle.safari)
      and not ((live.player or (battle.player and battle.player.fainted))
        and (live.enemy or (battle.enemy and battle.enemy.fainted))) then
    return { battle=battle, shot=shot, viewportKey=key, state=state,
      slots=slots, changed=changed, pending={player=live.player,enemy=live.enemy},
      live=live, ready=false, safe=false, complete=false,
      atomic=true, receiptRefresh=receiptRefresh, reserved=reserved }
  end

  for _, side in ipairs({ "player", "enemy" }) do
    if live[side] then
      local visual = FloatingHud.exactActorVisual(battle, shot, side)
      local old = not atomic and state and state[side] or nil
      if old and FloatingHud.sameStatusIdentity(old, visual) then
        slots[side] = FloatingHud.refreshStatusSlot(
          old, visual, shot, side) or old
        -- Even a renderer that mutates/reuses its visual receipt may move the
        -- projected head. Commit every fresh exact projection; generation and
        -- serial remain stable in commitStatusLatch.
        receiptRefresh[side] = slots[side] ~= old
      elseif old and not visual
          and FloatingHud.statusSlotMatchesLiveOwner(old, battle, side) then
        slots[side] = old
      elseif old and visual and old.battler ~= nil and old.mon ~= nil
          and old.battler == visual.battler
          and old.mon == visual.mon then
        mismatch[side] = FloatingHud.statusIdentityMismatch(old, visual)
        slots[side] = FloatingHud.refreshStatusSlot(old, visual, shot, side)
        changed[side] = slots[side] ~= nil
      elseif visual then
        mismatch[side] = old
          and FloatingHud.statusIdentityMismatch(old, visual) or "initial"
        slots[side] = FloatingHud.statusSlotFromVisual(shot, side, visual)
        changed[side] = slots[side] ~= nil
      end
      pending[side] = slots[side] == nil
    end
  end

  local ready = true
  for _, side in ipairs({ "player", "enemy" }) do
    if live[side] and not slots[side] then ready = false end
  end
  local safe, unsafeReason = false, nil
  if ready then
    safe, unsafeReason = FloatingHud.statusLatchFrameSafe(
      shot, slots, reserved)
  end
  return {
    battle=battle, shot=shot, viewportKey=key, state=state,
    slots=slots, changed=changed, pending=pending, mismatch=mismatch, live=live,
    ready=ready, safe=safe, complete=ready and safe,
    unsafeReason=unsafeReason,
    atomic=atomic, receiptRefresh=receiptRefresh, reserved=reserved,
  }
end

function FloatingHud.attachmentReceipt(state, proposal)
  local rects, anchors, generations, pending = {}, {}, {}, {}
  for _, side in ipairs({ "player", "enemy" }) do
    local slot = state and state[side]
    if proposal and proposal.live[side] and slot then
      rects[side], anchors[side] = slot.rect, slot.anchor
      generations[side] = slot.generation
    end
    local visual = proposal and FloatingHud.exactActorVisual(
      proposal.battle, proposal.shot, side) or nil
    pending[side] = proposal and proposal.live[side]
      and (not slot or (not FloatingHud.sameStatusIdentity(slot, visual)
        and not (not visual and FloatingHud.statusSlotMatchesLiveOwner(
          slot, proposal.battle, side)))) or false
  end
  return {
    schema="voxel-ascendant/hud-owner-screen-latch/v1",
    binding={ player="player", enemy="enemy" },
    anchors=anchors, rects=rects, generations=generations,
    pending=pending, mismatch=state and state.lastMismatch or {},
    serial=state and state.serial or 0,
    viewportKey=state and state.viewportKey or nil,
  }
end

function FloatingHud.commitStatusLatch(proposal)
  if not (proposal and proposal.complete and proposal.battle
      and proposal.shot and not proposal.shot.cameraSafety
      and proposal.viewportKey
        == FloatingHud.statusViewportKey(proposal.shot)) then
    return false
  end
  local battle = proposal.battle
  local state = FloatingHud.statusAttachmentStates[battle]
  if state ~= proposal.state then return false end
  if not state or proposal.atomic then
    state = { serial=state and state.serial or 0,
              generations=state and state.generations
                or { player=0, enemy=0 },
              lastMismatch=state and state.lastMismatch or {} }
  end
  for _, side in ipairs({ "player", "enemy" }) do
    if proposal.live[side] then
      local slot = proposal.slots[side]
      local visual = FloatingHud.exactActorVisual(
        battle, proposal.shot, side)
      local exactVisual = slot and visual
        and FloatingHud.sameStatusIdentity(slot, visual)
      local exactHiddenOwner = slot and not visual
        and FloatingHud.statusSlotMatchesLiveOwner(slot, battle, side)
      if not (exactVisual or exactHiddenOwner) then
        return false
      end
    end
  end
  for _, side in ipairs({ "player", "enemy" }) do
    if not proposal.live[side] then
      state[side] = nil
    elseif proposal.changed[side] then
      state.serial = state.serial + 1
      state.generations[side] = (state.generations[side] or 0) + 1
      state.lastMismatch[side] = proposal.atomic and "viewport"
        or proposal.mismatch[side]
      proposal.slots[side].generation = state.generations[side]
      proposal.slots[side].serial = state.serial
      state[side] = proposal.slots[side]
    elseif proposal.receiptRefresh and proposal.receiptRefresh[side] then
      -- Animation frames update current content, hull and head-projected
      -- geometry without pretending that the semantic owner was reacquired.
      local previous = state[side]
      proposal.slots[side].generation = previous and previous.generation
      proposal.slots[side].serial = previous and previous.serial
      state[side] = proposal.slots[side]
    end
  end
  state.viewportKey, state.initialized = proposal.viewportKey, true
  FloatingHud.statusAttachmentStates[battle] = state
  battle._floatingBattleHudOwnerAttachment =
    FloatingHud.attachmentReceipt(state, proposal)
  return true, state
end

function FloatingHud.statusLatchReceipt(battle, proposal)
  return FloatingHud.attachmentReceipt(
    battle and FloatingHud.statusAttachmentStates[battle] or nil, proposal)
end

function FloatingHud.clearStatusLatch(battle)
  if not battle then return false end
  FloatingHud.statusAttachmentStates[battle] = nil
  battle._floatingBattleHudOwnerAttachment = nil
  return true
end

-- Bind content by semantic battle side after positional collision resolution.
-- Do not infer ownership from left/right or upper/lower screen order: a full
-- Stadium orbit can cross projections without ever turning Tentacool's enemy
-- card into Pikachu's player card.
function FloatingHud.bindStatusPayloads(battle, pose)
  local slots = type(pose) == "table" and pose.slots or nil
  slots = type(slots) == "table" and slots or {}
  local payloads = {}
  if slots.enemy then
    payloads.enemy = {
      side="enemy", battler=slots.enemy.battler, rect=slots.enemy.rect,
    }
  end
  if slots.player then
    payloads.player = {
      side="player", battler=slots.player.battler, rect=slots.player.rect,
    }
  end
  return payloads
end

-- Shadow offset in FINAL framebuffer pixels, even though the HUD itself changes
-- integer scale with the window. Called after g.scale(k,k), hence division by k.
local function shadowLogical(k, extraScale)
  return FloatingHud.SHADOW_PX / math.max(0.001, k * (extraScale or 1))
end

-- Draw the same hard silhouette around the original shadow origin. This deliberately
-- uses only eight neighbouring copies (plus the original), rather than a shader or a
-- large NxN dilation loop: it keeps the pixel-art edge crisp and avoids the much more
-- invasive shadow rewrite that made the abandoned v0.6.8 branch unstable.
local function eachShadowOffset(k, extraScale, fn)
  local denom = math.max(0.001, k * (extraScale or 1))
  local o = FloatingHud.SHADOW_PX / denom
  local growPx = math.max(0, tonumber(FloatingHud.SHADOW_GROW_PX) or 0)
  local grow = growPx / denom

  fn(o, o)
  if grow <= 0 then return end

  fn(o - grow, o)
  fn(o + grow, o)
  fn(o, o - grow)
  fn(o, o + grow)
  fn(o - grow, o - grow)
  fn(o + grow, o - grow)
  fn(o - grow, o + grow)
  fn(o + grow, o + grow)
end

local function drawMaskedFont(text, x, y, r, gg, b, a)
  local shader = getTextMaskShader()
  if not shader then
    -- Fallback is the engine's native black font. This path should only happen
    -- on a driver that cannot compile the tiny mask shader.
    g.setShader()
    g.setColor(r, gg, b, a or 1)
    return Font.draw(text, x, y)
  end

  local previous = g.getShader()
  g.setShader(shader)
  pcall(shader.send, shader, "ink", { r, gg, b, a or 1 })
  g.setColor(1, 1, 1, 1)
  local out = Font.draw(text, x, y)
  g.setShader(previous)
  return out
end

local function drawShadowText(text, x, y, k, extraScale)
  text = tostring(text or "")
  extraScale = extraScale or 1
  local theme = hudTheme()
  local shadow, ink = theme.shadow, theme.text

  if extraScale ~= 1 then
    g.push()
    g.translate(x, y)
    g.scale(extraScale, extraScale)
    eachShadowOffset(k, extraScale, function(sx, sy)
      drawMaskedFont(text, sx, sy, shadow[1], shadow[2], shadow[3], 1)
    end)
    drawMaskedFont(text, 0, 0, ink[1], ink[2], ink[3], 1)
    g.pop()
    return
  end

  eachShadowOffset(k, 1, function(sx, sy)
    drawMaskedFont(text, x + sx, y + sy,
                   shadow[1], shadow[2], shadow[3], 1)
  end)
  drawMaskedFont(text, x, y, ink[1], ink[2], ink[3], 1)
end

local function drawShadowTextCentered(text, centerX, y, k, extraScale)
  extraScale = extraScale or 1
  local w = textWidth(text) * extraScale
  drawShadowText(text, centerX - w * 0.5, y, k, extraScale)
end

local function drawGenderSymbol(symbol, x, y, k, scale)
  if symbol ~= "♂" and symbol ~= "♀" then return false end
  scale = tonumber(scale) or 1
  local ink = symbol == "♂" and { 0.20, 0.64, 1.00 }
                              or { 1.00, 0.30, 0.66 }
  local shadow = hudTheme().shadow

  -- Draw the two signs as geometry instead of relying on a Unicode glyph in
  -- Gen I's deliberately small bitmap font. This keeps them identical on
  -- desktop, Android and iOS.
  local function shape(dx, dy)
    if symbol == "♂" then
      g.circle("line", dx + 3.0, dy + 5.0, 2.3)
      g.line(dx + 4.7, dy + 3.3, dx + 8.0, dy + 0.0)
      g.line(dx + 5.4, dy + 0.0, dx + 8.0, dy + 0.0,
             dx + 8.0, dy + 2.6)
    else
      g.circle("line", dx + 4.0, dy + 3.2, 2.3)
      g.line(dx + 4.0, dy + 5.5, dx + 4.0, dy + 9.0)
      g.line(dx + 1.8, dy + 7.3, dx + 6.2, dy + 7.3)
    end
  end

  g.push()
  g.translate(x, y)
  g.scale(scale, scale)
  g.setColor(shadow[1], shadow[2], shadow[3], 0.94)
  g.setLineWidth(3)
  shape(1, 1)
  g.setColor(ink[1], ink[2], ink[3], 1)
  g.setLineWidth(1.35)
  shape(0, 0)
  g.setLineWidth(1)
  g.pop()
  return true
end

local function drawShadowAsset(img, x, y, k, scale, colored)
  if not img then return false end
  scale = scale or FloatingHud.ASSET_SCALE

  -- Silhouette shadow first. Tinting an Image black preserves its alpha mask.
  local theme = hudTheme()
  g.setColor(theme.shadow[1], theme.shadow[2], theme.shadow[3], 1)
  eachShadowOffset(k, 1, function(sx, sy)
    g.draw(img, x + sx, y + sy, 0, scale, scale)
  end)

  -- Battleplates are white masks; status/caught keep their authored colors.
  local color = colored and { 1, 1, 1 } or theme.plate
  g.setColor(color[1], color[2], color[3], 1)
  g.draw(img, x, y, 0, scale, scale)
  return true
end

local function drawShadowAssetRotated(img, x, y, k, scale, angle)
  if not img then return false end
  scale = scale or FloatingHud.ASSET_SCALE
  angle = angle or 0
  local iw, ih = img:getDimensions()
  local w, h = iw * scale, ih * scale
  local cx, cy = x + w * 0.5, y + h * 0.5

  local theme = hudTheme()
  g.setColor(theme.shadow[1], theme.shadow[2], theme.shadow[3], 1)
  eachShadowOffset(k, 1, function(sx, sy)
    g.draw(img, cx + sx, cy + sy, angle, scale, scale, iw * 0.5, ih * 0.5)
  end)
  g.setColor(theme.plate[1], theme.plate[2], theme.plate[3], 1)
  g.draw(img, cx, cy, angle, scale, scale, iw * 0.5, ih * 0.5)
  return true
end

local function drawStatus(mon, x, y, k)
  local status = mon and mon.status
  if not status then return false end

  local path = STATUS_ASSETS[status]
  local img = path and assetImage(path) or nil
  if img then
    drawShadowAsset(img, x, y, k, FloatingHud.ASSET_SCALE, true)
    return true
  end

  local fallback = STATUS_FALLBACK[status]
  if fallback then
    drawShadowText(fallback, x, y, k)
    return true
  end
  return false
end

local function drawCaughtMarker(x, y, k, mode)
  local img = assetImage(CAUGHT_ASSET)
  if img then
    if mode == "grey" then
      local theme = hudTheme()
      g.setColor(theme.shadow[1], theme.shadow[2], theme.shadow[3], 1)
      eachShadowOffset(k, 1, function(sx, sy)
        g.draw(img, x + sx, y + sy, 0,
               FloatingHud.ASSET_SCALE, FloatingHud.ASSET_SCALE)
      end)
      g.setColor(0.52, 0.52, 0.52, 1)
      g.draw(img, x, y, 0,
             FloatingHud.ASSET_SCALE, FloatingHud.ASSET_SCALE)
      return true
    end
    return drawShadowAsset(img, x, y, k, FloatingHud.ASSET_SCALE, true)
  end
  drawShadowText("C", x, y, k)
  return true
end

local function drawShinyMarker(x, y, k)
  local theme = hudTheme()
  local function star(dx, dy)
    g.polygon("fill",
      dx + 4, dy, dx + 5.2, dy + 2.8,
      dx + 8, dy + 4, dx + 5.2, dy + 5.2,
      dx + 4, dy + 8, dx + 2.8, dy + 5.2,
      dx, dy + 4, dx + 2.8, dy + 2.8)
  end
  local o = shadowLogical(k, 1)
  g.setColor(theme.shadow[1], theme.shadow[2], theme.shadow[3], 1)
  star(o, o)
  g.setColor(1.00, 0.82, 0.08, 1)
  star(0, 0)
  return true
end

local function drawEventMarker(x, y, k)
  local o = shadowLogical(k, 1)
  g.setColor(0, 0, 0, 1)
  g.rectangle("fill", x + 2 + o, y + o, 3, 7)
  g.rectangle("fill", x + o, y + 2 + o, 7, 3)
  g.setColor(0.98, 0.99, 1.00, 1)
  g.rectangle("fill", x + 2, y, 3, 7)
  g.rectangle("fill", x, y + 2, 7, 3)
  g.setColor(0.28, 0.88, 1.00, 1)
  g.rectangle("fill", x + 2, y + 2, 3, 3)
  return true
end

local function drawStatusMarkers(battle, side, battler, k, right, y)
  local kinds = FloatingHud.statusMarkerKinds(battle, side, battler)
  local x = right - #kinds * 10
  for _, kind in ipairs(kinds) do
    if kind == "caught" then
      drawCaughtMarker(x, y, k, hudCaughtChoice(battle))
    elseif kind == "shiny" then
      drawShinyMarker(x, y, k)
    elseif kind == "event" then
      drawEventMarker(x, y, k)
    end
    x = x + 10
  end
  return #kinds > 0
end

local function drawHPFill(layout, ratio)
  local r = layout.hpFill
  ratio = clamp(ratio or 0, 0, 1)
  local w = r.w * ratio
  if w <= 0 then return end

  -- Gen-I style HP states: green above half, yellow from 21-50%, red at 20%
  -- or lower. Only the fill changes colour; the authored plate remains white.
  if ratio <= 0.20 then
    g.setColor(0.95, 0.16, 0.12, 1)
  elseif ratio <= 0.50 then
    g.setColor(1.00, 0.82, 0.10, 1)
  else
    g.setColor(0.15, 0.92, 0.30, 1)
  end
  g.rectangle("fill", r.x, r.y, w, r.h)
end

local function drawEXPFill(layout, ratio, mode)
  local r = layout.expFill
  if not r or mode == "off" then return end
  ratio = clamp(ratio or 0, 0, 1)
  local w = r.w * ratio
  if w <= 0 then return end

  if mode == "black" then
    g.setColor(0.01, 0.02, 0.03, 1)
  else
    g.setColor(0.12, 0.62, 1.00, 1)
  end
  g.rectangle("fill", r.x, r.y, w, r.h)
end

local function drawCompactHpBar(x, y, width, height, ratio)
  ratio = clamp(tonumber(ratio) or 0, 0, 1)
  g.setColor(0.02, 0.04, 0.05, 0.88)
  g.rectangle("fill", x, y, width, height, 2, 2)
  g.setColor(0.82, 0.90, 0.92, 0.92)
  g.rectangle("line", x, y, width, height, 2, 2)
  if ratio <= 0.20 then
    g.setColor(0.98, 0.18, 0.14, 1)
  elseif ratio <= 0.50 then
    g.setColor(1.00, 0.80, 0.10, 1)
  else
    g.setColor(0.12, 0.94, 0.30, 1)
  end
  local fill = math.max(0, (width - 2) * ratio)
  if fill > 0 then g.rectangle("fill", x + 1, y + 1, fill, height - 2, 1, 1) end
end

function FloatingHud.drawColoredAsset(image, x, y, scale, alpha)
  if not image then return false end
  g.setColor(1, 1, 1, alpha or 1)
  g.draw(image, x or 0, y or 0, 0, scale or 1, scale or 1)
  return true
end

function FloatingHud.drawHandCursor(targetX, targetY, scale, frame)
  -- A small white glove points down at the current choice. It is geometry rather
  -- than a font glyph or OS cursor, so it never changes across render backends.
  scale = tonumber(scale) or 1
  local bob = math.sin((tonumber(frame) or 0) * 0.14) * 1.25
  g.push()
  g.translate(targetX - 8 * scale, targetY - 20 * scale + bob)
  g.scale(scale, scale)
  g.setLineJoin("miter")
  g.setColor(0.005, 0.015, 0.025, 0.98)
  g.polygon("fill", 5,0, 10,0, 10,7, 12,4, 15,5, 15,10,
            12,15, 10,15, 10,19, 6,19, 6,15, 3,13, 1,9,
            2,6, 5,8)
  g.setColor(0.98, 0.99, 1.00, 1)
  g.polygon("fill", 6,1, 9,1, 9,10, 11,6, 13,6, 14,9,
            11,14, 9,14, 9,16, 7,16, 7,14, 4,12, 2,9,
            3,7, 6,10)
  g.setColor(0.23, 0.83, 1.00, 1)
  g.rectangle("fill", 6, 16, 4, 3)
  g.setColor(0.005, 0.015, 0.025, 0.75)
  g.line(4,12, 7,12, 9,14)
  g.setLineJoin("none")
  g.pop()
  return true
end

function FloatingHud.drawStyleSurface(kind, logicalW, logicalH, k)
  local style = hudStyle()
  if style == "oras" then
    g.setColor(0, 0, 0, 0.56)
    g.rectangle("fill", 3, 4, logicalW - 4, logicalH - 3, 9, 9)
    g.setColor(0.015, 0.045, 0.065, kind == "message" and 0.78 or 0.90)
    g.rectangle("fill", 0, 0, logicalW - 4, logicalH - 4, 9, 9)
    g.setColor(1, 1, 1, 0.15)
    g.line(9, 3, logicalW - 16, 3)
    if kind == "command" then
      drawEditionCardBorder("command", 0, 0,
        logicalW - 4, logicalH - 4, 9, 1)
    elseif kind == "message" then
      drawEditionCardBorder("message", 0, 0,
        logicalW - 4, logicalH - 4, 9, 1)
    else
      drawEditionCardBorder(kind, 0, 0,
        logicalW - 4, logicalH - 4, 9, 1)
    end
    return true
  end
  return false
end

local function drawMegaBadge(battle, profile, x, y, k)
  if not profile then return false end
  local frame = tonumber(battle and battle.frame) or 0
  local pulse = 0.5 + 0.5 * math.sin(frame * 0.11)
  local radius = 5 + pulse * 0.8
  local accent = hudTheme().accent
  g.setColor(accent[1], accent[2], accent[3], 0.42 + pulse * 0.40)
  g.circle("fill", x, y, radius)
  g.setColor(1, 1, 1, 0.72 + pulse * 0.28)
  g.circle("line", x, y, radius)
  drawMaskedFont("M", x - 4, y - 4, 1, 1, 1, 0.82 + pulse * 0.18)
  return true
end

function FloatingHud.partyForSide(battle, side)
  if not battle then return nil end
  if side == "enemy" then return battle.enemyParty end
  if type(battle.playerParty) == "table" then return battle.playerParty end
  local save = battle.game and battle.game.save
  return save and save.party or nil
end

function FloatingHud.partyBallState(battle, side, slot, battler)
  local party = FloatingHud.partyForSide(battle, side)
  local mon = type(party) == "table" and party[slot] or nil
  if not mon then return "empty" end
  local hp = tonumber(mon.hp) or 0
  local active = battler and mon == battler.mon
  -- The active Battler animates HP independently from the backing party Mon.
  -- During the final damage/faint frames mon.hp may still contain the old
  -- positive value although the visible HUD has already reached zero.  Use
  -- the same displayed value as the status card so the opposing team receipt
  -- cannot show a red/live ball next to a visibly defeated Pokemon.
  if active then
    local shown = select(1, shownHP(battler))
    if battler.fainted == true or shown <= 0 then return "defeated" end
    return "active"
  end
  return hp > 0 and "alive" or "defeated"
end

function FloatingHud.drawPartyReceipt(battle, side, battler, k, logicalW)
  if not (battle and battler and battler.mon) then return false end
  -- Match ORAS: the player's roster is always visible; the opposing receipt
  -- appears only when a trainer/link enemyParty actually exists. A wild Pokémon
  -- is not presented as a six-slot team.
  if type(FloatingHud.partyForSide(battle, side)) ~= "table" then return false end
  local source = assetImage(TRAINER_BALL_ASSETS.alive)
  if not source then return false end
  local iw, ih = source:getDimensions()
  -- These authored receipts already contain their own crisp black outline.
  -- Draw them without the generic plate shadow: at this size a second
  -- silhouette muddies the states and makes six proper balls look like dots.
  local iconScale = FloatingHud.ASSET_SCALE * 0.72
  local iconW, iconH = iw * iconScale, ih * iconScale
  local gap = 2
  logicalW = tonumber(logicalW) or select(1, plateSize(side))
  local rowW = iconW * 6 + gap * 5
  local x = math.floor((logicalW - rowW) * 0.5 + 0.5)
  local y = side == "player" and 35 or 29
  for slot = 1, 6 do
    local state = FloatingHud.partyBallState(battle, side, slot, battler)
    local ball = assetImage(TRAINER_BALL_ASSETS[state])
    if ball then
      local bx = x + (slot - 1) * (iconW + gap)
      if state == "active" then
        local accent = hudTheme().accent
        g.setColor(accent[1], accent[2], accent[3], 0.40)
        g.circle("fill", bx + iconW * 0.5, y + iconH * 0.5,
                 iconW * 0.59)
      end
      g.setColor(1, 1, 1, 1)
      g.draw(ball, bx, y, 0, iconScale, iconScale)
    end
  end
  return iconH > 0
end

local function drawCompactStatusCard(battle, side, battler, k, logicalW, logicalH)
  local mon = battler.mon
  local theme = hudTheme()
  local hp, maxHP = shownHP(battler)
  local ratio = hp / math.max(1, maxHP)
  local gender = genderSymbol(battle, mon)
  local nameScale = side == "player" and 0.82 or 0.78
  local levelScale = 0.72
  local genderScale = nameScale * 0.82
  local levelText = "Lv." .. tostring(mon.level or "?")
  local levelW = textWidth(levelText) * levelScale
  local levelX = logicalW - 7 - levelW
  local genderRoom = gender and (8 * genderScale + 2) or 0
  local nameX, nameY = 7, 4
  local nameMax = math.max(16, (levelX - nameX - genderRoom - 3) / nameScale)
  local name = fitText(battler.name or mon.species or "", nameMax)
  local glass = FloatingHud.statusGlassStrength()

  -- A narrow ORAS ribbon: opaque enough directly behind text, transparent over
  -- the arena everywhere else, with clipped ends that visually hug the Pokémon.
  g.setColor(0, 0, 0, 0.48 * glass)
  g.polygon("fill", 4, 4, logicalW - 2, 4,
            logicalW - 9, logicalH, 0, logicalH)
  g.setColor(0.012, 0.038, 0.055, 0.91 * glass)
  g.polygon("fill", 1, 1, logicalW - 6, 1,
            logicalW - 12, logicalH - 3, 0, logicalH - 3)
  g.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.78)
  g.setLineWidth(1)
  g.line(7, logicalH - 3, logicalW - 13, logicalH - 3)

  drawShadowText(name, nameX, nameY, k, nameScale)
  local genderX = nameX + textWidth(name) * nameScale + 2
  if gender and genderX + 8 * genderScale < levelX then
    drawGenderSymbol(gender, genderX, nameY + 0.5, k, genderScale)
  end
  drawShadowText(levelText, levelX, nameY + 0.5, k, levelScale)

  local hpLabel = hudLanguage() == "de" and "KP" or "HP"
  drawShadowText(hpLabel, 7, 17, k, 0.62)
  drawCompactHpBar(27, 17.5, logicalW - 39, 7, ratio)

  if side == "player" then
    local status = mon.status and STATUS_FALLBACK[mon.status] or nil
    local infoY = 28
    if status then
      drawShadowText(status, 7, infoY, k, 0.58)
    end
    local numbers = tostring(hp) .. "/" .. tostring(maxHP)
    local numberScale = 0.68
    drawShadowText(numbers,
                   logicalW - 8 - textWidth(numbers) * numberScale,
                   infoY, k, numberScale)

    local expMode = hudExpChoice(battle)
    if expMode ~= "off" then
      local exp = expRatio(battle, battler)
      local expX, expY, expW = 22, logicalH - 7, logicalW - 34
      drawShadowText(hudLanguage() == "de" and "EP" or "EXP",
                     7, expY - 1.5, k, 0.40)
      g.setColor(0.01, 0.025, 0.04, 0.96)
      g.rectangle("fill", expX, expY, expW, 3, 1, 1)
      if expMode == "black" then
        g.setColor(0.01, 0.02, 0.03, 1)
      else
        g.setColor(0.11, 0.67, 1.00, 1)
      end
      g.rectangle("fill", expX, expY, expW * exp, 3, 1, 1)
      if expMode == "blue" then
        g.setColor(0.70, 0.93, 1.00, 0.72)
        g.rectangle("fill", expX, expY, expW * exp, 1)
      end
    end
  elseif showWildDVs(battle, side, battler) then
    -- Wild opponents do not own a six-ball party receipt, leaving the lower
    -- band of the compact ORAS card free. The old floating-HUD branch already
    -- rendered these five read-only Gen-I DVs; mirror that feature in the
    -- actually selected compact card instead of making the menu toggle a no-op.
    local text = dvText(mon)
    if text then
      local prefix = "DV "
      local scale = 0.43
      local maxWidth = logicalW - 16
      while scale > 0.32
          and textWidth(prefix .. text) * scale > maxWidth do
        scale = scale - 0.02
      end
      drawShadowText(prefix .. text, 7, logicalH - 13, k, scale)
    end
  end
  FloatingHud.drawPartyReceipt(battle, side, battler, k, logicalW)
  -- KASC suppresses every native-coordinate overlay after this exact VASC
  -- frame commits. Preserve its read-only shiny/event metadata, plus the
  -- caught cue, inside the same owned card instead of leaving detached pixels.
  drawStatusMarkers(battle, side, battler, k, logicalW - 7, logicalH - 13)
  drawEditionCardBorder("status", 0, 0, logicalW, logicalH, 0, 1)
end

local cardCanvases = {}
local cardMeshes = {}
-- VASC presents its world canvas upside-down on iOS. Intermediate HUD canvases
-- are always authored upright; only their final world-plane draw is pre-flipped.
FloatingHud.activeWorldPreflipHeight = nil

local function cardCanvas(side, logicalW, logicalH)
  local pad = FloatingHud.CANVAS_PAD or 0
  local raster = math.max(1, tonumber(FloatingHud.CANVAS_RENDER_SCALE) or 1)

  -- cw/ch are texture pixels; logicalCW/logicalCH are the exact same plane in
  -- HUD coordinates. The mesh later uses the logical size, so increasing raster
  -- density never changes the HUD's size or any hand-tuned layout coordinate.
  local logicalCW = logicalW + pad * 2
  local logicalCH = logicalH + pad * 2
  local cw = math.ceil(logicalCW * raster)
  local ch = math.ceil(logicalCH * raster)
  local canvas = cardCanvases[side]
  if not canvas or canvas:getWidth() ~= cw or canvas:getHeight() ~= ch then
    local ok, made = pcall(g.newCanvas, cw, ch, { dpiscale = 1 })
    if not (ok and made) then return nil end
    -- The authored assets themselves remain nearest-filtered. The completed
    -- supersampled card is sampled linearly only during its final perspective
    -- projection, avoiding the broken/stair-stepped glyph edges of the old
    -- ~105x63 intermediate texture.
    pcall(made.setFilter, made, "linear", "linear")
    canvas = made
    cardCanvases[side] = canvas
  end
  return canvas, cw, ch, pad, raster, logicalCW, logicalCH
end

local function renderCardCanvas(battle, side, battler, k, logicalW, logicalH)
  local plate = plateImage(side)
  -- ORAS draws its own compact ribbon and needs no legacy donor plate. The
  -- release package intentionally contains ORAS assets only.
  if hudStyle() == "float" and not plate then return nil end
  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    cardCanvas(side, logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.LAYOUT[side]
  local mon = battler.mon
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()
  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    -- Draw the exact same logical HUD at a denser raster resolution. Nothing
    -- below this line needs new coordinates: one logical pixel simply occupies
    -- `raster` texture pixels while this offscreen capture is being made.
    g.scale(raster, raster)
    g.translate(pad, pad)

    if hudStyle() ~= "float" then
      drawCompactStatusCard(battle, side, battler, k, logicalW, logicalH)
    else

    -- Structural shadow first. Keep the same global growth treatment as every
    -- other authored HUD asset, but do not draw the white plate yet because HP/EXP
    -- fills still have to land underneath it.
    local theme = hudTheme()
    g.setColor(theme.shadow[1], theme.shadow[2], theme.shadow[3], 1)
    eachShadowOffset(k, 1, function(sx, sy)
      g.draw(plate, sx, sy, 0,
             FloatingHud.ASSET_SCALE, FloatingHud.ASSET_SCALE)
    end)

    -- Dynamic fills remain behind the authored white support.
    local hp, maxHP = shownHP(battler)
    drawHPFill(layout, hp / maxHP)
    if side == "player" then
      drawEXPFill(layout, expRatio(battle, battler), hudExpChoice(battle))
    end

    g.setColor(theme.plate[1], theme.plate[2], theme.plate[3], 1)
    g.draw(plate, 0, 0, 0, FloatingHud.ASSET_SCALE, FloatingHud.ASSET_SCALE)

    local gender = genderSymbol(battle, mon)
    local nameRight = gender and layout.gender and (layout.gender.x - 3)
                      or (logicalW - 5)
    local name = fitText(battler.name or mon.species or "",
                         math.max(8, nameRight - layout.name.x))
    drawShadowText(name, layout.name.x, layout.name.y, k)
    if gender and layout.gender then
      drawGenderSymbol(gender, layout.gender.x, layout.gender.y, k)
    end
    drawStatus(mon, layout.status.x, layout.status.y, k)
    drawShadowText(tostring(mon.level or "?"), layout.level.x, layout.level.y, k,
                   layout.level.scale or 1)

    drawStatusMarkers(battle, side, battler, k,
                      logicalW - 5, layout.caught and layout.caught.y or 8)

    local hpText = tostring(hp) .. "/" .. tostring(maxHP)
    local hpX = layout.hpNumbers.right - textWidth(hpText)
    drawShadowText(hpText, hpX, layout.hpNumbers.y, k)

    if side == "enemy" and showWildDVs(battle, side, battler) then
      local text = dvText(mon)
      if text then
        local scale = layout.dvs.scale or 1
        local visualW = textWidth(text) * scale
        local x = (logicalW - visualW) / 2
        drawShadowText(text, x, layout.dvs.y, k, scale)
      end
    end

    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH, pad
end

-- Message/command planes use the same supersampled intermediate-canvas strategy
-- as the Pokemon plates, but keep their own cache because their aspect ratios
-- and content are unrelated to either battler.

local partyIconImages = {}

local function partyIconImage(species)
  species = tostring(species or "")
  if species == "" then return nil end
  if partyIconImages[species] ~= nil then return partyIconImages[species] or nil end
  local path = PKMN_ICON_FOLDER .. species .. ".png"
  local ok, img = pcall(function() return mod.assets:image(path) end)
  if ok and img then
    pcall(img.setFilter, img, "nearest", "nearest")
    partyIconImages[species] = img
    return img
  end
  partyIconImages[species] = false
  return nil
end

function FloatingHud.crystalPartyIcon(mon, battle, menu)
  local data = battle and battle.data
            or (battle and battle.game and battle.game.data)
            or (menu and menu.game and menu.game.data)
  local def = data and data.pokemon and mon and data.pokemon[mon.species]
  local dex = def and math.floor(tonumber(def.dex) or 0) or 0
  if dex < 1 or dex > 251 then return nil end
  local folder = INTEGRATED_KASC and "assets/crystal_menu_icons/"
                                   or "assets/hud/crystal_menu_icons/"
  return assetImage((folder .. "%03d.png"):format(dex))
end

-- Extended species are intentionally not painted as invented Crystal art.
-- Resolve the ordinary front/Dex sprite through the engine's live sprite seam
-- so KASC and other species providers can supply their registered fallback.
function FloatingHud.standardPartySprite(mon, battle, menu)
  local data = battle and battle.data
            or (battle and battle.game and battle.game.data)
            or (menu and menu.game and menu.game.data)
  if not (data and mon and mon.species) then return nil end
  local okSprites, Sprites = pcall(require, "src.pokemon.Sprites")
  local okAssets, Assets = pcall(require, "src.render.Assets")
  if not (okSprites and Sprites and type(Sprites.path) == "function"
      and okAssets and Assets and type(Assets.resolve) == "function") then
    return nil
  end
  local okPath, path = pcall(
    Sprites.path, data, mon.species, "front", { mon=mon, kind="dex" })
  if not (okPath and type(path) == "string" and path ~= "") then return nil end
  local key = "dex:" .. path
  if partyIconImages[key] ~= nil then return partyIconImages[key] or nil end
  local okImage, image = pcall(function()
    return g.newImage(Assets.resolve(path))
  end)
  if okImage and image then
    pcall(image.setFilter, image, "nearest", "nearest")
    partyIconImages[key] = image
    return image
  end
  partyIconImages[key] = false
  return nil
end

-- Keep the numerous stack/touch helpers behind one private table. LuaJIT 2.1
-- gives each function a hard 200-local-variable ceiling; declaring every
-- helper as another factory-scope local made this otherwise valid module stop
-- compiling as the integrated HUD grew. Table fields preserve the same
-- closures and call sites while consuming one factory local instead of one
-- slot per helper.
local HudRuntime = {}

function HudRuntime.battleStateInStack(game)
  local states = game and game.stack and game.stack.states
  if not states then return nil end
  for i = #states, 1, -1 do
    local state = states[i]
    if getmetatable(state) == BattleState
        or (state and state.game == game and state.player and state.enemy
            and state.phase ~= nil) then
      return state
    end
  end
  return nil
end

function HudRuntime.stateInStack(game, wanted)
  local states = game and game.stack and game.stack.states
  if not (states and wanted) then return false end
  for i = #states, 1, -1 do
    if states[i] == wanted then return true end
  end
  return false
end

function HudRuntime.topState(game)
  local stack = game and game.stack
  if not stack then return nil end
  if type(stack.top) == "function" then
    local ok, value = pcall(stack.top, stack)
    if ok and value ~= nil then return value end
  end
  local states = stack.states
  return states and states[#states] or nil
end

function HudRuntime.isTextBoxState(state)
  return state and (state.isTextBox == true
    or (type(state.visibleText) == "function"
        and type(state.shown) == "table"
        and state.pageIndex ~= nil))
end

function HudRuntime.moveLearnTextBoxInStack(game)
  local states = game and game.stack and game.stack.states
  if not states then return nil end
  for i = #states, 1, -1 do
    local state = states[i]
    if state and state.__floatingBattleMoveLearnText then return state end
  end
  return nil
end

-- AskName is another pushed TextBox + ChoiceBox flow, but unlike move learning
-- the stock battle intentionally blanks the whole field while it is active.
-- Keep a semantic marker on the concrete TextBox so we can leave the staged
-- battlefield visible and render that exact native text through our message plate.
function HudRuntime.nicknameTextBoxInStack(game)
  local states = game and game.stack and game.stack.states
  if not states then return nil end
  for i = #states, 1, -1 do
    local state = states[i]
    if state and state.__floatingBattleNicknameText then return state end
  end
  return nil
end

function HudRuntime.nicknameOverlayActiveForBattle(battle)
  if not battle then return false end
  local text = battle._floatingBattleNicknameText
  if text and HudRuntime.stateInStack(battle.game, text) then return true end
  if text then battle._floatingBattleNicknameText = nil end
  return false
end

function HudRuntime.moveLearnOverlayActiveForBattle(battle)
  if not battle then return false end
  local game = battle.game
  local menu = battle._floatingBattleMoveLearnMenu
  if menu and HudRuntime.stateInStack(game, menu) then return true end
  if menu then battle._floatingBattleMoveLearnMenu = nil end

  local text = battle._floatingBattleMoveLearnText
  if text and HudRuntime.stateInStack(game, text) then return true end
  if text then battle._floatingBattleMoveLearnText = nil end
  return false
end

function HudRuntime.partyOverlayActiveForBattle(battle)
  local menu = battle and battle._floatingBattlePartyMenu
  if not menu then return false end
  if HudRuntime.stateInStack(menu.game or battle.game, menu) then return true end
  battle._floatingBattlePartyMenu = nil
  return false
end

local panelCanvases = {}

local function panelCanvas(key, logicalW, logicalH, topExtra)
  local pad = FloatingHud.CANVAS_PAD or 0
  topExtra = math.max(0, tonumber(topExtra) or 0)
  local raster = math.max(1, tonumber(FloatingHud.CANVAS_RENDER_SCALE) or 1)
  local logicalCW = logicalW + pad * 2
  local logicalCH = logicalH + pad * 2 + topExtra
  local cw = math.ceil(logicalCW * raster)
  local ch = math.ceil(logicalCH * raster)
  local canvas = panelCanvases[key]

  if not canvas or canvas:getWidth() ~= cw or canvas:getHeight() ~= ch then
    local ok, made = pcall(g.newCanvas, cw, ch, { dpiscale = 1 })
    if not (ok and made) then return nil end
    pcall(made.setFilter, made, "linear", "linear")
    canvas = made
    panelCanvases[key] = canvas
  end

  return canvas, cw, ch, pad, raster, logicalCW, logicalCH
end

function FloatingHud.drawAdaptiveMessageSurface(battle, logicalW, logicalH, k)
  if hudStyle() == "float" then return false end
  local theme = hudTheme()
  local lowHp = battle and battle.player and battle.player.mon
    and (tonumber(battle.player.mon.hp) or 0)
       / math.max(1, tonumber(battle.player.mon.stats
         and battle.player.mon.stats.hp) or 1) <= 0.20
  local accent = lowHp and { 1.00, 0.28, 0.22 } or theme.accent
  local panel = { 0.01, 0.05, 0.08, 0.76 }
  local x, y, width, height = 1, 1, logicalW - 2, logicalH - 2
  local glass = FloatingHud.textGlassStrength()

  g.setColor(0, 0, 0, 0.56 * glass)
  g.rectangle("fill", x + 2, y + 2, width, height, 5, 5)
  g.setColor(panel[1], panel[2], panel[3], panel[4] * glass)
  g.rectangle("fill", x, y, width, height, 5, 5)
  g.setColor(1, 1, 1, 0.18)
  g.line(x + 7, y + 3, x + width - 7, y + 3)
  if lowHp then
    g.setColor(accent[1], accent[2], accent[3], 0.88)
    g.line(x + 9, y + 5, x + width - 9, y + 5)
  end
  drawEditionCardBorder("message", x, y, width, height, 5, 1)
  return true
end

function FloatingHud.drawMessageLine(text, x, y, k)
  drawShadowText(text, x, y, k,
                 tonumber(FloatingHud.MESSAGE.textScale) or 1)
end

-- Public and side-effect-free for visual QA. The caller supplies only rows the
-- engine has already revealed; no BattleState/TextBox field can be advanced or
-- rewritten here.
function FloatingHud.layoutMessageLines(lines, logicalW, logicalH)
  local layout = FloatingHud.MESSAGE
  return Bundle.MessageLayout.layout(Font, lines, {
    logicalWidth=logicalW, logicalHeight=logicalH,
    textX=layout.textX or 10,
    rightPadding=layout.textRightPadding or 24,
    top=layout.textTop or 7, bottom=layout.textBottom or 7,
    lineGap=layout.textLineGap or 2,
    line1Y=layout.line1Y or 9, line2Y=layout.line2Y or 27,
    textScale=layout.textScale or 1,
    minScale=layout.textMinScale or 0.72,
  })
end

local function drawMessageLayout(visual, k)
  if not (visual and visual.complete) then return false end
  for _, line in ipairs(visual.lines) do
    drawShadowText(line.text, line.x, line.y, k, line.scale)
  end
  return true
end

local function renderMessageCanvas(battle, k, logicalW, logicalH)
  local plate = assetImage(MESSAGE_PLATE_ASSET)
  if hudStyle() == "float" and not plate then return nil end
  if hudStyle() ~= "float" and not FloatingHud.commandAssetsReady() then return nil end

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("message", logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.MESSAGE
  local lines = visibleBattleMessageLines(battle)
  -- Resolve the complete visual layout before touching the canvas/transform
  -- stack. An impossible page therefore fails open without leaking g.push().
  local visual = FloatingHud.layoutMessageLines(lines, logicalW, logicalH)
  if not (visual and visual.complete) then return nil end
  local cursor = assetImage(MESSAGE_CURSOR_ASSET)
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if not FloatingHud.drawAdaptiveMessageSurface(battle, logicalW, logicalH, k) then
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
    end

    drawMessageLayout(visual, k)

    -- Match the original wait prompt: blink only while the engine is waiting
    -- for acknowledgement. If the tiny authored cursor ever fails to load, the
    -- message remains perfectly usable; only the cosmetic marker disappears.
    local waiting = battle.msgWaiting or battle.msgPrompt
    if waiting and cursor and ((tonumber(battle.frame) or 0) % 60 < 30) then
      local cursorW, cursorH = assetLogicalSize(MESSAGE_CURSOR_ASSET)
      if cursorW and cursorH then
        local x = logicalW - cursorW - (layout.cursorRight or 9)
        local y = logicalH - cursorH - (layout.cursorBottom or 6)
        drawShadowAsset(cursor, x, y, k, FloatingHud.ASSET_SCALE)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end


local function renderMoveLearnMessageCanvas(box, k, logicalW, logicalH)
  local plate = assetImage(MESSAGE_PLATE_ASSET)
  if not box then return nil end
  if hudStyle() == "float" and not plate then return nil end
  if hudStyle() ~= "float" and not FloatingHud.commandAssetsReady() then return nil end

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("learn_message", logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.MESSAGE
  local lines = visibleTextBoxMessageLines(box)
  -- Same preflight as ordinary battle text: MoveLearn/catch/nickname share the
  -- visual plane but retain their native TextBox state machine.
  local visual = FloatingHud.layoutMessageLines(lines, logicalW, logicalH)
  if not (visual and visual.complete) then return nil end
  local cursor = assetImage(MESSAGE_CURSOR_ASSET)
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if not FloatingHud.drawAdaptiveMessageSurface(nil, logicalW, logicalH, k) then
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
    end
    drawMessageLayout(visual, k)

    -- Mirror TextBox's own more-arrow condition. Choice prompts do not need the
    -- arrow: as soon as the page completes, their YES/NO surface owns attention.
    local waiting = box.waiting
      or (box.done and not box.choice and not box.auto and not box.stay)
    if waiting and cursor and ((tonumber(box.blink) or 0) % 60 < 30) then
      local cursorW, cursorH = assetLogicalSize(MESSAGE_CURSOR_ASSET)
      if cursorW and cursorH then
        local x = logicalW - cursorW - (layout.cursorRight or 9)
        local y = logicalH - cursorH - (layout.cursorBottom or 6)
        drawShadowAsset(cursor, x, y, k, FloatingHud.ASSET_SCALE)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end

local function renderChoiceCanvas(choice, k)
  if not choice then return nil end
  local layout = FloatingHud.CHOICE
  local style = hudStyle()
  local logicalW = style == "oras" and 112 or layout.logicalW or 48
  local logicalH = style ~= "float" and 30 or layout.logicalH or 18
  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("choice", logicalW, logicalH)
  if not canvas then return nil end

  local selected = clamp(math.floor(tonumber(choice.index) or 1), 1, 2)
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if style ~= "float" then
      FloatingHud.drawStyleSurface("choice", logicalW, logicalH, k)
      local labels = hudLanguage() == "de" and { "JA", "NEIN" }
                                           or { "YES", "NO" }
      local half = (logicalW - 8) * 0.5
      for i = 1, 2 do
        local x = 4 + (i - 1) * half
        if i == selected then
          if style == "oras" then
            g.setColor(0.22, 0.86, 1.00, 0.34)
          else
            g.setColor(0.82, 0.88, 0.66, 1)
          end
          g.rectangle("fill", x + 2, 5, half - 4, 19, 5, 5)
          g.setColor(style == "oras" and 1 or 0.45,
                     style == "oras" and 1 or 0.18,
                     style == "oras" and 1 or 0.22, 0.95)
          g.rectangle("line", x + 2, 5, half - 4, 19, 5, 5)
        end
        local width = textWidth(labels[i]) * 0.82
        drawShadowText(labels[i], x + half * 0.5 - width * 0.5, 10, k, 0.82)
      end
    else
      local yesScale = selected == 1
        and (layout.selectedScale or 1.28) or (layout.idleScale or 0.82)
      local noScale = selected == 2
        and (layout.selectedScale or 1.28) or (layout.idleScale or 0.82)

      local function drawCenteredChoice(label, cx, cy, scale)
        local w = textWidth(label) * scale
        local h = 8 * scale
        drawShadowText(label, cx - w * 0.5, cy - h * 0.5, k, scale)
      end

      local centerX = layout.centerX or (logicalW * 0.5)
      drawCenteredChoice("YES", centerX, layout.yesCenterY or 15, yesScale)
      drawCenteredChoice("NO",  centerX, layout.noCenterY or 40, noScale)
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH, logicalW, logicalH
end

-- PartyMenu does not push a ChoiceBox for voluntary battle switching. Instead it
-- flips `menu.submenu` and keeps SWITCH / STATS / CANCEL in `menu.subItems`, with
-- `menu.subIndex` as the live native cursor. Because we hide PartyMenu's own pixels,
-- that submenu used to exist logically but had no replacement drawing at all.
local function renderPartyChoiceCanvas(menu, k)
  if not (menu and menu.submenu and type(menu.subItems) == "table"
      and #menu.subItems > 0) then return nil end

  local layout = FloatingHud.PARTY_CHOICE or FloatingHud.CHOICE
  local count = #menu.subItems
  local selectedScale = layout.selectedScale or 1.65
  local idleScale = layout.idleScale or 1.05
  local firstY = layout.firstCenterY or 14
  local rowStep = layout.rowStep or 25

  -- Native battle currently supplies exactly three rows, but size from the live
  -- list so a ui.party.submenu hook cannot create an invisible extra option.
  local maxTextW = 0
  for i = 1, count do
    local entry = menu.subItems[i]
    local label = tostring((entry and entry.label) or "")
    maxTextW = math.max(maxTextW, textWidth(label) * selectedScale)
  end
  local logicalW = math.max(layout.logicalW or 96, maxTextW + 12)
  local lastY = firstY + (count - 1) * rowStep
  local logicalH = math.max(layout.logicalH or 78, lastY + 14)

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("party_choice", logicalW, logicalH)
  if not canvas then return nil end

  local selected = clamp(math.floor(tonumber(menu.subIndex) or 1), 1, count)
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    local centerX = layout.centerX or (logicalW * 0.5)
    -- If logicalW had to grow for a hook-added long label, keep the list centered
    -- in the actual plane rather than at the original authored width's midpoint.
    if logicalW ~= (layout.logicalW or 96) then centerX = logicalW * 0.5 end

    for i = 1, count do
      local entry = menu.subItems[i]
      local label = tostring((entry and entry.label) or "")
      local scale = i == selected and selectedScale or idleScale
      local cy = firstY + (i - 1) * rowStep
      local w = textWidth(label) * scale
      local h = 8 * scale
      drawShadowText(label, centerX - w * 0.5, cy - h * 0.5, k, scale)
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH, logicalW, logicalH
end


function FloatingHud.commandAssetMetrics(image, logicalW, logicalH,
                                         maxW, maxH, controlScale,
                                         designW, designH)
  if not image then return nil end
  local sourceW, sourceH = image:getWidth(), image:getHeight()
  designW = math.max(1, tonumber(designW) or sourceW)
  designH = math.max(1, tonumber(designH) or sourceH)
  local baseScale = math.min(
    (logicalW * maxW * (controlScale or 1)) / designW,
    (logicalH * maxH) / designH)
  return {
    baseScale=baseScale,
    layoutW=designW * baseScale,
    layoutH=designH * baseScale,
  }
end

function FloatingHud.orasCommandLayout(battle, logicalW, logicalH)
  local selected = clamp(math.floor(tonumber(battle.menuIndex) or 1), 1, 4)
      local rowEntries = {
        { index=3, key="bag",     maxW=0.18, maxH=0.32 },
        { index=2, key="pokemon", maxW=0.18, maxH=0.32 },
        { index=4, key="run",     maxW=0.16, maxH=0.30 },
      }
      local fightEntry = {
        index=1, key="fight", maxW=0.30, maxH=0.32,
      }
      local profile = megaProfileFor(battle, battle.player, "player")
      if profile then
        table.insert(rowEntries, 2, {
          key="mega", maxW=0.16, maxH=0.36, mega=true,
        })
      end
      local megaFocused = profile
        and battle._ascendantBattleHudMegaFocus == true
      local megaArmed = profile and FloatingHud.megaArmed(battle)
      local frame = tonumber(battle.frame) or 0
      local controlScale = FloatingHud.CONTROL_SCALE or 1
      local rowGap = clamp(logicalW * 0.025, 5, 9)
      local rowWidth, rowTop, visibleCount = 0, logicalH, 0
      for _, entry in ipairs(rowEntries) do
        entry.image = FloatingHud.styleAsset(entry.key)
        if entry.image then
          entry.baseScale = math.min(
            (logicalW * entry.maxW * controlScale) / entry.image:getWidth(),
            (logicalH * entry.maxH) / entry.image:getHeight())
          entry.layoutW = entry.image:getWidth() * entry.baseScale
          entry.layoutH = entry.image:getHeight() * entry.baseScale
          rowWidth = rowWidth + entry.layoutW + rowGap
          rowTop = math.min(rowTop, logicalH - entry.layoutH)
          visibleCount = visibleCount + 1
        end
      end
      rowWidth = math.max(0, rowWidth - rowGap)
      -- Request the full 150% size first, then shrink every secondary action
      -- by one shared factor only when four icons cannot fit a narrow phone.
      -- This preserves their relative proportions and never stretches art.
      local rowContentW = math.max(1,
        rowWidth - math.max(0, visibleCount - 1) * rowGap)
      local rowFit = math.min(1,
        math.max(0.35,
          (logicalW - 8 - math.max(0, visibleCount - 1) * rowGap)
          / rowContentW))
      rowWidth, rowTop = 0, logicalH
      for _, entry in ipairs(rowEntries) do
        if entry.image then
          entry.baseScale = entry.baseScale * rowFit
          entry.layoutW = entry.image:getWidth() * entry.baseScale
          entry.layoutH = entry.image:getHeight() * entry.baseScale
          rowWidth = rowWidth + entry.layoutW + rowGap
          rowTop = math.min(rowTop, logicalH - entry.layoutH)
        end
      end
      rowWidth = math.max(0, rowWidth - rowGap)
      local rowX = (logicalW - rowWidth) * 0.5
      for _, entry in ipairs(rowEntries) do
        if entry.image then
          entry.focused = entry.mega and megaFocused
                       or (entry.index == selected and not megaFocused)
          local pulse = entry.focused
            and (0.96 + 0.04 * math.sin(frame * 0.12)) or 1
          entry.scale = entry.baseScale * pulse
          entry.width = entry.image:getWidth() * entry.scale
          entry.height = entry.image:getHeight() * entry.scale
          entry.layoutX = rowX
          entry.x = entry.layoutX + (entry.layoutW - entry.width) * 0.5
          entry.y = logicalH - entry.height
          rowX = rowX + entry.layoutW + rowGap
        end
      end

      fightEntry.image = FloatingHud.styleAsset("fight")
      local actionGap = clamp(logicalW * 0.012, 2, 5)
      if fightEntry.image then
        local metrics = FloatingHud.commandAssetMetrics(
          fightEntry.image, logicalW, logicalH,
          fightEntry.maxW, fightEntry.maxH, controlScale,
          FloatingHud.ORAS_FIGHT_DESIGN_W,
          FloatingHud.ORAS_FIGHT_DESIGN_H)
        fightEntry.baseScale = metrics.baseScale
        fightEntry.layoutW = metrics.layoutW
        fightEntry.layoutH = metrics.layoutH
        fightEntry.focused = selected == 1 and not megaFocused
        local pulse = fightEntry.focused
          and (0.96 + 0.04 * math.sin(frame * 0.12)) or 1
        fightEntry.scale = fightEntry.baseScale * pulse
        fightEntry.width = fightEntry.image:getWidth() * fightEntry.scale
        fightEntry.height = fightEntry.image:getHeight() * fightEntry.scale
        fightEntry.layoutX = logicalW * 0.5 - fightEntry.layoutW * 0.5
        fightEntry.layoutY = math.max(2,
          rowTop - fightEntry.layoutH - actionGap)
        fightEntry.x = fightEntry.layoutX
          + (fightEntry.layoutW - fightEntry.width) * 0.5
        fightEntry.y = fightEntry.layoutY
          + (fightEntry.layoutH - fightEntry.height) * 0.5
      end

      local entries = { fightEntry }
      for _, entry in ipairs(rowEntries) do entries[#entries + 1] = entry end
  return rowEntries, fightEntry, entries, rowTop, actionGap, megaArmed, frame
end

function FloatingHud.orasCommandBounds(battle, rect, scale, logicalW, logicalH)
  local _, _, entries = FloatingHud.orasCommandLayout(battle, logicalW, logicalH)
  local bounds = {}
  for _, entry in ipairs(entries) do
    if entry.image and entry.layoutX then
      local x = entry.layoutX
      local y = entry.layoutY or (logicalH - entry.layoutH)
      -- Include the largest focus/MEGA glow, not the transparent dock canvas.
      local marginX = entry.layoutW * .13 + 2
      local marginY = entry.layoutH * .24 + 2
      local top = math.max(0, y - marginY)
      local bottom = math.min(logicalH, y + entry.layoutH + marginY)
      bounds[#bounds+1] = {rect[1]+(x-marginX)*scale,
        rect[2]+top*scale, (entry.layoutW+marginX*2)*scale,
        (bottom-top)*scale}
      if entry.focused then
        local cx = entry.x + entry.width*.5
        local cursorTop = entry.y - 18
        bounds[#bounds+1] = {rect[1]+(cx-8)*scale,
          rect[2]+cursorTop*scale, 16*scale, 20*scale}
      end
    end
  end
  return bounds
end

local function renderCommandCanvas(battle, k, logicalW, logicalH)
  local style = hudStyle()
  local plate = assetImage(COMMAND_PLATE_ASSET)
  local selector = assetImage(COMMAND_SELECTOR_ASSET)
  if style == "float" and not (plate and selector) then return nil end
  if style ~= "float" and not FloatingHud.commandAssetsReady() then return nil end

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("command", logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.COMMAND
  local labels = battle.safari
    and { "BALL", "BAIT", "ROCK", "RUN" }
     or hudLanguage() == "de"
       and { "KAMPF", "PKMN", "BEUTEL", "FLUCHT" }
        or { "FIGHT", "PKMN", "ITEM", "RUN" }
  if battle.safari and hudLanguage() == "de" then
    labels = { "BALL", "KÖDER", "STEIN", "FLUCHT" }
  end
  local selected = clamp(math.floor(tonumber(battle.menuIndex) or 1), 1, 4)
  battle._ascendantBattleHudCommandLogicalHits = nil
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if style == "oras" and battle.safari then
      -- Safari is a real four-action battle menu, but it has no acting player
      -- battler and therefore cannot reuse FIGHT/PKMN/ITEM icon semantics.
      -- Keep the ORAS glass language while rendering its native BALL / BAIT /
      -- ROCK / RUN actions as explicit cards. Input remains the engine's
      -- menuIndex, so this is presentation-only and preserves Safari logic.
      FloatingHud.drawStyleSurface("command", logicalW, logicalH, k)
      local gap = 6
      local marginX, marginY = 8, 7
      local cardW = (logicalW - marginX * 2 - gap) * 0.5
      local cardH = (logicalH - marginY * 2 - gap) * 0.5
      local commandHits = {}
      local cursorX, cursorY = logicalW * 0.5, logicalH * 0.5
      for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = marginX + col * (cardW + gap)
        local y = marginY + row * (cardH + gap)
        local focused = i == selected
        local pulse = 0.5 + 0.5 * math.sin((battle.frame or 0) * 0.12)
        g.setColor(0.012, 0.038, 0.055, 0.95)
        g.rectangle("fill", x, y, cardW, cardH, 7, 7)
        g.setColor(0.22, 0.86, 1.00,
          focused and (0.28 + pulse * 0.16) or 0.12)
        g.rectangle("fill", x + 2, y + 2, cardW - 4, cardH - 4, 6, 6)
        g.setColor(focused and 1 or 0.28,
                   focused and 1 or 0.88,
                   1, focused and 0.98 or 0.78)
        g.setLineWidth(focused and 2 or 1)
        g.rectangle("line", x, y, cardW, cardH, 7, 7)
        g.setLineWidth(1)
        drawShadowTextCentered(labels[i], x + cardW * 0.5,
                               y + cardH * 0.5 - 4, k, 0.82)
        commandHits[#commandHits + 1] = {
          action="command", index=i, x=x, y=y, w=cardW, h=cardH,
        }
        if focused then cursorX, cursorY = x + cardW * 0.5, y end
      end
      battle._ascendantBattleHudCommandLogicalHits = commandHits
      FloatingHud.drawHandCursor(cursorX, cursorY, 0.82, battle.frame)
    elseif style == "oras" then
      -- No enclosing dock. Measure the actual localized sprites, flow the
      -- secondary actions into one compact centred row, then place FIGHT just
      -- above that row. Neither ultrawide nor phone canvases can stretch the
      -- spaces because the gaps have fixed responsive bounds.
      local rowEntries, fightEntry, entries, rowTop, actionGap, megaArmed, frame =
        FloatingHud.orasCommandLayout(battle, logicalW, logicalH)
      local commandHits = {}
      -- Split the visual gap at one shared boundary. FIGHT owns the upper half
      -- and every lower-row action owns the lower half, so padded touch targets
      -- remain generous without one action stealing another action's edge.
      local rowHitTop = rowTop - actionGap * 0.5
      if fightEntry.image and fightEntry.x and fightEntry.y then
        commandHits[#commandHits + 1] = {
          action="command", index=1,
          x=fightEntry.layoutX, y=fightEntry.layoutY - 3,
          w=fightEntry.layoutW,
          h=math.max(1, rowHitTop - (fightEntry.layoutY - 3)),
        }
      end
      for _, entry in ipairs(rowEntries) do
        if entry.image and entry.layoutX then
          commandHits[#commandHits + 1] = {
            action=entry.mega and "command_mega" or "command",
            index=entry.index,
            x=entry.layoutX, y=rowHitTop,
            w=entry.layoutW, h=logicalH - rowHitTop,
          }
        end
      end
      battle._ascendantBattleHudCommandLogicalHits = commandHits
      local cursorX, cursorY = logicalW * 0.5, logicalH * 0.5
      for _, entry in ipairs(entries) do
        if entry.image and entry.x and entry.y then
          local focused = entry.focused == true
          if entry.mega then
            if megaArmed then
              local activePulse = 0.5 + 0.5 * math.sin(frame * 0.13)
              g.setBlendMode("add")
              g.setColor(1.00, 0.20, 0.78, 0.18 + activePulse * 0.12)
              g.ellipse("fill", entry.x + entry.width * 0.5,
                        entry.y + entry.height * 0.57,
                        entry.width * 0.62, entry.height * 0.66)
              g.setBlendMode("alpha")
              g.setColor(0.98, 0.56, 1.00, 0.96)
              g.setLineWidth(1.5)
              g.ellipse("line", entry.x + entry.width * 0.5,
                        entry.y + entry.height * 0.57,
                        entry.width * 0.55, entry.height * 0.57)
              g.setLineWidth(1)
            else
              g.setColor(0.02, 0.06, 0.08, 0.52)
              g.ellipse("fill", entry.x + entry.width * 0.5,
                        entry.y + entry.height * 0.58,
                        entry.width * 0.52, entry.height * 0.54)
            end
          end
          if focused then
            local focus = 0.5 + 0.5 * math.sin(frame * 0.10)
            g.setColor(0.22, 0.86, 1.00, 0.12 + focus * 0.18)
            g.ellipse("fill", entry.x + entry.width * 0.5,
                      entry.y + entry.height * 0.62,
                      entry.width * 0.54, entry.height * 0.58)
            cursorX, cursorY = entry.x + entry.width * 0.5, entry.y
          end
          FloatingHud.drawColoredAsset(entry.image, entry.x, entry.y, entry.scale,
                                       entry.mega and (megaArmed and 1 or 0.74) or 1)
          if entry.mega then
            local badge = megaArmed
              and (hudLanguage() == "de" and "AN" or "ON")
              or (hudLanguage() == "de" and "AUS" or "OFF")
            local badgeScale = 0.48
            local badgeW = textWidth(badge) * badgeScale + 6
            local badgeX = entry.x + entry.width - badgeW
            local badgeY = entry.y + 1
            g.setColor(megaArmed and 0.70 or 0.08,
                       megaArmed and 0.08 or 0.13,
                       megaArmed and 0.58 or 0.16, 0.94)
            g.rectangle("fill", badgeX, badgeY, badgeW, 8, 4, 4)
            g.setColor(1, 1, 1, 0.96)
            drawShadowTextCentered(badge, badgeX + badgeW * 0.5,
                                   badgeY + 1, k, badgeScale)
          end
        end
      end
      FloatingHud.drawHandCursor(cursorX, cursorY, 0.82, battle.frame)
    else
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
      for i = 1, 4 do
        local y = (layout.firstY or 13) + (i - 1) * (layout.rowStep or 22)
        if i == selected then
          drawShadowAsset(selector,
                          layout.selectorX or 9,
                          y + (layout.selectorYOffset or -1),
                          k, FloatingHud.ASSET_SCALE)
        end
        drawShadowText(labels[i] or "", layout.textX or 20, y, k)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end

local SPECIAL_MOVE_TYPES = {
  FIRE = true,
  WATER = true,
  GRASS = true,
  ELECTRIC = true,
  ICE = true,
  PSYCHIC = true,
  DRAGON = true,
}

local function moveMaxPPValues(battle, move)
  local def = moveDefinition(battle, move)
  local cur = type(move) == "table"
    and (tonumber(move.pp) or tonumber(move.currentPP) or tonumber(move.currentPp))
    or nil
  local maxpp = type(move) == "table"
    and (tonumber(move.maxPP) or tonumber(move.maxPp))
    or nil
  if maxpp == nil then maxpp = def and tonumber(def.pp) or cur or 0 end
  if cur == nil then cur = maxpp or 0 end
  return math.max(0, math.floor((cur or 0) + 0.5)),
         math.max(0, math.floor((maxpp or 0) + 0.5))
end

-- Gen1Recomp builds its vanilla move records directly from the ROM, so those
-- records intentionally contain mechanics (effect/power/type/accuracy/PP) but
-- no prose description. Keep authored/custom descriptions first, then provide a
-- compact RBY fallback using Smogon's RB move wording/semantics.
local SMOGON_RB_MOVE_DESCRIPTIONS = {
  BIDE = "Waits 2-3 turns; deals double the damage taken.",
  CONVERSION = "User becomes the same type as the target.",
  FOCUS_ENERGY = "Quarters the user's chance for a critical hit.",
  HAZE = "Resets all stat changes. Removes foe's status.",
  LIGHT_SCREEN = "While active, user's Special is 2x when damaged.",
  MIRROR_MOVE = "User uses the target's last used move against it.",
  MIST = "While active, user is protected from stat drops.",
  REFLECT = "While active, the user's Defense is doubled.",
  REST = "User sleeps 2 turns and restores HP and status.",
  SPLASH = "No competitive use.",
  SUBSTITUTE = "User takes 1/4 its max HP to put in a Substitute.",
  TOXIC = "Badly poisons the target.",
  SWIFT = "Never misses, even against Dig and Fly.",
  TRANSFORM = "Copies target's stats, moves, types, and species.",

  COUNTER = "If hit by Normal/Fighting move, deals 2x damage.",
  DRAGON_RAGE = "Deals 40 HP of damage to the target.",
  NIGHT_SHADE = "Damage = user's level. Can hit Normal types.",
  PSYWAVE = "Random damage from 1 to (user's level*1.5 - 1).",
  SEISMIC_TOSS = "Damage = user's level. Can hit Ghost types.",
  SONICBOOM = "Deals 20 HP of damage to the target.",
  SUPER_FANG = "Deals damage equal to half the target's current HP.",

  DOUBLE_KICK = "Hits 2 times.",
  TWINEEDLE = "Hits 2 times. Last hit has 20% chance to poison.",
  FLY = "Flies up on first turn, attacks on second.",
  DIG = "Digs underground turn 1, strikes turn 2.",
  RAZOR_WIND = "Charges turn 1. Hits turn 2.",
  SKULL_BASH = "Charges turn 1. Hits turn 2.",
  SOLARBEAM = "Charges turn 1. Hits turn 2.",

  HYPER_BEAM = "Can't move next turn if target or sub is not KOed.",
  RAGE = "Lasts forever. Raises user's Attack by 1 when hit.",
  MIMIC = "Random move known by the target replaces this.",
  METRONOME = "Picks a random move.",
  LEECH_SEED = "1/16 of target's HP is restored to user every turn.",
  DISABLE = "For 0-7 turns, disables one of the target's moves.",
  DREAM_EATER = "User gains 1/2 HP inflicted. Sleeping target only.",
  PAY_DAY = "Scatters coins.",
  ROAR = "In battles, the opponent switches. In the wild, the Pokémon runs.",
  TELEPORT = "No competitive use.",
  WHIRLWIND = "No competitive use.",
}

local SMOGON_RB_EFFECT_DESCRIPTIONS = {
  DRAIN_HP_EFFECT = "User recovers 50% of the damage dealt.",
  BURN_SIDE_EFFECT1 = "10% chance to burn the target.",
  FREEZE_SIDE_EFFECT1 = "10% chance to freeze the target.",
  PARALYZE_SIDE_EFFECT1 = "10% chance to paralyze the target.",
  POISON_SIDE_EFFECT1 = "20% chance to poison the target.",
  EXPLODE_EFFECT = "Target's Def halved during damage. User faints.",
  DREAM_EATER_EFFECT = "User gains 1/2 HP inflicted. Sleeping target only.",
  MIRROR_MOVE_EFFECT = "User uses the target's last used move against it.",

  ATTACK_UP1_EFFECT = "Raises the user's Attack by 1.",
  DEFENSE_UP1_EFFECT = "Raises the user's Defense by 1.",
  SPEED_UP1_EFFECT = "Raises the user's Speed by 1.",
  SPECIAL_UP1_EFFECT = "Raises the user's Special by 1.",
  ACCURACY_UP1_EFFECT = "Raises the user's accuracy by 1.",
  EVASION_UP1_EFFECT = "Raises the user's evasiveness by 1.",
  ATTACK_DOWN1_EFFECT = "Lowers the target's Attack by 1.",
  DEFENSE_DOWN1_EFFECT = "Lowers the target's Defense by 1.",
  SPEED_DOWN1_EFFECT = "Lowers the target's Speed by 1.",
  SPECIAL_DOWN1_EFFECT = "Lowers the target's Special by 1.",
  ACCURACY_DOWN1_EFFECT = "Lowers the target's accuracy by 1.",
  EVASION_DOWN1_EFFECT = "Lowers the target's evasiveness by 1.",

  ATTACK_UP2_EFFECT = "Raises the user's Attack by 2.",
  DEFENSE_UP2_EFFECT = "Raises the user's Defense by 2.",
  SPEED_UP2_EFFECT = "Raises the user's Speed by 2.",
  SPECIAL_UP2_EFFECT = "Raises the user's Special by 2.",
  ACCURACY_UP2_EFFECT = "Raises the user's accuracy by 2.",
  EVASION_UP2_EFFECT = "Raises the user's evasiveness by 2.",
  ATTACK_DOWN2_EFFECT = "Lowers the target's Attack by 2.",
  DEFENSE_DOWN2_EFFECT = "Lowers the target's Defense by 2.",
  SPEED_DOWN2_EFFECT = "Lowers the target's Speed by 2.",
  SPECIAL_DOWN2_EFFECT = "Lowers the target's Special by 2.",
  ACCURACY_DOWN2_EFFECT = "Lowers the target's accuracy by 2.",
  EVASION_DOWN2_EFFECT = "Lowers the target's evasiveness by 2.",

  BIDE_EFFECT = "Waits 2-3 turns; deals double the damage taken.",
  THRASH_PETAL_DANCE_EFFECT = "Lasts 3-4 turns. Confuses the user afterwards.",
  SWITCH_AND_TELEPORT_EFFECT = "No competitive use.",
  TWO_TO_FIVE_ATTACKS_EFFECT = "Hits 2-5 times in one turn.",
  FLINCH_SIDE_EFFECT1 = "10% chance to make the target flinch.",
  SLEEP_EFFECT = "Causes the target to fall asleep.",
  POISON_SIDE_EFFECT2 = "40% chance to poison the target.",
  BURN_SIDE_EFFECT2 = "30% chance to burn the target.",
  PARALYZE_SIDE_EFFECT2 = "30% chance to paralyze the target.",
  FLINCH_SIDE_EFFECT2 = "30% chance to make the target flinch.",
  OHKO_EFFECT = "Deals 65535 damage. Fails if target is faster.",
  CHARGE_EFFECT = "Charges turn 1. Hits turn 2.",
  TRAPPING_EFFECT = "Prevents the target from moving for 2-5 turns.",
  ATTACK_TWICE_EFFECT = "Hits 2 times.",
  JUMP_KICK_EFFECT = "User takes 1 HP of damage if it misses.",
  MIST_EFFECT = "While active, user is protected from stat drops.",
  FOCUS_ENERGY_EFFECT = "Quarters the user's chance for a critical hit.",
  RECOIL_EFFECT = "Has 1/4 recoil.",
  CONFUSION_EFFECT = "Confuses the target.",
  HEAL_EFFECT = "Heals the user by 50% of its max HP.",
  TRANSFORM_EFFECT = "Copies target's stats, moves, types, and species.",
  LIGHT_SCREEN_EFFECT = "While active, user's Special is 2x when damaged.",
  REFLECT_EFFECT = "While active, the user's Defense is doubled.",
  POISON_EFFECT = "Poisons the target.",
  PARALYZE_EFFECT = "Paralyzes the target.",
  ATTACK_DOWN_SIDE_EFFECT = "33% chance to lower the target's Attack by 1.",
  DEFENSE_DOWN_SIDE_EFFECT = "33% chance to lower the target's Defense by 1.",
  SPEED_DOWN_SIDE_EFFECT = "33% chance to lower the target's Speed by 1.",
  SPECIAL_DOWN_SIDE_EFFECT = "33% chance to lower the target's Special by 1.",
  CONFUSION_SIDE_EFFECT = "10% chance to confuse the target.",
  TWINEEDLE_EFFECT = "Hits 2 times. Last hit has 20% chance to poison.",
  SUBSTITUTE_EFFECT = "User takes 1/4 its max HP to put in a Substitute.",
  HYPER_BEAM_EFFECT = "Can't move next turn if target or sub is not KOed.",
  RAGE_EFFECT = "Lasts forever. Raises user's Attack by 1 when hit.",
  MIMIC_EFFECT = "Random move known by the target replaces this.",
  METRONOME_EFFECT = "Picks a random move.",
  LEECH_SEED_EFFECT = "1/16 of target's HP is restored to user every turn.",
  SPLASH_EFFECT = "No competitive use.",
  DISABLE_EFFECT = "For 0-7 turns, disables one of the target's moves.",
}

local function moveIdKey(move)
  local id = type(move) == "table" and (move.id or move.moveId or move.move) or move
  return tostring(id or ""):upper()
end

local function moveDescriptionText(battle, move)
  local def = moveDefinition(battle, move)
  local desc = def and (def.description or def.desc or def.shortDesc or def.effectDesc) or ""
  desc = tostring(desc or "")
  desc = desc:gsub("\r\n", "\n"):gsub("\r", "\n")
  desc = desc:gsub("%s*\n+%s*", " ")
  desc = desc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  if desc == "" then
    local id = moveIdKey(move)
    desc = SMOGON_RB_MOVE_DESCRIPTIONS[id] or ""
    if desc == "" and def then
      local effect = tostring(def.effect or ""):upper()
      desc = SMOGON_RB_EFFECT_DESCRIPTIONS[effect] or ""
    end
    if desc == "" and def and def.highCrit then
      desc = "High critical hit ratio."
    end
  end

  local lowered = desc:lower()
  if lowered == "no additional effect." or lowered == "no additional effect" then
    return ""
  end
  return desc
end

local function movePowerValue(battle, move)
  local def = moveDefinition(battle, move)
  local value = def and tonumber(def.power) or nil
  if not value or value <= 0 then return nil end
  return math.floor(value + 0.5)
end

local function moveAccuracyValue(battle, move)
  local def = moveDefinition(battle, move)
  local value = def and tonumber(def.accuracy) or nil
  if not value or value <= 0 then return nil end
  if value > 100 and value <= 255 then
    value = (value / 255) * 100
  end
  return clamp(math.floor(value + 0.5), 1, 100)
end

local function moveCategoryKey(battle, move)
  local def = moveDefinition(battle, move)
  local raw = def and (def.category or def.damageClass or def.damageCategory
      or def.class or def.kind) or nil
  if type(raw) == "table" then raw = raw.name or raw.id end
  raw = tostring(raw or ""):upper():gsub("[%s_%-]+", "")
  if raw == "STATUS" or raw == "NONDAMAGING" or raw == "EFFECT"
      or raw == "UTILITY" or raw == "SUPPORT" then
    return "STATUS"
  end
  if raw == "PHYSICAL" or raw == "PHYS" then return "PHYSICAL" end
  if raw == "SPECIAL" or raw == "SPEC" or raw == "SP" then return "SPECIAL" end

  if not movePowerValue(battle, move) then return "STATUS" end
  return SPECIAL_MOVE_TYPES[moveTypeKey(battle, move)] and "SPECIAL" or "PHYSICAL"
end

-- The Gen-I ROM font intentionally lacks a percent glyph. Keep using that font
-- for the visual language of the HUD, but reserve one 8px cell for every `%` so
-- descriptions containing probabilities wrap exactly as they will be rendered.
local function inlineHudTextWidth(text)
  text = tostring(text or "")
  local total = 0
  local pos = 1
  while true do
    local at = text:find("%", pos, true)
    if not at then
      total = total + textWidth(text:sub(pos))
      break
    end
    total = total + textWidth(text:sub(pos, at - 1)) + 8
    pos = at + 1
  end
  return total
end

local function wrapHudText(text, maxWidth, extraScale, maxLines)
  text = tostring(text or "")
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  local out = {}
  local scale = math.max(0.1, tonumber(extraScale) or 1)

  local function appendLine(line)
    if line ~= "" then
      out[#out + 1] = line
    end
    return maxLines and #out >= maxLines
  end

  for paragraph in text:gmatch("[^\n]+") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = (line == "") and word or (line .. " " .. word)
      if line == "" or inlineHudTextWidth(candidate) * scale <= maxWidth then
        if inlineHudTextWidth(candidate) * scale <= maxWidth then
          line = candidate
        else
          local piece = ""
          for ch in word:gmatch(".") do
            local joined = piece .. ch
            if piece ~= "" and inlineHudTextWidth(joined) * scale > maxWidth then
              if appendLine(piece) then return out end
              piece = ch
            else
              piece = joined
            end
          end
          line = piece
        end
      else
        if appendLine(line) then return out end
        line = word
      end
    end
    if appendLine(line) then return out end
  end

  return out
end

local function drawPercentGlyph(x, y, k, scale)
  scale = math.max(0.5, tonumber(scale) or 1)
  local px = math.max(0.75, scale)
  local dots = {
    {0, 0}, {1, 0}, {0, 1}, {1, 1},
    {5, 5}, {6, 5}, {5, 6}, {6, 6},
    {5, 0}, {4, 1}, {3, 2}, {3, 3}, {2, 4}, {1, 5}, {0, 6},
  }

  local function drawAt(ox, oy, r, gg, b)
    g.setColor(r, gg, b, 1)
    for _, pt in ipairs(dots) do
      g.rectangle("fill",
                  x + ox + pt[1] * px,
                  y + oy + pt[2] * px,
                  px, px)
    end
  end

  eachShadowOffset(k, scale, function(sx, sy)
    drawAt(sx, sy, 0, 0, 0)
  end)
  drawAt(0, 0, 1, 1, 1)
end


-- Draw normal Gen-I glyphs and splice the custom percent sign inline. This makes
-- `%` reusable in every Smogon description instead of special-casing accuracy.
local function drawShadowInlineText(text, x, y, k, extraScale)
  text = tostring(text or "")
  extraScale = math.max(0.25, tonumber(extraScale) or 1)
  local cursor = x
  local pos = 1

  while true do
    local at = text:find("%", pos, true)
    local chunk = at and text:sub(pos, at - 1) or text:sub(pos)
    if chunk ~= "" then
      drawShadowText(chunk, cursor, y, k, extraScale)
      cursor = cursor + textWidth(chunk) * extraScale
    end
    if not at then break end

    drawPercentGlyph(cursor + 0.5 * extraScale,
                     y + 0.5 * extraScale,
                     k,
                     0.72 * extraScale)
    cursor = cursor + 8 * extraScale
    pos = at + 1
  end
end

local function drawFightMoveHeader(layout, battle, move, k)
  local contentY = tonumber(layout.contentYOffset) or 0
  local divider = assetImage(FIGHT_DIVIDER_ASSET)
  if divider then
    drawShadowAsset(divider,
                    layout.dividerX or 55,
                    (layout.dividerY or 40) + contentY,
                    k,
                    FloatingHud.ASSET_SCALE * math.max(0.25, layout.dividerScale or 1))
  end

  local desc = moveDescriptionText(battle, move)
  local descScale = math.max(0.25, tonumber(layout.descScale) or 1)
  local descLines = wrapHudText(desc,
                                tonumber(layout.descWidth) or 184,
                                descScale,
                                tonumber(layout.descMaxLines) or 3)
  local lineStep = tonumber(layout.descLineStep) or (8 * descScale + 1)
  local bottomY = (tonumber(layout.descBottomY) or 23) + contentY
  local descX = tonumber(layout.descX) or 57
  local startY = bottomY - math.max(0, #descLines - 1) * lineStep
  for i = 1, #descLines do
    drawShadowInlineText(descLines[i], descX, startY + (i - 1) * lineStep,
                         k, descScale)
  end

  local statsScale = math.max(0.25, tonumber(layout.statsScale) or 1)
  local statsY = (tonumber(layout.statsY) or 35) + contentY
  local accuracy = moveAccuracyValue(battle, move)
  if accuracy then
    local accText = tostring(accuracy)
    local percentX = tonumber(layout.statsAccPercentX) or 184
    local gap = tonumber(layout.statsAccGap) or 1
    local accW = textWidth(accText) * statsScale
    -- Number grows LEFT toward the divider; the percent sign remains pinned.
    drawShadowText(accText,
                   percentX - gap * statsScale - accW,
                   statsY,
                   k,
                   statsScale)
    drawPercentGlyph(percentX,
                     statsY + 1 * statsScale,
                     k,
                     0.72 * statsScale)
  end

  local category = moveCategoryKey(battle, move)
  local categoryImage = assetImage(FIGHT_CATEGORY_ASSETS[category] or "")
  if categoryImage then
    drawShadowAsset(categoryImage,
                    tonumber(layout.statsCategoryX) or 194,
                    (tonumber(layout.statsCategoryY) or 31) + contentY,
                    k,
                    FloatingHud.ASSET_SCALE * math.max(0.25, layout.statsCategoryScale or 1))
  else
    local label = (category == "PHYSICAL" and "PHY")
               or (category == "SPECIAL" and "SPC")
               or "STS"
    drawShadowTextCentered(label,
                           (tonumber(layout.statsCategoryX) or 194) + 5,
                           statsY,
                           k,
                           0.8)
  end

  local power = movePowerValue(battle, move)
  if power then
    local powerText = tostring(power)
    -- Power grows RIGHT from a fixed left edge just after the category icon.
    drawShadowText(powerText,
                   tonumber(layout.statsPowerX) or 207,
                   statsY,
                   k,
                   statsScale)
  end
end

local function drawFightMoveRows(layout, battle, moves, count, selected, selector, k)
  local contentY = tonumber(layout.contentYOffset) or 0
  local listScale = math.max(0.5, tonumber(layout.listScale) or 1)
  local anchorX = tonumber(layout.listAnchorX) or 0
  local anchorY = tonumber(layout.listAnchorY) or 0
  local function sx(value)
    return anchorX + ((tonumber(value) or anchorX) - anchorX) * listScale
  end

  for i = 1, count do
    local move = moves[i]
    local y = (tonumber(layout.firstY) or 49) + contentY
            + (i - 1) * (tonumber(layout.rowStep) or 17) * listScale
    if move then
      if i == selected then
        drawShadowAsset(selector,
                        sx(layout.selectorX or 43),
                        y + (layout.selectorYOffset or 0) * listScale,
                        k,
                        FloatingHud.ASSET_SCALE * listScale)
      end

      local color = moveTypeColor(battle, move)
      g.setColor(color[1], color[2], color[3], color[4] or 1)
      g.rectangle("fill",
                  sx(layout.typeX or 55),
                  y + (layout.typeYOffset or 1) * listScale,
                  (layout.typeW or 4) * listScale,
                  (layout.typeH or 14) * listScale)

      drawShadowText(moveDisplayName(battle, move),
                     sx(layout.textX or 65), y, k, listScale)

      local curPP, maxPP = moveMaxPPValues(battle, move)
      local ppText = string.format("%d/%d", curPP, maxPP)
      local ppScale = math.max(0.5, tonumber(layout.ppScale) or listScale)
      local ppRight = sx(layout.ppRight or 211)
      drawShadowText(ppText,
                     ppRight - textWidth(ppText) * ppScale,
                     y + (layout.ppYOffset or 0) * listScale,
                     k,
                     ppScale)
    end
  end
end

local function renderFightCanvas(battle, k, logicalW, logicalH)
  local style = hudStyle()
  local plate = assetImage(FIGHT_PLATE_ASSET)
  local selector = assetImage(COMMAND_SELECTOR_ASSET)
  if not (battle and battle.player) then return nil end
  if style == "float" and not (plate and selector) then return nil end
  if style ~= "float" and not FloatingHud.commandAssetsReady() then return nil end

  local topPad = style == "float"
    and math.max(0, tonumber(FloatingHud.FIGHT.canvasTopPad) or 0) or 0
  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("fight", logicalW, logicalH, topPad)
  if not canvas then return nil end

  local layout = FloatingHud.FIGHT
  local moves = battle.player.curMoves or {}
  local count = math.min(4, #moves)
  local selected = clamp(math.floor(tonumber(battle.moveIndex) or 1), 1,
                         math.max(1, count))
  battle._ascendantBattleHudMoveLogicalHits = nil
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad + topPad)

    if style == "oras" then
      local moveTab = FloatingHud.styleAsset("move")
      local profile = megaProfileFor(battle, battle.player, "player")
      local mega = profile and FloatingHud.styleAsset("mega") or nil
      local megaFocused = mega
        and battle._ascendantBattleHudMoveMegaFocus == true
      local megaArmed = mega and FloatingHud.megaArmed(battle)
      local backFocused = battle._ascendantBattleHudMoveBackFocus == true
      local frame = tonumber(battle.frame) or 0
      local controlScale = FloatingHud.CONTROL_SCALE or 1
      local gap = math.max(6 * controlScale,
                           math.min(10 * controlScale, logicalW * 0.022))
      local cardW = math.min(148 * controlScale,
                             (logicalW - gap) * 0.5)
      local gridW = cardW * 2 + gap
      local gridX = (logicalW - gridW) * 0.5
      local cardH = 29 * controlScale
      -- MEGA occupies its own top-edge chip. No part of its hit target overlaps
      -- attack 1, so touch, mouse and controller focus can never choose both.
      local megaChipY = mega and 22 or nil
      local megaChipH = mega and 29 * controlScale or nil
      local rowOneY = mega
        and (megaChipY + megaChipH + 6 * controlScale)
         or (24 * controlScale)
      local rowTwoY = rowOneY + cardH + 5 * controlScale
      local positions = {
        { x=gridX, y=rowOneY }, { x=gridX + cardW + gap, y=rowOneY },
        { x=gridX, y=rowTwoY }, { x=gridX + cardW + gap, y=rowTwoY },
      }
      local megaX, megaY, megaW, megaH, megaScale
      local megaChipX, megaChipW
      if mega then
        local chipMax = math.max(32, cardW - 8)
        local chipMin = math.min(72 * controlScale, chipMax)
        megaChipW = clamp(cardW * 0.74, chipMin,
                          math.max(chipMin,
                                   math.min(106 * controlScale, chipMax)))
        megaChipX = positions[1].x + (cardW - megaChipW) * 0.5
        local baseScale = math.min(
          (megaChipW - 24 * controlScale) / mega:getWidth(),
          (megaChipH - 5 * controlScale) / mega:getHeight())
        local pulse = (megaArmed or megaFocused)
          and (0.96 + 0.04 * math.sin(frame * 0.13)) or 1
        megaScale = baseScale * pulse
        megaW, megaH = mega:getWidth() * megaScale,
                       mega:getHeight() * megaScale
        megaX = megaChipX + 5 * controlScale
          + ((megaChipW - 10 * controlScale) - megaW) * 0.5
        megaY = megaChipY + (megaChipH - megaH) * 0.5
      end
      local moveHits = {}
      if mega then
        moveHits[#moveHits + 1] = {
          action="move_mega",
          x=megaChipX - 4, y=megaChipY - 2,
          w=megaChipW + 8, h=megaChipH + 4,
        }
      end
      for i = 1, count do
        moveHits[#moveHits + 1] = {
          action="move", index=i,
          x=positions[i].x, y=positions[i].y,
          w=cardW, h=cardH,
        }
      end
      for i = 1, count do
        local pos = positions[i]
        local color = moveTypeColor(battle, moves[i])
        local moveFocused = i == selected and not megaFocused and not backFocused
        local focusPulse = 0.5 + 0.5 * math.sin(frame * 0.12)
        g.setColor(0.012, 0.038, 0.055, 0.94)
        g.rectangle("fill", pos.x, pos.y, cardW, cardH,
                    7 * controlScale, 7 * controlScale)
        g.setColor(color[1] * 0.68, color[2] * 0.68,
                   color[3] * 0.68,
                   moveFocused and (0.54 + focusPulse * 0.14) or 0.42)
        g.rectangle("fill", pos.x + 2 * controlScale,
                    pos.y + 2 * controlScale,
                    cardW - 4 * controlScale,
                    cardH - 4 * controlScale,
                    6 * controlScale, 6 * controlScale)
        g.setColor(color[1], color[2], color[3], 1)
        g.rectangle("fill", pos.x + 7 * controlScale,
                    pos.y + 2 * controlScale,
                    cardW - 14 * controlScale, 2 * controlScale)
        g.setLineWidth(moveFocused and (2 + focusPulse) or 1)
        g.rectangle("line", pos.x, pos.y, cardW, cardH,
                    7 * controlScale, 7 * controlScale)
        if moveFocused then
          g.setColor(1, 1, 1, 0.76 + focusPulse * 0.22)
          g.rectangle("line", pos.x + 2 * controlScale,
                      pos.y + 2 * controlScale,
                      cardW - 4 * controlScale,
                      cardH - 4 * controlScale,
                      6 * controlScale, 6 * controlScale)
        end
        g.setLineWidth(1)
        local textLeft = pos.x + 7 * controlScale
        local textRight = pos.x + cardW - 7 * controlScale
        local textCenter = (textLeft + textRight) * 0.5
        local textRoom = math.max(16, textRight - textLeft)
        local nameScale = 0.72 * controlScale
        local moveName = fitText(moveDisplayName(battle, moves[i]),
                                 textRoom / nameScale)
        drawShadowTextCentered(moveName, textCenter,
                               pos.y + 6 * controlScale, k, nameScale)
        local curPP, maxPP = moveMaxPPValues(battle, moves[i])
        local pp = string.format("%d/%d", curPP, maxPP)
        g.setColor(1, 1, 1, 1)
        drawShadowTextCentered(pp, textCenter,
                               pos.y + 17 * controlScale, k,
                               0.58 * controlScale)
      end

      if mega then
        g.setColor(0.008, 0.030, 0.046, 0.96)
        g.rectangle("fill", megaChipX, megaChipY,
                    megaChipW, megaChipH, 9, 9)
        if megaArmed then
          local glow = 0.5 + 0.5 * math.sin(frame * 0.13)
          g.setBlendMode("add")
          g.setColor(1.00, 0.16, 0.76, 0.18 + glow * 0.12)
          g.rectangle("fill", megaChipX - 3, megaChipY - 3,
                      megaChipW + 6, megaChipH + 6, 11, 11)
          g.setBlendMode("alpha")
          g.setColor(1.00, 0.38, 0.84, 0.96)
          g.setLineWidth(2)
        elseif megaFocused then
          g.setColor(0.32, 0.90, 1.00, 0.96)
          g.setLineWidth(2)
        else
          g.setColor(0.25, 0.60, 0.70, 0.76)
          g.setLineWidth(1)
        end
        g.rectangle("line", megaChipX, megaChipY,
                    megaChipW, megaChipH, 9, 9)
        if megaFocused then
          g.setColor(1, 1, 1, 0.95)
          g.rectangle("line", megaChipX + 2, megaChipY + 2,
                      megaChipW - 4, megaChipH - 4, 7, 7)
        end
        g.setLineWidth(1)
        FloatingHud.drawColoredAsset(mega, megaX, megaY, megaScale,
                                     megaArmed and 1 or 0.72)
        local badge = megaArmed
          and (hudLanguage() == "de" and "AN" or "ON")
          or (hudLanguage() == "de" and "AUS" or "OFF")
        local badgeScale = 0.48 * controlScale
        local badgeW = textWidth(badge) * badgeScale + 6
        local badgeX = megaChipX + megaChipW - badgeW - 3
        local badgeY = megaChipY + 3 * controlScale
        g.setColor(megaArmed and 0.72 or 0.08,
                   megaArmed and 0.06 or 0.14,
                   megaArmed and 0.58 or 0.18, 0.96)
        g.rectangle("fill", badgeX, badgeY, badgeW,
                    8 * controlScale, 4 * controlScale, 4 * controlScale)
        drawShadowTextCentered(badge, badgeX + badgeW * 0.5,
                               badgeY + 1, k, badgeScale)
      end

      local backBaseScale = 0.58 * controlScale
      local backLayoutW = moveTab and moveTab:getWidth() * backBaseScale or 0
      local backLayoutH = moveTab and moveTab:getHeight() * backBaseScale or 0
      local backPulse = backFocused
        and (0.96 + 0.04 * math.sin(frame * 0.12)) or 1
      local backScale = backBaseScale * backPulse
      local backW = moveTab and moveTab:getWidth() * backScale or 0
      local backH = moveTab and moveTab:getHeight() * backScale or 0
      local backLayoutX = (logicalW - backLayoutW) * 0.5
      local backLayoutY = logicalH - backLayoutH
      local backX = backLayoutX + (backLayoutW - backW) * 0.5
      local backY = backLayoutY + (backLayoutH - backH) * 0.5
      local backLabel = hudLanguage() == "de" and "ZURÜCK" or "BACK"
      local backLabelScale = 0.62 * controlScale
      local backBadgeW = textWidth(backLabel) * backLabelScale
                       + 8 * controlScale
      local backBadgeH = 10 * controlScale
      local backBadgeX = (logicalW - backBadgeW) * 0.5
      local backBadgeY = backLayoutY - 12 * controlScale
      if moveTab then
        moveHits[#moveHits + 1] = {
          action="move_back",
          x=backLayoutX - 5, y=backBadgeY - 2,
          w=backLayoutW + 10, h=logicalH - (backBadgeY - 2),
        }
      end
      battle._ascendantBattleHudMoveLogicalHits = moveHits
      if moveTab then
        if backFocused then
          g.setColor(0.22, 0.86, 1.00, 0.24)
          g.ellipse("fill", logicalW * 0.5, backY + backH * 0.58,
                    backW * 0.58, backH * 0.66)
        end
        FloatingHud.drawColoredAsset(moveTab, backX, backY, backScale, 1)
        g.setColor(0.008, 0.030, 0.046, 0.94)
        g.rectangle("fill", backBadgeX, backBadgeY,
                    backBadgeW, backBadgeH,
                    4 * controlScale, 4 * controlScale)
        g.setColor(0.28, 0.88, 1.00, backFocused and 1 or 0.78)
        g.rectangle("line", backBadgeX, backBadgeY,
                    backBadgeW, backBadgeH,
                    4 * controlScale, 4 * controlScale)
        drawShadowTextCentered(backLabel, logicalW * 0.5,
                               backBadgeY + controlScale,
                               k, backLabelScale)
      end
      if backFocused and moveTab then
        FloatingHud.drawHandCursor(logicalW * 0.5, backBadgeY,
                                   0.90, battle.frame)
      elseif megaFocused and mega then
        FloatingHud.drawHandCursor(megaChipX + megaChipW * 0.5,
                                   megaChipY, 0.90, battle.frame)
      elseif count > 0 then
        local chosen = positions[selected]
        FloatingHud.drawHandCursor(chosen.x + cardW * 0.5,
                                   chosen.y, 0.90, battle.frame)
      end
    else
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
      if count > 0 then
        drawFightMoveHeader(layout, battle, moves[selected], k)
        drawFightMoveRows(layout, battle, moves, count, selected, selector, k)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end


local function renderLearnCanvas(menu, battle, k, logicalW, logicalH)
  local style = hudStyle()
  local plate = selectPlateImage()
  local selector = assetImage(COMMAND_SELECTOR_ASSET)
  if not (menu and menu.mon) then return nil end
  if style == "float" and not (plate and selector) then return nil end
  if style ~= "float" and not FloatingHud.commandAssetsReady() then return nil end

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("learn", logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.LEARN
  local moves = menu.mon.moves or {}
  local count = math.min(4, #moves)
  local selected = clamp(math.floor(tonumber(menu.index) or 1), 1, math.max(1, count))
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if style == "oras" then
      local moveTab = FloatingHud.styleAsset("move")
      local controlScale = FloatingHud.CONTROL_SCALE or 1
      local frame = tonumber(menu._ascendantBattleHudFrame)
                 or tonumber(menu.frame)
                 or tonumber(battle and battle.frame) or 0
      local gap = math.max(6 * controlScale,
                           math.min(10 * controlScale, logicalW * 0.022))
      local cardW = math.min(148 * controlScale,
                             (logicalW - gap) * 0.5)
      local gridW = cardW * 2 + gap
      local gridX = (logicalW - gridW) * 0.5
      local cardH = 29 * controlScale
      local rowOneY = 20 * controlScale
      local rowTwoY = rowOneY + cardH + 5 * controlScale
      local positions = {
        { x=gridX, y=rowOneY },
        { x=gridX + cardW + gap, y=rowOneY },
        { x=gridX, y=rowTwoY },
        { x=gridX + cardW + gap, y=rowTwoY },
      }
      for i = 1, count do
        local pos = positions[i]
        local color = moveTypeColor(battle, moves[i])
        local focusPulse = 0.5 + 0.5 * math.sin(frame * 0.12)
        g.setColor(0.012, 0.038, 0.055, 0.94)
        g.rectangle("fill", pos.x, pos.y, cardW, cardH,
                    7 * controlScale, 7 * controlScale)
        g.setColor(color[1] * 0.68, color[2] * 0.68,
                   color[3] * 0.68,
                   i == selected and (0.54 + focusPulse * 0.14) or 0.42)
        g.rectangle("fill", pos.x + 2 * controlScale,
                    pos.y + 2 * controlScale,
                    cardW - 4 * controlScale,
                    cardH - 4 * controlScale,
                    6 * controlScale, 6 * controlScale)
        g.setColor(color[1], color[2], color[3], 1)
        g.rectangle("fill", pos.x + 7 * controlScale,
                    pos.y + 2 * controlScale,
                    cardW - 14 * controlScale, 2 * controlScale)
        g.setLineWidth(i == selected and (2 + focusPulse) or 1)
        g.rectangle("line", pos.x, pos.y, cardW, cardH,
                    7 * controlScale, 7 * controlScale)
        g.setLineWidth(1)
        local nameScale = 0.72 * controlScale
        local moveName = fitText(moveDisplayName(battle, moves[i]),
                                 (cardW - 14 * controlScale) / nameScale)
        drawShadowTextCentered(moveName, pos.x + cardW * 0.5,
                               pos.y + 6 * controlScale, k, nameScale)
        local curPP, maxPP = moveMaxPPValues(battle, moves[i])
        drawShadowTextCentered(string.format("%d/%d", curPP, maxPP),
                               pos.x + cardW * 0.5,
                               pos.y + 17 * controlScale,
                               k, 0.58 * controlScale)
      end
      if count > 0 then
        local chosen = positions[selected]
        FloatingHud.drawHandCursor(chosen.x + cardW * 0.5,
                                   chosen.y, 0.90, frame)
      end
      if moveTab then
        local backScale = 0.58 * controlScale
        local backW = moveTab:getWidth() * backScale
        local backH = moveTab:getHeight() * backScale
        local backX = (logicalW - backW) * 0.5
        local backY = logicalH - backH
        FloatingHud.drawColoredAsset(
          moveTab, backX, backY, backScale, 1)
        local backLabel = hudLanguage() == "de" and "ZURÜCK" or "BACK"
        local backLabelScale = 0.62 * controlScale
        local backBadgeW = textWidth(backLabel) * backLabelScale
                         + 8 * controlScale
        local backBadgeH = 10 * controlScale
        local backBadgeX = (logicalW - backBadgeW) * 0.5
        local backBadgeY = backY - 12 * controlScale
        g.setColor(0.008, 0.030, 0.046, 0.94)
        g.rectangle("fill", backBadgeX, backBadgeY,
                    backBadgeW, backBadgeH,
                    4 * controlScale, 4 * controlScale)
        g.setColor(0.28, 0.88, 1.00, 0.78)
        g.rectangle("line", backBadgeX, backBadgeY,
                    backBadgeW, backBadgeH,
                    4 * controlScale, 4 * controlScale)
        drawShadowTextCentered(backLabel, logicalW * 0.5,
                               backBadgeY + controlScale,
                               k, backLabelScale)
      end
    else
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
      if count > 0 then
        drawFightMoveHeader(layout, battle, moves[selected], k)
        drawFightMoveRows(layout, battle, moves, count, selected, selector, k)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end

local function renderPartyCanvas(menu, battle, k, logicalW, logicalH)
  local style = hudStyle()
  local plate = assetImage(PKMN_PLATE_ASSET)
  local selector = assetImage(COMMAND_SELECTOR_ASSET)
  if not menu then return nil end
  if style == "float" and not plate then return nil end

  local canvas, cw, ch, pad, raster, logicalCW, logicalCH =
    panelCanvas("pkmn", logicalW, logicalH)
  if not canvas then return nil end

  local layout = FloatingHud.PKMN
  local party = menu.party or (menu.game and menu.game.save and menu.game.save.party) or {}
  local count = math.min(6, #party)
  local selected = clamp(math.floor(tonumber(menu.index) or 1), 1, math.max(1, count))
  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()

  local ok, err = pcall(function()
    g.setCanvas(canvas)
    g.origin()
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.push()
    g.scale(raster, raster)
    g.translate(pad, pad)

    if style == "float" then
      drawShadowAsset(plate, 0, 0, k, FloatingHud.ASSET_SCALE)
    else
      FloatingHud.drawStyleSurface("pkmn", logicalW, logicalH, k)
      if style == "oras" then
        local tab = FloatingHud.styleAsset("pokemon")
        if tab then FloatingHud.drawColoredAsset(tab, 5, 3, 0.31, 1) end
      end
    end

    local firstY = style == "oras" and 24 or layout.firstY or 10
    -- The expanded two-line row needs enough real vertical room for its KP
    -- text and five-pixel bar. Basing this on the per-row budget avoids the
    -- 241..280px transition band where a fixed "large" layout used to paint
    -- into the next Pokémon.
    local availableRowStep = style == "oras"
      and ((logicalH - firstY - 8) / math.max(6, count)) or 0
    local largeParty = style == "oras" and availableRowStep >= 46
    local maxRowStep = largeParty and 56 or 30
    local rowStep = style == "oras"
      and math.min(maxRowStep, math.max(15,
        (logicalH - firstY - 8) / math.max(6, count)))
       or layout.rowStep or 17
    local iconX = style ~= "float" and 12 or layout.iconX or 63
    local iconTarget = style == "oras"
      and math.min(largeParty and 32 or 24, rowStep - 2) or 16
    local textX = style ~= "float" and (iconX + iconTarget + 7)
                                      or layout.textX or 82
    local selectorX = style ~= "float" and 8 or layout.selectorX or 55

    -- PartyMenu is the active/top state here, so BattleState.frame is paused.
    -- Its own blink counter remains live and drives both the authentic Crystal
    -- pose toggle and the restrained selected-icon pulse.
    local partyFrame = tonumber(menu and menu.blink)
                    or tonumber(battle and battle.frame) or 0

    for i = 1, count do
      local mon = party[i]
      local y = firstY + (i - 1) * rowStep

      if i == selected then
        if style == "float" and selector then
          drawShadowAsset(selector,
                          selectorX,
                          y + (layout.selectorYOffset or -1),
                          k, FloatingHud.ASSET_SCALE)
        else
          local accent = style == "oras" and { 0.22, 0.86, 1.00, 0.30 }
                                         or { 0.73, 0.82, 0.55, 0.88 }
          g.setColor(accent[1], accent[2], accent[3], accent[4])
          g.rectangle("fill", 7, y - 1, logicalW - 14, rowStep - 1, 4, 4)
          g.setColor(style == "oras" and 1 or 0.45,
                     style == "oras" and 1 or 0.18,
                     style == "oras" and 1 or 0.22, 0.90)
          g.rectangle("line", 7, y - 1, logicalW - 14, rowStep - 1, 4, 4)
        end
      end

      -- Resolve the same front/Dex art KASC selected for its Crystal view. This
      -- keeps every species on the detailed Gorochu-style presentation instead
      -- of letting the bundled 16x16 menu sheet intercept Pokédex 001-251.
      -- The tiny authentic Crystal menu icon remains a final safety fallback
      -- when neither KASC nor the engine can provide front/Dex artwork.
      local dexIcon = style == "oras"
        and FloatingHud.standardPartySprite(mon, battle, menu) or nil
      local crystalIcon = not dexIcon and style == "oras"
        and FloatingHud.crystalPartyIcon(mon, battle, menu) or nil
      local icon = dexIcon or crystalIcon
        or partyIconImage(mon and mon.species)
      local drewIcon = false
      if icon then
        local iw, ih = icon:getDimensions()
        local crystal = crystalIcon ~= nil and iw == 16 and ih >= 96
        local frameH = crystal and 16
                    or ih
        local ticks = math.max(1, math.floor(layout.iconFrameTicks or 18))
        -- Crystal's own party list animates only the selected row and toggles
        -- its two down-facing poses. Cycling six directions made the Pokémon
        -- appear to spin in place rather than sit cleanly in the list.
        local phase = math.floor(partyFrame / ticks)
        local frame = crystal and i == selected and phase % 2 == 1 and 3 or 0
        local quad = g.newQuad(0, frame * frameH, iw, frameH, iw, ih)
        local baseScale = iconTarget / math.max(1, math.max(iw, frameH))
        local iconPulse = i == selected
          and (0.96 + 0.04 * math.sin(partyFrame * 0.12)) or 1
        local scale = baseScale * iconPulse
        local slotW, slotH = iw * baseScale, frameH * baseScale
        local drawW, drawH = iw * scale, frameH * scale
        local drawX = iconX + (slotW - drawW) * 0.5
        local drawY = y + (slotH - drawH) * 0.5
        g.setColor(0,0,0,1)
        local o = shadowLogical(k, 1)
        g.draw(icon, quad, drawX + o, drawY + o, 0, scale, scale)
        g.setColor(1,1,1,1)
        g.draw(icon, quad, drawX, drawY, 0, scale, scale)
        drewIcon = true
      end

      -- If both registered Dex/front art and the optional legacy icon path are
      -- unavailable, keep the row functional and text-complete. Gen1Recomp's
      -- PartyMenu icon painter is intentionally private, so this standalone
      -- HUD does not pretend there is a public drawIcon API to call.

      local partyData = battle and battle.data
                     or (battle and battle.game and battle.game.data)
                     or (menu and menu.game and menu.game.data)
      local def = partyData and partyData.pokemon
                  and mon and partyData.pokemon[mon.species]
      local name = mon and tostring(mon.nickname or (def and def.name)
                                    or mon.species or "POKéMON") or ""
      local nameScale = style ~= "float" and (largeParty and 1.0 or 0.82) or 1
      local levelText = mon and ("Lv." .. tostring(mon.level or "?")) or ""
      local levelScale = style ~= "float" and (largeParty and 0.78 or 0.64) or 1
      local levelX = logicalW - 12 - textWidth(levelText) * levelScale
      local gender = mon and genderSymbol(battle, mon) or nil
      local genderScale = largeParty and 0.90 or 0.70
      local genderRoom = gender and (10 * genderScale + 3) or 0
      local fittedName = fitText(
        name, math.max(8, (levelX - textX - genderRoom - 4) / nameScale))
      drawShadowText(fittedName, textX, y + 1, k, nameScale)
      if gender then
        local genderX = textX + textWidth(fittedName) * nameScale + 2
        if genderX + 8 * genderScale < levelX then
          drawGenderSymbol(gender, genderX, y + 0.5, k, genderScale)
        end
      end
      if mon then drawShadowText(levelText, levelX, y + 2, k, levelScale) end

      if mon then
        local hp = math.max(0, tonumber(mon.hp) or 0)
        local maxHP = math.max(1, tonumber(mon.stats and mon.stats.hp) or 1)
        if menu and menu.heal and menu.heal.mon == mon
            and tonumber(menu.heal.shown) then
          hp = clamp(math.floor(tonumber(menu.heal.shown)), 0, maxHP)
        end
        local ratio = clamp(hp / maxHP, 0, 1)
        local hx = textX
        local hw = math.max(24, logicalW - textX - 12)
        local hpHeight = largeParty and 5 or 3
        local hy = largeParty and (y + 37) or (y + rowStep - hpHeight - 1)
        local infoY = largeParty and (y + 22) or (y + 11)
        local hpScale = largeParty and 0.75 or 0.58
        local hpLabel = hudLanguage() == "de" and "KP" or "HP"
        local hpText = tostring(hp) .. "/" .. tostring(maxHP)
        drawShadowText(hpLabel, hx, infoY, k, hpScale)
        local status = mon.status and STATUS_FALLBACK[mon.status] or nil
        if status then
          drawShadowText(status,
                         hx + textWidth(hpLabel) * hpScale + 5,
                         infoY, k, hpScale * 0.92)
        end
        drawShadowText(hpText,
                       hx + hw - textWidth(hpText) * hpScale,
                       infoY, k, hpScale)

        -- White track + Gen-I HP colour; thickened on the full-screen phone UI.
        g.setColor(0,0,0,1)
        g.rectangle("fill", hx + 1, hy + 1, hw, hpHeight + 1)
        g.setColor(1,1,1,1)
        g.rectangle("fill", hx, hy, hw, hpHeight)
        if ratio <= 0.20 then
          g.setColor(0.95, 0.16, 0.12, 1)
        elseif ratio <= 0.50 then
          g.setColor(1.00, 0.82, 0.10, 1)
        else
          g.setColor(0.15, 0.92, 0.30, 1)
        end
        g.rectangle("fill", hx, hy, hw * ratio, hpHeight)
      end
    end

    g.pop()
  end)

  g.setShader(prevShader)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1,1,1,1)
  if not ok then error(err, 0) end
  return canvas, logicalCW, logicalCH
end


local function rotatedPoint(x, y, angle)
  if angle == 0 then return x, y end
  local c, s = math.cos(angle), math.sin(angle)
  return x * c - y * s, x * s + y * c
end

local function drawPerspectiveCanvas(canvas, cx, cy, w, h, signal, roll, side,
                                     depthOverride, squeezeOverride,
                                     pitchSignal, pitchDepthOverride,
                                     pitchSqueezeOverride)
  signal = clamp(signal or 0, -1, 1)

  -- Status/command planes preserve the established v0.5 behavior. A caller may
  -- opt into a signed custom depth (the message plate does) without changing
  -- the hand-tuned Pokemon plates.
  local depth
  if depthOverride ~= nil then
    depth = clamp(tonumber(depthOverride) or 0, -0.45, 0.45)
  else
    depth = clamp(FloatingHud.PERSPECTIVE_DEPTH or 0, 0, 0.45)
  end

  local squeeze
  if squeezeOverride ~= nil then
    squeeze = clamp(tonumber(squeezeOverride) or 0, 0, 0.35)
  else
    squeeze = clamp(FloatingHud.PERSPECTIVE_WIDTH_SQUEEZE or 0, 0, 0.35)
  end

  -- Positive signal makes the RIGHT edge the near edge; negative makes LEFT near.
  local leftScale  = 1 - signal * depth
  local rightScale = 1 + signal * depth
  local widthScale = 1 - math.abs(signal) * squeeze
  local lx, rx = -w * 0.5 * widthScale, w * 0.5 * widthScale
  local lhy, rhy = h * 0.5 * leftScale, h * 0.5 * rightScale

  -- Optional second-axis perspective. BattleCam.pitch is 0..1, so positive pitch
  -- means the camera has climbed above the authored low seat. Narrow the top edge
  -- and open the bottom edge a little, plus a tiny height compression. Existing
  -- status/command callers omit these parameters and therefore remain bit-for-bit
  -- on their established geometry.
  pitchSignal = clamp(tonumber(pitchSignal) or 0, -1, 1)
  local pitchDepth = clamp(tonumber(pitchDepthOverride) or 0, -0.35, 0.35)
  local pitchSqueeze = clamp(tonumber(pitchSqueezeOverride) or 0, 0, 0.25)
  local topWidth = 1 - pitchSignal * pitchDepth
  local bottomWidth = 1 + pitchSignal * pitchDepth
  local heightScale = 1 - math.abs(pitchSignal) * pitchSqueeze

  local x1,y1 = rotatedPoint(lx * topWidth,    -lhy * heightScale, roll) -- top-left
  local x2,y2 = rotatedPoint(rx * topWidth,    -rhy * heightScale, roll) -- top-right
  local x3,y3 = rotatedPoint(rx * bottomWidth,  rhy * heightScale, roll) -- bottom-right
  local x4,y4 = rotatedPoint(lx * bottomWidth,  lhy * heightScale, roll) -- bottom-left

  -- A single quad is rasterized as two triangles, whose affine UV interpolation
  -- makes the diagonal visible when the four corners form a strong trapezoid.
  -- Subdivide the card and bilinearly place a small grid across the same four
  -- corners. The remaining per-triangle error is tiny and the whole HUD now reads
  -- as one continuous plane instead of two halves pulling in different directions.
  local gx = math.max(2, math.floor(FloatingHud.PERSPECTIVE_GRID_X or 12))
  local gy = math.max(2, math.floor(FloatingHud.PERSPECTIVE_GRID_Y or 6))
  local verts = {}

  for iy = 0, gy do
    local v = iy / gy
    for ix = 0, gx do
      local u = ix / gx
      local tx = x1 + (x2 - x1) * u
      local ty = y1 + (y2 - y1) * u
      local bx = x4 + (x3 - x4) * u
      local by = y4 + (y3 - y4) * u
      local x = tx + (bx - tx) * v
      local y = ty + (by - ty) * v
      verts[#verts + 1] = { x, y, u, v }
    end
  end

  local key = side .. ":" .. gx .. "x" .. gy
  local mesh = cardMeshes[key]
  if not mesh then
    mesh = g.newMesh(verts, "triangles", "dynamic")
    local map = {}
    local row = gx + 1
    for iy = 0, gy - 1 do
      for ix = 0, gx - 1 do
        local a = iy * row + ix + 1
        local b = a + 1
        local d = a + row
        local c = d + 1
        map[#map + 1] = a; map[#map + 1] = b; map[#map + 1] = c
        map[#map + 1] = a; map[#map + 1] = c; map[#map + 1] = d
      end
    end
    mesh:setVertexMap(map)
    cardMeshes[key] = mesh
  else
    mesh:setVertices(verts)
  end

  mesh:setTexture(canvas)
  g.setColor(1, 1, 1, 1)
  if FloatingHud.activeWorldPreflipHeight then
    g.push("transform")
    g.origin()
    g.translate(0, FloatingHud.activeWorldPreflipHeight)
    g.scale(1, -1)
    g.draw(mesh, cx, cy)
    g.pop()
  else
    g.draw(mesh, cx, cy)
  end
end

local function drawCard(battle, shot, side, battler, prepared)
  if not (battler and battler.mon) then return false end
  local rect, k, logicalW, logicalH
  if prepared then
    rect, k, logicalW, logicalH = prepared.rect, prepared.k,
                                  prepared.logicalW, prepared.logicalH
  else
    rect, k, logicalW, logicalH = FloatingHud.projectOwnerStatusRect(shot, side)
  end
  if not rect then return false end

  local canvas, cw, ch = renderCardCanvas(battle, side, battler, k,
                                          logicalW, logicalH)
  if not canvas then return false end

  local signal = prepared and prepared.signal
  if signal == nil then signal = cameraYawSignal() end
  local roll = prepared and prepared.roll
  if roll == nil then roll = hudRotation() end
  local cx = rect[1] + rect[3] / 2
  local cy = rect[2] + rect[4] / 2

  -- Canvas padding is transparent and symmetric, so it can be included in the
  -- projected plane without changing the HUD's visual centre.
  drawPerspectiveCanvas(canvas, cx, cy, cw * k, ch * k, signal, roll, side)
  return true
end

function FloatingHud.screenDockRect(shot, kind)
  if not shot then return nil end
  local logicalW, logicalH = FloatingHud.panelLogicalSize(kind)
  if not (logicalW and logicalH) then return nil end
  -- Horizontal breathing room clears rounded phone corners. Vertically the
  -- command cluster is deliberately anchored to the framebuffer itself on every
  -- device. A reported iOS/Android home-indicator inset may reduce the scale, but
  -- it must never make this visually continuous bottom UI float above the edge.
  -- The transparent supersampling pad may clip outside the framebuffer without
  -- clipping any authored control pixels.
  local insetLeft, _, insetRight, insetBottom = FloatingHud.safeInsets(shot)
  local safe = math.max(7, math.floor(math.min(shot.pw, shot.ph) * 0.024))
  local pad = math.max(0, tonumber(FloatingHud.CANVAS_PAD) or 0)
  local totalAvailable = math.max(1,
    shot.pw - insetLeft - insetRight - safe * 2)
  local safeHeight = math.max(1,
    shot.ph - insetBottom - safe * 2)
  local heightCap = math.max(0.25,
    (safeHeight * (FloatingHud.DOCK_HEIGHT_SHARE or 0.31))
      / (logicalH + pad * 2))
  local scale = math.min(uiScale(shot), heightCap)
  local padPixels = pad * scale
  local contentAvailable = math.max(1, totalAvailable - padPixels * 2)
  local maxLogicalWidth = math.max(1,
    tonumber(FloatingHud.DOCK_MAX_LOGICAL_WIDTH) or 720)
  local available = math.min(contentAvailable, maxLogicalWidth * scale)
  local left = insetLeft + safe + (totalAvailable - available) * 0.5
  local bottom = 0
  logicalW = available / scale
  local height = logicalH * scale
  return { left, shot.ph - bottom - height, available, height },
         scale, logicalW, logicalH
end

function FloatingHud.drawMenuPlane(canvas, cx, cy, width, height, side)
  if hudStyle() == "float" then
    drawPerspectiveCanvas(canvas, cx, cy, width, height,
                          cameraYawSignal(), hudRotation(), side)
    return
  end
  drawPerspectiveCanvas(canvas, cx, cy, width, height, 0, 0, side,
                        0, 0, 0, 0, 0)
end

function HudRuntime.commandRectFor(shot)
  if not (shot and shot.player) then return nil end
  if hudStyle() ~= "float" then
    return FloatingHud.screenDockRect(shot, "command")
  end
  local logicalW, logicalH = FloatingHud.panelLogicalSize("command")
  if not (logicalW and logicalH) then return nil end

  local s = tonumber(shot.scale) or 1
  local baseScale = uiScale(shot)
  local drawScale = baseScale * distanceScale(shot, "player")
                    * (FloatingHud.COMMAND.scale or 1)
  local footX = shot.lx + shot.player[1] * s
  local footY = shot.ly + shot.player[2] * s
  local w = logicalW * drawScale
  local h = logicalH * drawScale
  local x = footX - w - (FloatingHud.COMMAND.xGap or 8) * baseScale
  -- Right-edge/middle anchor: the player's projected feet sit beside the middle
  -- of the command plate instead of beside its lower-right corner.
  local y = footY - h * 0.5 + (FloatingHud.COMMAND.yOffset or 0) * baseScale
  local margin = FloatingHud.MARGIN

  x = clamp(x, margin, math.max(margin, shot.pw - w - margin))
  -- Deliberately no lower-screen clamp: this plate belongs to the projected
  -- player position. Let it continue down with the mon instead of pinning it
  -- against the viewport and colliding with the player's status plate.
  y = math.max(margin, y)
  return { x, y, w, h }, drawScale, logicalW, logicalH
end

function HudRuntime.fightRectFor(shot)
  if not (shot and shot.player) then return nil end
  if hudStyle() ~= "float" then
    return FloatingHud.screenDockRect(shot, "fight")
  end
  local logicalW, logicalH = FloatingHud.panelLogicalSize("fight")
  if not (logicalW and logicalH) then return nil end

  local s = tonumber(shot.scale) or 1
  local baseScale = uiScale(shot)
  local drawScale = baseScale * distanceScale(shot, "player")
                    * (FloatingHud.FIGHT.scale or 1)
  local footX = shot.lx + shot.player[1] * s
  local footY = shot.ly + shot.player[2] * s
  local w = logicalW * drawScale
  local h = logicalH * drawScale
  local x = footX + (FloatingHud.FIGHT.xGap or 10) * baseScale
  local y = footY - h + (FloatingHud.FIGHT.yOffset or 0) * baseScale
  local margin = FloatingHud.MARGIN

  x = clamp(x, margin, math.max(margin, shot.pw - w - margin))
  y = math.max(margin, y)
  return { x, y, w, h }, drawScale, logicalW, logicalH
end


function HudRuntime.learnRectFor(shot)
  if not (shot and shot.player) then return nil end
  if hudStyle() ~= "float" then
    return FloatingHud.screenDockRect(shot, "learn")
  end
  local logicalW, logicalH = FloatingHud.panelLogicalSize("learn")
  if not (logicalW and logicalH) then return nil end

  local s = tonumber(shot.scale) or 1
  local baseScale = uiScale(shot)
  local drawScale = baseScale * distanceScale(shot, "player")
                    * (FloatingHud.LEARN.scale or 1)
  local footX = shot.lx + shot.player[1] * s
  local footY = shot.ly + shot.player[2] * s
  local w = logicalW * drawScale
  local h = logicalH * drawScale
  local x = footX + (FloatingHud.LEARN.xGap or 10) * baseScale
  local y = footY - h + (FloatingHud.LEARN.yOffset or 0) * baseScale
  local margin = FloatingHud.MARGIN

  x = clamp(x, margin, math.max(margin, shot.pw - w - margin))
  y = math.max(margin, y)
  return { x, y, w, h }, drawScale, logicalW, logicalH
end

function HudRuntime.partyRectFor(shot)
  if not (shot and shot.player) then return nil end
  if hudStyle() ~= "float" then
    local mobile = PLATFORM_OS == "Android" or PLATFORM_OS == "iOS"
                or shot.pw < 700 or shot.pw < shot.ph
    if mobile then
      local scale = math.max(0.5, math.min(uiScale(shot), shot.pw / 320))
      return { 0, 0, shot.pw, shot.ph }, scale,
             shot.pw / scale, shot.ph / scale
    end
    local logicalW, logicalH = 240, 180
    local scale = math.min(uiScale(shot),
                           (shot.pw * 0.34) / logicalW,
                           (shot.ph * 0.72) / logicalH)
    scale = math.max(0.55, scale)
    local width, height = logicalW * scale, logicalH * scale
    local margin = math.max(8, math.floor(math.min(shot.pw, shot.ph) * 0.018))
    return { margin, (shot.ph - height) * 0.5, width, height },
           scale, logicalW, logicalH
  end
  local logicalW, logicalH = FloatingHud.panelLogicalSize("pkmn")
  if not (logicalW and logicalH) then return nil end

  local s = tonumber(shot.scale) or 1
  local baseScale = uiScale(shot)
  local drawScale = baseScale * distanceScale(shot, "player")
                    * (FloatingHud.PKMN.scale or 1)
  local footX = shot.lx + shot.player[1] * s
  local footY = shot.ly + shot.player[2] * s
  local w = logicalW * drawScale
  local h = logicalH * drawScale
  local x = footX + (FloatingHud.PKMN.xGap or 10) * baseScale
  local y = footY - h * 0.5 + (FloatingHud.PKMN.yOffset or -10) * baseScale
  local margin = FloatingHud.MARGIN

  x = clamp(x, margin, math.max(margin, shot.pw - w - margin))
  y = math.max(margin, y)
  return { x, y, w, h }, drawScale, logicalW, logicalH
end

local function drawPartyPanel(menu, battle, shot)
  if not (menu and battle and shot) then
    return false
  end
  if hudStyle() == "float" and not assetImage(PKMN_PLATE_ASSET) then
    return false
  end
  local rect, k, logicalW, logicalH = HudRuntime.partyRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderPartyCanvas(menu, battle, k, logicalW, logicalH)
  if not canvas then return false end

  local cx = rect[1] + rect[3] * 0.5
  local cy = rect[2] + rect[4] * 0.5
  g.push("all")
  g.origin()
  FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "pkmn")

  -- Voluntary battle switching is a submenu INSIDE PartyMenu, not a pushed
  -- ChoiceBox. PartyMenu's native renderer is hidden by this mod, so paint the
  -- live native submenu here while leaving its update/actions completely intact.
  if menu.submenu and menu.battle and menu.onSwitch then
    local subCanvas, subCW, subCH, subLogicalW, subLogicalH =
      renderPartyChoiceCanvas(menu, k)
    if subCanvas then
      local layout = FloatingHud.PARTY_CHOICE or FloatingHud.CHOICE
      local planeW = subLogicalW * k
      local planeH = subLogicalH * k

      -- Match the YES/NO language: a transparent floating list right-aligned to
      -- its parent panel. Prefer just above PKMN; clamp the whole plane on-screen
      -- so mobile/tall HUD scales cannot hide SWITCH again.
      local subCX = rect[1] + rect[3] - planeW * 0.5
                    + (layout.rightOffset or -2) * k
      local subCY = rect[2] - planeH * 0.5 - (layout.aboveGap or 2) * k
      local margin = FloatingHud.MARGIN or 4
      subCX = clamp(subCX, margin + planeW * 0.5,
                    math.max(margin + planeW * 0.5,
                             shot.pw - margin - planeW * 0.5))
      subCY = clamp(subCY, margin + planeH * 0.5,
                    math.max(margin + planeH * 0.5,
                             shot.ph - margin - planeH * 0.5))

      FloatingHud.drawMenuPlane(subCanvas, subCX, subCY,
                                subCW * k, subCH * k, "pkmn_choice")
    end
  end

  g.pop()
  return true
end

function HudRuntime.messageRectFor(shot)
  if not shot then return nil end
  local logicalW, logicalH = FloatingHud.panelLogicalSize("message")
  if not (logicalW and logicalH) then return nil end

  if hudStyle() ~= "float" then
    local insetLeft, _, insetRight, insetBottom = FloatingHud.safeInsets(shot)
    local safe = math.max(7,
      math.floor(math.min(shot.pw, shot.ph) * 0.024))
    local left = insetLeft + safe
    local right = insetRight + safe
    local availableW = math.max(1, shot.pw - left - right)
    local availableH = math.max(1, shot.ph - insetBottom - safe)
    local desired = uiScale(shot) * (FloatingHud.MESSAGE.scale or 1)
    local drawScale = math.max(0.35, math.min(
      desired,
      availableW / logicalW,
      (availableH * 0.23) / logicalH))
    local w, h = logicalW * drawScale, logicalH * drawScale
    local x = left + (availableW - w) * 0.5
    -- Keep the message readable above the live START/SELECT controls. They are
    -- still visible and fully interactive; only the provider-owned text plate
    -- moves. Without touch controls the authored physical-bottom dock remains.
    local y = shot.ph - h
    local controlTop = FloatingHud.touchStartSelectTop(shot)
    if controlTop then
      local gutter = math.max(6, math.floor(math.min(shot.pw, shot.ph) * 0.015))
      y = math.min(y, controlTop - gutter - h)
      y = math.max(safe, y)
      -- Raising the mobile dialog above START/SELECT can overlap an actor
      -- and permanently retire the 3D battle. Fit its proportional plate in
      -- the clear gap below exact visible ink, without moving the controls.
      -- Keep at least native-size text (or the smaller user-selected scale)
      -- and at least 60% of the desired scale. If that cannot clear the actors,
      -- the unchanged camera-safety evaluator must still reject the seat.
      local bottom = y + h
      local minimumScale = math.min(drawScale, math.max(1, drawScale * .60))
      local padding = math.max(8, math.floor(math.min(shot.pw, shot.ph) * .012))
      for _=1,2 do
        local ceiling = y
        for _, side in ipairs({ "player", "enemy" }) do
          local visual = shot.actorVisuals and shot.actorVisuals[side]
          local hull = visual and visual.hull
          if hull and hull[1] < x + w + padding
              and hull[1] + hull[3] + padding > x
              and hull[2] < bottom + padding then
            ceiling = math.max(ceiling, hull[2] + hull[4] + padding + 1)
          end
        end
        local fitted = math.max(minimumScale,
          math.min(drawScale, (bottom - ceiling) / logicalH))
        drawScale = fitted
        w, h = logicalW * drawScale, logicalH * drawScale
        x, y = left + (availableW - w) * .5, bottom - h
      end
    end
    return { x, y, w, h }, drawScale, logicalW, logicalH
  end

  local s = tonumber(shot.scale) or 1
  local baseScale = uiScale(shot)
  local playerScale = shot.player and distanceScale(shot, "player") or 1
  local enemyScale = shot.enemy and distanceScale(shot, "enemy") or 1
  local pairScale = (playerScale + enemyScale) * 0.5
  local drawScale = baseScale * pairScale * (FloatingHud.MESSAGE.scale or 1)

  local px = shot.player and shot.player[1] or 80
  local py = shot.player and shot.player[2] or 96
  local ex = shot.enemy and shot.enemy[1] or 80
  local ey = shot.enemy and shot.enemy[2] or 56
  local cx = shot.lx + ((px + ex) * 0.5) * s
             + (FloatingHud.MESSAGE.xOffset or 0) * baseScale
  local cy = shot.ly + ((py + ey) * 0.5) * s
             + (FloatingHud.MESSAGE.yOffset or 25) * baseScale

  local w = logicalW * drawScale
  local h = logicalH * drawScale
  local x = cx - w * 0.5
  local y = cy - h * 0.5
  local margin = FloatingHud.MARGIN

  x = clamp(x, margin, math.max(margin, shot.pw - w - margin))
  y = clamp(y, margin, math.max(margin, shot.ph - h - margin))
  return { x, y, w, h }, drawScale, logicalW, logicalH
end

function HudRuntime.mapPanelHits(rect, scale, logicalHits)
  if not (rect and type(logicalHits) == "table") then return nil end
  local out = {}
  for _, hit in ipairs(logicalHits) do
    if hit and hit.x and hit.y and hit.w and hit.h then
      out[#out + 1] = {
        action=hit.action, index=hit.index,
        x=rect[1] + hit.x * scale,
        y=rect[2] + hit.y * scale,
        w=hit.w * scale, h=hit.h * scale,
      }
    end
  end
  return #out > 0 and out or nil
end

local function drawCommandPanel(battle, shot)
  if not (battle and battle.phase == "menu" and not battle.demo) then
    return false
  end

  local rect, k, logicalW, logicalH = HudRuntime.commandRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderCommandCanvas(battle, k, logicalW, logicalH)
  if not canvas then return false end
  battle._ascendantBattleHudCommandHits = HudRuntime.mapPanelHits(
    rect, k, battle._ascendantBattleHudCommandLogicalHits)

  local cx = rect[1] + rect[3] * 0.5
  local cy = rect[2] + rect[4] * 0.5
  FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "command")
  return true
end

local function drawFightPanel(battle, shot)
  if not (battle and battle.phase == "moveSelect"
      and battle.player and battle.player.curMoves
      and not battle.demo and not battle.safari) then
    return false
  end

  local rect, k, logicalW, logicalH = HudRuntime.fightRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderFightCanvas(battle, k, logicalW, logicalH)
  if not canvas then return false end
  battle._ascendantBattleHudMoveHits = HudRuntime.mapPanelHits(
    rect, k, battle._ascendantBattleHudMoveLogicalHits)

  local cx = rect[1] + rect[3] * 0.5
  local topPad = hudStyle() == "float"
    and math.max(0, tonumber(FloatingHud.FIGHT.canvasTopPad) or 0) or 0
  local cy = rect[2] + rect[4] * 0.5 - topPad * k * 0.5
  FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "fight")
  return true
end

local function drawLearnPanel(menu, battle, shot)
  if not (menu and menu.selecting and battle and shot) then
    return false
  end
  if hudStyle() == "float" and not selectPlateImage() then
    return false
  end
  local rect, k, logicalW, logicalH = HudRuntime.learnRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderLearnCanvas(menu, battle, k, logicalW, logicalH)
  if not canvas then return false end

  local cx = rect[1] + rect[3] * 0.5
  local cy = rect[2] + rect[4] * 0.5
  FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "learn")
  return true
end

local function messageCameraTransform()
  local layout = FloatingHud.MESSAGE
  local rawCameraSignal = cameraYawSignal()
  local neutralSignal = FloatingHud.CAMERA_CENTER_OFFSET or 0
  local cameraSignal = clamp(
    neutralSignal
      + (rawCameraSignal - neutralSignal) * (layout.cameraSignalGain or 2.50),
    -1, 1)
  local signal = clamp((layout.perspectiveBias or -0.28)
                       + cameraSignal * (layout.cameraInfluence or 0.80), -1, 1)
  local roll = math.rad((layout.baseRotationDeg or -7.0)
                        + cameraSignal * (layout.cameraRotationDeg or 2.0))
  local pitchSignal = -clamp(
    cameraPitchSignal() * (layout.pitchSignalGain or 1.0)
      * (layout.pitchInfluence or 0.35),
    0, 1)
  return signal, roll, pitchSignal
end

local function drawMessagePanel(battle, shot)
  if not battleMessageActive(battle) then return false end
  if battle.demo then return false end

  local rect, k, logicalW, logicalH = HudRuntime.messageRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderMessageCanvas(battle, k, logicalW, logicalH)
  if not canvas then return false end

  local layout = FloatingHud.MESSAGE
  local signal, roll, pitchSignal = messageCameraTransform()
  local cx = rect[1] + rect[3] * 0.5
  local cy = rect[2] + rect[4] * 0.5

  if hudStyle() == "float" then
    drawPerspectiveCanvas(canvas, cx, cy, cw * k, ch * k, signal, roll, "message",
                          layout.perspectiveDepth or 0.32,
                          layout.perspectiveWidthSqueeze or 0.12,
                          pitchSignal,
                          layout.pitchPerspectiveDepth or 0.16,
                          layout.pitchHeightSqueeze or 0.05)
  else
    FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "message")
  end
  return true
end


local function drawMoveLearnMessagePanel(box, battle, shot)
  if not (box and battle and shot) then return false end
  local rect, k, logicalW, logicalH = HudRuntime.messageRectFor(shot)
  if not rect then return false end
  local canvas, cw, ch = renderMoveLearnMessageCanvas(box, k, logicalW, logicalH)
  if not canvas then return false end

  local layout = FloatingHud.MESSAGE
  local signal, roll, pitchSignal = messageCameraTransform()
  local cx = rect[1] + rect[3] * 0.5
  local cy = rect[2] + rect[4] * 0.5
  if hudStyle() == "float" then
    drawPerspectiveCanvas(canvas, cx, cy, cw * k, ch * k, signal, roll,
                          "learn_message",
                          layout.perspectiveDepth or 0.32,
                          layout.perspectiveWidthSqueeze or 0.12,
                          pitchSignal,
                          layout.pitchPerspectiveDepth or 0.16,
                          layout.pitchHeightSqueeze or 0.05)
  else
    FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "learn_message")
  end
  return true
end

local function drawChoicePanel(choice, battle, shot)
  if not (choice and battle and shot) then return false end
  local messageRect, k = HudRuntime.messageRectFor(shot)
  if not (messageRect and k) then return false end

  local canvas, cw, ch, logicalW, logicalH = renderChoiceCanvas(choice, k)
  if not canvas then return false end

  local layout = FloatingHud.CHOICE
  local planeW = logicalW * k
  local planeH = logicalH * k
  local cx = messageRect[1] + messageRect[3]
             - planeW * 0.5 + (layout.rightOffset or -2) * k
  local cy = messageRect[2] - planeH * 0.5 - (layout.aboveGap or 2) * k
  local signal, roll, pitchSignal = messageCameraTransform()
  local msg = FloatingHud.MESSAGE

  if hudStyle() == "float" then
    drawPerspectiveCanvas(canvas, cx, cy, cw * k, ch * k, signal, roll, "choice",
                          msg.perspectiveDepth or 0.32,
                          msg.perspectiveWidthSqueeze or 0.12,
                          pitchSignal,
                          msg.pitchPerspectiveDepth or 0.16,
                          msg.pitchHeightSqueeze or 0.05)
  else
    FloatingHud.drawMenuPlane(canvas, cx, cy, cw * k, ch * k, "choice")
  end
  return true
end

local function drawBattleFlowPanel(battle, shot)
  if not floatingCommandsEnabled(battle) then return nil end
  if battle then
    -- Hit zones are receipts for the controls actually painted this frame.
    -- Clear stale geometry before any message/submenu can take ownership.
    battle._ascendantBattleHudCommandHits = nil
    battle._ascendantBattleHudMoveHits = nil
  end

  local game = battle and battle.game
  local top = game and HudRuntime.topState(game) or nil

  -- Caught-Pokemon AskName uses a native TextBox with opts.choice. The stock
  -- renderer blanks the entire battle behind it; when we claim this semantic
  -- flow we keep the staged scene visible and project both the native text and
  -- its native ChoiceBox with the same message / YES-NO surfaces used elsewhere.
  if HudRuntime.nicknameOverlayActiveForBattle(battle) then
    local text = battle._floatingBattleNicknameText
    local choice = battle._floatingBattleChoice
    if choice and top == choice and HudRuntime.stateInStack(game, choice)
        and choice.__floatingBattleChoiceText == text then
      local drewMessage = drawMoveLearnMessagePanel(text, battle, shot)
      local drewChoice = drawChoicePanel(choice, battle, shot)
      if drewMessage or drewChoice then
        battle._floatingBattleNicknameSceneFrame = battle.frame
        battle._floatingBattleChoiceSceneFrame = battle.frame
      end
      return "nickname"
    end
    if text and top == text and HudRuntime.stateInStack(game, text) then
      if drawMoveLearnMessagePanel(text, battle, shot) then
        battle._floatingBattleNicknameSceneFrame = battle.frame
      end
      return "nickname"
    end
    return "nickname"
  end

  -- Pushed foregrounds (MoveLearnMenu/TextBox/ChoiceBox) must be painted into
  -- shot.canvas too. Desktop can get away with drawing these in render.hud after
  -- the battle viewport is composed; Android/iOS cannot reliably do so. This is
  -- the same fix that made PKMN and ITEM visible on mobile in v0.7.1.
  if HudRuntime.moveLearnOverlayActiveForBattle(battle) then
    local choice = battle._floatingBattleChoice
    if choice and top == choice and HudRuntime.stateInStack(game, choice) then
      local sourceText = choice.__floatingBattleChoiceText
      local drewMessage = false
      if sourceText and HudRuntime.stateInStack(game, sourceText) then
        drewMessage = drawMoveLearnMessagePanel(sourceText, battle, shot)
      end
      local drewChoice = drawChoicePanel(choice, battle, shot)
      if drewMessage or drewChoice then
        battle._floatingBattleMoveLearnSceneFrame = battle.frame
        battle._floatingBattleChoiceSceneFrame = battle.frame
      end
      return "learn"
    end

    local text = battle._floatingBattleMoveLearnText
    if text and top == text and HudRuntime.stateInStack(game, text) then
      if drawMoveLearnMessagePanel(text, battle, shot) then
        battle._floatingBattleMoveLearnSceneFrame = battle.frame
      end
      return "learn"
    end

    local menu = battle._floatingBattleMoveLearnMenu
    if menu and top == menu and menu.selecting
        and HudRuntime.stateInStack(game, menu) then
      menu.isOpaque = false
      if drawLearnPanel(menu, battle, shot) then
        battle._floatingBattleMoveLearnSceneFrame = battle.frame
      end
      return "learn"
    end

    -- Keep the old battle text suppressed during a transient learn-flow frame,
    -- even if the pushed state changed between update and draw.
    return "learn"
  end

  -- Ordinary battle ChoiceBox uses the same scene-canvas route. This also keeps
  -- trainer switch YES/NO prompts visible on mobile before their PKMN picker is
  -- created.
  local choice = battle and battle._floatingBattleChoice or nil
  if choice and top == choice and HudRuntime.stateInStack(game, choice) then
    local drewMessage = drawMessagePanel(battle, shot)
    local drewChoice = drawChoicePanel(choice, battle, shot)
    if drewMessage or drewChoice then
      battle._floatingBattleChoiceSceneFrame = battle.frame
    end
    return "messages"
  end

  -- PKMN is a pushed state rather than a BattleState phase. Paint it directly
  -- into the staged scene; render.hud remains only a fallback. BAG deliberately
  -- stays on the registered BagMenu screen owned by Useful Bag/KASC/the engine.
  if HudRuntime.partyOverlayActiveForBattle(battle) then
    local menu = battle._floatingBattlePartyMenu
    if menu and drawPartyPanel(menu, battle, shot) then
      battle._floatingBattlePartySceneFrame = battle.frame
    end
    return "party"
  end
  if drawMessagePanel(battle, shot) then return "messages" end
  if drawCommandPanel(battle, shot) then return "menu" end
  if drawFightPanel(battle, shot) then return "moves" end
  return nil
end

local function bottomOwnedThisFrame(battle)
  if not battle then return false end
  local owned = battle._floatingBattleBottomDrawn
  return (owned == "messages" and battle.phase == "messages")
      or (owned == "menu" and battle.phase == "menu")
      or (owned == "moves" and battle.phase == "moveSelect")
      or (owned == "party" and HudRuntime.partyOverlayActiveForBattle(battle))
      or (owned == "learn" and HudRuntime.moveLearnOverlayActiveForBattle(battle))
      or (owned == "nickname"
          and HudRuntime.nicknameOverlayActiveForBattle(battle))
end

local function drawTextGlass(battle, shot)
  -- Legacy Dramatic Shape only. PotatoVoxel and Voxel Ascendant use their
  -- own panel/native-paper paths instead of this donor composite.
  if not (BattleHud and OverworldBattle.textRects) then return end
  for _, rect in pairs(OverworldBattle.textRects(battle)) do
    BattleHud.panel(toWorld(rect, shot), shot, true)
  end
end

local function vrActive()
  local ok, vr = pcall(V.require, "VR")
  return ok and vr and vr.active and vr.active() or false
end

local function supportedFloatingLayout(battle)
  if not battle then return false end
  if vrActive() then return false end
  if OverworldBattle.backPinned and OverworldBattle.backPinned(battle) then return false end
  -- Safari has no player battler, but its enemy status, ball counter and
  -- BALL/BAIT/ROCK/RUN flow are fully represented by the ORAS provider.
  -- Scripted catch demos remain native because they drive their own cursor.
  if battle.demo then return false end
  return true
end

-- ---------------------------------------------------------------------------
-- Host integration
-- ---------------------------------------------------------------------------

local hostMode = nil

-- Replacement-HUD lifecycle shared by both voxel hosts. A send-out owns a
-- battler before its first drawable actor exists: the engine's grow-in starts
-- with three empty frames, then exposes only 3/7 and 5/7 silhouettes. Declaring
-- the status plate live in that interval creates a circular camera dependency:
-- camera safety asks for an exact actor receipt which the current render cannot
-- publish yet. Keep only that growing side out of status ownership until its
-- first full frame; the other side and every non-grow transition retain their
-- existing ownership.
-- This remains independent of statusHUDVisible(), because Potato suppresses
-- that native surface and consulting it would hide us.
local function floatingHudLive(battle, slide)
  if not battle then return false, false end

  local growing = type(battle.growIn) == "table"
    and battle.growIn.battler or nil
  local enemy = battle.enemy and not battle.enemy.fainted
                and not battle.showEnemyTrainer
                and not battle.enemySendingOut and growing ~= battle.enemy
  local player = battle.player and not battle.player.fainted
                 and not (battle.safari or battle.demo)
                 and not battle.showPlayerBack and not battle.sendingOut
                 and growing ~= battle.player
  return enemy and true or false, player and true or false
end

-- Safari's BALLxNN count is authored inside the native text-area command row,
-- not in a player status card. Once ORAS owns that bottom surface the count
-- therefore needs an explicit replacement. Keep it compact and independent
-- of the enemy card so capture/escape messages cannot make the remaining
-- inventory disappear for a frame.
function FloatingHud.safariBallCountBounds(battle, shot)
  if not (battle and type(battle.safari) == "table" and shot
      and tonumber(shot.pw) and tonumber(shot.ph)) then return nil end
  local _, insetTop = FloatingHud.safeInsets(shot)
  return {
    shot.pw * .325, (insetTop or 0) + 4,
    shot.pw * .35, math.max(24, shot.ph * .075),
  }
end

local function drawSafariBallCount(battle, shot)
  if not (battle and type(battle.safari) == "table" and shot) then
    return false
  end
  local balls = math.max(0, math.floor(tonumber(battle.safari.balls) or 0))
  local label = (hudLanguage() == "de" and "SAFARI-BÄLLE " or "SAFARI BALLS ")
    .. tostring(balls)
  local scale = math.max(0.72, math.min(1.15, uiScale(shot) * 0.48))
  local paddingX, paddingY = 10 * scale, 5 * scale
  local w = textWidth(label) * scale + paddingX * 2
  local h = 8 * scale + paddingY * 2
  local insetLeft, insetTop, insetRight = FloatingHud.safeInsets(shot)
  local x = clamp((shot.pw - w) * 0.5,
                  insetLeft + 4, shot.pw - insetRight - w - 4)
  local y = insetTop + 5
  g.setColor(0.008, 0.030, 0.046,
             0.94 * FloatingHud.statusGlassStrength())
  g.rectangle("fill", x, y, w, h, 7 * scale, 7 * scale)
  g.setColor(0.22, 0.86, 1.00, 0.94)
  g.setLineWidth(math.max(1, scale))
  g.rectangle("line", x, y, w, h, 7 * scale, 7 * scale)
  g.setLineWidth(1)
  drawShadowTextCentered(label, x + w * 0.5, y + paddingY, 1, scale)
  return true
end

-- Draw every piece of floating battle UI that belongs in the 3D world canvas.
-- Return two independent ownership flags: status plates and bottom flow UI.
-- This separation lets unfinished phases (party/items) keep using the native
-- renderer until their own floating replacement exists.
local function drawFloatingSceneUI(battle, shot, includeTextGlass, deferCommit)
  if battle and battle.game then activeRuntimeGame = battle.game end
  if battle then FloatingHud.observeMegaFormTransitions(battle) end
  if battle then battle._floatingBattleBottomDrawn = nil end
  if not (battle and shot and shot.canvas and (shot.scale or 0) > 0) then
    return false, false
  end
  if not supportedFloatingLayout(battle) then return false, false end

  local wantsStatus = floatingStatusHudEnabled(battle)
  local wantsCommands = floatingCommandsEnabled(battle)
  if not wantsStatus and not wantsCommands then return false, false end

  local statusAssetsReady = FloatingHud.statusAssetsReady()
  local slide = (battle.introSlide or 0) * 4
  local enemyLive, playerLive = floatingHudLive(battle, slide)
  local statusDrawn = false
  local statusComplete = not wantsStatus or not (enemyLive or playerLive)
  local statusProposal = nil
  local bottomKind = nil

  local statusReserved = {}
  if wantsCommands and not battle.introBalls then
    local rect
    if battle.phase == "menu" then
      rect = HudRuntime.commandRectFor(shot)
    elseif battle.phase == "moveSelect" and not battle.safari then
      rect = HudRuntime.fightRectFor(shot)
    elseif battle.phase == "messages" or battleMessageActive(battle) then
      rect = HudRuntime.messageRectFor(shot)
    end
    if rect then statusReserved[#statusReserved + 1] = rect end
  end
  -- Safari's counter is status furniture too. Feed its exact public band into
  -- the same proposal the renderer later commits; otherwise a portrait CORNERS
  -- card can be accepted underneath the visible ball count.
  local safariStatusRect = FloatingHud.safariBallCountBounds(battle, shot)
  if safariStatusRect then
    statusReserved[#statusReserved + 1] = safariStatusRect
  end

  local prevCanvas = g.getCanvas()
  local prevBlend, prevAlpha = g.getBlendMode()
  local prevShader = g.getShader()
  local prevPreflipHeight = FloatingHud.activeWorldPreflipHeight
  if isAscendantHost and PLATFORM_OS == "iOS"
      and not FloatingHud.providerCanvasUpright then
    FloatingHud.activeWorldPreflipHeight = shot.ph
  end
  local ok, err = pcall(function()
    g.setCanvas(shot.canvas)
    g.setBlendMode("alpha")
    g.setShader()
    g.setColor(1, 1, 1, 1)

    -- The transformation belongs to the Pokémon layer: it follows the active
    -- projected battler, while status cards and every interactive control are
    -- drawn afterwards and therefore remain perfectly readable/clickable.
    FloatingHud.drawMegaTransformation(battle, shot)

    local enemyCard, playerCard
    if wantsStatus and statusAssetsReady and (enemyLive or playerLive) then
      statusProposal = FloatingHud.proposeStatusLatch(
        battle, shot, playerLive, enemyLive, statusReserved)
      local displaySlots = FloatingHud.statusSlotsForPresentation(
        battle, statusProposal, playerLive, enemyLive)
      local pose = {
        slots=displaySlots or {},
        signal=0, roll=0, mode="owner-screen-latched",
      }
      local payloads = FloatingHud.bindStatusPayloads(battle, pose)
      local function prepared(side, payload)
        local rect = payload and payload.rect
        local logicalW, logicalH = plateSize(side)
        if not (rect and logicalW and logicalH) then return nil end
        return {
          rect=rect, k=rect[3] / logicalW,
          logicalW=logicalW, logicalH=logicalH,
          signal=pose.signal, roll=pose.roll,
          binding=side, battler=payload.battler, motionMode=pose.mode,
        }
      end
      enemyCard = prepared("enemy", payloads.enemy)
      playerCard = prepared("player", payloads.player)
    end
    local enemyDrew, playerDrew = not enemyLive, not playerLive
    if enemyCard then
      enemyDrew = drawCard(
        battle, shot, "enemy", enemyCard.battler, enemyCard)
      statusDrawn = enemyDrew or statusDrawn
    end
    if playerCard then
      playerDrew = drawCard(
        battle, shot, "player", playerCard.battler, playerCard)
      statusDrawn = playerDrew or statusDrawn
    end
    statusComplete = statusProposal ~= nil
      and (statusProposal.complete
        or statusProposal.displayedFromCommittedSlots == true)
      and enemyDrew and playerDrew
    if battle.safari then
      statusDrawn = drawSafariBallCount(battle, shot) or statusDrawn
    end

    if wantsCommands then
      bottomKind = drawBattleFlowPanel(battle, shot)
    end

    -- Dramatic Shape's frosted donor panel remains useful for battle phases we
    -- have not replaced yet. During the opening party-ball window it is only a
    -- translucent copy of Gen1's empty text box: the authoritative introText is
    -- queued immediately afterwards and drawMessagePanel projects that text
    -- through our own plate. Do not leave the donor rectangle underneath it.
    if includeTextGlass and not bottomKind and not battle.introBalls then
      drawTextGlass(battle, shot)
    end
  end)

  g.setShader(prevShader)
  FloatingHud.activeWorldPreflipHeight = prevPreflipHeight
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)

  if not ok then
    battle._floatingBattleBottomDrawn = nil
    mod.log:warn("floating battle UI draw failed: %s", tostring(err))
    return false, false, nil, false
  end

  if statusComplete and statusProposal and statusProposal.complete
      and not deferCommit
      and not FloatingHud.commitStatusLatch(statusProposal) then
    statusComplete, statusDrawn = false, false
  end

  -- The engine's SE_WAVY_SCREEN only bends its now-mostly-empty 160x144 BG
  -- canvas. Once our floating surfaces are safely on the staged scene, bend
  -- that scene too so Psychic's second half remains visible in voxel battles.
  local waveOk, waveErr = pcall(applySceneWave, battle, shot)
  if not waveOk and not sceneWaveWarned then
    sceneWaveWarned = true
    mod.log:warn("floating battle scene wave failed: %s", tostring(waveErr))
  end

  battle._floatingBattleBottomDrawn = bottomKind
  if reportPerformanceHud then
    local player = statusProposal and statusProposal.slots
      and statusProposal.slots.player
    local enemy = statusProposal and statusProposal.slots
      and statusProposal.slots.enemy
    local playerRect = player and player.rect
    local enemyRect = enemy and enemy.rect
    local orientation
    if love and love.window
        and type(love.window.getDisplayOrientation) == "function" then
      local sampled, value = pcall(love.window.getDisplayOrientation)
      if sampled then orientation = value end
    end
    pcall(reportPerformanceHud, {
      hud="GEN1-ORAS", viewportWidth=shot.pw, viewportHeight=shot.ph,
      orientation=orientation, source=PLATFORM_OS or "desktop",
      inBounds=not statusProposal or statusProposal.safe ~= false,
      orientationOk=true,
      reason=statusProposal and (statusProposal.safe
        and "anchors-in-bounds" or "status-anchor-unsafe")
        or "status-not-present",
      playerX=playerRect and playerRect[1], playerY=playerRect and playerRect[2],
      playerWidth=playerRect and playerRect[3],
      playerHeight=playerRect and playerRect[4],
      enemyX=enemyRect and enemyRect[1], enemyY=enemyRect and enemyRect[2],
      enemyWidth=enemyRect and enemyRect[3], enemyHeight=enemyRect and enemyRect[4],
    })
  end
  return statusDrawn, bottomKind ~= nil, statusProposal, statusComplete
end

-- The temporary party-ball rows are fields inside BattleState:drawHUDs, not a
-- separate visibility surface. Older builds hid them by running the whole
-- method under an empty scissor. That was too broad: host or engine additions
-- to drawHUDs (including animation-time presentation) disappeared with them.
-- Mask only the two ball-row inputs and let the status visibility hook below
-- continue to suppress the ordinary native HP/name blocks.
local function drawHUDsWithoutNativeBallRows(draw, battle, ...)
  local introBalls = rawget(battle, "introBalls")
  local showEnemyBalls = rawget(battle, "showEnemyBalls")
  battle.introBalls = nil
  battle.showEnemyBalls = nil
  local ok, a, b, c = pcall(draw, battle, ...)
  battle.introBalls = introBalls
  battle.showEnemyBalls = showEnemyBalls
  if not ok then error(a, 0) end
  return a, b, c
end

-- Preserve arbitrary hook return tuples while still restoring temporarily
-- shadowed host state after a protected call.
function FloatingHud.packValues(...)
  return { n=select("#", ...), ... }
end
FloatingHud.unpackValues = table.unpack or unpack

-- A companion overlay may yield only after VASC has committed replacement
-- pixels for THIS exact staged frame.  A live-looking shot pointer or the old
-- boolean alone is insufficient: either can survive briefly across a failed
-- provider draw or a frame transition and would erase the only readable HUD.
function FloatingHud.hasExactHudSnapReceipt(battle)
  if type(battle) ~= "table"
      or type(OverworldBattle.hudSnapReceipt) ~= "function" then
    return false
  end
  local shot = rawget(battle, "voxelAscendantShot")
  if shot == nil then return false end
  local ok, receipt = pcall(OverworldBattle.hudSnapReceipt, battle)
  return ok and type(receipt) == "table"
    and receipt.schema == "voxel-ascendant/hud-snap/v1"
    and receipt.snapped == true
    and type(receipt.owner) == "string" and receipt.owner ~= ""
    and receipt.shot == shot
end

-- An exact frame receipt establishes presentation ownership for this battle,
-- not for the current actor canvas. Throw/send-out/switch/attack phases can
-- replace the staged shot while the same BattleState remains live; keeping
-- this latch on that exact table lets the ORAS provider bridge those expected
-- actor-receipt gaps without ever leaking ownership into the next battle.
local BATTLE_HUD_OWNER_LATCH_SCHEMA =
  "voxel-ascendant/oras-battle-owner-latch/v1"

function FloatingHud.battleHudOwnerLatched(battle)
  local latch = type(battle) == "table"
    and rawget(battle, "_ascendantBattleHudOwnerLatch") or nil
  return type(latch) == "table"
    and latch.schema == BATTLE_HUD_OWNER_LATCH_SCHEMA
    and latch.battle == battle
    and type(latch.owner) == "string" and latch.owner ~= ""
end

function FloatingHud.latchExactBattleHudOwner(battle)
  if not FloatingHud.hasExactHudSnapReceipt(battle) then return false end
  local ok, receipt = pcall(OverworldBattle.hudSnapReceipt, battle)
  if not (ok and type(receipt) == "table") then return false end
  battle._ascendantBattleHudOwnerLatch = {
    schema=BATTLE_HUD_OWNER_LATCH_SCHEMA,
    battle=battle,
    owner=receipt.owner,
    shot=receipt.shot,
  }
  return true
end

-- Only bridge a stale-but-successful receipt from the SAME established owner.
-- A provider error publishes snapped=false and therefore still fails open to
-- the native UI; the battle latch must never turn a real failure into a blank
-- frame merely because an older ORAS frame once succeeded.
function FloatingHud.hasBattleHudOwnerContinuity(battle)
  if not FloatingHud.battleHudOwnerLatched(battle)
      or type(OverworldBattle.hudSnapReceipt) ~= "function" then
    return false
  end
  -- AskName and a genuinely retired staged renderer deliberately clear the
  -- current shot. An old owner may bridge shot identity, never shot absence.
  if rawget(battle, "voxelAscendantShot") == nil then return false end
  local ok, receipt = pcall(OverworldBattle.hudSnapReceipt, battle)
  local latch = rawget(battle, "_ascendantBattleHudOwnerLatch")
  return ok and type(receipt) == "table"
    and receipt.schema == "voxel-ascendant/hud-snap/v1"
    and receipt.snapped == true
    and receipt.owner == latch.owner
end

function FloatingHud.clearBattleHudOwner(battle)
  if type(battle) ~= "table" then return false end
  battle._ascendantBattleHudOwnerLatch = nil
  return true
end

-- VASC reserves its edge HUD inside the staged world canvas before BattleState
-- reaches the public drawHudPanels seam. Replacing only the dynamic status
-- source lets the host retain its snapshot receipt while drawing transparent
-- native bands; our cards are then painted exactly once by drawHudPanels.
FloatingHud.iosBlankStatusLayer = nil
function FloatingHud.blankIosStatusLayer()
  if not FloatingHud.iosBlankStatusLayer then
    local ok, canvas = pcall(g.newCanvas, 160, 144, { dpiscale = 1 })
    if not (ok and canvas) then return nil end
    pcall(canvas.setFilter, canvas, "nearest", "nearest")
    FloatingHud.iosBlankStatusLayer = canvas
  end
  local previous = g.getCanvas()
  local blend, alpha = g.getBlendMode()
  g.setCanvas(FloatingHud.iosBlankStatusLayer)
  g.clear(0, 0, 0, 0)
  if previous then g.setCanvas(previous) else g.setCanvas() end
  g.setBlendMode(blend or "alpha", alpha)
  return FloatingHud.iosBlankStatusLayer
end

function FloatingHud.ownsHostStatus(battle)
  return isAscendantHost
    and supportedFloatingLayout(battle)
    and floatingStatusHudEnabled(battle)
    and FloatingHud.statusAssetsReady()
end

function FloatingHud.ownsHostCommands(battle)
  return isAscendantHost
    and supportedFloatingLayout(battle)
    and floatingCommandsEnabled(battle)
    and FloatingHud.commandAssetsReady()
end

function FloatingHud.iosOwnsStatus(battle)
  return PLATFORM_OS == "iOS" and FloatingHud.ownsHostStatus(battle)
end

function FloatingHud.iosOwnsCommands(battle)
  return PLATFORM_OS == "iOS" and FloatingHud.ownsHostCommands(battle)
end

-- Desktop/Android VASC calls snapHUDs during update and bakes textTexture into
-- shot.canvas before drawHudPanels runs. Suppressing BattleState:drawTextArea
-- later is therefore too late. Remove the native text placements at the live
-- snapshot source; VASC still completes and receipts the snap, but has no old
-- frame, command labels or move box to composite.
if isAscendantHost and not hostProviderAvailable
    and type(OverworldBattle.textPlacements) == "function" then
  FloatingHud.baseHostTextPlacements = OverworldBattle.textPlacements
  OverworldBattle.textPlacements = function(battle, ...)
    if FloatingHud.ownsHostCommands(battle) then return {} end
    return FloatingHud.baseHostTextPlacements(battle, ...)
  end
end

if isAscendantHost and not hostProviderAvailable then
  local baseHudTexture = OverworldBattle.hudTexture
  local baseHudLive = OverworldBattle.hudLive
  local basePartyRects = OverworldBattle.partyRects

  if type(baseHudTexture) == "function" then
    OverworldBattle.hudTexture = function(battle, ...)
      if FloatingHud.ownsHostStatus(battle) then
        return FloatingHud.blankIosStatusLayer() or baseHudTexture(battle, ...)
      end
      return baseHudTexture(battle, ...)
    end
  end
  if type(baseHudLive) == "function" then
    OverworldBattle.hudLive = function(battle, ...)
      if FloatingHud.ownsHostStatus(battle) then return false, false end
      return baseHudLive(battle, ...)
    end
  end
  if type(basePartyRects) == "function" then
    OverworldBattle.partyRects = function(battle, ...)
      if FloatingHud.ownsHostStatus(battle) then return {} end
      return basePartyRects(battle, ...)
    end
  end

end

-- BattlePartyBalls is intentionally absent from VASC's public module facade.
-- Its late fallback does expose one stable seam: the battle.overlay hook skips
-- persistent rows while the host's snapshot receipt is true. Shadow that receipt
-- only for this draw call and restore the exact old value immediately afterward.
if isAscendantHost and mod.hooks and type(mod.hooks.wrap) == "function" then
  mod.hooks:wrap("battle.overlay", function(nextOverlay, battle, ...)
    if not (FloatingHud.ownsHostStatus(battle)
        and FloatingHud.hasExactHudSnapReceipt(battle)) then
      return nextOverlay(battle, ...)
    end
    local previous = rawget(battle, "voxelAscendantHudSnapped")
    battle.voxelAscendantHudSnapped = true
    local results = FloatingHud.packValues(pcall(nextOverlay, battle, ...))
    battle.voxelAscendantHudSnapped = previous
    if not results[1] then error(results[2], 0) end
    return FloatingHud.unpackValues(results, 2, results.n)
  end, 12000)
end

if isAscendantHost and not hostFloatingAvailable then
  -- Native fallback by design. Do not install any pixel suppression or menu
  -- ownership on iOS/unknown Ascendant platforms; all helpers above also report
  -- their floating layers disabled, so the rest of the file stays transparent.
  hostMode = "voxel_ascendant_ios_fallback"

elseif isAscendantHost and hostProviderAvailable then
  -- Modern VASC owns the authoritative shot, pre-flip and lifecycle receipt.
  -- The provider registered below is the only pixel path; legacy panel/snap
  -- wrappers would otherwise draw the complete ORAS HUD a second time.
  hostMode = INTEGRATED_KASC and "voxel_ascendant_kasc_provider"
                                 or "voxel_ascendant_default_provider"

elseif isAscendantHost and type(OverworldBattle.drawHudPanels) == "function" then
  -- Voxel Ascendant's live path mirrors the modern panel-host seam: BattleState
  -- stores voxelAscendantShot, binds the world override, then calls drawHudPanels
  -- before the engine's own battle UI. Paint into that shot.canvas here.
  hostMode = "voxel_ascendant"

  local PANEL_KEY = "_floatingBattleHudBaseDrawHudPanels"
  if not OverworldBattle[PANEL_KEY] then
    OverworldBattle[PANEL_KEY] = OverworldBattle.drawHudPanels
  end
  local baseDrawHudPanels = OverworldBattle[PANEL_KEY]

  function FloatingHud.drawPanelHostHudPanels(battle)
    if not battle then return baseDrawHudPanels(battle) end
    if type(OverworldBattle.hudSnapReceipt) == "function" then
      local receipt = OverworldBattle.hudSnapReceipt(battle)
      if type(receipt) == "table" and receipt.owner == "kanto_ascendant.oras"
          and receipt.shot == battleShot(battle) and receipt.snapped == true then
        return
      end
    end
    FloatingHud.installNativeTextSuppression()
    FloatingHud.installBattleTextSink(battle)
    FloatingHud.installKascOverlaySuppression(battle)
    battle._floatingBattleHudPanelDrawn = false
    local shot = battleShot(battle)
    local statusDrawn, bottomDrawn = drawFloatingSceneUI(battle, shot, false)
    if statusDrawn then
      battle._floatingBattleHudPanelDrawn = true
    end
    -- Before introText becomes the current queue item there is intentionally no
    -- custom message to paint. Still claim the panel host for that short
    -- introBalls window so its empty translucent native rectangle cannot leak.
    if statusDrawn or bottomDrawn
        or (floatingCommandsEnabled(battle) and battle.introBalls
            and supportedFloatingLayout(battle)) then
      return
    end
    return baseDrawHudPanels(battle)
  end

  OverworldBattle.drawHudPanels = FloatingHud.drawPanelHostHudPanels

  local DRAW_KEY = "_floatingBattleHudBaseDrawHUDs"
  if not BattleState[DRAW_KEY] then BattleState[DRAW_KEY] = BattleState.drawHUDs end
  local baseDrawHUDs = BattleState[DRAW_KEY]
  if type(baseDrawHUDs) == "function" then
    function BattleState:drawHUDs(...)
      local owns = floatingStatusHudEnabled(self)
                   and battleShot(self)
                   and FloatingHud.statusAssetsReady()
      if owns then
        return drawHUDsWithoutNativeBallRows(baseDrawHUDs, self, ...)
      end
      return baseDrawHUDs(self, ...)
    end
  end

  local statusHookInstalled = false
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("battle.status_hud_visible", function(next, state)
      if floatingStatusHudEnabled(state) and state and battleShot(state)
          and supportedFloatingLayout(state)
          and FloatingHud.statusAssetsReady() then
        return false
      end
      return next(state)
    end, 12000)
    statusHookInstalled = true
  end

  if not statusHookInstalled then
    local STATUS_KEY = "_floatingBattleHudBaseStatusHUDVisible"
    if not BattleState[STATUS_KEY] then
      BattleState[STATUS_KEY] = BattleState.statusHUDVisible
    end
    local baseStatusHUDVisible = BattleState[STATUS_KEY]
    if type(baseStatusHUDVisible) == "function" then
      function BattleState:statusHUDVisible(...)
        if floatingStatusHudEnabled(self) and battleShot(self)
            and supportedFloatingLayout(self)
            and FloatingHud.statusAssetsReady() then
          return false
        end
        return baseStatusHUDVisible(self, ...)
      end
    end
  end

elseif type(OverworldBattle.snapHUDs) == "function" then
  -- Dramatic Shape 1.6.x path: it asks snapHUDs to composite HUD furniture into
  -- the window-resolution world canvas, then suppresses the native HUD itself.
  hostMode = "dramatic_shape"
  local BASE_KEY = "_floatingBattleHudBaseSnapHUDs"
  if not OverworldBattle[BASE_KEY] then
    OverworldBattle[BASE_KEY] = OverworldBattle.snapHUDs
  end
  local baseSnapHUDs = OverworldBattle[BASE_KEY]

  function FloatingHud.snapHUDs(battle, shot)
    FloatingHud.installNativeTextSuppression()
    FloatingHud.installBattleTextSink(battle)
    FloatingHud.installKascOverlaySuppression(battle)
    local wantStatus = floatingStatusHudEnabled(battle)
    local wantCommands = floatingCommandsEnabled(battle)
    battle._floatingBattleHudPanelDrawn = false

    if not wantStatus and not wantCommands then
      return baseSnapHUDs(battle, shot)
    end

    local statusDrawn, bottomDrawn = drawFloatingSceneUI(battle, shot, true)
    if statusDrawn then
      battle._floatingBattleHudPanelDrawn = true
    end

    if not wantStatus and bottomDrawn then
      local nativeTextRects = OverworldBattle.textRects
      if type(nativeTextRects) == "function" then
        OverworldBattle.textRects = function() return {} end
      end
      local ok, nativeUp = pcall(baseSnapHUDs, battle, shot)
      OverworldBattle.textRects = nativeTextRects
      if not ok then error(nativeUp, 0) end
      return nativeUp or true
    end

    -- introBalls begins before the trainer-challenge message becomes current.
    -- Claim that silent lead-in too; otherwise baseSnapHUDs reconstructs the
    -- empty frosted text rectangle we deliberately withheld above.
    if statusDrawn or bottomDrawn
        or (wantCommands and battle.introBalls
            and supportedFloatingLayout(battle)) then
      return true
    end
    return baseSnapHUDs(battle, shot)
  end

  OverworldBattle.snapHUDs = FloatingHud.snapHUDs

  -- Gen1Recomp draws the temporary trainer/player Poké Ball rows inside
  -- BattleState:drawHUDs, independently of the lower-UI visibility predicate.
  -- Keep the method alive for renderer lifecycle compatibility, mask only those
  -- row inputs, and suppress its ordinary status blocks through the semantic
  -- visibility seam below. This is deliberately BattleState-scoped: overworld
  -- TextBox rendering never passes through it.
  local DRAW_KEY = "_floatingBattleHudBaseDrawHUDs"
  if not BattleState[DRAW_KEY] then BattleState[DRAW_KEY] = BattleState.drawHUDs end
  local baseDrawHUDs = BattleState[DRAW_KEY]
  if type(baseDrawHUDs) == "function" then
    function BattleState:drawHUDs(...)
      local owns = floatingStatusHudEnabled(self)
                   and battleShot(self)
                   and FloatingHud.statusAssetsReady()
                   and not self.demo
      if owns then
        return drawHUDsWithoutNativeBallRows(baseDrawHUDs, self, ...)
      end
      return baseDrawHUDs(self, ...)
    end
  end

  local statusHookInstalled = false
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("battle.status_hud_visible", function(next, state)
      if floatingStatusHudEnabled(state) and state and battleShot(state)
          and supportedFloatingLayout(state)
          and FloatingHud.statusAssetsReady() then
        return false
      end
      return next(state)
    end, 12000)
    statusHookInstalled = true
  end

  if not statusHookInstalled then
    local STATUS_KEY = "_floatingBattleHudBaseStatusHUDVisible"
    if not BattleState[STATUS_KEY] then
      BattleState[STATUS_KEY] = BattleState.statusHUDVisible
    end
    local baseStatusHUDVisible = BattleState[STATUS_KEY]
    if type(baseStatusHUDVisible) == "function" then
      function BattleState:statusHUDVisible(...)
        if floatingStatusHudEnabled(self) and battleShot(self)
            and supportedFloatingLayout(self)
            and FloatingHud.statusAssetsReady() then
          return false
        end
        return baseStatusHUDVisible(self, ...)
      end
    end
  end

elseif type(OverworldBattle.drawHudPanels) == "function" then
  -- PotatoVoxel path. Like Ascendant, BattleState calls drawHudPanels before the
  -- native battle UI; the only host difference is the BattleState shot field.
  hostMode = "potato_voxel"

  local PANEL_KEY = "_floatingBattleHudBaseDrawHudPanels"
  if not OverworldBattle[PANEL_KEY] then
    OverworldBattle[PANEL_KEY] = OverworldBattle.drawHudPanels
  end
  local baseDrawHudPanels = OverworldBattle[PANEL_KEY]

  function FloatingHud.drawPanelHostHudPanels(battle)
    if not battle then return baseDrawHudPanels(battle) end
    FloatingHud.installNativeTextSuppression()
    FloatingHud.installBattleTextSink(battle)
    FloatingHud.installKascOverlaySuppression(battle)
    battle._floatingBattleHudPanelDrawn = false
    local shot = battleShot(battle)
    local statusDrawn, bottomDrawn = drawFloatingSceneUI(battle, shot, false)
    if statusDrawn then
      battle._floatingBattleHudPanelDrawn = true
    end
    if statusDrawn or bottomDrawn
        or (floatingCommandsEnabled(battle) and battle.introBalls
            and supportedFloatingLayout(battle)) then
      return
    end
    return baseDrawHudPanels(battle)
  end

  OverworldBattle.drawHudPanels = FloatingHud.drawPanelHostHudPanels

  local DRAW_KEY = "_floatingBattleHudBaseDrawHUDs"
  if not BattleState[DRAW_KEY] then BattleState[DRAW_KEY] = BattleState.drawHUDs end
  local baseDrawHUDs = BattleState[DRAW_KEY]
  if type(baseDrawHUDs) == "function" then
    function BattleState:drawHUDs(...)
      local owns = floatingStatusHudEnabled(self)
                   and battleShot(self)
                   and FloatingHud.statusAssetsReady()
      if owns then
        return drawHUDsWithoutNativeBallRows(baseDrawHUDs, self, ...)
      end
      return baseDrawHUDs(self, ...)
    end
  end

  local statusHookInstalled = false
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("battle.status_hud_visible", function(next, state)
      if floatingStatusHudEnabled(state) and state and battleShot(state)
          and supportedFloatingLayout(state)
          and FloatingHud.statusAssetsReady() then
        return false
      end
      return next(state)
    end, 12000)
    statusHookInstalled = true
  end

  if not statusHookInstalled then
    local STATUS_KEY = "_floatingBattleHudBaseStatusHUDVisible"
    if not BattleState[STATUS_KEY] then
      BattleState[STATUS_KEY] = BattleState.statusHUDVisible
    end
    local baseStatusHUDVisible = BattleState[STATUS_KEY]
    if type(baseStatusHUDVisible) == "function" then
      function BattleState:statusHUDVisible(...)
        if floatingStatusHudEnabled(self) and battleShot(self)
            and supportedFloatingLayout(self)
            and FloatingHud.statusAssetsReady() then
          return false
        end
        return baseStatusHUDVisible(self, ...)
      end
    end
  end

else
  error("ASCENDANT_BATTLE_HUD_REVIEW: unsupported OverworldBattle HUD API", 0)
end

-- ---------------------------------------------------------------------------
-- Navigation semantics for the visible ORAS battle controls
-- ---------------------------------------------------------------------------
--
-- Gen1Recomp's stock command menu is a 2x2 grid. Our visible order follows the
-- lower screen edge and conditionally inserts MEGA as a fifth real focus target.
-- Ordinary actions stay native; only MEGA invokes KASC's exported activation.
local UPDATE_KEY = "_floatingBattleHudBaseUpdate"
if not BattleState[UPDATE_KEY] then
  BattleState[UPDATE_KEY] = BattleState.update
end
local baseBattleUpdate = BattleState[UPDATE_KEY]

if type(baseBattleUpdate) == "function" then
  function BattleState:update(...)
    FloatingHud.advanceMegaTransformation(self, select(1, ...))
    local input = self.game and self.game.input
    local commandsEnabled = floatingCommandsEnabled(self)
    if not commandsEnabled then
      self._floatingBattlePartyPending = nil
      self._floatingBattleChoicePartyPending = nil
    end
    local ownsCommand = commandsEnabled
                        and self.phase == "menu"
                        and self._floatingBattleBottomDrawn == "menu"
                        and input and type(input.wasPressed) == "function"
    local ownsMoves = commandsEnabled
                   and self.phase == "moveSelect"
                   and self._floatingBattleBottomDrawn == "moves"
                   and input and type(input.wasPressed) == "function"
    if not ownsMoves then
      self._ascendantBattleHudMoveBackFocus = nil
      self._ascendantBattleHudMoveMegaFocus = nil
    end

    -- The supplied MOVE control is the visible Back action at the bottom of
    -- the 2x2 grid. It participates in D-pad/A navigation instead of being a
    -- decorative heading; native B remains an immediate shortcut from a move.
    if ownsMoves then
      local moveCount = math.min(4, #(self.player and self.player.curMoves or {}))
      local moveMegaProfile = megaProfileFor(self, self.player, "player")
      if not moveMegaProfile then
        self._ascendantBattleHudMoveMegaFocus = nil
        FloatingHud.clearMegaArmed(self)
      end
      if self._ascendantBattleHudMoveMegaFocus then
        if input:wasPressed("a") then
          FloatingHud.toggleMegaArmed(self)
          return
        elseif input:wasPressed("b") or input:wasPressed("down") then
          self._ascendantBattleHudMoveMegaFocus = nil
          return
        elseif input:wasPressed("right") then
          self._ascendantBattleHudMoveMegaFocus = nil
          self.moveIndex = math.min(2, math.max(1, moveCount))
          return
        elseif input:wasPressed("left") or input:wasPressed("up") then
          return
        end
      elseif self._ascendantBattleHudMoveBackFocus then
        if input:wasPressed("a") or input:wasPressed("b") then
          self._ascendantBattleHudMoveBackFocus = nil
          self.moveSwapIndex = nil
          FloatingHud.clearMegaArmed(self)
          self.phase = "menu"
          return
        elseif input:wasPressed("up") then
          local a, b, c = baseBattleUpdate(self, ...)
          if self.phase == "moveSelect" then
            self._ascendantBattleHudMoveBackFocus = nil
            self.moveIndex = moveCount >= 3 and 3 or math.max(1, moveCount)
          end
          return a, b, c
        elseif input:wasPressed("left") or input:wasPressed("right")
            or input:wasPressed("down") then
          return
        end
      else
        if input:wasPressed("a") and not self.moveSwapIndex
            and FloatingHud.megaArmed(self) then
          local committed, reason = FloatingHud.commitMegaMove(
            self, self.moveIndex)
          if committed then return end
          -- Disabled/empty-PP moves remain native validation paths and do not
          -- consume the armed transformation. Any KASC activation failure is
          -- fail-open: base update executes the chosen ordinary move instead.
          if reason ~= "move_unusable" then
            FloatingHud.clearMegaArmed(self)
          end
        end
        local left = input:wasPressed("left")
        local right = input:wasPressed("right")
        local up = input:wasPressed("up")
        local down = input:wasPressed("down")
        if left or right or up or down then
          local current = clamp(math.floor(tonumber(self.moveIndex) or 1),
                                1, math.max(1, moveCount))
          local target = current
          if left and current % 2 == 0 then
            target = current - 1
          elseif right and current % 2 == 1 and current + 1 <= moveCount then
            target = current + 1
          elseif up and current == 1 and moveMegaProfile then
            target = -1
          elseif up and current > 2 then
            target = current - 2
          elseif down and current <= 2 and current + 2 <= moveCount then
            target = current + 2
          elseif down and current > 2 then
            target = 0
          elseif down then
            target = 0
          end
          local a, b, c = baseBattleUpdate(self, ...)
          if self.phase == "moveSelect" then
            self._ascendantBattleHudMoveBackFocus = target == 0 or nil
            self._ascendantBattleHudMoveMegaFocus = target == -1 or nil
            -- baseBattleUpdate still receives the physical direction so host
            -- effects/cursor audio keep ticking. Virtual MEGA/BACK targets are
            -- outside the native grid, therefore restore the originating move
            -- instead of retaining native UP/DOWN's wraparound mutation.
            self.moveIndex = target > 0 and target or current
            if target == -1 then self.moveSwapIndex = nil end
          end
          return a, b, c
        end
        if input:wasPressed("b") then
          FloatingHud.clearMegaArmed(self)
        end
      end
    end

    local megaProfile = ownsCommand
      and megaProfileFor(self, self.player, "player") or nil
    if not ownsCommand or not megaProfile then
      self._ascendantBattleHudMegaFocus = nil
    end

    -- Both command and move-picker MEGA controls edit one local armed state.
    -- They never consume KASC's transformation or leave the current menu.
    if ownsCommand and self._ascendantBattleHudMegaFocus then
      if input:wasPressed("a") then
        FloatingHud.toggleMegaArmed(self)
        return
      elseif input:wasPressed("b") then
        self._ascendantBattleHudMegaFocus = nil
        return
      end
    end

    -- Remember the exact frame PKMN is confirmed because PartyMenu is rendered
    -- by this HUD. BAG intentionally has no HUD latch: native command index 3
    -- reaches BattleState:openItems(), which resolves the registered BagMenu with
    -- { battle = self } and already fail-opens to the builtin screen.
    if ownsCommand and not self._ascendantBattleHudMegaFocus
        and input:wasPressed("a") then
      if self.menuIndex == 2 then
        self._floatingBattlePartyPending = true
      end
      if self.menuIndex ~= 1 then FloatingHud.clearMegaArmed(self) end
    end

    if ownsCommand then
      local up = input:wasPressed("up")
      local down = input:wasPressed("down")
      local left = input:wasPressed("left")
      local right = input:wasPressed("right")

      if up or down or left or right then
        local index = clamp(math.floor(tonumber(self.menuIndex) or 1), 1, 4)
        local current = self._ascendantBattleHudMegaFocus and 0 or index
        local rowOrder = megaProfile and { 3, 0, 2, 4 } or { 3, 2, 4 }
        local nextIndex = current
        if up and current ~= 1 then
          nextIndex = 1
        elseif down and current == 1 then
          nextIndex = 2
        elseif left or right then
          if current == 1 then
            nextIndex = left and (megaProfile and 0 or 3) or 2
          else
            local rowIndex = 1
            for i, candidate in ipairs(rowOrder) do
              if candidate == current then rowIndex = i break end
            end
            rowIndex = clamp(rowIndex + (left and -1 or 1), 1, #rowOrder)
            nextIndex = rowOrder[rowIndex]
          end
        end

        -- Let native input keep cursor sounds and non-visual side effects, then
        -- replace only the index with the actual two-level layout shown here.
        local a, b, c = baseBattleUpdate(self, ...)
        if self.phase == "menu" then
          self._ascendantBattleHudMegaFocus = nextIndex == 0 or nil
          if nextIndex ~= 0 then self.menuIndex = nextIndex end
        end
        return a, b, c
      end
    end

    -- Do NOT clear the PKMN intent immediately after native update. Depending on
    -- the active renderer/UI stack, PartyMenu may be constructed or first become
    -- render-visible on the following frame. The latch is consumed only when the
    -- concrete PartyMenu is claimed.
    return baseBattleUpdate(self, ...)
  end
end

if type(BattleState.moveGridNavigation) == "function" then
  local MOVE_NAV_KEY = "_floatingBattleHudBaseMoveGridNavigation"
  if not BattleState[MOVE_NAV_KEY] then
    BattleState[MOVE_NAV_KEY] = BattleState.moveGridNavigation
  end
  local baseMoveGridNavigation = BattleState[MOVE_NAV_KEY]
  function BattleState:moveGridNavigation(...)
    if floatingCommandsEnabled(self)
        and self.phase == "moveSelect"
        and self._floatingBattleBottomDrawn == "moves" then
      return hudStyle() ~= "float"
    end
    return baseMoveGridNavigation(self, ...)
  end
end

-- Direct touch ownership for the controls this HUD paints. Keyboard/controller
-- navigation remains authoritative, but a phone tap should not have to imitate
-- several D-pad presses. The draw path publishes framebuffer-pixel receipts;
-- this event wrapper only selects the native target and queues one ordinary A
-- edge, so all actual battle actions still run inside BattleState:update.
function HudRuntime.hudTouchPixelPosition(x, y)
  local unitW, unitH = g.getDimensions()
  local pixelW, pixelH = unitW, unitH
  if g.getPixelDimensions then
    local ok, pw, ph = pcall(g.getPixelDimensions)
    if ok and tonumber(pw) and tonumber(ph) and pw > 0 and ph > 0 then
      pixelW, pixelH = pw, ph
    end
  end
  return (tonumber(x) or 0) * pixelW / math.max(1, unitW),
         (tonumber(y) or 0) * pixelH / math.max(1, unitH)
end

function HudRuntime.hudHitAt(hits, x, y)
  for _, hit in ipairs(type(hits) == "table" and hits or {}) do
    if x >= hit.x and x <= hit.x + hit.w
        and y >= hit.y and y <= hit.y + hit.h then
      return hit
    end
  end
  return nil
end

function HudRuntime.queueHudTouchAction(game, battle, hit)
  if not (game and battle and hit and bottomOwnedThisFrame(battle)) then
    return false
  end
  local input = game.input
  if not (input and type(input.overlayPressed) == "function"
      and type(input.overlayReleased) == "function") then return false end

  if hit.action == "command_mega" then
    if battle.phase ~= "menu"
        or not megaProfileFor(battle, battle.player, "player") then return false end
    battle._ascendantBattleHudMegaFocus = true
  elseif hit.action == "command" then
    if battle.phase ~= "menu" or not hit.index then return false end
    battle._ascendantBattleHudMegaFocus = nil
    battle.menuIndex = clamp(math.floor(hit.index), 1, 4)
  elseif hit.action == "move_mega" then
    if battle.phase ~= "moveSelect"
        or not megaProfileFor(battle, battle.player, "player") then return false end
    battle.moveSwapIndex = nil
    battle._ascendantBattleHudMoveBackFocus = nil
    battle._ascendantBattleHudMoveMegaFocus = true
  elseif hit.action == "move" then
    local count = math.min(4, #(battle.player and battle.player.curMoves or {}))
    if battle.phase ~= "moveSelect" or not hit.index
        or hit.index < 1 or hit.index > count then return false end
    battle.moveIndex = hit.index
    battle._ascendantBattleHudMoveBackFocus = nil
    battle._ascendantBattleHudMoveMegaFocus = nil
  elseif hit.action == "move_back" then
    if battle.phase ~= "moveSelect" then return false end
    battle._ascendantBattleHudMoveMegaFocus = nil
    battle._ascendantBattleHudMoveBackFocus = true
  else
    return false
  end

  -- A press+release before Input:step produces one clean edge without leaving
  -- a held virtual button behind. Claiming this touch also prevents the same
  -- finger from pressing an overlapping on-screen Game Boy control.
  input:overlayPressed("a")
  input:overlayReleased("a")
  return true
end

-- Engine 0.1.90+ exposes uncaptured real mouse/touch presses through this
-- public seam. Older builds still use Game:touchpressed below; installing both
-- is safe because a captured legacy touch returns before the base method can
-- publish a pointer event, while a real desktop mouse only reaches this hook.
if mod.hooks and type(mod.hooks.wrap) == "function" then
  mod.hooks:wrap("input.pointer", function(nextInput, game, pointer)
    if type(pointer) == "table" and pointer.phase == "pressed"
        and (pointer.source == "touch" or pointer.source == "mouse")
        and (pointer.source ~= "mouse" or pointer.button == nil
             or pointer.button == 1) then
      local battle = HudRuntime.battleStateInStack(game)
      if battle and bottomOwnedThisFrame(battle) then
        local px, py = HudRuntime.hudTouchPixelPosition(pointer.x, pointer.y)
        local hits = battle.phase == "moveSelect"
          and battle._ascendantBattleHudMoveHits
          or battle.phase == "menu" and battle._ascendantBattleHudCommandHits
          or nil
        local hit = HudRuntime.hudHitAt(hits, px, py)
        if hit and HudRuntime.queueHudTouchAction(game, battle, hit) then
          return true
        end
      end
    end
    return nextInput(game, pointer)
  end, 13000)
end

local GAME_TOUCH_KEY = "_ascendantBattleHudBaseTouchPressed"
if type(Game) == "table" and type(Game.touchpressed) == "function" then
  if not Game[GAME_TOUCH_KEY] then Game[GAME_TOUCH_KEY] = Game.touchpressed end
  local baseGameTouchPressed = Game[GAME_TOUCH_KEY]
  function Game:touchpressed(id, x, y, ...)
    local battle = HudRuntime.battleStateInStack(self)
    if battle and bottomOwnedThisFrame(battle) then
      local px, py = HudRuntime.hudTouchPixelPosition(x, y)
      local hits = battle.phase == "moveSelect"
        and battle._ascendantBattleHudMoveHits
        or battle.phase == "menu" and battle._ascendantBattleHudCommandHits
        or nil
      local hit = HudRuntime.hudHitAt(hits, px, py)
      if hit and HudRuntime.queueHudTouchAction(self, battle, hit) then return end
    end
    return baseGameTouchPressed(self, id, x, y, ...)
  end
end

-- ---------------------------------------------------------------------------
-- Battle PartyMenu presentation
-- ---------------------------------------------------------------------------
--
-- Keep PartyMenu input/callbacks completely native. The authoritative signal
-- is the PKMN-confirmation latch set on BattleState before the engine pushes the
-- PartyMenu. `opts.battle` remains a useful hint, but some UI mods rebuild those
-- options, so the final screen.render_visible seam can claim the concrete state
-- directly from the stack even when that field has disappeared.
do
  local okParty, PartyMenu = pcall(require, "src.ui.PartyMenu")
  if okParty and type(PartyMenu) == "table"
      and not PartyMenu.__floatingBattleHudPartyPatched then
    PartyMenu.__floatingBattleHudPartyPatched = true
    local baseNew = PartyMenu.new
    local baseDraw = PartyMenu.draw
    local baseWide = PartyMenu.drawWidescreen

    local function claimBattleParty(menu, battle)
      if not floatingCommandsEnabled(battle) then return menu end
      if not (menu and battle) then return menu end
      if hudStyle() == "float" and not assetImage(PKMN_PLATE_ASSET) then return menu end

      menu.isOpaque = false
      menu.__floatingBattleParty = battle
      battle._floatingBattlePartyMenu = menu
      battle._floatingBattlePartyPending = nil
      battle._floatingBattleChoicePartyPending = nil

      -- screen.render_visible can ask about the same state every frame. Never
      -- stack another update/draw wrapper onto an already-claimed PartyMenu.
      if menu.__floatingBattlePartyClaimed == battle then
        return menu
      end
      menu.__floatingBattlePartyClaimed = battle

      -- Instance-level ownership wins over later class-level skins without
      -- replacing update/input. This is important for menu overhauls that draw
      -- Party from a final HUD pass rather than directly in PartyMenu.draw.
      local nativeUpdate = menu.update
      if type(nativeUpdate) == "function" then
        menu.update = function(self, ...)
          self.isOpaque = false
          local a, b, c = nativeUpdate(self, ...)
          self.isOpaque = false
          return a, b, c
        end
      end

      menu.drawsWidescreen = function() return false end
      menu.wantsFillScale = function() return false end

      menu.draw = function(self, ...)
        self.isOpaque = false
        battle._floatingBattlePartyMenu = self
        local shot = battleShot(battle)
        if shot and drawPartyPanel(self, battle, shot) then return end
        if type(baseDraw) == "function" then return baseDraw(self, ...) end
      end

      menu.drawWidescreen = function(self, ...)
        self.isOpaque = false
        battle._floatingBattlePartyMenu = self
        local shot = battleShot(battle)
        if shot and drawPartyPanel(self, battle, shot) then return end
        if type(baseWide) == "function" then return baseWide(self, ...) end
      end

      return menu
    end

    if type(baseNew) == "function" then
      PartyMenu.new = function(game, opts, ...)
        opts = opts or {}
        local battle = HudRuntime.battleStateInStack(game)
        local menu = baseNew(game, opts, ...)
        if not floatingCommandsEnabled(battle) then return menu end

        -- The PKMN confirmation latch is the authoritative discriminator. Some
        -- UI/renderer mods rebuild PartyMenu options and drop `opts.battle`, so
        -- requiring that field lets their fullscreen Party skin escape. Keep
        -- opts.battle as a secondary hint, but never require it.
        local pending = battle and battle._floatingBattlePartyPending
        local choicePartyPending = battle and battle._floatingBattleChoicePartyPending
        -- Claim the mandatory faint replacement at construction time too. The old
        -- screen.render_visible fallback was late enough that mobile had already
        -- composed the underlying battle frame, leaving only an invisible PartyMenu.
        local activeMon = battle and battle.player and battle.player.mon or nil
        local forcedFaintPicker = battle and battle.player
          and (battle.player.fainted == true
               or (activeMon and tonumber(activeMon.hp) and activeMon.hp <= 0))
        -- Any PartyMenu explicitly created with opts.battle belongs to the battle
        -- flow, not only the manual PKMN command. The forced replacement picker after
        -- our active Pokémon faints uses this same constructor seam while battle.phase
        -- is no longer "menu", which is why v0.6.7 let that one native Party screen
        -- escape. Keep this narrow to the engine's own opts.battle marker.
        local nativeBattlePicker = battle and opts.battle
        if menu and battle and (pending or nativeBattlePicker
            or choicePartyPending or forcedFaintPicker) then
          return claimBattleParty(menu, battle)
        end
        return menu
      end
    end

    -- Compatibility fallback: if a host/mod constructed the battle PartyMenu via
    -- an unusual path but preserved our marker, keep the class methods capable of
    -- drawing it. Normal PKMN menus use the stronger instance-level methods above.
    if type(baseDraw) == "function" then
      PartyMenu.draw = function(self, ...)
        local battle = self.__floatingBattleParty
        if not floatingCommandsEnabled(battle) then return baseDraw(self, ...) end
        if battle and HudRuntime.stateInStack(self.game, self)
            and (hudStyle() ~= "float" or assetImage(PKMN_PLATE_ASSET)) then
          self.isOpaque = false
          battle._floatingBattlePartyMenu = self
          local shot = battleShot(battle)
          if shot and drawPartyPanel(self, battle, shot) then return end
        end
        return baseDraw(self, ...)
      end
    end

    if type(baseWide) == "function" then
      PartyMenu.drawWidescreen = function(self, ...)
        local battle = self.__floatingBattleParty
        if not floatingCommandsEnabled(battle) then return baseWide(self, ...) end
        if battle and HudRuntime.stateInStack(self.game, self)
            and (hudStyle() ~= "float" or assetImage(PKMN_PLATE_ASSET)) then
          self.isOpaque = false
          battle._floatingBattlePartyMenu = self
          local shot = battleShot(battle)
          if shot and drawPartyPanel(self, battle, shot) then return end
        end
        return baseWide(self, ...)
      end
    end

    -- Hard ownership seam copied from the working full-UI replacement strategy:
    -- screen.render_visible sits OUTSIDE PartyMenu.draw, so a later class-level
    -- skin cannot resurrect its fullscreen pixels. When the pending PKMN picker
    -- first reaches the state stack, claim that concrete state and make the
    -- native screen itself invisible while keeping update/input alive.
    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("screen.render_visible", function(next, state)
        local visible = next(state)
        if visible == false then return false end
        local game = state and state.game
        local battle = game and HudRuntime.battleStateInStack(game) or nil
        if not floatingCommandsEnabled(battle) then return visible end
        -- Narrow compatibility fallback for UI mods that rebuild PartyMenu.new opts:
        -- when the active battler is actually fainted, the next concrete PartyMenu in
        -- that same battle can only be the mandatory replacement picker. This avoids
        -- the overly broad "claim every PartyMenu above a battle" experiment from the
        -- bad v0.6.8 branch.
        local activeMon = battle and battle.player and battle.player.mon or nil
        local forcedFaintParty = battle and state and getmetatable(state) == PartyMenu
          and battle.player
          and (battle.player.fainted == true
               or (activeMon and tonumber(activeMon.hp) and activeMon.hp <= 0))

        local isParty = state and (
          state.__floatingBattleParty ~= nil
          or getmetatable(state) == PartyMenu
          or (battle and (battle._floatingBattlePartyPending
                            or battle._floatingBattleChoicePartyPending)
              and type(state.party) == "table"
              and state.index ~= nil
              and type(state.bottomMessage) == "function")
        )

        if isParty and battle
            and (state.__floatingBattleParty == battle
                 or battle._floatingBattlePartyPending
                 or battle._floatingBattleChoicePartyPending
                 or forcedFaintParty
                 or battle._floatingBattlePartyMenu == state) then
          claimBattleParty(state, battle)
          state.isOpaque = false
          return false
        end
        return visible
      end, 20000)

      -- Render our PKMN plate in the final HUD pass, AFTER the state renderer.
      -- This mirrors the reference mod's architecture: PartyMenu owns all native
      -- input/state, screen.render_visible removes only its pixels, and the custom
      -- presentation is painted once on top of the still-live voxel battle.
      mod.hooks:wrap("render.hud", function(next, game, viewport)
        local out = next(game, viewport)
        local battle = HudRuntime.battleStateInStack(game)
        if not floatingCommandsEnabled(battle) then return out end
        local menu = battle and battle._floatingBattlePartyMenu or nil
        if menu and HudRuntime.stateInStack(game, menu) then
          local top = game and game.stack and (
            (game.stack.top and game.stack:top())
            or (game.stack.states and game.stack.states[#game.stack.states])
          )
          if top == menu then
            menu.isOpaque = false
            local shot = battleShot(battle)
            if shot and battle._floatingBattlePartySceneFrame ~= battle.frame then
              local ok, err = pcall(drawPartyPanel, menu, battle, shot)
              if not ok then
                mod.log:warn("floating PKMN HUD draw failed: %s", tostring(err))
              end
            end
          end
        end
        return out
      end, 15000)
    end
  end
end

-- ---------------------------------------------------------------------------
-- In-battle MoveLearnMenu presentation
-- ---------------------------------------------------------------------------
-- Gen1Recomp deliberately implements move learning as a pushed MoveLearnMenu:
--   MoveLearnMenu -> TextBox(+ChoiceBox) -> SELECT old move -> result TextBox.
-- Keep every native state/callback/timing rule intact, but replace each visual
-- layer while a voxel BattleState remains underneath. The ordinary battle text
-- is suppressed for the whole foreground so transparent panels never overlap.
do
  local okLearn, MoveLearnMenu = pcall(require, "src.ui.MoveLearnMenu")
  if okLearn and type(MoveLearnMenu) == "table"
      and not MoveLearnMenu.__floatingBattleHudLearnPatched then
    MoveLearnMenu.__floatingBattleHudLearnPatched = true
    local baseNew = MoveLearnMenu.new
    local MoveLearnHandoff = {
      presentationKey="__vascMoveLearnPresentationHandoffV1",
      legacyKey="__floatingBattleMoveLearnHandoffV1",
      schema="voxel-ascendant/gen1-move-learn-owner-handoff/v1",
      presentationOwner="voxel-ascendant/gen1-move-learn-presentation/v1",
      legacyOwner="voxel-ascendant/gen1-floating-move-learn/v1",
    }

    function MoveLearnHandoff.presentation()
      local handoff = rawget(MoveLearnMenu, MoveLearnHandoff.presentationKey)
      if type(handoff) ~= "table"
          or handoff.apiVersion ~= 1
          or handoff.schema ~= MoveLearnHandoff.schema
          or handoff.owner ~= MoveLearnHandoff.presentationOwner then
        return nil
      end
      return handoff
    end

    function MoveLearnHandoff.presentationActive()
      local handoff = MoveLearnHandoff.presentation()
      if not (handoff and type(handoff.active) == "function") then return false end
      local ok, active = pcall(handoff.active)
      return ok and active == true
    end

    function MoveLearnHandoff.presentationOwns(menu)
      local handoff = MoveLearnHandoff.presentation()
      if not (handoff and type(handoff.owns) == "function") then return false end
      local ok, owns = pcall(handoff.owns, menu)
      return ok and owns == true
    end

    local function claimLearnTextBox(box, menu, battle)
      if not (box and battle and HudRuntime.isTextBoxState(box)) then
        return box
      end
      if rawget(box, "__floatingBattleMoveLearnOwner") == nil then
        box.__floatingBattleMoveLearnOpacityRecord = {
          hadRaw=rawget(box, "isOpaque") ~= nil,
          value=rawget(box, "isOpaque"),
        }
      end
      box.isOpaque = false
      box.__floatingBattleMoveLearnText = battle
      box.__floatingBattleMoveLearnOwner = menu
      battle._floatingBattleMoveLearnText = box
      return box
    end

    local function claimTopLearnText(menu, battle)
      local top = HudRuntime.topState(menu and menu.game
        or battle and battle.game)
      if top and top ~= menu and HudRuntime.isTextBoxState(top) then
        claimLearnTextBox(top, menu, battle)
      end
    end

    function MoveLearnHandoff.release(menu)
      if type(menu) ~= "table" then return false end
      local battle = rawget(menu, "__floatingBattleMoveLearn")
      local record = rawget(menu, "__floatingBattleMoveLearnRecord")
      if type(record) ~= "table" or battle == nil then return false end

      for name, field in pairs(record.fields or {}) do
        if rawget(menu, name) == field.wrapper then
          if field.hadRaw then rawset(menu, name, field.raw)
          else rawset(menu, name, nil) end
        end
      end
      if rawget(menu, "isOpaque") == false then
        if record.hadRawOpacity then
          rawset(menu, "isOpaque", record.rawOpacity)
        else
          rawset(menu, "isOpaque", nil)
        end
      end

      local text = battle._floatingBattleMoveLearnText
      if text and rawget(text, "__floatingBattleMoveLearnOwner") == menu then
        local opacity = rawget(text,
          "__floatingBattleMoveLearnOpacityRecord")
        if rawget(text, "isOpaque") == false and type(opacity) == "table" then
          if opacity.hadRaw then rawset(text, "isOpaque", opacity.value)
          else rawset(text, "isOpaque", nil) end
        end
        rawset(text, "__floatingBattleMoveLearnText", nil)
        rawset(text, "__floatingBattleMoveLearnOwner", nil)
        rawset(text, "__floatingBattleMoveLearnOpacityRecord", nil)
        battle._floatingBattleMoveLearnText = nil
      end
      if battle._floatingBattleMoveLearnMenu == menu then
        battle._floatingBattleMoveLearnMenu = nil
      end
      rawset(menu, "__floatingBattleMoveLearn", nil)
      rawset(menu, "__floatingBattleMoveLearnClaimed", nil)
      rawset(menu, "__floatingBattleMoveLearnRecord", nil)
      return true
    end

    function MoveLearnHandoff.claim(menu, battle)
      if not floatingCommandsEnabled(battle) then return menu end
      if not (menu and battle) then return menu end
      -- A concrete full-surface receipt always wins.  Merely seeing a class
      -- contract is insufficient: fail-open explicitly releases the instance
      -- before asking this legacy owner to resume it.
      if MoveLearnHandoff.presentationOwns(menu) then
        MoveLearnHandoff.release(menu)
        return menu
      end
      if menu.__floatingBattleMoveLearnClaimed == battle then return menu end
      local fields = {}
      for _, name in ipairs({
        "enter", "confirmAbandon", "finish", "update", "draw",
      }) do
        fields[name] = {
          hadRaw=rawget(menu, name) ~= nil,
          raw=rawget(menu, name),
          resolved=menu[name],
        }
      end
      menu.__floatingBattleMoveLearnRecord = {
        fields=fields,
        hadRawOpacity=rawget(menu, "isOpaque") ~= nil,
        rawOpacity=rawget(menu, "isOpaque"),
      }
      menu.isOpaque = false
      menu.__floatingBattleMoveLearn = battle
      battle._floatingBattleMoveLearnMenu = menu
      menu.__floatingBattleMoveLearnClaimed = battle

      -- enter() pushes the long "trying to learn" TextBox immediately after the
      -- menu reaches the stack. Tag that concrete box rather than reproducing its
      -- paging/typewriter/YES-NO state machine ourselves.
      local nativeEnter = fields.enter.resolved
      if type(nativeEnter) == "function" then
        fields.enter.wrapper = function(self, ...)
          local a, b, c = nativeEnter(self, ...)
          claimTopLearnText(self, battle)
          return a, b, c
        end
        menu.enter = fields.enter.wrapper
      end

      local nativeConfirm = fields.confirmAbandon.resolved
      if type(nativeConfirm) == "function" then
        fields.confirmAbandon.wrapper = function(self, ...)
          local a, b, c = nativeConfirm(self, ...)
          claimTopLearnText(self, battle)
          return a, b, c
        end
        menu.confirmAbandon = fields.confirmAbandon.wrapper
      end

      local nativeFinish = fields.finish.resolved
      if type(nativeFinish) == "function" then
        fields.finish.wrapper = function(self, ...)
          local a, b, c = nativeFinish(self, ...)
          -- finish() pops MoveLearnMenu and pushes the learned/did-not-learn
          -- TextBox. The menu object is still valid here, so tag that result box.
          claimTopLearnText(self, battle)
          return a, b, c
        end
        menu.finish = fields.finish.wrapper
      end

      local nativeUpdate = fields.update.resolved
      if type(nativeUpdate) == "function" then
        fields.update.wrapper = function(self, dt, ...)
          self.isOpaque = false
          self._ascendantBattleHudFrame =
            (tonumber(self._ascendantBattleHudFrame) or 0) + 1
          local input = self.game and self.game.input

          if self.selecting and input and type(input.wasPressed) == "function" then
            local up = input:wasPressed("up") or input:wasPressed("left")
            local down = input:wasPressed("down") or input:wasPressed("right")
            if up or down then
              -- Our SELECT presentation intentionally contains only the four real
              -- moves. B still invokes native confirmAbandon(), so the invisible
              -- fifth CANCEL row is unnecessary and cannot trap the cursor.
              local n = math.max(1, math.min(4, #(self.mon and self.mon.moves or {})))
              local index = clamp(math.floor(tonumber(self.index) or 1), 1, n)
              self.index = ((index - 1 + (up and -1 or 1)) % n) + 1
              return
            end
          end

          local a, b, c = nativeUpdate(self, dt, ...)
          self.isOpaque = false
          -- HM rejection and several native branches push TextBox directly from
          -- update(), bypassing enter/confirmAbandon/finish wrappers.
          claimTopLearnText(self, battle)
          return a, b, c
        end
        menu.update = fields.update.wrapper
      end

      -- Never let the native full-screen forget-list pixels appear. The state is
      -- still alive and authoritative; render.hud paints our SELECT clone later.
      local nativeDraw = fields.draw.resolved
      fields.draw.wrapper = function(self, ...)
        self.isOpaque = false
        battle._floatingBattleMoveLearnMenu = self
        if self.selecting then return end
        if type(nativeDraw) == "function" then return nativeDraw(self, ...) end
      end
      menu.draw = fields.draw.wrapper

      return menu
    end

    -- Explicit retirement/resume seam shared only with the newer opaque
    -- MoveLearnPresentation Card.  It exposes no battle engine or save data;
    -- both sides validate schema and owner before acting on a concrete menu.
    MoveLearnHandoff.legacyBridge = rawget(
      MoveLearnMenu, MoveLearnHandoff.legacyKey)
    if MoveLearnHandoff.legacyBridge == nil
        or (type(MoveLearnHandoff.legacyBridge) == "table"
            and MoveLearnHandoff.legacyBridge.schema == MoveLearnHandoff.schema
            and MoveLearnHandoff.legacyBridge.owner == MoveLearnHandoff.legacyOwner) then
      MoveLearnHandoff.legacyBridge = {
        apiVersion=1,
        schema=MoveLearnHandoff.schema,
        owner=MoveLearnHandoff.legacyOwner,
        owns=function(menu)
          return type(menu) == "table"
            and rawget(menu, "__floatingBattleMoveLearnRecord") ~= nil
            and rawget(menu, "__floatingBattleMoveLearn") ~= nil
        end,
        release=function(menu)
          return MoveLearnHandoff.release(menu)
        end,
        claim=function(menu)
          if type(menu) ~= "table"
              or MoveLearnHandoff.presentationOwns(menu) then return false end
          local battle = HudRuntime.battleStateInStack(menu.game)
          if not (battle and not battle.safari and not battle.demo) then return false end
          MoveLearnHandoff.claim(menu, battle)
          claimTopLearnText(menu, battle)
          return rawget(menu, "__floatingBattleMoveLearn") == battle
        end,
      }
      rawset(MoveLearnMenu, MoveLearnHandoff.legacyKey,
        MoveLearnHandoff.legacyBridge)
    end

    if type(baseNew) == "function" then
      MoveLearnMenu.new = function(game, mon, newMoveId, onDone, learnedSound, ...)
        local battle = HudRuntime.battleStateInStack(game)
        local menu = baseNew(game, mon, newMoveId, onDone, learnedSound, ...)
        -- Construction happens before StateStack emits screen.pushed.  Yield
        -- here so the new full-surface owner receives the untouched native
        -- methods and complete return tuples instead of our SELECT clone.
        if MoveLearnHandoff.presentationActive() then return menu end
        if not floatingCommandsEnabled(battle) then return menu end
        if menu and battle and not battle.safari and not battle.demo then
          return MoveLearnHandoff.claim(menu, battle)
        end
        return menu
      end
    end

    if mod.hooks and type(mod.hooks.wrap) == "function" then
      -- Hide only states that we explicitly tagged as part of this move-learning
      -- foreground. This is deliberately narrower than claiming arbitrary TextBox
      -- or MoveLearnMenu instances over a battle.
      mod.hooks:wrap("screen.render_visible", function(next, state)
        local visible = next(state)
        if MoveLearnHandoff.presentationOwns(state) then
          -- A stale hot-reload marker must not let this retired owner suppress
          -- the exact screen now backed by an opaque full-surface receipt.
          MoveLearnHandoff.release(state)
          return visible
        end
        local game = state and state.game
        local battle = game and HudRuntime.battleStateInStack(game) or nil
        if not floatingCommandsEnabled(battle) then return visible end
        if battle and state then
          if state.__floatingBattleMoveLearn == battle then
            state.isOpaque = false
            battle._floatingBattleMoveLearnMenu = state
            return false
          end
          if state.__floatingBattleMoveLearnText == battle then
            state.isOpaque = false
            battle._floatingBattleMoveLearnText = state
            return false
          end
        end
        return visible
      end, 20015)

      mod.hooks:wrap("render.hud", function(next, game, viewport)
        local out = next(game, viewport)
        local battle = HudRuntime.battleStateInStack(game)
        if not floatingCommandsEnabled(battle) then return out end
        if not battle then return out end
        local top = HudRuntime.topState(game)
        local shot = battleShot(battle)
        if not shot then return out end

        local text = battle._floatingBattleMoveLearnText
        if text and top == text and HudRuntime.stateInStack(game, text) then
          if battle._floatingBattleMoveLearnSceneFrame ~= battle.frame then
            local ok, err = pcall(drawMoveLearnMessagePanel, text, battle, shot)
            if not ok then
              mod.log:warn("floating move-learn message failed: %s", tostring(err))
            end
          end
          return out
        elseif text and not HudRuntime.stateInStack(game, text) then
          battle._floatingBattleMoveLearnText = nil
        end

        local menu = battle._floatingBattleMoveLearnMenu
        if menu and MoveLearnHandoff.presentationOwns(menu) then
          MoveLearnHandoff.release(menu)
          return out
        end
        if menu and top == menu and menu.selecting
            and HudRuntime.stateInStack(game, menu) then
          menu.isOpaque = false
          if battle._floatingBattleMoveLearnSceneFrame ~= battle.frame then
            local ok, err = pcall(drawLearnPanel, menu, battle, shot)
            if not ok then
              mod.log:warn("floating move-learn SELECT failed: %s", tostring(err))
            end
          end
        elseif menu and not HudRuntime.stateInStack(game, menu) then
          battle._floatingBattleMoveLearnMenu = nil
        end
        return out
      end, 15150)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Caught-Pokemon nickname prompt presentation
-- ---------------------------------------------------------------------------
-- Gen1Recomp's AskName path intentionally sets blankForAskName=true before
-- returning a TextBox, which makes BattleState:drawClassic paint a full white
-- 160x144 field. For staged voxel battles that destroys the very scene our
-- floating prompt is anchored to. Keep every native TextBox/ChoiceBox callback
-- and NamingScreen handoff intact, but cancel only that presentation blank and
-- tag the concrete TextBox for our existing message renderer.
do
  local ASK_NICK_KEY = "_floatingBattleHudBaseAskNicknameUI"
  if type(BattleState.askNicknameUI) == "function" then
    if not BattleState[ASK_NICK_KEY] then
      BattleState[ASK_NICK_KEY] = BattleState.askNicknameUI
    end
    local baseAskNicknameUI = BattleState[ASK_NICK_KEY]

    function BattleState:askNicknameUI(...)
      local box = baseAskNicknameUI(self, ...)
      if not floatingCommandsEnabled(self) then return box end
      if not (box and HudRuntime.isTextBoxState(box) and battleShot(self)) then
        return box
      end
      if self.safari or self.demo then return box end

      -- Presentation only: the original choice callback still clears this flag
      -- and still pushes NamingScreen on YES. Clearing it now merely prevents
      -- drawClassic / compatible hosts from replacing the staged scene with white.
      self.blankForAskName = false
      box.isOpaque = false
      box.__floatingBattleNicknameText = self
      self._floatingBattleNicknameText = box
      return box
    end
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("screen.render_visible", function(next, state)
      local visible = next(state)
      local game = state and state.game
      local battle = game and HudRuntime.battleStateInStack(game) or nil
      if not floatingCommandsEnabled(battle) then return visible end
      if state and battle and state.__floatingBattleNicknameText == battle then
        state.isOpaque = false
        battle._floatingBattleNicknameText = state
        return false
      end
      return visible
    end, 20018)

    mod.hooks:wrap("render.hud", function(next, game, viewport)
      local out = next(game, viewport)
      local battle = HudRuntime.battleStateInStack(game)
      if not floatingCommandsEnabled(battle) then return out end
      if not battle then return out end
      local text = battle._floatingBattleNicknameText
      if not text then return out end
      if not HudRuntime.stateInStack(game, text) then
        battle._floatingBattleNicknameText = nil
        return out
      end
      local top = HudRuntime.topState(game)
      if top ~= text then return out end
      local shot = battleShot(battle)
      if shot and battle._floatingBattleNicknameSceneFrame ~= battle.frame then
        local ok, err = pcall(drawMoveLearnMessagePanel, text, battle, shot)
        if not ok then
          mod.log:warn("floating nickname message failed: %s", tostring(err))
        end
      end
      return out
    end, 15175)
  end
end

-- ---------------------------------------------------------------------------
-- Battle YES / NO presentation
-- ---------------------------------------------------------------------------
-- Battle sayChoice pushes a real ChoiceBox above BattleState. Keep that box as
-- the sole input/callback authority, hide only its pixels, and paint horizontal
-- YES / NO above our existing message plate. If YES opens a PartyMenu (trainer
-- switch prompt), a short latch lets the PKMN backend claim that picker too.
do
  local okChoice, ChoiceBox = pcall(require, "src.ui.ChoiceBox")
  if okChoice and type(ChoiceBox) == "table"
      and not ChoiceBox.__floatingBattleHudChoicePatched then
    ChoiceBox.__floatingBattleHudChoicePatched = true
    local baseNew = ChoiceBox.new

    local function isDirectBattleChoice(game, choice, battle)
      local states = game and game.stack and game.stack.states
      if type(states) ~= "table" then return false end
      for index, state in ipairs(states) do
        if state == choice then return states[index - 1] == battle end
      end
      -- Construction happens before push. A bag/party confirmation belongs
      -- to that screen even while the underlying battle waits in messages.
      return states[#states] == battle
    end

    local function claimBattleChoice(choice, battle, sourceText)
      if not floatingCommandsEnabled(battle) then return choice end
      if not (choice and battle) then return choice end
      -- sourceText is also used by the caught-Pokemon nickname prompt;
      -- any tagged source keeps the native callback/input while replacing pixels.
      choice.isOpaque = false
      choice.__floatingBattleChoice = battle
      choice.__floatingBattleChoiceText = sourceText
      battle._floatingBattleChoice = choice

      if choice.__floatingBattleChoiceClaimed == battle then return choice end
      choice.__floatingBattleChoiceClaimed = battle

      local nativeUpdate = choice.update
      if type(nativeUpdate) == "function" then
        choice.update = function(self, dt, ...)
          self.isOpaque = false
          battle._floatingBattleChoice = self
          local input = self.game and self.game.input

          -- The presented pair is horizontal, but accept both axes so keyboard,
          -- D-pad and existing muscle memory all remain comfortable.
          if self.pending == nil and input and type(input.wasPressed) == "function" then
            if input:wasPressed("left") or input:wasPressed("up") then
              self.index = 1
              return
            elseif input:wasPressed("right") or input:wasPressed("down") then
              self.index = 2
              return
            end

            -- A YES may invoke the trainer-switch callback. Arm before native
            -- ChoiceBox update; PartyMenu.new consumes it if that callback pushes
            -- a picker. It intentionally survives ChoiceBox's short pending/hold.
            if input:wasPressed("a") and (tonumber(self.index) or 1) == 1
                and not self.__floatingBattleChoiceText then
              battle._floatingBattleChoicePartyPending = true
            end
          end

          local a, b, c = nativeUpdate(self, dt, ...)
          self.isOpaque = false

          -- Once the ChoiceBox has actually left the stack, a synchronous YES
          -- callback has already had its chance to construct PartyMenu. If no
          -- picker consumed the latch, discard it.
          if not HudRuntime.stateInStack(self.game, self)
              and battle._floatingBattleChoicePartyPending then
            battle._floatingBattleChoicePartyPending = nil
          end
          return a, b, c
        end
      end

      return choice
    end

    if type(baseNew) == "function" then
      ChoiceBox.new = function(game, onChoose, opts, ...)
        local battle = HudRuntime.battleStateInStack(game)
        local sourceText = HudRuntime.moveLearnTextBoxInStack(game)
        local nicknameText = HudRuntime.nicknameTextBoxInStack(game)
        local choice = baseNew(game, onChoose, opts, ...)
        if not floatingCommandsEnabled(battle) then return choice end
        -- Move-learning and caught-nickname TextBoxes each own the message that
        -- must remain visible under their native ChoiceBox.
        if choice and battle and sourceText
            and sourceText.__floatingBattleMoveLearnText == battle then
          return claimBattleChoice(choice, battle, sourceText)
        end
        if choice and battle and nicknameText
            and nicknameText.__floatingBattleNicknameText == battle then
          return claimBattleChoice(choice, battle, nicknameText)
        end
        if choice and battle and battle.phase == "messages"
            and isDirectBattleChoice(game, choice, battle) then
          return claimBattleChoice(choice, battle, nil)
        end
        return choice
      end
    end

    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("screen.render_visible", function(next, state)
        local visible = next(state)
        if visible == false then return false end
        local game = state and state.game
        local stackedBattle = game
          and HudRuntime.battleStateInStack(game) or nil
        local battle = state and state.__floatingBattleChoice or stackedBattle
        if not floatingCommandsEnabled(battle) then return visible end
        local sourceText = state and state.__floatingBattleChoiceText
          or (game and HudRuntime.moveLearnTextBoxInStack(game) or nil)
          or (game and HudRuntime.nicknameTextBoxInStack(game) or nil)
        local isLearnChoice = state and battle and sourceText
          and sourceText.__floatingBattleMoveLearnText == battle
          and getmetatable(state) == ChoiceBox
        local isNicknameChoice = state and battle and sourceText
          and sourceText.__floatingBattleNicknameText == battle
          and getmetatable(state) == ChoiceBox
        local isBattleChoice = state and battle and battle.phase == "messages"
          and (state.__floatingBattleChoice == battle
               or (getmetatable(state) == ChoiceBox
                 and isDirectBattleChoice(game, state, battle)))
        if isLearnChoice or isNicknameChoice or isBattleChoice then
          claimBattleChoice(state, battle,
                            (isLearnChoice or isNicknameChoice) and sourceText or nil)
          state.isOpaque = false
          return false
        end
        return visible
      end, 20020)

      mod.hooks:wrap("render.hud", function(next, game, viewport)
        local out = next(game, viewport)
        local battle = HudRuntime.battleStateInStack(game)
        if not floatingCommandsEnabled(battle) then return out end
        local choice = battle and battle._floatingBattleChoice or nil
        if choice and HudRuntime.stateInStack(game, choice) then
          local top = game and game.stack and (
            (game.stack.top and game.stack:top())
            or (game.stack.states and game.stack.states[#game.stack.states])
          )
          if top == choice then
            choice.isOpaque = false
            local shot = battleShot(battle)
            if shot and battle._floatingBattleChoiceSceneFrame ~= battle.frame then
              -- Fallback only. The preferred path now paints ChoiceBox into the
              -- staged battle canvas before mobile composites the viewport.
              local sourceText = choice.__floatingBattleChoiceText
              local okMsg, errMsg
              if sourceText and HudRuntime.stateInStack(game, sourceText) then
                okMsg, errMsg = pcall(drawMoveLearnMessagePanel, sourceText, battle, shot)
              else
                okMsg, errMsg = pcall(drawMessagePanel, battle, shot)
              end
              if not okMsg then
                mod.log:warn("floating battle choice message failed: %s", tostring(errMsg))
              end
              local okPick, errPick = pcall(drawChoicePanel, choice, battle, shot)
              if not okPick then
                mod.log:warn("floating YES/NO HUD draw failed: %s", tostring(errPick))
              end
            end
          end
        elseif battle then
          battle._floatingBattleChoice = nil
        end
        return out
      end, 15200)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Native bottom-UI suppression for the phases we already replace
-- ---------------------------------------------------------------------------
--
-- Keep BattleState:drawTextArea alive under an empty scissor rather than
-- skipping it. Gen1Recomp stores some presentation lifecycle work there, while
-- our replacement only wants ownership of its pixels. Messages, the main
-- command menu and move selection are claimed here; pushed PKMN and ITEM states
-- are suppressed at their state-stack seams above.
function FloatingHud.nativeReplacementCommitted(battle)
  if not battle or battle.demo or not supportedFloatingLayout(battle) then
    return false
  end
  -- Modern VASC publishes the provider verdict only after the replacement was
  -- transactionally committed to this exact staged shot.  Do not infer pixel
  -- ownership from an enabled option or a live-looking shot: either may remain
  -- true during an asset/provider failure, where the native HUD is the only
  -- readable fallback.
  if isAscendantHost and hostProviderAvailable
      and type(OverworldBattle.hudSnapReceipt) == "function" then
    if FloatingHud.hasExactHudSnapReceipt(battle) then
      FloatingHud.latchExactBattleHudOwner(battle)
      return true
    end
    return FloatingHud.hasBattleHudOwnerContinuity(battle)
  end
  -- Older Dramatic Shape/Potato hosts predate receipts. Preserve their reviewed
  -- ownership rule while still admitting Safari now that it has a complete
  -- status, ball-count and four-action replacement.
  return battleShot(battle) ~= nil
end

-- A successful provider already ran Gen1's HUD lifecycle once inside VASC's
-- private layer.  Some engine/companion draw chains invoke drawHUDs again late
-- in the public battle pass; keep that real method alive under a zero scissor
-- so no native Safari status block can cover the committed ORAS card.
function FloatingHud.installNativeHudSuppression()
  local current = BattleState.drawHUDs
  if type(current) ~= "function" then return false end
  if current == FloatingHud.currentHudSuppression then return true end

  local base = current
  local wrapped = function(self, ...)
    local ownsStatusSurface = floatingStatusHudEnabled(self)
      and FloatingHud.nativeReplacementCommitted(self)
    if not ownsStatusSurface then return base(self, ...) end

    g.push("all")
    g.setScissor(0, 0, 0, 0)
    local results = FloatingHud.packValues(pcall(base, self, ...))
    g.pop()
    if not results[1] then error(results[2], 0) end
    return FloatingHud.unpackValues(results, 2, results.n)
  end
  FloatingHud.currentHudSuppression = wrapped
  BattleState.drawHUDs = wrapped
  return true
end

function FloatingHud.installNativeTextSuppression()
  local current = BattleState.drawTextArea
  if type(current) ~= "function" then return false end
  if current == FloatingHud.currentTextSuppression then return true end

  -- Capture the current function in this wrapper's closure. If another renderer
  -- wraps/replaces us later, reinstalling outside it remains recursion-safe.
  local base = current
  local wrapped = function(self, ...)
    local ownsBottomSurface = floatingCommandsEnabled(self)
      and FloatingHud.nativeReplacementCommitted(self)
    if not ownsBottomSurface then return base(self, ...) end

    g.push("all")
    g.setScissor(0, 0, 0, 0)
    local results = FloatingHud.packValues(pcall(base, self, ...))
    g.pop()
    if not results[1] then error(results[2], 0) end
    return FloatingHud.unpackValues(results, 2, results.n)
  end
  FloatingHud.currentTextSuppression = wrapped
  BattleState.drawTextArea = wrapped
  return true
end

function FloatingHud.nativeTextSinkCanvas()
  if FloatingHud.nativeTextSink then return FloatingHud.nativeTextSink end
  local ok, canvas = pcall(g.newCanvas, 160, 144, { dpiscale = 1 })
  if not (ok and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest")
  FloatingHud.nativeTextSink = canvas
  return canvas
end

function FloatingHud.installBattleTextSink(battle)
  if not battle then return false end
  if rawget(battle, "drawTextArea") == battle._ascendantBattleHudTextSinkWrapper then
    return true
  end
  local base = rawget(battle, "drawTextArea") or BattleState.drawTextArea
  if type(base) ~= "function" then return false end
  local wrapped = function(self, ...)
    local owns = floatingCommandsEnabled(self)
      and FloatingHud.nativeReplacementCommitted(self)
    local sink = owns and FloatingHud.nativeTextSinkCanvas() or nil
    if not sink then return base(self, ...) end
    local previous = g.getCanvas()
    local blend, alpha = g.getBlendMode()
    g.setCanvas(sink)
    g.clear(0, 0, 0, 0)
    local results = FloatingHud.packValues(pcall(base, self, ...))
    if previous then g.setCanvas(previous) else g.setCanvas() end
    g.setBlendMode(blend or "alpha", alpha)
    if not results[1] then error(results[2], 0) end
    return FloatingHud.unpackValues(results, 2, results.n)
  end
  battle._ascendantBattleHudTextSinkWrapper = wrapped
  battle.drawTextArea = wrapped
  return true
end

-- KASC's caught marker and standalone EXP strip duplicate information now
-- integrated into the ORAS cards. KASC owns those overlays and exposes the
-- only supported ownership seam. Older providers without that public seam
-- remain untouched and fail open.
function FloatingHud.installKascOverlaySuppression()
  local kasc = kascExports()
  if not kasc then return false end
  local battleService = type(kasc.qualityOfLife) == "table"
    and kasc.qualityOfLife.battle or nil
  if type(battleService) == "table"
      and type(battleService.setHudOwnerPredicate) == "function" then
    return battleService:setHudOwnerPredicate(function(state)
      if not FloatingHud.ownsHostStatus(state) then return false end
      return FloatingHud.hasExactHudSnapReceipt(state)
    end)
  end
  return false
end

FloatingHud.installNativeHudSuppression()
FloatingHud.installNativeTextSuppression()
if mod.events and type(mod.events.on) == "function" then
mod.events:on("battle.started", function(event)
    -- A recycled or externally prepared BattleState must begin without an
    -- ownership decision from an earlier fight. The first exact receipt below
    -- is the only operation allowed to establish this battle's latch.
    FloatingHud.clearBattleHudOwner(event and event.battle)
    if event and event.battle and event.battle.game then
      activeRuntimeGame = event.battle.game
    end
    -- Reinstall outside any companion wrapper added after mods.loaded.  The
    -- exact receipt predicate keeps failed/standard/demo frames fail-open.
    FloatingHud.installNativeHudSuppression()
    FloatingHud.installNativeTextSuppression()
    FloatingHud.installBattleTextSink(event and event.battle)
    FloatingHud.installKascOverlaySuppression(event and event.battle)
  end)
end

local bottomHookInstalled = false
if mod.hooks and type(mod.hooks.wrap) == "function" then
  mod.hooks:wrap("battle.bottom_ui_visible", function(next, state)
    if floatingCommandsEnabled(state)
        and FloatingHud.nativeReplacementCommitted(state) then
      return false
    end
    return next(state)
  end, 12000)
  bottomHookInstalled = true
end

-- Compatibility fallback when the launcher visibility hook is unavailable.
if not bottomHookInstalled then
  local BOTTOM_KEY = "_floatingBattleHudBaseBottomUIVisible"
  if not BattleState[BOTTOM_KEY] then
    BattleState[BOTTOM_KEY] = BattleState.bottomUIVisible
  end
  local baseBottomUIVisible = BattleState[BOTTOM_KEY]
  if type(baseBottomUIVisible) == "function" then
    function BattleState:bottomUIVisible(...)
      if floatingCommandsEnabled(self)
          and FloatingHud.nativeReplacementCommitted(self) then
        return false
      end
      return baseBottomUIVisible(self, ...)
    end
  end
end

-- Gen1Recomp's real drawHUDs consults this semantic hook before emitting the
-- enemy name/HP block.  Modern VASC intentionally waits for the exact receipt:
-- hidden lifecycle draws before commit remain intact, while the later public
-- pixel pass is suppressed only after ORAS (or the complete VASC legacy
-- compositor) has actually landed.
if isAscendantHost and hostProviderAvailable then
  local statusReceiptHookInstalled = false
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("battle.status_hud_visible", function(next, state)
      if floatingStatusHudEnabled(state)
          and FloatingHud.nativeReplacementCommitted(state) then
        return false
      end
      return next(state)
    end, 12500)
    statusReceiptHookInstalled = true
  end
  if not statusReceiptHookInstalled then
    local STATUS_RECEIPT_KEY = "_floatingBattleHudReceiptStatusVisible"
    if not BattleState[STATUS_RECEIPT_KEY] then
      BattleState[STATUS_RECEIPT_KEY] = BattleState.statusHUDVisible
    end
    local baseStatusHUDVisible = BattleState[STATUS_RECEIPT_KEY]
    if type(baseStatusHUDVisible) == "function" then
      function BattleState:statusHUDVisible(...)
        if floatingStatusHudEnabled(self)
            and FloatingHud.nativeReplacementCommitted(self) then
          return false
        end
        return baseStatusHUDVisible(self, ...)
      end
    end
  end
end

-- Public, versioned rectangles consumed by VASC's camera director.  This is
-- deliberately a provider-v1 capability rather than a VASC/KASC identity
-- check: any complete replacement HUD may describe its occupied pixels, and a
-- claiming provider which omits the capability simply receives a static shot.
function FloatingHud.cameraBounds(battle, shot)
  if not (battle and shot and tonumber(shot.pw) and tonumber(shot.ph)
          and supportedFloatingLayout(battle)) then return nil end
  local reserved = {}
  local function add(id, rect, ownerSide, allowOwnActorOverlap, ownerVisualGap,
                     safeAreaPolicy)
    if type(rect) == "table" and tonumber(rect[1]) and tonumber(rect[2])
        and tonumber(rect[3]) and tonumber(rect[4])
        and rect[3] > 0 and rect[4] > 0 then
      local item = {
        id=id, x=rect[1], y=rect[2], w=rect[3], h=rect[4],
      }
      if allowOwnActorOverlap == true then
        item.ownerSide = ownerSide
        item.allowOwnActorOverlap = true
        if ownerVisualGap == true then item.ownerVisualGap = true end
      end
      if safeAreaPolicy ~= nil then item.safeAreaPolicy = safeAreaPolicy end
      reserved[#reserved + 1] = item
    end
  end

  local flowRect, flowId, commandBounds
  if floatingCommandsEnabled(battle) and not battle.introBalls then
    if battle.phase == "menu" then
      local k, w, h
      flowRect, k, w, h = HudRuntime.commandRectFor(shot)
      flowId = "command"
      if flowRect and hudStyle() == "oras" and not battle.safari then
        commandBounds = FloatingHud.orasCommandBounds(battle, flowRect, k, w, h)
      end
    elseif battle.phase == "moveSelect" and not battle.safari then
      flowRect, flowId = HudRuntime.fightRectFor(shot), "fight"
    elseif battle.phase == "messages" or battleMessageActive(battle) then
      flowRect, flowId = HudRuntime.messageRectFor(shot), "message"
    end
  end

  -- Calculate this once before proposing status geometry. The identical rect
  -- is both a latch obstacle and the public camera reservation below.
  local statusReserved = commandBounds or (flowRect and { flowRect } or {})
  local safariRect = FloatingHud.safariBallCountBounds(battle, shot)
  if safariRect then statusReserved[#statusReserved + 1] = safariRect end

  if floatingStatusHudEnabled(battle) and FloatingHud.statusAssetsReady() then
    local slide = (battle.introSlide or 0) * 4
    local enemyLive, playerLive = floatingHudLive(battle, slide)
    -- Pure proposal only. Current owner cards come from the exact candidate
    -- head/hull and are never written to per-battle state from this query.
    local proposal = FloatingHud.proposeStatusLatch(
      battle, shot, playerLive, enemyLive, statusReserved)
    if not proposal.ready then
      for _, side in ipairs({ "player", "enemy" }) do
        if proposal.live[side] and proposal.pending[side] then
          return nil, "owner-render-pending"
        end
      end
      return nil, "owner-render-pending"
    end
    -- Camera and renderer share the same current head-projected rectangles.
    -- An unsafe proposal is a seat rejection; no stale card may be retained
    -- over a moving Pokemon merely to keep the provider nominally complete.
    if not proposal.complete then return nil, "owner-render-unsafe" end
    local slots = proposal.slots
    for _, side in ipairs({ "player", "enemy" }) do
      local slot = slots[side]
      local live = side == "player" and playerLive or enemyLive
      local visual = type(shot.actorVisuals) == "table"
        and shot.actorVisuals[side] or nil
      -- Damage/attack frames may intentionally omit one actor visual. The
      -- renderer keeps that exact live owner's committed card, so its nominal
      -- conservative prism is not a visible pixel collision for this frame.
      -- Publish the gap explicitly; a switch cannot earn it because the slot
      -- must still match the current battler/mon owner.
      local ownerVisualGap = live and visual == nil
        and FloatingHud.statusSlotMatchesLiveOwner(slot, battle, side) or false
      add(side .. "-status", slot and slot.rect, side,
          ownerVisualGap, ownerVisualGap)
    end
    add("safari-balls", safariRect)
  end

  -- The framed command/fight/message surface deliberately joins the physical
  -- bottom edge.  Publish that one narrow exception instead of making the
  -- camera infer it from a rectangle: status cards and floating furniture
  -- remain fully constrained by the reported iOS safe area.
  local flowSafeAreaPolicy = flowRect and hudStyle() ~= "float"
    and (flowId == "command" or flowId == "fight" or flowId == "message")
    and math.abs((flowRect[2] or 0) + (flowRect[4] or 0) - shot.ph) < 1e-6
    and "physical-bottom-dock" or nil
  if commandBounds then
    for _, rect in ipairs(commandBounds) do
      local policy = math.abs(rect[2]+rect[4]-shot.ph) < 1e-6
        and "physical-bottom-dock" or nil
      add("command", rect, nil, nil, nil, policy)
    end
  else
    add(flowId, flowRect, nil, nil, nil, flowSafeAreaPolicy)
  end

  local left, top, right, bottom = FloatingHud.safeInsets(shot)
  return {
    schema="voxel-ascendant/hud-camera-bounds/v1",
    width=shot.pw, height=shot.ph,
    safeInsets={ left or 0, top or 0, right or 0, bottom or 0 },
    reserved=reserved,
  }
end

-- Decide whether the provider produced a complete frame. Before the first
-- exact ORAS receipt this remains strictly fail-open. Once this SAME battle
-- owns the presentation, an expected actor gap may omit one status card (or
-- all furniture during a silent throw/return animation) without handing the
-- frame back to Cartridge 2D. Required message/menu pixels must still exist,
-- and an exception or missing asset never reaches this decision at all.
function FloatingHud.providerFrameComplete(
    battle, statusRequired, statusComplete,
    commandsRequired, bottomDrawn, statusDrawn)
  local continuity = FloatingHud.battleHudOwnerLatched(battle)
  if statusRequired and statusComplete ~= true and not continuity then
    return false
  end
  if commandsRequired and bottomDrawn ~= true then return false end
  if battle and battle.safari and not continuity then
    if statusDrawn ~= true or statusComplete ~= true then return false end
    if (battle.phase == "menu" or battle.phase == "messages")
        and bottomDrawn ~= true and not battle.introBalls then
      return false
    end
  end
  local complete = (statusRequired and statusComplete == true
      and (not commandsRequired or bottomDrawn == true))
    or (not statusRequired and (statusDrawn or bottomDrawn))
    or (floatingCommandsEnabled(battle) and battle and battle.introBalls
        and supportedFloatingLayout(battle))
  return complete or continuity
end

local hudProvider = {
  apiVersion = 1,
  id = INTEGRATED_KASC and "kanto_ascendant.oras"
                           or "voxel_ascendant.oras",
  -- KASC owns the whole HUD decision in a combined stack. If its live QoL
  -- choice is STANDARD (or its ORAS draw fails), VASC must not substitute a
  -- different built-in skin underneath it; the native/readable frame wins.
  exclusive = INTEGRATED_KASC,
  active = function(battle) return floatingStatusHudEnabled(battle)
                            or floatingCommandsEnabled(battle) end,
  claim = function(battle, shot)
    if not (battle and shot and supportedFloatingLayout(battle)) then
      return false
    end
    -- Safari's native drawHUDs owns its only status block, while drawTextArea
    -- owns BALLxNN and the four-action flow. Claiming only half
    -- would erase the other half once the renderer publishes snapped=true.
    -- Require a complete transactional replacement; otherwise fail open to
    -- VASC's legacy compositor/native engine UI for this frame.
    if battle.safari then
      return not not (floatingStatusHudEnabled(battle)
         and FloatingHud.statusAssetsReady()
         and floatingCommandsEnabled(battle) and FloatingHud.commandAssetsReady()
        )
    end
    return not not ((floatingStatusHudEnabled(battle)
          and FloatingHud.statusAssetsReady())
        or (floatingCommandsEnabled(battle) and FloatingHud.commandAssetsReady())
      )
  end,
  draw = function(battle, shot, context)
    local previousUpright = FloatingHud.providerCanvasUpright
    FloatingHud.providerCanvasUpright = context and context.preflipped == true
    local okDraw, statusDrawn, bottomDrawn, statusProposal, statusComplete =
      pcall(drawFloatingSceneUI, battle, shot, false, true)
    FloatingHud.providerCanvasUpright = previousUpright
    if not okDraw then error(statusDrawn, 0) end
    local slide = ((battle and battle.introSlide) or 0) * 4
    local enemyLive, playerLive = floatingHudLive(battle, slide)
    local statusRequired = floatingStatusHudEnabled(battle)
      and (enemyLive or playerLive)
    local commandsRequired = floatingCommandsEnabled(battle) and battle
      and not battle.introBalls and (battle.phase == "menu"
        or battle.phase == "moveSelect" or battle.phase == "messages"
        or battleMessageActive(battle))
    if not FloatingHud.providerFrameComplete(
        battle, statusRequired, statusComplete,
        commandsRequired, bottomDrawn, statusDrawn) then
      return false
    end
    if statusRequired and statusComplete == true and statusProposal
        and statusProposal.complete then
      if not (context and type(context.afterCommit) == "function") then
        return false
      end
      local proposal = statusProposal
      if context.afterCommit(function()
          return FloatingHud.commitStatusLatch(proposal)
        end) ~= true then
        return false
      end
    end
    return true
  end,
  suppressesNativeStatus = function(battle)
    return floatingStatusHudEnabled(battle)
  end,
  suppressesNativeText = function(battle)
    return floatingCommandsEnabled(battle)
  end,
  suppressesBottomUi = function(battle)
    return floatingCommandsEnabled(battle)
  end,
  cameraBoundsSchema = "voxel-ascendant/hud-camera-bounds/v1",
  cameraBounds = function(battle, shot)
    return FloatingHud.cameraBounds(battle, shot)
  end,
  -- The provider transaction remains fail-open on its private canvas, but the
  -- compositor only needs to clear/blit pixels occupied by these exact HUD
  -- regions. This avoids two empty full-window GPU passes at Retina/4K sizes.
  damageBoundsSchema = "voxel-ascendant/hud-damage-bounds/v1",
  damageBounds = function(battle, shot)
    -- The Mega sphere/sigil/flash are scene-space presentation, not HUD
    -- furniture. While they are active the private provider layer must be
    -- committed as a whole; limiting the transaction to the card/menu
    -- rectangles would successfully draw the effect and then discard every
    -- pixel around the projected battler.
    if battle and battle._ascendantBattleHudMegaTransformation then
      return nil
    end
    -- Pushed choices/pickers extend beyond ordinary status/message damage
    -- rectangles. A regional commit otherwise clips their rendered pixels
    -- (SHIFT YES/NO became only a thin border on mobile). Use a complete
    -- transaction for these temporary foregrounds; ordinary frames retain
    -- the regional optimization and the same allocated provider canvas.
    local choice = battle and battle._floatingBattleChoice
    if (choice and HudRuntime.stateInStack(battle.game, choice))
        or HudRuntime.partyOverlayActiveForBattle(battle)
        or HudRuntime.moveLearnOverlayActiveForBattle(battle)
        or HudRuntime.nicknameOverlayActiveForBattle(battle) then
      return nil
    end
    local bounds = FloatingHud.cameraBounds(battle, shot)
    if not bounds or type(bounds.reserved) ~= "table" then return nil end
    local rects = {}
    for _, rect in ipairs(bounds.reserved) do
      -- Camera reservations already contain the complete visual rectangle.
      -- Keep a small physical-pixel guard for filtered edges and shadows.
      local pad = 8
      rects[#rects + 1] = {
        x=(tonumber(rect.x) or 0) - pad,
        y=(tonumber(rect.y) or 0) - pad,
        w=(tonumber(rect.w) or 0) + pad * 2,
        h=(tonumber(rect.h) or 0) + pad * 2,
      }
    end
    if #rects == 0 then return nil end
    return {
      schema="voxel-ascendant/hud-damage-bounds/v1",
      width=shot.pw, height=shot.ph, rects=rects,
    }
  end,
  finishBattle = function(battle)
    FloatingHud.clearMegaPresentation(battle)
    FloatingHud.clearBattleHudOwner(battle)
    return FloatingHud.clearStatusLatch(battle)
  end,
}
local registerProvider = INTEGRATED_VASC
  and registerBundledProvider
  or OverworldBattle.setBattleHudProvider
if isAscendantHost and type(registerProvider) == "function" then
  local okProvider, providerReason = pcall(
    registerProvider, hudProvider)
  if not okProvider or providerReason == false then
    mod.log:warn("%s ORAS HUD provider registration failed open: %s",
                 INTEGRATED_KASC and "KASC" or "VASC",
                 tostring(providerReason))
  end
end

mod.exports.orasBattleHud = FloatingHud
mod.exports.ascendantBattleHud = {
  apiVersion = 1,
  version = "0.5.0-vasc.1",
  available = true,
  hostMode = function() return hostMode end,
  platform = PLATFORM_OS,
  supports = { MAP=true, ARENA=true, DISCS=true },
  statusScale = function() return FloatingHud.STATUS_SCALE end,
  enabled = battleHudEnabled,
  provider = hudProvider,
}
mod.log:info("%s ORAS Battle HUD installed over %s %s (%s)",
             INTEGRATED_KASC and "KASC" or "VASC",
             tostring(hostId or "voxel host"), tostring(ds.version), tostring(hostMode))
return FloatingHud
end
