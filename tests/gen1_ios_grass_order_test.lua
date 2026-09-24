-- A navigation ghost must run before grass; opaque actors must run after it.
-- This executes the scene's cast pass with renderer dependencies recorded.
local root=assert((...) or arg[1],'package root required')..'/'
local calls,glass,seams,room={},false,false,nil
local function mark(name)calls[#calls+1]=name end
local noop=function()end
local depth={
 roomVisibility=function(v)room=v end,
 glass=function(v)glass=v end,seams=function(v)seams=v end,
 beginGhost=function()mark('ghost-start')end,endGhost=function()mark('ghost-end')end,
 waterline=noop,
}
local hide=false
local modules={
 Voxel3D=depth,CanvasPresentation={OS='iOS'},
 VoxelState={isFirstPerson=function()return false end},
 FirstPerson={hidePlayer=function()return hide end},
 PropVisibility={forView=function()return function()return true end end},
 VoxelFurniture={draw=function()mark('furniture')end},
 Gen1OverworldStadium={draw=function(p)
  assert(not glass and not seams and room==nil,'actors retain actor shading and unclipped rooms')
  mark(p.isPlayer and 'player' or 'npc');return true
 end},
}
package.preload['src.render.PaletteFX']=function()return {}end
package.preload['src.world.Map']=function()return {}end
local scene=assert(loadfile(root..'lib/VoxelScene.lua')){require=function(n)
 if not modules[n]then modules[n]={}end;return modules[n]
end}
local draw=scene._drawCast
for i=1,100 do
 local name=debug.getupvalue(draw,i);if not name then break end
 if name=='drawGhost'then debug.setupvalue(draw,i,function()mark('ghost')end)end
 if name=='billboardPull'then debug.setupvalue(draw,i,function()return 1 end)end
 if name=='eachFigure'then debug.setupvalue(draw,i,function()mark('figures')end)end
end
local state={map={},currentRoom={}}
local posed={{isPlayer=true},{isPlayer=false}}
local function grass()
 assert(glass and seams and room==state.currentRoom,'grass retains terrain shading and room mask')
 mark('grass')
end
draw(state,posed,noop,{},grass)
assert(table.concat(calls,',')=='furniture,ghost-start,ghost,ghost-end,grass,player,npc,figures')
assert(glass and seams,'terrain shading restored after actors')
calls={};draw(state,posed,noop,nil,nil)
assert(table.concat(calls,',')=='furniture,player,npc,figures','reflections/desktop must not acquire a grass or ghost pass')
hide=true;calls={};draw(state,posed,noop,{},grass)
assert(table.concat(calls,',')=='furniture,grass,npc,figures','first-person hides player/ghost, not grass or NPCs')
print('PASS iOS grass ordering, ghost exclusion, room/material state, reflections and first-person')
