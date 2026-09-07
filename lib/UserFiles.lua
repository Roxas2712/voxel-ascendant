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

function UserFiles.image(relative)
  if not (assets and type(assets.image) == "function") then return nil end
  local ok, value = pcall(assets.image, assets, relative)
  return ok and value or nil
end

function UserFiles.read(relative, maxBytes)
  if not (assets and type(assets.read) == "function") then
    return nil, "bounded asset reads are unavailable"
  end
  local ok, value, reason = pcall(assets.read, assets, relative, maxBytes)
  if not ok or type(value) ~= "string" then
    return nil, ok and reason or tostring(value)
  end
  return value
end

function UserFiles.sha256(relative, maxBytes)
  if not (assets and type(assets.sha256) == "function") then
    return nil, "bounded asset hashing is unavailable"
  end
  local ok, value, reason = pcall(assets.sha256, assets, relative, maxBytes)
  if not ok or type(value) ~= "string" or not value:match("^[0-9a-f]+$")
     or #value ~= 64 then
    return nil, ok and reason or tostring(value)
  end
  return value
end

return UserFiles
