-- Installation-local, data-only cache of authored prop geometry. GPU objects
-- remain session-owned. A changed model/palette/mesher signature is a miss.
local V=...
local B=V.require('BuildBudget')
local Digest=V.require('GeometryDigest')
local C={hits=0,packagedHits=0,misses=0,writes=0}
local MAX_BYTES=16*1024*1024
local REVISION='authored-box-faces-v1'
local function api()
 local d=love and love.data;local store=V.mod and V.mod.cache
 if d and d.hash and d.pack and d.unpack then return d,store end
end
local function hash(d,raw)
 return Digest.hex(d,raw)
end
local function names(d,kind,signature,paletteSize)
 return 'voxel-geometry-v1/'..assert(hash(d,kind))..'.bin',
  assert(hash(d,REVISION..'|'..paletteSize..'|'..signature))
end
-- Both installations and the release package contain only validated numbers,
-- never Lua. The model signature is checked even for shipped data, so changing
-- a building/stone cannot accidentally reuse geometry from an older release.
local function decode(d,raw,key)
 if type(raw)~='string' or #raw<140 or #raw>MAX_BYTES or raw:sub(1,4)~='VGC1' or raw:sub(5,68)~=key then return end
 local body=raw:sub(133)
 if hash(d,body)~=raw:sub(69,132) then return end
 local nv,ni,pos=d.unpack('<I4I4',body)
 if nv==0 or nv%4~=0 or ni~=nv/4*6 or #body~=8+nv*48+ni*4 then return end
 local vertices,indices={},{}
 for i=1,nv do
  B.tick()
  local x,y,z,u,v,s,nextPos=d.unpack('<dddddd',body,pos);pos=nextPos
  local row={x,y,z,u,v,s}
  for _,n in ipairs(row)do if n~=n or math.abs(n)==math.huge then return end end
  vertices[i]=row
 end
 for i=1,ni do
  B.tick();local n,nextPos=d.unpack('<I4',body,pos);pos=nextPos
  if n<1 or n>nv then return end;indices[i]=n
 end
 return vertices,indices
end
function C.get(kind,signature,paletteSize)
 local d,store=api();if not d then return end
 local path,key=names(d,kind,signature,paletteSize)
 if store and store.read then
  local ok,vv,ii=pcall(function()
   if store.info then local info=store:info(path);if not info or not info.size or info.size>MAX_BYTES then return end end
   B.check();return decode(d,store:read(path),key)
  end)
  if ok and vv and ii then C.hits=C.hits+1;return vv,ii end
 end
 local mod=V.mod
 if mod and mod.read then
  local ok,vv,ii=pcall(function()
   B.check()
   -- Content-addressed files also share aliases with identical box layouts.
   -- No startup directory scan, write or all-model allocation is required.
   return decode(d,mod:read('assets/voxel-geometry-v1/'..key..'.bin'),key)
  end)
  if ok and vv and ii then
   C.hits=C.hits+1;C.packagedHits=C.packagedHits+1;return vv,ii
  end
 end
 C.misses=C.misses+1
end
function C.put(kind,signature,paletteSize,vertices,indices)
 local d,store=api();if not d or not store or not store.write then return false end
 if 140+#vertices*48+#indices*4>MAX_BYTES then return false end
 local ok,result=pcall(function()
  local path,key=names(d,kind,signature,paletteSize)
  local parts={d.pack('string','<I4I4',#vertices,#indices)}
  for _,row in ipairs(vertices)do B.tick();parts[#parts+1]=d.pack('string','<dddddd',unpack(row))end
  for _,n in ipairs(indices)do B.tick();parts[#parts+1]=d.pack('string','<I4',n)end
  local body=table.concat(parts);B.check()
  return store:write(path,'VGC1'..key..assert(hash(d,body))..body)
 end)
 if ok and result then C.writes=C.writes+1;return true end
 return false
end
return C
