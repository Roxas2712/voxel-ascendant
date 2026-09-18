-- Interaction-owned Johto idle pilot. Does not grant general modal animation.
local M={}
local unpack=table.unpack or unpack
local function pack(...)return {n=select("#",...),...}end
local baseProfiles={
 MAHOGANY_GYM={{index=1,role='pryce',atlas='assets/characters/npcs/pryce-kasc-hd-4x3-walk-sheet-v1.png'}},
 AZALEA_GYM={{index=1,role='bugsy',atlas='assets/characters/npcs/bugsy-kasc-hd-4x3-walk-sheet-v1.png'}},
 VIRIDIAN_GYM={{index=1,role='blue',atlas='assets/characters/npcs/blue-johto-gym-kasc-hd-4x3-walk-sheet-v1.png'}},
 CINNABAR_ISLAND={{index=1,role='blue',atlas='assets/characters/npcs/blue-johto-gym-kasc-hd-4x3-walk-sheet-v1.png'}},
 ELMS_LAB={{index=1,role='professor-elm',atlas='assets/characters/npcs/professor-elm-kasc-hd-4x3-walk-sheet-v1.png'}},
 PLAYERS_HOUSE_1F={
  {index=1,role='johto-mother',atlas='assets/characters/npcs/johto-mother-kasc-hd-4x3-walk-sheet-v1.png'},
  {index=5,role='pokefan-female-gen2',atlas='assets/characters/npcs/pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png'},
 },
}
local directions={'right','down-right','down','down-left','left','up-left','up','up-right'}
local function direction(dx,dy)
 if type(dx)~='number' or type(dy)~='number' or dx~=dx or dy~=dy
  or math.abs(dx)==math.huge or math.abs(dy)==math.huge or dx==0 and dy==0 then return end
 local angle=math.atan2(dy,dx)
 return directions[(math.floor(angle/(math.pi/4)+.5)%8)+1],angle
