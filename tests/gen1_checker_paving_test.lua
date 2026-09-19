local root=arg[1]or'.'
local settings={new=function(_,_,values)
 local s={value=values[1]};function s:get()return self.value end;return s
end}
local O=assert(loadfile(arg[2]or(root..'/lib/Gen1OutdoorScenery.lua')))({require=function()return settings end})
local tiles={}
local map={id='FUCHSIA_CITY',def={tileset='OVERWORLD',generation=1,width=2,height=1,blocks={122,123}},
 tileAt=function(_,x,y)return tiles[y*8+x+1]end}
for y=0,3 do for x=0,7 do
 tiles[y*8+x+1]=x<4 and ((x+y)%2==0 and 44 or 48)or((x+y)%2==0 and 48 or 57)
end end
local function at(x,y)return O.material(map,O.profile(map),map:tileAt(x,y),x,y)end
for _,id in ipairs({'FUCHSIA_CITY','ROUTE_12','ROUTE_10'})do
 map.id=id
 for y=0,3 do for x=0,7 do assert(at(x,y)==-163,'paving is still alternating: '..id..' '..x..','..y)end end
end
-- Preserve regional treatments and never reinterpret a reused/edited block.
map.id='ROUTE_20';for y=0,3 do for x=0,3 do assert(at(x,y)==-160)end end
map.id='FUCHSIA_CITY';tiles[2]=20
assert(at(0,0)==-159 and at(1,0)==nil,'mixed shore block was paved')
tiles[2]=48;map.def.blocks[1]=10;assert(at(0,0)==-159,'ordinary lawn was paved')
map.id='ROUTE_12';tiles[1]=60
assert(at(0,0)==-130 and O.bankMaterial(map,true,'ground',60,'water')==-130,'pier deck/bank must keep wood')
map.id='ROUTE_20';assert(at(0,0)==-162 and O.bankMaterial(map,true,'ground',60,'water')==-167,'Seafoam stone landing changed')
map.id='FUCHSIA_CITY';tiles[1]=44
map.def.blocks[1]=122;tiles[2]=82;assert(at(1,0)==-159,'encounter grass was paved')
O.ground.value=false;assert(at(0,0)==nil)
O.ground.value=true;map.def.generation=2;assert(at(0,0)==nil,'Gen2 tiles reinterpreted as Gen1')
print('PASS both canonical checker motifs; regional beach, edited blocks, lawns, encounter grass, disabled option and Gen2 preserved')
