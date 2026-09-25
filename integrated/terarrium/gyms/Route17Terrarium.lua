-- Route 17 / Cycling Road: compact coastal bridge terrarium for PANDY.
-- Visual direction: ODias; supplied HGSS bridge and LGPE coastal route references.
-- Preserve host bowl, cameras, participants, platforms and branding.
local R={revision='route-17-cycling-road-compact-v1'}
function R.appliesTo(id)return id=='ROUTE_17'end
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
 local rockTones={{.31,.39,.40},{.40,.47,.46},{.49,.54,.49},{.57,.61,.54},{.42,.50,.51}}
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
 local sea={.18,.49,.62};local steel={.53,.64,.73};local dark={.31,.43,.52}
 local pale={.77,.83,.83};local white={.91,.93,.86};local green={.39,.57,.30}
 disk(0,.021,0,73.5,sea,96)
 -- The deck widens through the battle clearing, with sea exposed on both sides.
 local edge={{-25,-68},{25,-68},{45,-54},{62,-26},{62,26},{45,54},{25,68},{-25,68},{-45,54},{-62,26},{-62,-26},{-45,-54}}
 for i=1,#edge do local j=i%#edge+1;local a,b=edge[i],edge[j]
  quad({0,.052,0},{a[1],.052,a[2]},{b[1],.052,b[2]},{0,.052,0},steel)
 end
 local function inside(x,z)
  local az=math.abs(z)
  local w=az<=26 and 62 or (az<=54 and 62-(az-26)*17/28 or 45-(az-54)*20/14)
  return az<67.5 and math.abs(x)<w-.6
 end
 -- Flat slotted panels reproduce the pale steel grating of Cycling Road.
 for x=-58,58,8 do for z=-62,62,8 do
  if inside(x-3.8,z-3.8) and inside(x+3.8,z+3.8) and inside(x-3.8,z+3.8) and inside(x+3.8,z-3.8)then
   rect(x,z,7.65,7.65,.064,{.64,.73,.79})
   for k=0,5 do rect(x-2.75+k*1.1,z,.47,5.9,.072,{.41,.54,.66})end
   for _,q in ipairs({-3.1,3.1})do rect(x,z+q,6.4,.17,.074,pale)end
  end
 end end
 -- Clear lane markings and a painted cycle symbol, all at floor height.
 for z=-57,57,13 do rect(0,z,.65,5,.084,white)end
 for _,x in ipairs({-22,22})do rect(x,0,.50,115,.083,white)end
 local function paintLine(x,z,u,v,w)
  local dx,dz=u-x,v-z;local l=math.sqrt(dx*dx+dz*dz);local nx,nz=-dz/l*w/2,dx/l*w/2
  quad({x+nx,.087,z+nz},{u+nx,.087,v+nz},{u-nx,.087,v-nz},{x-nx,.087,z-nz},white)
 end
 local bx,bz=-11,31
 for _,x in ipairs({bx-4,bx+4})do for i=0,23 do local a,b=i*math.pi/12,(i+1)*math.pi/12
  paintLine(x+2.4*math.cos(a),bz+2.4*math.sin(a),x+2.4*math.cos(b),bz+2.4*math.sin(b),.31)
 end end
 for _,p in ipairs({{-4,0,-1,-3},{-1,-3,1,0},{1,0,-4,0},{-1,-3,3,-3},{3,-3,1,0},{3,-3,4,0},{3,-3,2.3,-4.6},{2.3,-4.6,4,-4.6},{-2,-3.8,0,-3.8}})do
  paintLine(bx+p[1],bz+p[2],bx+p[3],bz+p[4],.34)
 end
 -- Low outer parapets, lavender posts and small red marker lamps.
 for i=1,#edge do local j=i%#edge+1;local a,b=edge[i],edge[j]
  if i~=1 and i~=7 then
   beam({a[1],1.0,a[2]},{b[1],1.0,b[2]},.65,{.63,.60,.57},6)
   beam({a[1],3.4,a[2]},{b[1],3.4,b[2]},.22,pale,6)
   local n=math.ceil(math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2)/10)
   for k=0,n-1 do local t=k/n;local x,z=a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t
    box(x,.07,z,.70,3.7,.70,{.68,.59,.69})
    if k%2==0 then box(x,3.77,z,.9,.62,.9,{.87,.33,.22})end
   end
  end
 end
 -- A short steel truss at the right rear evokes the elevated bridge in HGSS.
 local tx={{44,-51},{49,-43},{54,-35}}
 for i=1,#tx do local p=tx[i]
  box(p[1],.08,p[2],1.3,12,1.3,{.47,.58,.54})
  box(p[1],11.9,p[2],2.1,.65,2.1,pale)
  if i<#tx then local q=tx[i+1]
   beam({p[1],12,p[2]},{q[1],12,q[2]},.55,{.55,.67,.63},6)
   beam({p[1],2,p[2]},{q[1],11.7,q[2]},.30,{.57,.69,.66},6)
   beam({p[1],11.7,p[2]},{q[1],2,q[2]},.30,{.57,.69,.66},6)
  end
 end
 -- Two narrow planted verges and benches recall the LGPE coastal park.
 for _,x in ipairs({-33,33})do
  rect(x,-49,13,15,.091,green)
  for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
   box(x+sx*5.5,.092,-49+sz*6.5,.45,.7,.45,{.62,.60,.46})
  end end
 end
 local function bench(x,z)
  local wood={.59,.44,.22};local metal={.25,.32,.29}
  for _,dx in ipairs({-3.3,3.3})do
   box(x+dx,.10,z, .48,2.0,2.7,metal)
   box(x+dx,1.8,z-1.1,.38,2.3,.38,metal)
  end
  for j=0,2 do box(x,2,z-1+j*.8,9,.25,.63,wood)end
  for j=0,1 do box(x,2.6+j*.70,z-1.1,9,.48,.30,wood)end
 end
 bench(-33,-47);bench(34,-48)
 -- Rounded shrubs and yellow flowers, with no tall vegetation in the centre.
 local function shrub(x,z,r)
  local saved=rockTones
  rockTones={{.28,.46,.24},{.37,.56,.29},{.46,.64,.34},{.52,.67,.35},{.35,.52,.28}}
  stone(x,z,r,r*.75,r*1.2,3,.1);rockTones=saved
 end
 for _,p in ipairs({{-38,-53,2.2},{-28,-54,2},{28,-54,2},{39,-54,2},{-47,-39,2.3},{48,34,2.2},{-48,33,2.2}})do shrub(p[1],p[2],p[3])end
 for _,x in ipairs({-39,-27,28,39})do for i=0,3 do local z=-52+i*2.4
  box(x,.095,z,.11,1.2,.11,green);disk(x,1.35,z,.43,{.94,.81,.25},6)
 end end
 -- Small three-blade wind turbine. Rotor is fixed; animation belongs to PANDY.
 local wx,wz=-27,-61
 beam({wx,.08,wz},{wx,32,wz},.70,white,9)
 box(wx,31.3,wz,1.7,1.6,3.0,pale)
 local hub={wx,32,wz+1.7}
 for i=0,2 do local a=math.pi/2+i*2*math.pi/3
  local dx,dy=math.cos(a),math.sin(a);local nx,ny=-dy,dx
  local function v(d,w)return{hub[1]+dx*d+nx*w,hub[2]+dy*d+ny*w,hub[3]}end
  quad(v(.5,-.40),v(9.5,-.20),v(11,.1),v(2,1.25),white)
 end
 beam({wx,32,wz+1.3},{wx,32,wz+2.1},.9,white,10)
 -- Static coastal ripples and rocks only where the water is exposed.
 for i=1,90 do local a=i*2.399;local r=66+(i%6)
  local x,z=math.cos(a)*r,math.sin(a)*r
  if not inside(x,z) and x*x+z*z<72^2 then rect(x,z,1.7,.14,.06,{.52,.75,.78})end
 end
 for _,p in ipairs({{-65,26,2,2,1.3,1},{65,-26,2,2,1.2,3},{-52,49,2.4,2,1.7,4},{53,48,2,2,1.2,2}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
end
return R
