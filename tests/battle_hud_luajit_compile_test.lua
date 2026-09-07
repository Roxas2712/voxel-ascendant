-- Regression contract for LuaJIT's hard 200-local limit per function.
-- Loading is intentionally enough: executing the factory requires the full
-- engine, while the production blocker happened during compilation before
-- any dependency or fail-open path could run.

local path = arg and arg[1] or "battle_hud_oras.lua"
local chunk, err = loadfile(path)
assert(chunk, "battle_hud_oras.lua must compile under LuaJIT: "
  .. tostring(err))

print("battle_hud_oras LuaJIT compile: ok")
