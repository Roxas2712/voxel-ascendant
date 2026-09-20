-- Vermilion Gym / Lt. Surge. Compact interior for integration by PANDY.
-- Visual direction: ODias; supplied HGSS, Let's Go and Thunder Badge images.
-- Reuse the host bowl, camera, participants, trainer plinths and branding.
local V={revision='vermilion-compact-v1'}
local steel={.37,.45,.45}
local dark={.16,.22,.24}
local silver={.67,.74,.72}
local gold={.96,.68,.13}
local paleGold={1,.85,.32}
local red={.72,.16,.17}
local blue={.15,.39,.68}
local cyan={.31,.88,1}

function V.appliesTo(mapId)return mapId=='VERMILION_GYM'end

function V.button(h)
 local q=h.quad
 local function p(a,r,d)return{math.cos(a)*r,-7+math.sin(a)*r,78.35+d}end
 local center={0,-7,78.35}
 -- Eight yellow lobes around a faceted orange central stone.
 for i=0,7 do
  local a=math.pi/2+i*math.pi/4
  local left,tip,right=p(a-.38,6.25,0),p(a,8.35,0),p(a+.38,6.25,0)
  q(center,left,tip,right,{.09,.11,.12})
  local l,t,r=p(a-.365,6.14,.03),p(a,8.08,.03),p(a+.365,6.14,.03)
  local il,ir=p(a-.39,4.92,.03),p(a+.39,4.92,.03)
  q(il,l,t,ir,paleGold)
  q(ir,t,r,ir,{1,1,.48})
  q(p(a-.385,4.85,.05),p(a-.38,6.07,.05),p(a+.38,6.07,.05),p(a+.385,4.85,.05),i%2==0 and{1,.61,.02}or{1,.75,.07})
  q(center,p(a-.39,4.73,.07),p(a+.39,4.73,.07),center,{1,.37,.02})
 end
 q({-2.6,-9.9,78.46},{-1.6,-10.6,78.46},{1.4,-3.1,78.46},{.1,-2.9,78.46},{1,.80,.76})
 q({.2,-10.9,78.47},{.7,-10.8,78.47},{3,-4.4,78.47},{2.3,-3.8,78.47},{1,.80,.76})
end

