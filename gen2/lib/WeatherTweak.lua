-- Gen-2 loader shim for the generation-neutral optional weather tweak.
local V = ...
local source, readErr = V.mod:read("shared/WeatherTweak.lua")
if type(source) ~= "string" then
  error("VOXEL_ASCENDANT: shared WeatherTweak is missing: "
        .. tostring(readErr), 0)
end
local chunk, compileErr = (loadstring or load)(
  source, "@" .. tostring(V.mod.path or "VOXEL_ASCENDANT")
          .. "/shared/WeatherTweak.lua")
if not chunk then error(tostring(compileErr), 0) end
return chunk(V)
