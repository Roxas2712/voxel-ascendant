-- Sparse silhouettes on the sea horizon. Geometry shares OutdoorHorizon's
-- palette/batches and never becomes a tile, collision or shadow caster.
local V=...
local M={}
local specs={
 ROUTE_21={{edge='east',along=96,kind='island',reach=240},
           {edge='east',along=800,kind='town',reach=240}},
 ROUTE_20={{edge='south',along=240,kind='town',reach=224},
           {edge='south',along=880,kind='islands',reach=256}},
 ROUTE_19={{edge='east',along=480,kind='town',reach=240}},
 CINNABAR_ISLAND={{edge='west',along=32,kind='volcano',reach=768}},
 ROUTE_12={{edge='east',along=800,kind='town',reach=352}},
 ROUTE_13={{edge='east',along=96,kind='islands',reach=352}},
 ROUTE_14={{edge='east',along=576,kind='island',reach=352}},
 VERMILION_CITY={{edge='south',along=320,kind='town',reach=240}},
}
local sizes={island={128,96},islands={144,104},town={144,96},volcano={320,384}}
local function overlap(x,z,w,d,r,pad)
 return x<r.x1+pad and x+w>r.x0-pad and z<r.z1+pad and z+d>r.z0-pad
end
function M.geometry(maps,horizon,emit,yieldStep,worldMaps)
 local eligible=false
 for _,e in ipairs(maps)do if e.map and e.map.def and e.map.def.generation~=2 and specs[e.map.id]then eligible=true;break end end
 if not eligible then return end
 local placement=V.require('WorldPlacement')
 local root=maps[1];local rp=worldMaps and placement.position(root.map.id,worldMaps)
 local protected={}
 for _,e in ipairs(maps)do protected[#protected+1]=e end
 -- Include unloaded playable maps: loading a neighbour must never replace a
 -- previously fake island. An inconsistent edited world fails closed.
 if worldMaps and not rp then return end
 if rp then
  for id,def in pairs(worldMaps)do
   local p=placement.position(id,worldMaps)
   if p and p.anchor==rp.anchor then
    local x,z=p.x+root.ox-rp.x,p.y+root.oy-rp.y
    protected[#protected+1]={x0=x,z0=z,x1=x+def.width*32,z1=z+def.height*32}
   end
  end
 end
 local emitted={}
 for _,e in ipairs(maps)do
  local id=e.map.id;local def=e.map.def
  for _,s in ipairs(def and def.generation~=2 and specs[id]or{})do
   local along=s.along
   local len=(s.edge=='west'or s.edge=='east')and e.h or e.w
   if along<len and horizon.edgeClass(e.map,s.edge,along)=='open_water'then
    local w,d=unpack(sizes[s.kind]);local x,z=e.x0,e.z0
    if s.edge=='east'then x,z=e.x1+s.reach,e.z0+along
    elseif s.edge=='west'then x,z=e.x0-s.reach,e.z0+along
    else x,z=e.x0+along,e.z1+s.reach end
    local clear=true
    for _,r in ipairs(protected)do if overlap(x,z,w,d,r,32)then clear=false;break end end
    local key=id..':'..s.kind..':'..along
    if clear and not emitted[key]then
     emitted[key]=true
     local function b(dx,y,dz,bw,bh,bd,c)emit(x+dx,y,z+dz,bw,bh,bd,c,false)end
     -- Foundations penetrate below the shared sea plane, never hover above it.
     b(8,-20,8,w-16,24,d-16,9)
     b(0,-12,24,w,14,d-48,9)
     b(24,0,16,w-48,7,d-32,21)
     if s.kind=='volcano'then
      -- Broad weathered cone, asymmetric shoulders and an actual recessed
      -- crater ring. No fire particles or lights in the distant scenery.
      for tier=0,7 do
       local ix=math.floor(tier*17/4)*4;local iz=math.floor(tier*21/4)*4
       local shift=tier%3*3
       local tw,td=w-16-ix*2,d-16-iz*2
       local cut=math.floor(math.min(tw,td)*.22/4)*4
       local tone=tier%3==0 and 18 or 5
       b(8+ix+cut,4+tier*20,8+iz+shift,tw-cut*2,20,td,tone)
       b(8+ix,4+tier*20,8+iz+shift+cut,cut,20,td-cut*2,5)
       b(8+ix+tw-cut,4+tier*20,8+iz+shift+cut,cut,20,td-cut*2,9)
      end
      b(24,4,48,96,44,112,5);b(208,4,224,80,54,112,9)
      local cx,cz=w/2,d/2
      b(cx-24,164,cz-18,48,5,36,30)
      b(cx-32,160,cz-32,64,18,10,5);b(cx-32,160,cz+14,64,14,10,9)
      b(cx-34,160,cz-22,10,19,36,9);b(cx+28,160,cz-22,10,16,36,5)
     elseif s.kind=='town'then
      for i=0,4 do
       local bx=18+i*23;local bz=22+i%2*22;local h=12+(i*7)%12
       b(bx,7,bz,18,h,22,i%2==0 and 18 or 24)
       b(bx-2,7+h,bz-2,22,4,26,i%2==0 and 28 or 30)
       b(bx+2,11+h,bz+2,14,3,18,i%2==0 and 28 or 30)
      end
      b(42,7,18,12,34,12,18);b(39,41,15,18,5,18,30)
     else
      local count=s.kind=='islands'and 3 or 2
      for i=0,count-1 do
       local bx=16+i*34;local bz=20+i%2*24;local h=24+(i*13)%25
       b(bx,5,bz,44,h*.55,42,9)
       b(bx+5,5+h*.55,bz+4,32,h*.3,30,5)
       b(bx+12,5+h*.85,bz+10,18,h*.15+4,18,21)
      end
     end
    end
   end
   if yieldStep then yieldStep()end
  end
 end
end
return M
