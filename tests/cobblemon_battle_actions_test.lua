local modules={Mat4={},StadiumPack={N_MOVES=165,NONE=-1},StadiumRig={},LugiaRescue={}}
local V={require=function(n)return assert(modules[n],n)end}
local Mon=assert(loadfile('gen2/lib/StadiumMon.lua'))(V)
local Bridge=assert(loadfile('gen2/lib/BattleStadiumAnimations.lua'))(V)
local function actor(source)
 local a=Mon.new('player');a.rig={};a.model={source=source,actions={idle=1,battle=1,attack_default=2,attack_physical=3,attack_special=4,attack_status=5,flinch=6,entrance=7},anims={}}
 for i=1,7 do a.model.anims[i]={seconds=.5}end
 return a
end
local a=actor('cobblemon')
local cases={{ {category='physical',type='FIRE',power=40},3 },{{category='special',type='NORMAL',power=40},4},{{type='FIRE',power=40},4},{{type='PSYCHIC_TYPE',power=40},4},{{type='DARK',power=40},4},{{type='NORMAL',power=40},3},{{type='STEEL',power=40},3},{{type='FIRE',power=0},5},{{category='status',power=1},5},{{type='UNKNOWN',power=40},2},{{},2}}
for _,row in ipairs(cases)do
 for _,route in ipairs({'attack','attackGen2'})do
  a.state='idle';assert(a[route](a,22,row[1]));assert(a.anim==row[2],route..' category routing');assert(a.state=='attack' and not a.loop)
  a:update(1);assert(a.state=='idle','attack must return to idle')
 end
 a.state='idle';assert(Bridge.requestGen2Attack(a,nil,row[1]));assert(a.anim==row[2],'named/custom moves must retain definition without numeric index')
end
for _,category in ipairs({'physical','special','status'})do
 local key='attack_'..category;local keep=a.model.actions[key];a.model.actions[key]=nil;a.state='idle'
 assert(a:attack(22,{category=category,power=40}) and a.anim==2,'missing category must use VASC, not another original attack');a.model.actions[key]=keep
end
a.state='idle';assert(a:request('hit') and a.anim==6,'Cobblemon recoil used cry');a.state='idle';assert(a:request('entrance') and a.anim==7)
a.state='idle';a._stage1Recoil=1;assert(Bridge.requestRecoil(a) and a.anim==6 and a._stage1Recoil==nil,'authored recoil must replace generic nudge')
a.time=.1;assert(Bridge.requestRecoil(a) and a.time==.1,'HP observation restarted existing recoil')
a.state='faint';assert(not a:attack(22,{category='physical'}) and not a:attackGen2(22,{category='special'}),'fainted actor restarted')
a.state='idle';assert(a:manualAttackGen2() and a.anim==2,'manual button must not cycle into faint or walk')
local stadium=actor('stadium');stadium.model.moveAnim={[22]=2};stadium.model.moveAux={};stadium.model.ctx={}
assert(stadium:attack(22,{category='special'}) and stadium.anim==3,'Stadium exact move table changed')
stadium.state='idle';assert(stadium:request('hit') and stadium.anim==7,'Stadium hit contract changed')
local fallback={rig={},state='idle',attackGen2=function()return false end,request=function(_,state)assert(state=='attack');return true end}
assert(Bridge.requestGen2Attack(fallback,200,{category='special'}),'existing VASC fallback not reached')
print('PASS Cobblemon categories, both generation routes, missing clips, custom IDs, recoil, faint priority and unchanged Stadium fallback')

local crystal=actor('cobblemon');local released=0;crystal.rig.release=function()released=released+1 end
V.PokemonModelProvider={resolve=function()return 'crystal' end}
assert(not crystal:setSpecies(25,true) and not crystal.rig and not crystal.model and released==1,'Crystal source must retire 3D resources without reading Stadium packs')
V.PokemonModelProvider=nil
print('PASS Crystal live source releases model without unrelated optional pack loading')
