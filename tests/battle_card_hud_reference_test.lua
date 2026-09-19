local root=assert(arg[1])
local f=assert(io.open(root..'/lib/BattleScene.lua'));local s=f:read('*a');f:close()
local a=assert(s:find('local hudCardPoses=',1,true))
local b=assert(s:find('\nactorVisualsFor = function',a,true))
local Mat4=dofile(root..'/lib/Mat4.lua')
local Scene={CELL=16}
local layout={player={0,0,0},enemy={1,0,0},actorScale={player=1,enemy=1},profileObject={},flipX={}}
Scene.presentationLayout=function()return layout end
Scene.presentationMetrics=function(tex)return tex.metrics end
Scene.textureFlipX=function()return false end
local env=setmetatable({BattleScene=Scene,Mat4=Mat4,Voxel3D={eye={0,0,1}},
  BattleBillboard={yawToward=function()return 0 end},
  monMatrix=function()return Mat4.identity()end,
  V={require=function(n)
    if n=='VoxelBattleStage' then return {presentationScale=function()return 1 end}end
    if n=='BattleHeroesBridge' then return {append=function()end}end
    error(n)
  end},
},{__index=_G})
local fn=assert(loadstring(s:sub(a,b-1)..'\nreturn actorVisualForCard'))
setfenv(fn,env);local receipt=fn()
local tex={canvas={},vascRenderBattler={},vascRenderMon={},vascRenderModelKey='flier|front',
  metrics={canvasWidth=100,canvasHeight=100,inkX0=20,inkX1=79,inkY0=10,inkY1=89,
    anchorX=50,baseline=90,scale=.01,combinedScale=1}}
local arena={player={},enemy={}}
local I=Mat4.identity();I[6]=-1
local function visual()
  return receipt(Scene.monCards(arena,0,{player=tex},nil,I,{0,0,1},true)[1],I,1000,600,1)
end
local first=visual();assert(first.hudHead)
for frame=1,30 do
  tex.metrics.inkY0=10+frame;tex.metrics.inkX0=20+frame
  tex.canvas={} -- animation frame canvases do not replace the battler
  local v=visual()
  assert(v.hudHead.x==first.hudHead.x and v.hudHead.y==first.hudHead.y,'card HUD followed ink')
  assert(v.head.y~=first.head.y,'live card hull frozen')
end
I[4]=.1;local camera=visual();assert(camera.hudHead.x~=first.hudHead.x)
tex.vascRenderMon={};local replaced=visual()
assert(replaced.hudHead.y~=camera.hudHead.y,'switch reused old reference')
tex.vascRenderModelKey='flier|mega';tex.metrics.inkY0=1
assert(visual().hudHead.y~=replaced.hudHead.y,'form change reused old reference')
print('PASS_CARD_HUD_REFERENCE: animated ink, frame canvas, camera, switch and form')
