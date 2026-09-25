local function module(name)return assert(loadfile('integrated/terarrium/'..name..'.lua'))()end
local reports,compiles,draws,pushes,live=0,0,0,0,0
local fault='compile'
local function resource()
 live=live+1
 return {setFilter=function()end,setWrap=function()end,send=function()end,
  release=function(self)assert(not self.freed);self.freed=true;live=live-1 end}
end
local g={newShader=function()compiles=compiles+1;if fault=='compile'then error('compiler rejected shader')end;return resource()end,
 push=function()pushes=pushes+1 end,pop=function()pushes=pushes-1 end,getCanvas=function()end,getDimensions=function()return 640,480 end,
 rectangle=function()draws=draws+1;if fault=='draw'then error('draw rejected')end end}
for _,k in ipairs({'origin','setShader','setDepthMode','setColor','setBlendMode'})do g[k]=function()end end
love={graphics=g,image={}}
local api={ballAppearance=function()return {base={1,1,1},accent={1,1,1}}end,
 reportEffectFailure=function()reports=reports+1 end}
local background=module('Background')(api);local arena={terarrium={ballStyle='poke'},mid={0,0}}
for i=1,120 do assert(background.draw(arena,'auto')==false)end
assert(compiles==1 and reports==1 and pushes==0)
background.release();fault=nil;assert(background.draw(arena,'auto'))
fault='draw';assert(not background.draw(arena,'night'));local n=draws
for i=1,120 do assert(not background.draw(arena,'night'))end
assert(draws==n and reports==2 and pushes==0)
background.release();assert(live==0)
print('PASS optional background: bounded compile/draw failures, graphics state, cleanup and retry')

local bakeAttempts,stages,geometry=0,0,0
function love.image.newImageData(w,h)
 if w==64 then bakeAttempts=bakeAttempts+1;if fault=='pixels'then error('pixel allocation rejected')end end
 local r=resource();r.w=w;r.setPixel=function()end;return r
end
function g.newImage(data)
 if data.w==64 and fault=='texture'then error('texture upload rejected')end
 return resource()
end
local G={newMesh=function()return resource()end,draw=function()geometry=geometry+1 end}
for _,k in ipairs({'seams','glass','shadowReception'})do G[k]=function()end end
local current
local lights={available=function()return true end,clear=function()current=nil end,
 stage=function()stages=stages+1;current={};if fault=='stage'then error('light preparation rejected')end;return current end}
local lighting=module('Lighting')({lights=lights,graphics=G,clock=function()return 0 end,enabled=function()return true end,reportEffectFailure=api.reportEffectFailure})
local function read(path)local f=assert(io.open('integrated/terarrium/'..path));local s=f:read('*a');f:close();return s end
local service=module('Terarrium')({Voxel3D=G,Mat4={translate=function()return {}end},
 resolveStyle=function()return {id='gym'}end,gymDesign=module('GymDesigns')(read,1),lighting=lighting})
arena.terarrium=service.setup({id='FIGHTING_DOJO'})
for _,failure in ipairs({'pixels','texture','stage'})do
 fault=failure;local before=reports
 assert(service.prepareLighting(arena,0)==false)
 assert(not current and not service.lightEnabled() and reports==before+1)
 local b,s=bakeAttempts,stages
 for i=1,120 do assert(service.prepareLighting(arena,0)==false);service.draw(arena,0)end
 assert(bakeAttempts==b and stages==s and reports==before+1,'failed optional lighting repeats work')
 assert(geometry>0,'lighting failure hid geometry')
 service.release();assert(live==0,'failed lighting retained resources')
 fault=nil;assert(service.prepareLighting(arena,0));assert(service.lightEnabled())
 service.release();assert(live==0)
end
print('PASS optional lighting: allocation/upload/stage failure, geometry retained, bounded retries, cleanup and recovery')
