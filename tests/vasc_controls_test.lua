local root=arg[1]or'.'
local keys,presses,releases,touches={}, {}, {},0
local world={};local stack={states={world}}
function stack:top()return self.states[#self.states]end
function stack:push(s)self.states[#self.states+1]=s end
function stack:pop()return table.remove(self.states)end
local game={stack=stack,save={},overworld=world,touchControls={reset=function()end,noteGamepad=function()end}}
function game:keypressed(k)keys[#keys+1]=k end
function game:draw()return 1,nil,3 end
function game:gamepadpressed(j,b)presses[#presses+1]={j,b}end
function game:gamepadreleased(j,b)releases[#releases+1]={j,b}end
function game:touchpressed()touches=touches+1 end
function game:touchmoved()touches=touches+1 end
function game:touchreleased()touches=touches+1 end
function game:cancelPointers()end
local w,h,inset=800,600,0
local graphics=setmetatable({getDimensions=function()return w,h end,newFont=function()return{getWidth=function(_,s)return #s*6 end}end},{__index=function()return function()end end})
love={graphics=graphics,system={getOS=function()return'Desktop'end}}
package.loaded['src.core.Game']=game
package.loaded['src.core.SafeArea']={windowRect=function()return inset,inset,w-inset*2,h-inset*2 end}
local function setting(value)return{get=function()return value end,setValue=function(_,v,g)assert(g==game);value=v end}end
local overlay={enabled=setting(false),fps=setting(false),cpu=setting(false)}
local hooks={}
local V={PerformanceOverlay=overlay,require=function(id)
 if id=='VascQuickOptions'then return{rows=function()return{}end}end
 if id=='AppearanceShortcuts'then return{settings={}}end
 if id=='OverworldBattle'then return{shot=function()return nil end}end
 assert(id=='ShortcutToast');return{notify=function()end}end,
 mod={hooks={wrap=function(_,id,fn)hooks[id]=fn end}}}
local baseRequire=V.require
local M=assert(loadfile(root..'/lib/VascControls.lua'))(V);M.install({});M.install({})
local clock=0;love.timer={getTime=function()return clock end}
world.map={id='PALLET_TOWN'}
assert(M.hintAlpha(game)==0);clock=.2;assert(M.hintAlpha(game)==1)
stack:push({ascendantContentInventory=true});assert(M.hintAlpha(game)==0,'hint covered download menu');stack:pop();assert(M.hintAlpha(game)==1)
clock=2.25;assert(M.hintAlpha(game)==.5);clock=2.5;assert(M.hintAlpha(game)==0)
world.map={id='PALLET_TOWN'};clock=3;assert(M.hintAlpha(game)==0,'same map object rebuild flashed hint')
world.map={id='ROUTE_1'};assert(M.hintAlpha(game)==0);clock=3.2;assert(M.hintAlpha(game)==1)
clock=6;assert(M.hintAlpha(game)==0)
local battle={player={},enemy={},data={},phase='intro'};stack:push(battle)
assert(M.hintAlpha(game)==0);clock=6.2;assert(M.hintAlpha(game)==1)
stack:push({dialogue=true});assert(M.hintAlpha(game)==0,'hint covered battle dialog');stack:pop();assert(M.hintAlpha(game)==1)
battle.phase='menu';clock=9;assert(M.hintAlpha(game)==0,'battle phase flashed hint again')
stack:pop();assert(M.hintAlpha(game)==0,'battle end flashed hint')
game.touchControls.active=true;assert(M.mobile(game),'engine touch mode ignored');game.touchControls.active=false
game:keypressed('f4');assert(overlay.enabled:get()and overlay.fps:get()and not overlay.cpu:get())
game:keypressed('f4');assert(not overlay.enabled:get()and overlay.fps:get())
game:keypressed('f1');game:keypressed('f2');assert(keys[1]=='f1'and keys[2]=='f2','save/load stolen')
local pad1,pad2={},{}
game:gamepadpressed(pad1,'rightshoulder');assert(#presses==0)
game:gamepadpressed(pad1,'dpdown');assert(overlay.enabled:get()and #presses==0,'chord also changed speed/moved')
game:gamepadpressed(pad1,'dpdown');assert(overlay.enabled:get(),'duplicate down toggled twice')
game:gamepadreleased(pad1,'rightshoulder');game:gamepadreleased(pad1,'dpdown');assert(#presses==0)
game:gamepadpressed(pad1,'rightshoulder');game:gamepadreleased(pad1,'rightshoulder');assert(#presses==1 and presses[1][2]=='rightshoulder','R1-alone lost')
game:gamepadpressed(pad1,'rightshoulder');game:gamepadpressed(pad2,'dpleft');assert(#presses==2,'cross-controller chord')
game:gamepadpressed(pad1,'dpleft');assert(keys[#keys]=='f6')
game:gamepadreleased(pad1,'dpleft');game:gamepadreleased(pad1,'rightshoulder')
game:gamepadpressed(pad1,'rightshoulder');game:gamepadpressed(pad1,'start');assert(M.current(game),'controller help missing')
game:gamepadreleased(pad1,'start');game:gamepadreleased(pad1,'rightshoulder');assert(#presses==2)
local panel=M.current(game);game:keypressed('down');assert(panel.selected==2)
game:gamepadpressed(pad1,'a');assert(keys[#keys]=='0'and M.current(game),'controller selection did not invoke live owner')
game:gamepadreleased(pad1,'a');game:gamepadpressed(pad1,'b');game:gamepadreleased(pad1,'b');assert(stack:top()==world)
-- Native text/capture screens retain every key and pad binding.
local capture={onKeyPressed=function()end,onGamepadPressed=function()end};stack:push(capture)
local n=#presses;game:gamepadpressed(pad1,'rightshoulder');assert(#presses==n+1)
game:keypressed('f3');game:keypressed('f4');assert(stack:top()==capture and keys[#keys]=='f4')
stack:pop()
-- A modifier interrupted by focus loss must not fire a delayed speed change.
game:gamepadpressed(pad1,'rightshoulder');game:cancelPointers();n=#presses
game:gamepadreleased(pad1,'rightshoulder');assert(#presses==n)
-- Narrow phones, rotated landscapes and safe-area insets: targets stay usable.
love.system.getOS=function()return'Android'end
for _,size in ipairs({{390,844,12},{844,390,20},{320,568,0},{1280,800,0}})do
 w,h,inset=size[1],size[2],size[3]
 game:draw();local r=M.paint.layout.launcher
 assert(r[3]==48 and r[4]==48,'compact marker must keep a generous touch target')
 game:touchpressed('finger',r[1]+5,r[2]+5);assert(M.current(game));game:touchreleased('finger',0,0)
 assert(touches==0,'launcher leaked to virtual pad')
 local panel=M.current(game)
 for index=1,#panel.rows do
  panel.selected=index;game:draw();local t=M.paint.layout
  for _,entry in ipairs(t.rows)do
  local r=entry.rect
   assert(r[3]>=260 and r[4]>=48 and r[1]>=inset and r[2]>=inset and r[1]+r[3]<=w-inset and r[2]+r[4]<=h-inset,'unsafe or tiny mobile target')
  end
 end
 game:draw();local r=M.paint.layout.close
 game:touchpressed('close',r[1]+5,r[2]+5);assert(not M.current(game));game:touchmoved('close',0,0);game:touchreleased('close',0,0)
 assert(touches==0,'closing contact clicked underlying gameplay')
end
-- Reserved top-left message band ends at y=72. Hint and hidden touch target
-- stay below it even on narrow desktops; no permanent three-button strip.
for _,size in ipairs({{320,568},{640,360},{800,600},{1280,800}})do
 w,h,inset=size[1],size[2],0
 local r=M.layout(game).launcher
 assert(r[2]>=82 and r[2]>=18+54+10,'help overlaps shortcut notification')
 clock=100;game:draw();assert(M.hintAlpha(game)==0)
 assert(M.pointer(game,{phase='pressed',source='touch',x=r[1]+4,y=r[2]+4}),'faded mobile help unreachable')
 M.close(game)
end
-- Rebuild hit regions after rotation: old coordinates cannot activate a row.
game:keypressed('f3');game:draw();w=w+10
assert(M.pointer(game,{phase='pressed',source='mouse',x=40,y=40,button=1})and M.current(game))
game:keypressed('escape');assert(stack:top()==world)
local a,b,c=game:draw();assert(a==1 and b==nil and c==3,'draw return values changed')
print('PASS VASC controls: FPS owner, F1/F2 retained, per-pad chords, deferred R1, no repeat/spill, text capture, focus reset, modal touch ownership, phone portrait/landscape and safe-area bounds')
-- Language follows Universal's active language in both contexts, including
-- when it changes while the panel is already open. OS/HUD choices are irrelevant.
local printed={};graphics.print=function(s)printed[#printed+1]=s end
local function has(s)for _,text in ipairs(printed)do if text==s then return true end end;return false end
local deTitles={'Pokémon-Sprites','Personen','Begleiter','FPS / Framezeit','Kampfansicht','Kameraansicht','Voxel-Raster','Tiefenunschärfe','Weltkrümmung','Wasser','Näher heran','Weiter heraus'}
w,h,inset=1280,800,0
for _,context in ipairs({world,battle})do
 if context==battle then stack:push(battle)end
 assert(M.open(game))
 for _,mode in ipairs({'absent','de','en','no-export','error'})do
  local handle=mode=='no-export'and{}or{exports={bootLanguage=mode}}
  V.mod.find=function(id)
   if mode=='error'then error('unavailable')end
   if id=='translation-german-universal'and mode~='absent'then return handle end
  end
  local de=mode=='de';assert(M.language()==(de and'de'or'en'))
  for index,row in ipairs(M.current(game).rows)do
   M.current(game).selected=index;printed={};M.draw(game)
   assert(has(de and'VASC · Schnellmenü'or'VASC · Quick menu'),'wrong heading')
   assert(has(M.mobile(game)and(de and'Zeile antippen zum Ändern · ×: schließen'or'Tap a row to change · ×: close')or(de and'↑ / ↓: wählen · Enter / A: ändern · Esc / B: zurück'or'↑ / ↓: select · Enter / A: change · Esc / B: back')))
   local title=de and row.titleDe or row.title
   if row.key=='f4' then assert(has(overlay.enabled:get()and(de and'AN'or'ON')or(de and'AUS'or'OFF')))end
   assert(has(title),'wrong row language: '..index..'/'..mode)
   if not de then assert(M.mobile(game)and has(row.submenu and'Tap to open'or'Tap to change')or(has(row.detail)and has(row.hint)),'English interaction help missing')end
  end
 end
 M.close(game)
 -- Test method-style mod finder plus mobile and desktop launchers.
 local handle={exports={bootLanguage='de'}}
 V.mod.find=function(self,id)assert(self==V.mod);if id=='translation-german-universal'then return handle end end
 for _,mobile in ipairs({false,true})do
  love.system.getOS=function()return mobile and'Android'or'Desktop'end
  for _,lang in ipairs({'de','en'})do
   handle.exports.bootLanguage=lang;M.hintAlpha=function()return 1 end
   printed={};M.draw(game)
   assert(has(mobile and'V'or(lang=='de'and'F3 · VASC-Hilfe'or'F3 · VASC Help')))
   if mobile then assert(not has('Tap this corner')and not has('Diese Ecke antippen'))end
   local notification;V.require=function(id)if id~='ShortcutToast'then return baseRequire(id)end;return{notify=function(a,b)notification={a,b}end}end
   M.fps(game);assert(notification[1]==(lang=='de'and'[F4] FPS / FRAMEZEIT'or'[F4] FPS / FRAME TIME'))
   assert(notification[2]==(overlay.enabled:get()and(lang=='de'and'AN'or'ON')or(lang=='de'and'AUS'or'OFF')))
  end
 end
 if context==battle then stack:pop()end
end
print('PASS help language: world/battle, all rows, live Universal DE/EN, absent/invalid finder, mobile/desktop hints and FPS notifications')

-- Touch activates the same live setting as keyboard/controller and updates
-- the status without closing the panel or clicking the world underneath.
V.mod.find=nil;love.system.getOS=function()return'iOS'end
w,h,inset=390,844,12
assert(M.open(game));local fpsIndex
for i,r in ipairs(M.current(game).rows)do if r.key=="f4"then fpsIndex=i end end
assert(fpsIndex);M.current(game).selected=fpsIndex;M.draw(game)
local before=overlay.enabled:get();local row
for _,r in ipairs(M.paint.layout.rows)do if r.index==fpsIndex then row=r end end
assert(row)
game:touchpressed('toggle',row.rect[1]+20,row.rect[2]+20)
game:touchreleased('toggle',0,0)
assert(overlay.enabled:get()~=before and M.current(game))
assert(M.status(game,fpsIndex)==(overlay.enabled:get()and'ON'or'OFF'))
assert(touches==0,'menu contact leaked')
M.close(game)
print('PASS iOS direct touch: actual setting toggled, live status, panel stays open, no gameplay touch leak')

-- Terrarium orientation is reachable from the V/F3 panel in both contexts,
-- and uses the existing boolean preference through the real setting owner.
local Setting=assert(loadfile(root..'/lib/ModSetting.lua'))(V)
local camera=Setting.new('terarriumBehindRed','BATTLE ORIENTATION',{false,true},{'SIDE','BEHIND TRAINER'},false)
local prior=V.require
V.require=function(id)
 if id=='IntegratedTerarrium'then return{entries=function()return{{camera,'Arrange both teams.'}}end}end
 return prior(id)
end
game.save.options={}
for _,context in ipairs({world,battle})do
 if context==battle then stack:push(battle)end
 assert(M.open(game));local submenu
 for i,r in ipairs(M.current(game).rows)do if r.id=='terrarium'then submenu=i end end
 assert(submenu);M.activate(game,submenu)
 local row=assert(M.current(game).rows[1]);assert(row.id=='terarriumBehindRed')
 assert(row.status(false)=='SIDE'and row.status(true)=='SEITLICH')
 M.activate(game,1)
 assert(M.current(game).group=='terrarium'and camera:get()==true)
 assert(game.save.options.modOptions.VOXEL_ASCENDANT.terarriumBehindRed==true)
 assert(row.status(false)=='BEHIND TRAINER'and row.status(true)=='HINTER TRAINER')
 M.activate(game,1);assert(camera:get()==false);M.close(game)
 if context==battle then stack:pop()end
end
print('PASS Terrarium quick menu: world/battle, persisted orientation, DE/EN values, submenu retained')
