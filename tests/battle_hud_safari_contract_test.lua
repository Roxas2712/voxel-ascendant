-- Safari-specific VASC/KASC replacement-HUD contract.
--
-- Safari used to be rejected by supportedFloatingLayout.  VASC therefore
-- fell back to its legacy wide compositor, whose successful receipt had no
-- owner; KASC correctly failed open and painted its native QoL fragments over
-- the otherwise valid VASC battle.  Exercise the real layout predicate and
-- the real OverworldBattle receipt/suppression seams with that combined state.

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local value = assert(handle:read("*a"))
  handle:close()
  return value
end

local source = read("battle_hud_oras.lua")
assert(loadfile("battle_hud_oras.lua"), "battle_hud_oras.lua does not compile")
local predicateStart = assert(source:find(
  "local function supportedFloatingLayout", 1, true))
local predicateEnd = assert(source:find(
  "\nend\n\n-- ---------------------------------------------------------------------------\n-- Host integration",
  predicateStart, true))
predicateEnd = predicateEnd + #"\nend" - 1
local predicateChunk, predicateError = (loadstring or load)([[
local OverworldBattle = { backPinned=function() return false end }
local function vrActive() return false end
]] .. source:sub(predicateStart, predicateEnd)
  .. "\nreturn supportedFloatingLayout\n", "@actual-safari-layout")
assert(predicateChunk, predicateError)
local supportedFloatingLayout = predicateChunk()

local safari = {
  kind="safari", safari={ balls=17 }, phase="menu", introBalls=true,
  enemy={ mon={ species="RHYHORN", level=25, hp=72 }, name="RHYHORN" },
}
eq(supportedFloatingLayout(safari), true,
  "Safari was rejected by the ORAS provider layout predicate")
eq(supportedFloatingLayout({ demo=true }), false,
  "scripted catch demo was incorrectly claimed as interactive ORAS Safari")
check(source:find('and { "BALL", "BAIT", "ROCK", "RUN" }', 1, true),
  "Safari ORAS command labels are absent")
check(source:find("drawSafariBallCount", 1, true),
  "Safari ORAS ball-count surface is absent")

-- Asset readiness is a public predicate consumed by the strict transactional
-- provider seam.  A chained Lua `and` expression returns its final image
-- userdata, not the boolean true; that made Safari's all-or-nothing claim look
-- truthy to ordinary code while `tryBattleHudProvider` correctly rejected it.
-- Execute the real asset/readiness functions with image-shaped objects so this
-- test preserves the exact type boundary that failed in the combined build.
local assetsStart = assert(source:find("local images = {}", 1, true))
local assetsEnd = assert(source:find(
  "\nlocal function selectPlateImage", assetsStart, true))
local assetChunk, assetError = (loadstring or load)([=[
local FloatingHud = { ASSET_SCALE=1/8 }
local function image(path)
  return {
    path=path,
    setFilter=function() end,
    getWidth=function() return 64 end,
    getHeight=function() return 32 end,
    getDimensions=function() return 64, 32 end,
  }
end
local mod = { assets={ image=function(_, path) return image(path) end } }
local MEGA_TRANSFORMATION_ASSET = "assets/hud/oras/mega_transformation.png"
local function hudLanguage() return "en" end
local function hudStyle() return "oras" end
]=] .. source:sub(assetsStart, assetsEnd - 1)
  .. "\nreturn FloatingHud\n", "@actual-safari-asset-readiness")
assert(assetChunk, assetError)
local AssetHud = assetChunk()
eq(type(AssetHud.statusAssetsReady()), "boolean",
  "status asset readiness is not a strict boolean")
eq(AssetHud.statusAssetsReady(), true, "loaded status asset was rejected")
eq(type(AssetHud.commandAssetsReady()), "boolean",
  "command asset readiness leaked the final image object")
eq(AssetHud.commandAssetsReady(), true,
  "complete loaded command asset set was rejected")

-- Real combined-save shape from the affected upgrade: ORAS was explicitly
-- selected while the retired position key still contained FRAME. The one-time
-- migration must not reinterpret an explicit modern choice as STANDARD.
local stored = { battleHudStyle="oras", battleHudPosition="frame" }
local SettingsV = {
  mod={
    id="VOXEL_ASCENDANT",
    options={ get=function(_, key) return stored[key] end },
    find=function(id)
      if id == "kanto_ascendant" then return { exports={} } end
    end,
  },
}
local settingsCache = {}
function SettingsV.require(name)
  if settingsCache[name] then return settingsCache[name] end
  eq(name, "ModSetting", "unexpected Safari settings dependency")
  settingsCache[name] = assert(loadfile("lib/ModSetting.lua"))(SettingsV)
  return settingsCache[name]
