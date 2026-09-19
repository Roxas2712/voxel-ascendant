local profile=assert(loadfile('gen2/data/voxel_heights.lua'))()
local source=assert(io.open('gen2/lib/Buildings.lua')):read('*a')
local a=assert(source:find('local function matches(',1,true))
local b=assert(source:find('-- Two native maps',a,true))
local chunk=assert(loadstring(source:sub(a,b-1)..'return matches'))
local function keyOf(x,y)return(y+64)*4096+x+64 end
setfenv(chunk,setmetatable({keyOf=keyOf},{__index=_G}))
local matches=chunk()
local function find(id)for _,p in ipairs(profile.buildings.TilesetJohto)do if p.id==id then return p end end end
local gold=assert(find('johto_lighthouse'));local crystal=assert(find('johto_lighthouse_crystal'))
local fixtures={{{49,54,54,54,54,54,54,52},{65,72,72,72,72,72,72,68},{65,72,72,72,72,72,72,68},{81,82,82,82,82,82,82,84},{26,7,7,7,7,7,7,28},{26,38,38,38,38,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,38,38,28},{26,7,55,56,7,7,7,28},{1,2,57,58,2,2,2,22}},{{49,54,54,54,54,54,54,52},{65,72,72,72,72,72,72,68},{65,72,72,72,72,72,72,68},{81,82,82,82,82,82,82,84},{128,129,129,129,129,129,129,130},{131,132,147,133,134,147,135,136},{137,138,139,140,141,139,142,143},{144,145,145,145,145,145,145,146},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,38,38,7,7,38,38,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,7,7,28},{26,7,7,7,7,38,38,28},{26,7,55,56,7,7,7,28},{1,2,57,58,2,2,2,22}}}
for i,rows in ipairs(fixtures)do
 local map={id='OLIVINE_CITY',def={width=20,height=18}}
 local S={tileAt={}};for y,row in ipairs(rows)do for x,t in ipairs(row)do S.tileAt[keyOf(x+55,y+27)]=t end end
 local selected=i==1 and gold or crystal
 assert(matches(S,selected,56,28,map),'native edition rejected')
 assert(not matches(S,i==1 and crystal or gold,56,28,map),'wrong edition claimed lighthouse')
 if i==2 then
  for _,change in ipairs({'tile','map','width','height','x','y'})do
   local old=S.tileAt[keyOf(56,28)];local x,y=56,28
   if change=='tile'then S.tileAt[keyOf(56,28)]=old+1 elseif change=='map'then map.id='VIOLET_CITY'
   elseif change=='width'then map.def.width=21 elseif change=='height'then map.def.height=19
   elseif change=='x'then x=57 else y=29 end
   assert(not matches(S,crystal,x,y,map),'modified placement accepted: '..change)
   S.tileAt[keyOf(56,28)]=old;map.id='OLIVINE_CITY';map.def.width=20;map.def.height=18
  end
 end
end
assert(crystal.roofRows==gold.roofRows and crystal.depth==gold.depth and crystal.slab==gold.slab)
for i,row in ipairs(gold.tiles)do
 if i<5 or i>8 then for j,t in ipairs(row)do assert(crystal.tiles[i][j]==t)end end
end
print('PASS_JOHTO_LIGHTHOUSE_NATIVE_GOLD_CRYSTAL_AND_EDITED_EXCLUSIONS')
