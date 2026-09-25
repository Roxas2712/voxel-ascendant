-- Team Rocket Hideout 1: compact industrial puzzle scene for integration by PANDY.
-- Visual direction: ODias; supplied industrial hideout concept art and Rocket R icon.
-- Reuse host bowl, camera, participants, trainer plinths and branding.
local R={revision='rocket-hideout-industrial-compact-v1'}
local maps={ROCKET_HIDEOUT_B1F=true,ROCKET_HIDEOUT_B2F=true,ROCKET_HIDEOUT_B3F=true}
function R.appliesTo(mapId)return maps[mapId]==true end
local black={.085,.095,.105}
local red={.57,.12,.15}
local trim={.77,.76,.70}
local wood={.37,.20,.12}

local function rocket(q,x,y,z,size)
 -- Approved reference silhouette, encoded as merged horizontal mesh strips.
 -- Coordinates: left, top, right, bottom; the counter remains open geometry.
 local width,height=127,128
 local spans={
  {2,0,90,1},
  {1,1,95,2},
  {0,2,99,3},
  {0,3,101,4},
  {0,4,104,5},
  {0,5,106,7},
  {0,7,107,8},
  {0,8,109,9},
  {0,9,110,10},
  {0,10,111,11},
  {0,11,113,13},
  {0,13,115,15},
  {0,15,116,16},
  {0,16,117,17},
  {0,17,118,18},
  {0,18,119,21},
  {0,21,120,22},
  {0,22,121,24},
  {0,24,123,26},
  {0,26,124,29},
  {0,29,125,34},
  {0,34,126,35},
  {0,35,38,56},
  {78,35,126,36},
  {80,36,126,37},
  {81,37,126,38},
  {82,38,127,39},
  {84,39,127,42},
  {85,42,127,49},
  {84,49,127,51},
  {82,51,127,52},
  {81,52,126,54},
  {78,54,126,56},
  {0,56,126,57},
  {0,57,125,62},
  {0,62,124,64},
  {0,64,123,66},
  {0,66,121,69},
  {0,69,120,70},
  {0,70,119,72},
  {0,72,118,73},
  {0,73,117,74},
  {0,74,116,76},
  {0,76,115,77},
  {0,77,114,78},
  {0,78,113,79},
  {0,79,111,80},
  {0,80,110,82},
  {0,82,109,83},
  {0,83,108,84},
  {0,84,107,87},
  {0,87,108,90},
  {0,90,109,92},
  {0,92,39,93},
  {70,92,110,93},
  {0,93,38,126},
  {71,93,110,94},
  {71,94,111,95},
  {72,95,111,97},
  {72,97,113,98},
  {74,98,113,99},
  {74,99,114,100},
  {75,100,114,101},
  {75,101,115,102},
  {76,102,115,104},
  {76,104,116,105},
  {77,105,116,106},
  {77,106,117,107},
  {78,107,117,108},
  {78,108,118,110},
  {79,110,118,111},
  {79,111,119,112},
  {80,112,119,113},
  {80,113,120,114},
  {81,114,120,115},
  {81,115,121,117},
  {82,117,121,118},
  {82,118,123,119},
  {84,119,123,120},
  {84,120,124,121},
  {85,121,124,122},
  {85,122,125,124},
  {86,124,125,125},
  {86,125,126,126},
  {1,126,37,127},
  {87,126,126,127},
  {2,127,36,128},
  {87,127,125,128},
 }
 local function at(px,py)
  return{x+(px-width/2)*size*1.62/height,y+(.5-py/height)*size*1.62,z}
 end
 local c={.84,.035,.055}
 for _,s in ipairs(spans)do
  q(at(s[1],s[4]),at(s[3],s[4]),at(s[3],s[2]),at(s[1],s[2]),c)
 end
end
function R.button(h)rocket(h.quad,0,-7,78.4,8.3)end

