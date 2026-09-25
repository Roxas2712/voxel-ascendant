-- Silph Company: compact occupied lobby for integration by PANDY.
-- Visual direction: ODias; supplied Silph lobby concept art and Rocket R icon.
-- Reuse host bowl, camera, participants, trainer plinths and branding.
local R={revision='silph-rocket-invasion-compact-v2'}
-- Caller must also gate this scene to the Team Rocket invasion story phase.
function R.appliesTo(mapId)
 local f=type(mapId)=='string' and mapId:match('^SILPH_CO_(%d+)F$')
 return f~=nil and tonumber(f)>=1 and tonumber(f)<=11
end
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
 local ivory={.82,.83,.77}
 local teal={.12,.53,.59}
 local gold={.76,.65,.31}
 local dark={.16,.19,.22}
 local function cylinder(x,y,z,r,height,c,n)
  n=n or 20
  disk(x,y+height,z,r,c,n)
  for i=0,n-1 do
   local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   local ax,az=x+math.cos(a)*r,z+math.sin(a)*r
   local bx,bz=x+math.cos(b)*r,z+math.sin(b)*r
   quad({ax,y,az},{bx,y,bz},{bx,y+height,bz},{ax,y+height,az},c,.78+.16*math.cos(a))
  end
 end
 -- A tiled corporate lobby, with warm waiting strips and a clear combat floor.
 disk(0,.02,0,73.5,{.44,.46,.47},96)
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(math.floor(x/8)+math.floor(z/8)*3+200)%4
   local colors=math.abs(x)>40 and {{.70,.59,.43},{.75,.65,.49},{.79,.69,.53},{.72,.62,.47}}
    or {{.30,.33,.37},{.39,.40,.41},{.35,.33,.33},{.44,.43,.41}}
   rect(x,z,7.8,7.8,.034,colors[n+1])
  end
 end end
 -- A restrained square motif replaces the full lobby's expansive concentric paving.
 for _,x in ipairs({-35,35})do rect(x,5,1.4,78,.04,{.57,.47,.37})end
 for _,z in ipairs({-34,44})do rect(0,z,70,1.4,.04,{.57,.47,.37})end
 -- Twin shallow fountain basins, shifted towards the rear for participant clearance.
 local function fountain(x,z)
  cylinder(x,.04,z,12.8,1.1,dark,32)
  cylinder(x,1.14,z,12.3,1.7,ivory,32)
  disk(x,2.86,z,9.4,{.07,.37,.52},32)
  disk(x,2.88,z,8.6,{.20,.61,.72},32)
  for i=0,23 do
   local a,b=i*2*math.pi/24,(i+1)*2*math.pi/24
   local c=(i>=4 and i<=6)and gold or ((i%3==0)and{.91,.90,.82}or ivory)
   local function p(r,t)return{x+r*math.cos(t),2.92,z+r*math.sin(t)}end
   quad(p(9.6,a+.013),p(12.25,a+.013),p(12.25,b-.013),p(9.6,b-.013),c)
  end
  -- Low nozzle only. Water jets and animated ripples are left for integration.
  cylinder(x,2.9,z,.9,.35,ivory,12)
  for i=0,7 do local a=i*math.pi/4
   disk(x+math.cos(a)*6.5,2.91,z+math.sin(a)*6.5,.38,{.55,.79,.82},6)
  end
 end
 -- Common masonry waist joins both plinths and rims, leaving two separate pools.
 -- The cap sits just below the segmented rim faces to avoid coplanar overlap.
 box(0,.04,-34,6,1.1,10,dark)
 box(0,1.14,-34,6,1.7,10,ivory)
 box(0,2.84,-34,6,.07,10,ivory)
 fountain(-13.4,-34);fountain(13.4,-34)
 -- Rear panelled wall and lift, condensed to the compact bowl outline.
 box(0,0,-64,62,22,2,ivory)
 for _,x in ipairs({-26,-18,18,26})do
  box(x,1,-62.85,7.6,18.5,.35,{.44,.24,.18})
  box(x,16.9,-62.58,7.1,2.1,.18,{.88,.85,.68})
  box(x-3.6,1,-62.4,.35,20,.4,dark)
 end
 box(0,0,-62.65,16,20,.6,ivory)
 box(0,.3,-62.2,12.6,15,.4,dark)
 for _,x in ipairs({-3.05,3.05})do box(x,.5,-61.94,5.9,14.6,.2,teal)end
 box(0,15.9,-62.1,12.6,2.6,.3,gold)
 box(0,16.6,-61.85,7.5,.55,.1,ivory)
 box(8.2,7,-62.2,.9,2,.3,dark)
 -- Team Rocket occupation banners flank the corporate lift.
 for _,x in ipairs({-25,25})do
  box(x,9,-61.9,7.4,11,.4,black)
  quad({x-3.7,9,-61.6},{x+3.7,9,-61.6},{x,6.8,-61.6},{x-3.7,9,-61.6},black)
  rocket(quad,x,14.3,-61.3,3.8)
 end
 -- Reception at rear left: pale L-shaped counter with a turquoise worktop.
 box(-43,0,-43,20,6.3,7,ivory)
 box(-43,6.3,-43,20.7,.7,7.5,teal)
 box(-34,0,-48,3,6.3,11,ivory)
 box(-34,6.3,-48,3.5,.7,11.3,teal)
 box(-43,1.7,-39.35,17,1.0,.2,{.49,.50,.49})
 box(-43,3.2,-39.3,11,.5,.2,gold)
 box(-47,7,-43.5,4.6,3.2,.6,dark)
 box(-47,7.3,-43.1,3.8,2.4,.12,{.53,.76,.78})
 rect(-40,-43.3,3.5,2.6,7.04,ivory)
 -- Short stair flight on the back-right side.
 for i=0,5 do box(43,0,-41-i*2.1,9,.6+i*.7,2.1,ivory)end
 for _,x in ipairs({37.7,48.3})do box(x,0,-46.3,.7,5.5,13,dark)end
 -- Waiting sofas: low heights keep camera sightlines open.
 local function sofa(x,z,c)
  if clear(x,z,8,13)then
   box(x,0,z,7,1.2,12,dark)
   box(x,1.2,z,7.4,2,12.4,c)
   box(x-2.9,3.2,z,1.6,3.5,12.4,c)
   for _,dz in ipairs({-5.8,5.8})do box(x,3.2,z+dz,7,1.4,1,c)end
   box(x+.2,3.22,z,4.2,.2,.25,{.09,.36,.42})
  end
 end
 sofa(-57,-16,teal);sofa(-57,30,teal)
 -- Two small lounge clusters, using the reference's pink and pale chairs.
 local function chair(x,z,c)
  if clear(x,z,5,5)then
   box(x,0,z,3.5,1.3,3.5,dark);box(x,1.3,z,4.8,1.5,4.8,c)
   box(x,2.8,z-1.8,4.8,2.5,1.2,c)
  end
 end
 for _,z in ipairs({14,37})do
  if clear(53,z,11,8)then
   box(53,0,z,8,2,5,dark);box(53,2,z,9,.45,6,{.48,.48,.44})
  end
  chair(50,z-6.5,{.76,.22,.40});chair(56,z-6.5,{.76,.22,.40})
  chair(50,z+6.5,ivory);chair(56,z+6.5,ivory)
 end
 local function plant(x,z)
  if clear(x,z,5.5,5.5)then
   cylinder(x,.04,z,2.5,2.9,ivory,12)
   cylinder(x,2.9,z,2.2,.3,dark,12)
   box(x,3.1,z,.7,3,.7,wood)
   cylinder(x,4,z,3.3,2.8,{.22,.43,.24},10)
   cylinder(x,6.8,z,2.8,2.6,{.32,.56,.28},10)
   cylinder(x,9.4,z,1.7,1.4,{.43,.64,.34},10)
  end
 end
 for _,p in ipairs({{-30,-52},{30,-52},{-64,4},{-48,46},{47,49},{62,-28}})do plant(p[1],p[2])end
 -- Low pale perimeter panels retain the corporate interior without enclosing it.
 for _,p in ipairs({{-65,-24},{-65,24},{65,-24},{65,24}})do
  if clear(p[1],p[2],1.5,11)then
   box(p[1],0,p[2],1.5,6,11,ivory)
   box(p[1],5.6,p[2],1.6,.5,11,teal)
  end
 end
 rect(0,62,18,12,.045,dark)
 rect(0,62,16.5,10.5,.048,{.57,.13,.25})
 for _,x in ipairs({-7.1,7.1})do rect(x,62,.3,8.7,.051,gold)end
 for _,z in ipairs({57.7,66.3})do rect(0,z,14.2,.3,.051,gold)end
end
return R
