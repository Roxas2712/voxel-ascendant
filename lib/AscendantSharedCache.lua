-- KASC alone reuses the existing VASC sprite cache, so adding/removing VASC
-- never forces a second download. This adapter cannot access other mod data.
local M={ID='VOXEL_ASCENDANT'}
function M.new(fs)
  local function path(key)
    assert(type(key)=='string' and #key<=512 and not key:find('..',1,true)
      and not key:find('//',1,true) and not key:find('[\\:%z\1-\31]')
      and (key:match('^sprite%-content/[%w/_.-]+$')or key:match('^hd%-content/[%w/_.-]+$')),'invalid shared content key')
    return 'mod_cache/'..M.ID..'/'..key
  end
  local cache={}
  function cache:read(key)return fs.read(path(key))end
  function cache:info(key)return fs.getInfo(path(key),'file')end
  function cache:delete(key)return fs.remove(path(key))end
  function cache:write(key,bytes)
    if type(bytes)~='string' or #bytes>67108864 then return nil,'invalid cache bytes'end
    local p=path(key);local parent=p:match('^(.*)/[^/]+$')
    if fs.createDirectory(parent)==false then return nil,'cache directory unavailable'end
    return fs.write(p,bytes)
  end
  return cache
end
return M
