-- Saffron Gym / Sabrina. Compact terrarium for integration by PANDY.
-- Visual direction: ODias; supplied Let's Go concept art and Marsh Badge.
-- Reuse the host bowl, camera, participants, trainer plinths and branding.
local S={revision='saffron-compact-v1'}
local navy={.065,.14,.22}
local teal={.10,.32,.38}
local cyan={.22,.82,.83}
local pink={.96,.36,.59}
local yellow={.98,.84,.36}
local cream={.99,.95,.66}
function S.appliesTo(mapId)return mapId=='SAFFRON_GYM'end

function S.button(h)
 local q=h.quad
 local function p(a,r,z)return{math.cos(a)*r,-7+math.sin(a)*r,78.35+z}end
 -- Concentric gold discs, orange bevels and the dark inner contour.
 for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
  local lit=math.sin(a)+math.cos(a)>.15
  q(p(a,8.2,0),p(b,8.2,0),p(b,7.55,.02),p(a,7.55,.02),lit and{1,.93,.27}or{1,.34,.12})
  q(p(a,7.55,.02),p(b,7.55,.02),p(b,4.95,.045),p(a,4.95,.045),lit and{1,.84,.12}or{1,.55,.20})
  q(p(a,4.95,.05),p(b,4.95,.05),p(b,4.73,.05),p(a,4.73,.05),{.10,.09,.055})
  q(p(a,4.73,.07),p(b,4.73,.07),p(b,3.55,.09),p(a,3.55,.09),lit and{1,1,.44}or{1,.54,.21})
  q({0,-7,78.46},p(a,3.55,.11),p(b,3.55,.11),{0,-7,78.46},{1,.92,.24})
 end
end

