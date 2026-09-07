-- Gen-1 loader shim for generation-neutral ambient audio focus.
local V = ...
local source, readErr = V.mod:read("shared/AmbientAudio.lua")
if type(source) ~= "string" then error(tostring(readErr), 0) end
local chunk, compileErr = (loadstring or load)(source,
  "@" .. tostring(V.mod.path or "VOXEL_ASCENDANT") .. "/shared/AmbientAudio.lua")
if not chunk then error(tostring(compileErr), 0) end
return chunk(V)
