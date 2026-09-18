local root=arg[1]or'.'
local engine=assert(os.getenv('GEN1RECOMP_DIR'))
local maps=dofile(engine..'/red/data/generated/maps.lua')
local profiles=assert(loadfile(root..'/lib/Gen1InteriorPanoramas.lua'))()
local state={level=1,FP_LEVEL=6}
function state.isFull(level)return (level or state.level)==1 end
local V,modules={},{}
function V.require(n)
 if n=='VoxelState'then return state end
 if n=='HorizonWall'then return {
  interiorProfileFor=profiles.profileFor,
  classFor=function()return 'interior'end,
  isOutdoorMap=function(m)return m.def.outdoor==true end,
 }end
 if not modules[n]then modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V)end
 return modules[n]
end
local R,C=V.require('CurrentRoom'),V.require('InteriorCutaway')
local allowed={POKEMON_MANSION_1F=true,POKEMON_MANSION_2F=true,
 POKEMON_MANSION_3F=true,POKEMON_MANSION_B1F=true,POWER_PLANT=true}
for id,p in pairs(profiles.profiles)do
 assert((p.cutawayPlan==true)==(allowed[id]==true),'unexpected complete dungeon plan '..id)
end
for id in pairs(allowed)do
 local d=maps[id];local map={id=id,def=d};local original=table.concat(d.blocks,',')
 for level=1,7 do
  state.level=level
  assert(C.active(map)==(level<=5),'wrong camera mode '..level)
  for _,origin in ipairs({{2,2},{13,10},{20,30},{40,20}})do
   local view=R.plan(map,{shapeAt={}},origin[1],origin[2],{})
   local count=0
   for y=0,d.height*4-1 do for x=0,d.width*4-1 do
    local visible=R.visible(view,x*8,y*8)
    if visible then count=count+1 end
    do
     local expected=d.blocks[math.floor(y/4)*d.width+math.floor(x/4)+1]~=d.borderBlock
     assert(visible==expected,'moving clips native footprint or reveals padding '..id)
    end
   end end
   assert(next(view.gates)==nil and count>1000,'dungeon still reduced to moving chamber '..id)
  end
 end
 assert(table.concat(d.blocks,',')==original,'map blocks changed '..id)
end
for _,edge in ipairs({'north','south','east','west'})do
 local horizontal=edge=='north'or edge=='south';local axis=horizontal and 3 or 1
 local sign=(edge=='north'or edge=='west')and 1 or -1
 local wall={kind='wall',interiorPanel={edge=edge,at=64},ox=200,oy=-100}
 local low={kind='cutaway_base',interiorPanel=wall.interiorPanel,ox=wall.ox,oy=wall.oy}
 local at=64+(horizontal and wall.oy or wall.ox)
 local eye,focus={0,100,0},{0,0,0};focus[axis]=at+sign*20
 eye[axis]=at+sign*40
 assert(C.rimVisible(wall,true,eye,focus)and not C.rimVisible(low,true,eye,focus),'duplicate full/low faces')
 eye[axis]=at-sign*40
 assert(not C.rimVisible(wall,true,eye,focus)and C.rimVisible(low,true,eye,focus),'wall footprint disappeared '..edge)
 assert(C.rimVisible(wall,false,eye,focus)and not C.rimVisible(low,false,eye,focus),'eye-level wall shortened '..edge)
end
-- A stationary camera-mode change must refresh the actual cached GPU mask.
local map={id='POWER_PLANT',def=maps.POWER_PLANT}
local shapes={shapeAt={}}
for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
 shapes.shapeAt[(y+64)*4096+x+64]={class='ground'}
end end
modules.Structures={forMap=function()return shapes end}
modules.ChunkMesher={elevation=function()return {atTile=function()return 0 end}end}
modules.Voxel3D={pushQuad=function()end,newMesh=function()return {release=function()end}end}
local uploads=0
local function image()return {release=function()end,setFilter=function()end,setWrap=function()end,
 replacePixels=function()uploads=uploads+1 end}end
love={graphics={getSystemLimits=function()return {texturesize=4096}end,newImage=image},
 image={newImageData=function(w,h)return {release=function()end,mapPixel=function(_,fn)
  for y=0,h-1 do for x=0,w-1 do fn(x,y)end end
 end}end}}
local ow={map=map,player={cellX=5,cellY=5}}
state.level=1;local full=assert(R.prepare(ow));assert(full.cutaway)
assert(R.prepare(ow)==full,'unchanged frame rebuilt mask')
state.level=6;local eye=assert(R.prepare(ow));assert(eye~=full and not eye.cutaway,'stale FULL mask in first person')
state.level=1;local restored=assert(R.prepare(ow));assert(restored~=eye and restored.cutaway,'stale eye-level mask in FULL')
assert(restored.image==full.image and uploads==2,'camera toggle reallocates mask texture')
R.release()
print('PASS five native dungeon plans stable across movement; exact map/camera guards; low walls preserve bearings/offsets; stationary camera toggles refresh cached mask')
