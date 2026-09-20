-- Pokemon Tower: compact creation for PANDY, inspired by the supplied 7F concept.
-- Visual direction: ODias. Purple ghost illustration adapted as the front emblem.
-- Reuse host bowl, camera, participants, trainer plinths and branding.
local P={revision='pokemon-tower-compact-v1'}
function P.appliesTo(mapId)
 return type(mapId)=='string' and mapId:match('^POKEMON_TOWER_[2-7]F$')~=nil
end
local dark={.16,.14,.24}
local stone={.33,.29,.42}
local ivory={.81,.80,.75}
local lilac={.52,.43,.61}

function P.button(h)
 local q=h.quad
 local function at(p,d)return{p[1]*8.4,-6.5+p[2]*8.4,78.35+d}end
 local function poly(points,c,d)
  for i=2,#points-1 do q(at(points[1],d),at(points[i],d),at(points[i+1],d),at(points[1],d),c)end
 end
 -- Rounded purple ghost with pointed ears, crescent eyes, smile and clawed hands.
 local shape={{-.70,.88},{-.60,.38},{-.76,.08},{-.71,-.27},{-.47,-.48},{-.23,-.55},
  {-.12,-.72},{.12,-.79},{.30,-.68},{.17,-.61},{.37,-.50},{.64,-.29},{.72,.06},{.57,.38},{.68,.88},{.33,.66},{-.25,.64}}
 local center={0,.05}
 for i=1,#shape do local j=i%#shape+1
  q(at(center,0),at(shape[i],0),at(shape[j],0),at(center,0),i<9 and{.27,.10,.23}or{.37,.14,.30})
 end
 poly({{-.67,.84},{-.57,.42},{-.43,.56}}, {.53,.28,.43},.02)
 poly({{.64,.83},{.52,.42},{.38,.55}}, {.53,.28,.43},.02)
 local eyes={
  {{-.49,.27},{-.41,.39},{-.24,.42},{-.10,.32},{-.12,.24},{-.27,.32},{-.40,.33}},
  {{.10,.29},{.19,.41},{.37,.43},{.49,.35},{.47,.28},{.35,.34},{.22,.33}}}
 for _,e in ipairs(eyes)do poly(e,{1,.90,.59},.05)end
 poly({{-.37,.14},{-.24,.02},{-.07,-.03},{.12,.0},{.31,.16},{.19,.10},{.05,.13},{-.12,.08}}, {1,.98,.84},.055)
 for _,s in ipairs({-1,1})do
  local function mirror(points)local out={};for i,p in ipairs(points)do out[i]={s*p[1],p[2]}end;return out end
  poly(mirror({{.56,.05},{.75,.16},{.91,.06},{.99,-.12},{.92,-.31},{.83,-.15},{.77,-.36},{.68,-.15},{.58,-.28},{.53,-.08}}),{.20,.065,.16},.075)
  for i=0,2 do local x=.61+i*.14;local yy=-.11-(i%2)*.04
   poly(mirror({{x,yy},{x+.06,yy-.19},{x-.025,yy-.11}}),{.94,.83,.82},.08)
  end
 end
