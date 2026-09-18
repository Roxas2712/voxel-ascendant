-- Experimental scene acting. Admitted textures load outside draw; exact
-- dialogue ownership is separate from the general idle/movement permission.
local M={}
local unpack=table.unpack or unpack
local function pack(...)return {n=select('#',...),...}end
local names={'down-left','down-right','up-left','up-right'}
function M.new(options)
 local mod,Dialogue=assert(options.mod),assert(options.dialogue)
 local api={generation=options.generation,selected=0,loads=0,seatedMother=options.seatedMother}
 local game,owner,conversation,bridge,gen2Installed
 local dialogueIdle=options.dialogueIdle
 local states={}
 for path,definition in pairs(assert(options.profiles))do
  local state={definition=definition,poses={}}
  for _,pose in ipairs(definition.poses or {})do
   state.poses[#state.poses+1]={definition=pose}
  end
  states[mod.path..'/'..path]=state
 end
 local prepared={}
 local function clearPrepared()
  for sprite in pairs(prepared)do prepared[sprite]=nil end
 end
 local function value(key,default)
  if not mod.options or type(mod.options.get)~='function' then return default end
  local ok,v=pcall(mod.options.get,mod.options,key)
  if ok and v~=nil then return v end
  return default
 end
 function api:enabled()
  return (self.generation==1 or self.generation==2) and value('human_acting_pilot',false)==true
   and value('card_animation_mode','classic')=='natural'
   and value('hd_walking_sprites',true)==true
 end
 function api:reset()
  clearPrepared()
  for _,state in pairs(states)do
   if state.turn then state.turn:reset()end
   for _,pose in ipairs(state.poses)do if pose.turn then pose.turn:reset()end end
  end
  if owner then owner:reset()end
  if conversation then conversation:reset()end
  if api.seatedMother then api.seatedMother:reset()end
 end
 local function adopt(g)
  if game~=g then
   api:reset();if conversation then conversation:close()end
   game=g;owner=g and Dialogue.new(g)or nil
   conversation=g and api.generation==1 and options.conversation and options.conversation.new(g)or nil
  end
 end
 function api:load(state)
  if not state or state.texture or state.attempted or not self:enabled()then return end
  state.attempted=true
  local atlas,bounds=state.definition.atlas,state.definition.bounds
  local ok,result=pcall(function()
   local data=require('src.render.Assets').imageData(mod.path..'/'..atlas)
   assert(data and data:getWidth()==bounds[1].imageWidth and data:getHeight()==bounds[1].imageHeight,'acting atlas dimensions')
   for _,b in ipairs(bounds)do
    local _,_,_,alpha=data:getPixel(math.floor((b.left+b.right)/2),math.floor((b.top+b.bottom)/2))
    assert(alpha and alpha>.02,'empty acting pose')
   end
   local image=love.graphics.newImage(data)
   image:setFilter('linear','linear')
   return image
  end)
  if not ok then self.error=tostring(result);return end
  if options.turn and state.definition.turn then
   state.turn,self.turnError=options.turn.new(mod.path,state.definition.turn,options.idle)
  end
  state.texture=result;self.loads=self.loads+1;state.sources={}
  for i,name in ipairs(names)do
   local source={id=mod.path..'/'..atlas..'#'..name,texture=result,bounds={}}
   for r=0,3 do source.bounds[r]={};for c=0,2 do source.bounds[r][c]=bounds[i]end end
   local eyes=state.definition.eyes and state.definition.eyes[i]
   if eyes then
    -- Acting sheets use a reviewed free-form atlas instead of the ordinary
    -- 3x4 walk layout. Keep the eye boxes on the selected source so HumanBlink
    -- can composite the full atlas without guessing from actor identity.
    source.humanBlink={procedural=true,fullAtlas=true,
     width=bounds[i].imageWidth,height=bounds[i].imageHeight,rows={[0]=eyes}}
   end
   state.sources[name]=source
  end
 end
 function api:loadWorld(world)
  if not self:enabled()then return end
  for _,actor in pairs(world and world.npcs or {})do
   local def=actor.sprite and actor.sprite.def
   local state=def and states[def.ascendantAtlasImage]
   if state then
    self:load(state)
    -- Exact dialogue poses are prepared on map entry, outside the draw that
    -- first selects them. A missing optional pose falls back to the already
    -- loaded directional sheet for this same actor.
    for _,pose in ipairs(state.poses)do self:load(pose)end
   end
  end
 end
 function api:frame(g,world,allowGrid)
  adopt(g);clearPrepared()
  if not self:enabled()then self:reset();return end
  local liveWorld=api.generation==2 and game and game.world
    or game and (game.overworld or game.world)
  if not game or not world or liveWorld~=world then return end
  -- Candidate diagonal silhouettes do not yet have reviewed grid occupancy.
  if allowGrid then self:reset();return end
  if self.seatedMother then
   local sprite,source=self.seatedMother:frame(game,world,conversation,love.timer.getTime())
   if sprite then prepared[sprite]=source end
  end
  if not owner and not dialogueIdle then return end
  for _,state in pairs(states)do
   state.turnUsed=false
   for _,pose in ipairs(state.poses)do pose.turnUsed=false end
  end
  local function selectActor(actor,target)
   local sprite=actor and actor.sprite;local def=sprite and sprite.def
   local state=def and states[def.ascendantAtlasImage]
   if not state or def.ascendantCharacterAction~=nil then return end
   self:load(state);if not state.sources then return end
   local other,direction,angle,kind,key
   if target then other,direction,angle,kind,key=unpack(target,1,target.n) end
   if not direction then return end
   local selected=state
   for _,pose in ipairs(state.poses)do
    local definition=pose.definition
    if definition.key==key and definition.kind==kind then
     self:load(pose)
     if pose.sources then selected=pose end
     break
    end
   end
   local turned=selected.turn and selected.turn:prepare(sprite,direction,love.timer.getTime(),actor.facing)
   selected.turnUsed=turned~=nil
   if turned or selected.sources[direction]then
    prepared[sprite]=turned or selected.sources[direction]
   end
  end
  if self.generation==1 and owner then
   local a,b,c=owner:actors()
   if a then selectActor(a,pack(owner:target(world,a,game.stack:top())))end
   if b then selectActor(b,pack(owner:target(world,b,game.stack:top())))end
   if c then selectActor(c,pack(owner:target(world,c,game.stack:top())))end
  elseif self.generation==2 and dialogueIdle then
   for _,actor in pairs(world.npcs or {})do
    selectActor(actor,pack(dialogueIdle:target(game,actor)))
   end
  end
  for _,state in pairs(states)do
   if state.turn and not state.turnUsed then state.turn:reset()end
   for _,pose in ipairs(state.poses)do
    if pose.turn and not pose.turnUsed then pose.turn:reset()end
   end
  end
 end
 function api:source(sprite)
  if not self:enabled()then return end
  local source=prepared[sprite]
  if source then self.selected=self.selected+1 end
  return source
 end
 function api:conversationOwns(world,actorOrSprite,box)
  if not self:enabled() or not conversation or not world then return false end
  local actor=actorOrSprite and actorOrSprite.sprite and actorOrSprite or nil
  if not actor then
   for _,candidate in pairs(world.npcs or {})do
    if candidate.sprite==actorOrSprite then if actor then return false end;actor=candidate end
   end
  end
  return actor and conversation:owns(world,actor,box) or false
 end
 local function entityForRecord(world,record)
  if not world or not record or not record.sprite then return end
  local entity=world.player and world.player.sprite==record.sprite and world.player or nil
  for _,candidate in pairs(world.npcs or {})do
   if candidate.sprite==record.sprite then
    if entity then return end
    entity=candidate
   end
  end
  return entity
 end
 function api:idleContext(g,record)
  adopt(g)
  if not self:enabled() or not game or not record or not record.sprite then return false end
  local world=self.generation==2 and game.world or game.overworld or game.world
  if not world or not world.map or not game.stack or type(game.stack.top)~='function'then return false end
  local ok,box=pcall(game.stack.top,game.stack)
  if not ok or not box or box.isTextBox~=true then return false end
  local entity=entityForRecord(world,record)
  if not entity then return false end
  if owner and owner:target(world,entity,box)then return true,world,world.map,box end
  if conversation and type(conversation.participants)=='function'then
   local speaker,listener=conversation:participants(world,box)
   if entity==speaker or entity==listener then return true,world,world.map,box end
  end
  if dialogueIdle then
   local eligible,w,map,owned=dialogueIdle:eligible(game,record)
   if eligible then return eligible,w,map,owned end
  end
  return false
 end
 function api:scriptContext(g,record)
  adopt(g)
  if self.generation~=1 or not self:enabled() or not game then return false end
  local world=game.overworld or game.world
  if not world or not world.map or (world.map.id~='PALLET_TOWN' and world.map.id~='OAKS_LAB')
      or not game.stack or type(game.stack.top)~='function'then return false end
  local ok,top=pcall(game.stack.top,game.stack)
  if not ok or not top or top.isOverworld~=true then return false end
  local entity=entityForRecord(world,record)
  local role=entity and entity.sprite and entity.sprite.def and entity.sprite.def.ascendantRole
  if not entity or (entity~=world.player and role~='professor-oak') or not entity.moving then return false end
  for _,move in pairs(world.scriptMoves or {})do
   if move.entity==entity and move.remaining~=nil then return true,world,world.map end
  end
  return false
 end
 function api:install()
  if self.generation==2 then
   if gen2Installed then return end
   gen2Installed=true
   if mod.events and type(mod.events.on)=='function'then
    local function warm(ev)
     if ev and ev.game then adopt(ev.game)end
     api:reset()
     local world=game and game.world
     if api:enabled() and world then api:loadWorld(world)end
    end
    for _,event in ipairs({'game.ready','save.loaded','save.created','map.entered','map.reloaded'})do
     mod.events:on(event,warm)
    end
    mod.events:on('mod.options_changed',function(ev)
     if not ev or not ev.mod or ev.mod==mod.id then
      api:reset();for _,state in pairs(states)do
       state.attempted=nil
       for _,pose in ipairs(state.poses)do pose.attempted=nil end
      end;api.error=nil
      local world=game and game.world
      if api:enabled() and world then api:loadWorld(world)end
     end
    end)
   end
   return
  end
  if bridge or self.generation~=1 then return end
  local ok,TextBox=pcall(require,'src.render.TextBox')
  if not ok or type(TextBox.new)~='function' then return end
  local native=TextBox.new;bridge={module=TextBox,native=native}
  local own=bridge
  own.wrapper=function(g,text,...)
   local result=pack(native(g,text,...))
   if bridge==own and g==game and owner and api:enabled()then
    local key=Dialogue.keyForText(g.data and g.data.text,text)
    owner:capture(key,result[1])
   end
   return unpack(result,1,result.n)
  end
  TextBox.new=own.wrapper
  if mod.hooks and type(mod.hooks.wrap)=='function'then
   mod.hooks:wrap('world.talk',function(nextFn,world,actor,...)
    if bridge==own and api:enabled() and conversation then
     return conversation:talk(world,actor,nextFn,world,actor,...)
    end
    return nextFn(world,actor,...)
   end)
  end
  local function warm()
   local world=game and (game.overworld or game.world)
   local id=world and world.map and world.map.id
   if api:enabled()then
    if id=='PALLET_TOWN' or id=='OAKS_LAB' then api:loadWorld(world)end
    if id=='REDS_HOUSE_1F' and api.seatedMother then api.seatedMother:queue()end
   end
  end
  if mod.events and type(mod.events.on)=='function'then
   for _,event in ipairs({'game.ready','save.loaded','save.created','map.entered','map.reloaded'})do
    mod.events:on(event,function(ev)
     if ev and ev.game then adopt(ev.game)end
     api:reset()
     warm()
    end)
   end
   mod.events:on('mod.options_changed',function(ev)
    if not ev or not ev.mod or ev.mod==mod.id then
     api:reset();for _,state in pairs(states)do state.attempted=nil end;api.error=nil
     if api.seatedMother then api.seatedMother:retry()end
     warm()
    end
   end)
  end
 end
 function api:restore()
  self:reset();game=nil;owner=nil
  if conversation then conversation:close();conversation=nil end
  if self.seatedMother then self.seatedMother:restore()end
  if bridge and bridge.module.new==bridge.wrapper then bridge.module.new=bridge.native end
  bridge=nil;gen2Installed=nil
  for _,state in pairs(states)do
   if state.turn then state.turn:restore();state.turn=nil end
   if state.texture then state.texture:release()end
   state.texture,state.sources,state.attempted=nil,nil,nil
   for _,pose in ipairs(state.poses)do
    if pose.turn then pose.turn:restore();pose.turn=nil end
    if pose.texture then pose.texture:release()end
    pose.texture,pose.sources,pose.attempted=nil,nil,nil
   end
  end
 end
 return api
end
return M
