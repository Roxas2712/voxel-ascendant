-- Gen2 capture units, using the same bounded species curve and fixed source
-- reference as Gen1. Geometry, shadows and projections all consume pixelWorld.
local V=...
local Size=V.require('BattleSpriteSize')
-- Gen1's normalized artwork uses one 16-unit tile, not Gen2's historical
-- 32-unit raw-card enlargement. Applying both enlargements doubled every
-- normalized Pokémon again, especially on the Terrarium's 1.8x stage.
local M={pixelWorld=16/56}
function M.apply(tex,def,sourceExtent,sourceKey,nativeDex)
  if tex.trainer or tex.trainerArt then return tex end
  local entry=type(def)=='table'and(def.dexEntry or def.pokedex)or{}
  local metres=tonumber(entry.heightM)
  local inches=metres and metres/.0254 or ((tonumber(entry.heightFt)or 0)*12+(tonumber(entry.heightIn)or 0))
  -- Native Gen2 stores feet and inches as FFII (e.g. Abra 211 = 2 ft 11 in).
  local nativeHeight=type(nativeDex)=="table" and tonumber(nativeDex.height)
  if inches<=0 and nativeHeight then inches=math.floor(nativeHeight/100)*12+nativeHeight%100 end
  tex.heightIn=inches>0 and inches or nil
  tex.vascReferenceExtent=sourceExtent
  tex.vascSpriteSourceKey=sourceKey
  local extent=Size.referenceExtent(tex)
  tex.pixelWorld=M.pixelWorld*(extent and 50/extent or 1)*Size.speciesScale(tex.heightIn)
  return tex
end
return M
