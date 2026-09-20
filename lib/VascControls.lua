-- Keyboard, controller and touch share the existing setting/shortcut owners.
-- The panel is a stack state: the world/battle pauses while choosing an action.
local V=...
local M={HELP_KEY="f3",FPS_KEY="f4"}
local Host=V.controlsHost
local Game=Host and Host.Game or require("src.core.Game")
local unpack=table.unpack or unpack
local function pack(...)return{n=select("#",...),...}end
local function top(g)return g and g.stack and g.stack:top()end
local function ready(g)
  if Host then return Host.ready(g) end
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
  local world=Host and Host.world(g) or g.overworld
  local map=world and world.map
  local id=map and(map.id or map)or world
  local s=hints[g];local t=now()
  if not s then s={map=id,battle=b,started=t};hints[g]=s
  else
    if id~=s.map or(b and b~=s.battle)then s.started=t end
    s.map=id;s.battle=b
  end
  -- Menus, dialogue and fades cover the scene: never paint the arrival hint
  -- over their own controls. Context tracking above still consumes its timer.
  if Host then
    if Host.context(g)=="other" then return 0 end
  elseif top(g) ~= g.overworld and top(g) ~= b then return 0 end
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
local groupNames={terrarium={"Terrarium","Terrarium"},wilds={"Wilds","Wilds"},followers={"Followers","Begleiter"},town={"Town Pokémon","Stadt-Pokémon"},effects={"Camera & world","Kamera & Welt"}}
function M.context(g)
 if Host then return Host.context(g,M.current(g)) end
 local p=M.current(g);local t=p and p.previous or top(g)
 if t and t.player and t.enemy and t.phase then return "battle",t end
 if t==g.overworld then return "world",t end
 return "other",t
end
local function terrariumRows()
 local out={}
 local labels={
  terarriumBehindRed={"Battle orientation","Kampfausrichtung"},
  terarriumLighting={"Lighting","Beleuchtung"},
  terarriumIdleAnimation={"Idle motion","Ruheanimation"},
  terarriumIdleSound={"Idle sound","Animationsklang"},
 }
 for _,entry in ipairs(V.require('IntegratedTerarrium').entries())do
  local setting=entry[1];local title=labels[setting.key]
  if title then
   out[#out+1]={id=setting.key,title=title[1],titleDe=title[2],hint='',
    detail=entry[2] or '',
    detailDe=setting.key=='terarriumBehindRed'and'Wechselt im nächsten Befehlsmenü. Trainer, Pokémon und Attacken folgen der Ausrichtung.'or'',
    status=function(de)
     local value=setting:get()
     if setting.key=='terarriumBehindRed'then return value and(de and'HINTER TRAINER'or'BEHIND TRAINER')or(de and'SEITLICH'or'SIDE')end
     return value and(de and'AN'or'ON')or(de and'AUS'or'OFF')
    end,
    change=function(game,dir)setting:cycle(game,dir)end}
  end
 end
 return out
