-- Native forest landmarks omitted by the generic outer-map skyline.
-- Geometry only: warp cells, collision and the eastern Route 2 bypass stay native.
local V=...
local M={}
function M.gates(maps,horizon)
 local result={}
 if not V.require('Gen1PalletVillage').buildings:get()then return result end
 for _,e in ipairs(maps)do for _,edge in ipairs({'north','south'})do
  if horizon.viridianForestGateVerified and horizon.viridianForestGateVerified(e.map,edge)then
   local spec=horizon.viridianForestGateSpec(edge);local p=spec.path
   local out=edge=='north'and -1 or 1
   local boundary=edge=='north'and 0 or e.h
   local x0,x1=e.ox+p.x0-16,e.ox+p.x1+16
   local z0,z1=e.oy+boundary+out*76,e.oy+boundary
   z0,z1=math.min(z0,z1),math.max(z0,z1)
   -- A custom resident map owns its own surface and must not be overlaid.
   local clear=true
   for _,other in ipairs(maps)do if other~=e and x0<other.x1 and x1>other.x0 and z0<other.z1 and z1>other.z0 then clear=false end end
   if clear then result[#result+1]={entry=e,edge=edge,out=out,boundary=e.oy+boundary,
     opening0=e.ox+p.x0,opening1=e.ox+p.x1,x0=x0,x1=x1,z0=z0,z1=z1}end
  end
 end end
 return result
end
function M.geometry(maps,horizon,emit,yieldStep)
 if V.require('Gen1OutdoorScenery').trees:get()then
  for _,e in ipairs(maps)do
   if horizon.route2ForestVerified and horizon.route2ForestVerified(e.map)then
    -- Dense overlapping crowns close the view at walking and survey height.
    -- Every box remains inside the verified blocked reserve, including lobes.
    local function b(x,y,z,w,h,d,c)
     w,d=math.min(w,216-x),math.min(d,600-z)
     if w>0 and d>0 then emit(e.ox+x,y,e.oy+z,w,h,d,c)end
    end
    for z=360,599,32 do for x=8,215,32 do
     local n=(math.floor(x/32)*3+math.floor(z/32)*7)%5
     local h=98+n*6
     b(x+13,0,z+13,6,h-30,6,4)
     b(x,34,z,32,h-46,32,1)
     b(x+2,h-22,z+2,28,22,28,2)
     b(x+7,h,z+6,20,10+n,20,3)
     b(x,h-12,z+8,10,12,20,2)
     if yieldStep then yieldStep()end
    end end
   end
  end
 end
 for _,gate in ipairs(M.gates(maps,horizon))do
  local x0,x1,a,b=gate.x0,gate.x1,gate.opening0,gate.opening1
  local z=gate.boundary;local out=gate.out
  local function box(x,y,d,w,h,depth,c,lit)
   local z0=z+out*d;local z1=z+out*(d+depth)
   emit(x,y,math.min(z0,z1),w,h,math.abs(z1-z0),c,lit)
  end
  -- Path and floor lead continuously through a wide framed passage.
  box(a,-1,0,b-a,1,72,10)
  for _,x in ipairs({x0,b})do
   box(x,0,16,16,4,48,18)
   box(x,4,16,16,30,48,15)
   box(x,6,15,3,29,2,14);box(x+13,6,15,3,29,2,14)
   box(x+4,14,14,8,12,1,11,true)
   box(x+7,14,13,2,12,1,14)
  end
  box(a-3,0,14,3,33,4,14);box(b,0,14,3,33,4,14)
  box(x0,31,14,x1-x0,5,52,14)
  -- Stepped pitched roof; warm timber and green tiles fit both forest exits.
  for tier=0,7 do
   box(x0-4+tier*2,36+tier,12,(x1-x0)+8-tier*4,1,56,2+(tier%2))
  end
  -- Small leaf relief on the lintel, no oversized text panel.
  local mid=(a+b)/2
  box(mid-5,32,11,10,3,2,10)
  box(mid-2,33,9,4,3,2,3)
  if yieldStep then yieldStep()end
 end
end
return M
