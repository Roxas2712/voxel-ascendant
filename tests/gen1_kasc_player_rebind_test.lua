package.loaded['src.core.Game']={}
local root=assert(arg[1])
local W=assert(loadfile(root..'/integrated/ascendant_pokemon_overworld/src/walking_sprites.lua'))()

local native={kind='native',def={id='SPRITE_RED'}}
local kasc={kind='kasc',def={id='SPRITE_KA_CRYSTAL_GREEN_WALK'}}
local player={sprite=native}
local rawCalls,refreshCalls=0,0
function player:update()
 rawCalls=rawCalls+1
 self.sprite=kasc
 return nil,'native-update',nil,4
end

local world={player=player,playerState='normal'}
local game={overworld=world}
local binder=setmetatable({generation=1,activeGame=game,playerBridges=setmetatable({},{__mode='k'}),
 originals=setmetatable({},{__mode='k'}),atlasByRole={green='green-atlas'},characterActions=nil,
 _playerIdentityOwner=function()return 'kanto_ascendant'end},W)
function binder:_bind(entity,atlas,role,owner)
 assert(entity==player and atlas=='green-atlas' and role=='green')
 entity.sprite={kind='vasc',def={ascendantRole=role,ascendantAtlasImage=atlas}}
 entity.ascendantCharacterOwner=owner
 return true
end
function binder:refreshPlayer(active)
 assert(active==game);refreshCalls=refreshCalls+1
 return self:_bindPlayer(active,player,'green')
end

assert(binder:_bindPlayer(game,player,'green')==1)
assert(player.sprite.kind=='vasc')
local a,b,c,d=player:update()
assert(select('#',a,b,c,d)==4 and a==nil and b=='native-update' and c==nil and d==4)
assert(rawCalls==1 and refreshCalls==1)
assert(player.sprite.kind=='vasc','KASC renderer survived after player update')
assert(player.sprite.def.ascendantRole=='green')

local handlers={}
local mod={events={on=function(_,name,callback,priority)
 handlers[name]=handlers[name] or {};handlers[name][#handlers[name]+1]={callback=callback,priority=priority}
end}}
local installed=setmetatable({installed=false,mod=mod,generation=1},W)
assert(installed:install())
for _,name in ipairs({'save.loaded','save.created','game.ready','map.entered','map.reloaded',
 'character.selected','mod.johto_ascendant.character_selected','world.stepped','mod.options_changed'})do
 assert(handlers[name] and handlers[name][1].priority==-1000,name..' did not run after identity providers')
end

print('PASS Gen1 KASC player rebind: provider update first, VASC Green presentation last, exact returns and lifecycle priority')
