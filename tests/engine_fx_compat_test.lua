local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local moduleNames = { "src.render.GBCFX", "src.render.ShaderFX" }
local savedPreload, savedLoaded = {}, {}
for _, name in ipairs(moduleNames) do
  savedPreload[name] = package.preload[name]
  savedLoaded[name] = package.loaded[name]
end

local function reset()
  for _, name in ipairs(moduleNames) do package.loaded[name] = nil end
end

local function loadCompat()
  return assert(loadfile("lib/EngineFxCompat.lua"))({})
end

-- Gen1Recomp 0.2.19: use the legacy ladder and pin its persisted value.
reset()
local legacyLevels = {}
package.preload["src.render.GBCFX"] = function()
  return { setLevel = function(level) legacyLevels[#legacyLevels + 1] = level end }
end
package.preload["src.render.ShaderFX"] = function()
  error("0.2.19 must not probe ShaderFX after finding GBCFX", 0)
end
local legacy = loadCompat()
eq(legacy.kind(), "gbcfx", "0.2.19 engine FX was not detected")
local legacyOpts = { gbcfx = 4 }
eq(legacy.disable(legacyOpts), true, "legacy saved level was not reported changed")
eq(legacyOpts.gbcfx, 0, "legacy saved level was not pinned off")
eq(#legacyLevels, 1, "legacy setLevel was not called exactly once")
eq(legacyLevels[1], 0, "legacy live level was not disabled")

-- Gen1Recomp 0.2.22: GBCFX is gone. Deactivate both ShaderFX slots while
-- retaining preset names and parameter edits for restoration without VASC.
reset()
package.preload["src.render.GBCFX"] = function()
  error("module 'src.render.GBCFX' not found", 0)
end
local deactivations = 0
package.preload["src.render.ShaderFX"] = function()
  return { deactivate = function(slot)
    eq(slot, nil, "ShaderFX must deactivate both slots")
    deactivations = deactivations + 1
  end }
end
local current = loadCompat()
eq(current.kind(), "shaderfx", "0.2.22 ShaderFX was not detected")
local params = { ["lcd.slangp"] = { strength = 0.75 } }
local currentOpts = {
  gbcfx = 3,
  shaderfx = "lcd.slangp",
  shaderfxSecondary = "bevel.slangp",
  shaderfxParams = params,
}
eq(current.disable(currentOpts), true, "obsolete GBCFX value was not sanitized")
eq(currentOpts.gbcfx, 0, "obsolete GBCFX value survived 0.2.22 pinning")
eq(currentOpts.shaderfx, "lcd.slangp", "main ShaderFX choice was erased")
eq(currentOpts.shaderfxSecondary, "bevel.slangp",
   "secondary ShaderFX choice was erased")
eq(currentOpts.shaderfxParams, params, "ShaderFX parameter table was replaced")
eq(deactivations, 1, "ShaderFX was not deactivated exactly once")

-- Unexpected/custom engine packages missing both modules must still load VASC.
reset()
package.preload["src.render.GBCFX"] = function() error("missing GBCFX", 0) end
package.preload["src.render.ShaderFX"] = function() error("missing ShaderFX", 0) end
local absent = loadCompat()
eq(absent.kind(), "none", "missing engine FX did not fail open")
eq(absent.disable({}), false, "missing engine FX invented an option change")

for _, name in ipairs(moduleNames) do
  package.preload[name] = savedPreload[name]
  package.loaded[name] = savedLoaded[name]
end

print("engine FX compatibility: ok")
