-- Mt. Moon: open compact cave terrarium for PANDY.
-- Visual direction: ODias; supplied moon.jpg and LGPE Mt. Moon references.
-- Preserve host bowl, cameras, participants, trainer platforms and branding.
local R={revision='mt-moon-compact-v1'}
local maps={MT_MOON_1F=true,MT_MOON_B1F=true,MT_MOON_B2F=true}
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
 local rockTones={{.31,.32,.38},{.39,.39,.43},{.47,.46,.46},{.52,.50,.47},{.38,.40,.48}}
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
   quad(tip,rings[3][i],rings[3][k],tip,rockTones[(i+seed)%3+2])
  end
 end
 -- Dry, level earth across the battle area.
 disk(0,.021,0,73.5,{.47,.44,.40},96)
 for i=1,130 do local a=i*2.399963;local r=math.sqrt(i/131)*70
  local x,z=math.cos(a)*r,math.sin(a)*r
  local c=({{.49,.46,.42},{.44,.42,.39},{.52,.49,.44},{.46,.43,.41}})[i%4+1]
  for j=0,6 do local u,v=j*math.pi*2/7+i*.13,(j+1)*math.pi*2/7+i*.13
   local px,pz=clip(x+math.cos(u)*(2.7+i%4),z+math.sin(u)*2.3)
   local qx,qz=clip(x+math.cos(v)*(2.7+i%4),z+math.sin(v)*2.3)
   quad({x,.033,z},{px,.033,pz},{qx,.033,qz},{x,.033,z},c)
  end
 end
 -- Worn circular floor markings from the LGPE interior, all flat.
 for _,p in ipairs({{-28,14,5.4},{0,-4,6},{27,-8,5.2}})do
  local x,z,r=p[1],p[2],p[3]
  for i=0,25 do local a,b=i*math.pi/13,(i+1)*math.pi/13
   local c=i%4==0 and {.48,.45,.40} or {.40,.38,.34}
   quad({x+r*math.cos(a),.041,z+r*.72*math.sin(a)},
    {x+r*math.cos(b),.041,z+r*.72*math.sin(b)},
    {x+(r-.48)*math.cos(b),.041,z+(r-.48)*.72*math.sin(b)},
    {x+(r-.48)*math.cos(a),.041,z+(r-.48)*.72*math.sin(a)},c)
  end
 end
 -- Rock shelves and walls kept around the perimeter of the open bowl.
 for _,p in ipairs({{-32,-55,14,11,20,1},{-47,-42,11,12,17,2},{-56,-22,9,12,11,3},
  {-63,0,6,9,6,4},{35,-55,12,9,21,5},{51,-37,10,10,15,6},{63,7,6,9,6,7}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 -- Tall tapered stalagmites with asymmetric faceted profiles.
 local function spire(x,z,r,h,seed)
  local n=7;local rings={}
  for j=1,4 do local sc=({1,.67,.27,0})[j];local hy=({0,.28,.73,1})[j]
   rings[j]={}
   for i=1,n do local a=(i-1)*math.pi*2/n
    rings[j][i]={x+math.cos(a)*r*sc+(j-1)*.17,.06+h*hy,z+math.sin(a)*r*sc}
   end
  end
  for j=1,3 do for i=1,n do local k=i%n+1
   quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],rockTones[(i+seed)%5+1])
  end end
 end
 for _,p in ipairs({{-42,-48,3,25,1},{-56,-32,2.7,19,2},{43,-47,3.2,26,3},
  {60,-27,2.2,15,4},{-60,26,2.3,8,5},{59,31,2.4,8,2},{-44,48,2,6,1},{44,49,2,6,3}})do
  spire(p[1],p[2],p[3],p[4],p[5])
 end
 -- Main blue moon rock: a broad faceted dome at the back of the clearing.
 -- The object is a stone, not a ceiling or a sky backdrop.
 local cx,cz=0,-56.8
 local function moonPoint(a,b,offset)
  local r=math.cos(b);offset=offset or 0
  return{cx+(20.0+offset)*r*math.cos(a),.09+(21.0+offset)*math.sin(b),cz+(10.2+offset)*r*math.sin(a)}
 end
 local moonColors={{.29,.43,.62},{.34,.49,.68},{.38,.54,.72},{.32,.46,.65},{.42,.57,.74}}
 for j=0,8 do for i=0,31 do
  local a,b=i*math.pi/16,(i+1)*math.pi/16
  local u,v=j*math.pi/18,(j+1)*math.pi/18
  local ci=math.max(1,math.min(5,math.floor(2.5+1.25*math.sin(a)+j*.13)))
  quad(moonPoint(a,u),moonPoint(b,u),moonPoint(b,v),moonPoint(a,v),moonColors[ci],.96+.025*math.sin(i*.8+j*.5))
 end end
 -- Shallow crater-like marks follow the same faceted dome surface.
 -- Small patches are placed within individual faces, avoiding detached decals.
 for _,p in ipairs({{6,2},{10,3},{13,1},{4,4},{9,5},{12,4},{7,6},{3,1},{14,3}})do
  local i,j=p[1],p[2]
  local a,b=(i+.2)*math.pi/16,(i+.8)*math.pi/16
  local u,v=(j+.2)*math.pi/18,(j+.65)*math.pi/18
  -- Bilinear interpolation on the parent quad keeps the patch above its surface.
  local aa,bb=i*math.pi/16,(i+1)*math.pi/16
  local uu,vv=j*math.pi/18,(j+1)*math.pi/18
  local A,B,C,D=moonPoint(aa,uu),moonPoint(bb,uu),moonPoint(bb,vv),moonPoint(aa,vv)
  local function on(s,t)
   local q={}
   for k=1,3 do q[k]=(1-t)*((1-s)*A[k]+s*B[k])+t*((1-s)*D[k]+s*C[k])end
   q[1]=q[1]+.018*math.cos((aa+bb)/2);q[2]=q[2]+.018;q[3]=q[3]+.025
   return q
  end
  quad(on(.2,.2),on(.8,.2),on(.68,.65),on(.28,.65),{.24,.36,.53})
 end
 -- Small stones form a broken ring around the foot of the moon rock.
 for i=0,14 do local a=i*math.pi/14
  stone(cx+21.5*math.cos(a),cz+11.2*math.sin(a),1.9,1.7,1.9,i+2)
 end
 -- Scattered rubble stays low at the front and clear of trainer platforms.
 for _,p in ipairs({{-55,37,4,4,3,1},{-34,57,4,3,2.8,3},{-9,66,3,3,2,4},
  {29,61,3.5,3,2.5,2},{53,40,4,4,3,5}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 for i=1,30 do local a=i*2.399;local r=58+(i%4)*3
  local x,z=math.cos(a)*r,math.sin(a)*r
  if clear(x,z,4,4)then stone(x,z,1.1+(i%3)*.25,.9,1+(i%2)*.4,i)end
 end
end
return R