function S.build(h,setup)
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
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},{math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},navy)
 end
 -- Octagonal arena footprint. The playable floor remains at host ground level.
 local outer={{-48,-33},{-36,-45},{36,-45},{48,-33},{48,33},{36,45},{-36,45},{-48,33}}
 local function ring(scale1,scale2,y,c)
  for i=1,8 do local j=i%8+1;local a,b=outer[i],outer[j]
   quad({a[1]*scale1,y,a[2]*scale1},{b[1]*scale1,y,b[2]*scale1},
    {b[1]*scale2,y,b[2]*scale2},{a[1]*scale2,y,a[2]*scale2},c)
  end
 end
 ring(1.075,1.02,.03,teal);ring(1.02,1,.04,pink)
 ring(1,.93,.05,navy);ring(.93,.915,.06,cyan)
 -- Clip each warm panel to the inside of the octagonal border.
 local function clip(poly,nx,nz,limit)
  local out={}
  for i=1,#poly do local a,b=poly[i],poly[i%#poly+1]
   local da,db=a[1]*nx+a[2]*nz-limit,b[1]*nx+b[2]*nz-limit
   if da<=0 then out[#out+1]=a end
   if (da<=0)~=(db<=0)then local t=da/(da-db);out[#out+1]={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t}end
  end
  return out
 end
 for x=-42,42,6 do for z=-39,39,6 do
  local poly={{x-2.85,z-2.85},{x+2.85,z-2.85},{x+2.85,z+2.85},{x-2.85,z+2.85}}
  for _,p in ipairs({{1,0,43.7},{-1,0,43.7},{0,1,41},{0,-1,41},{1,1,73.7},{1,-1,73.7},{-1,1,73.7},{-1,-1,73.7}})do
   if #poly>0 then poly=clip(poly,p[1],p[2],p[3])end
  end
  local n=(x*7+z*11+4000)%4
  local c=z>21 and({{.95,.69,.48},{.98,.77,.52},{.97,.73,.56},{.94,.66,.53}})[n+1]
    or({{.94,.82,.37},{.98,.90,.50},{.91,.78,.34},{.98,.94,.66}})[n+1]
  if #poly>=3 then
   for i=2,#poly-1 do quad({poly[1][1],.034,poly[1][2]},{poly[i][1],.034,poly[i][2]},
    {poly[i+1][1],.034,poly[i+1][2]},{poly[1][1],.034,poly[1][2]},c)end
  end
 end end
 -- Narrow access bridge, represented at ground level for the participant rig.
 rect(0,57,11,23,.041,teal)
 rect(0,57,7,23,.045,{.67,.90,.83})
 for z=48,66,6 do rect(0,z,6.5,.3,.05,navy)end
 for _,x in ipairs({-5.2,5.2})do rect(x,57,.45,23,.06,pink)end
 -- Two stepped audience wings, with dark faces and cyan horizontal bands.
 for _,s in ipairs({-1,1})do for row=0,1 do for i=0,10 do
  local z=-32+i*6.4;local x=s*(54+row*6)
  if (math.abs(x)+2.7)^2+(math.abs(z)+2.9)^2<72^2 and clear(x,z,5.4,6)then
   local y=5+row*4;local c=({pink,cyan,yellow})[(i+row)%3+1]
   box(x,0,z,5.8,y,6.2,navy)
   for level=1,row+2 do box(x-s*2.94,level*1.4,z,.15,.50,6.1,cyan)end
   box(x,y,z,5.8,.4,6.1,teal)
   box(x,y+.4,z,4.5,.9,4.8,c)
   box(x+s*1.75,y+1.3,z,.8,3,4.8,c)
   box(x+s*2.8,y,z,.22,.5,6.2,pink)
  end
 end end end
 -- Rear tower facades and golden windows recall the skyscraper setting.
 for _,s in ipairs({-1,1})do
  local x=s*26
  box(x,0,-55,13,24,10,navy)
  for row=0,2 do
   box(x,2+row*7,-49.9,11,4.5,.25,yellow)
   for dx=-4,4,2.7 do box(x+dx,2+row*7,-49.6,.25,4.5,.3,teal)end
   box(x,7+row*7,-49.5,13,.5,.4,cyan)
  end
  box(x,23.5,-55,13.4,.6,10.4,pink)
 end
 -- Compact Sabrina dais at the back, with a teal mat and psychic-circle motif.
 box(0,0,-55,32,5.5,15,navy)
 box(0,1.5,-47.4,31,2.5,.3,yellow)
 for x=-14,14,4 do box(x,1.5,-47.15,.35,2.5,.4,teal)end
 box(0,5.5,-55,32,.5,15,cyan)
 box(0,6,-55,29,.3,12,teal)
 rect(0,-55,21,10,6.31,{.35,.58,.45})
 for i=0,31 do local a,b=i*math.pi/16,(i+1)*math.pi/16
  quad({math.cos(a)*3.5,6.34,-55+math.sin(a)*3.5},{math.cos(b)*3.5,6.34,-55+math.sin(b)*3.5},
   {math.cos(b)*3.1,6.34,-55+math.sin(b)*3.1},{math.cos(a)*3.1,6.34,-55+math.sin(a)*3.1},cyan)
 end
 for i=0,2 do box(0,0,-43.5-i*1.7,12,1.5+i*1.5,1.7,teal)end
 -- Flat teleporter motifs; decorative only, with no gameplay or light effect.
 for _,s in ipairs({-1,1})do
  local x=s*30;local z=32
  rect(x,z,8,8,.042,teal);rect(x,z,6.7,6.7,.046,pink);rect(x,z,5.5,5.5,.049,navy)
  rect(x,z,3,3,.053,cyan)
 end
 -- Paired low entrance markers echo the small statues in the concept art.
 for _,x in ipairs({-12,12})do
  if clear(x,55,5,5)then
   box(x,0,55,5,1,5,teal);box(x,1,55,3,3,3,{.62,.79,.75})
   box(x,4,55,3.3,1.6,3,{.83,.90,.79})
   box(x,5.6,55,1.6,.6,1.6,pink)
  end
 end
end
return S
