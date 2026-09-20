-- Cerulean Gym / Misty: compact terrarium for integration by PANDY.
-- Visual direction: ODias, using the references supplied in the conversation.
-- This module contains scene geometry and the Cascade emblem; reuse the host bowl.
-- Geometry is authored in arena-local units; actor feet remain owned by the host.
local C={revision='cerulean-compact-v1'}
local white={.88,.94,.94}
local tile={.69,.83,.85}
local grout={.34,.58,.64}
local blue={.10,.41,.65}
local deep={.065,.34,.53}
local water={.12,.59,.72}
local foam={.56,.86,.90}

local function badge(quad,cx,cy,z,scale)
 -- Independently authored Cascade silhouette: blue drop with a pale metal edge.
 local outline={{0,1},{-.24,.67},{-.50,.30},{-.64,.01},{-.65,-.22},
  {-.56,-.48},{-.38,-.66},{-.15,-.75},{0,-.77},{.15,-.75},
  {.38,-.66},{.56,-.48},{.65,-.22},{.64,.01},{.50,.30},{.24,.67}}
 for layer=0,2 do
  local r=scale*(1-layer*.10)
  local tone=layer==0 and {.76,.84,.89}or layer==1 and {.025,.26,.41}or{.04,.59,.77}
  for i=1,#outline do local a,b=outline[i],outline[i%#outline+1]
   quad({cx,cy,z+layer*.08},{cx+a[1]*r,cy+a[2]*r,z+layer*.08},
    {cx+b[1]*r,cy+b[2]*r,z+layer*.08},{cx,cy,z+layer*.08},tone)
  end
 end
 quad({cx-scale*.33,cy+scale*.23,z+.25},{cx-scale*.18,cy+scale*.43,z+.25},
  {cx-scale*.23,cy+scale*.13,z+.25},{cx-scale*.36,cy-scale*.03,z+.25},white)
end

function C.button(h)
 badge(h.quad,0,-7,78.2,8.1)
end

function C.appliesTo(mapId)
 return mapId=='CERULEAN_GYM'
end