end
function M.new(options)
 local mod=assert(options.mod);local game,pending,current;local closed=false
 local profiles={}
 for mapId,list in pairs(baseProfiles)do
  profiles[mapId]={};for _,profile in ipairs(list)do profiles[mapId][#profiles[mapId]+1]=profile end
 end
 local seats=options.seatProfiles and options.seatProfiles.byGeneration
 seats=seats and seats[2]or{}
 for mapId,list in pairs(seats)do
  profiles[mapId]=profiles[mapId]or{}
  for _,seat in ipairs(list)do
   local duplicate=false
   for _,profile in ipairs(profiles[mapId])do
    if profile.index==seat.index and profile.role==seat.role then duplicate=true;break end
   end
   if not duplicate then
    profiles[mapId][#profiles[mapId]+1]={index=seat.index,role=seat.role,
     atlas=seat.path,cellX=seat.cellX,cellY=seat.cellY}
   end
  end
 end
 local api={}
 local function atlasFamily(path)
  local name=tostring(path or ''):gsub('\\','/'):match('([^/]+)%.png$')or''
  return name:gsub('%-variant%-.+$',''):gsub('(%-sheet%-v%d+)%-.+$','%1')
 end
 local function admitted(def,profile)
  local atlas=tostring(def and def.ascendantAtlasImage or ''):gsub('\\','/')
  return def and def.ascendantRole==profile.role
   and (atlas:find('/assets/characters/npcs/',1,true)or atlas:sub(1,24)=='assets/characters/npcs/')
   and atlasFamily(atlas)==atlasFamily(profile.atlas)
 end
 local function enabled()
  if closed or options.generation~=2 then return false end
  local function value(k,d)local ok,v=pcall(mod.options.get,mod.options,k);if ok and v~=nil then return v end;return d end
  return value('human_acting_pilot',false)==true and value('card_animation_mode','classic')=='natural'
   and value('hd_walking_sprites',true)==true and value('actor_voxel_grid','off')=='off'
 end
 function api:reset()
  if current and current.wrapper and current.vm.showTextFn==current.wrapper then
   current.vm.showTextFn=current.originalShow
  end
  pending,current=nil,nil
 end
 local function valid(s)
  if not s then return false end
  local w=s and s.world;local a=s and s.actor;local sp=a and a.sprite;local d=sp and sp.def
  return enabled() and game and game.save==s.save and game.stack==s.stack and game.world==w and w.map==s.map and w.map.id==s.mapId
   and w.player==s.player and w.vm==s.vm and w.talkNpc==a and sp==s.sprite and d==s.def
   and admitted(d,s.profile)
   and d.ascendantCharacterAction==nil and a.def==s.actorDef and a.def.scriptKey==s.key and a.def.index==s.profile.index
   and (s.profile.cellX==nil or a.cellX==s.profile.cellX and a.cellY==s.profile.cellY)
 end
 function api:eligible(g,record)
  local s=current
  if g~=game or not valid(s) then self:reset();return false end
  local w,a=s.world,s.actor
  local topOk,box=pcall(s.stack.top,s.stack)
  local runningOk,running=pcall(w.scriptRunning,w)
  if not topOk or not runningOk or running~=true or w.vm.ctx~=s.ctx then self:reset();return false end
  if not s.box then return false end
  -- Once a displayed window loses its safe state, returning to that same
  -- object/position must not revive it. The owned VM may grant a fresh box.
  if box~=s.box or not box.isTextBox then s.box=nil;return false end
  if a.moving or a.scriptedMoving or a.frozen~=true or a.px~=s.px or a.py~=s.py then
   s.box=nil;return false
  end
  if record.sprite~=a.sprite or record.def~=s.def then return false end
  return true,w,w.map,s.box
 end
 function api:target(g,actor)
  if not actor or not actor.sprite then return end
  local ok,w=api:eligible(g,{sprite=actor.sprite,def=actor.sprite.def})
  if not ok then return end
  local player=w.player
  if not player or type(player.px)~='number' or type(player.py)~='number' then return end
  local face,angle=direction(player.px-actor.px,player.py-actor.py)
  if not face then return end
  return player,face,angle,'speaker','johto-owned-dialogue'
 end
 function api:restore()closed=true;self:reset();game=nil end
 if options.generation~=2 then return api end
 local events=assert(mod.events)
 for _,name in ipairs({'game.ready','save.loaded','save.created','map.entered','map.reloaded','mod.options_changed'})do
  events:on(name,function(ev)if ev and ev.game then game=ev.game end;api:reset()end)
 end
 events:on('world.interacted',function(ev)
  api:reset();local w=game and game.world;local a=ev and ev.target
  if not enabled() or not w or not w.map or not profiles[w.map.id] or ev.mapId~=w.map.id
   or type(w.vm)~='table' or ev.kind~='npc' or type(a)~='table' or not a.sprite or not a.def or not a.def.scriptKey then return end
  local found=false;for _,npc in pairs(w.npcs or {})do if npc==a then found=true end end
  if not found then return end
  local selected;local d=a.sprite.def
  for _,profile in ipairs(profiles[w.map.id])do
   if d and a.def.index==profile.index and admitted(d,profile)
    and (profile.cellX==nil or a.cellX==profile.cellX and a.cellY==profile.cellY)then selected=profile end
  end
  if not selected then return end
  pending={world=w,map=w.map,mapId=w.map.id,profile=selected,save=game.save,stack=game.stack,player=w.player,vm=w.vm,actor=a,sprite=a.sprite,
   def=a.sprite.def,actorDef=a.def,key=a.def.scriptKey}
  if not valid(pending) then pending=nil end
 end)
 events:on('script.started',function(ev)
  local s=pending;api:reset();local ctx=ev and ev.ctx
  if not valid(s) or not ctx or ctx.generation~=2 or ctx.kind~='script' or ctx.vm~=s.vm
   or ctx.scriptKey~=s.key or type(s.actorDef.index)~='number' or ctx.object~=s.actorDef.index+1 then return end
  if type(s.vm.showTextFn)~='function' then return end
  s.ctx=ctx;current=s;s.originalShow=s.vm.showTextFn
  s.wrapper=function(...)
   local request=s.vm.pending
   s.showing=current==s and s.vm.ctx==s.ctx and request and request.kind=='text'
   local result=pack(pcall(s.originalShow,...));s.showing=nil
   if not result[1] then api:reset();error(result[2],0)end
   return unpack(result,2,result.n)
  end
  s.vm.showTextFn=s.wrapper
 end)
 events:on('script.ended',function()api:reset()end)
 events:on('screen.pushed',function(ev)
  local s=current;local box=ev and ev.state
  if not valid(s) or s.vm.ctx~=s.ctx then return end
  s.box=nil
  if box and box.isTextBox==true and s.showing==true then
   s.box=box;s.px,s.py=s.actor.px,s.actor.py
  end
 end)
 events:on('screen.popped',function(ev)
  if current and ev and ev.state==current.box then current.box=nil end
 end)
 return api
end
return M
