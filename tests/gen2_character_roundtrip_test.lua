local root=assert(arg[1])
local Walking=assert(loadfile(root..'/integrated/ascendant_pokemon_overworld/src/walking_sprites.lua'))()
local player,npc={},{}
local game={save={version='crystal',player={characterKey='kris'}},world={player=player,entities={player,npc},map={id='ROUTE_29'}}}
local callbacks={}
local binder=setmetatable({generation=2,mod={id='VOXEL_ASCENDANT',events={on=function(_,name,fn)callbacks[name]=fn end}},
  atlasByRole={gold='gold',kris='kris',silver='silver'},playerRole='gold',activeGame=game,
  compat={characterSources=function()return {}end},applied=0,
  enabled=function()return true end,_kasc=function()end,
  _bindPlayer=function(_,entityGame,entity,role)assert(entity==player);entity.role=role;return 1 end,
  _rowFor=function()end,_atlasFor=function()return 'npc' end,_identity=function()return 'SPRITE_TEACHER'end,
  _bind=function(_,entity)assert(entity~=player,'player was rebound as NPC');entity.bound=true;return true end,
},Walking)
binder:install()
for _,key in ipairs({'kris','gold','silver','johto.kris','johto.gold','johto.silver','kris'})do
  game.save={version='crystal',player={characterKey=key}}
  callbacks['save.loaded']({game=game})
  local expected=key:gsub('johto%.','')
  assert(player.role==expected,'save identity stuck on previous hero')
  assert(npc.bound,'missing npcs table skipped entities')
  binder:apply(game,false);assert(player.role==expected,'movement lost authoritative hero')
end
callbacks['mod.johto_ascendant.character_selected']({game=game,character='silver'})
assert(player.role=='silver','explicit JASC selection lost')
binder:apply(game,false);assert(player.role=='silver')
game.save={version='crystal',player={characterKey='kris'}}
callbacks['save.created']({game=game});assert(player.role=='kris')
game.world.npcs={npc};game.world.objects={npc,player}
binder:apply(game,false);assert(player.role=='kris')
print('PASS Gen2 hero save/selection roundtrip, sparse entity buckets, player excluded from NPC rebinding')
