local root=assert(arg[1]);local G=love.graphics
local M=assert(loadfile(root..'/lib/Mat4.lua'))({})
local now=0
local api={Mat4=M,clock=function()return now end,Voxel3D={eye={0,157,205},vp={.012,0,0,0,0,-.012,-.007,0,0,0,0,0,0,0,0,1}}}
local fog=assert(loadfile(root..'/integrated/terarrium/GymAtmosphere.lua'))()(api)
local canvas=G.newCanvas(160,160)
local arena={mid={0,0},terarrium={actors={player={-25,0,0},enemy={25,0,0}},gymDesign={}}}
local function render(id,time)
 now=time;arena.terarrium.id=id
 G.push('all');G.setCanvas({canvas,depth=true});G.clear(0,0,0,0);G.origin()
 fog.draw(arena,0);G.pop();assert(not fog.failure,fog.failure)
 local p=canvas:newImageData();local count,total=0,0
 for y=0,159 do for x=0,159 do local r,g,b,a=p:getPixel(x,y);if a>.01 then count=count+1;total=total+a end end end
 p:release();return count,total
end
for _,id in ipairs({'POKEMON_TOWER_7F','FUCHSIA_GYM','CINNABAR_GYM'})do
 for _,t in ipairs({0,2,7,99})do local n,a=render(id,t);assert(n>100 and a>20,id..': invisible atmosphere');print('GPU_ATMOSPHERE',id,t,n,a)end
end
local n=render('ROCKET_HIDEOUT_B4F',0);assert(n==0,'mist leaked into another room')
fog.release();canvas:release()
print('PASS_TERRARIUM_ATMOSPHERE_GPU')
