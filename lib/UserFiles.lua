-- Public, read-only boundary for files placed inside the installed mod.
-- Gen1Recomp intentionally removes raw love.filesystem from mod sandboxes;
-- mod.assets is the supported shallow-list/info/path API and works for both
-- an extracted direct install and a mounted package. VASC never writes,
-- renames or removes anything in the user's folder.

local V = ...
local UserFiles = {}
local assets = V and V.mod and V.mod.assets

function UserFiles.info(relative, kind)
  if not (assets and type(assets.info) == "function") then return nil end
  local ok, value = pcall(assets.info, assets, relative)
  if not ok or type(value) ~= "table" then return nil end
  if kind and value.type ~= kind then return nil end
  return value
end

function UserFiles.list(relative)
  if not (assets and type(assets.list) == "function") then return {} end
  local ok, value = pcall(assets.list, assets, relative)
  return ok and type(value) == "table" and value or {}
end

function UserFiles.path(relative)
  if not (assets and type(assets.path) == "function") then return nil end
  local ok, value = pcall(assets.path, assets, relative)
  return ok and type(value) == "string" and value or nil
end

return UserFiles