function R.build(h,setup)
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
 local function disk(x,y,z,r,c,N)
  N=N or 16
  for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
   quad({x,y,z},{x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x,y,z},c)
  end
 end
 local white={.83,.83,.77}
 local steel={.48,.50,.51}
 local edge={.26,.29,.31}
 local gold={.67,.49,.18}
 local blue={.23,.48,.67}
 local green={.12,.36,.27}
 local function cylinder(x,y,z,r,height,c,n)
  n=n or 24
  disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.80+.15*math.cos(a))
  end
 end
 local function stripe(x1,z1,x2,z2,w,y,c)
  local dx,dz=x2-x1,z2-z1;local length=math.sqrt(dx*dx+dz*dz)
  local nx,nz=-dz/length*w/2,dx/length*w/2
  quad({x1+nx,y,z1+nz},{x2+nx,y,z2+nz},{x2-nx,y,z2-nz},{x1-nx,y,z1-nz},c)
 end
 -- Dark, restrained industrial floor, with fine panel joints.
 disk(0,.02,0,73.5,{.19,.19,.21},96)
 for x=-66,66,12 do for z=-66,66,12 do
  if (math.abs(x)+5.95)^2+(math.abs(z)+5.95)^2<73^2 then
   local c=({{.23,.23,.25},{.24,.24,.26},{.22,.22,.24}})[(math.floor(x/12)+math.floor(z/12)*3+200)%3+1]
   rect(x,z,11.9,11.9,.034,c)
  end
 end end
 -- Decorative spin tiles: directions are a compact visual composition, not puzzle logic.
 local function arrowTile(x,z,dir,stop)
  local c=stop and{.62,.54,.21}or green
  rect(x,z,10.3,10.3,.041,edge);rect(x,z,9.5,9.5,.043,c)
  for _,d in ipairs({-4.45,4.45})do
   rect(x+d,z,.18,9,.045,{.37,.50,.41});rect(x,z+d,9,.18,.045,{.37,.50,.41})
  end
  if stop then
   rect(x,z,6.7,2.2,.049,white)
   return
  end
  local ca,sa=math.cos(dir),math.sin(dir)
  local function p(a,b)return{x+a*ca-b*sa,.049,z+a*sa+b*ca}end
  for _,b in ipairs({-2.2,2.2})do
   quad(p(-3.2,b+1.65),p(0,b-1.9),p(3.2,b+1.65),p(-3.2,b+1.65),white)
  end
 end
 local path={
  {-18,44,math.pi/2},{-6,44,math.pi/2},{6,44,math.pi/2},{18,44,0},
  {18,32,0},{18,20,0},{6,20,-math.pi/2},{-6,20,-math.pi/2},
  {-18,20,0},{-18,8,0},{-18,-4,0},{-18,-16,math.pi/2},
  {-6,-16,math.pi/2},{6,-16,math.pi/2},{18,-16,math.pi},
  {18,-4,math.pi},{18,8,math.pi/2},{30,8,0},{30,-4,0},
  {30,-16,0},{30,-28,-math.pi/2},{18,-28,-math.pi/2},
  {6,-28,0},{6,-40,0}
 }
 for _,p in ipairs(path)do arrowTile(p[1],p[2],p[3],false)end
 arrowTile(30,44,0,true);arrowTile(-30,-16,0,true)
 -- Low metal obstacle blocks with X braces and black/yellow safety stripes.
 local function crate(x,z)
  if not clear(x,z,10.5,10.5)then return end
  box(x,.04,z,10.5,1.5,10.5,black)
  box(x,1.54,z,10.2,2.3,10.2,edge)
  box(x,3.84,z,10.5,.7,10.5,steel)
  rect(x,z,9.7,9.7,4.55,{.43,.45,.46})
  stripe(x-3.5,z-3.5,x+3.5,z+3.5,.65,4.58,{.68,.75,.75})
  stripe(x-3.5,z+3.5,x+3.5,z-3.5,.65,4.58,{.68,.75,.75})
  for d=-4,2,2.5 do
   quad({x+d,.35,z+5.27},{x+d+1.15,.35,z+5.27},{x+d+2.1,1.35,z+5.27},{x+d+.95,1.35,z+5.27},gold)
   quad({x+5.27,.35,z+d},{x+5.27,.35,z+d+1.15},{x+5.27,1.35,z+d+2.1},{x+5.27,1.35,z+d+.95},gold)
   quad({x-5.27,.35,z+d},{x-5.27,.35,z+d+1.15},{x-5.27,1.35,z+d+2.1},{x-5.27,1.35,z+d+.95},gold)
  end
 end
 for _,p in ipairs({{-42,-40},{-30,-40},{-18,-40},{42,-40},
  {-42,-16},{-42,-4},{-42,8},{42,8},{42,20},{42,32},
  {-30,32},{-18,32},{-6,32},{6,32},{-30,44},{-30,56},{-18,56},{-6,56},{42,44},{42,56}})do crate(p[1],p[2])end
 -- Back wall, low partitions, vents and static fluorescent fittings.
 box(0,0,-64,64,21,2,white)
 box(0,0,-62.85,64,2,.45,black);box(0,2,-62.75,64,1.8,.4,{.62,.12,.10})
 box(-22,12,-62.65,14,6.7,.6,edge);box(-22,12.5,-62.3,12.7,5.5,.3,black)
 for x=-27.5,-16.5,1.1 do box(x,12.8,-61.95,.32,4.9,.15,steel)end
 box(3,15.5,-62.6,15,1.8,.5,edge);box(3,15.85,-62.25,13.5,1.1,.2,white)
 for _,p in ipairs({{-62,-28},{62,-28},{-64,19},{64,19}})do
  local x,z=p[1],p[2]
  if clear(x,z,1.5,12)then
   box(x,3,z,1.5,9,12,white);box(x,0,z,1.6,1.7,12,black)
   box(x,1.7,z,1.65,1.3,12,{.62,.12,.10})
  end
 end
 -- Utility cabinet and electrical control unit.
 box(24,0,-57,11,17,6,white)
 box(24,2,-53.9,9.3,13.2,.3,steel)
 box(23,7,-53.65,2.6,6,.15,black)
 box(27,9,-53.63,.8,1.5,.12,{.70,.17,.13});box(27,6.8,-53.63,.8,1.5,.12,blue)
 for y=2.7,4,.45 do box(24,y,-53.62,7,.13,.12,edge)end
 box(12,0,-57,9,9,5,edge)
 for _,x in ipairs({9.8,14.2})do
  box(x,1,-54.4,3.2,6.8,.3,steel)
  for y=2,6,1.4 do box(x,y,-54.2,.65,.8,.13,white)end
 end
 -- Blue-fronted storage cupboards on the rear left.
 for _,x in ipairs({-31,-20})do
  box(x,0,-53.5,10,13,4.5,white)
  for _,dx in ipairs({-2.3,2.3})do
   box(x+dx,3.7,-51.15,4.1,8.4,.3,edge)
   box(x+dx,4.1,-50.93,3.5,7.6,.15,{.22,.39,.46})
   for j=-1,1 do box(x+dx+j*.9,4.5,-50.8,.22,6.5,.10,{.39,.56,.61})end
   box(x+dx,7.6,-50.71,3.6,.25,.11,white)
  end
  box(x,1.2,-51.1,8.8,1.7,.3,steel)
 end
 -- Computer desk and keyboard, kept to the left edge.
 local tx,tz=-53,-27
 if clear(tx,tz,10,10)then
  for _,x in ipairs({tx-4,tx+4})do box(x,0,tz,.8,5.5,8,edge)end
  box(tx,5.5,tz,10.5,.7,9,white)
  box(tx,6.2,tz-1.3,6,4.2,.65,edge)
  box(tx,6.6,tz-.87,5.1,3.3,.13,{.58,.75,.75})
  rect(tx,tz+2.4,5.7,2,6.24,edge)
  for x=tx-2.3,tx+2.3,.7 do rect(x,tz+2.4,.18,1.4,6.26,white)end
  box(tx-1,0,tz+8,.7,2.8,.7,edge);box(tx-1,2.8,tz+8,4.8,1.2,4.8,blue)
  box(tx-1,4,tz+10,4.8,3.4,.65,blue)
 end
 -- Static blue capsule: opaque inset panels, no glass, fluid animation or light effects.
 local cx,cz=52,-27
 cylinder(cx,.04,cz,5.8,1,edge);cylinder(cx,1.04,cz,5,1.4,steel)
 cylinder(cx,2.44,cz,4.1,11.7,blue)
 for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
  local c=({{.20,.44,.65},{.24,.53,.71},{.39,.68,.80},{.22,.49,.68}})[i%4+1]
  quad({cx+4.12*math.cos(a),3,cz+4.12*math.sin(a)},{cx+4.12*math.cos(b),3,cz+4.12*math.sin(b)},
   {cx+4.12*math.cos(b),13.6,cz+4.12*math.sin(b)},{cx+4.12*math.cos(a),13.6,cz+4.12*math.sin(a)},c)
 end
 cylinder(cx,14.14,cz,4.8,1.2,steel);cylinder(cx,15.34,cz,4.2,.8,blue)
 disk(cx,16.16,cz,2.6,{.14,.32,.48},24)
 for _,s in ipairs({-1,1})do box(cx+s*4.8,0,cz,1.4,2.2,2.4,edge)end
 -- Side waiting sofa, reference blue upholstery.
 if clear(-57,35,8,14)then
  box(-57,0,35,7.2,1.5,13,edge);box(-57,1.5,35,7.5,2.2,13.5,blue)
  box(-60,3.7,35,1.6,4,13.5,blue)
  for _,z in ipairs({29,41})do box(-57,3.7,z,7,1.8,1.4,blue)end
  box(-56.6,3.74,35,4.2,.10,.3,{.15,.34,.50})
 end
 -- Cardboard storage crates and short stairs near the back.
 for _,p in ipairs({{-43,-52},{-37,-58}})do
  box(p[1],0,p[2],6,4.8,5,{.60,.43,.27})
  rect(p[1],p[2],1.0,5,4.82,{.75,.61,.41})
  box(p[1],.5,p[2]+2.52,1,3.8,.1,{.75,.61,.41})
 end
 for i=0,4 do box(38,0,-51-i*2,8,.65+i*.65,2,steel)end
 rect(0,65,16,7,.044,edge)
 for z=63,67,2 do rect(0,z,14,1.6,.046,steel)end
end
return R
