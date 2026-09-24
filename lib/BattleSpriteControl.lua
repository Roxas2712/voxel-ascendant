-- Encounter-local overrides with an optional persisted HD default.
-- Rendering never writes a live Pokemon or changes its battle state.
local V = ...
local M = { KEY="0" }
M.setting=V.require("ModSetting").new("battleHdSprites", "HD BATTLE SPRITES",
  {false,true}, {"OFF", "ON"}, false)
M.styleSetting=V.require("ModSetting").new("battleSpriteStyle", "BATTLE POKEMON STYLE",
 {"current","original","crystal","hd","stadium1","stadium2","cobblemon"},
 {"AUTO","ORIGINAL","CRYSTAL","HD ANIMATED","STADIUM 1","STADIUM 2","COBBLEMON"},"current")
local states = setmetatable({}, {__mode="k"})
local Game = require("src.core.Game")
local Battle = require("src.battle.BattleState")
local unpack = table.unpack or unpack
local function pack(...) return {n=select("#",...),...} end
local function active(game)
  local stack=game and game.stack
  local top=stack and stack:top()
  local function ready(b)
    return b and b.player and b.enemy and b.data and (b.phase=="menu" or b.phase=="moveSelect")
      and not b.current and not b.growIn and not b.sendingOut
      and not b.ended and not b.demo and not b.oakDemo
  end
  if ready(top) then return top end
  -- F3 may be opened from the move/item selector, which is a ListMenu above
  -- the BattleState. Its command-menu battle is still the exact art owner.
  if top and type(top.items)=="table" then
    for i=#(stack.states or {}),1,-1 do
      local b=stack.states[i]
      if ready(b) then return b end
      if b and b.player and b.enemy then return end
    end
  end
end
M.active=active
local function staged(b)
  return b.voxelAscendantShot~=nil and not V.require("OverworldBattle").playerBackPinned(b)
end
local function state(b)
  local s=states[b]
  if not s then
    local hd=M.setting:get()==true
    local choice=M.styleSetting:get();if choice=="current" and hd then choice="hd" end
    s={choice=choice,label=string.upper(choice),cache={}}
    states[b]=s
  end
  return s
end
function M.choice(b)
  return b and b.player and b.enemy and state(b).choice or "current"
end
function M.manual(b)
  local c=M.choice(b);return c=="original" or c=="crystal" or c=="hd"
end
local function pathFor(b,mon,view,choice)
  if not mon or mon._ascMegaForm or mon.ascMegaForm or mon.form then return nil end
  local def=b.data.pokemon[mon.species]
  if not def then return nil end
  if choice=="original" then
    local path=view=="back" and def.spriteBack or def.spriteFront
    if path and require("src.render.Assets").exists(path) then return path,def.trueColor==true end
  elseif choice=="crystal" then
    -- Public companion seam preserves its exact shiny and rear artwork.
    for _,id in ipairs({"kanto_ascendant","trainer_rematch"})do
      local ok,h=pcall(V.mod.find,id)
      if not ok or not h then ok,h=pcall(V.mod.find,V.mod,id)end
      local a=ok and h and h.exports and h.exports.crystalAnimation
      if a and a.staticFrameOne then
        local shiny=V.require("Gen2CrystalFronts").isShiny(mon)
        local yes,path,tc=pcall(a.staticFrameOne,{data=b.data,species=mon.species,mon=mon,kind="battle"},view,shiny and "shiny" or "normal")
        if yes and path then return path,tc end
      end
    end
    if view=="front" then
      local r=V.require("Gen2CrystalFronts").resolve(b.data,mon)
      if r then return r.path,r.trueColor end
    end
  end
