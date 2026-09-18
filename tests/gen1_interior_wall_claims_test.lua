local root=arg[1] or '.'
local enabled,profile=true,{nativeRoomPanels=true}
local panels={}
local V={require=function(n)
 if n=="Gen1SecurityDoors"or n=="Gen1BreachExterior"then return assert(loadfile(root.."/lib/"..n..".lua"))()end
 if n=="Gen1InteriorLayout" then return {panelsFor=function()return panels end}end
 if n=="VoxelFurniture" then return {floorTile=function()return 1 end}end
 return {enabled=function()return enabled end,interiorProfileFor=function()return profile end}
end}
local M=assert(loadfile(root..'/lib/Gen1InteriorWallClaims.lua'))(V)
local key=function(x,y)return(y+64)*4096+x+64 end
local function fixture()
 local s={shapeAt={},skip={},ground={},voxelFurnitureClaims={}}
 for _,p in ipairs({{3,0,'wall'},{3,5,'wall'},{4,0,'stair_e'},{5,0,'bookcase'},{6,0,'wall'}})do
  s.shapeAt[key(p[1],p[2])]={class=p[3],h=16}
 end
 s.voxelFurnitureClaims[key(6,0)]=true
 return s
end
local map={def={width=4,height=4,tileset='REDS_HOUSE_2'}}
local s=fixture();M.claim(s,map)
assert(s.skip[key(3,0)] and s.shapeAt[key(3,0)].h==0)
for _,p in ipairs({{3,5},{4,0},{5,0},{6,0}})do assert(not s.skip[key(p[1],p[2])],'removed interior/furniture/stairs')end
enabled=false;s=fixture();M.claim(s,map);assert(not next(s.skip),'OFF lost vanilla walls')
enabled=true;profile=nil;s=fixture();M.claim(s,map);assert(not next(s.skip),'unreviewed map affected')
profile={nativeRoomPanels=true}
panels={{edge='south',at=40,from=16,upto=40,openings={}},
 {edge='north',at=56,from=16,upto=40,openings={}}}
s=fixture();M.claim(s,map)
assert(s.skip[key(3,5)],'old internal wall still covers the replacement panel')
assert(not s.skip[key(5,0)] and not s.skip[key(4,0)],'furniture or stair removed')
map.def.tileset='FACILITY';s=fixture();s.tileAt={}
for x,id in ipairs({42,36,74,25,64,86})do
 local k=key(x,5);s.shapeAt[k]={class='wall',h=16};s.tileAt[k]=id
end
panels={{edge='south',at=40,from=0,upto=128,openings={}}};M.claim(s,map)
assert(s.skip[key(1,5)],'structural wall not replaced')
for x=2,6 do assert(not s.skip[key(x,5)],'locked gate, console, rail or lift door removed')end
-- A panorama beside the president's desk must not consume the desk, console,
-- counter or stairs when the independent furniture switch is disabled.
map.id='SILPH_CO_11F';map.def.tileset='INTERIOR';s=fixture();s.tileAt={}
for x,id in ipairs({87,52,68,11,27,31,93,94})do
 local k=key(x,5);s.shapeAt[k]={class='wall',h=16};s.tileAt[k]=id
end
M.claim(s,map)
assert(s.skip[key(1,5)],'Silph partition was not replaced')
for x=2,8 do assert(not s.skip[key(x,5)],'Silph equipment or native gate consumed by generic wall claim')end
print('PASS panel-backed wall claims, uncovered walls, furniture/stairs/gates/equipment preserved, OFF and nonprofile fallback')

-- Lance's indented frame sits farther inside a block than the panorama
-- panel strip. Its black corner pixels belong to that obsolete frame.
local lance={id='LANCES_ROOM',def={tileset='DOJO',width=13,height=13,borderBlock=3,blocks={},warps={}}}
for i=1,169 do lance.def.blocks[i]=3 end
lance.def.blocks[6*13+4+1]=78
lance.def.blocks[6*13+5+1]=111
lance.def.blocks[6*13+2+1]=0x72
local function frame()
 return {shapeAt={[key(17,26)]={class='wall',h=16},[key(22,26)]={class='void',h=0},
  [key(24,26)]={class='void',h=0},[key(8,26)]={class='wall',h=16}},
  tileAt={[key(17,26)]=38,[key(22,26)]=15,[key(24,26)]=15,[key(8,26)]=38},
  skip={},ground={},voxelFurnitureClaims={}}
end
panels={};s=frame();M.claim(s,lance)
assert(s.skip[key(17,26)],'Lance obsolete interior wall remains')
assert(s.skip[key(22,26)],'Lance frame corner remains black')
assert(not s.skip[key(24,26)],'external void became floor')
assert(not s.skip[key(8,26)],'scripted entrance gate was removed')
for _,field in ipairs({'width','height'})do
 local old=lance.def[field];lance.def[field]=12;s=frame();M.claim(s,lance)
 assert(not s.skip[key(17,26)]and not s.skip[key(22,26)],'modified room was admitted')
 lance.def[field]=old
end
enabled=false;s=frame();M.claim(s,lance);assert(not next(s.skip),'OFF lost original Lance frame');enabled=true
lance.def.warps={{x=11,y=13}};s=frame();M.claim(s,lance);assert(not s.skip[key(22,26)],'warp cell covered')
print('PASS Lance static frame, black corners, external void/gate/warp/modified-map/OFF guards')

lance.def.warps={};s=frame()
s.tileAt[key(17,26)]=2 -- statue crown, even if a classifier calls it wall
M.claim(s,lance);assert(not s.skip[key(17,26)],'statue crown treated as obsolete room frame')
print('PASS statue art excluded from Lance frame ownership')
