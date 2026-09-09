-- The four static native boulders in Crystal Cianwood Gym.
-- Production module; placement is activated only by the explicit Structures hook.
-- Moving Strength objects and their puzzle scripts are deliberately untouched.
local V=...
local R={}
local source=V.require('Gen2PewterRocks')
local positions={{2,6},{6,6},{2,7},{6,7}}
local art={4,5,20,21}
local function key(x,y)return(y+64)*4096+x+64 end
function R.matches(map,x,y)
 local d=map and map.def
 if not(d and map.id=='CIANWOOD_GYM' and d.generation==2
  and d.tileset=='TILESET_TOWER' and d.width==5 and d.height==9
  and d.environment=='INDOOR' and not d.outdoor and not next(d.connections or{}))then return false end
 if not((x==2 or x==6)and(y==6 or y==7))then return false end
 if map:cellCollision(x,y)~=7 or map:isWarpTileCell(x,y)then return false end
 for dy=0,1 do for dx=0,1 do
  if map:tileAt(x*2+dx,y*2+dy)~=art[dy*2+dx+1]then return false end
 end end
 return true
end
function R.find(map)
 local out={};for _,p in ipairs(positions)do
  if R.matches(map,p[1],p[2])then out[#out+1]={x=p[1],y=p[2]}end
 end;return out
end
-- Cianwood uses the identical Tower glyph. Reuse its fully glyph-guarded
-- rounded 12px model, not the Pewter placement contract or copied geometry.
function R.model(atlas,unmerged,budget)return source.model(atlas,unmerged,budget)end
function R.build(S,map,atlas,budget)
 local targets={}
 for _,p in ipairs(R.find(map))do
  local free=true;for dy=0,1 do for dx=0,1 do
   if S.skip[key(p.x*2+dx,p.y*2+dy)]then free=false end
  end end
  if free then targets[#targets+1]=p end
 end
 if #targets==0 then return 0 end
 local model=R.model(atlas,false,budget);if not model then return 0 end
 for _,p in ipairs(targets)do
  S.roundStamps[#S.roundStamps+1]={quads=model,mx=p.x*16+8,my=0,mz=p.y*16+8,r=8}
  for dy=0,1 do for dx=0,1 do local k=key(p.x*2+dx,p.y*2+dy)
   S.skip[k]=true;S.ground[k]=false
   S.shapeAt[k]={class='building',art='building',h=0,flat=false,authored=true}
  end end
 end
 return #targets
end
return R
