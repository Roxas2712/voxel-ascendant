-- Celadon Gym / Erika. Compact terrarium for integration by PANDY.
-- Visual direction: ODias; supplied Let's Go concept art and Rainbow Badge.
-- The host supplies the bowl, camera, actors, trainer plinths and branding.
local C={revision='celadon-compact-v1'}
local leaf={.23,.44,.12}
local leafLight={.40,.59,.20}
local leafDark={.11,.29,.10}
local bark={.35,.22,.12}
local stone={.80,.76,.62}
local flowers={{.96,.41,.65},{.98,.79,.22},{.84,.86,.97},{.49,.54,.90},{.92,.54,.21}}
function C.appliesTo(mapId)return mapId=='CELADON_GYM'end

function C.button(h)
 local quad=h.quad
 local colors={{1,.07,.22},{1,.42,.025},{1,.91,.14},{.62,.98,.14},
  {.25,.82,.03},{.16,.89,.85},{.08,.41,.95},{.92,.15,.85}}
 local function at(a,r,t,d)return{math.cos(a)*r-math.sin(a)*t,-7+math.sin(a)*r+math.cos(a)*t,78.35+d}end
 for i=1,8 do
  local a=math.pi/2-(i-1)*math.pi/4;local col=colors[i]
  local polygon={{3.15,-1.1},{3.15,1.1},{6.45,2.65},{8.3,1.45},{8.3,-1.45},{6.45,-2.65}}
  local hi={};local lo={}
  for k=1,3 do hi[k]=col[k]*.44+.56;lo[k]=col[k]*.61 end
  for j=1,6 do local k=j%6+1;local p,q=polygon[j],polygon[k]
   local function inner(v)return{5.9+(v[1]-5.9)*.73,v[2]*.73}end
   local u,v=inner(p),inner(q)
   quad(at(a,5.9,0,0),at(a,p[1],p[2],0),at(a,q[1],q[2],0),at(a,5.9,0,0),{.06,.08,.07})
   quad(at(a,5.9+(p[1]-5.9)*.96,p[2]*.96,.03),at(a,5.9+(q[1]-5.9)*.96,q[2]*.96,.03),at(a,v[1],v[2],.03),at(a,u[1],u[2],.03),j<4 and hi or lo)
   quad(at(a,5.9,0,.05),at(a,u[1],u[2],.05),at(a,v[1],v[2],.05),at(a,5.9,0,.05),col)
  end
 end
 -- Four silver inner petals and a small square clasp, as in the reference.
 for i=0,3 do local a=math.pi/4+i*math.pi/2
  quad(at(a,.7,-.7,.06),at(a,2.8,-1,.06),at(a,3.1,.8,.06),at(a,.8,1,.06),{.64,.66,.64})
  quad(at(a,2.1,-.7,.08),at(a,2.8,-1,.08),at(a,3.1,.8,.08),at(a,2.3,.5,.08),{.94,.95,.93})
 end
 quad({-1.25,-8.25,78.46},{1.25,-8.25,78.46},{1.25,-5.75,78.46},{-1.25,-5.75,78.46},{.30,.32,.31})
 quad({-.88,-7.88,78.48},{.88,-7.88,78.48},{.88,-6.12,78.48},{-.88,-6.12,78.48},{.96,.97,.94})
 quad({-.47,-7.64,78.49},{.47,-7.64,78.49},{.47,-6.36,78.49},{-.47,-6.36,78.49},{.66,.68,.66})
end

