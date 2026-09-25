-- Seafoam Islands: compact frozen cave terrarium for PANDY.
-- Visual direction: ODias; supplied LGPE and FRLG Articuno-scene references.
-- Preserve host bowl, cameras, participants, platforms and branding.
local R={revision='seafoam-islands-ice-compact-v1'}
local maps={SEAFOAM_ISLANDS_1F=true,SEAFOAM_ISLANDS_B1F=true,SEAFOAM_ISLANDS_B2F=true,SEAFOAM_ISLANDS_B3F=true,SEAFOAM_ISLANDS_B4F=true}
function R.appliesTo(id)return maps[id]==true end
function R.button(h)end
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
 local rockTones={{.18,.29,.36},{.23,.36,.43},{.30,.44,.50},{.38,.50,.55},{.24,.38,.46}}
 local function clip(x,z)
  local r=math.sqrt(x*x+z*z)
  if r>72.9 then return x/r*72.9,z/r*72.9 end
  return x,z
 end
 local function stone(x,z,rx,rz,height,seed,y0)
  y0=y0 or .045
  local n=7;local rings={}
  for j=0,2 do
   rings[j+1]={}
   local scale=({1,.90,.52})[j+1];local h=({0,.49,.90})[j+1]
   for i=0,n-1 do local a=i*math.pi*2/n+.17*seed
    local wobble=1+.13*math.sin(i*4.7+seed+j*.6)
    local px,pz=clip(x+math.cos(a)*rx*scale*wobble+j*.16,z+math.sin(a)*rz*scale*wobble)
    rings[j+1][i+1]={px,y0+height*(h+(j>0 and .045*math.sin(i*2.9+seed)or 0)),pz}
   end
  end
  for j=1,2 do for i=1,n do local k=i%n+1
   local a,b,c,d=rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i]
   quad(a,b,c,a,rockTones[(i+seed+j)%5+1],.94)
   quad(a,c,d,a,rockTones[(i+seed+j+1)%5+1],.92)
  end end
  for i=1,n do local k=i%n+1
   local tip={x-.16*rx,y0+height,z+.08*rz}
   quad(tip,rings[3][i],rings[3][k],tip,({{.65,.80,.84},{.75,.87,.89},{.58,.74,.80}})[(i+seed)%3+1])
  end
 end
 local ice={.66,.80,.85};local frost={.83,.91,.92};local water={.15,.36,.53}
 disk(0,.021,0,73.5,water,96)
 -- An angular ice shelf surrounded by a narrow strip of blue water.
 for i=0,47 do local a,b=i*math.pi/24,(i+1)*math.pi/24
  local r=64+1.2*math.sin(a*6);local s=64+1.2*math.sin(b*6)
  local x,z=r*math.cos(a),r*math.sin(a);local u,v=s*math.cos(b),s*math.sin(b)
  quad({0,.065,0},{x,.065,z},{u,.065,v},{0,.065,0},ice)
  quad({x,.066,z},{u,.066,v},{u*1.027,.039,v*1.027},{x*1.027,.039,z*1.027},frost)
 end
 -- Frosted patches stay flat beneath the host participants.
 for i=1,110 do local a=i*2.399963;local r=math.sqrt(i/111)*59.5
  local x,z=math.cos(a)*r,math.sin(a)*r
  local c=({{.72,.84,.87},{.77,.87,.88},{.61,.76,.83},{.69,.81,.88}})[i%4+1]
  for j=0,5 do local u,v=j*math.pi/3+i*.12,(j+1)*math.pi/3+i*.12
   quad({x,.075,z},{x+math.cos(u)*(2.5+i%4),.075,z+math.sin(u)*2.4},
    {x+math.cos(v)*(2.5+i%4),.075,z+math.sin(v)*2.4},{x,.075,z},c)
  end
 end
 -- Fine branched cracks are surface marks, not actual holes.
 for i=1,14 do local a=i*2.399;local r=14+(i%4)*11
  local x,z=math.cos(a)*r,math.sin(a)*r
  for j=0,2 do local dx,dz=math.cos(a+j*.6)*2.8,math.sin(a+j*.6)*2.8
   quad({x,.084,z},{x+.10,.084,z-.07},{x+dx+.10,.084,z+dz-.07},{x+dx,.084,z+dz},{.41,.62,.72})
   x,z=x+dx,z+dz
  end
 end
 -- Dark, frost-capped rock masses frame the back and descend to the sides.
 for _,p in ipairs({{-24,-59,12,10,17,1},{22,-60,12,9,17,2},{-48,-42,10,11,12,3},
  {51,-40,10,10,12,4},{-59,-20,8,10,7,5},{62,7,6,8,5,6}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 -- Freestanding ice columns reinterpret the tall frozen supports in the reference.
 -- They finish inside the open terrarium and do not support a ceiling.
 local facets={{.35,.61,.73},{.46,.71,.81},{.62,.83,.89},{.74,.90,.94},{.43,.68,.79},{.54,.77,.86},{.39,.65,.77},{.68,.87,.93}}
 local function column(x,z,r,h,seed)
  local n=8;local rings={}
  for j=1,5 do local sc=({1.32,.88,.70,.82,.98})[j];local hy=({0,.12,.48,.82,1})[j]
   rings[j]={}
   for i=1,n do local a=(i-1)*math.pi/4+.13*seed
    rings[j][i]={x+math.cos(a)*r*sc+(j-1)*.22,.12+h*hy+(j==5 and .75*math.sin(i*2.3+seed)or 0),z+math.sin(a)*r*sc}
   end
  end
  for j=1,4 do for i=1,n do local k=i%n+1
   quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],facets[(i+seed)%8+1],.95+.015*j)
  end end
  for i=1,n do local k=i%n+1
   quad({x+.9,h+.35,z},rings[5][i],rings[5][k],{x+.9,h+.35,z},frost)
  end
 end
 column(-37,-44,4.8,30,1);column(0,-63,5.4,35,2);column(39,-47,4.5,31,4)
 -- Short crystalline ice spikes, lower toward the viewer.
 local function shard(x,z,r,h,lean)
  local n=6;local tip={x+lean,h+.10,z-.4}
  for i=0,n-1 do local a,b=i*math.pi/3,(i+1)*math.pi/3
   local A={x+r*math.cos(a),.09,z+r*math.sin(a)}
   local B={x+r*math.cos(b),.09,z+r*math.sin(b)}
   quad(A,B,tip,A,facets[i+1])
  end
 end
 for _,p in ipairs({{-58,30,1.6,7},{55,31,1.6,7},{-42,47,1.5,5.5},{42,49,1.4,5.5},
  {-27,-49,1.5,8},{29,-54,1.5,9}})do
  shard(p[1],p[2],p[3],p[4],.7)
  shard(p[1]+2.5,p[2]+1.3,p[3]*.65,p[4]*.55,-.3)
 end
 -- Low fractured ice ridges along the margins, inspired by the LGPE foreground.
 for _,p in ipairs({{-43,33},{45,36},{-24,59},{26,59}})do
  for j=0,5 do local x,z=p[1]+(j-2.5)*1.5,p[2]+.65*math.sin(j*2)
   if clear(x,z,3,3)then shard(x,z,.85,1.6+(j%3)*.6,.8)end
  end
 end
 -- Broad frozen steps lead to a small rear rock shelf.
 box(0,.085,-53,16,3.5,8,{.41,.60,.69})
 rect(0,-53,16,8,3.60,frost)
 for i=0,3 do
  box(0,.085,-43-i*1.6,15, .85*(i+1),1.72,{.49,.68,.77})
  rect(0,-43-i*1.6,14.9,1.66,.105+.85*(i+1),ice)
 end
 -- Snow-covered boulders and small broken ice floes in the surrounding water.
 for _,p in ipairs({{-56,34,4,4,3,2},{-40,51,3.5,3.5,2.5,3},{35,55,3.5,3,2.5,5},{55,37,4,4,3,4}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 for i=0,21 do local a=i*math.pi/11;local r=69.2
  local x,z=r*math.cos(a),r*math.sin(a)
  if i%3==0 then
   quad({x-1.5,.053,z-1},{x+1.4,.053,z-.7},{x+1.1,.053,z+1},{x-1,.053,z+1.3},frost)
  else rect(x,z,1.9,.14,.055,{.43,.66,.77})end
 end
end
return R
