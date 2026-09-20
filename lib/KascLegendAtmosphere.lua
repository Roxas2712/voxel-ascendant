-- Exact reviewed KASC rooms/routes. Native puzzles, palettes used by gameplay,
-- encounters, and dark/FLASH state remain owned by the original scripts.
local M={}
local groups={
 ember={tileset='CAVERN',ids={'KA_HEVO_GROUDON_CHAMBER','KA_HEVO_RED_UPPER','KA_HEVO_RED_ABYSS','KA_HEVO_RED_RECOVERY','KA_HEVO_RED_LOWER','KA_HEVO_RED_SHRINE'},
  color={.46,.30,.23},density=.013,height=42},
 tide={tileset='CAVERN',ids={'KA_HEVO_KYOGRE_CHAMBER','KA_HEVO_BLUE_TIDAL_DEPTHS','KA_HEVO_BLUE_KYOGRE_SHRINE'},
  color={.28,.44,.51},density=.014,height=38,crystals=true},
 frost={tileset='CAVERN',ids={'KA_HEVO_BLUE_FROST_THRESHOLD','KA_HEVO_BLUE_FROST_HALL','KA_HEVO_BLUE_GLACIER_MAZE'},
  color={.48,.61,.67},density=.012,height=34,crystals=true},
 grove={tileset='FOREST',ids={'KA_HEVO_GREEN_THRESHOLD','KA_HEVO_GREEN_GROVE','KA_HEVO_GREEN_MIST','KA_HEVO_GREEN_RAYQUAZA_SHRINE'},
  color={.35,.47,.40},density=.010,height=38},
}
local maps={}
for key,p in pairs(groups)do p.kind=key;for _,id in ipairs(p.ids)do maps[id]=p end end
function M.profile(map)
 local d=map and map.def
 local p=d and maps[map.id or d.id]
 if p and d.generation~=2 and d.tileset==p.tileset then return p end
end
-- Only ordinary CAVERN floor block 25. Water, ice, stairs, switches,
-- authored glyphs and collision-bearing rock blocks retain their identity.
function M.material(map,x,y)
 local profile=M.profile(map)
 if not(profile and profile.tileset=='CAVERN'and x and y)then return nil end
 local d=map.def
 if not(d.blocks and d.width)then return nil end
 if x<0 or y<0 or x>=d.width*4 or y>=d.height*4 then return nil end
 local cx,cy=math.floor(x/2),math.floor(y/2)
 if not map:isWalkableCell(cx,cy)or map:isWaterCell(cx,cy)then return nil end
 if map.warpAtCell and map:warpAtCell(cx,cy)then return nil end
 local block=d.blocks[math.floor(y/4)*d.width+math.floor(x/4)+1]
 if block~=25 then return nil end
 return profile.kind=='ember'and -177 or profile.kind=='frost'and -181 or -180
end
return M
