-- S.S. Anne bow: open foredeck terrarium for integration by PANDY.
-- Visual direction: ODias; focus on the bow in the supplied LGPE concept art.
-- Preserve the compact host bowl, participants, trainer platforms, camera and branding.
local R={revision='ss-anne-bow-compact-v1'}
local black={.10,.20,.25}
local wood={.43,.29,.17}
function R.appliesTo(mapId)return mapId=='SS_ANNE_BOW'end
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
 local ivory={.88,.88,.80}
 local white={.96,.95,.88}
 local shadow={.64,.70,.69}
 local orange={.86,.42,.13}
 local navy={.10,.22,.28}
 local glass={.19,.40,.48}
 local metal={.65,.72,.72}
 local function cyl(x,y,z,r,height,c,n)
  n=n or 16;disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*math.pi*2/n,(i+1)*math.pi*2/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.83+.12*math.cos(a))
  end
 end
 local function beam(a,b,r,c,n)
  n=n or 8
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local l=math.sqrt(dx*dx+dy*dy+dz*dz)
  if l<.001 then return end
  dx,dy,dz=dx/l,dy/l,dz/l
  local ux,uy,uz=-dz,0,dx
  if math.abs(dy)>.95 then ux,uy,uz=1,0,0 end
  local ul=math.sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
  local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
  local function p(base,t)return{base[1]+r*(ux*math.cos(t)+vx*math.sin(t)),base[2]+r*(uy*math.cos(t)+vy*math.sin(t)),base[3]+r*(uz*math.cos(t)+vz*math.sin(t))}end
  for i=0,n-1 do local a0,a1=i*math.pi*2/n,(i+1)*math.pi*2/n
   quad(p(a,a0),p(b,a0),p(b,a1),p(a,a1),c,.85+.1*math.cos(a0))
  end
 end
 -- Long foredeck planks, clipped to the compact circular host bowl.
 disk(0,.02,0,73.5,{.34,.23,.14},96)
 for col=0,35 do local x=-70+col*4
  local span=math.sqrt(math.max(0,72.8^2-(math.abs(x)+1.9)^2))
  for row=-5,5 do local z=row*16+(col%2)*8
   local lo,hi=math.max(z-7.9,-span),math.min(z+7.9,span)
   if hi-lo>.4 then
    local tone=({{.52,.35,.21},{.57,.39,.24},{.60,.41,.25},{.55,.36,.21}})[(col+row+20)%4+1]
    rect(x,(lo+hi)/2,3.84,hi-lo,.035,tone)
    if hi-lo>5 then
     rect(x+.85,(lo+hi)/2,.06,hi-lo-2,.038,{.45,.30,.18})
     for _,zz in ipairs({lo+.65,hi-.65})do
      rect(x-.9,zz,.14,.18,.040,{.32,.27,.20});rect(x+.9,zz,.14,.18,.040,{.32,.27,.20})
     end
    end
   end
  end
 end
 -- White bulwark and low rails trace the open bow perimeter.
 local function arcBand(r,y,height,c)
  for i=0,47 do local a,b=-2.50+i*5/48,-2.50+(i+1)*5/48
   quad({r*math.sin(a),y,r*math.cos(a)},{r*math.sin(b),y,r*math.cos(b)},
    {r*math.sin(b),y+height,r*math.cos(b)},{r*math.sin(a),y+height,r*math.cos(a)},c)
  end
 end
 arcBand(71.8,.04,2.5,ivory);arcBand(71.9,.65,.75,orange)
 arcBand(71.7,0,.45,navy)
 for i=0,32 do local a=-2.50+i*5/32;local x,z=71.4*math.sin(a),71.4*math.cos(a)
  cyl(x,2.5,z,.26,3.3,white,8)
 end
 for _,y in ipairs({3.5,5.8})do
  for i=0,47 do local a,b=-2.50+i*5/48,-2.50+(i+1)*5/48
   beam({71.4*math.sin(a),y,71.4*math.cos(a)},{71.4*math.sin(b),y,71.4*math.cos(b)},.22,white,6)
  end
 end
 -- Convex forward face of the superstructure, kept entirely at the back.
 local function point(t,y,off)return{40*math.sin(t),y,-69+18*math.cos(t)+(off or 0)}end
 local function band(y,h,c,off)
  for i=0,19 do local a,b=-1+i/10,-1+(i+1)/10
   quad(point(a,y,off),point(b,y,off),point(b,y+h,off),point(a,y+h,off),c,.91+.07*math.cos(a))
  end
 end
 band(0,8.5,ivory);band(8.5,1.8,white,.7)
 band(10.3,6.2,glass);band(16.5,1.7,white,.5)
 band(18.2,7,glass);band(25.2,1.7,white,.5)
 band(26.9,1.1,orange,.55);band(28,1.2,white,.65)
 -- Window mullions and a few restrained pale-blue reflections.
 for i=0,16 do local t=-1+i/8
  local p=point(t,0,.1)
  for _,r in ipairs({{10.3,6.2},{18.2,7}})do
   beam({p[1],r[1],p[3]},{p[1],r[1]+r[2],p[3]},.22,ivory,6)
  end
 end
 for i=0,7 do local a=-.95+i*.25;local b=a+.032
  for _,r in ipairs({{10.6,5.5},{18.5,6.3}})do
   quad(point(a,r[1],.04),point(b,r[1],.04),point(b+.035,r[1]+r[2],.04),point(a+.035,r[1]+r[2],.04),{.36,.57,.62})
  end
 end
 -- Side returns and a small top cap are part of the bridge, not a roof over the arena.
 for _,s in ipairs({-1,1})do
  local p=point(s,0,0);local q={s*23,0,-66}
  quad(p,q,{q[1],29.2,q[3]},{p[1],29.2,p[3]},ivory,.85)
 end
 quad({-23,0,-66},{23,0,-66},{23,29.2,-66},{-23,29.2,-66},ivory,.75)
 for i=0,19 do
  quad({0,29.2,-63},point(-1+i/10,29.2,.65),point(-1+(i+1)/10,29.2,.65),{0,29.2,-63},white)
 end
 quad({-23,29.2,-66},{23,29.2,-66},point(1,29.2,.65),point(-1,29.2,.65),white)
 -- A modest central bridge door and paired portholes at deck level.
 box(0,.3,-50.82,6.4,7.4,.24,shadow)
 box(0,.5,-50.66,5.3,6.8,.12,ivory)
 box(0,3.5,-50.54,3.6,2.8,.10,glass)
 box(1.8,2.2,-50.5,.3,.3,.18,orange)
 local function porthole(t)
  local p=point(t,4.5,.16);local nx,nz=math.sin(t)*.45,math.cos(t)
  local l=math.sqrt(nx*nx+nz*nz);nx,nz=nx/l,nz/l
  local function ring(r,off,c)
   for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
    local function at(u)return{p[1]+math.cos(u)*r*nz+nx*off,p[2]+math.sin(u)*r,p[3]-math.cos(u)*r*nx+nz*off}end
    local mid={p[1]+nx*off,p[2],p[3]+nz*off};quad(mid,at(a),at(b),mid,c)
   end
  end
  ring(1.45,0,shadow);ring(1.09,.04,navy)
 end
 for _,t in ipairs({-.78,-.57,.57,.78})do porthole(t)end
 -- Short white mast above the bridge: a recognisable silhouette, without a funnel.
 cyl(0,29.2,-60,4,.8,shadow,20);cyl(0,30,-60,.72,13.5,white,12)
 cyl(0,43.5,-60,1.1,1.4,ivory,12)
 for _,p in ipairs({{34.5,9},{39,7}})do
  beam({-p[2],p[1],-60},{p[2],p[1],-60},.38,ivory,8)
  for _,s in ipairs({-1,1})do beam({s*p[2],p[1],-60},{0,p[1]-2.5,-60},.18,metal,6)end
 end
 -- Slatted white loungers are kept in the side pockets.
 local function chair(x,z,flip)
  local function at(u,y,v)return{x+u,y,z+v*flip}end
  local function rod(a,b,r)beam(at(a[1],a[2],a[3]),at(b[1],b[2],b[3]),r,white,8)end
  for _,s in ipairs({-1,1})do
   rod({s*3.2,.1,-5.5},{s*3.2,3,-3.5},.28)
   rod({s*3.2,.1,5.5},{s*3.2,3,3.5},.28)
   rod({s*3.2,3,-4},{s*3.2,3,5},.30)
   rod({s*3.2,3,-4},{s*3.2,9,-7},.30)
   rod({s*3.5,3,0},{s*3.5,5,-.8},.23)
   rod({s*3.5,5,-.8},{s*3.5,5,-3.8},.23)
  end
  for j=0,6 do local v=-3.5+j*1.25
   quad(at(-3,3.06,v),at(3,3.06,v),at(3,3.06,v+.77),at(-3,3.06,v+.77),ivory)
  end
  for j=0,5 do local v=-4-j*.5;local y=3+j
   quad(at(-3,y,v),at(3,y,v),at(3,y+.68,v-.34),at(-3,y+.68,v-.34),white)
  end
 end
 chair(-49,-23,1);chair(49,-23,1);chair(-49,34,-1);chair(49,34,-1)
 local function table(x,z)
  cyl(x,.06,z,1.7,.4,shadow,16);cyl(x,.46,z,.4,3.9,metal,12)
  cyl(x,4.36,z,3.25,.5,ivory,24);disk(x,4.87,z,2.98,white,24)
 end
 table(-61,0);table(61,11)
 -- Small mooring fittings at the bow corners; the middle remains open.
 for _,s in ipairs({-1,1})do local x,z=s*28,60
  box(x,.04,z,5,.4,3,shadow)
  for _,dx in ipairs({-1.5,1.5})do cyl(x+dx,.44,z,.55,1.4,navy,10)end
  beam({x-2.3,1.8,z},{x+2.3,1.8,z},.36,navy,8)
 end
end
return R
