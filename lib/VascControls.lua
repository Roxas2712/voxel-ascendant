-- Keyboard, controller and touch share the existing setting/shortcut owners.
-- The panel is a stack state: the world/battle pauses while choosing an action.
local V=...
local M={HELP_KEY="f3",FPS_KEY="f4"}
local Game=require("src.core.Game")
local unpack=table.unpack or unpack
local function pack(...)return{n=select("#",...),...}end
local function top(g)return g and g.stack and g.stack:top()end
local function ready(g)
  local t=top(g)
  return g and g.save and g.overworld and t and not t.onKeyPressed
    and not t.onGamepadPressed and not t.imeActive
end
-- Follow the Universal translation's active boot language, never the OS,
-- ROM, or a separately saved battle-HUD language preference.
function M.language()
  local mod=V and V.mod
  if not (mod and type(mod.find)=="function")then return "en"end
  local ok,handle=pcall(mod.find,"translation-german-universal")
  if not ok or not handle then ok,handle=pcall(mod.find,mod,"translation-german-universal")end
  local exports=ok and type(handle)=="table" and handle.exports
  return type(exports)=="table" and exports.bootLanguage=="de" and "de"or"en"
end
local function toast(a,b)V.require("ShortcutToast").notify(a,b)end
local hints=setmetatable({},{__mode="k"})
local function now()return love and love.timer and love.timer.getTime and love.timer.getTime()or 0 end
function M.hintAlpha(g)
  local b
  for _,s in ipairs(g.stack and g.stack.states or{})do
    if s.player and s.enemy and s.data and s.phase then b=s end
  end
  local map=g.overworld and g.overworld.map
  local id=map and(map.id or map)or g.overworld
  local s=hints[g];local t=now()
  if not s then s={map=id,battle=b,started=t};hints[g]=s
  else
    if id~=s.map or(b and b~=s.battle)then s.started=t end
    s.map=id;s.battle=b
  end
  -- Menus, dialogue and fades cover the scene: never paint the arrival hint
  -- over their own controls. Context tracking above still consumes its timer.
  if top(g) ~= g.overworld and top(g) ~= b then return 0 end
  local age=t-s.started
  if age<0 or age>=2.5 then return 0 end
  return math.max(0,math.min(1,age/.15,(2.5-age)/.5))
end
function M.mobile(g)
  -- Use the engine's platform decision; mods cannot read environment variables
  -- in every host sandbox. This also honours the desktop touch-test mode.
  if g and g.touchControls and g.touchControls.active then return true end
  if os and os.getenv and os.getenv("POKEPORT_TOUCH")=="1"then return true end
  local osName=love and love.system and love.system.getOS and love.system.getOS()
  return osName=="Android"or osName=="iOS"
end
function M.fps(g)
  if not ready(g)then return false end
  local hud=V.PerformanceOverlay or V.require("PerformanceOverlay")
  local on=not hud.enabled:get()
  if on then hud.fps:setValue(true,g)end
  hud.enabled:setValue(on,g)
  local de=M.language()=="de"
  toast(de and "[F4] FPS / FRAMEZEIT"or"[F4] FPS / FRAME TIME",
    on and (de and "AN"or"ON")or(de and "AUS"or"OFF"))
  return true
