local function extract(path, first, last, env, extra)
  local f=assert(io.open(path));local source=f:read('*a');f:close()
  local a=assert(source:find(first,1,true));local b=assert(source:find(last,a+#first,true))
  local fn=assert(loadstring(source:sub(a,b-1)..(extra or '')))
  setfenv(fn,setmetatable(env,{__index=_G}));return fn()
end
local values={}
local function read(key, fallback) local v=values[key];if v==nil then return fallback end;return v end
local F,M={},{}
extract('battle_hud_oras.lua','function FloatingHud.configureControls','function FloatingHud.screenDockRect',
  {FloatingHud=F,optionChoice=read})
extract('gen2/lib/BattleControllerUI.lua','function M.configureControls','local function commandDockRect',
  {M=M,optionValue=function(_,...)return read(...)end})
extract('battle_hud_oras.lua','function FloatingHud.roundControls','function FloatingHud.drawGlassControl',
  {FloatingHud=F,optionChoice=read})
for _, viewport in ipairs({{390,844},{844,390},{1024,768},{2048,1536}}) do
  local ww,wh=unpack(viewport)
  local rect={ww*.1,wh*.7,ww*.8,wh*.3}
  values={}
  assert(not F.roundControls())
  for _,api in ipairs({F,M}) do
    local got,s=api.configureControls(ww,wh,rect,2,300,156)
    assert(got==rect and s==2,'default must preserve exact authored rectangle')
  end
  for _,size in ipairs({.5,.75,1,1.5})do
    for _,x in ipairs({-40,0,40})do
      for _,y in ipairs({0,25,60})do
        values={battle_controls_scale=size,battle_controls_x=x,battle_controls_y=y}
        local a,s=F.configureControls(ww,wh,rect,2,300,156)
        local b,t=M.configureControls(ww,wh,rect,2,300,156)
        for i=1,4 do assert(math.abs(a[i]-b[i])<1e-8,'generation parity')end
        assert(s==t and math.abs(a[3]/a[4]-rect[3]/rect[4])<1e-8,'proportions')
        assert(a[1]>=0 and a[2]>=0 and a[1]+a[3]<=ww+1e-8 and a[2]+a[4]<=wh+1e-8,'screen bounds')
        assert(F.roundControls()==(size~=1 or x~=0 or y~=0),'auto round')
      end
    end
  end
end
values={battle_controls_y=25,battle_controls_shape='original'};assert(not F.roundControls())
values={battle_controls_shape='round'};assert(F.roundControls())
values={battle_controls_shape='glass',battle_controls_y=25};assert(not F.roundControls(),'glass is explicit alternative')
values={};assert(not F.roundControls(),'reset restores original')
local size={800,600}
local queued={}
local enabled=true
M.owns=function()return enabled end
extract('gen2/lib/BattleControllerUI.lua','M.controlPaint =','function M.install(game)',{
  M=M,love={graphics={getDimensions=function()return unpack(size)end}},
  overlayFor=function()return nil end,commandInputReady=function()return true end,
  playerMoves=function()return {1,2,3,4}end,
  queueNativeConfirm=function(_,key)queued[#queued+1]=key or 'a';return true end,
})
local screen={phase='menu',menuIndex=1}
local function publish(action,index)
 screen._vascControlHits={}
 M.recordControl(screen,{100,200},2,10,20,30,40,action,index)
 M.controlPaint[screen]={hits=screen._vascControlHits,phase=screen.phase,ww=800,wh=600}
end
publish('command',3)
assert(not M.pressControls(screen,119,240),'outside must pass through')
assert(M.pressControls(screen,130,260) and screen.menuIndex==3 and queued[1]=='a')
assert(not M.pressControls(screen,130,260),'same paint cannot activate twice')
screen.phase='moves';publish('move',4)
assert(M.pressControls(screen,130,260) and screen.moveIndex==4 and queued[2]=='a')
publish('back');assert(M.pressControls(screen,130,260) and queued[3]=='b')
publish('move',2);screen.message='waiting';assert(not M.pressControls(screen,130,260));screen.message=nil
size={600,800};assert(not M.pressControls(screen,130,260),'rotation retires paint');size={800,600}
enabled=false;assert(not M.pressControls(screen,130,260),'native UI must retain input');enabled=true
screen.phase='menu';assert(not M.pressControls(screen,130,260),'phase changed since paint')
local schema=assert(loadfile('gen2/options.lua'))();local defaults={}
for _,spec in ipairs(schema)do defaults[spec.key]=spec.default end
assert(defaults.battle_controls_scale==1 and defaults.battle_controls_x==0
 and defaults.battle_controls_y==0 and defaults.battle_controls_shape=='auto')
print('PASS controls: exact defaults, viewport matrix, round mode, touch moves/back, ownership, resize, duplicate taps')
local resetMenu={}
local settings={}
for key,default in pairs({battle_controls_scale=1,battle_controls_x=0,
 battle_controls_y=0,battle_controls_shape='auto',battle_controls_transparency=0,player_hud_x=40})do
 settings[#settings+1]={{key=key,values={default},defaultIndex=1,current='custom',
  setValue=function(self,v)self.current=v end}}
end
extract('lib/VascMenu.lua','function VascMenu.resetBattleControls','local function sectionRows',
 {VascMenu=resetMenu,config={settings=settings}})
resetMenu.resetBattleControls({})
for _,entry in ipairs(settings)do
 local setting=entry[1]
 assert(setting.current==(setting.key=='player_hud_x' and 'custom' or setting.values[1]),'reset scope')
end
print('PASS button reset preserves existing status/card settings')
extract('battle_hud_oras.lua','function FloatingHud.controlsOpacity','local function drawPerspectiveCanvas',
 {FloatingHud=F,optionChoice=read})
extract('gen2/lib/BattleControllerUI.lua','function M.controlsOpacity','function M.drawFull',
 {M=M,optionValue=function(_,...)return read(...)end})
for _,case in ipairs({{nil,1},{0,1},{40,.6},{70,.3},{90,.1},{100,.1},{-20,1},{'40',.6},{'bad',1},{0/0,1}})do
 values={battle_controls_transparency=case[1]}
 assert(math.abs(F.controlsOpacity()-case[2])<1e-8,'Gen1 opacity')
 assert(math.abs(M.controlsOpacity({})-case[2])<1e-8,'Gen2 opacity')
end
values={}
local receipt={1,2,3,4}
assert(M.drawControlsWithOpacity({},800,600,function()return receipt end)==receipt,
 'default must bypass the extra render pass and preserve the input rectangle')
assert(defaults.battle_controls_transparency==0,'default is unchanged')
print('PASS transparency defaults, limits, invalid values and generation parity')

local drawnAlpha
local drawPlane=extract('battle_hud_oras.lua','function FloatingHud.controlsOpacity','local function drawCard',{
 FloatingHud=F,optionChoice=read,cardMeshes={},
 rotatedPoint=function(x,y)return x,y end,
 clamp=function(v,a,b)return math.max(a,math.min(b,v))end,
 g={newMesh=function()return {setVertexMap=function()end,setVertices=function()end,setTexture=function()end}end,
 setColor=function(_,_,_,a)drawnAlpha=a end,draw=function()end},
},'\nreturn drawPerspectiveCanvas')
values={battle_controls_transparency=70}
for _,side in ipairs({'command','fight','learn','player','enemy','message'})do
 drawPlane({},50,50,100,100,0,0,side)
 local expected=(side=='command' or side=='fight' or side=='learn') and .3 or 1
 assert(math.abs(drawnAlpha-expected)<1e-8,'transparency scope: '..side)
end
print('PASS real Gen1 compositor fades only controls; status cards and messages remain unchanged')

extract('battle_hud_oras.lua','function FloatingHud.positionTextbox','function HudRuntime.messageRectFor',
 {FloatingHud=F,optionChoice=read})
extract('gen2/lib/BattleControllerUI.lua','function M.positionTextbox','local function messageDockRect',
 {M=M,optionValue=function(_,...)return read(...)end})
for _,viewport in ipairs({{390,844},{844,390},{1024,768},{2048,1536}})do
 local w,h=unpack(viewport)
 for _,api in ipairs({F,M})do
  local rect={w*.1,h*.8,w*.8,h*.2,bottomInset=0}
  values={};assert(api.positionTextbox(w,h,rect)==rect and rect[1]==w*.1 and rect[2]==h*.8)
  values={battle_textbox_x=5,battle_textbox_y=-25}
  local moved=api.positionTextbox(w,h,rect)
  assert(math.abs(moved[1]-w*.15)<1e-8 and math.abs(moved[2]-h*.55)<1e-8)
  assert(moved[3]==w*.8 and moved[4]==h*.2 and moved.bottomInset==0)
  for _,x in ipairs({-60,60,999,0/0})do
   values={battle_textbox_x=x,battle_textbox_y=x}
   local pos=api.positionTextbox(w,h,{w*.1,h*.8,w*.8,h*.2})
   assert(pos[1]>=0 and pos[2]>=0 and pos[1]+pos[3]<=w+1e-8 and pos[2]+pos[4]<=h+1e-8)
  end
 end
end
assert(defaults.battle_textbox_x==0 and defaults.battle_textbox_y==0)
for _,path in ipairs({'lib/VascMenu.lua','lib/gen2_a21_shared/VascMenu.lua'})do
 local rows={}
 for _,key in ipairs({'battle_textbox_x','battle_textbox_y','battle_controls_x','player_hud_x'})do
  rows[#rows+1]={{key=key,current=35,values={0},defaultIndex=1,setValue=function(self,v)self.current=v end}}
 end
 local menu={}
 extract(path,'function VascMenu.resetBattleControls','local function sectionRows',{VascMenu=menu,config={settings=rows}})
 menu.resetBattleControls({});assert(rows[1][1].current==35 and rows[2][1].current==35)
 rows[3][1].current=25;menu.resetBattleTextbox({})
 assert(rows[1][1].current==0 and rows[2][1].current==0 and rows[3][1].current==25 and rows[4][1].current==35)
end
print('PASS textbox translation, viewport bounds, exact defaults and independent resets in both generations')
