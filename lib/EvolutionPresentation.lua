-- One complete surface for the native evolution movie and its retained text.
-- Rules, update, cancellation, cries, application and callbacks stay native.
local V = ...
local M = { apiVersion=2, schema="voxel-ascendant/gen1-evolution-presentation/v2" }
local WIDTH, HEIGHT = 512, 288
local installed, eventUnregister = false, {}
local owned = setmetatable({}, {__mode="k"})
local fields={"draw","drawWidescreen","uiSize","isWideBattleLayout","wantsFillScale","drawsWidescreen","sgbPalettes","isOpaque","letterboxWhite","bgMode"}
local Overlay = V.require("OrasPartyOverlayPresentation")
local function evolutionClass()
  local ok, value = pcall(require, "src.ui.EvolutionState")
  return ok and type(value)=="table" and value or nil
end
function M.isEvolutionState(state)
  local class=evolutionClass()
  local mt=type(state)=="table" and getmetatable(state)
  return class~=nil and (mt==class or type(mt)=="table" and rawget(mt,"__index")==class)
end
local function stack(state) return state.game and state.game.stack and state.game.stack.states or {} end
local function copyMon(mon,species)
  local copy={};for k,v in pairs(mon or {})do copy[k]=v end
  copy.species=species;return copy
end
-- Match the engine's flash schedule, without advancing any gameplay state.
local function showsNew(t)
  for b=1,8 do
    local hold=18-2*b
    if t<hold then return false end
    t=t-hold
    local swap=b*6
    if t<swap then return t%6<3 end
    t=t-swap
  end
  return true
end
local function modals(state,record)
  local above=false
  for _,s in ipairs(stack(state))do
    if s==state then above=true
    elseif above then
      if s.isOpaque then break end
      if s.isTextBox then
        Overlay.decorateTextBox(s,{wideBattle=true})
        -- The movie owns the surround too, not a retained white battle.
        s.letterboxWhite=false
      end
    end
  end
end
local function resultAbove(state)
  local above=false
  for _,s in ipairs(stack(state))do
    if s==state then above=true
    elseif above and (s.isTextBox or s.isOpaque)then return true end
  end
  return false
end
local function requestArt(state,record)
  if record.style~="hd" then return end
  local H=V.require("HdPokemonPresentation")
  for _,key in ipairs{"old","new"}do
    if not record[key.."HD"] and not record[key.."Missing"] then
      local ok,art,status=pcall(H.create,state.game,record[key.."Mon"],"front",128)
      if ok and art then record[key.."HD"]=art
      elseif not ok or status~="pending" then record[key.."Missing"]=true end
    end
  end
end
local function spriteFor(state,record,key)
  local hd=record[key.."HD"]
  if hd then
    local H=V.require("HdPokemonPresentation")
    -- Derive elapsed from render time; repeated surface draws do not accelerate it.
    local ok,img=pcall(H.advancePresentation,hd,record.dt,state.game)
    if ok and img then return img,true end
    record[key.."HD"]=nil;record[key.."Missing"]=true
  end
  local art=record[key.."Crystal"]
  if art and record.style~="original" then
    local api=record.crystal
    if api then
      local ok,img=pcall(api.advancePresentation,art,record.dt,state.game)
      if ok and img then return img,art.trueColor end
    end
  end
  return record[key.."Sprite"] or state[key.."Sprite"],record[key.."TrueColor"] or state[key.."SpriteTrueColor"]
end
local function drawSurface(state)
  local record=owned[state];if not record then return end
  local anchor=state
  state=record.movie or state
  local g=love.graphics
  local now=love.timer.getTime()
  record.dt=math.max(0,math.min(.1,now-(record.lastDraw or now)))
  record.lastDraw=now
  g.setShader();g.setScissor();g.setBlendMode("alpha","alphamultiply")
  g.setColor(.025,.055,.12,1);g.rectangle("fill",0,0,WIDTH,HEIGHT)
  g.setColor(.07,.15,.27,1);g.rectangle("fill",16,12,480,169,12,12)
  g.setColor(.18,.43,.56,.5);g.ellipse("fill",256,159,88,12)
  g.setColor(.44,.78,.9,.7);g.setLineWidth(1);g.ellipse("line",256,159,88,12)
  requestArt(state,record)
  if not state.loading then
    local key=state.done and (state.canceled and "old" or "new")
      or (showsNew((state.t or 0)-80) and "new" or "old")
    local img,trueColor=spriteFor(state,record,key)
    if img then
      local w,h=img:getDimensions()
      local scale=math.min(126/math.max(1,w),132/math.max(1,h))
      local silhouette=not state.done and (state.t or 0)>=80
      g.setColor(silhouette and .12 or 1,silhouette and .22 or 1,silhouette and .3 or 1,1)
      if not trueColor and not silhouette then
        local P=require("src.render.PaletteFX")
        local shader=P.shader()
        local colors=P.monPal(state.game.data,record[key.."Mon"].species)
        if shader and colors then P.sendColors(shader,colors);g.setShader(shader)end
      end
      g.draw(img,256-w*scale/2,160-h*scale,0,scale,scale)
      g.setShader()
      state.__vascEvolutionSpriteSource=record[key.."HD"] and "hd" or (record[key.."Crystal"] or record[key.."TrueColor"]) and "crystal" or "native"
    end
  end
  -- The intro is retained below the movie and therefore hidden by opacity.
  -- Draw its actual typed glyphs, not a reconstructed/translated message.
  if record.intro and not record.movie and not resultAbove(anchor)then
    Overlay.drawTextBox(record.intro)
    state.__vascEvolutionIntroDrawn=true
  else state.__vascEvolutionIntroDrawn=false end
  g.setColor(1,1,1,1)
