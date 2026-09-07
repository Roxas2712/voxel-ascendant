-- Execute the real ORAS HUD factory with VASC's closed public facade shape.
-- OrasBattleMessageLayout is private and must arrive through the explicit
-- factory bundle; otherwise the first battle message draw freezes a nil
-- upvalue and crashes only after the HUD has installed successfully.

package.path = "./?.lua;./?/init.lua;"
  .. "/Users/maarten/Documents/Recompile/gen1recomp/?.lua;"
  .. "/Users/maarten/Documents/Recompile/gen1recomp/?/init.lua;"
  .. package.path

local function check(value, label)
  if not value then error("FAIL: " .. label, 2) end
end

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)"):format(
      label, tostring(expected), tostring(actual)), 2)
  end
end

local BattleState = {
  update=function() end,
  drawHUDs=function() end,
  drawTextArea=function() end,
  bottomUIVisible=function() return true end,
  statusHUDVisible=function() return true end,
}
local Game = { touchpressed=function() end }
local Font = {}
function Font.width(value) return #tostring(value or "") * 8 end
function Font.split(value)
  local out = {}
  value = tostring(value or "")
  for index = 1, #value do out[index] = { from=index, to=index } end
  return out
end
function Font.draw() end

package.preload["src.battle.BattleState"] = function() return BattleState end
package.preload["src.core.Game"] = function() return Game end
package.preload["src.render.Font"] = function() return Font end
package.preload["src.pokemon.Growth"] = function() return {} end
package.preload["src.core.Platform"] = function()
  return { detect=function() return { os="OS X" } end }
end
for _, name in ipairs({
  "src.ui.PartyMenu", "src.ui.MoveLearnMenu", "src.ui.ChoiceBox",
}) do
  package.preload[name] = function() return {} end
end

love = { graphics={} }
local g = love.graphics
for _, name in ipairs({
  "setColor", "rectangle", "line", "push", "pop", "origin",
  "setScissor", "setCanvas", "clear", "setBlendMode", "setShader",
}) do
  g[name] = function() end
end
g.getDimensions = function() return 1280, 720 end
g.getCanvas = function() return nil end
g.getBlendMode = function() return "alpha", "alphamultiply" end

local registeredProvider, installedLegacyBridge
local ownerOverworldBattle = {
  drawHudPanels=function() end,
  textPlacements=function() return { "owner-text" } end,
  hudTexture=function() return "owner-hud" end,
  hudLive=function() return true, true end,
  partyRects=function() return { owner=true } end,
  setDefaultBattleHudProvider=function(provider)
    registeredProvider = provider
    return true
  end,
  setLegacyCompatibilityBridge=function(bridge)
    installedLegacyBridge = bridge
    return true
  end,
}
local ownerTextPlacements = ownerOverworldBattle.textPlacements
local ownerPartyRects = ownerOverworldBattle.partyRects
local BattleCam = {}
local publicLookups = {}
local publicFacade = {}
local OverworldBattlePublic = assert(loadfile(
  "lib/adapters/gen1/OverworldBattlePublic.lua"))()
local publicOverworldBattle = OverworldBattlePublic.new(ownerOverworldBattle)
function publicFacade.require(name)
  publicLookups[#publicLookups + 1] = name
  if name == "OverworldBattle" then return publicOverworldBattle end
  if name == "BattleCam" then return BattleCam end
  -- Mirrors PublicFacade: private presentation helpers are intentionally not
  -- exported to companion mods.
  return nil
end

local mod = {
  id="VOXEL_ASCENDANT", version="test",
  exports={ lib=publicFacade },
  options={ get=function() return nil end },
  assets={ image=function() return nil end },
  log={ info=function() end, warn=function() end, error=function() end },
}

local MessageLayout = assert(loadfile("lib/OrasBattleMessageLayout.lua"))()
local mainHandle = assert(io.open("main_gen1.lua", "rb"))
local mainSource = assert(mainHandle:read("*a"))
mainHandle:close()
check(mainSource:find(
  'MessageLayout=V.require("OrasBattleMessageLayout")', 1, true),
  "Gen1 installer did not pass the private message bundle")
check(mainSource:find(
  "RegisterDefaultBattleHudProvider=function(provider)", 1, true),
  "Gen1 installer did not pass the bounded default-provider capability")
local factory = assert(loadfile("battle_hud_oras.lua"))()
local hud = assert(factory(mod, {
  MessageLayout=MessageLayout,
  RegisterDefaultBattleHudProvider=
    ownerOverworldBattle.setDefaultBattleHudProvider,
}))
eq(mod.exports.orasBattleHud, hud, "factory did not export installed HUD")
eq(registeredProvider, mod.exports.ascendantBattleHud.provider,
  "factory did not register its provider")
check(type(installedLegacyBridge) == "table",
  "real public OverworldBattle facade was not installed")
eq(rawget(publicOverworldBattle, "setDefaultBattleHudProvider"), nil,
  "default-provider setter leaked through the public facade")
eq(rawget(publicOverworldBattle, "textPlacements"), nil,
  "ORAS factory mutated public text placements")
eq(rawget(publicOverworldBattle, "partyRects"), nil,
  "ORAS factory mutated public party placements")
eq(ownerOverworldBattle.textPlacements, ownerTextPlacements,
  "ORAS factory replaced the private text-placement owner")
eq(ownerOverworldBattle.partyRects, ownerPartyRects,
  "ORAS factory replaced the private party-placement owner")

for _, name in ipairs(publicLookups) do
  check(name ~= "OrasBattleMessageLayout",
    "private message layout leaked through the public facade")
end

local visual = hud.layoutMessageLines({
  "ULTRALANGERNICKNAME used THUNDERBOLT!",
}, 288, 64)
check(visual and visual.complete, "real HUD message layout did not complete")
check(type(visual.lines) == "table" and #visual.lines >= 1,
  "real HUD message layout produced no draw rows")
local flattened = {}
for _, line in ipairs(visual.lines) do flattened[#flattened + 1] = line.text end
eq(table.concat(flattened, " "),
  "ULTRALANGERNICKNAME used THUNDERBOLT!",
  "real HUD message layout lost revealed text")

print("battle HUD private message bundle/draw path: ok")