end
local function crystalMotion(b,mon,view)
  if mon._ascMegaForm or mon.ascMegaForm or mon.form then return nil end
  for _,id in ipairs({"kanto_ascendant","trainer_rematch"})do
    local ok,h=pcall(V.mod.find,id)
    if not ok or not h then ok,h=pcall(V.mod.find,V.mod,id)end
    local a=ok and h and h.exports and h.exports.crystalAnimation
    if a and type(a.presentationAnimation)=="function"
        and type(a.advancePresentation)=="function"then
      local copy={};for k,v in pairs(mon)do copy[k]=v end
      local surface=staged(b) and "voxel_map" or "battle"
      local yes,presentation=pcall(a.presentationAnimation,copy.species,copy,view,surface,
        {data=b.data,forceStyle=true,trim=true})
      if yes and presentation and presentation.image then return presentation.image,a,presentation end
    end
  end
end
local function imageFor(b,side,view,choice)
  local actor=b[side];local mon=actor and actor.mon
  if not mon or actor.transformed or actor.preTransform or (actor.curStats and actor.curStats~=mon.stats) or (side=="enemy" and (b.ghost or b.ghostReal)) then return nil end
  local s=state(b)
  local key=side..":"..view..":"..choice
  local old=s.cache[key]
  local stamp=tostring(mon.species)..":"..tostring(mon._ascMegaForm)..":"..tostring(mon.form)..":"..tostring(mon.shiny)..":"..tostring(mon.dvs)
  if old and old.mon==mon and old.stamp==stamp then return old.image or nil end
  local image,animation,presentation,pending
  if choice=="hd" then
    animation=V.require("HdPokemonPresentation")
    presentation,pending=animation.create(b.game,mon,view)
    -- All direction banks share the actor's clock: orbiting must not restart
    -- an idle animation or change its playback speed.
    if presentation then
      for _,entry in pairs(s.cache)do
        if entry.side==side and entry.mon==mon and entry.stamp==stamp
            and entry.animation==animation and entry.presentation then
          presentation.elapsed=entry.presentation.elapsed
          animation.advancePresentation(presentation,0,b.game or Game)
          break
        end
      end
    end
    image=presentation and presentation.image
    -- Pending is not missing artwork: retry when the bounded preparation
    -- completes instead of caching a permanent native fallback for this mon.
    if pending=="pending" then return nil end
  elseif choice=="crystal" then image,animation,presentation=crystalMotion(b,mon,view)end
  local path,tc
  if not image then path,tc=pathFor(b,mon,view,choice)end
  if path then
    local copy={};for k,v in pairs(mon)do copy[k]=v end
    copy._vascBattleAppearance={path=path,trueColor=tc}
    local ok,result=pcall(Battle.makeBattler,b.data,copy,view=="back",nil)
    if ok and result then image=result.sprite end
  end
  s.cache[key]={mon=mon,stamp=stamp,image=image or false,side=side,animation=animation,presentation=presentation}
  return image
end
M.imageFor=imageFor
-- Source rows are front/left/back/right. Select from the opponent bearing
-- in camera space; the card itself remains a readable upright billboard.
function M.viewToward(position,other,eye,previous)
  if not (position and other and eye) then return previous or "front" end
  local dx,dz=other[1]-position[1],other[3]-position[3]
  local ex,ez=eye[1]-position[1],eye[3]-position[3]
  local forward=dx*ex+dz*ez
  local right=dx*ez-dz*ex
  if dx*dx+dz*dz<1e-8 or ex*ex+ez*ez<1e-8 then return previous or "front" end
  local a,b=math.abs(forward),math.abs(right)
  -- Small hysteresis prevents alternating rows at a diagonal during drift.
  local sameQuadrant=(previous=="front" and forward>=0)
    or (previous=="world_back" and forward<0)
    or (previous=="right" and right>=0)
    or (previous=="left" and right<0)
  if sameQuadrant and math.abs(a-b)<math.max(a,b)*.12 then return previous end
  if a>b then return forward>=0 and "front" or "world_back" end
  return right>=0 and "right" or "left"
end
function M.worldView(b,side)
  local s=state(b)
  return s.worldViews and s.worldViews[side] or (side=="player" and "right" or "left")
end
function M.orientWorld(b,layout,eye)
  if M.choice(b)~="hd" or not (layout and eye) then return false end
  local s=state(b);s.worldViews=s.worldViews or {}
  local changed=false
  for _,side in ipairs({"player","enemy"})do
    local previous=M.worldView(b,side)
    local nextView=M.viewToward(layout[side],layout[side=="player" and "enemy" or "player"],eye,previous)
    if nextView~=previous then changed=true end
    s.worldViews[side]=nextView
  end
  return changed
