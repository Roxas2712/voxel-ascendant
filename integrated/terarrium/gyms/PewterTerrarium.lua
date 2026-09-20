-- Pewter Gym / Brock: compact terrarium for integration by PANDY.
-- Visual direction: ODias; supplied Let's Go concept art and Boulder Badge.
-- Reuse the host's compact bowl, participants, trainer plinths and branding.
local P={revision='pewter-compact-v1'}
local stone={.40,.47,.51}
local lightStone={.62,.69,.71}
local darkStone={.23,.30,.35}
local ivory={.84,.85,.80}

function P.appliesTo(mapId)return mapId=='PEWTER_GYM'end

local function boulderBadge(quad,x,y,z,size)
 local outer={{-.57,.79},{.21,.97},{.81,.62},{.98,-.15},
  {.61,-.78},{-.03,-.98},{-.70,-.69},{-.97,.09}}
 local inner={{-.30,.39},{.11,.49},{.42,.30},{.49,-.11},
  {.28,-.43},{-.02,-.53},{-.36,-.38},{-.50,.04}}
 local tones={{.62,.63,.63},{.75,.76,.76},{.91,.93,.93},{.76,.79,.80},
  {.86,.88,.88},{.60,.63,.65},{.42,.46,.49},{.48,.51,.53}}
 local function at(p,dz)return{x+p[1]*size,y+p[2]*size,z+dz}end
 for i=1,8 do local j=i%8+1
  quad({x,y,z},at(outer[i],0),at(outer[j],0),{x,y,z},{.055,.065,.075})
  local a,b,c,d=outer[i],outer[j],inner[j],inner[i]
  local cx,cy=(a[1]+b[1]+c[1]+d[1])/4,(a[2]+b[2]+c[2]+d[2])/4
  local function inset(p)return{cx+(p[1]-cx)*.95,cy+(p[2]-cy)*.95}end
  quad(at(inset(a),.03),at(inset(b),.03),at(inset(c),.03),at(inset(d),.03),tones[i])
  quad({x,y,z+.04},at({inner[i][1]*.96,inner[i][2]*.96},.04),
   at({inner[j][1]*.96,inner[j][2]*.96},.04),{x,y,z+.04},{.71,.74,.75})
 end
 -- Slim highlights keep the central stone readable at icon size.
 quad(at({-.20,-.42},.07),at({-.11,-.46},.07),at({.16,.45},.07),at({.05,.46},.07),{.94,.96,.96})
end

function P.button(h)boulderBadge(h.quad,0,-7,78.35,8.0)end

