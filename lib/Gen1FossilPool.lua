-- Fuchsia's live zoo exhibit. Only captured voxel poses are replaced;
-- the native object, fossil flags, sign and collision grid keep their owners.
local V=...
local M={}
local cache=setmetatable({},{__mode='k'})
function M.species(flags)
  flags=flags or {}
  if flags.EVENT_GOT_DOME_FOSSIL then return 'OMANYTE',138 end
  if flags.EVENT_GOT_HELIX_FOSSIL then return 'KABUTO',140 end
end
function M.matches(p)
  local d=p.entity and p.entity.def
  return p.mapId=='FUCHSIA_CITY' and d and d.name=='FUCHSIACITY_FOSSIL'
    and d.sprite=='SPRITE_FOSSIL' and not p.isPlayer
end
function M.position(map,x,y,time)
  if not map:isWaterCell(x,y) then return end
  -- Find a rectangular swimming area wholly contained in this pool. Never
  -- follow a bounding box across a concave bank or an adjacent water body.
  local l,r,t,b=x,x,y,y
  while l>x-8 and map:isWaterCell(l-1,y) do l=l-1 end
  while r<x+8 and map:isWaterCell(r+1,y) do r=r+1 end
  local function row(cy)
    for cx=l,r do if not map:isWaterCell(cx,cy) then return false end end
    return true
  end
  while t>y-8 and row(t-1) do t=t-1 end
  while b<y+8 and row(b+1) do b=b+1 end
  local rx=math.max(0,((r-l+1)*16-20)/2)
  local rz=math.max(0,((b-t+1)*16-20)/2)
  local a=(time or 0)*.65
  local px=(l+r+1)*8-8+math.cos(a)*rx
  local py=(t+b+1)*8-8+math.sin(a)*rz
  local dx,dz=-math.sin(a)*rx,math.cos(a)*rz
  local facing=math.abs(dx)>math.abs(dz) and (dx<0 and 'left' or 'right')
    or (dz<0 and 'up' or 'down')
  return px,py,facing
end
local function card(game,species,dex)
  local path,tc=require('src.pokemon.Sprites').path(game.data,species,'front',{kind='overworld'})
  if not path then return end
  local A=require('src.render.Assets')
  local image=A.image(path)
  if not tc then
    local P=require('src.render.PaletteFX')
    local colors=P.monPal(game.data,species) or {{255,255,255},{170,170,170},{85,85,85},{0,0,0}}
    image=require('src.render.SpriteRenderer').obpImage(path,colors,'fossil-pool:'..species..':'..tostring(P.monPalName(game.data,species)))
  end
  local w,h=image:getDimensions()
  return {def={id='VASC_FOSSIL_POOL_'..species,image=path,frames=1,
    frameWidth=w,frameHeight=h,trueColor=true,pokemonDex=dex},image=image,
    resolveImage=function()return image end}
end
function M.prepare(state,posed,game)
  if not (state.map and state.map.id=='FUCHSIA_CITY' and game) then return end
  local species,dex=M.species(game.save and game.save.flags)
  if not species then return end -- Native pre-choice exhibit is undetermined.
  local now=love.timer.getTime()
  for _,p in ipairs(posed) do if M.matches(p) then
    local original=p.entity
    local x,y=math.floor((original.px+8)/16),math.floor((original.py+8)/16)
    local px,py,facing=M.position(state.map,x,y,now)
    if px then
      local slot=cache[original]
      if not slot or slot.species~=species then
        local ok,sprite=pcall(card,game,species,dex)
        if ok and sprite then
          slot={species=species,sprite=sprite,entity={ascendantPokemonModelSource='stadium2',
            ascendantPokemonModelDex=dex,pokemonModel=true,stadiumModel=true,spriteKind='swimming'}}
          cache[original]=slot
        end
      end
      if slot and slot.species==species then
        slot.entity.px,slot.entity.py=px,py
        p.entity,p.sprite=slot.entity,slot.sprite
        p.px,p.py,p.facing=px,py,facing
        p.phase,p.flip,p.colors=0,false,nil
        p.fossilPoolSpecies=species
      end
    end
  end end
end
return M