end
local germanRows={
  {key="0",title="Pokémon-Sprites",hint="0 · R1 + oben",detail="Im Kampf wechseln, sonst Sprite-Auswahl öffnen."},
  {key="f6",title="Personen",hint="F6 · R1 + links",detail="HD und Original-2D umschalten."},
  {key="f7",title="Begleiter",hint="F7 · R1 + rechts",detail="Verfügbare Begleiter-Sprites wechseln."},
  {key="f4",title="FPS / Framezeit",hint="F4 · R1 + unten",detail="Leistungsanzeige ein- oder ausblenden."},
  {key="8",title="Kampfansicht",hint="8",detail="MAP, Arena, Discs und Terrarium durchschalten."},
  {key="v",title="Kameraansicht",hint="V / 3 · R2",detail="Verfügbare Voxel-Kamerastufen wechseln."},
  {key="5",title="Voxel-Raster",hint="5",detail="Darstellung des Voxel-Rasters ändern."},
  {key="6",title="Tiefenunschärfe",hint="6",detail="Tiltshift-Darstellung wechseln."},
  {key="7",title="Weltkrümmung",hint="7",detail="Krümmung der Voxel-Welt ändern."},
  {key="9",title="Wasser",hint="9",detail="Wasserdarstellung wechseln."},
  {key="q",title="Näher heran",hint="Q",detail="Aktuelle Kamera heranzoomen."},
  {key="e",title="Weiter heraus",hint="E",detail="Aktuelle Kamera herauszoomen."},
}
M.rows={
  {key="0",title="Pokémon sprites",hint="0 · R1 + up",detail="Switch in battle; otherwise open sprite selection."},
  {key="f6",title="Characters",hint="F6 · R1 + left",detail="Switch between HD and original 2D."},
  {key="f7",title="Follower",hint="F7 · R1 + right",detail="Cycle through available follower sprites."},
  {key="f4",title="FPS / Frame time",hint="F4 · R1 + down",detail="Show or hide performance statistics."},
  {key="8",title="Battle view",hint="8",detail="Cycle MAP, Arena, Discs and Terrarium."},
  {key="v",title="Camera view",hint="V / 3 · R2",detail="Cycle through available voxel camera modes."},
  {key="5",title="Voxel grid",hint="5",detail="Change the voxel grid display."},
  {key="6",title="Depth of field",hint="6",detail="Change the tilt-shift effect."},
  {key="7",title="World curvature",hint="7",detail="Change the curvature of the voxel world."},
  {key="9",title="Water",hint="9",detail="Change the water display."},
  {key="q",title="Zoom in",hint="Q",detail="Move the current camera closer."},
  {key="e",title="Zoom out",hint="E",detail="Move the current camera further away."},
}
function M.current(g)return top(g)and top(g)._vascControls and top(g)or nil end
function M.close(g)
  if not M.current(g)then return false end
  g.stack:pop();M.paint=nil;return true
end
function M.activate(g,index)
  local panel=M.current(g);local row=M.rows[index]
  if not panel or not row then return false end
  local previous=panel.previous
  M.close(g)
  if top(g)~=previous then return false end
  -- Uncover the actual context before invoking its normal availability gate.
  g:keypressed(row.key)
  if top(g)==previous then M.open(g,index)end
  return true
