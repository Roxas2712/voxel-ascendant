local root=assert(os.getenv('VASC_TEST_ROOT'))
local function near(a,b)assert(math.abs(a-b)<1e-7,tostring(a)..' != '..tostring(b))end
for _,prefix in ipairs({'','gen2/'})do
 local P=assert(loadfile(root..'/'..prefix..'lib/VascBattleAnimPlayer.lua'))({})
 for _,points in ipairs({{{20,90},{140,50}},{{80,115},{80,25}},{{145,55},{30,100}}})do
  local a,b=points[1],points[2]
  P.setFrameAnchors({player={emitter=a,body=a},enemy={emitter=b,body=b}})
  for _,side in ipairs({true,false})do
   local from,to=side and a or b,side and b or a
   local x,y=P.mapPoint({x=128,y=224,f=3},side);near(x,from[1]);near(y,from[2])
   x,y=P.mapPoint({x=384,y=96,f=3},side);near(x,to[1]);near(y,to[2])
   -- A cel aligned with the authored attack axis follows the actual target.
   local angle=P.mapAngle({f=3,a=math.deg(math.atan2(-128,256))},side)
   local dx,dy=to[1]-from[1],to[2]-from[2];local d=math.sqrt(dx*dx+dy*dy)
   near(math.cos(angle),dx/d);near(math.sin(angle),dy/d)
   near(P.mapAngle({f=4,a=19},side),math.rad(19))
  end
 end
 P.clearFrameAnchors();near(P.mapAngle({f=3,a=19},true),math.rad(19))
 if prefix==''then
  local frame={player={body={80,110},emitter={80,100}},enemy={body={80,20},emitter={80,10}}}
  local original={player={26,96},enemy={124,56}}
  for _,side in ipairs({true,false})do
   local t=P.nativeProjection(frame,original,side);assert(t)
   for _,team in ipairs({'player','enemy'})do
    local a=original[team];local x,y=a[1]-75,a[2]-76
    local expected=frame[team][((team=='player')==side)and'emitter'or'body']
    near(t.x+(x*math.cos(t.angle)-y*math.sin(t.angle))*t.scale,expected[1])
    near(t.y+(x*math.sin(t.angle)+y*math.cos(t.angle))*t.scale,expected[2])
   end
  end
  for _,size in ipairs({{1100,700},{480,900}})do
   local shot={scale=3,lx=10,ly=20,actorVisuals={player={hull={100,400,60,100}},enemy={hull={200,100,40,80}}}}
   local cx,cy,ax,ay,k=70,60,75,76,.5
   local a=P.projectedAnchors(shot,cx,cy,ax,ay,k);assert(a)
   for _,side in ipairs({'player','enemy'})do
    for kind,f in pairs({emitter=.28,body=.55})do
     local p=a[side][kind];local h=shot.actorVisuals[side].hull
     near(((p[1]-ax)*k+cx)*shot.scale+shot.lx,h[1]+h[3]*.5)
     near(((p[2]-ay)*k+cy)*shot.scale+shot.ly,h[2]+h[4]*f)
    end
   end
  end
 end
end
-- A stale side-facing presentation must be corrected by the arena actually drawn.
local board={yawToward=function()return 0 end,matrix=function(...)return {...}end}
local V={require=function(name)if name=='BattleBillboard'then return board end;return {}end}
local B=assert(loadfile(root..'/lib/BattleHeroesBridge.lua'))(V)
local hero={canvas={},width=12,height=25,view='side'}
hero.setView=function(v,f)hero.view=v;hero.facing=f;return hero end
local enemy={canvas={},width=12,height=25,view='side'}
enemy.setView=function(v,f)enemy.view=v;enemy.facing=f;return enemy end
local arena={terarrium={cameraMode='behind'},terarriumService={trainerFoot=function(_,side,y)return{side=='player'and -19 or 19,y,side=='player'and 46 or -40}end}}
local textures={battleHeroes={player=hero,enemy=enemy}}
local layout={player={0,0,20},enemy={0,0,-20},actorScale={player=1,enemy=1}}
B.append({},textures,layout,{0,157,205},nil,arena)
assert(hero.view=='terarrium-back'and enemy.view=='terarrium-front')
arena.terarrium.cameraMode='side';B.append({},textures,layout,{0,157,205},nil,arena)
assert(hero.view=='side'and enemy.view=='side')
print('PASS_TERRARIUM_ATTACK_AND_TRAINER_ALIGNMENT')
