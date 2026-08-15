local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("%s (got %s, want %s)"):format(
    message, tostring(actual), tostring(expected)))
end

local optionValues = { battle_art = "crystal", crystal_motion = true }
local handles = {}
local mod = {
  id = "VOXEL_ASCENDANT",
  path = "/mods/VOXEL_ASCENDANT",
  options = { get = function(_, key) return optionValues[key] end },
  read = function(_, path)
    if path:match("^assets/crystal_gen1/") then return "png" end
    return nil
  end,
  find = function(id) return handles[id] end,
}

local Setting = {}
Setting.__index = Setting
function Setting.new(key)
  return setmetatable({ key = key }, Setting)
end
function Setting:get() return optionValues[self.key] end

local V = { mod = mod }
function V.require(name)
  assert(name == "ModSetting", "unexpected module " .. tostring(name))
  return Setting
end
function V.data(name)
  assert(name == "crystal_gen1_timing")
  return { normal = { ["25"] = { 100, 100 } }, shiny = {} }
end

local CrystalArt = assert(loadfile("lib/CrystalArt.lua"))(V)
local ctx = {
  kind = "battle", side = "front", species = "PIKACHU",
  mon = { species = "PIKACHU", shiny = false },
  data = { pokemon = { PIKACHU = { dex = 25 } } },
}
local calls = 0
local function native(path)
  calls = calls + 1
  return path
end

local selected = CrystalArt.resolve(native, "native/pikachu.png", ctx)
eq(calls, 1, "native resolver runs exactly once")
eq(selected,
  "/mods/VOXEL_ASCENDANT/assets/crystal_gen1/front/normal/25/001.png",
  "VASC selects its own copied Crystal front")
eq(ctx.trueColor, true, "Crystal card opts out of Gen-I recoloring")
check(CrystalArt.selected[ctx.mon] ~= nil,
  "front motion is armed for a supplied second frame")

local other = CrystalArt.resolve(function() return "other/provider.png" end,
  "native/pikachu.png", ctx)
eq(other, "other/provider.png", "another sprite provider keeps priority")

handles.kanto_ascendant = { exports = { version = "6.5.2" } }
local withKasc = CrystalArt.resolve(native, "kasc/pikachu.png", ctx)
eq(withKasc, "kasc/pikachu.png", "KASC remains the sprite authority")
eq(CrystalArt.selected[ctx.mon], nil, "KASC also clears VASC motion state")

handles.kanto_ascendant = nil
optionValues.battle_art = "native"
local nativeChoice = CrystalArt.resolve(native, "native/pikachu.png", ctx)
eq(nativeChoice, "native/pikachu.png", "GEN I menu choice preserves native art")

print(("PASS crystal_art_test: %d assertions"):format(checks))
