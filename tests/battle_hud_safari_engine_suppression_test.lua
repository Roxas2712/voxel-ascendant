-- Safari replacement-HUD pixel ownership against the byte-real Gen1Recomp
-- BattleState methods.  The older contract fixture supplied miniature HUD
-- methods; this one deliberately executes the imported engine's drawHUDs and
-- drawTextArea bodies, with only their asset/font sinks reduced to solid test
-- pixels.  That catches late native UI surviving over an exact VASC receipt.

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local value = assert(handle:read("*a"))
  handle:close()
  return value
end

local source = read("battle_hud_oras.lua")
check(source:find("function FloatingHud.nativeReplacementCommitted", 1, true),
  "shared exact-receipt native suppression predicate is absent")
check(source:find(
  "FloatingHud.nativeReplacementCommitted(state)", 1, true),
  "bottom/status visibility hooks do not use the exact receipt predicate")
check(not source:find(
  "battleShot(self) and not self.safari and not self.demo", 1, true),
  "Safari is still explicitly excluded from native suppression")

-- Preserve the real Engine method bodies while keeping this focused test
-- independent of generated font/HUD PNG contents.  Every engine glyph/tile
-- call paints an unmistakable opaque marker into the real LÖVE canvas.
local fontCalls, hudCalls = 0, 0
package.loaded["src.render.Font"] = nil
package.preload["src.render.Font"] = function()
  local Font = {}
  function Font.split(value)
    local out = {}
    for index = 1, #tostring(value or "") do out[index] = index end
    return out
  end
  function Font.draw(value, x, y)
    fontCalls = fontCalls + 1
    local width = math.max(1, #tostring(value or "")) * 4
    love.graphics.rectangle("fill", x or 0, y or 0, width, 4)
    return width
  end
  function Font.drawCode(_, x, y)
    fontCalls = fontCalls + 1
    love.graphics.rectangle("fill", x or 0, y or 0, 4, 4)
    return 4
  end
  function Font.drawBox(tx, ty, tw, th)
    fontCalls = fontCalls + 1
    love.graphics.rectangle("fill", tx * 8, ty * 8, tw * 8, th * 8)
  end
  return Font
end

package.loaded["src.render.HudTiles"] = nil
package.preload["src.render.HudTiles"] = function()
  return {
    tile=function(_, x, y)
      hudCalls = hudCalls + 1
      love.graphics.rectangle("fill", x or 0, y or 0, 4, 4)
    end,
    drawHPBar=function(_, tx, ty)
      hudCalls = hudCalls + 1
      love.graphics.rectangle("fill", tx * 8, ty * 8, 56, 6)
    end,
  }
end

package.loaded["src.core.Strings"] = nil
package.preload["src.core.Strings"] = function()
  local Strings = {}
  function Strings.get(value) return tostring(value or "") end
  function Strings.source(value) return value end
  return setmetatable(Strings, {
    __call=function(_, value) return tostring(value or "") end,
  })
end

package.loaded["src.battle.BattleState"] = nil
local BattleState = require("src.battle.BattleState")
check(type(BattleState.drawHUDs) == "function",
  "real Gen1Recomp BattleState:drawHUDs unavailable")
check(type(BattleState.drawTextArea) == "function",
  "real Gen1Recomp BattleState:drawTextArea unavailable")

local receiptStart = assert(source:find(
  "function FloatingHud.hasExactHudSnapReceipt", 1, true))
local receiptEnd = assert(source:find(
  "\nend\n\n-- VASC reserves its edge HUD", receiptStart, true))
receiptEnd = receiptEnd + #"\nend" - 1

local suppressionStart = assert(source:find(
  "function FloatingHud.nativeReplacementCommitted", 1, true),
  "shared exact-receipt native suppression predicate is absent")
local suppressionEnd = assert(source:find(
  "\nfunction FloatingHud.nativeTextSinkCanvas", suppressionStart, true))

local shot = { canvas={}, scale=2 }
local receipt = {
  schema="voxel-ascendant/hud-snap/v1",
  shot=shot,
  snapped=true,
  owner="voxel_ascendant.oras",
}
local OverworldBattle = {
  hudSnapReceipt=function() return receipt end,
}
local FloatingHud = {
  packValues=function(...) return { n=select("#", ...), ... } end,
  unpackValues=table.unpack or unpack,
}
local g = love.graphics
local function floatingStatusHudEnabled() return true end
local function floatingCommandsEnabled() return true end
local function supportedFloatingLayout(battle)
  return battle ~= nil and not battle.demo
end
local function battleShot(battle) return battle and battle.voxelAscendantShot end

local installSource = source:sub(receiptStart, receiptEnd) .. "\n"
  .. source:sub(suppressionStart, suppressionEnd - 1)
  .. "\nreturn FloatingHud\n"
local installEnv = setmetatable({
    FloatingHud=FloatingHud,
    OverworldBattle=OverworldBattle,
    BattleState=BattleState,
    g=g,
    floatingStatusHudEnabled=floatingStatusHudEnabled,
    floatingCommandsEnabled=floatingCommandsEnabled,
    supportedFloatingLayout=supportedFloatingLayout,
    battleShot=battleShot,
    isAscendantHost=true,
    hostProviderAvailable=true,
    type=type,
    rawget=rawget,
    pcall=pcall,
    error=error,
  }, { __index=_G })
local installChunk, installError
if loadstring then
  installChunk, installError = loadstring(
    installSource, "@actual-safari-native-suppression")
  if installChunk then setfenv(installChunk, installEnv) end
else
  installChunk, installError = load(
    installSource, "@actual-safari-native-suppression", "t", installEnv)
end
assert(installChunk, installError)
FloatingHud = installChunk()
eq(FloatingHud.installNativeHudSuppression(), true,
  "native HUD suppression did not install")
eq(FloatingHud.installNativeTextSuppression(), true,
  "native text suppression did not install")

local battle = setmetatable({
  kind="safari",
  safari={ balls=17 },
  phase="menu",
  menuIndex=1,
  frame=0,
  introSlide=0,
  introBalls=false,
  showEnemyTrainer=false,
  enemySendingOut=false,
  showPlayerBack=false,
  fx={},
  data={},
  enemy={
    name="NIDORINO",
    fainted=false,
    mon={ species="NIDORINO", level=31, hp=50, stats={ hp=50 } },
  },
  voxelAscendantShot=shot,
}, { __index=BattleState })
battle.statusHUDVisible = function() return true end
battle.bottomUIVisible = function() return true end
battle.caughtMarkerVisible = function() return false end
battle.colorMode = function() return false end
battle.growInScale = function() return false end

local canvas = assert(love.graphics.newCanvas(160, 144, { dpiscale=1 }))
local function opaquePixels()
  local data = canvas:newImageData()
  local pixels = 0
  for y = 0, data:getHeight() - 1 do
    for x = 0, data:getWidth() - 1 do
      local _, _, _, alpha = data:getPixel(x, y)
      if alpha > 0 then pixels = pixels + 1 end
    end
  end
  return pixels
end

local function renderNative()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  BattleState.drawHUDs(battle, 0)
  BattleState.drawTextArea(battle)
  love.graphics.setCanvas()
  return opaquePixels()
end

-- The exact successful ORAS frame must still execute both real Engine methods
-- for lifecycle compatibility, but neither method may contribute one pixel.
local beforeFont, beforeHud = fontCalls, hudCalls
eq(renderNative(), 0,
  "native Safari status/menu pixels survived exact ORAS receipt")
check(fontCalls > beforeFont and hudCalls > beforeHud,
  "suppression skipped rather than preserving Engine draw lifecycles")

-- VASC's complete legacy compositor is also a visible owner. It must not be
-- followed by another native pass if ORAS assets deliberately failed open to
-- that compositor rather than all the way to the in-frame engine UI.
receipt.owner = "voxel_ascendant.legacy"
eq(renderNative(), 0,
  "native Safari pixels survived a successful VASC legacy receipt")

-- Once one exact frame established this BattleState's owner, a stale-but-
-- successful receipt is the expected hand-over state while throw/switch or an
-- attack replaces the staged shot. The same battle must not flash native UI.
receipt.shot = {}
eq(renderNative(), 0,
  "stale successful battle owner flashed native Safari pixels")
receipt.shot = shot
receipt.owner = "voxel_ascendant.oras"

-- A failed provider must remain readable through the original Safari UI.
receipt = {
  schema="voxel-ascendant/hud-snap/v1", shot=shot, snapped=false,
  reason="provider-failed", owner="voxel_ascendant.oras",
}
check(renderNative() > 0,
  "provider failure did not fail open to the native Safari UI")

-- Scripted old-man/demo battles have their own cursor and always stay native,
-- even if a stale-looking receipt is presented by a hostile fixture.
receipt.snapped = true
battle.demo = true
check(renderNative() > 0,
  "scripted demo UI was incorrectly suppressed")

print("Safari byte-real Engine native suppression: ok")
