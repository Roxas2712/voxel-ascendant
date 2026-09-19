-- Validate the shipped captures independently of the runtime loader: every
-- view is complete, dimensions match the PNG IHDR, and residency is bounded.
local root=arg[1] or '.'
local index=assert(loadfile(root..'/gen2/data/johto_world_cache.lua'))()
local total,maxBytes,lightViews=0,0,0
local function u32(s,offset)
 local a,b,c,d=s:byte(offset,offset+3);return ((a*256+b)*256+c)*256+d
end
for _,version in ipairs({'crystal','gold'})do
 local entry=assert(index[version],version..' missing')
 assert(#entry.signature==64 and #entry.maps==31,'source manifest incomplete')
 local count,lights=0,0
 for key,v in pairs(entry.views)do
  count=count+1;local bytes=v.ground.w*v.ground.h*4;local hasLights=false
  assert(v.size==640 and #v.eye==3,'wrong projection receipt')
  for _,face in ipairs({'north','east','south','west'})do
   assert(v.files[face..'-land'],'open backdrop face: '..key..'/'..face)
  end
  local gf=assert(io.open(root..'/'..v.ground.path,'rb'));local gs=gf:read(24);gf:close()
  assert(u32(gs,17)==v.ground.w and u32(gs,21)==v.ground.h,'ground PNG dimensions')
  assert(v.ground.spanX>0 and v.ground.spanZ>0,'ground placement')
  for name,c in pairs(v.files)do
   assert(c.x>=0 and c.y>=0 and c.w>0 and c.h>0 and c.x+c.w<=v.size and c.y+c.h<=v.size,'invalid crop')
   local f=assert(io.open(root..'/'..v.path..'/'..name..'.png','rb'));local s=f:read(24);f:close()
   assert(s:sub(1,8)=='\137PNG\r\n\26\n' and u32(s,17)==c.w and u32(s,21)==c.h,'PNG dimension mismatch')
   bytes=bytes+c.w*c.h*4
   if name:match('%-lights$')then hasLights=true end
  end
  assert(bytes<=6*1024*1024,'view over budget: '..key)
  maxBytes=math.max(maxBytes,bytes)
  if hasLights then lights=lights+1 end
 end
 assert(count==124,'missing map/depth views');assert(lights>0,'night windows missing')
 print('CATALOG_VERIFIED',version,count,lights)
 total=total+count;lightViews=lightViews+lights
end
print('PASS_JOHTO_WORLD_CATALOG',total,maxBytes,lightViews)