end
local function draw(state)
  local g=love.graphics;g.push("all")
  local ok,err=pcall(drawSurface,state)
  g.pop()
  if not ok then error(err,0)end
end
local function claimSurface(state,record)
  record.original={}
  for _,key in ipairs(fields)do record.original[key]=rawget(state,key)end
  owned[state]=record
  state.__vascEvolutionPresentation=true
  state.__vascEvolutionPresentationSchema=M.schema
  state.__vascEvolutionPresentationOriginalDraw=state.draw
  state.isOpaque=true
  state.letterboxWhite=true
  state.bgMode=function()return "black"end
  state.uiSize=function()return WIDTH,HEIGHT end
  state.isWideBattleLayout=function()return true end
  state.wantsFillScale=function()return true end
  state.drawsWidescreen=function()return true end
  state.sgbPalettes=function()return {{colors=false,x=0,y=0,w=WIDTH,h=HEIGHT}}end
  state.draw=draw
  state.drawWidescreen=function(self,ww,wh)
    if not tonumber(ww) or not tonumber(wh)then return draw(self)end
    local g=love.graphics;local scale=math.min(ww/WIDTH,wh/HEIGHT)
    g.push("all");g.origin();g.setShader();g.setScissor()
    g.setColor(.025,.055,.12,1);g.rectangle("fill",0,0,ww,wh)
    g.translate((ww-WIDTH*scale)/2,(wh-HEIGHT*scale)/2);g.scale(scale,scale)
    local ok,err=pcall(draw,self);g.pop();if not ok then error(err,0)end
  end
  modals(state,record)
  V.require("MobileMenuPresentation").attach(state,{
    owner="evolution",logicalW=WIDTH,logicalH=HEIGHT,backdrop={.025,.055,.12},
    drawLogical=draw,
  })
end
function M.decorate(state)
  if not M.isEvolutionState(state)then return state,false,"not-evolution"end
  if owned[state]then return state,false,"already-decorated"end
  local record={style="current",oldMon=copyMon(state.mon,state.mon.species),newMon=copyMon(state.mon,state.newSpecies)}
  for i,s in ipairs(stack(state))do
    if s==state then
      local intro=stack(state)[i-1]
      if intro and intro.isTextBox and intro.stay then record.intro=intro end
      break
    end
    if s.player and s.enemy then record.style=V.require("BattleSpriteControl").choice(s)end
  end
  local options=state.game.save and state.game.save.options
  local kasc=options and options.modOptions and options.modOptions.kanto_ascendant
  if record.style=="current" and kasc and kasc.pokemon_sprite_style=="original"then record.style="original"end
  if record.style=="current" and V.require("BattleSpriteControl").setting:get()==true then record.style="hd"end
  for _,id in ipairs{"kanto_ascendant","trainer_rematch"}do
    local ok,h=pcall(V.mod.find,id)
    if not ok or not h then ok,h=pcall(V.mod.find,V.mod,id)end
    if ok and h and h.exports and h.exports.crystalAnimation then record.crystal=h.exports.crystalAnimation;break end
  end
  if record.style~="original" and record.crystal then
    for _,key in ipairs{"old","new"}do
      local mon=record[key.."Mon"]
      local ok,art=pcall(record.crystal.presentationAnimation,mon.species,mon,"front","scenes",
        {data=state.game.data,trim=true,forceStyle=record.style=="crystal"})
      if ok then record[key.."Crystal"]=art end
    end
  elseif record.style=="original" then
    for _,key in ipairs{"old","new"}do
      local def=state.game.data.pokemon[record[key.."Mon"].species]
      if def and def.spriteFront then
        local ok,img=pcall(love.graphics.newImage,def.spriteFront)
        if ok then record[key.."Sprite"]=img end
      end
    end
  end
  if record.style~="original" then
    for _,key in ipairs{"old","new"}do
      if not record[key.."Crystal"] then
        local r=V.require("Gen2CrystalFronts").resolve(state.game,record[key.."Mon"])
        if r then
          local ok,img=pcall(love.graphics.newImage,r.path)
          if ok then record[key.."Sprite"]=img;record[key.."TrueColor"]=r.trueColor end
        end
      end
    end
  end
  claimSurface(state,record)
  return state,true
end
function M.install(mod)
  if installed then return true end
  if not(mod and mod.events and type(mod.events.on)=="function")then return false,"screen-events-unavailable"end
  eventUnregister[#eventUnregister+1]=mod.events:on("screen.pushed",function(event)
    M.decorate(event and event.state)
    for state,record in pairs(owned)do modals(state,record)end
  end,-11000)
  eventUnregister[#eventUnregister+1]=mod.events:on("screen.popped",function(event)
    local state=event and event.state
    local record=state and owned[state]
    if not record then return end
    owned[state]=nil
    -- The engine pops the movie before learnEvolutionMoves, but deliberately
    -- retains its intro until that entire callback chain completes. Keep only
    -- our presentation on that existing owner; never add/pop gameplay states.
    if not record.movie and record.intro and state.done then
      for _,remaining in ipairs(stack(state))do
        if remaining==record.intro then
          record.movie=state
          claimSurface(remaining,record)
          break
        end
      end
    end
  end)
  installed=true;return true
end
function M.health()return {schema=M.schema,ok=installed,state=installed and "active"or"inactive",eventRegistered=installed}end
function M.deactivate()
  for state,record in pairs(owned)do
    for _,key in ipairs(fields)do rawset(state,key,record.original[key])end
    state.__vascEvolutionPresentation=nil
    owned[state]=nil
  end
  for _,off in ipairs(eventUnregister)do if type(off)=="function"then off()end end
  eventUnregister={};installed=false;return true
end
return M