end
local Settings = assert(loadfile("lib/OrasBattleHudSettings.lua"))(SettingsV)
local combinedSave = {
  save={ options={ modOptions={ VOXEL_ASCENDANT=stored } } },
  mods={ modOptions={ VOXEL_ASCENDANT=stored } },
}
eq(Settings.migrateLegacyFrame(SettingsV.mod, combinedSave), false,
  "explicit ORAS Safari save was remigrated to STANDARD")
eq(Settings.style(), "oras", "combined Safari save lost ORAS selection")
eq(stored.battleHudPosition, "frame",
  "explicit ORAS save was destructively rewritten")

-- Execute the actual provider claim closure with the real layout predicate.
-- This is the precise branch that declined Safari in RC3.
local providerStart = assert(source:find(
  "function FloatingHud.providerFrameComplete(", 1, true))
local providerEnd = assert(source:find(
  "\nlocal registerProvider =", providerStart, true))
local providerChunk, providerError = (loadstring or load)([[
local INTEGRATED_KASC = false
local OverworldBattle = { backPinned=function() return false end }
local function vrActive() return false end
local STATUS_READY, COMMAND_READY = true, true
local DRAW_STATUS, DRAW_BOTTOM = true, true
local FloatingHud = {
  statusAssetsReady=function() return STATUS_READY end,
  commandAssetsReady=function() return COMMAND_READY end,
  battleHudOwnerLatched=function() return false end,
}
local function floatingStatusHudEnabled() return true end
local function floatingCommandsEnabled() return true end
local function floatingHudLive() return true, true end
local function drawFloatingSceneUI()
  -- Match the current provider's exact-latch return tuple. This fixture tests
  -- Safari's all-or-nothing ownership decision; the concrete latch geometry
  -- has its own real-render contracts.
  return DRAW_STATUS, DRAW_BOTTOM, nil, DRAW_STATUS
end
]] .. source:sub(predicateStart, predicateEnd)
  .. "\n" .. source:sub(providerStart, providerEnd - 1)
  .. [[
return hudProvider, function(statusReady, commandReady, drawStatus, drawBottom)
  STATUS_READY, COMMAND_READY = statusReady, commandReady
  if drawStatus ~= nil then DRAW_STATUS = drawStatus end
  if drawBottom ~= nil then DRAW_BOTTOM = drawBottom end
end
]], "@actual-safari-provider")
assert(providerChunk, providerError)
local provider, setProviderAssets = providerChunk()
eq(provider.claim(safari, { canvas={}, scale=2 }), true,
  "default ORAS provider did not claim the realistic Safari frame")
setProviderAssets(true, { image="loaded-command-assets" })
eq(type(provider.claim(safari, { canvas={}, scale=2 })), "boolean",
  "Safari provider claim leaked a truthy asset object")
eq(provider.claim(safari, { canvas={}, scale=2 }), true,
  "Safari provider did not normalize loaded command assets to a claim")
setProviderAssets(true, false)
eq(provider.claim(safari, { canvas={}, scale=2 }), false,
  "Safari provider claimed without its command replacement")
setProviderAssets(false, true)
eq(provider.claim(safari, { canvas={}, scale=2 }), false,
  "Safari provider claimed without its status/ball replacement")
setProviderAssets(true, true)
eq(provider.claim({ demo=true }, { canvas={}, scale=2 }), false,
  "default ORAS provider claimed the scripted catch demo")
eq(provider.draw(safari, { canvas={}, scale=2 }, {}), true,
  "complete Safari ORAS provider draw did not commit")
safari.introBalls = false
setProviderAssets(true, true, true, false)
eq(provider.draw(safari, { canvas={}, scale=2 }, {}), false,
  "partial Safari provider draw did not fail open")
setProviderAssets(true, true, true, true)
safari.introBalls = true

-- Install the actual VASC BattleState wrappers in a minimal engine fixture.
local nativeHUD, nativeText = 0, 0
local BattleState = {
  resolveBattleScale=function() return 1 end,
  picImage=function(_, image) return image end,
  backPlacement=function() return 0, 0 end,
  frontPlacement=function() return 0, 0 end,
  draw=function() end,
  drawPicsLayer=function() end,
  drawTextArea=function() nativeText = nativeText + 1 end,
  drawAnimLayer=function() end,
  drawZonePass=function() end,
  drawHUDs=function() nativeHUD = nativeHUD + 1 end,
  fxHidden=function() return false end,
  growInScale=function() return nil end,
}
local OverworldState = { pushBattle=function() end }
package.preload["src.battle.BattleState"] = function() return BattleState end
package.preload["src.world.OverworldController"] = function()
  return OverworldState
