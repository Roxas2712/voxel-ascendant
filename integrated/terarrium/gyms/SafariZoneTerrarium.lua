-- Safari Zone: compact savanna terrarium for PANDY.
-- Visual direction: ODias; supplied safari.jpg and safari2.jpg references.
-- Preserve host bowl, cameras, participants, trainer platforms and branding.
local R={revision='safari-zone-savanna-compact-v1'}
local maps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
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
 local rockTones={{.38,.40,.36},{.46,.48,.41},{.55,.55,.45},{.62,.60,.49},{.48,.51,.47}}
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
 local earth={.65,.56,.34};local gold={.77,.65,.36};local bark={.37,.29,.18}
 disk(0,.021,0,73.5,earth,96)
 -- Flat meadow and worn grass colors leave the middle traversable.
 for i=1,145 do local a=i*2.399963;local r=math.sqrt(i/146)*70
  local x,z=math.cos(a)*r,math.sin(a)*r
  local c=({{.68,.59,.36},{.71,.62,.39},{.60,.55,.32},{.73,.64,.40},{.62,.58,.35}})[i%5+1]
  for j=0,6 do local u,v=j*math.pi*2/7+i*.12,(j+1)*math.pi*2/7+i*.12
   local px,pz=clip(x+math.cos(u)*(3+i%4),z+math.sin(u)*2.6)
   local qx,qz=clip(x+math.cos(v)*(3+i%4),z+math.sin(v)*2.6)
   quad({x,.034,z},{px,.034,pz},{qx,.034,qz},{x,.034,z},c)
  end
 end
 -- Irregular waterhole tucked into the left front margin.
 local px,pz=-46,33
 local function pondPoint(a,r)
  local wobble=1+.07*math.sin(a*5)+.035*math.cos(a*3)
  return{px+15*r*wobble*math.cos(a),.055,pz+10*r*wobble*math.sin(a)}
 end
 for i=0,47 do local a,b=i*math.pi/24,(i+1)*math.pi/24
  local A,B=pondPoint(a,1),pondPoint(b,1)
  local C,D=pondPoint(b,1.13),pondPoint(a,1.13)
  C[2]=.045;D[2]=.045
  quad(A,B,C,D,{.45,.53,.35})
  quad({px,.055,pz},A,B,{px,.055,pz},{.26,.53,.61})
  local E,F=pondPoint(a,.83),pondPoint(b,.83);E[2]=.059;F[2]=.059
  quad(E,F,B,A,{.36,.62,.64})
 end
 for i=0,7 do local z=pz-6+i*1.7;local x=px+math.sin(i*2)*6
  rect(x,z,2.5+i%3,.13,.065,{.66,.81,.75})
 end
 -- Branching acacias with flattened, overlapping faceted leaf crowns.
 local greens={{.35,.46,.22},{.44,.54,.28},{.50,.59,.31},{.57,.64,.36},{.40,.51,.25}}
 local function crown(x,y,z,rx,rz,seed)
  local n=12;local low,edge,top={},{},{}
  for i=1,n do local a=(i-1)*math.pi/6
   local w=1+.10*math.sin(i*3.2+seed)
   low[i]={x+math.cos(a)*rx*.72,y-.9,z+math.sin(a)*rz*.72}
   edge[i]={x+math.cos(a)*rx*w,y+.2,z+math.sin(a)*rz*w}
   top[i]={x+math.cos(a)*rx*.65,y+2.6+.35*math.sin(i+seed),z+math.sin(a)*rz*.65}
  end
  for i=1,n do local j=i%n+1
   quad(low[i],low[j],edge[j],edge[i],greens[1])
   quad(edge[i],edge[j],top[j],top[i],greens[(i+seed)%3+2])
   quad({x,y+3.1,z},top[i],top[j],{x,y+3.1,z},greens[(i+seed)%3+3])
   quad({x,y-.95,z},low[j],low[i],{x,y-.95,z},greens[1])
  end
 end
 local function acacia(x,z,s,seed)
  local fork={x+1.8*s,17*s,z-.7*s}
  beam({x,.04,z},{x-1.1*s,8*s,z},1.35*s,bark,8)
  beam({x-1.1*s,8*s,z},fork,1.05*s,bark,8)
  for i=1,5 do local a=(i-1)*math.pi*2/5+.3*seed
   local ex=x+math.cos(a)*9*s;local ez=z+math.sin(a)*5*s;local ey=(23+i%2)*s
   local middle={x+math.cos(a)*4*s,20*s,z+math.sin(a)*2*s}
   beam(fork,middle,.67*s,bark,7);beam(middle,{ex,ey,ez},.43*s,bark,7)
   crown(ex,ey,ez,8.5*s,4.7*s,seed+i)
  end
  crown(x,25*s,z,10*s,6.5*s,seed)
  for i=0,3 do local a=i*math.pi/2+.4
   beam({x,.4,z},{x+math.cos(a)*3*s,.055,z+math.sin(a)*3*s},.45*s,bark,6)
  end
 end
 acacia(-37,-46,1.05,1);acacia(23,-59,.94,3);acacia(53,-29,.70,2)
 -- Golden grass tufts in the outer meadow; clipped away from the water and people.
 local function tuft(x,z,h,seed,green)
  local c=green and {.39,.53,.29} or ({gold,{.64,.53,.27},{.83,.72,.42}})[seed%3+1]
  for k=0,4 do local a=k*2.399+seed*.7
   local dx,dz=math.cos(a),math.sin(a);local w=.43
   local tx,tz=clip(x+dx*1.1,z+dz*1.1)
   quad({x-dz*w,.055,z+dx*w},{x+dz*w,.055,z-dx*w},{tx,h*(.7+.06*k),tz},{x-dz*w,.055,z+dx*w},c)
  end
 end
 for i=1,420 do local a=i*2.399963;local r=44+math.sqrt(i/420)*27.5
  local x,z=math.cos(a)*r,math.sin(a)*r
  local pond=((x-px)/18)^2+((z-pz)/13)^2
  if pond>1 and clear(x,z,3,3)then tuft(x,z,3.4+(i%5)*.55,i,i%6==0)end
 end
 -- Reeds and a handful of stones around the lagoon, with an open water surface.
 for _,a in ipairs({.25,.6,1.0,1.4,2.1,2.7,3.3,3.7,4.0,4.6,5.1})do
  local p=pondPoint(a,1.13)
  if clear(p[1],p[3],3,3)then
   tuft(p[1],p[3],3.9,math.floor(a*10),true)
   beam({p[1],.07,p[3]},{p[1]+.22,4.4,p[3]},.075,{.39,.43,.21},5)
   beam({p[1]+.22,3.7,p[3]},{p[1]+.22,4.65,p[3]},.18,{.40,.29,.18},6)
  end
 end
 for _,p in ipairs({{-59,25,2.7,2,1.7,2},{-56,42,3,2.3,2,4},{-34,39,2,2,1.2,1},
  {-49,-43,5,4,3,3},{42,-47,4,3,2.6,5},{57,37,4,3,2.7,2},{37,56,3,3,2,1}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 -- Low shrubs add green accents among the dry grasses.
 for _,p in ipairs({{-58,-20,3.3,2.4},{-26,-63,3.5,2.5},{46,-44,3.2,2.4},{61,25,2.7,2},{27,62,2.7,2}})do
  crown(p[1],1.0,p[2],p[3],p[4],2)
 end
end
return R
