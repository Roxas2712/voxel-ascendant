-- Explicit native QA experiment. Never imported by the Gen2 release host.
-- Reuses Gen1 irradiance and visibility, adapting emitters from native Johto
-- window UVs. Production Gen2 ownership/generation gates are not changed.
return function(game)
 io.stdout:setvbuf('no')
 assert(os.getenv('POKEPORT_IDENTITY')=='vasc-gen2-light-preview-20260919','isolated preview identity required')
 local root=assert(os.getenv('PREVIEW_ROOT'));local output=assert(os.getenv('VIEW_OUTPUT'))
 local function wait(n)for _=1,n do coroutine.yield()end end
 local ex=assert(game.mods.exports.VOXEL_ASCENDANT);local bridge
 for i=1,50 do local name,value=debug.getupvalue(ex.voxelStatus,i);if name=='GoldVoxelBridge'then bridge=value;break end end
 assert(bridge and ex.active and ex.rendererInstalled)
 if ex.ascendantContent then ex.ascendantContent.promptDisabled=true end
 local V=bridge.lib;local G=V.require('Voxel3D');local B=V.require('Buildings');local Scene=V.require('VoxelScene');local D=V.require('DayNight')
 local chosen={voxelDiskCache=false,voxel3d=true,daytime='night',weather='clear',enabled=false,town_pokemon=false,openWorld=true,cameraMode='third',voxelCharacters=false}
 local opts=V.mod.options;local get=opts.get
 opts.get=function(self,k,...)if chosen[k]~=nil then return chosen[k]end;return get(self,k,...)end
 local modules={};local P={mod=V.mod}
 P.require=function(name)
  if name=='LocalLights' or name=='LightVisibility'then
   if not modules[name]then modules[name]=assert(loadfile(root..'/lib/'..name..'.lua'))(P)end
   return modules[name]
  end
  return V.require(name)
 end
 local L=P.require('LocalLights');L.supported=true;L.ownerActive=true;L.setting:setValue(true,game)
 local emitters={};local stamp=B.stamp
 B.stamp=function(S,map,quads,tx,ty,bw,bh,t)
  local panes=V.require('GlassMask').rects(map.tileset)
  local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 128
  local list=emitters[map.id]or {};emitters[map.id]=list
  local lo={1e9,1e9,1e9};local hi={-1e9,-1e9,-1e9}
  for _,q in ipairs(quads)do for _,p in ipairs(q)do for a=1,3 do lo[a]=math.min(lo[a],p[a]);hi[a]=math.max(hi[a],p[a])end end end
  for _,q in ipairs(quads)do
   local u0,v0,u1,v1=1e9,1e9,-1e9,-1e9
   for _,uv in ipairs(q.uv)do u0=math.min(u0,uv[1]*aw);u1=math.max(u1,uv[1]*aw);v0=math.min(v0,uv[2]*ah);v1=math.max(v1,uv[2]*ah)end
   local glass=false
   for _,p in ipairs(panes)do if u1>p.x and u0<p.x+p.w and v1>p.y and v0<p.y+p.h then glass=true;break end end
   -- Emit through actual vertical facade panes, never roof or recess tops.
   local x,y,z=0,0,0;for _,p in ipairs(q)do x=x+p[1]/4;y=y+p[2]/4;z=z+p[3]/4 end
   local n
   if math.abs(q[1][3]-q[2][3])<.01 and math.abs(q[1][3]-q[3][3])<.01 then n={0,0,z>(lo[3]+hi[3])/2 and 1 or -1}
   elseif math.abs(q[1][1]-q[2][1])<.01 and math.abs(q[1][1]-q[3][1])<.01 then n={x>(lo[1]+hi[1])/2 and 1 or -1,0,0}end
   if glass and n then
    x=x+tx*8+n[1]*2;z=z+ty*8+n[3]*2
    local near=false;for _,p in ipairs(list)do if (p.x-x)^2+(p.y-y)^2+(p.z-z)^2<64 then near=true;break end end
    if not near then list[#list+1]={x=x,y=y,z=z,normal=n,radius=64,power=1.25,color={1,.67,.30},owner={}}end
   end
  end
  return stamp(S,map,quads,tx,ty,bw,bh,t)
 end
 local lit=false;local profile='desktop';local programs={};local nativeShader=G.shader
 G.shader=function(grid)
  if not lit then return nativeShader(grid)end
  local key=profile..tostring(grid)
  if not programs[key]then
   local source=G._shaderSource('full',grid)
   source=source:gsub('#ifdef PIXEL',function()return '#ifdef PIXEL\nuniform vec3 eye;\n'..L.glsl()end,1)
   local normal=L.mobile and 'vec3 localNormal=vec3(0,1,0);' or 'vec3 localNormal=cross(dFdx(vWorld),dFdy(vWorld));localNormal/=max(length(localNormal),.0001);localNormal*=dot(localNormal,eye-vWorld)<0.0?-1.0:1.0;'
   local count
   source,count=source:gsub('vec3 rgb = p.rgb %* vShade',normal..'\nvec3 rgb = p.rgb * localSurfaceShade(vShade,localNormal,vWorld)',1);assert(count==1,'native shader diffuse seam missing')
   source,count=source:gsub('rgb = mix%(rgb, ghostColor, ghost%);','rgb += p.rgb * localIrradiance(vWorld,localNormal);\nrgb = mix(rgb, ghostColor, ghost);',1);assert(count==1)
   programs[key]=love.graphics.newShader(source)
  end
  return programs[key]
 end
 local begin=G.beginScene
 G.beginScene=function(...)
  local result=begin(...)
  if lit then local sh=love.graphics.getShader();if sh then sh:send('eye',G.eye);L.send(sh,true)end end
  return result
 end
 local state;local render=Scene.render
 Scene.render=function(s,...)
  state=s;V.require('FirstPerson').yaw=math.pi;V.require('FirstPerson').pitch=.13
  V.require('Sky').clock=12
  local pool={};local night=D.windowLight()
  if night>0 then for _,e in ipairs(emitters[s.map.id]or {})do
   local c={};for k,v in pairs(e)do c[k]=v end;c.power=e.power*night;pool[#pool+1]=c
  end end
  local p=s.player;local focus={p and p.px or 160,16,p and p.py or 160}
  L.stage(L.sky(s.map,true,'clear',true),D.tint(true),L.select(pool,focus,L.MAX_LIGHTS))
  return render(s,...)
 end
 love.window.setMode(1100,700,{vsync=1})
 local save=require('src.core.gen2.Save').newGame({playerName='LIGHTQA'})
 game.save=save;game:adoptSave(save);game.world.save=save;require('src.mods.Runtime').emit('save.created',{game=game,save=save});game:continueGame(save);wait(120)
 game.world.checkTrainerBattle=function()return false end;game.world.trySceneScript=function()return false end;game.world.tryCoordScript=function()return false end;game.world.tryWildEncounter=function()return false end
 local function shot(name)
  love.graphics.captureScreenshot(function(data)local f=assert(io.open(output..'/'..name..'.png','wb'));f:write(data:encode('png'):getString());f:close();data:release()end);wait(3)
 end
 for _,id in ipairs({'GOLDENROD_CITY','NEW_BARK_TOWN','ECRUTEAK_CITY'})do
  assert(game.world:setMap(id,10,8,'up'));wait(180)
  assert(#(emitters[id]or {})>0,'no native window emitters '..id)
  for _,hour in ipairs({'day','night'})do
   D.setting:setValue(hour,game);wait(60)
   lit=false;wait(10);shot(id..'-'..hour..'-off')
   lit=true;wait(10);assert(not L.failure,L.failure);shot(id..'-'..hour..'-on')
   print('LIGHT_PREVIEW',id,hour,#(emitters[id]or {}),#L.current().lights)
  end
 end
 profile='mobile';L.mobile=true;L.MAX_LIGHTS=4;L.MAX_BLOCKERS=4;L.MAX_PORTALS=2;P.require('LightVisibility').invalidate()
 wait(20);assert(#L.current().lights<=4 and not L.failure);shot('ECRUTEAK_CITY-night-mobile-budget')
 print('PASS_GEN2_DYNAMIC_LIGHT_PREVIEW',bridge.frames3d,#L.current().lights)
 love.event.quit()
end
