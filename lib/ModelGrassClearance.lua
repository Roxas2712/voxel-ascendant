-- A small model parts only the grass immediately around its feet. This
-- keeps Wilds sprite-sized bodies readable without enlarging the Pokémon.
local M={LIMIT=16}
M.GLSL=[[
uniform int modelGrassCount;
uniform vec4 modelGrassFeet[16]; // world x, ground y, world z, local radius
vec4 modelGrassPosition(vec4 w) {
  float bend=0.0;
  for(int i=0;i<16;i++) {
    if(i>=modelGrassCount) break;
    vec4 f=modelGrassFeet[i];
    float h=w.y-f.y;
    if(h>0.0 && h<=8.1) {
      vec2 delta=w.xz-f.xz;
      float nearFoot=1.0-smoothstep(f.w*.45,f.w,length(delta));
      bend=max(bend,h*.78*nearFoot);
    }
  }
  w.y-=bend;
  return w;
}
]]
function M.rows(posed)
 local rows={}
 for _,p in ipairs(posed or {})do
  local b=p.stadiumBounds
  if p.stadiumMon and p.entity and p.entity.ascendantPokemonModelSource=='cobblemon'
      and not p.swimming and b and b[5]-b[2]<12 then
    -- The actual animated body footprint, not distance to the player.
    rows[#rows+1]={(b[1]+b[4])*.5,p.gh or 0,(b[3]+b[6])*.5,
      math.max(6,math.min(10,math.max(b[4]-b[1],b[6]-b[3])*.5+3))}
    if #rows==M.LIMIT then break end
  end
 end
 return rows
end
return M
