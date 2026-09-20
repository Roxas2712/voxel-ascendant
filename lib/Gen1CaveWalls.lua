-- Taller native rock at eye level; the original low wall remains the
-- dollhouse cutaway. Native shapes and actor/warp support never change.
local V=...
local P=V.require('Gen1CavePanoramas')
local M={extraHeight=16,tagOffset=1024}
function M.native(map)
 return map and map.def and map.def.tileset=='CAVERN'
   and map.def.generation~=2
   and (P.maps[map.id or map.def.id]~=nil or P.extensionMaps[map.id or map.def.id]~=nil)
end
function M.eligible(map,tx,ty)
 if not M.native(map) or tx<0 or ty<0 or tx>=map.def.width*4 or ty>=map.def.height*4 then return false end
 if type(map.isWalkableCell)~='function' or type(map.warpAtCell)~='function' then return false end
 local x,y=math.floor(tx/2),math.floor(ty/2)
 return not map:isWalkableCell(x,y) and not map:warpAtCell(x,y)
   and not (map.isWaterCell and map:isWaterCell(x,y))
end
function M.amount(map,level)
 return M.native(map) and (level==6 or level==7) and 1 or 0
end
function M.isRock(material)
 return type(material)=='number' and ((material<=-201 and material>=-206)
   or (material<=-211 and material>=-216))
end
-- The rock material derives UVs from world coordinates, leaving texture Y
-- available for the original 16px wall's top. Only tagged rock is cut down.
M.GLSL=[[
  uniform float caveWallsTall;
  vec4 caveWallPosition(vec4 p, vec2 uv) {
    bool rock=(uv.x<=-201.0 && uv.x>=-206.0)
      || (uv.x<=-211.0 && uv.x>=-216.0);
    if(rock && uv.y>512.0) {
      float top=uv.y-1024.0;
      p.y=mix(min(p.y,top),p.y,caveWallsTall);
    }
    return p;
  }
]]
return M
