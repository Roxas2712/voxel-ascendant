local V=os.getenv('VASC_TEST_ROOT') or './'
local S=assert(loadfile(V..'lib/BattleSpriteSize.lua'))()
local function eq(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b))end
local expected={{.3,41.478260869565},{.4,43},{1,50},{1.1,50.903225806452},{1.5,54},{1.7,55.297297297297},{8.8,70.222222222222},{14.5,72.909090909091}}
for _,r in ipairs(expected)do eq(50*S.speciesScale(r[1]/.0254),r[2])end
for _,bad in ipairs({0,-1,0/0,math.huge,'broken'})do eq(S.speciesScale(bad),1)end
local last=0
for i=1,100000 do local s=S.speciesScale(i/10000/.0254);assert(s>=last and s>.72 and s<1.56);last=s end
assert(S.speciesScale(.4/.0254)/S.speciesScale(1.5/.0254)>.79)
assert(S.speciesScale(14.5/.0254)/S.speciesScale(.4/.0254)<2)
local t={vascRenderMon={},vascRenderModelKey='PIKACHU|front',inkTransient=true}
assert(S.referenceExtent(t,1,1,10,10)==nil)
t.vascReferenceExtent=27;t.vascReferenceComplete=true
eq(S.referenceExtent(t,1,1,10,10),27)
t.ascendantSpriteReceipt={apiVersion=1,body='full',referenceExtent=81};t.kantoAscendantNonCrystalHd=true
eq(S.referenceExtent(t,1,1,10,10),81)
t.ascendantSpriteReceipt.referenceExtent=0/0
assert(S.referenceExtent(t,1,1,10,10)==nil,'inherited native extent used by repainted card')
t.inkTransient=nil;eq(S.referenceExtent(t,0,0,26,26),27)
for frame=1,100 do eq(S.referenceExtent(t,0,0,30+frame%5,26),27)end
t.vascRenderModelKey='RAICHU|front';eq(S.referenceExtent(t,0,0,50,50),51)
t.vascRenderModelKey='PIKACHU|front';eq(S.referenceExtent(t,0,0,50,50),27)
print('PASS: approved target sizes, monotone bounded curve, malformed heights, stable fallback across poses, form ownership, transient/raw-source and wrapper isolation')

local f=assert(io.open(V..'lib/OverworldBattle.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('function OverworldBattle.sourceSpriteExtent',1,true))
local b=assert(source:find('-- Render one side',a,true))
for _,colon in ipairs({false,true})do
 local image={};local owner={};local api={apiVersion=1,forImage=function(img)assert(img==image);return 35 end}
 owner.find=function(first,second)
  local id=colon and first==owner and second or not colon and first
  if id=='kanto_ascendant'then return{exports={battleSpriteMetrics67=api}}end
 end
 local O={};local fn=assert(loadstring(source:sub(a,b-1)))
 setfenv(fn,setmetatable({OverworldBattle=O,V={mod=owner},BattlePics={inkBounds=function()error('verified source fell through')end}},{__index=_G}));fn()
 local extent,complete=O.sourceSpriteExtent(image);eq(extent,35);assert(complete)
end
print('PASS dot/colon companion capabilities including a nil nonthrowing lookup')
