-- Gen2 adapter for VASC's packaged Terrarium geometry. The battle logic and
-- lifecycle remain owned by the Gen2 Card host.
local V=...
local M={zoom=1,yaw=0,pitch=0}
function M.style(map)
 local id=tostring(map and map.id or ''):upper()
 local env=tostring(map and (map.environment or(map.def and map.def.environment))or''):upper()
 local family
 if id:find('ICE_PATH',1,true)then family='ice'
 elseif id:find('FOREST',1,true)then family='forest'
 elseif env=='CAVE' or id:find('CAVE',1,true)or id:find('MT_MORTAR',1,true)or id:find('WHIRL_ISLAND',1,true)or id:find('VICTORY_ROAD',1,true)then family='cave'
 elseif id:find('TOWER',1,true)then family='tower'
 elseif env=='ROUTE' or id:match('^ROUTE_%d+$')then family='grass'
 elseif env=='TOWN' or id:match('_CITY$')or id:match('_TOWN$')then family='city'
 end
 return family and{id=family}or V.require('BattleArenaStyle').resolve(map)
end
local function read(name)
 return assert((loadstring or load)(assert(V.mod:read('integrated/terarrium/'..name)), '@terarrium/'..name))()
end
function M.service()
 if M.current then return M.current end
 local designs=read('BallDesigns.lua')
 local function opt(k)return V.mod.options:get('terarrium'..k)end
 local api={Voxel3D=V.require('Voxel3D'),Mat4=V.require('Mat4'),resolveStyle=M.style,
   clock=function()return love.timer.getTime()end,
   cameraMode=function()return opt('BehindRed') and 'behind' or 'side'end,
   idleEnabled=function()return opt('IdleAnimation')~=false end,
   ballStyle=function(map)return designs.resolve(opt('BallStyle'),'standard',map and map.id)end,
   ballAppearance=function(k)return designs.definitions[k]or designs.definitions.poke end}
 api.reportEffectFailure=function(effect,reason)V.require('Diagnostics').write('terrarium-'..effect..'-error',{reason=reason,requested='TERRARIUM',actual='TERRARIUM',source='optional-'..effect})end
 api.reportDomeFailure=function(reason)api.reportEffectFailure('dome',reason)end
 api.lighting=read('Lighting.lua')({lights=V.require('LocalLights'),graphics=api.Voxel3D,clock=api.clock,reportEffectFailure=api.reportEffectFailure,enabled=function()return opt('Lighting')end})
 api.gymDesign=read('GymDesigns.lua')(function(path)return V.mod:read('integrated/terarrium/'..path)end,2)
 api.branding=function()return read('Branding.lua')({path=V.mod.path..'/integrated/terarrium'})end
 local atmosphere=read('GymAtmosphere.lua')(api)
 api.drawAtmosphere=atmosphere.draw;api.releaseAtmosphere=atmosphere.release
 local sound=read('IdleSound.lua')()
 api.idleImpact=function()if opt('IdleSound')~=false then sound.play()end end
 api.stopIdleSound=sound.stop;api.releaseIdleSound=sound.release
 local background=read('Background.lua')(api)
 api.drawBackground=function(arena)background.draw(arena,opt('Background')or'auto')end
 api.releaseBackground=background.release
 local dome=read('Dome.lua')(api)
 api.drawDome=function(arena,y)local style=opt('Dome');if style and style~='off'then dome.draw(arena,y,style)end end
 api.releaseDome=dome.release
 M.current=read('Terarrium.lua')(api)
 return M.current
end
function M.arena(map)
 local arena=V.require('StadiumStage').arena(map)
 if not arena then return end
 local service=M.service()
 arena.terarrium=service.setup(map)
 arena.terarriumService=service
 arena.portableStage='terarrium'
 for _,side in ipairs({'player','enemy'})do
  local p=arena.terarrium.actors[side]
  arena[side]={arena.mid[1]+p[1],arena.mid[2]+p[3]}
  arena[side..'Cell']={(arena[side][1]-8)/16,(arena[side][2]-8)/16}
 end
 return arena
end
-- Transform the authored camera and up vector together about the focus.
function M.reset() M.zoom,M.yaw,M.pitch=1,0,0 end
function M.scaleZoom(factor)
 if type(factor)~='number' or factor~=factor or factor<=0 or factor==math.huge then return false end
 M.zoom=math.max(.45,math.min(3,M.zoom*factor));return true
end
function M.stepZoom(n)return M.scaleZoom(1.12^n)end
function M.manualLook(yaw,pitch)
 M.yaw=(M.yaw+(yaw or 0))%(2*math.pi)
 M.pitch=math.max(-.65,math.min(.65,M.pitch+(pitch or 0)))
 return true
end
function M.camera(arena,groundY)
 local cam=arena.terarriumService.camera(arena,groundY)
 local function rotate(x,y,z)
  local cp,sp=math.cos(M.pitch),math.sin(M.pitch)
  y,z=y*cp-z*sp,y*sp+z*cp
  local c,s=math.cos(M.yaw),math.sin(M.yaw)
  return {x*c+z*s,y,z*c-x*s}
 end
 local f=cam.focus
 local d=rotate(cam.eye[1]-f[1],cam.eye[2]-f[2],cam.eye[3]-f[3])
 cam.eye={f[1]+d[1],f[2]+d[2],f[3]+d[3]}
 cam.up=rotate(unpack(cam.up or{0,1,0}))
 cam.fov=2*math.atan(math.tan(cam.fov/2)*M.zoom)
 M.lastCamera=cam
 return cam,math.atan2(math.sqrt(d[1]^2+d[3]^2),d[2])
end
function M.release()
 if M.current then M.current.release();M.current=nil end
 M.reset();M.lastCamera=nil
end
return M
