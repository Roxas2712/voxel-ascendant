-- Explicit Gen1 opening-scene metadata, not general modal permission.
local M={}
local unpack=table.unpack or unpack
local function pack(...)return {n=select("#",...),...}end
local hasPause={
 _OaksLabRivalFedUpWithWaitingText=true,
 _OaksLabOakChooseMonText=true,
 _OaksLabRivalWhatAboutMeText=true,
}
local routes={
 _OaksLabRivalFedUpWithWaitingText={map='OAKS_LAB',speaker='OAKSLAB_RIVAL',partner='OAKSLAB_OAK1'},
 _OaksLabOakChooseMonText={map='OAKS_LAB',speaker='OAKSLAB_OAK1',partner='player',observer='OAKSLAB_RIVAL'},
 _OaksLabRivalWhatAboutMeText={map='OAKS_LAB',speaker='OAKSLAB_RIVAL',partner='OAKSLAB_OAK1'},
 _OaksLabOakBePatientText={map='OAKS_LAB',speaker='OAKSLAB_OAK1',partner='OAKSLAB_RIVAL'},
 _PalletTownOakItsUnsafeText={map='PALLET_TOWN',speaker='PALLETTOWN_OAK',partner='player'},
}
function M.keyForText(data,text)
 if type(data)~='table' or type(text)~='string' then return end
 local found
 for key in pairs(routes)do
  if data[key]==text then
   if found then return end
   found=key
  end
 end
 return found
end
local function actor(world,name)
 if name=='player' then return world.player end
 local found
 for _,npc in pairs(world.npcs or {})do
  if npc.def and npc.def.name==name then
   if found then return nil end -- Ambiguous duplicated object: no inferred owner.
   found=npc
  end
 end
 return found
end
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function snapshot(a)
 if type(a)~='table' or type(a.sprite)~='table' or a.moving or a.scriptedMoving
   or not finite(a.px) or not finite(a.py) then return end
 local d=a.sprite.def
 return {actor=a,sprite=a.sprite,def=d,atlas=d and d.ascendantAtlasImage,
  action=d and d.ascendantCharacterAction,px=a.px,py=a.py}
end
local function unchanged(s)
 local a=s.actor;local d=a.sprite and a.sprite.def
 return a.sprite==s.sprite and d==s.def and (not d or
  (d.ascendantAtlasImage==s.atlas and d.ascendantCharacterAction==s.action))
  and a.px==s.px and a.py==s.py and not a.moving and not a.scriptedMoving
end
local directions={'right','down-right','down','down-left','left','up-left','up','up-right'}
function M.direction(dx,dy)
 if not finite(dx) or not finite(dy) or (dx==0 and dy==0) then return end
 local angle=math.atan2(dy,dx)
 return directions[(math.floor(angle/(math.pi/4)+.5)%8)+1],angle
end
function M.new(game)
 local current
 local api={}
 function api:reset()
  if current and current.doneWrapper and current.box.onDone==current.doneWrapper then
   current.box.onDone=current.nativeDone
  end
  current=nil
 end
 function api:actors()
  if current then return current.a.actor,current.b.actor,current.observer and current.observer.actor end
 end
 local function context(world,map)
  local flags=game.save and game.save.flags
  if not flags or flags.EVENT_OAK_ASKED_TO_CHOOSE_MON then return false end
  if map.id=='OAKS_LAB' and not flags.EVENT_FOLLOWED_OAK_INTO_LAB then return false end
  return (game.overworld or game.world)==world and world.map==map
 end
 function api:capture(key,box)
  self:reset()
  local route=routes[key];local world=game.overworld or game.world
  if not route or not box or box.isTextBox~=true or not world or not world.map
    or world.map.id~=route.map or not context(world,world.map)then return false end
  local a,b=snapshot(actor(world,route.speaker)),snapshot(actor(world,route.partner))
  local observer=route.observer and snapshot(actor(world,route.observer))
  if not a or not b or route.observer and not observer then return false end
  current={box=box,key=key,route=route,world=world,map=world.map,save=game.save,
    player=world.player,a=a,b=b,observer=observer}
  -- Retain this exact pose through the native three-tick dialogue pause.
  -- Admit only a hold created by this box's completion callback; unrelated
  -- emotes, overworld frames and modal overlays never inherit the pose.
  local c=current
  if hasPause[key] and type(box.onDone)=='function' then
   c.nativeDone=box.onDone
   c.doneWrapper=function(...)
    local before=world.emote
    local result=pack(c.nativeDone(...))
    local hold=world.emote
    if current==c and hold and hold~=before and hold.frames==3
      and hold.npc==nil and type(hold.onDone)=='function' and game.stack:top()==world then
     c.hold=hold;c.holdDone=hold.onDone
    end
    return unpack(result,1,result.n)
   end
   box.onDone=c.doneWrapper
  end
  return true
 end
 function api:target(world,entity,box)
  local c=current
  if not c then return end
  if game.save~=c.save or world~=c.world or world.player~=c.player or not context(world,c.map)
    or actor(world,c.route.speaker)~=c.a.actor or actor(world,c.route.partner)~=c.b.actor
    or not unchanged(c.a) or not unchanged(c.b)
    or c.observer and (actor(world,c.route.observer)~=c.observer.actor or not unchanged(c.observer))then self:reset();return end
  local top=game.stack:top()
  local hold=c.hold
  local inPause=top==world and box==world and hold and world.emote==hold
    and hold.onDone==c.holdDone and hold.npc==nil
    and finite(hold.frames) and hold.frames>0 and hold.frames<=3
  if not inPause and (box~=c.box or top~=box) then return end
  -- Both speaker and listener attend to each other. Other actors retain
  -- their own native pose instead of all turning toward the player.
  local other,kind
  if entity==c.a.actor then other,kind=c.b.actor,'speaker'
  elseif entity==c.b.actor then other,kind=c.a.actor,'listener'
  elseif c.observer and entity==c.observer.actor then other,kind=c.a.actor,'observer'
  else return end
  local direction,angle=M.direction(other.px-entity.px,other.py-entity.py)
  if not direction then return end
  return other,direction,angle,kind,c.key
 end
 return api
end
return M