end

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
 local function disk(x,y,z,r,c,N)
  N=N or 16
  for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
   quad({x,y,z},{x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x,y,z},c)
  end
 end
 disk(0,.02,0,73.5,dark,96)
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(math.floor(x/8)*3+math.floor(z/8)*7+100)%4
   rect(x,z,7.7,7.7,.032,({{.25,.21,.35},{.29,.25,.38},{.22,.19,.31},{.31,.27,.41}})[n+1])
  end
 end end
 -- Widened ivory-and-mint aisle accommodates both compact participant layouts.
 rect(0,8,61,114,.039,{.61,.64,.58})
 for x=-28,28,4 do for z=-46,62,4 do
  local n=(math.floor(x/4)*3+math.floor(z/4)*7+200)%4
  local c=math.abs(x)>20 and({{.60,.72,.56},{.68,.78,.62},{.71,.79,.67},{.53,.63,.53}})[n+1]
   or({{.83,.82,.75},{.87,.86,.80},{.78,.78,.72},{.90,.88,.82}})[n+1]
  rect(x,z,3.86,3.86,.043,c)
 end end
 -- Rows of small gravestones: bevelled tops, inscription marks and offering cups.
 local function tomb(x,z,n)
  box(x,.035,z,7.5,.65,6.2,ivory);box(x,.685,z,6.5,.7,5.4,stone)
  box(x,1.385,z,5.2,1.2,4.2,dark)
  local outline={{-2.05,2.4},{2.05,2.4},{2.05,6.9},{1.6,7.8},{.65,8.25},{-.65,8.25},{-1.6,7.8},{-2.05,6.9}}
  for i=1,#outline do local j=i%#outline+1;local a,b=outline[i],outline[j]
   quad({x+a[1],a[2],z-.1},{x+b[1],b[2],z-.1},{x+b[1],b[2],z-1.8},{x+a[1],a[2],z-1.8},lilac,.82)
  end
  for i=2,#outline-1 do
   quad({x+outline[1][1],outline[1][2],z-.08},{x+outline[i][1],outline[i][2],z-.08},
    {x+outline[i+1][1],outline[i+1][2],z-.08},{x+outline[1][1],outline[1][2],z-.08},stone)
  end
  box(x,3.0,z+.01,3,3.5,.13,dark)
  for row=0,3 do
   box(x-.15+(row%2)*.2,3.45+row*.62,z+.10,1.35+((row+n)%3)*.23,.10,.05,{.52,.49,.58})
  end
  for _,s in ipairs({-1,1})do
   box(x+s*2,1.7,z+1.5,.9,.9,.9,stone)
   disk(x+s*2,2.61,z+1.5,.33,dark,12)
  end
 end
 local count=0
 for _,s in ipairs({-1,1})do for row=0,2 do
  local x=s*(40+row*10)
  for z=-30,36,11 do
   if (math.abs(x)+4)^2+(math.abs(z)+3.3)^2<71.5^2 and clear(x,z,8,7)then
    count=count+1;tomb(x,z,count)
   end
  end
 end end
 -- Low side divisions retain the orderly arrangement of the tower interior.
 for _,s in ipairs({-1,1})do for z=-31,35,11 do
  if clear(s*34,z,1,10)then box(s*34,0,z,.8,2.1,10.5,ivory)end
 end end
 -- Rear stepped memorial facade with pale framing and violet inset panels.
 for _,v in ipairs({{-29,20,9},{-18,25,10},{0,30,23},{18,25,10},{29,20,9}})do
  local x,height,w=v[1],v[2],v[3]
  box(x,0,-62,w,height,2.2,ivory)
  box(x,2,-60.75,w-2,height-4,.4,lilac)
  for _,dx in ipairs({-w/2+.65,w/2-.65})do box(x+dx,0,-60.4,.85,height,1.1,{.69,.69,.65})end
  box(x,height-.5,-62,w+.7,.85,2.7,ivory)
  for i=0,7 do local a,b=i*math.pi/8,(i+1)*math.pi/8;local r=(w-2)/2
   quad({x+math.cos(a)*r,height-5+math.sin(a)*r*.55,-60.3},{x+math.cos(b)*r,height-5+math.sin(b)*r*.55,-60.3},
    {x+math.cos(b)*(r-.35),height-5+math.sin(b)*(r-.35)*.55,-60.3},{x+math.cos(a)*(r-.35),height-5+math.sin(a)*(r-.35)*.55,-60.3},ivory)
  end
  if x==0 then
   for _,s in ipairs({-1,1})do
    quad({s*.7,4,-60.2},{s*1.4,4,-60.2},{s*1.4,18,-60.2},{s*.7,19,-60.2},{.65,.58,.73})
    quad({s*.7,17,-60.2},{s*7.3,24,-60.2},{s*7.3,25,-60.2},{s*.7,19,-60.2},{.65,.58,.73})
   end
  end
 end
 -- Altar, raised memorial block, purple mat and paired unlit candle fixtures.
 box(0,0,-52,32,3.6,12,stone);box(0,3.6,-52,33,1.2,12.6,ivory)
 box(0,4.8,-56,15,5.5,6,dark);box(0,10.3,-56,16,.8,6.4,stone)
 box(0,5.2,-52.85,11,1.8,.2,{.22,.18,.28})
 box(0,4.8,-48.3,14,.6,2.6,{.57,.45,.25})
 box(0,5.4,-48.3,12,.15,1.8,dark)
 for _,x in ipairs({-12,12})do
  box(x,4.8,-49,1.8,.45,1.8,{.64,.51,.27});box(x,5.25,-49,.45,2,.45,{.64,.51,.27})
  box(x,7.25,-49,1.25,.35,1.25,{.64,.51,.27});box(x,7.6,-49,.68,1.5,.68,ivory)
 end
 rect(0,-40,25,9,.046,{.27,.12,.30});rect(0,-40,23,7,.048,{.44,.18,.41})
 for _,x in ipairs({-10,10})do rect(x,-40,.3,6,.05,{.30,.12,.31})end
 -- Small faceted ellipsoids for the fox statues and memorial flowers.
 local function oval(x,y,z,rx,ry,rz,c)
  local rings={}
  for j=0,4 do local a=-math.pi/2+j*math.pi/4;rings[j+1]={}
   for i=0,7 do local b=i*math.pi/4
    rings[j+1][i+1]={x+math.cos(a)*math.cos(b)*rx,y+math.sin(a)*ry,z+math.cos(a)*math.sin(b)*rz}
   end
  end
  for j=1,4 do for i=1,8 do local k=i%8+1
   quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],c,.77+j*.035+(i%3)*.04)
  end end
 end
 for _,s in ipairs({-1,1})do
  local x,z=s*24,-54
  box(x,0,z,7.5,1.2,7.5,stone);box(x,1.2,z,6.2,4.7,6.2,dark);box(x,5.9,z,7,.7,7,ivory)
  -- Ninetales-inspired pale sculpture: seated body, muzzle, ears and nine tails.
  oval(x,8.7,z,1.65,2.5,1.65,ivory)
  oval(x-s*.6,11.2,z+.5,1.4,1.4,1.2,ivory)
  oval(x-s*1.7,10.9,z+1.1,1.0,.48,.65,ivory)
  for _,dz in ipairs({-.3,1.1})do
   quad({x-s*1.1,12,z+dz},{x+s*.2,12,z+dz},{x-s*.2,14,z+dz},{x-s*1.1,12,z+dz},ivory)
  end
  for j=0,8 do local a=-1.1+j*.275
   local tx=x+s*(2.2+math.cos(a)*1.6);local tz=z-1.4+math.sin(a)*2.6
   oval(tx,9+math.cos(a)*1.4,tz,1.05,2.4,1.0,ivory)
  end
  for _,dx in ipairs({-.75,.75})do box(x+dx,6.6,z+1.0,.7,1.9,1.6,ivory)end
  -- Small offering vase behind the altar.
  box(s*11,4.8,-57,1.5,1.8,1.5,stone)
  for j=0,2 do oval(s*11+(j-1)*.5,7.5+j*.5,-57,1,1.3,.8,{.27,.40,.30})end
 end
 -- Low perimeter frames imply the curved interior without enclosing the top.
 for _,s in ipairs({-1,1})do for _,z in ipairs({-35,-13,10,32})do
  local x=s*64
  if x*x+(math.abs(z)+4)^2<73^2 and clear(x,z,2,8)then
   box(x,0,z,1.4,13,8,ivory);box(x-s*.85,1.5,z,.2,10,5.7,lilac)
   box(x,12.5,z,1.8,.8,8.4,ivory)
  end
 end end
 -- Entry stair motif remains a thin floor treatment at the compact ground plane.
 rect(0,66,17,10,.047,stone)
 for z=62,70,2 do rect(0,z,14,1.75,.050,ivory)end
end
return P
