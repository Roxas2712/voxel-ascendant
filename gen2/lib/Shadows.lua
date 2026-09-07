-- Cast-shadow quality switch shared by the free-roam and battle scenes.
--
-- Shadow mapping is one of the most expensive passes in the renderer and is
-- particularly fragile on some mobile GPUs.  It used to be unconditional:
-- the only way to lose it was for canvas creation or shader compilation to
-- fail.  This setting makes the intended fallback explicit and persistent.
--
-- ON remains the default so existing installs keep their current look.  OFF
-- skips the light pass and makes the scene shaders use their already-bound
-- blank map with a zero shadow weight.  No GPU object has to be destroyed,
-- which makes changing the row safe in the middle of a map or battle.

local V = ...

local ModSetting = V.require("ModSetting")

local Shadows = {}

Shadows.KEY = "shadows"
Shadows.LABEL = "SHADOWS"

Shadows.setting = ModSetting.new(Shadows.KEY, Shadows.LABEL,
                                 { true, false }, { "ON", "OFF" })

function Shadows.enabled()
  return Shadows.setting:get() and true or false
end

return Shadows
