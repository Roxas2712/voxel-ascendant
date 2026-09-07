-- The sealed source remains intact locally. The downloadable RC excludes
-- only new Pokemon HD art; MMO fallbacks and every HD character stay offline.
local M={}
local optional={"pokemon-animation-cards","pokemon-flame-cards",
  "pokemon-idle-events-549","pokemon-runtime","pokemon-runtime-549",
  "pokemon-walksheets","pokemon-walksheets-549","followers"}
function M.optional(path)
  for _,name in ipairs(optional)do
    local prefix="assets/"..name.."/"
    if type(path)=="string" and path:sub(1,#prefix)==prefix then return true end
  end
  return false
end
return M
