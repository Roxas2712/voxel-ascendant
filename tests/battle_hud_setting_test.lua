local function check(value, message)
  if not value then error(message, 2) end
end

local current
local setting = {
  get = function() return current or "transparent" end,
}

local V = {
  require = function(name)
    if name == "ModSetting" then
      return {
        new = function(key, label, values, labels)
          check(key == "hudBacking", "unexpected HUD setting key")
          check(label == "HUD BACKING", "unexpected HUD setting label")
          check(values[1] == "transparent", "transparent is not the default")
          check(labels[1] == "TRANSPARENT", "default label is not transparent")
          return setting
        end,
      }
    end
    if name == "PixelCanvas" then
      return { new = function() return false, nil end }
    end
    error("unexpected module: " .. tostring(name))
  end,
}

local BattleHud = assert(loadfile("lib/BattleHud.lua"))(V)
check(BattleHud.transparent(), "fresh HUD backing is not transparent")
check(BattleHud.statusPanel({}, {}) == true,
      "transparent status HUD attempted to draw a panel")

current = "frost"
check(not BattleHud.transparent(), "frost selection was ignored")
check(BattleHud.statusPanel({}, {}) == false,
      "frost path did not delegate to the panel renderer")

io.write("PASS battle_hud_setting_test\n")
