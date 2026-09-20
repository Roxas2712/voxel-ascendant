-- Materials for the actual cave enclosure, never battle-background selection.
local M={sourceW=960,sourceH=320,textureW=1920,wallPeriod=960,ceilingSize=256}
M.families={}
for _,name in ipairs({'seafoam','rock_tunnel','diglett','victory_road','cerulean','mt_moon'})do
 local key='cave_'..name
 M.families[key]={asset=key..'Wall',path='assets/scenery/'..key..'_wall.compact.png'}
end
M.maps={}
local groups={seafoam={'SEAFOAM_ISLANDS_1F','SEAFOAM_ISLANDS_B1F','SEAFOAM_ISLANDS_B2F','SEAFOAM_ISLANDS_B3F','SEAFOAM_ISLANDS_B4F'},
 rock_tunnel={'ROCK_TUNNEL_1F','ROCK_TUNNEL_B1F'},
 diglett={'DIGLETTS_CAVE','DIGLETTS_CAVE_ROUTE_2','DIGLETTS_CAVE_ROUTE_11'},
 victory_road={'VICTORY_ROAD_1F','VICTORY_ROAD_2F','VICTORY_ROAD_3F'},
 cerulean={'CERULEAN_CAVE_1F','CERULEAN_CAVE_2F','CERULEAN_CAVE_B1F'},
 mt_moon={'MT_MOON_1F','MT_MOON_B1F','MT_MOON_B2F'}}
for name,ids in pairs(groups)do for _,id in ipairs(ids)do M.maps[id]='cave_'..name end end
-- Reviewed KASC maps authored on the native CAVERN blockset. Explicit IDs
-- avoid repainting unrelated custom tilesets or matching by a name prefix.
M.extensionMaps={
 KANTO_ASCENDANT_PRISM_GROTTO='cave_victory_road',
 KA_HEVO_BLUE_FROST_HALL='cave_seafoam',
 KA_HEVO_BLUE_FROST_THRESHOLD='cave_seafoam',
 KA_HEVO_BLUE_GLACIER_MAZE='cave_seafoam',
 KA_HEVO_BLUE_KYOGRE_SHRINE='cave_cerulean',
 KA_HEVO_BLUE_TIDAL_DEPTHS='cave_cerulean',
 KA_HEVO_GROUDON_CHAMBER='cave_diglett',
 KA_HEVO_KYOGRE_CHAMBER='cave_cerulean',
 KA_HEVO_RED_ABYSS='cave_rock_tunnel',
 KA_HEVO_RED_LOWER='cave_rock_tunnel',
 KA_HEVO_RED_RECOVERY='cave_rock_tunnel',
 KA_HEVO_RED_SHRINE='cave_rock_tunnel',
 KA_HEVO_RED_UPPER='cave_rock_tunnel',
 KA_HEVO_SHARED_SEALED_ANTECHAMBER='cave_victory_road',
 KA_HEVO_TUNNEL_ALL='cave_rock_tunnel',
 KA_HOENN_ANCIENT_TOMB='cave_victory_road',
 KA_HOENN_DESERT_RUINS='cave_diglett',
 KA_HOENN_ISLAND_CAVE='cave_seafoam',
 KA_HOENN_WISH_CHAMBER='cave_victory_road',
 KA_ROCKET_CERULEAN_RELAY_1F='cave_cerulean',
}
function M.materialFor(map)
 local def=map and map.def
 if not def then return nil end
 if def.runtimeAuthority=='KASC_6_7_STARTER_HABITAT_V2_3'and def.voxelOwner=='kanto_ascendant'
   and (def.tileset=='KA_HABITAT_STONE'or def.tileset=='KA_HABITAT_MYSTIC')then return 'cave_rock_tunnel'end
 if def.tileset=='KA_MOLTRES_VOLCANO_67'and def.kaOwner=='kasc.hoenn-moltres-volcano/v4'
  and(map.id=='KA_MOLTRES_VOLCANO_BASE'or map.id=='KA_MOLTRES_VOLCANO_ASCENT')then return 'cave_diglett'end
 if def.tileset~='CAVERN' then return nil end
 local id=map.id or def.id
 return M.maps[id] or M.extensionMaps[id]
end
function M.textureSize(g)
 local limit=M.textureW
 if g.getSystemLimits then
  local ok,limits=pcall(g.getSystemLimits)
  if ok and limits and type(limits.texturesize)=='number' then limit=math.min(limit,limits.texturesize) end
 end
 local width=math.max(2,math.floor(limit/2)*2)
 return width,math.max(1,math.floor(M.sourceH*width/M.textureW))
end
function M.wall(g,image,width,height)
 -- Reflect the continuation in the retained atlas: both the middle join and
 -- repeat boundary use identical edge texels, even for imperfect source art.
 -- This avoids hard joins without a translucent second layer in the world.
 g.setColor(1,1,1,1)
 width,height=width or M.textureW,height or M.sourceH
 local sx,sy=width/M.textureW,height/M.sourceH
 g.draw(image,0,0,0,sx,sy)
 g.draw(image,width,0,0,-sx,sy)
end
function M.ceiling(g,image)
 -- A square stone sample from the same material keeps the ceiling palette
 -- coherent. Mirroring in both axes closes both repeat seams. Static bake.
 local size=M.sourceH;local half=M.ceilingSize/2
 local quad=g.newQuad((M.sourceW-size)/2,0,size,size,M.sourceW,M.sourceH)
 g.setColor(.65,.65,.65,1)
 local scale=half/size
 for _,x in ipairs({0,M.ceilingSize})do for _,y in ipairs({0,M.ceilingSize})do
  g.draw(image,quad,x,y,0,x==0 and scale or -scale,y==0 and scale or -scale)
 end end
 if quad.release then quad:release()end
end
return M