end
function M.panelKey(g,k)
  local p=M.current(g);if not p then return false end
  if k=="escape"or k==M.HELP_KEY then M.close(g)
  elseif k=="up"then p.selected=(p.selected-2)%#M.rows+1
  elseif k=="down"then p.selected=p.selected%#M.rows+1
  elseif k=="left"or k=="pageup"then p.selected=math.max(1,p.selected-(p.perPage or 6))
  elseif k=="right"or k=="pagedown"then p.selected=math.min(#M.rows,p.selected+(p.perPage or 6))
  elseif k=="return"or k=="space"then M.activate(g,p.selected)
  else for i,row in ipairs(M.rows)do if row.key==k then M.activate(g,i);break end end end
  M.paint=nil
  return true
end
local padKeys={dpup="up",dpdown="down",dpleft="left",dpright="right",a="return",b="escape",start="escape",back="escape"}
function M.open(g,selected)
  if M.current(g)then return true end
  if not ready(g)then return false end
  local p={_vascControls=true,previous=top(g),selected=selected or 1}
  p.onKeyPressed=function(_,k)M.panelKey(g,k)end
  p.onGamepadPressed=function(_,b)M.panelKey(g,padKeys[b])end
  if g.touchControls and g.touchControls.reset then g.touchControls:reset()end
  g.stack:push(p);M.paint=nil
  return true
end
function M.toggle(g)if M.current(g)then return M.close(g)end;return M.open(g)end
local function safeRect()
  return require("src.core.SafeArea").windowRect()
end
local function hit(r,x,y)return x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]end
function M.layout(g)
  local x,y,w,h=safeRect();local p=M.current(g)
  if not p then
    -- The first 72 pixels belong to shortcut receipts and diagnostics. Keep
    -- a stable separate lane below them, including at narrow window widths.
    return{launcher={x+12,y+82,170,48},safe={x,y,w,h}}
  end
  local width=math.min(610,w-16);local perPage=math.max(1,math.min(6,math.floor((h-156)/64)))
  p.perPage=perPage
  local page=math.floor((p.selected-1)/perPage);local pages=math.ceil(#M.rows/perPage)
  local height=perPage*64+144;local px=x+(w-width)/2;local py=y+math.max(4,(h-height)/2)
  local t={safe={x,y,w,h},panel={px,py,width,height},page=page,pages=pages,rows={},
    close={px+width-64,py+8,56,48},prev={px+12,py+height-56,76,48},next={px+width-88,py+height-56,76,48}}
  for i=1,perPage do
    local index=page*perPage+i
    if M.rows[index]then t.rows[#t.rows+1]={index=index,rect={px+12,py+72+(i-1)*64,width-24,58}}end
  end
  return t
end
function M.draw(g)
  M.paint=nil
  local p=M.current(g)
  local de=M.language()=="de"
  local rows=de and germanRows or M.rows
  if not p and not ready(g)then return end
  local hintAlpha=M.hintAlpha(g)
  local t=M.layout(g);local graphics=love.graphics;local ww,hh=graphics.getDimensions()
  if not p and hintAlpha==0 then
    M.paint={screen=top(g),w=ww,h=hh,layout=t};return
  end
  graphics.push("all");graphics.origin();graphics.setCanvas();graphics.setShader();graphics.setScissor();graphics.setBlendMode("alpha")
  M.font=M.font or graphics.newFont(14);M.small=M.small or graphics.newFont(12)
  local function box(r,active)
    graphics.setColor(active and .09 or .025,active and .26 or .075,active and .32 or .10,.97)
    graphics.rectangle("fill",r[1],r[2],r[3],r[4],7,7)
    graphics.setColor(.25,.74,.79,1);graphics.rectangle("line",r[1],r[2],r[3],r[4],7,7)
  end
  local function label(s,x,y,font)graphics.setFont(font or M.font);graphics.setColor(.94,.97,.98,1);graphics.print(s,x,y)end
  if not p then
    -- No permanent HUD control. The same touch target remains reachable after
    -- the short context-change hint fades, without another gesture on A/B.
    if hintAlpha>0 then
      local r=t.launcher
      graphics.setColor(.025,.07,.09,.38*hintAlpha);graphics.rectangle("fill",r[1],r[2],r[3],r[4],7,7)
      graphics.setColor(.85,.95,.97,.75*hintAlpha);graphics.setFont(M.font)
      graphics.print(M.mobile(g)and(de and "VASC · Hilfe"or"VASC · Help")
        or(de and "F3 · VASC-Hilfe"or"F3 · VASC Help"),r[1]+10,r[2]+6)
      graphics.setFont(M.small)
      graphics.print(M.mobile(g)and(de and "Diese Ecke antippen"or"Tap this corner")
        or"Controller: R1 + Start",r[1]+10,r[2]+27)
    end
  else
    graphics.setColor(.015,.025,.035,.87);graphics.rectangle("fill",0,0,ww,hh)
    box(t.panel);local px,py=t.panel[1],t.panel[2]
    label(de and "VASC · Steuerung"or"VASC · Controls",px+14,py+12)
    label(de and "F3 / R1 + Start · A: ändern · B: zurück"
      or"F3 / R1 + Start · A: change · B: back",px+14,py+38,M.small)
    box(t.close);label("×",t.close[1]+21,t.close[2]+12)
    for _,entry in ipairs(t.rows)do
      local r,row=entry.rect,rows[entry.index];box(r,p.selected==entry.index)
      local title=row.title
      if row.key=="f4"then title=title..((V.PerformanceOverlay or V.require("PerformanceOverlay")).enabled:get()and(de and " · AN"or" · ON")or(de and " · AUS"or" · OFF"))end
      label(title,r[1]+10,r[2]+4)
      label(row.hint,r[1]+10,r[2]+23,M.small)
      if M.small:getWidth(row.detail)<=r[3]-20 then label(row.detail,r[1]+10,r[2]+40,M.small)end
    end
    box(t.prev);box(t.next);label("<",t.prev[1]+31,t.prev[2]+14);label(">",t.next[1]+31,t.next[2]+14)
    label((t.page+1).." / "..t.pages,px+t.panel[3]/2-16,t.prev[2]+14)
  end
  graphics.pop();M.paint={screen=top(g),w=ww,h=hh,layout=t}
end
function M.pointer(g,p)
  local panel=M.current(g)
  if not p or(p.source~="touch"and p.source~="mouse")then return false end
  if p.phase~="pressed"then return panel~=nil end
  if p.source=="mouse"and p.button and p.button~=1 then return panel~=nil end
  local paint=M.paint;local w,h=love.graphics.getDimensions()
  if not paint or paint.screen~=top(g)or paint.w~=w or paint.h~=h then return panel~=nil end
  local t=paint.layout
  if not panel then
    if hit(t.launcher,p.x,p.y)then M.toggle(g);return true end
    return false
  end
  if hit(t.close,p.x,p.y)then M.close(g)
  elseif hit(t.prev,p.x,p.y)then M.panelKey(g,"left")
  elseif hit(t.next,p.x,p.y)then M.panelKey(g,"right")
  else for _,r in ipairs(t.rows)do if hit(r.rect,p.x,p.y)then M.activate(g,r.index);break end end end
  return true
end
function M.install(shortcuts)
  if M.installed then return end;M.installed=true
  local key,draw=Game.keypressed,Game.draw
  function Game:keypressed(k,...)
    if M.current(self)then return M.panelKey(self,k)end
    if k==M.HELP_KEY and M.toggle(self)then return end
    if k==M.FPS_KEY and M.fps(self)then return end
    return key(self,k,...)
  end
  function Game:draw(...)local r=pack(draw(self,...));M.draw(self);return unpack(r,1,r.n)end
  V.mod.hooks:wrap("input.pointer",function(next,g,p)
    if M.pointer(g,p)then return true end;return next(g,p)
  end,2000002)
  -- R1 alone retains the engine speed binding, deferred until release so a
  -- chord never changes speed. Track ownership per controller, including ups.
  local pressed,released=Game.gamepadpressed,Game.gamepadreleased
  local states=setmetatable({},{__mode="k"});local nilPad={}
  local function state(j)local id=j or nilPad;states[id]=states[id]or{swallowed={},forwarded={}};return states[id]end
  local chords={dpup="0",dpleft="f6",dpright="f7",dpdown="f4",start="f3"}
  function Game:gamepadpressed(j,b,...)
    local s=state(j)
    if s.swallowed[b]then return end
    if M.current(self)then
      s.swallowed[b]=true
      if b=="rightshoulder"then s.used=true end
      M.panelKey(self,padKeys[b]);return
    end
    local selectHeld=false
    if j and j.isGamepadDown then
      local ok,held=pcall(j.isGamepadDown,j,"back");selectHeld=ok and held==true
    end
    if b=="rightshoulder"and ready(self)and not selectHeld then
      if not s.held then s.held=true;s.used=false;s.screen=top(self)end
      return
    end
    if s.held and chords[b]then
      s.used=true;s.swallowed[b]=true
      if ready(self)then self:keypressed(chords[b])end
      if self.touchControls and self.touchControls.noteGamepad then self.touchControls:noteGamepad()end
      return
    end
    s.forwarded[b]=true;return pressed(self,j,b,...)
  end
  function Game:gamepadreleased(j,b,...)
    local s=state(j)
    if b=="rightshoulder"and s.held then
      s.held=false
      local replay=not s.used and top(self)==s.screen and ready(self)
      s.used=false;s.screen=nil
      if replay then pressed(self,j,b);return released(self,j,b,...)end
      return
    end
    if s.swallowed[b]then
      s.swallowed[b]=nil
      -- Only a prior native press owes a native release. A chord's release
      -- must not reach a newly opened screen's release handler.
      if s.forwarded[b]then s.forwarded[b]=nil;return released(self,j,b,...)end
      return
    end
    s.forwarded[b]=nil
    return released(self,j,b,...)
  end
  -- TouchControls normally gets first refusal. Only the launcher and open
  -- panel take precedence, avoiding overlaps with custom mobile pad layouts.
  local tp,tm,tr=Game.touchpressed,Game.touchmoved,Game.touchreleased
  local contacts={}
  function Game:touchpressed(id,x,y,...)
    if M.pointer(self,{phase="pressed",source="touch",x=x,y=y})then contacts[id]=true;return end
    return tp(self,id,x,y,...)
  end
  function Game:touchmoved(id,...)if contacts[id]then return end;return tm(self,id,...)end
  function Game:touchreleased(id,...)if contacts[id]then contacts[id]=nil;return end;return tr(self,id,...)end
  -- Focus loss already resets native input; drop our deferred R1 as well.
  local cancel=Game.cancelPointers
  if cancel then function Game:cancelPointers(...)
    states=setmetatable({},{__mode="k"});contacts={};M.paint=nil
    return cancel(self,...)
  end end
  local removed=Game.joystickremoved
  if removed then function Game:joystickremoved(j,...)
    states[j or nilPad]=nil;return removed(self,j,...)
  end end
end
return M
