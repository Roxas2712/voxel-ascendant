-- Exterior route-gate entrances are defined by the original map warps.
-- They are visual facade stamps only; collision and warp data stay untouched.
local M={}
local gates={ROUTE_2_GATE=true,ROUTE_5_GATE=true,ROUTE_6_GATE=true,
 ROUTE_7_GATE=true,ROUTE_8_GATE=true,ROUTE_11_GATE_1F=true,
 ROUTE_12_GATE_1F=true,ROUTE_15_GATE_1F=true,ROUTE_16_GATE_1F=true,
 ROUTE_18_GATE_1F=true,ROUTE_22_GATE=true,
 VIRIDIAN_FOREST_NORTH_GATE=true,VIRIDIAN_FOREST_SOUTH_GATE=true,SAFARI_ZONE_GATE=true}
local function group(warps,axis,value,other,lo,hi)
 local found,seen,dest={}, {},nil
 for _,w in ipairs(warps or {})do
  if w[axis]==value and type(w[other])=='number' and w[other]>=lo and w[other]<hi
      and gates[w.destMap] and type(w.destWarp)=='number' then
   if dest and dest~=w.destMap or seen[w[other]] then return nil end
   dest=w.destMap;seen[w[other]]=w;found[#found+1]=w[other]
  end
 end
 table.sort(found)
 if #found<1 or #found>2 or (#found==2 and found[2]~=found[1]+1) then return nil end
 return {start=found[1],count=#found,dest=dest,warp=seen[found[1]]}
end
function M.forBuilding(map,tx,ty,bw,bh)
 local def=map and map.def
 if not def or def.tileset~='OVERWORLD' then return {} end
 local x,y,w,h=tx/2,ty/2,bw/2,bh/2
 local west=group(def.warps,'x',x-1,'y',y,y+h)
 local east=group(def.warps,'x',x+w,'y',y,y+h)
 local doors={}
 if west and east and west.dest==east.dest and west.start==east.start
     and west.count==east.count then
  for _,side in ipairs{'west','east'}do
   doors[#doors+1]={side=side,x=side=='west' and -0.02 or bw*8+0.02,
    z=(west.start-y)*16,width=west.count*16,tiles={11,12,27,28}}
  end
 end
 local south=group(def.warps,'y',y+h-1,'x',x,x+w)
 if south then
  doors[#doors+1]={side='south',x=(south.start-x)*16,z=bh*8+0.02,
   width=south.count*16,tiles={11,12,27,28}}
 end
 local north=group(def.warps,'y',y-1,'x',x,x+w)
 if north then doors.north={x=(north.start-x)*16,width=north.count*16,warp=north.warp} end
 return doors
end
return M
