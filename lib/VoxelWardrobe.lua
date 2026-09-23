-- Voxel garments share the wardrobe's saved choices, never its HD pixels.
local V=...
local M={schema='ascendant.voxel-wardrobe/v1',errors={},cache={},built=0}
local packs,compositor={}
local order,sizes={},{}
local CACHE_ROOT="wardrobe/voxel-demo/"
local function saveIndex()
 local lines={};for _,file in ipairs(order)do lines[#lines+1]=file.." "..sizes[file]end
 assert(V.mod.cache:write(CACHE_ROOT.."index.txt",table.concat(lines,"\n")))
end
local function prune(keep)
 local total=0;for _,size in pairs(sizes)do total=total+size end
 while #order>96 or total>64*1024*1024 do
  local file=table.remove(order,1);assert(file~=keep,"voxel atlas exceeds cache budget")
  assert(V.mod.cache:delete(file));total=total-sizes[file];sizes[file]=nil
  for key,item in pairs(M.cache)do if item.file==file then M.cache[key]=nil end end
 end
end
do
 local body=V.mod.cache:read(CACHE_ROOT.."index.txt")
 if type(body)=="string"and #body<30000 then
  for role,key,size in body:gmatch("wardrobe/voxel%-demo/(%a+)/([0-9a-f]+)%.png (%d+)")do
   if (role=="red"or role=="blue"or role=="green")and #key==64 then
    local file=CACHE_ROOT..role.."/"..key..".png";local info=V.mod.cache:info(file)
    if info and not sizes[file]then order[#order+1]=file;sizes[file]=info.size or tonumber(size)end
   end
  end
 end
 prune();saveIndex()
end
local ROOT='integrated/ascendant_pokemon_overworld/assets/voxel-wardrobe/'
local function readLua(path)
 local code=assert(V.mod:read(path),'missing voxel wardrobe file '..path)
 return assert((loadstring or load)(code,'@'..V.mod.path..'/'..path))()
end
local function sha(bytes)return love.data.encode('string','hex',love.data.hash('sha256',bytes))end
function M.resolve(role,action,wardrobe,selection)
 role=tostring(role):lower();action=action or'walk'
 local dir=ROOT..role..'/'
 if not packs[role]then packs[role]=readLua(dir..'manifest.lua')end
 local pack=packs[role]
 selection=selection or wardrobe.get(role)
 local parts=wardrobe.assets.parts(role:upper(),selection)
 -- Original bags keep the Champion palette in voxel presentation as in HD.
 -- Copy the selection: never mutate the shared HD/native parts or saved choices.
 if selection.outfit=='champion'and parts.accessory=='original'and pack.parts.accessory['champion-bag']then
  local resolved={};for key,value in pairs(parts)do resolved[key]=value end
  resolved.accessory='champion-bag';parts=resolved
 end
 local fields={pack.revision,role,action,selection.hair or'natural',selection.streak or'none'}
 for _,slot in ipairs({'upper','lower','footwear','head','eyewear','accessory'})do fields[#fields+1]=parts[slot]or''end
 local request=table.concat(fields,':')
 local hit=M.cache[request]
 if hit and V.mod.cache:exists(hit.file)then return hit.path end
 compositor=compositor or readLua('integrated/wardrobe/wardrobe_overlay.lua')
 local output,receipt=compositor.build(pack,action,parts,{
  newImage=love.image.newImageData,sha256=sha,
  read=function(file)return love.image.newImageData(V.mod.path..'/'..dir..file)end,
 },{hair=selection.hair,streak=selection.streak,allowDraft=M.allowDraft==true or(V.mod.exports.voxelCharacterCard and V.mod.exports.voxelCharacterCard.enabled())==true})
 local png=output:encode('png');output:release()
 local bytes=png:getString();png:release()
 -- The path carries the geometry family so idle/blink use voxel landmarks.
 local file='wardrobe/voxel-demo/'..role..'/'..receipt.cacheKey..'.png'
 assert(V.mod.cache:write(file,bytes))
 local path='mod_cache/'..V.mod.id..'/'..file
 if not sizes[file]then order[#order+1]=file end;sizes[file]=#bytes;prune(file);saveIndex()
 M.cache[request]={path=path,file=file};M.built=M.built+1
 return path
end
function M.authoringMode(enabled)
 if enabled~=nil then M.allowDraft=enabled==true end
 return M.allowDraft==true
end
return M
