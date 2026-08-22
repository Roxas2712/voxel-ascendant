local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local engineTier = "high"
package.loaded["src.core.Performance"] = {
  detect = function() return engineTier end,
}

local stored = {}
local mod = { id = "VOXEL_ASCENDANT" }
mod.options = { get = function(_, key) return stored[key] end }
local V = { mod = mod }
local loaded = {}
function V.require(name)
  if not loaded[name] then loaded[name] = assert(loadfile("lib/" .. name .. ".lua"))(V) end
  return loaded[name]
end

local ModSetting = V.require("ModSetting")
local Profile = V.require("DeviceProfile")
local sky = ModSetting.new("sky", "SKY", { "full", "flat" }, { "FULL", "FLAT" })
local aa = ModSetting.new("aa", "AA", { 0, 2 }, { "OFF", "2X" })
Profile.configure({
  { setting = sky, max = "full", handheld = "full", eco = "flat" },
  { setting = aa, max = 2, handheld = 0, eco = 0 },
})

local game = {
  save = { options = { modOptions = { VOXEL_ASCENDANT = stored } } },
  mods = { modOptions = { VOXEL_ASCENDANT = stored } },
  writes = 0,
}
function game:writeOptions() self.writes = self.writes + 1 end

Profile.restore(game, true)
eq(Profile.setting:get(), "auto", "new save did not retain AUTO")
eq(Profile.effective(), "max", "desktop AUTO did not resolve to MAX")
eq(sky:get(), "full", "MAX sky")
eq(aa:get(), 2, "MAX AA")

sky:setValue("flat", game)
eq(Profile.setting:get(), "custom", "child change did not enter CUSTOM")
eq(stored.deviceProfile, "custom", "CUSTOM was not persisted")
eq(aa:get(), 2, "CUSTOM rewrote an unrelated child")

-- A stored CUSTOM profile never applies a preset during reload.
aa:sync(0)
stored.aa = 0
Profile.restore(game, false)
eq(aa:get(), 0, "CUSTOM reload overwrote a child")

-- Explicit AUTO remains dynamic across devices and applies atomically to the
-- same persisted child keys.
engineTier = "balanced"
Profile.setting:setValue("auto", game)
eq(Profile.effective(), "handheld", "mobile AUTO did not resolve")
eq(sky:get(), "full", "handheld sky")
eq(aa:get(), 0, "handheld AA")

-- Migration: old saves with hand-tuned children but no profile are CUSTOM.
stored.deviceProfile = nil
stored.sky, stored.aa = "flat", 0
sky:sync("flat")
aa:sync(0)
Profile.setting.index = nil
Profile.restore(game, false)
eq(Profile.setting:get(), "custom", "legacy tuned save was not preserved")
eq(sky:get(), "flat", "legacy sky was overwritten")

local row = Profile.row()
Profile.setting:setValue("auto", game, true)
if not row.value():find("AUTO/HANDHELD", 1, true) then
  error("AUTO row does not expose the effective device profile")
end

print("device profile persistence: ok")
