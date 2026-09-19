-- Render-only immersion. Native cells, routes and the player's SURF owner
-- remain authoritative. A swimmer on land must still stand normally.
local V=...
local M={}
M.setting=V.require('ModSetting').new('waterActors','SWIMMING',{true,false},{'ON','OFF'},true)
-- Aquatic species which can rest at the surface. Flying/levitating followers
-- and land species are deliberately not pushed under water.
local aquatic={}
for _,dex in ipairs({7,8,9,54,55,60,61,62,72,73,79,80,86,87,90,91,
  98,99,116,117,118,119,120,121,129,130,131,134,138,139,140,141,
  158,159,160,170,171,183,184,186,194,195,199,211,222,223,224,226,230})do aquatic[dex]=true end

function M.kind(p)
 local e=p.entity;local d=p.sprite and p.sprite.def or{}
 if p.isPlayer or not e or e.surfing or e.hopStep or e.hopping then return end
 local dex=tonumber(d.ascendantPokemonDex or d.pokemonDex or e.ascendantPokemonModelDex)
 -- Respect the spawn owner's swimming registry, including species beyond
 -- the original dex. Static aquatic identities also cover imported followers.
 if dex then return (e.spriteKind=='swimming' or aquatic[dex]) and 'pokemon' or nil end
 local obj=e.def or{}
 if obj.sprite=='SPRITE_SWIMMER' or obj.trainerClass=='OPP_SWIMMER'
   or d.ascendantRole=='swimmer' or d.ascendantRole=='swimmer-female-gen2' then return 'human' end
end

function M.prepare(state,posed)
 local enabled=M.setting:get()==true
 local now=love and love.timer and love.timer.getTime and love.timer.getTime() or 0
 for _,p in ipairs(posed)do
  local kind=(enabled or p.fossilPoolSpecies) and M.kind(p);local map
  if kind then
   if p.mapId==state.map.id then map=state.map
   else for _,g in ipairs(state.ghosts or{})do if g.map and g.map.id==p.mapId then map=g.map;break end end end
  end
  if kind and map and type(map.isWaterCell)=='function' then
   local e=p.entity
   -- Use the owner's local coordinates, not a connected map's world offset.
   local x,y=math.floor((e.px+8)/16),math.floor((e.py+8)/16)
   if map:isWaterCell(x,y) then
    local shapes=V.require('TileShape').forMap(map)
    local shape=shapes.classes and shapes.classes.water
    local height=shape and shape.h or -2
    local base=V.require('ChunkMesher').elevation(map)
    p.waterline=(base and base:at(x,y) or 0)+height
    -- Human shoulders/neck remain visible. Pokemon keep their upper body;
    -- shared sheets are never edited, and the shader clips submerged limbs.
    local depth=kind=='human' and 9 or 6
    local bob=math.sin(now*2.1+e.px*.73/16+e.py*.41/16)*.35
    p.swimBob=bob
    p.lift=p.waterline-depth+bob-p.gh
    p.swimming=kind
   end
  end
 end
end
return M
