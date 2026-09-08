local function extract(path,first,last,env)
 local f=assert(io.open(path));local s=f:read('*a');f:close()
 local a=assert(s:find(first,1,true));local b=assert(s:find(last,a,true))
 local fn=assert(loadstring(s:sub(a,b-1)));setfenv(fn,setmetatable(env,{__index=_G}));fn()
end
local current={visible=true,species=95,rig={}}
local actor={schema='voxel-ascendant/actor-render/v1',side='player',battler={},mon={},view='stadium-model',modelKey='stadium:95',textureToken=current.rig}
local texture={vascRenderBattler=actor.battler,vascRenderMon=actor.mon,vascRenderModelKey='sprite:95',vascRenderTextureToken={},vascSpriteView='front'}
local session={player=current,at={player=actor.battler}};actor.battler.mon=actor.mon
local Stadium={}
extract('gen2/lib/Stadium.lua','function Stadium.matchesVisualReceipt','function Stadium.presentationMatrices',{Stadium=Stadium,session=session})
local env={V={require=function()return Stadium end}}
local f=assert(io.open('lib/OverworldBattle.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local function actorMatchesTexture',1,true));local b=assert(s:find('local function shotMatchesTextures',a,true))
local fn=assert(loadstring(s:sub(a,b-1)..'return actorMatchesTexture'));setfenv(fn,setmetatable(env,{__index=_G}));local matches=fn()
assert(matches(actor,texture),'live 3D model mistaken for sprite replacement')
assert(matches(actor,nil),'covered model incorrectly requires a sprite')
local rig=current.rig;current.rig={};assert(not matches(actor,texture),'old rig accepted');current.rig=rig
current.species=10;assert(not matches(actor,texture),'old species accepted');current.species=95
texture.vascRenderMon={};assert(not matches(actor,texture),'old semantic owner accepted');texture.vascRenderMon=actor.mon
actor.view='front';actor.modelKey=texture.vascRenderModelKey;actor.textureToken=texture.vascRenderTextureToken
assert(matches(actor,texture),'sprite animation regressed')
texture.vascRenderTextureToken={};assert(not matches(actor,texture),'stale sprite token accepted')
local session={player={model={},scale=1,yaw=7},enemy={model={},scale=.5,yaw=8}}
for _,m in pairs(session)do m.matrix=function(self,x,y,z,dx,dz)self.yaw=99;return{x,y,z,dx,dz,self.scale}end end
local Stadium={}
extract('gen2/lib/Stadium.lua','function Stadium.presentationMatrices','function Stadium.draw(',{Stadium=Stadium,session=session})
local layout={player={10,2,30},enemy={50,4,60},actorScale={player=2,enemy=1}}
local matrices=Stadium.presentationMatrices(layout)
assert(matrices.player[1]==10 and matrices.player[2]==2 and matrices.player[4]==40 and matrices.player[6]==2,'resolver/facing/scale not applied')
assert(session.player.yaw==7 and session.enemy.yaw==8 and not session.player.model_matrix,'candidate query mutated live model')
Stadium.commitPresentation(layout);assert(session.player.model_matrix[3]==30 and session.enemy.model_matrix[1]==50,'render did not commit resolver coordinates')
print('Stadium scene ownership and placement: ok')

local rig={projectedBounds=function()return 10,20,30,40,-99,-99,-99,99,99,99 end}
local owner={mon={}}
local env={Stadium={},Mat4={mul=function()return{}end},session={player={visible=true,rig=rig,model_matrix={},species=95},at={player=owner}},projectPosedBounds=function()return{-900,-900,1800,1800}end}
extract('gen2/lib/Stadium.lua','local function receiptAnchors','-- How wide the Pokemon',env)
local receipt=env.Stadium.visualReceipt('player',{},960,600,7)
assert(receipt.hull[1]==10 and receipt.hull[2]==20 and receipt.hull[3]==30 and receipt.hull[4]==40,'empty AABB corners counted as visible body')
assert(receipt.battler==owner and receipt.mon==owner.mon,'geometry update changed semantic owner')
print('Stadium exact visible bounds: ok')