end
function M.visibleRows(g,group)
 if Host then return Host.rows(g,group,M) end
 local context=M.context(g);local out={}
 if group=='terrarium'then return terrariumRows()end
 local allowed=context=="battle" and {['0']=true,['8']=true,['5']=true,['6']=true,f4=true,q=true,e=true}
  or context=="world" and {['0']=true,v=true,f6=true,f4=true}or{f4=true}
 if context=='battle'then
  local ok,shot=pcall(function()local b=V.require('OverworldBattle');return b.shot and b.shot()end)
  if not(ok and shot)then allowed['5']=nil;allowed.q=nil;allowed.e=nil end
 end
 for i,row in ipairs(M.rows)do
  local effect=row.key=='5'or row.key=='6'or row.key=='7'or row.key=='9'or row.key=='q'or row.key=='e'
  if (not group and allowed[row.key])or(group=='effects'and context=='world'and effect)then
   local copy={};for k,v in pairs(row)do copy[k]=v end
   copy.titleDe=germanRows[i].title;copy.detailDe=germanRows[i].detail;copy.hintDe=germanRows[i].hint
   out[#out+1]=copy
  end
 end
 if context=='world'then
  local extra=V.require('VascQuickOptions').rows(g,V.require('AppearanceShortcuts').settings)
  if group then
   for _,row in ipairs(extra)do if row.group==group then out[#out+1]=row end end
  else
   for _,id in ipairs({'followers','wilds','town','effects'})do
    local count=id=='effects'and 6 or 0
    for _,row in ipairs(extra)do if row.group==id then count=count+1 end end
    if count>0 then out[#out+1]={id=id,title=groupNames[id][1],titleDe=groupNames[id][2],submenu=id,hint='',detail='',status=function()return '›'end}end
   end
  end
 end
 if not group and (context=='world'or context=='battle')then
  out[#out+1]={id='terrarium',title='Terrarium',titleDe='Terrarium',submenu='terrarium',hint='',detail='',status=function()return '›'end}
 end
 if context=='battle'and allowed.q then
  out[#out+1]={id='battle-distance',title='Camera distance',titleDe='Kameraabstand',hint='',detail='Starting zoom. Pinch to zoom; drag to look. Mouse wheel / right stick: camera.',detailDe='Startabstand. Zwei Finger: Zoom; ziehen: drehen. Mausrad / rechter Stick: Kamera.',
   status=function()return tostring(V.require('BattleCam').distanceSetting:get())..'X'end,
   change=function(game)V.require('BattleCam').distanceSetting:cycle(game);V.require('BattleCam').applyDistanceSetting(true)end}
  out[#out+1]={id='camera-reset',title='Centre camera',titleDe='Kamera zentrieren',hint='',detail='Return to your selected starting distance and angle.',detailDe='Zum gewählten Startabstand und Blickwinkel zurückkehren.',status=function()return '↺'end,
   change=function()V.require('BattleCam').recentre()end}
 end
 local order=context=='battle'and{['8']=1,['0']=2,['5']=3,['6']=4,['battle-distance']=5,q=6,e=7,['camera-reset']=8,f4=9}or{v=1,followers=2,wilds=3,town=4,['0']=5,f6=6,effects=7,f4=8}
 if not group then table.sort(out,function(a,b)return(order[a.key or a.id]or 99)<(order[b.key or b.id]or 99)end)end
 return out
end
function M.back(g)
 local p=M.current(g)
 if p and p.group then p.group=nil;p.selected=1;p.rows=M.visibleRows(g);M.paint=nil;return true end
 return M.close(g)
end
-- Read the same live owners the shortcuts change; never maintain a second
-- set of booleans in the panel. Multi-state effects show their selected mode.
function M.status(g,index)
  local p=M.current(g);local row=p and p.rows[index]or M.rows[index];if not row then return "" end
  if row.status then return row.status(M.language()=="de")end
  local de=M.language()=="de"
  local function setting(s)
    if not s then return de and "Nicht verfügbar"or"Unavailable"end
    if s.row then return s:row().value()end
    local value=s:get()
    if type(value)=="boolean"then return value and(de and "AN"or"ON")or(de and "AUS"or"OFF")end
    return tostring(value)
  end
  local ok,value=pcall(function()
    local k=row.key
    if k=="f4"then return setting((V.PerformanceOverlay or V.require("PerformanceOverlay")).enabled)end
    if k=="f6"or k=="f7"then
      local a=V.require("AppearanceShortcuts").settings
      if k=="f6"then return a.apo_hd_walking_sprites and(a.apo_hd_walking_sprites:get()and"HD"or"2D / ORIGINAL")end
      if not a.apo_hd_pokemon_followers then return end
      return a.apo_hd_pokemon_followers:get()and setting(a.apo_follower_sprite_source)or"2D / ORIGINAL"
    end
    if k=="v"or k=="6"then
      local pipelines=require("src.render.Pipelines")
      local module=V.require(k=="v"and"VoxelState"or"TiltShift")
      return (module.ANGLE_LABELS or module.LABELS)[pipelines.level(k=="v"and"voxel"or"tiltshift")+1]
    end
    local modules={["5"]="VoxelGrid",["7"]="WorldCurve",["8"]="OverworldBattle",["9"]="Water"}
    if modules[k]then
      local owner=V.require(modules[k])
      if k=="8"then
        local panel=M.current(g);local b=panel and panel.previous or top(g)
        local request=owner.presentationRequests and owner.presentationRequests[b]
        if request then
          local mode=request.mode or(request.plan and request.plan.mode)
          local label=mode==true and "MAP"or mode==owner.ARENA and "ARENA"
            or mode==owner.FLAT_B and "DISCS"or mode=="terarrium"and"TERRARIUM"
          if label then return label..(request.pending and(de and " · wartet"or" · pending")or"")end
        end
      end
      return setting(k=="5"and M.context(g)=="battle"and owner.battleSetting or owner.setting)
    end
    if k=="0"then
      local panel=M.current(g);local b=panel and panel.previous or top(g)
      if b and b.player and b.enemy and b.phase then
        local choice=V.require("BattleSpriteControl").choice(b)
        return choice=="current"and"AUTO"or choice:upper()
      end
      return de and "Auswahl öffnen"or"Open selection"
    end
    if k=="q"then return "+"end
    if k=="e"then return "−"end
  end)
  value=ok and value or nil
  if value=="OFF"then return de and"AUS"or"OFF"end
  if value=="ON"then return de and"AN"or"ON"end
  return value or(de and"Nicht verfügbar"or"Unavailable")
end
function M.current(g)return top(g)and top(g)._vascControls and top(g)or nil end
function M.close(g)
  if not M.current(g)then return false end
  g.stack:pop();M.paint=nil;return true
end
function M.activate(g,index)
  local panel=M.current(g);local row=panel and panel.rows[index]
  if not panel or not row then return false end
  if row.submenu then panel.group=row.submenu;panel.selected=1;panel.rows=M.visibleRows(g,panel.group);M.paint=nil;return true end
  local group=panel.group
  local previous=panel.previous
  M.close(g)
  if top(g)~=previous then return false end
  -- Uncover the actual context before invoking its normal availability gate.
  if row.change then row.change(g,1)
  elseif row.key=='5'and M.context(g)=='battle'then V.require('VoxelGrid').battleSetting:cycle(g)
  else g:keypressed(row.key)end
  if top(g)==previous then M.open(g,index,group)end
  return true
end
function M.panelKey(g,k)
  local p=M.current(g);if not p then return false end
  if k=="escape"then M.back(g)
  elseif k==M.HELP_KEY then M.close(g)
  elseif k=="up"then p.selected=(p.selected-2)%#p.rows+1
  elseif k=="down"then p.selected=p.selected%#p.rows+1
  elseif k=="left"or k=="pageup"then p.selected=math.max(1,p.selected-(p.perPage or 6))
  elseif k=="right"or k=="pagedown"then p.selected=math.min(#p.rows,p.selected+(p.perPage or 6))
  elseif k=="return"or k=="space"then M.activate(g,p.selected)
  else for i,row in ipairs(p.rows)do if row.key and row.key==k then M.activate(g,i);break end end end
  M.paint=nil
  return true
end
local padKeys={dpup="up",dpdown="down",dpleft="left",dpright="right",a="return",b="escape",start="f3",back="escape",leftshoulder="pageup",rightshoulder="pagedown"}
function M.open(g,selected,group)
  if M.current(g)then return true end
  if not ready(g)or M.context(g)=="other"then return false end
  local p={_vascControls=true,previous=top(g),selected=selected or 1,group=group}
  p.rows=M.visibleRows(g,group);if #p.rows==0 then return false end
  p.selected=math.min(p.selected,#p.rows)
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
    local mobile=M.mobile(g)
    return{launcher={x+12,y+82,mobile and 48 or 170,48},safe={x,y,w,h}}
  end
  local width=math.max(220,math.min(610,w-16));local perPage=math.max(1,math.min(6,math.floor((h-156)/64)))
  p.perPage=perPage
  local page=math.floor((p.selected-1)/perPage);local pages=math.ceil(#p.rows/perPage)
  local height=perPage*64+144;local px=x+(w-width)/2;local py=y+math.max(4,(h-height)/2)
  local t={safe={x,y,w,h},panel={px,py,width,height},page=page,pages=pages,rows={},
    close={px+width-64,py+8,56,48},prev={px+12,py+height-56,76,48},next={px+width-88,py+height-56,76,48}}
  if p.group then t.back={px+width/2-55,py+height-56,110,48}end
  for i=1,perPage do
    local index=page*perPage+i
    if p.rows[index]then t.rows[#t.rows+1]={index=index,rect={px+12,py+72+(i-1)*64,width-24,58}}end
  end
  return t
end
function M.draw(g)
  M.paint=nil
  local p=M.current(g)
  local de=M.language()=="de"
  local rows=p and p.rows or{}
  if not p and(not ready(g)or M.context(g)=="other")then return end
  local mobile=M.mobile(g)
  local hintAlpha=mobile and 1 or M.hintAlpha(g)
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
    -- Mobile has no F3/R1 shortcut: keep its touch launcher discoverable.
    -- Desktop retains the short arrival hint.
    if mobile then
      local r=t.launcher
      local cx,cy=r[1]+r[3]/2,r[2]+r[4]/2
      -- A small persistent marker, with a forgiving 48px touch target.
      graphics.setColor(0,0,0,.16);graphics.circle("fill",cx,cy+1,16)
      graphics.setColor(1,1,1,.24);graphics.circle("fill",cx,cy,15)
      graphics.setLineWidth(1)
      graphics.setColor(1,1,1,.62);graphics.circle("line",cx,cy,15)
      graphics.setFont(M.font)
      local tx=cx-M.font:getWidth("V")/2
      local ty=cy-(M.font.getHeight and M.font:getHeight()or 14)/2
      graphics.setColor(0,0,0,.35);graphics.print("V",tx+1,ty+1)
      graphics.setColor(1,1,1,.95);graphics.print("V",tx,ty)
    elseif hintAlpha>0 then
      local r=t.launcher
      graphics.setColor(.025,.07,.09,.38*hintAlpha);graphics.rectangle("fill",r[1],r[2],r[3],r[4],7,7)
      graphics.setColor(.85,.95,.97,.75*hintAlpha);graphics.setFont(M.font)
      graphics.print(de and "F3 · VASC-Hilfe"or"F3 · VASC Help",r[1]+10,r[2]+6)
      graphics.setFont(M.small)
      graphics.print("Controller: R1 + Start",r[1]+10,r[2]+27)
    end
  else
    graphics.setColor(.015,.025,.035,.87);graphics.rectangle("fill",0,0,ww,hh)
    box(t.panel);local px,py=t.panel[1],t.panel[2]
    label("VASC · "..(p.group and groupNames[p.group][de and 2 or 1]or(de and "Schnellmenü"or"Quick menu")),px+14,py+12)
    label(mobile and(de and "Zeile antippen zum Ändern · ×: schließen"or"Tap a row to change · ×: close")
      or(de and "↑ / ↓: wählen · Enter / A: ändern · Esc / B: zurück"or"↑ / ↓: select · Enter / A: change · Esc / B: back"),px+14,py+38,M.small)
    box(t.close);label("×",t.close[1]+21,t.close[2]+12)
    for _,entry in ipairs(t.rows)do
      local r,row=entry.rect,rows[entry.index];box(r,p.selected==entry.index)
      label(de and row.titleDe or row.title,r[1]+10,r[2]+4)
      local status=M.status(g,entry.index)
      local statusWidth=M.small:getWidth(status)
      -- Status has its own line, including on narrow portrait phones.
      label(status,r[1]+10,r[2]+24,M.small)
      if not mobile and M.small:getWidth(row.hint)+statusWidth+32<=r[3]then
        label(row.hint,r[1]+r[3]-M.small:getWidth(row.hint)-10,r[2]+24,M.small)
      end
      local detail=mobile and(row.submenu and(de and "Antippen zum Öffnen"or"Tap to open")or(de and "Antippen zum Ändern"or"Tap to change"))or(de and row.detailDe or row.detail)or""
      if M.small:getWidth(detail)<=r[3]-20 then label(detail,r[1]+10,r[2]+40,M.small)end
    end
    box(t.prev);box(t.next);label("<",t.prev[1]+31,t.prev[2]+14);label(">",t.next[1]+31,t.next[2]+14)
    if t.back then
      box(t.back);label(de and "‹ Zurück"or"‹ Back",t.back[1]+18,t.back[2]+4)
      label((t.page+1).." / "..t.pages,t.back[1]+39,t.back[2]+27,M.small)
    else label((t.page+1).." / "..t.pages,px+t.panel[3]/2-16,t.prev[2]+14)end
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
  if t.back and hit(t.back,p.x,p.y)then M.back(g)
  elseif hit(t.close,p.x,p.y)then M.close(g)
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
  function Game:draw(...)local r=pack(draw(self,...));if Host and Host.drawBackdrop and M.current(self) then Host.drawBackdrop(self)end;M.draw(self);return unpack(r,1,r.n)end
  V.mod.hooks:wrap("input.pointer",function(next,g,p)
    if M.pointer(g,p)then return true end;return next(g,p)
  end,2000002)
  -- R1 alone retains the engine speed binding, deferred until release so a
  -- chord never changes speed. Track ownership per controller, including ups.
  local pressed,released=Game.gamepadpressed,Game.gamepadreleased
  local states=setmetatable({},{__mode="k"});local nilPad={}
  local function state(j)local id=j or nilPad;states[id]=states[id]or{swallowed={},forwarded={}};return states[id]end
  local chords=Host and Host.chords or {dpup="0",dpleft="f6",dpright="f7",dpdown="f4",start="f3"}
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
