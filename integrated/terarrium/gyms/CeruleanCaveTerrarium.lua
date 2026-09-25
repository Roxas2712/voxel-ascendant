-- Cerulean Cave: compact open terrarium for PANDY.
-- Visual direction: ODias; supplied LGPE Cerulean Cave concept art.
-- Preserve the host bowl, cameras, participants, trainer platforms and branding.
local R={revision='cerulean-cave-compact-v1'}
local maps={CERULEAN_CAVE_1F=true,CERULEAN_CAVE_2F=true,CERULEAN_CAVE_B1F=true}
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
 local rockTones={{.23,.25,.32},{.29,.31,.39},{.37,.36,.44},{.43,.41,.49},{.32,.32,.41}}
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
   quad(tip,rings[3][i],rings[3][k],tip,({{.31,.40,.34},{.38,.46,.37},{.43,.50,.39}})[(i+seed)%3+1])
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
 -- Peripheral water remains opaque and static; effects belong to the host.
 local water={.15,.32,.43};local wet={.23,.39,.46}
 disk(0,.021,0,73.5,water,96)
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  local r=66+1.2*math.sin(a*5);local s=66+1.2*math.sin(b*5)
  quad({r*math.cos(a),.025,r*math.sin(a)},{73*math.cos(a),.025,73*math.sin(a)},
   {73*math.cos(b),.025,73*math.sin(b)},{s*math.cos(b),.025,s*math.sin(b)},water)
 end
 -- Broad dry island; the irregular perimeter leaves room for host participants.
 local floor={.45,.42,.53}
 for i=0,79 do local a,b=i*math.pi/40,(i+1)*math.pi/40
  local r=63+1.5*math.sin(a*5)+.8*math.cos(a*9)
  local s=63+1.5*math.sin(b*5)+.8*math.cos(b*9)
  local x,z=r*math.cos(a),r*math.sin(a);local u,v=s*math.cos(b),s*math.sin(b)
  quad({0,.06,0},{x,.06,z},{u,.06,v},{0,.06,0},floor)
  quad({x,.065,z},{u,.065,v},{u*1.034,.032,v*1.034},{x*1.034,.032,z*1.034},{.30,.38,.37})
 end
 -- Flat, irregular stone patches and fissures do not raise the battle surface.
 for i=1,100 do local a=i*2.39996;local r=math.sqrt(i/101)*59
  local x,z=math.cos(a)*r,math.sin(a)*r
  local c=({{.47,.44,.55},{.41,.39,.50},{.50,.47,.57},{.43,.41,.52}})[i%4+1]
  for j=0,5 do local u,v=j*math.pi/3+i*.1,(j+1)*math.pi/3+i*.1
   quad({x,.071,z},{x+math.cos(u)*(2+i%4),.071,z+math.sin(u)*2.6},
    {x+math.cos(v)*(2+i%4),.071,z+math.sin(v)*2.6},{x,.071,z},c)
  end
 end
 for i=1,27 do local a=i*2.37;local r=9+(i*11)%45
  local x,z=math.cos(a)*r,math.sin(a)*r
  quad({x,.08,z},{x+.10,.08,z-.10},{x+2.4,.08,z+1},{x+2.3,.08,z+1.1},{.33,.32,.42})
 end
 -- Moss-capped cliffs across the rear. No ceiling covers the arena.
 for _,p in ipairs({{-37,-49,10,10,24,1},{-20,-60,11,9,28,2},{0,-65,11,7,27,3},
  {22,-59,11,10,29,4},{41,-47,10,11,23,5},{-53,-31,8,9,16,6},
  {55,-28,8,10,15,7},{-62,-7,5,7,8,8},{63,8,4,7,6,9}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 -- Faceted mint crystals: solid geometry with fixed bright faces.
 local facets={{.36,.68,.61},{.57,.83,.74},{.78,.96,.89},{.31,.57,.56},{.48,.75,.72},{.66,.88,.84}}
 local function shard(x,z,r,h,leanX,leanZ,y)
  y=y or .09;local n=6;local base,neck={},{}
  for i=1,n do local a=(i-1)*math.pi/3+.19
   base[i]={x+r*.64*math.cos(a),y,z+r*.64*math.sin(a)}
   neck[i]={x+leanX*.57+r*math.cos(a),y+h*.63,z+leanZ*.57+r*math.sin(a)}
  end
  local tip={x+leanX,y+h,z+leanZ}
  for i=1,n do local j=i%n+1
   quad(base[i],base[j],neck[j],neck[i],facets[i])
   quad(neck[i],neck[j],tip,neck[i],facets[(i+1)%6+1])
  end
 end
 local function crystals(x,z,s)
  stone(x,z,4.7*s,3.9*s,1.3*s,3)
  shard(x,z,2.1*s,14*s,1.6*s,-.7*s,1*s)
  shard(x-3*s,z+.3*s,1.55*s,8.5*s,-2*s,.8*s,.6*s)
  shard(x+2.8*s,z+1.1*s,1.5*s,9.5*s,2.3*s,1.5*s,.6*s)
  shard(x-.4*s,z+2.7*s,1.3*s,5.5*s,-.6*s,2.8*s,.5*s)
 end
 crystals(-29,-42,1.28);crystals(37,-37,1.36)
 crystals(-48,28,.65);crystals(48,30,.66)
 crystals(-32,53,.47);crystals(34,52,.47)
 -- Low mossy fragments frame the front without closing the view.
 for _,p in ipairs({{-56,30,5,5,4,2},{-47,44,5,5,3.8,4},{-34,54,4,3,2.5,1},
  {55,33,5,5,4,3},{44,48,5,4,3.5,6},{31,56,4,3,2.5,4}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 -- Short raised landing and steps at the back, between crystal clusters.
 box(0,.09,-53,14,3.0,8,rockTones[2])
 for i=0,3 do
  box(0,.09,-43-i*1.6,13, .73*(i+1),1.7,rockTones[i%3+2])
 end
 -- Ladder set against the left rear cliff, an architectural detail only.
 for _,x in ipairs({-44.5,-41.2})do beam({x,.1,-42},{x,14.5,-46},.35,{.48,.48,.47})end
 for i=0,8 do local t=i/8
  beam({-44.5,.6+13.4*t,-42.15-3.7*t},{-41.2,.6+13.4*t,-42.15-3.7*t},.24,{.58,.57,.52})
 end
 -- Fine static ripples near the exposed water rim.
 for i=0,35 do local a=i*math.pi/18;local r=69.1+(i%3)*.65
  local x,z=r*math.cos(a),r*math.sin(a)
  rect(x,z,1.2+(i%3)*.6,.12,.037,{.34,.51,.56})
 end
end
return R
