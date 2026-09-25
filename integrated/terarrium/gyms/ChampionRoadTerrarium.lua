-- Champion Road / Kanto Victory Road: compact rocky terrarium for PANDY.
-- Visual direction: ODias; based on the supplied LGPE Champion Road concept art.
-- Reuse the host bowl, camera, participants, trainer platforms and branding.
local R={revision='champion-road-compact-v2-fire'}
local black={.17,.14,.12}
local wood={.40,.34,.28}
local maps={VICTORY_ROAD_1F=true,VICTORY_ROAD_2F=true,VICTORY_ROAD_3F=true}
function R.appliesTo(mapId)return maps[mapId]==true end
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
 local earth={.48,.42,.35}
 local sand={.64,.57,.47}
 local rockTones={{.39,.32,.27},{.48,.40,.33},{.55,.47,.39},{.62,.54,.45},{.44,.37,.32}}
 local iron={.13,.12,.11}
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
 -- Dusty stone floor with irregular patches instead of a tiled pattern.
 disk(0,.02,0,73.5,earth,96)
 for i=1,115 do
  local a=i*2.399963;local r=math.sqrt(i/116)*70
  local x,z=math.cos(a)*r,math.sin(a)*r
  local sx,sz=3+(i%5)*1.05,1.9+(i%4)*.95
  local tone=({{.51,.45,.38},{.54,.48,.40},{.46,.40,.34},{.56,.50,.42}})[i%4+1]
  for j=0,5 do local u,v=j*math.pi/3+i*.17,(j+1)*math.pi/3+i*.17
   local ra,rb=1+.30*math.sin(j*3.4+i),1+.30*math.sin(((j+1)%6)*3.4+i)
   local px,pz=clip(x+math.cos(u)*sx*ra,z+math.sin(u)*sz*ra)
   local qx,qz=clip(x+math.cos(v)*sx*rb,z+math.sin(v)*sz*rb)
   quad({x,.033,z},{px,.033,pz},{qx,.033,qz},{x,.033,z},tone)
  end
 end
 -- Fine cracks on the ground remain flat beneath the participants.
 for i=1,23 do local a=i*2.01;local r=12+(i*13)%54
  local x,z=r*math.cos(a),r*math.sin(a)
  for j=0,2 do
   local dx,dz=math.cos(a+j*.6)*2,math.sin(a+j*.6)*2
   quad({x,.04,z},{x+.13,.04,z-.10},{x+dx+.13,.04,z+dz-.10},{x+dx,.04,z+dz},{.37,.33,.29})
   x,z=x+dx,z+dz
  end
 end
 -- Higher rock formations frame the back; the sides descend toward the entrance.
 local clusters={{-23,-59,9,9,25,1},{-42,-46,9,10,18,2},{-54,-28,8,8,13,3},
  {-61,-4,5.5,6,7,4},{27,-57,10,9,23,5},{44,-43,9,9,17,6},
  {58,-31,7,7,11,7},{62,5,4.8,5.5,6,8}}
 for _,p in ipairs(clusters)do stone(p[1],p[2],p[3],p[4],p[5],p[6])end
 -- A shallow rear terrace and broad rough-hewn steps.
 local terrace={{-12,-65},{-9,-70},{0,-72},{9,-70},{12,-65}}
 for i=1,#terrace do local j=i%#terrace+1;local a,b=terrace[i],terrace[j]
  quad({a[1],.04,a[2]},{b[1],.04,b[2]},{b[1],10.85,b[2]},{a[1],10.85,a[2]},rockTones[i%5+1])
  quad({0,10.855,-68},{a[1],10.855,a[2]},{b[1],10.855,b[2]},{0,10.855,-68},sand)
 end
 for i=0,7 do local z=-45-i*2.7
  box(0,.04,z,19-(i%3)*.35,1.35*(i+1),2.85,rockTones[(i+2)%5+1])
  rect(0,z,18.7-(i%3)*.35,2.72,1.35*(i+1)+.055,sand)
  rect(-4+(i%3)*2,z+.35,3,.10,1.35*(i+1)+.065,{.45,.39,.32})
 end
 -- Fragments along the perimeter, plus two larger boulders recalling the puzzle.
 for _,p in ipairs({{-54,34,5.5,6,6,3},{-45,46,4,4.5,4,1},{-34,57,4.4,4,4,4},
  {53,35,5,5.5,6,2},{44,48,4.2,4.8,4.5,3},{34,59,4,3.8,3.3,6}})do
  stone(p[1],p[2],p[3],p[4],p[5],p[6])
 end
 stone(-43,-8,5.8,5.2,8.8,2)
 stone(44,24,6.4,6,9.3,4)
 for i=1,32 do local a=i*2.39;local r=57+(i%4)*2.5
  local x,z=math.cos(a)*r,math.sin(a)*r
  if clear(x,z,3.4,3.4)then stone(x,z,1.1+(i%3)*.30,.8+(i%2)*.4,1.1+(i%3)*.5,i)end
 end
 -- Small static seep and pool between the left rock formations.
 local water={.25,.43,.50};local lightWater={.42,.58,.60}
 quad({-32,7,-51},{-30.8,7,-51},{-30.8,.065,-46},{-32,.065,-46},water)
 quad({-31.65,6.8,-50.94},{-31.2,6.8,-50.94},{-31.2,.075,-46},{-31.65,.075,-46},lightWater)
 quad({-32,.065,-46},{-30.8,.065,-46},{-32.2,.065,-39.5},{-34.5,.065,-40.5},water)
 quad({-34.5,.065,-40.5},{-32.2,.065,-39.5},{-36.5,.065,-32},{-38.7,.065,-33},water)
 disk(-37.7,.066,-32.7,3.5,water,13)
 rect(-37.3,-32.4,2.2,.16,.069,lightWater)
 rect(-38,-33.4,1.4,.13,.069,lightWater)
 -- Round stone pressure plate, decorative only.
 local function roundSwitch(x,z)
  local rings={{4.1,.07},{3.8,.6},{3.1,1.0}}
  for j=1,2 do for i=0,19 do local a,b=i*math.pi/10,(i+1)*math.pi/10
   local r,h=rings[j][1],rings[j][2];local nr,nh=rings[j+1][1],rings[j+1][2]
   quad({x+r*math.cos(a),h,z+r*math.sin(a)},{x+r*math.cos(b),h,z+r*math.sin(b)},
    {x+nr*math.cos(b),nh,z+nr*math.sin(b)},{x+nr*math.cos(a),nh,z+nr*math.sin(a)},{.65,.64,.59})
  end end
  disk(x,1.01,z,3.1,{.78,.77,.70},20)
  disk(x,1.02,z,2.1,{.49,.50,.48},20);disk(x,1.03,z,1.77,{.73,.73,.67},20)
  disk(x,1.04,z,.73,{.83,.81,.72},16)
 end
 roundSwitch(30,35)
 -- Tripod braziers with static sculpted fire; animation and lighting remain separate.
 local function brazier(x,z)
  for i=0,2 do local a=i*math.pi*2/3
   beam({x+2.6*math.cos(a),.07,z+2.6*math.sin(a)},{x-.6*math.cos(a),6,z-.6*math.sin(a)},.32,iron)
   beam({x,4.5,z},{x+2.6*math.cos(a),8.1,z+2.6*math.sin(a)},.32,iron)
  end
  for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
   quad({x+1.1*math.cos(a),6.7,z+1.1*math.sin(a)},{x+1.1*math.cos(b),6.7,z+1.1*math.sin(b)},
    {x+2.7*math.cos(b),8.2,z+2.7*math.sin(b)},{x+2.7*math.cos(a),8.2,z+2.7*math.sin(a)},iron)
   beam({x+2.7*math.cos(a),8.2,z+2.7*math.sin(a)},{x+2.7*math.cos(b),8.2,z+2.7*math.sin(b)},.23,iron,6)
  end
  disk(x,7.86,z,2.42,{.25,.17,.12},16)
  for i=0,6 do local a=i*2.39;local r=(i%3)*.65
   disk(x+r*math.cos(a),7.89,z+r*math.sin(a),.38,({{.70,.29,.09},{.86,.46,.12},{.41,.21,.12}})[i%3+1],7)
  end
  -- Added fire only: tapered orange tongues and a yellow centre.
  local function flame(ox,oz,scale,height)
   local profile={{0,.70,0},{.20,1,0},{.55,.62,.20},{.82,.27,.42},{1,0,.20}}
   local function p(j,i)
    local a=i*math.pi/4;local t=profile[j]
    return{x+ox+(math.sin(a)*t[2]+t[3])*scale,7.94+t[1]*height,z+oz+math.cos(a)*t[2]*scale}
   end
   for j=1,4 do for i=0,7 do
    local front=i==0 or i==7
    local tone=(front and j<=2)and{1,.79,.15}or(j<=2 and{1,.49,.045}or{.96,.34,.035})
    quad(p(j,i),p(j,i+1),p(j+1,i+1),p(j+1,i),tone)
   end end
  end
  flame(-1.0,-.20,.70,4.8)
  flame(.90,-.25,.72,5.5)
  flame(0,.25,1.45,8.0)
 end
 brazier(-14,-45);brazier(36,-39)
 brazier(-31,47);brazier(31,49)
end
return R
