-- Encounter-local appearance control. Never writes a live mon or a save option.
local V = ...
local M = { KEY="0" }
local states = setmetatable({}, {__mode="k"})
local Game = require("src.core.Game")
local Battle = require("src.battle.BattleState")
local unpack = table.unpack or unpack
local function pack(...) return {n=select("#",...),...} end
local function active(game)
  local stack=game and game.stack
  local b=stack and stack:top()
  if b and b.player and b.enemy and b.data and b.phase=="menu"
      and not b.current and not b.growIn and not b.sendingOut
      and not b.ended and not b.demo and not b.oakDemo then return b end
end
M.active=active
local function staged(b)
  return b.voxelAscendantShot~=nil and not V.require("OverworldBattle").playerBackPinned(b)
end
local function state(b)
  local s=states[b]
  if not s then s={choice="current",cache={}};states[b]=s end
  return s
end
function M.choice(b) return states[b] and states[b].choice or "current" end
function M.manual(b)
  local c=M.choice(b);return c=="original" or c=="crystal"
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
      local ok,h=pcall(V.mod.find,V.mod,id)
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
  local image,animation,presentation
  if choice=="crystal"then image,animation,presentation=crystalMotion(b,mon,view)end
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
function M.update(b,dt)
  local s=states[b]
  if not s or s.choice~="crystal"then return end
  for _,entry in pairs(s.cache)do
    if entry.animation and entry.presentation and b[entry.side]
        and b[entry.side].mon==entry.mon then
      local ok,image=pcall(entry.animation.advancePresentation,entry.presentation,dt,b.game or Game)
      if ok and image then entry.image=image
      else entry.animation=nil;entry.presentation=nil end
    end
  end
end
function M.choices(b)
  local rows={{id="current",label="AUTO"}}
  local view=staged(b) and "front" or "back"
  for _,r in ipairs({{id="original",label="ORIGINAL"},{id="crystal",label="CRYSTAL"}})do
    if imageFor(b,"player",view,r.id) and imageFor(b,"enemy","front",r.id) then rows[#rows+1]=r end
  end
  if staged(b) then
    local provider=V.PokemonModelProvider
    for _,id in ipairs({"stadium1","stadium2"})do
      local source=provider.resolve(id)
      if source==id then rows[#rows+1]={id=id,label=id=="stadium1" and "STADIUM 1" or "STADIUM 2"} end
    end
  end
  return rows
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
    if c~="current" then return (c=="stadium1" or c=="stadium2") and c or "crystal" end
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
  function Game:draw(...)local r=pack(draw(self,...));M.draw(self);return unpack(r,1,r.n)end
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