end
package.preload["src.core.Platform"] = function()
  error("headless Safari fixture uses love._os")
end
package.loaded["src.core.Platform"] = nil

_G.love = {
  _os="OS X",
  graphics={
    getCanvas=function() return nil end,
    setCanvas=function() end,
    getBlendMode=function() return "alpha", "alphamultiply" end,
    setBlendMode=function() end,
    setColor=function() end,
    push=function() end,
    pop=function() end,
    origin=function() end,
    setShader=function() end,
  },
}

local modules = {
  ModSetting={ new=function()
    return { get=function() return "auto" end }
  end },
  BattleArena={},
  BattleCam={ arenaDirectorSelected=function() return false end },
  BattleScene={ GB_W=160, GB_H=144 },
  BattleDOF={ invalidate=function() end },
  BattleHud={ invalidate=function() end },
  BattlePartyBalls={ PERSISTENT_RECT={ enemy={}, player={} } },
  BattlePics={ invalidate=function() end, filled=function(image) return image end },
  CanvasPresentation={ preflips=function() return false end },
  Voxel3D={}, ChunkMesher={},
}
local V = {
  require=function(name) return assert(modules[name], "missing " .. name) end,
  mod={ log={ warn=function() end } },
}
local OverworldBattle = assert(loadfile("lib/OverworldBattle.lua"))(V)
eq(OverworldBattle.install(), true, "VASC BattleState wrappers did not install")

local function upvalue(fn, wanted)
  for index = 1, 100 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return value end
  end
  error("missing upvalue " .. wanted)
end
local markSnapped = upvalue(upvalue(
  upvalue(OverworldBattle.update, "updateBattleFrame"), "commitShot"),
  "markSnapped")
local shot = { canvas={}, pw=1280, ph=720, scale=2 }
safari.voxelAscendantShot = shot

-- Real ORAS completion: KASC's public observer accepts this exact frame and
-- neither native status nor native text/command furniture may survive.
markSnapped(safari, shot, true, nil, "voxel_ascendant.oras")
local receipt = assert(OverworldBattle.hudSnapReceipt(safari))
eq(receipt.shot, shot, "ORAS Safari receipt shot")
eq(receipt.snapped, true, "ORAS Safari receipt snapped flag")
eq(receipt.owner, "voxel_ascendant.oras", "ORAS Safari receipt owner")
BattleState.drawHUDs(safari, 0)
BattleState.drawTextArea(safari)
eq(nativeHUD, 0, "native Safari HUD survived an exact ORAS receipt")
eq(nativeText, 0, "native Safari text/command area survived ORAS")

-- Successful legacy VASC fallback is still a complete visible owner. KASC
-- must not add QoL fragments merely because ORAS assets failed for one frame.
markSnapped(safari, shot, true, nil, "voxel_ascendant.legacy")
receipt = assert(OverworldBattle.hudSnapReceipt(safari))
eq(receipt.owner, "voxel_ascendant.legacy", "legacy fallback receipt owner")
BattleState.drawHUDs(safari, 0)
BattleState.drawTextArea(safari)
eq(nativeHUD, 0, "native Safari HUD survived a successful VASC fallback")
eq(nativeText, 0, "native Safari text survived a successful VASC fallback")

-- Genuine provider failure and explicit STANDARD remain fail-open: an
-- unsnapped receipt must delegate both native surfaces rather than erase UI.
markSnapped(safari, shot, false, "provider-failed", "voxel_ascendant.oras")
BattleState.drawHUDs(safari, 0)
BattleState.drawTextArea(safari)
eq(nativeHUD, 1, "provider failure did not restore native Safari HUD")
eq(nativeText, 1, "provider failure did not restore native Safari text")
markSnapped(safari, shot, false, "exclusive-provider-native",
            "voxel_ascendant.oras")
BattleState.drawHUDs(safari, 0)
BattleState.drawTextArea(safari)
eq(nativeHUD, 2, "STANDARD did not retain native Safari HUD")
eq(nativeText, 2, "STANDARD did not retain native Safari text")

print("Safari ORAS/KASC HUD ownership: ok")