function P.build(h,setup)
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
 -- Entire floor belongs to this scene. No external texture is required.
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},
   {math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},{.07,.28,.43})
 end
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.85)^2+(math.abs(z)+3.85)^2<73^2 then
   local n=(x*7+z*13+2000)%5
   local tile={.08+n*.013,.34+n*.018,.53+n*.022}
   rect(x,z,7.7,7.7,.029,tile)
   rect(x-1.6,z+1.4,3.1,.20,.031,{.20,.48,.65})
  end
 end end
 -- Sandy rock garden; the central lane remains open for either actor layout.
 rect(0,-1,92,82,.039,{.73,.62,.43})
 for x=-44,44,4 do for z=-40,36,4 do
  local n=(x*17+z*29+9999)%11
  rect(x,z,4.02,4.02,.041,{.76+n*.004,.65+n*.004,.46+n*.004})
  if n%3==0 then rect(x+.6,z-.8,.7+n*.065,.23,.043,{.64,.53,.36})end
  if n==2 then rect(x-.8,z+1.3,1.1,.16,.044,{.88,.79,.60})end
 end end
 -- Angular eight-sided rocks, with independently varied strata and facets.
 local function rock(x,y,z,r,height,seed,c)
  local rings={}
  for level=0,3 do
   local f=({1,.93,.68,.20})[level+1]
   local yy=({0,.25,.71,1})[level+1]*height
   rings[level+1]={}
   for i=0,7 do
    local a=i*math.pi/4;local jitter=.89+((i*7+seed*3+level)%7)*.031
    rings[level+1][i+1]={x+math.cos(a)*r*f*jitter+level*.23,y+yy,z+math.sin(a)*r*f*.78*jitter}
   end
  end
  for level=1,3 do for i=1,8 do local j=i%8+1
   local shade=.68+(i%4)*.07+(level-1)*.05
   quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],c,shade)
  end end
  for i=1,8 do local j=i%8+1
   quad({x+.7,y+height*1.07,z},rings[4][i],rings[4][j],{x+.7,y+height*1.07,z},c,1)
  end
 end
 -- Ochre outcrops frame the arena, rather than covering the battle positions.
 for _,side in ipairs({-1,1})do
  for i=0,6 do local z=-34+i*11;local x=side*(42+(i%2)*1.4)
   if clear(x,z,11,10)then
    rock(x,0,z,6.4+(i%3)*.7,8+(i%3)*2.5,i+side+4,{.76,.61,.39})
    rock(x-side*3,0,z+3,3.7,5.3,i+5,{.85,.72,.49})
   end
  end
 end
 for _,v in ipairs({{-32,-28,6.8,11},{31,-29,6.0,9},{-35,27,5.3,8},{34,28,6.0,9.7}})do
  if clear(v[1],v[2],v[3]*2,v[3]*1.6)then rock(v[1],0,v[2],v[3],v[4],7,{.81,.67,.44})end
 end
 -- Two rows of red / orange seats on blue-grey stepped terraces.
 for _,side in ipairs({-1,1})do
  for row=0,1 do for z=-32,32,6.4 do
   local x=side*(54+row*6.0)
   if (math.abs(x)+2.6)^2+(math.abs(z)+2.8)^2<71.7^2 and clear(x,z,5.0,5.8)then
    local y=2.4+row*3.3;local col=row==0 and{.68,.10,.13}or{.80,.36,.11}
    box(x,0,z,5.5,y,6.1,stone)
    box(x,y,z,4.8,.85,5.3,col)
    box(x+side*1.9,y+.65,z,.8,2.8,5.3,col)
    box(x-side*2.4,y-1,z,.22,3.6,5.9,ivory)
   end
  end end
 end
 -- Low stone stage at the rear, with the distinctive three-rock arrangement.
 box(0,0,-54,44,6.5,17,stone)
 box(0,6.5,-54,43,.6,17,lightStone)
 for row=0,2 do
  for col=-3,3 do
   box(col*6.1,row*2.05+.12,-45.4,5.8,1.8,.22,({stone,lightStone,darkStone})[(row+col+6)%3+1])
  end
 end
 for step=0,3 do box(0,0,-37-step*2.25,16,1.5+step*1.5,2.25,stone)end
 box(0,7.1,-53,18,1.8,7,{.49,.59,.62})
 rock(0,8.9,-56,7.3,18,3,{.58,.65,.64})
 rock(-14,7.1,-53,4,8.5,1,lightStone);rock(14,7.1,-53,4,8.5,5,lightStone)
 -- Blue stone wall: low enough to remain an open terrarium, with visible masonry.
 box(0,0,-63,65,29,2,darkStone)
 for row=0,5 do for col=-5,5 do
  local x=col*5.7+(row%2)*2.5
  if math.abs(x)<32 then
   local n=(row*3+col+20)%4
   box(x,row*4.7+.2,-61.8,5.5,4.4,.45,{.25+n*.025,.39+n*.024,.48+n*.025})
  end
 end end
 box(0,28.8,-63,67,.8,3,lightStone)
 -- Warm fixture colours evoke the light focused on Brock's stone pedestal.
 for _,x in ipairs({-24,24})do
  box(x,25.4,-60.8,3,1.2,2.2,darkStone)
  box(x,24.9,-60.6,2.2,.45,1.6,{.98,.81,.39})
 end
 -- Entrance statues and red welcome tile, kept below the camera sight lines.
 for _,x in ipairs({-16,16})do
  box(x,0,53,6,1.4,6,stone);box(x,1.4,53,5.4,1.1,5.4,lightStone)
  box(x,2.5,53,3.4,3.7,3.3,stone)
  box(x,6.2,53,3.6,2.1,3.2,lightStone)
  for _,side in ipairs({-1,1})do box(x+side*2.1,3.4,53,1.2,2.4,1.8,lightStone)end
  box(x,7.7,54.8,.8,1.5,1.5,lightStone)
 end
 rect(0,65,15,7,.04,{.76,.23,.12})
 rect(0,65,12.5,5,.042,{.90,.42,.20})
 rect(0,65,11,3.7,.044,{.72,.19,.12})
end
return P
