-- The far visibility boundary meets the air colour, never a black cutout.
-- IndoorMist separately renders the depth-tested drifting volume.
local V=...
local M={color={.30,.34,.37,1},towerColor={.34,.33,.39,2}}
function M.forView(map,view)
 if not view or not view.reach or not map or not map.def
  or map.def.generation==2 then return nil end
 if map.def.tileset=='CAVERN'then return M.color end
 if V and V.require('TowerAtmosphere').active(map)then return M.towerColor end
end
M.GLSL=[[
uniform vec4 caveBattleMist;
vec3 caveBattleFade(vec3 rgb, vec3 world) {
 if(caveBattleMist.a>0.5 && roomMaskSize.z>0.5) {
  vec2 uv=world.xz/roomMaskSize.xy;
  // Outside native map bounds the enclosure fades into the same opaque
  // colour as the framebuffer. Actual actors disable roomMaskSize.
  bool tower=caveBattleMist.a>1.5;
  bool insideMap=uv.x>=0.0 && uv.y>=0.0 && uv.x<1.0 && uv.y<1.0;
  // The tower panorama encloses a finite room; do not erase its walls.
  if(tower && !insideMap)return rgb;
  float reach=1.0;
  if(uv.x>=0.0 && uv.y>=0.0 && uv.x<1.0 && uv.y<1.0)
   reach=Texel(roomMask,uv).g;
  float distanceFade=smoothstep(tower ? 0.60 : 0.25,1.0,reach);
  // Native borders can end before the distance limit. Fade the last ground
  // cell too, instead of retaining a sharp cut against the empty backdrop.
  vec2 edge=min(world.xz,roomMaskSize.xy-world.xz);
  float borderFade=1.0-smoothstep(0.0,16.0,min(edge.x,edge.y));
  if(tower)borderFade=0.0;
  rgb=mix(rgb,caveBattleMist.rgb,max(distanceFade,borderFade));
 }
 return rgb;
}
]]
return M
