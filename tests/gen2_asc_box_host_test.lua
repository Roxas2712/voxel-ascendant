-- Real Gen2 Boxes/Mail semantics through the shared storage action adapter.
local root=arg[1] or '.'
package.path=root..'/?.lua;'..(os.getenv('GEN1RECOMP_DIR') or assert(os.getenv('ENGINE_DIR'),'ENGINE_DIR required'))..'/?.lua;'..package.path
local Boxes=require('src.core.gen2.Boxes')
local Mail=require('src.core.gen2.Mail')
local V={mod={read=function(_,path)local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end,options={get=function()return 'en'end}}}
V.require=function(name)
 if name=='AscBoxProvider' then return {gridSpec=function()return{columns=5,slots=20}end}end
 error('optional '..name)
end
local H=assert(loadfile(root..'/gen2/lib/PokemonUiGen2Host.lua'))(V)
local P={MODEL_SCHEMA='model',ACTION_RESULT_SCHEMA='result',API_VERSION=1,HOST_GENERATION=1}
local function mon(species,hp)
 return {species=species,nickname=species,level=10,hp=hp or 20,maxHp=20,stats={hp=20,attack=10,defense=10,speed=10,special=10},dvs={},moves={{pp=1,maxPp=10}},status='PSN',statusTurns=4}
end
local function session(party,boxed)
 local save={party=party,boxes={[1]=boxed or {}},currentBox=1}
 local game={save=save,data={pokemon={}}}
 local s=H.Shared.PcSession.new(P,{},game,{},{});setmetatable(s,H.Session);s.hostId='vasc_gen2_native';s.surface='pc_box';s:buildModel();return s,save
end
local function envelope(s,zone,slot,box)
 local model=s:buildModel();local binding
 for _,b in pairs(s.bindings)do if b.zone==zone and b.slot==slot and b.box==box then binding=b;break end end
 assert(binding,'missing binding')
 return {target={id=binding.id,zone=zone,slot=slot,box=box},host=s.hostId,hostGeneration=1,surface='pc_box',session=s.id,action='move',modelRevision=s.revision}
end
local a,b,c=mon('TOTODILE'),mon('PIDGEY'),mon('EEVEE')
local s,save=session({a,b},{c})
local e=envelope(s,'party',1);assert(s:deposit(e).status=='applied');assert(save.boxes[1][2]==a and save.party[1]==b);assert(a.hp==20 and not a.status and a.moves[1].pp==10)
e=envelope(s,'box',a[H.Shared.SLOT_META_KEY],1);a.hp=1;a.status='PAR';assert(s:withdraw(e).status=='applied');assert(save.party[2]==a and a.hp==20 and not a.status)
-- Fainted teammates do not permit removing the last healthy Pokemon.
s,save=session({mon('A'),mon('B',0)},{})
e=envelope(s,'party',1);assert(s:deposit(e).status=='rejected');assert(#save.party==2 and #save.boxes[1]==0)
-- Reject held mail; shifting/swapping other party members preserves letters.
a,b,c=mon('A'),mon('B'),mon('C');b.item='FLOWER_MAIL'
s,save=session({a,b,c},{})
local letter={message='My actual letter',author='GOLD'};Mail.set(save,2,letter)
e=envelope(s,'party',2);assert(s:deposit(e).status=='rejected');assert(save.party[2]==b and Mail.get(save,2)==letter)
e=envelope(s,'party',1);assert(s:deposit(e).status=='applied');assert(save.party[1]==b and Mail.get(save,1)==letter and not Mail.get(save,2))
e=envelope(s,'party',1);e.destination={zone='party',slot=2};assert(s:move(e).status=='applied');assert(save.party[2]==b and Mail.get(save,2)==letter and not Mail.get(save,1))
-- Box/party swap may not bypass mail or last-healthy guards.
e=envelope(s,'box',a[H.Shared.SLOT_META_KEY],1);e.destination={zone='party',slot=2};assert(s:move(e).status=='rejected');assert(save.party[2]==b)
local egg=mon('TOGEPI',0);egg.isEgg=true
s,save=session({mon('A'),mon('B',0)},{egg})
e=envelope(s,'box',1,1);e.destination={zone='party',slot=1};assert(s:move(e).status=='rejected');assert(save.boxes[1][1]==egg)
-- Egg descriptors and search do not disclose the hatchling; no egg release.
e=envelope(s,'box',1,1);assert(s:release(e).code=='egg_hidden');local m=s:buildModel();assert(m.zones.box.entries[1].pokemon.species=='EGG');assert(not m.availability.release.enabled)
-- Valid healthy swap preserves records and native box PP restoration.
a,b,c=mon('A'),mon('B'),mon('C');s,save=session({a,b},{c})
e=envelope(s,'box',1,1);e.destination={zone='party',slot=1};assert(s:move(e).status=='applied');assert(save.party[1]==c and save.boxes[1][1]==a);assert(a.moves[1].pp==10 and not a.status and not c.status)
-- Bound confirmation required; stale confirmations cannot release another mon.
e=envelope(s,'box',1,1);local result=s:release(e);assert(result.status=='confirmation_required');assert(#save.boxes[1]==1)
e.confirmationToken='wrong';assert(s:release(e).status=='rejected');assert(#save.boxes[1]==1)
e.confirmationToken=result.confirmation.token;assert(s:release(e).status=='applied');assert(#save.boxes[1]==0)
-- Dynamic backend follows expanded storage, including late box page and seat.
Boxes.NUM_BOXES=60;s,save=session({mon('A'),mon('B')},{mon('C')});e=envelope(s,'box',1,1);e.destination={zone='box',box=60,slot=20};assert(s:move(e).status=='applied');assert(save.boxes[60][1].species=='C' and #save.boxes[1]==0);assert(save.boxes[60][1][H.Shared.SLOT_META_KEY]==20);assert(s:buildModel().surfaceData.boxCount==60)
print('PASS_GEN2_ASC_BOX_MAIL_HEALTH_EGGS_CONFIRMATION_SWAP_60_BOXES')
