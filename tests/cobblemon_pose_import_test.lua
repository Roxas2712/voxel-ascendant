local V={};local cache={}
function V.require(n)if not cache[n]then cache[n]=assert(loadfile('lib/'..n..'.lua'))(V)end;return cache[n]end
local G=V.require('CobblemonGeometry');local Import=V.require('CobblemonImport')
local files={}
files.resolver={variations={{model='cobblemon:test',poser='cobblemon:test',texture='cobblemon:textures/test.png'}}}
files.model={['minecraft:geometry']={{description={texture_width=16,texture_height=16},bones={{name='body',pivot={0,0,0},cubes={{origin={0,0,0},size={1,1,1},uv={0,0}}}},{name='tail',parent='body',pivot={0,0,0}}}}}}
local function ref(n)return "q.bedrock('test', '"..n.."')"end
files.poser={poses={standing={poseTypes={'STAND'},animations={ref('body'),ref('tail'),ref('broken')}}},animations={physical=ref('physical'),special=ref('special'),status=ref('status'),recoil=ref('recoil')}}
local function clip(seconds,bones)return {animation_length=seconds,loop=true,bones=bones}end
files.animation={animations={
 ['animation.test.body']=clip(2,{body={position={0,1,0}}}),
 ['animation.test.tail']=clip(1,{tail={rotation={0,0,30}}}),
 ['animation.test.broken']=clip(1,{tail={rotation={'q.unsupported',0,0}}}),
 ['animation.test.physical']=clip(.6,{body={rotation={10,0,0}}}),
 ['animation.test.special']=clip(.8,{body={rotation={20,0,0}}}),
 ['animation.test.status']=clip(.4,{body={rotation={30,0,0}}}),
 ['animation.test.recoil']=clip(.3,{body={rotation={-10,0,0}}})}}
local catalog={species={['1']={'resolver'}},index={['model:test']='model',['poser:test']='poser',['animation:test']='animation'}}
local function compile()return Import.compile(catalog,1,{},function(p)return files[p] or p end,function(x)return x end)end
local m=compile();assert(m.actions.attack_physical~=m.actions.attack_special and m.actions.attack_status)
assert(m.actionSources.attack_default=='vasc' and m.actionSources.attack_physical=='cobblemon')
local pose=m.anims[m.actions.idle];assert(#pose.layers==2,'one bad layer discarded a good track')
local out=G.sample(m,m.actions.idle,45,true);assert(out[2][2]==1 and math.abs(out[3][6]+30*32768/180)<.01,'body and tail must both animate')
assert(#m.warnings>0,'unsupported track was not diagnosed')
files.poser.animations.special=ref('broken');m=compile();assert(not m.actions.attack_special and m.actions.attack_default,'invalid special did not retain VASC fallback')
files.poser.animations.physical=ref('absent');m=compile();assert(not m.actions.attack_physical,'missing clip claimed as original')
-- Independent loop periods, additive rotation/translation, multiplicative scale.
local a=G.clip(clip(1,{body={position={['0']={0,0,0},['1']={2,0,0}},scale={2,2,2}}}),{body=2})
local b=G.clip(clip(2,{body={position={['0']={0,0,0},['2']={0,4,0}},scale={3,3,3}}}),{body=2})
m.anims[#m.anims+1]={seconds=2,layers={a,b},channels={}}
local n=#m.anims;out=G.sample(m,n,45,true)
assert(out[2][1]==1 and out[2][2]==3 and out[2][7]==6,'independent periods/additive blend')
local prior=out;out=G.sample(m,n,75,true);assert(out==prior and out[2][1]==1 and out[2][2]==1,'pose buffer reuse/independent repeat')
print('PASS original category import, combined pose layers, independent clocks, rejected-layer isolation and authored fallback')