function C.build(h,setup)
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
 local function disk(x,y,z,r,c)
  for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
   quad({x,y,z},{x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x,y,z},c)
  end
 end
 -- Grassy circular ground and a light stone network through the garden.
 disk(0,.02,0,73.5,{.36,.49,.18})
 for x=-68,68,4 do for z=-68,68,4 do
  if (math.abs(x)+2)^2+(math.abs(z)+2)^2<72.5^2 then
   local path=math.abs(x)<8 or (math.abs(z)<8 and math.abs(x)<52)
     or (math.abs(x)>25 and math.abs(x)<34 and math.abs(z)<41)
     or (math.abs(z)>31 and math.abs(z)<39 and math.abs(x)<50)
   if path then
    local n=(x*11+z*7+4000)%5
    rect(x,z,3.85,3.85,.036,({{.83,.79,.66},{.90,.86,.73},{.77,.75,.67},{.86,.79,.61},{.92,.88,.77}})[n+1])
   elseif (x*7+z*3)%7==0 then
    rect(x,z,2.2,.3,.032,{.42,.54,.22})
   end
  end
 end end
 -- Low-poly foliage ellipsoids, with a bounded shared palette.
 local function foliage(x,y,z,rx,ry,rz,c)
  local rings={}
  for j=0,4 do
   local a=-math.pi/2+j*math.pi/4;rings[j+1]={}
   for i=0,7 do local b=i*math.pi/4
    rings[j+1][i+1]={x+math.cos(a)*math.cos(b)*rx,y+math.sin(a)*ry,z+math.cos(a)*math.sin(b)*rz}
   end
  end
  for j=1,4 do for i=1,8 do local k=i%8+1
   quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],c,.70+j*.06+(i%3)*.035)
  end end
 end
 local function flower(x,y,z,c,size)
  size=size or .72
  box(x,y-.65,z,.20,.65,.20,leafDark)
  for i=0,4 do local a=i*math.pi*.4;local px,pz=x+math.cos(a)*size*.67,z+math.sin(a)*size*.67
   rect(px,pz,size,size,y,c)
  end
  rect(x,z,size*.6,size*.6,y+.04,{1,.87,.32})
 end
 -- Segmented hedges suggest the maze without enclosing the participants.
 local seed=0
 local function hedge(x,z,w,d)
  if not clear(x,z,w,d)then return end
  seed=seed+1
  box(x,.03,z,w,4.7,d,leafDark)
  box(x,4.73,z,w+.4,.85,d+.4,leaf)
  box(x-.5,5.58,z-.4,w-.8,.25,d-.8,leafLight)
  if seed%2==0 then flower(x,5.95,z,flowers[seed%5+1],.8)end
 end
 for _,s in ipairs({-1,1})do
  for z=-36,36,6 do hedge(s*45,z,5.5,5.9)end
  for x=15,39,6 do hedge(s*x,-28,5.9,5.4);hedge(s*x,28,5.9,5.4)end
  for z=-22,22,6 do if math.abs(z)>10 then hedge(s*20,z,5.2,5.9)end end
  for x=16,40,6 do hedge(s*x,43,5.9,5.2)end
 end
 -- Flower borders follow the curved edge of the bowl.
 for i=0,35 do
  local a=i*math.pi/18;local x,z=math.cos(a)*64,math.sin(a)*64
  if z>-37 and math.abs(x)>11 and clear(x,z,5,5)then
   foliage(x,1.4,z,3,1.35,2.5,leaf)
   for j=0,2 do flower(x+(j-1)*1.3,2.8,z+(j%2)*.8,flowers[(i+j)%5+1],.65)end
  end
 end
 -- Erika's raised garden island and mature tree at the rear.
 disk(0,.045,-50,18,{.65,.42,.28})
 disk(0,.07,-50,16.9,{.47,.59,.24})
 box(0,.07,-53,4.5,20,4.5,bark)
 box(-2.6,12,-53,2.5,9,3,bark);box(3,15,-53,3,10,3,bark)
 for _,v in ipairs({{-4,-51,7,1.6,2},{3,-50,5,1.1,3},{1,-56,3,1.8,6}})do box(v[1],.08,v[2],v[3],v[4],v[5],bark)end
 foliage(0,26,-54,17,10,12,leafDark)
 foliage(-10,28,-52,11,8,10,leaf)
 foliage(10,29,-54,10,8,10,leaf)
 foliage(-2,35,-55,12,7,9,leafLight)
 foliage(6,33,-48,9,6,8,leafLight)
 for _,s in ipairs({-1,1})do
  for _,z in ipairs({-47,-55})do
   local x=s*12
   if clear(x,z,5,5)then
    box(x,.08,z,1,4,1,bark);foliage(x,5,z,3.3,2.5,3,leaf)
    for j=0,2 do flower(x+j-1,7.4,z+(j%2),flowers[1],.55)end
   end
  end
  for i=0,4 do flower(s*(5+i*1.5),.7,-40+(i%2)*1.4,flowers[4],.7)end
 end
 -- Short greenhouse window panels; open sky above, no roof or dome.
 for _,x in ipairs({-34,-24,24,34})do
  box(x,0,-58,9,1.8,2,{.60,.41,.28})
  box(x,1.8,-58,8,12,.4,{.48,.72,.77})
  for _,dx in ipairs({-4,0,4})do box(x+dx,1.8,-57.6,.35,12,.45,bark)end
  for _,y in ipairs({2,7,13.5})do box(x,y,-57.6,8.3,.35,.45,bark)end
  quad({x-3.7,9,-57.35},{x-1.9,9,-57.35},{x+2.1,13.1,-57.35},{x+.3,13.1,-57.35},{.72,.88,.86})
 end
 -- Small rose-covered entrance arch, scaled below the battle sight lines.
 for _,s in ipairs({-1,1})do
  box(s*9,0,48,1,12,1,bark)
  foliage(s*9,6,48,2.3,6,2.2,leaf)
 end
 for i=0,6 do
  local a=i*math.pi/6;local x=math.cos(a)*9;local y=11+math.sin(a)*5
  foliage(x,y,48,2.8,2,2.2,leaf)
  flower(x,y+1.8,48.5,flowers[i%2==0 and 1 or 3],.65)
 end
 for _,x in ipairs({-16,16})do
  if clear(x,57,5,5)then
   box(x,0,57,5,1,5,stone);box(x,1,57,3.7,3.2,3.7,{.53,.60,.52})
   box(x,4.2,57,3.2,2.1,3,stone)
  end
 end
end
return C