end
-- Warm only immutable HD frames during the covered introduction. Do not add
-- a live presentation to the encounter cache or advance its animation clock.
function M.prepare(b,side,view)
  if M.choice(b)~="hd" then return false end
  local actor=b[side];local mon=actor and actor.mon
  if not mon or actor.transformed or actor.preTransform
      or (actor.curStats and actor.curStats~=mon.stats)
      or (side=="enemy" and (b.ghost or b.ghostReal)) then return false end
  local presentation,status=V.require("HdPokemonPresentation").create(b.game,mon,view)
  return presentation~=nil,status
end
function M.update(b,dt)
  local s=states[b]
  if not s or (s.choice~="crystal" and s.choice~="hd") then return end
  for _,entry in pairs(s.cache)do
    if entry.animation and entry.presentation and b[entry.side]
        and b[entry.side].mon==entry.mon then
      local ok,image=pcall(entry.animation.advancePresentation,entry.presentation,dt,b.game or Game)
      if ok and image then entry.image=image
      else entry.animation=nil;entry.presentation=nil end
    end
  end
end
function M.choices(b,includeMissing)
  local rows={{id="current",label="AUTO"}}
  local view=staged(b) and "front" or "back"
  for _,r in ipairs({{id="original",label="ORIGINAL"},{id="crystal",label="CRYSTAL"}})do
    -- Availability is per actor, just like HD. A missing enemy pack must
    -- not hide an installed player style; that actor retains its native art.
    local available=imageFor(b,"player",view,r.id) or imageFor(b,"enemy","front",r.id)
    if available or includeMissing then r.unavailable=not available;rows[#rows+1]=r end
  end
  local hd=V.require("HdPokemonPresentation")
  local hdReady=hd.resolve(b.game,b.player and b.player.mon) or hd.resolve(b.game,b.enemy and b.enemy.mon)
  if hdReady or includeMissing then rows[#rows+1]={id="hd",label="HD ANIMATED",unavailable=not hdReady} end
  -- Model selection itself switches cropped backs to full-body presentation.
  -- Do not hide it behind the current sprite orientation.
  if b.voxelAscendantShot~=nil or includeMissing then
    local provider=V.PokemonModelProvider
    for _,id in ipairs({"stadium1","stadium2","cobblemon"})do
      local source=provider.resolve(id)
      local ready=b.voxelAscendantShot~=nil and source==id
      if ready or includeMissing then rows[#rows+1]={id=id,label=id=="cobblemon" and "COBBLEMON" or id=="stadium1" and "STADIUM 1" or "STADIUM 2",unavailable=not ready,needsStage=b.voxelAscendantShot==nil} end
    end
  end
  return rows
end
-- A broken optional art provider may fall back for this encounter only.
-- The persisted HD preference remains untouched for the next encounter.
function M.recover(b)
  local s=state(b)
  s.choice="original";s.label="ORIGINAL (RECOVERY)";s.cache={}
end
function M.select(game,id)
  local b=active(game)
  if not b then V.require("ShortcutToast").notify("POKEMON SPRITES","Wait for the command menu");return false end
  for _,row in ipairs(M.choices(b))do
    if row.id==id then
      local s=state(b);s.choice=id;s.label=row.label
      V.require("ShortcutToast").notify("POKEMON SPRITES",row.label)
      return true
    end
  end
  V.require("ShortcutToast").notify("POKEMON SPRITES","Source unavailable for this battle")
  return false
end
function M.cycle(game)
  local b=active(game);if not b then return false end
  local rows=M.choices(b);local s=state(b);local at=0
  for i,r in ipairs(rows)do if r.id==s.choice then at=i end end
  local row=rows[at%#rows+1];s.choice=row.id;s.label=row.label
  V.require("ShortcutToast").notify("POKEMON SPRITES",row.label)
  return true
end
-- Used by the existing model owner; selection expires with this encounter.
function M.modelRequest()
  local stack=Game.stack
  for _,b in ipairs(stack and stack.states or {})do
    local c=M.choice(b)
    if c~="current" then return (c=="stadium1" or c=="stadium2" or c=="cobblemon") and c or "crystal" end
  end
end
function M.withSprites(b,world,fn,...)
  if not M.manual(b) then return fn(...) end
  local saved={}
  for _,side in ipairs({"player","enemy"})do
    local actor=b[side]
    if actor then
      local view=side=="player" and not world and "back" or "front"
      local image=imageFor(b,side,view,M.choice(b))
      if image then saved[#saved+1]={actor,actor.sprite};actor.sprite=image end
    end
  end
  local result=pack(pcall(fn,...))
  for _,r in ipairs(saved)do r[1].sprite=r[2] end
  if not result[1] then error(result[2],0) end
  return unpack(result,2,result.n)
end
function M.rect(w,h)
  local scale=math.max(.7,math.min(1.5,w/960,h/600))
  return {12*scale,h-48*scale,190*scale,36*scale,scale}
end
function M.draw(game)
  if V.Controls then M.paint=nil;return end
  local b=active(game);if not b then M.paint=nil;return end
  local g=love.graphics;local w,h=g.getDimensions();local r=M.rect(w,h)
  g.push("all");g.origin();g.setCanvas();g.setShader();g.setScissor();g.setBlendMode("alpha")
  g.setColor(.025,.07,.10,.93);g.rectangle("fill",r[1],r[2],r[3],r[4],6,6)
  g.setColor(.2,.75,.83,1);g.rectangle("line",r[1],r[2],r[3],r[4],6,6)
  if not M.font then M.font=g.newFont(14) end
  g.setFont(M.font);g.setColor(1,1,1,1)
  g.print("[0] Sprites: "..(state(b).label or "AUTO"),r[1]+10*r[5],r[2]+9*r[5],0,r[5],r[5]);g.pop()
  M.paint={battle=b,rect=r,w=w,h=h}
end
function M.press(game,x,y)
  local p=M.paint;local b=active(game)
  if not p or p.battle~=b then return false end
  local w,h=love.graphics.getDimensions()
  if p.w~=w or p.h~=h then return false end
  local r=p.rect
  if x<r[1] or y<r[2] or x>=r[1]+r[3] or y>=r[2]+r[4] then return false end
  M.paint=nil;return M.cycle(game)
end
function M.install()
  if M.installed then return end
  M.installed=true
  V.BattleSpriteControl=M
  V.mod.hooks:wrap("pokemon.sprite",function(next,path,ctx)
    local own=ctx and ctx.mon and ctx.mon._vascBattleAppearance
    if own and ctx.kind=="battle" then ctx.trueColor=own.trueColor;return own.path end
    return next(path,ctx)
  end,2000000)
  local key=Game.keypressed
  function Game:keypressed(k,...)
    if k==M.KEY and M.cycle(self) then return end
    return key(self,k,...)
  end
  local draw=Game.draw
  function Game:draw(...)
    -- Includes covered transitions and Dex, and cleans abandoned requests
    -- after either screen closes. Never perform this work per eye or shadow.
    V.require("HdPokemonPresentation").pump()
    local r=pack(draw(self,...))
    V.require("OverworldBattle").drawFallbackNotice(self)
    M.draw(self)
    return unpack(r,1,r.n)
  end
  V.mod.hooks:wrap("input.pointer",function(next,game,p)
    if p and p.phase=="pressed" and (p.source=="touch" or p.source=="mouse")
        and (p.source~="mouse" or p.button==nil or p.button==1) and M.press(game,p.x,p.y) then return true end
    return next(game,p)
  end,2000000)
  local update=Battle.update
  function Battle:update(dt,...)
    local result=pack(update(self,dt,...));M.update(self,dt)
    return unpack(result,1,result.n)
  end
  local pics=Battle.drawPicsLayer
  function Battle:drawPicsLayer(...)
    return M.withSprites(self,false,pics,self,...)
  end
end
return M
