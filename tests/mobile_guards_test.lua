local function check(value, message)
  if not value then error(message, 2) end
end

package.preload["src.core.Platform"] = function()
  return { detect = function() return { os = "Android" } end }
end

local setting = { get = function() return "full" end }
local V = {
  require = function(name)
    if name == "ModSetting" then
      return { new = function() return setting end }
    end
    if name == "Mat4" then
      return { identity = function() return {} end }
    end
    if name == "ShadowMap" then return { res = 1024 } end
    if name == "Sky" or name == "DayNight" then return {} end
    error("unexpected module: " .. tostring(name))
  end,
  mod = { log = { warn = function() end } },
}

local Water = assert(loadfile("lib/Water.lua"))(V)
check(Water.onAndroid() == true, "engine Android detection was ignored")
check(Water.level() == 0, "Android did not force flat-water fallback")
check(Water.enabled() == false, "Android reflective water stayed enabled")

Water._androidOverride = false
check(Water.level() == 2, "non-Android FULL water level changed")
check(Water.enabled() == true, "non-Android water was disabled")

io.write("PASS mobile_guards_test\n")