function C.build(h,setup)
 local box,quad=h.box,h.quad
 local ice={.77,.91,.95}
 local sand={.85,.73,.52}
 local pink={.90,.29,.46}
 local function floorRect(x,z,w,d,y,tone)
  quad({x-w/2,y,z-d/2},{x+w/2,y,z-d/2},{x+w/2,y,z+d/2},{x-w/2,y,z+d/2},tone)
 end
 -- A miniature circular adaptation of the supplied gym plan.
 for x=-68,68,4 do for z=-68,68,4 do
  if (math.abs(x)+1.94)^2+(math.abs(z)+1.94)^2<72.8^2
   and (math.abs(x)-1.94>=47 or math.abs(z)-1.94>=41)then
   local tone=((x+z)/4)%4==0 and {.92,.84,.65}or sand
   floorRect(x,z,3.86,3.86,.02,tone)
  end
 end end
 floorRect(0,0,96,84,-.10,deep)
 floorRect(0,0,92,80,-.07,{.07,.54,.76})
 -- Fine directional water marks; small quads retain the VASC block vocabulary.
 for x=-43,43,4 do for z=-37,37,4 do
  local wave=math.sin(x*.34+z*.47)
  floorRect(x+wave*.7,z,1.0+(wave+1)*.9,.12,-.057,{.28,.72,.84})
  if (x+z)%3==0 then floorRect(x+.6,z+.7,1.6,.16,-.055,{.49,.82,.90})end
 end end
 for _,x in ipairs({-47,47})do box(x,-.02,0,1.6,.16,84,{.04,.23,.38})end
 for _,z in ipairs({-41,41})do box(0,-.02,z,94,.16,1.6,{.04,.23,.38})end
 -- Glass-coloured walkway tiles. Top faces remain at the shared battle-foot plane.
 local paths={}
 local function pathTile(x,z)
  local key=x..':'..z;if paths[key]then return end;paths[key]=true
  box(x,-.52,z,5.84,.52,5.84,{.33,.66,.78})
  floorRect(x,z,5.56,5.56,.002,ice)
  floorRect(x-1.9,z, .18,4.65,.006,{.96,.99,1})
  floorRect(x,z-1.9,4.65,.18,.006,{.96,.99,1})
  floorRect(x+.8,z+.9,1.7,.18,.007,{.62,.83,.90})
 end
 for z=-48,54,6 do pathTile(0,z)end
 -- Right rear and left front loops, as in the supplied plan.
 for x=6,30,6 do pathTile(x,-24);pathTile(x,0)end
 for z=-18,-6,6 do pathTile(30,z)end
 for x=-30,-6,6 do pathTile(x,0);pathTile(x,24)end
 for z=6,18,6 do pathTile(-30,z)end
 -- Keep both current camera arrangements supported, with a clear pad per Pokémon.
 for _,side in ipairs({'player','enemy'})do local p=setup.actors[side]
  box(p[1],-.46,p[3],17,.46,16,{.31,.63,.77})
  floorRect(p[1],p[3],16.5,15.5,.012,ice)
  floorRect(p[1],p[3],14.8,13.8,.014,{.70,.86,.92})
  for _,s in ipairs({-1,1})do floorRect(p[1]+s*7.8,p[3],.16,15,.018,white)end
 end
 local function clearTrainer(x,z,w,d)
  for _,p in pairs(setup.trainers)do
   if math.abs(p[1]-x)<w/2+8 and math.abs(p[3]-z)<d/2+8 then return false end
  end
  return true
 end
 -- Staggered aqua / amber spectators' seats, with gaps for trainer plinths.
 for _,side in ipairs({-1,1})do
  for row=0,2 do for z=-30,30,6 do
   local x=side*(54+row*4.7)
   if (math.abs(x)+2.1)^2+(math.abs(z)+2.6)^2<71.5^2 and clearTrainer(x,z,4.3,5.2)then
    local y=.7+row*2.6;local seat=(row+z/6)%3==0 and {.91,.60,.16}or{.22,.56,.62}
    box(x,0,z,4.5,y,5.5,{.29,.37,.42})
    box(x,y,z,4.1,.8,4.9,seat)
    box(x+side*1.65,y+.6,z,.7,2.6,4.9,seat)
   end
  end end
 end
 -- Three small diving towers, set behind the main battle lanes.
 local function diving(side,z,height)
  local x=side*49
  box(x,0,z,3.2,height,4,{.49,.59,.65})
  box(x-side*3.5,height,z,13,1.2,9,white)
  box(x-side*3.5,height+1.2,z,11,.24,7,{.22,.27,.39})
  for _,dz in ipairs({-4,4})do
   for _,dx in ipairs({-7,0,3})do box(x+side*dx,height+1.5,z+dz,.45,3.2,.45,white)end
   box(x-side*2,height+4.3,z+dz,10,.45,.45,white)
  end
  for y=1,height,2.6 do box(x+side*2,y,z,1.3,.4,4.4,white)end
 end
 diving(-1,-32,16);diving(1,-32,16)
 -- Third tower is lower, on the outer bank and clear of trainer feet.
 if clearTrainer(-54,28,9,9)then diving(-1,28,10)end
 -- Arched aquatic backdrop and pastel bands, following the provided elevation.
 for i=0,31 do
  local a,b=i*math.pi/32,(i+1)*math.pi/32
  local xa,xb=math.cos(a)*53,math.cos(b)*53
  local ya,yb=9+math.sin(a)*23,9+math.sin(b)*23
  quad({xa,9,-50},{xb,9,-50},{xb,yb,-50},{xa,ya,-50},{.15,.47,.66})
 end
 local bands={{.85,.96,.97},{.50,.82,.90},{.75,.87,.70},{.90,.89,.72},{.89,.67,.76}}
 for band=1,#bands do
  local r0=53+(band-1)*1.3;local r1=r0+1.3
  for i=0,31 do
   local a,b=i*math.pi/32,(i+1)*math.pi/32
   quad({math.cos(a)*r0,9+math.sin(a)*r0*.434,-50.15},
    {math.cos(b)*r0,9+math.sin(b)*r0*.434,-50.15},
    {math.cos(b)*r1,9+math.sin(b)*r1*.434,-50.15},
    {math.cos(a)*r1,9+math.sin(a)*r1*.434,-50.15},bands[band])
  end
 end
 box(0,8,-50,110,1.2,1.2,white)
 local function star(x,y,z,r)
  for layer=0,1 do local radius=r*(1-layer*.24);local tone=layer==0 and white or {.27,.70,.84}
   for i=0,9 do
    local a,b=math.pi/2+i*math.pi/5,math.pi/2+(i+1)*math.pi/5
    local ra=i%2==0 and radius or radius*.44;local rb=i%2==0 and radius*.44 or radius
    quad({x,y,z+layer*.04},{x+math.cos(a)*ra,y+math.sin(a)*ra,z+layer*.04},
     {x+math.cos(b)*rb,y+math.sin(b)*rb,z+layer*.04},{x,y,z+layer*.04},tone)
   end
  end
 end
 star(-43,27,-49.6,6.1);star(43,27,-49.6,6.1)
 -- Pale bubbles and little fish silhouettes replace raster artwork on the panel.
 for i=-4,4 do
  local x=i*9;local y=14+((i+5)%3)*3
  box(x,y,-49.6,2,.7,.15,{.60,.85,.91})
  quad({x+1,y-.7,-49.4},{x+2.3,y+.7,-49.4},{x+2.3,y-.7,-49.4},{x+1,y-.7,-49.4},foam)
  box(x+3,y+3,-49.6,.6,.6,.15,foam)
 end
 local function seaweed(x,z,height)
  for stalk=-1,1 do
   for j=0,6 do
    local dx=math.sin(j*.9+stalk)*1.8+stalk*2.1
    local col=j%2==0 and {.40,.57,.16}or{.58,.71,.22}
    box(x+dx,j*height/7,z+stalk,1.6,height/7+.5,1.3,col)
   end
  end
 end
 local function coral(x,z,col)
  box(x,0,z,5,1.4,4,col)
  for i=-1,1 do
   box(x+i*2,1,z,1.6,3.2+(i+1)%2*2,1.6,col)
   box(x+i*2.7,3,z,2.1,1.5,1.7,col)
  end
 end
 for _,side in ipairs({-1,1})do
  seaweed(side*18,-47,21);seaweed(side*29,-46,14)
  coral(side*23,-43,{.86,.20,.28});coral(side*15,-40,{.91,.67,.16})
  coral(side*35,-42,{.39,.67,.58})
 end
 -- The pink clam and pearl are the centrepiece of the reference scene.
 box(0,0,-46,23,1.4,13,white)
 for i=0,11 do
  local a,b=i*math.pi/12,(i+1)*math.pi/12
  local ra=11.7+(i%2)*1.1;local rb=11.7+((i+1)%2)*1.1
  quad({0,4,-46},{math.cos(a)*ra,5+math.sin(a)*ra,-47},
   {math.cos(b)*rb,5+math.sin(b)*rb,-47},{0,4,-46},{.98,.69,.72})
  quad({0,4.5,-45.7},{math.cos(a)*ra*.85,5+math.sin(a)*ra*.87,-46.7},
   {math.cos(b)*rb*.85,5+math.sin(b)*rb*.87,-46.7},{0,4.5,-45.7},i%2==0 and pink or{.98,.45,.57})
 end
 for i=-3,3 do box(i*2.6,1.6,-43+math.abs(i)*.25,2.8,1.5,7-math.abs(i)*.7,pink)end
 for i=0,7 do for j=0,15 do
  local function pearl(a,b)return{math.cos(a)*math.sin(b)*3.5,6+math.cos(b)*3.5,-42+math.sin(a)*math.sin(b)*3.5}end
  local a,b=j*math.pi/8,(j+1)*math.pi/8;local c,d=i*math.pi/8,(i+1)*math.pi/8
  quad(pearl(a,c),pearl(a,d),pearl(b,d),pearl(b,c),{1,.87,.86},.82+.17*math.sin(c))
 end end
 -- Two small turtle-shaped stone guardians at the entrance.
 for _,x in ipairs({-15,15})do
  box(x,0,55,6,1.7,6,{.28,.39,.46});box(x,1.7,55,5,1.0,5,{.63,.72,.74})
  box(x,2.7,55,3.6,4.2,2.5,{.47,.59,.65});box(x,6.9,55,2.9,2.3,2.8,{.66,.76,.79})
  box(x,3.3,53.5,4.1,3.8,1.7,{.32,.46,.53})
  for _,s in ipairs({-1,1})do box(x+s*2.2,3.7,55,1.1,2.2,1.3,{.57,.67,.70})end
 end
 floorRect(0,65,14,6,.03,{.91,.58,.67})
 badge(quad,0,23,-49.1,3.6)
end

return C
