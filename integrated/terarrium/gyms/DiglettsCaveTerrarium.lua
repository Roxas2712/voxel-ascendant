-- Diglett's Cave: compact earth-and-rock terrarium for PANDY.
-- Visual direction: ODias; based on the supplied LGPE cave and Diglett references.
-- Preserve the host bowl, cameras, participants, platforms and branding.
local R={revision='digletts-cave-compact-v1'}
function R.appliesTo(id)return id=='DIGLETTS_CAVE'end
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
 local rockTones={{.32,.26,.20},{.40,.33,.25},{.49,.40,.30},{.55,.46,.34},{.43,.35,.27}}
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
 local function beam(a,b,r,c,n)
  n=n or 7
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local l=math.sqrt(dx*dx+dy*dy+dz*dz)
  if l<.001 then return end
  dx,dy,dz=dx/l,dy/l,dz/l
  local ux,uy,uz=-dz,0,dx
  if math.abs(dy)>.95 then ux,uy,uz=1,0,0 end
  local ul=math.sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
  local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
  local function p(base,t)return{base[1]+r*(ux*math.cos(t)+vx*math.sin(t)),base[2]+r*(uy*math.cos(t)+vy*math.sin(t)),base[3]+r*(uz*math.cos(t)+vz*math.sin(t))}end
  for i=0,n-1 do local u,v=i*math.pi*2/n,(i+1)*math.pi*2/n
   quad(p(a,u),p(b,u),p(b,v),p(a,v),c,.84+.12*math.cos(u))
  end
 end
 local soil={.51,.41,.30}
 disk(0,.021,0,73.5,soil,96)
 -- Flat earth patches, small cracks and a gently winding lighter central path.
 for i=0,23 do local z=-69+i*5.8;local nz=z+5.8
  local x=math.sin(z*.035)*6;local nx=math.sin(nz*.035)*6
  if math.abs(z)<63 then
   quad({x-16,.03,z},{x+16,.03,z},{nx+16,.03,nz},{nx-16,.03,nz},{.55,.45,.33})
  end
 end
 for i=1,115 do local a=i*2.399963;local r=math.sqrt(i/116)*69
  local x,z=math.cos(a)*r,math.sin(a)*r
  local c=({{.53,.43,.32},{.48,.38,.28},{.57,.47,.35},{.50,.40,.30}})[i%4+1]
  for j=0,5 do local u,v=j*math.pi/3+i*.11,(j+1)*math.pi/3+i*.11
   local px,pz=clip(x+math.cos(u)*(2+i%4),z+math.sin(u)*2.2)
   local qx,qz=clip(x+math.cos(v)*(2+i%4),z+math.sin(v)*2.2)
   quad({x,.038,z},{px,.038,pz},{qx,.038,qz},{x,.038,z},c)
  end
 end
 -- Layered ledges: connected faceted shelves, broad at the foot and stepped back.
 local function ledge(x,z,rx,rz,h,seed)
  local n=10;local rings={}
  for level=1,6 do
   local sc=({1,.95,.76,.72,.53,.50})[level]
   local hy=({0,.32,.34,.67,.69,1})[level]
   rings[level]={}
   for i=1,n do local a=(i-1)*math.pi*2/n
    local wobble=1+.08*math.sin(i*3.2+seed)
    local px,pz=clip(x+math.cos(a)*rx*sc*wobble,z+math.sin(a)*rz*sc*wobble-(level-1)*.3)
    rings[level][i]={px,.06+h*(hy+(level>1 and .028*math.sin(i*2.3+seed) or 0)),pz}
   end
  end
  for level=1,5 do for i=1,n do local j=i%n+1
   local c=level%2==0 and {.57,.47,.34} or rockTones[(i+seed)%5+1]
   quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i],c)
  end end
  for i=1,n do local j=i%n+1
   quad({x,h+.06,z-1.5},rings[6][i],rings[6][j],{x,h+.06,z-1.5},{.53,.43,.31})
  end
 end
 ledge(-33,-52,20,15,22,1);ledge(0,-63,22,10,26,3);ledge(42,-52,14,9,23,2)
 ledge(-53,-26,13,17,14,4);ledge(56,-32,10,10,13,5)
 ledge(-62,0,8,10,7,6);ledge(62,6,8,10,7,7)
 -- Burrows have an opaque dark floor and an irregular raised soil lip.
 local function burrow(x,z,r)
  disk(x,.052,z,r*.94,{.19,.145,.10},20)
  for i=0,19 do local a,b=i*math.pi/10,(i+1)*math.pi/10
   local ra=r*(1.12+.07*math.sin(i*3));local rb=r*(1.12+.07*math.sin((i+1)*3))
   quad({x+r*.82*math.cos(a),.075,z+r*.82*math.sin(a)},
    {x+r*.82*math.cos(b),.075,z+r*.82*math.sin(b)},
    {x+rb*math.cos(b),.58,z+rb*math.sin(b)},{x+ra*math.cos(a),.58,z+ra*math.sin(a)},{.43,.33,.23})
   quad({x+ra*math.cos(a),.58,z+ra*math.sin(a)},{x+rb*math.cos(b),.58,z+rb*math.sin(b)},
    {x+rb*1.15*math.cos(b),.045,z+rb*1.15*math.sin(b)},
    {x+ra*1.15*math.cos(a),.045,z+ra*1.15*math.sin(a)},rockTones[i%3+2])
  end
 end
 -- Small low-poly Diglett sculptures derived from the supplied image.
 -- Brown rounded body, two black oval eyes and a pink oval nose; no limbs.
 local function oval(x,y,z,rx,ry,rz,c)
  local n,m=16,8
  local function p(i,j)
   local a=i*2*math.pi/n;local b=-math.pi/2+j*math.pi/m
   return{x+rx*math.cos(b)*math.cos(a),y+ry*math.sin(b),z+rz*math.cos(b)*math.sin(a)}
  end
  for j=0,m-1 do for i=0,n-1 do
   quad(p(i,j),p(i+1,j),p(i+1,j+1),p(i,j+1),c,.85+.15*j/(m-1))
  end end
 end
 local function diglett(x,z,s)
  burrow(x,z,4.3*s)
  local n=20;local rings={{0,2.45},{3.5,2.45},{5.2,2.3},{6.5,1.7},{7.1,.8},{7.3,0}}
  for j=1,#rings-1 do for i=0,n-1 do
   local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   local h,r=rings[j][1],rings[j][2];local nh,nr=rings[j+1][1],rings[j+1][2]
   quad({x+r*s*math.cos(a),.2+h*s,z+r*s*math.sin(a)},
    {x+r*s*math.cos(b),.2+h*s,z+r*s*math.sin(b)},
    {x+nr*s*math.cos(b),.2+nh*s,z+nr*s*math.sin(b)},
    {x+nr*s*math.cos(a),.2+nh*s,z+nr*s*math.sin(a)},
    {.61,.43,.31},.88+.10*math.sin(a)+.02*j/5)
  end end
  for _,dx in ipairs({-.87,.87})do
   oval(x+dx*s,4.98*s+.2,z+2.13*s,.26*s,.66*s,.20*s,{.055,.052,.043})
   oval(x+(dx-.055)*s,5.27*s+.2,z+2.30*s,.075*s,.14*s,.045*s,{.98,.96,.91})
  end
  oval(x,3.6*s+.2,z+2.42*s,1.15*s,.62*s,.57*s,{.78,.44,.56})
  oval(x-.24*s,3.85*s+.2,z+2.91*s,.27*s,.10*s,.045*s,{.93,.69,.77})
  for i=0,6 do local a=i*math.pi*2/7
   stone(x+math.cos(a)*3.4*s,z+math.sin(a)*3.3*s,1.05*s,.85*s,.85*s,i+1)
  end
 end
 diglett(-35,-32,1.10);diglett(44,28,.93);diglett(-34,47,.80)
 for _,p in ipairs({{-48,27,4.6},{35,-40,4.2},{34,51,4.5},{-17,-54,3.4},{55,-2,3.6}})do
  if clear(p[1],p[2],p[3]*2.6,p[3]*2.6)then burrow(p[1],p[2],p[3])end
 end
 -- Loose stones and compact rubble at the edge of the traversable clearing.
 for _,p in ipairs({{-55,36,5,4,3,2},{-45,48,4,4,3,4},{-25,60,4,3,2,3},
  {53,39,4,5,3,1},{42,51,4,4,2.7,5},{29,61,4,3,2.3,2}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 for i=1,30 do local a=i*2.399;local r=57+(i%4)*3
  local x,z=math.cos(a)*r,math.sin(a)*r
  if clear(x,z,4,4)then stone(x,z,1.1+(i%3)*.3,.9,1+(i%2)*.5,i)end
 end
end
return R
