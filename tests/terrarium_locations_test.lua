local root=os.getenv('VASC_TEST_ROOT')or'.'
local function loadModule(name)return assert(loadfile(root..'/integrated/terarrium/'..name))()end
local function read(name)local f=assert(io.open(root..'/integrated/terarrium/'..name,'rb'));local s=f:read('*a');f:close();return s end
local occupied=true
local lookup=loadModule('GymDesigns.lua')(read,1,function()return occupied end)
local gen2Lookup=loadModule('GymDesigns.lua')(read,2)
for _,id in ipairs({'LORELEIS_ROOM','BRUNOS_ROOM','AGATHAS_ROOM','LANCES_ROOM','CHAMPIONS_ROOM'})do assert(lookup(id)and not gen2Lookup(id),'Gen1 League must not replace Johto League')end
assert(not lookup('PEWTER_CITY')and not lookup('VIOLET_GYM'))
local live,built=0,0
local function resource()live=live+1;return{release=function(self)assert(not self.freed);self.freed=true;live=live-1 end,setFilter=function()end,setWrap=function()end}end
love={image={newImageData=function(w,h)local p=resource();p.minimum=1;p.setPixel=function(_,x,y,r,g,b,a)p.minimum=math.min(p.minimum,r);assert(x>=0 and y>=0 and x<w and y<h);for _,n in ipairs({x,y,r,g,b,a})do assert(n==n and math.abs(n)<1e8)end end;return p end},graphics={newImage=function(data)local p=resource();p.minimum=data.minimum;return p end}}
local G={}
function G.newMesh(v,idx)
 assert(#v>0 and #idx%3==0)
 for _,p in ipairs(v)do for _,n in ipairs(p)do assert(n==n and math.abs(n)<1e8,'nonfinite geometry')end end
 for _,i in ipairs(idx)do assert(i>=1 and i<=#v)end
 built=built+1;return resource()
end
for _,key in ipairs({'draw','seams','glass','shadowReception'})do G[key]=function()end end
local M={translate=function()return{}end}
local service=loadModule('Terarrium.lua')({Voxel3D=G,Mat4=M,resolveStyle=function()return{id='grass'}end,gymDesign=lookup})
local ids={'PEWTER_GYM','CERULEAN_GYM','VERMILION_GYM','CELADON_GYM','FUCHSIA_GYM','SAFFRON_GYM','CINNABAR_GYM','VIRIDIAN_GYM','LORELEIS_ROOM','BRUNOS_ROOM','AGATHAS_ROOM','LANCES_ROOM','CHAMPIONS_ROOM','ROCKET_HIDEOUT_B4F','VIOLET_GYM','ROUTE_1'}
for floor=2,7 do local id='POKEMON_TOWER_'..floor..'F';ids[#ids+1]=id;local count=0;lookup(id).button({quad=function()count=count+1 end});assert(count==0 and not gen2Lookup(id),'Tower ghost removed and Gen1 only')end
assert(not lookup('POKEMON_TOWER_1F'))
assert(lookup('ROCKET_HIDEOUT_B2F')and not gen2Lookup('ROCKET_HIDEOUT_B4F'))
local locations={
 SS_ANNE_BOW='ship',FIGHTING_DOJO='gym',POWER_PLANT='industrial',VIRIDIAN_FOREST='forest',
 DIGLETTS_CAVE='cave',OAKS_LAB='interior',ROUTE_17='coast'}
for floor=1,3 do
 locations['ROCKET_HIDEOUT_B'..floor..'F']='industrial'
 locations['VICTORY_ROAD_'..floor..'F']='cave'
 locations['POKEMON_MANSION_'..floor..'F']='interior'
end
locations.POKEMON_MANSION_B1F='interior'
for floor=1,11 do locations['SILPH_CO_'..floor..'F']='industrial'end
for _,area in ipairs({'CENTER','EAST','NORTH','WEST'})do locations['SAFARI_ZONE_'..area]='safari'end
for _,floor in ipairs({'1F','B1F','B2F'})do locations['MT_MOON_'..floor]='cave'end
for _,floor in ipairs({'1F','2F','B1F'})do locations['CERULEAN_CAVE_'..floor]='cave'end
for _,floor in ipairs({'1F','B1F','B2F','B3F','B4F'})do locations['SEAFOAM_ISLANDS_'..floor]='ice'end
local count=0
for id,family in pairs(locations)do
 count=count+1;assert(lookup(id)and lookup(id).family==family,id)
 assert(not gen2Lookup(id),'Gen1 location leaked into Gen2: '..id);ids[#ids+1]=id
end
assert(count==43,'location coverage changed: '..count)
for _,id in ipairs({'SS_ANNE_1F','SS_ANNE_KITCHEN','SS_ANNE_DECK','ROUTE_16','ROUTE_18',
 'SAFARI_ZONE_GATE','SAFARI_ZONE_SECRET_HOUSE','MT_MOON_SQUARE','DIGLETTS_CAVE_ROUTE_2',
 'POWER_PLANT_EXTERIOR','SILPH_CO_0F','SILPH_CO_12F','SILPH_CO_ELEVATOR','OAKS_LAB_EXTRA',
 'ROCKET_HIDEOUT_ELEVATOR','VICTORY_ROAD','POKEMON_MANSION_B2F','SEAFOAM_ISLANDS_B5F'})do
 assert(not lookup(id),'overbroad selection: '..id)
end
local silph=assert(lookup('SILPH_CO_11F'))
occupied=false;assert(not lookup('SILPH_CO_11F'),'cached occupation survived liberation')
assert(not service.setup({id='SILPH_CO_11F'}).gymDesign)
occupied=nil;assert(not lookup('SILPH_CO_11F'))
assert(not loadModule('GymDesigns.lua')(read,1)('SILPH_CO_11F'),'unknown story must use fallback')
occupied=true;assert(lookup('SILPH_CO_11F')==silph)
-- Host predicate reads the current save without writing flags or retaining a save table.
local game={save={flags={}}};local hostApi
local V={mod={world={game=game}},require=function()return {}end}
local host=assert(loadfile(root..'/lib/TerarriumHost.lua'))(V)
assert(host.builtin().register(function(api)
 hostApi=api;local service={};for _,key in ipairs({'setup','draw','cast','camera','trainerFoot','release'})do service[key]=function()end end;return service
end))
assert(hostApi.silphOccupied());assert(next(game.save.flags)==nil)
game.save.flags.EVENT_BEAT_SILPH_CO_GIOVANNI=true;assert(not hostApi.silphOccupied())
game.save={flags={}};assert(hostApi.silphOccupied())
game.save=nil;assert(not hostApi.silphOccupied())
print('PASS 43 exact location IDs, Gen2 exclusions, live Silph story state and missing-state fallback')

for _,id in ipairs(ids)do for _,mode in ipairs({'side','behind'})do
 local s=service.setup({id=id},mode)
 if lookup(id)then assert(s.family==(lookup(id).family or 'gym')and s.gymDesign==lookup(id))end
 local a={terarrium=s,mid={0,0}}
 service.draw(a,0);local n=built;service.draw(a,0);assert(built==n,'standing still rebuilt meshes')
 assert(live<=12,'cache exceeded four three-resource entries')
end end
service.release();assert(live==0,'resource leak')
-- Original standalone integration without design providers still works.
local legacy=loadModule('Terarrium.lua')({Voxel3D=G,Mat4=M,resolveStyle=function()return{id='gym'}end})
legacy.draw({terarrium=legacy.setup({id='PEWTER_GYM'}),mid={0,0}},0);legacy.release();assert(live==0)
print('PASS Terrarium: 30 authored designs, both layouts, bounded cache, finite meshes and legacy fallback')

-- Rocking is shared by authored arenas: nine seconds idle, both directions,
-- camera tilt with a level HUD, and immediate reset on input/menu/action/off.
local time,enabled=0,true
local rocking=loadModule('Terarrium.lua')({clock=function()return time end,idleEnabled=function()return enabled end})
local battle={phase='menu',menuIndex=1,game={input={down={}}}}
local arena={mid={0,0}}
rocking.activity(battle);local rest=rocking.camera(arena,0)
time=8.99;assert(rocking.idleSample()==0)
time=9.28;assert(rocking.idleSample()>.07);local left=rocking.camera(arena,0);assert(math.abs(left.up[1])>.01)
time=9.84;assert(rocking.idleSample()<-.07)
battle.game.input.down.a=true;rocking.activity(battle);assert(rocking.idleSample()==0)
battle.game.input.down={};rocking.activity(battle);time=time+9.28;assert(rocking.idleSample()>.07)
battle.phase='moves';rocking.activity(battle);assert(rocking.idleSample()==0)
battle.phase='menu';rocking.activity(battle);time=time+9.28;assert(rocking.idleSample()>.07)
enabled=false;rocking.activity(battle);assert(rocking.idleSample()==0)
print('PASS Terrarium rocking: delay, directions, camera, input, moves, off')

local flag=true;local frame
local L={mobile=true,available=function()return true end,clear=function()frame=nil end,stage=function(sky,tint,lamps)frame={lights=lamps};return frame end}
local light=loadModule('Lighting.lua')({lights=L,graphics=G,clock=function()return time end,enabled=function()return flag end})
local probe=light.bake({{0,0,0,12,18,12}});assert(probe.minimum<.9 and probe.minimum>=.7,'contact shadow missing or too dark');probe:release()
local flat=light.bake({{0,0,0,150,.03,150}});assert(flat.minimum==1,'flat floor must not occlude itself');flat:release()
local lit=loadModule('Terarrium.lua')({Voxel3D=G,Mat4=M,resolveStyle=function()return{id='gym'}end,gymDesign=lookup,lighting=light})
for _,id in ipairs(ids)do
 local a={terarrium=lit.setup({id=id}),mid={100,200}}
 assert(lit.prepareLighting(a,7));local bakes=light.bakes
 assert(frame.stageAO and frame.terrarium and frame.unoccluded and #frame.lights==2)
 assert(frame.stageOrigin[1]==100 and frame.stageOrigin[2]==7 and frame.stageOrigin[3]==200)
 for i=1,100 do assert(lit.prepareLighting(a,7))end;assert(light.bakes==bakes,'lightmap rebaked while idle')
 assert(live<=16,'lightmap cache exceeded four entries')
 flag=false;assert(not lit.prepareLighting(a,7));flag=true
end
L.mobile=false;assert(lit.prepareLighting({terarrium=lit.setup({id='CHAMPIONS_ROOM'}),mid={0,0}},0));assert(#frame.lights==3)
lit.release();assert(live==0,'lightmap leak')
print('PASS Terrarium lighting: 2 mobile / 3 desktop lights, one bake per entry, cache eviction, OFF, release')