function V.build(h,setup)
 local box,quad=h.box,h.quad
 local function rect(x,z,w,d,y,c)
  quad({x-w/2,y,z-d/2},{x+w/2,y,z-d/2},{x+w/2,y,z+d/2},{x-w/2,y,z+d/2},c)
 end
 local function clear(x,z,w,d)
  for _,p in pairs(setup.trainers)do
   if math.abs(p[1]-x)<w/2+8 and math.abs(p[3]-z)<d/2+8 then return false end
  end
  for _,p in pairs(setup.actors)do
   if math.abs(p[1]-x)<w/2+11 and math.abs(p[3]-z)<d/2+10 then return false end
  end
  return true
 end
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},{math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},dark)
 end
 -- Modular metal plates with rivets and raised diamond tread.
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(x*7+z*13+2000)%4
   rect(x,z,7.75,7.75,.03,({{.38,.44,.42},{.41,.47,.45},{.44,.49,.46},{.40,.46,.44}})[n+1])
   for _,dx in ipairs({-2,2})do for _,dz in ipairs({-2,2})do
    local a=x+dx;local b=z+dz
    quad({a-1,.044,b-.55},{a-.7,.044,b-.83},{a+1,.044,b+.55},{a+.7,.044,b+.83},{.53,.60,.57})
   end end
   rect(x-3.05,z-3.05,.35,.35,.046,silver)
  end
 end end
 -- Low yellow-and-black boundary strips leave the central battle floor open.
 for _,s in ipairs({-1,1})do
  rect(s*46,0,2,77,.05,gold)
  for z=-36,36,6 do rect(s*46,z,2,2.7,.055,dark)end
 end
 -- Faceted cylinders: oil drums, bins and electric pylons share this helper.
 local function cylinder(x,y,z,r,height,c,axis)
  local function at(a,rr,t)
   if axis=='x'then return{x+t-height/2,y+r+math.cos(a)*rr,z+math.sin(a)*rr}end
   return{x+math.cos(a)*rr,y+t,z+math.sin(a)*rr}
  end
  for i=0,11 do local a,b=i*math.pi/6,(i+1)*math.pi/6
   quad(at(a,r,0),at(b,r,0),at(b,r,height),at(a,r,height),c,.72+(i%4)*.07)
   quad(at(0,0,height),at(a,r,height),at(b,r,height),at(0,0,height),c,1)
  end
 end
 local function barrel(x,z,c,axis)
  local r,height=4.4,11
  cylinder(x,.05,z,r,height,c,axis)
  if axis=='x'then
   for _,xx in ipairs({x-4.7,x,x+4.7})do cylinder(xx,.05,z,r+.13,.6,silver,'x')end
  else
   for _,yy in ipairs({.6,5.4,10.5})do cylinder(x,yy,z,r+.15,.5,silver)end
   cylinder(x+1.4,11.1,z+.5,.65,.24,dark)
  end
 end
 -- HGSS-inspired bin rows, clipped around the actual participant anchors.
 for _,z in ipairs({-24,0,24})do for _,x in ipairs({-34,-17,0,17,34})do
  if clear(x,z,7,7)then
   cylinder(x,.05,z,3.15,5.7,steel)
   cylinder(x,5.75,z,3.35,.5,silver)
   cylinder(x,6.25,z,2.7,.03,dark)
   box(x,2.4,z+3.1,1.8,1,.25,gold)
   for _,dx in ipairs({-1.6,0,1.6})do box(x+dx,.65,z+2.65,.23,4,.3,silver)end
  end
 end end
 -- Brickwork and structural yellow beams form a short open backdrop.
 box(0,0,-63,65,29,2,{.35,.28,.22})
 for row=0,8 do for col=-5,5 do
  local x=col*6.1+(row%2)*3
  if math.abs(x)<31.5 then
   box(x,row*3.1+.15,-61.8,5.85,2.83,.5,({{.57,.28,.16},{.64,.32,.19},{.54,.25,.15},{.61,.29,.17}})[(row+col+20)%4+1])
  end
 end end
 for _,x in ipairs({-32,-16,16,32})do
  box(x,0,-60.9,1.9,29,2.1,gold)
  box(x-.4,0,-59.75,.4,29,.12,paleGold)
  box(x,0,-60,3.5,1.7,4,gold)
 end
 box(0,28.5,-62,66,.9,2.8,gold)
 -- Small graphic placards, built from coloured polygons rather than textures.
 for _,x in ipairs({-24,24})do
  box(x,16,-61.35,7,8,.13,{.85,.80,.62})
  box(x,17,-61.23,5.8,5.5,.08,x<0 and blue or gold)
  quad({x-2,21,-61.1},{x+.5,21,-61.1},{x-.6,19,-61.1},{x-2,19,-61.1},paleGold)
  quad({x-.6,19,-61.09},{x+2,19,-61.09},{x-1,17.5,-61.09},{x-.6,19,-61.09},paleGold)
 end
 -- Golden leader platform and front steps.
 box(0,0,-53,25,3.4,15,gold)
 box(0,3.4,-53,23,.4,13,paleGold)
 box(0,3.8,-53,18,.08,9,{.74,.46,.10})
 box(0,3.9,-53,16,.06,7,gold)
 box(0,0,-44.5,13,2,3,gold)
 box(0,0,-42,10,1,2,paleGold)
 -- Paired rows of static cyan arcs evoke the two original electric gates.
 for _,z in ipairs({-36,-41})do
  for _,x in ipairs({-8,8})do
   if clear(x,z,3,3)then
    cylinder(x,.06,z,1.8,3.8,steel)
    cylinder(x,3.86,z,1.9,1.1,cyan)
   end
  end
  for i=0,7 do
   local x1=-7+i*1.75;local x2=x1+1.75
   local y1=3.9+(i%2)*.8;local y2=3.9+((i+1)%2)*.8
   quad({x1,y1,z},{x2,y2,z},{x2,y2+.3,z},{x1,y1+.3,z},cyan)
  end
 end
 for _,v in ipairs({{-38,-47,red},{-48,-35,blue},{38,-47,blue},{48,-35,red},{-28,-53,blue},{28,-53,red}})do
  if clear(v[1],v[2],9,9)then barrel(v[1],v[2],v[3])end
 end
 if clear(-45,-19,12,9)then barrel(-45,-19,blue,'x')end
 -- Low entrance pedestals, styled after the two gym statues in HGSS.
 for _,x in ipairs({-13,13})do
  box(x,0,53,5.7,1.3,5.7,dark);box(x,1.3,53,5.1,1,5.1,silver)
  box(x,2.3,53,3,3.1,3,steel);box(x,5.4,53,3.4,2,3.1,silver)
  box(x,6.7,54.5,.8,1.1,1.4,silver)
 end
 rect(0,65,15,7,.05,dark)
 rect(0,65,13,5,.06,gold)
 rect(0,65,10,3,.07,{.72,.16,.12})
end
return V
