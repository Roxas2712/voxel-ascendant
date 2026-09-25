return function(mod)
 local base=mod:find('VOXEL_ASCENDANT')
 local host=base and base.exports and base.exports.terarrium
 assert(host and host.schema=='vasc.terarrium-host/v1' and (host.revision or 0)>=3,
  'Terarrium 0.2.2 benötigt den beiliegenden VASC-Adapter Revision 3 (Basis 3.0.23).')
 local source=assert(mod:read('Terarrium.lua'))
 local factory=assert((loadstring or load)(source,'@Terarrium.lua'))()
 local designs=assert((loadstring or load)(assert(mod:read('BallDesigns.lua')),'@TerarriumBallDesigns.lua'))()
 mod.options:define({{key='lighting',label='LIGHTING',type='toggle',default=true},{key='behindRed',label='KAMERA HINTER ROT',type='toggle',default=false},
  {key='idleAnimation',label='RUHEANIMATION',type='toggle',default=true},
  {key='idleSound',label='WACKELKLANG',type='toggle',default=true},
  {key='ballStyle',label='BALL-DESIGN',type='choice',default='auto',choices=designs.choices()},
  {key='background',label='RAHMEN / HINTERGRUND',type='choice',default='auto',choices={{'AUTO: BALL','auto'},{'NACHT','night'},{'WALD','forest'},{'STEIN','stone'},{'HELLE GALERIE','gallery'}}},
  {key='dome',label='GLASKUPPEL',type='choice',default='off',choices={{'AUS','off'},{'KLAR','clear'},{'BLAU','blue'},{'ROSA','rose'},{'GOLD','gold'}}}})
 local service
 local ok,reason=host.register(function(api)
  local sound=assert((loadstring or load)(assert(mod:read('IdleSound.lua')),'@TerarriumIdleSound.lua'))()()
  api.idleImpact=function()if mod.options:get('idleSound')~=false then sound.play()end end
  api.releaseIdleSound=sound.release
  api.stopIdleSound=sound.stop
  api.ballStyle=function(map)
   local difficulty='standard'
   local kasc=mod:find('kanto_ascendant')
   local options=mod.game and mod.game.mods and mod.game.mods.modOptions
   if kasc and options and options.kanto_ascendant then difficulty=options.kanto_ascendant.difficulty or difficulty end
   return designs.resolve(mod.options:get('ballStyle'),difficulty,map and map.id)
  end
  api.ballAppearance=function(key)return designs.definitions[key]or designs.definitions.poke end
  local background=assert((loadstring or load)(assert(mod:read('Background.lua')),'@TerarriumBackground.lua'))()(api)
  api.drawBackground=function(arena)background.draw(arena,mod.options:get('background')or'auto')end
  api.releaseBackground=background.release
  local dome=assert((loadstring or load)(assert(mod:read('Dome.lua')),'@TerarriumDome.lua'))()(api)
  api.drawDome=function(arena,y)local style=mod.options:get('dome');if style and style~='off'then dome.draw(arena,y,style)end end
  api.releaseDome=dome.release
  api.gymDesign=assert((loadstring or load)(assert(mod:read('GymDesigns.lua')),'@GymDesigns.lua'))()(function(path)return mod:read(path)end,1,api.silphOccupied)
  local atmosphere=assert((loadstring or load)(assert(mod:read('GymAtmosphere.lua')),'@GymAtmosphere.lua'))()(api)
  api.drawAtmosphere=atmosphere.draw;api.releaseAtmosphere=atmosphere.release
  api.clock=function()return love.timer.getTime()end
  api.idleEnabled=function()return mod.options:get('idleAnimation')~=false end
  api.branding=function()return assert((loadstring or load)(assert(mod:read('Branding.lua')),'@TerarriumBranding.lua'))()(mod)end
  api.cameraMode=function()return mod.options:get('behindRed')==true and 'behind' or 'side'end
  if api.LocalLights then api.lighting=assert((loadstring or load)(assert(mod:read('Lighting.lua')),'@TerarriumLighting.lua'))()({lights=api.LocalLights,graphics=api.Voxel3D,clock=api.clock,enabled=function()return mod.options:get('lighting')end})end
  service=factory(api);return service
 end)
 assert(ok,reason)
 mod.events:on('battle.ended',function(event)if event and not event.skipped then service.endBattle(event.battle,event.result)end end)
 mod.exports.schema='vasc.terarrium-card/v1';mod.exports.active=true;mod.exports.version='0.2.2'
end
