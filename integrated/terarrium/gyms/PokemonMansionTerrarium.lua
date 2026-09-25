-- Pokemon Mansion interior: compact diorama for integration by PANDY.
-- Visual direction: ODias, based on the supplied Let's Go interior concept art.
-- Reuse the host bowl, camera, participants, trainer platforms and branding.
local R={revision='pokemon-mansion-inside-compact-v2'}
local maps={POKEMON_MANSION_1F=true,POKEMON_MANSION_2F=true,POKEMON_MANSION_3F=true,POKEMON_MANSION_B1F=true}
function R.appliesTo(mapId)return maps[mapId]==true end
local black={.12,.11,.12}
local red={.47,.18,.15}
local trim={.80,.75,.62}
local wood={.30,.16,.12}
-- Keep the host's plain bowl button; no decorative face badge.
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
 local cream={.77,.73,.62}
 local pale={.87,.83,.72}
 local stone={.40,.46,.46}
 local slate={.24,.30,.31}
 local carpet={.48,.065,.075}
 local function cylinder(x,y,z,r,height,c,n)
  n=n or 16
  disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.78+.14*math.cos(a))
  end
 end
 local function segment(x1,z1,x2,z2,width,y,c)
  local dx,dz=x2-x1,z2-z1;local length=math.sqrt(dx*dx+dz*dz)
  if length<.001 then return end
  local nx,nz=-dz/length*width/2,dx/length*width/2
  quad({x1+nx,y,z1+nz},{x2+nx,y,z2+nz},{x2-nx,y,z2-nz},{x1-nx,y,z1-nz},c)
 end
 disk(0,.02,0,73.5,{.49,.46,.39},96)
 -- Cream diamond paving, faithfully borrowing the reference's diagonal grid.
 for u=-10,10 do for v=-10,10 do
  local x,z=(u-v)*5.6,(u+v)*5.6;local r=5.45
  if math.max((math.abs(x)+r)^2+z*z,x*x+(math.abs(z)+r)^2)<73^2 then
   local c=({cream,{.72,.69,.60},{.81,.77,.66},{.75,.71,.62}})[(u*3+v+200)%4+1]
   quad({x-r,.034,z},{x,.034,z-r},{x+r,.034,z},{x,.034,z+r},c)
  end
 end end
 -- Red hall runner, with uneven edge wear and a narrow faded border.
 rect(0,9,25,112,.044,{.30,.105,.085})
 rect(0,9,23.5,111,.046,carpet)
 for _,x in ipairs({-10.8,10.8})do rect(x,9,.24,108,.048,{.65,.34,.20})end
 for _,z in ipairs({-43,61})do rect(0,z,21.6,.24,.048,{.65,.34,.20})end
 for i=0,6 do local x=(i%2==0 and -1 or 1)*11.8;local z=-35+i*14
  quad({x,.051,z-1.9},{x-(x>0 and 1 or -1)*(1.2+i%3),.051,z-.3},{x,.051,z+2},{x,.051,z-1.9},cream)
 end
 -- Broken floor motifs are decorative dark insets, not functional collision holes.
 local function brokenFloor(x,z,rx,rz)
  if not clear(x,z,rx*2,rz*2)then return end
  local points={}
  for i=0,13 do local a=i*2*math.pi/14;local f=1-(i%3)*.10
   points[#points+1]={x+math.cos(a)*rx*f,.052,z+math.sin(a)*rz*f}
  end
  for i=1,#points do quad({x,.052,z},points[i],points[i%#points+1],{x,.052,z},{.055,.055,.06})end
  for i=0,9 do local a=i*2*math.pi/10
   local px,pz=x+math.cos(a)*(rx+.6),z+math.sin(a)*(rz+.6)
   box(px,.04,pz,1.6+(i%2),.55+(i%3)*.37,1.4+(i%3)*.4,(i%2==0)and cream or{.55,.48,.36})
  end
 end
 brokenFloor(-43,-27,7,5);brokenFloor(43,32,7,5)
 -- Fine cracks in the tile surface and isolated small chips.
 for _,p in ipairs({{-24,34},{29,17},{-38,-8},{33,-15},{-32,54},{24,48}})do
  local x,z=p[1],p[2]
  segment(x,z,x+2.6,z+3.2,.22,.05,{.35,.31,.25})
  segment(x+2.6,z+3.2,x+1.3,z+6.5,.18,.05,{.35,.31,.25})
  segment(x+2.6,z+3.2,x+5.3,z+2,.15,.05,{.35,.31,.25})
 end
 -- Low cream/red wall sections and recessed panels across the rear.
 for _,x in ipairs({-27,-13.5,0,13.5,27})do
  box(x,0,-63,13.2,17,2,red)
  box(x,3.3,-61.85,11.7,10.7,.32,trim)
  box(x,4.1,-61.58,10.2,9.1,.22,{.69,.62,.51})
  box(x,4.6,-61.42,9.2,8.1,.16,{.78,.72,.61})
  box(x,1.4,-61.8,10.4,.65,.2,{.51,.43,.30})
  box(x,15.4,-61.9,13, .8,.55,pale)
 end
 for _,x in ipairs({-33.5,-20.2,-6.7,6.7,20.2,33.5})do
  box(x,0,-61.7,.8,17,.55,cream)
 end
 -- Six cannelured columns; two deliberately broken, keeping rear and side silhouettes.
 local function column(x,z,height,broken)
  box(x,0,z,7.5,1.1,7.5,red);box(x,1.1,z,6.6,2.1,6.6,red)
  for _,dx in ipairs({-2,0,2})do box(x+dx,1.65,z+3.36,1.1,.85,.10,{.56,.48,.29})end
  box(x,3.2,z,7, .6,7,red)
  cylinder(x,3.8,z,2.8,.7,pale)
  cylinder(x,4.5,z,2.35,2.8,cream)
  cylinder(x,7.3,z,2.65,.6,pale)
  local low,top=7.9,height
  for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
   local ya=top+(broken and ((i*3)%5)*.45 or 0)
   local yb=top+(broken and (((i+1)*3)%5)*.45 or 0)
   local function p(angle,y)return{x+2.1*math.cos(angle),y,z+2.1*math.sin(angle)}end
   quad(p(a,low),p(b,low),p(b,yb),p(a,ya),(i%2==0)and pale or{.64,.61,.54},.86)
   if broken then quad({x,top-.3,z},p(a,ya),p(b,yb),{x,top-.3,z},cream)end
  end
  if not broken then cylinder(x,top,z,2.8,.7,pale);box(x,top+.7,z,6.5,1.4,6.5,red)end
 end
 column(-44,-36,19,false);column(44,-36,13,true)
 column(-66,0,15,false);column(66,0,16,false)
 column(-57,33,11,true);column(57,33,16,false)
 -- Arched window fragments stand low on the lateral perimeter.
 local function window(x,z)
  local sign=x<0 and 1 or -1
  box(x,0,z,1.2,13,11,red)
  box(x+sign*.7,3,z,.3,9,9,trim)
  box(x+sign*.9,3.7,z,.2,7.7,7.5,{.61,.67,.60})
  box(x+sign*1.03,3.7,z,.15,7.7,.45,{.49,.39,.22})
  box(x+sign*1.03,7.2,z,.15,.4,7.5,{.49,.39,.22})
  for i=0,9 do local a,b=i*math.pi/10,(i+1)*math.pi/10
   local function p(r,t)return{x+sign*1.05,11.4+math.sin(t)*r,z+math.cos(t)*r}end
   quad(p(3.45,a),p(3.45,b),p(3.9,b),p(3.9,a),{.49,.39,.22})
  end
 end
 window(-61,-30);window(61,-30)
 -- Bookshelf at the rear-left and a low overturned cabinet at the side.
 local function shelf(x,z)
  box(x,0,z,13,13,4,wood)
  box(x,1,z+2.05,11,10.8,.2,{.16,.11,.10})
  for _,y in ipairs({1.2,5.1,9.1,12.2})do box(x,y,z+2.2,12,.5,1,wood)end
  for row=0,2 do for i=0,6 do
   local c=({{.42,.20,.16},{.22,.31,.31},{.37,.40,.24},{.62,.53,.36}})[(i+row)%4+1]
   box(x-4.7+i*1.5,1.7+row*3.9,z+2.2,.85,2.7-(i%3)*.3,.8,c)
  end end
 end
 shelf(-25,-54)
 if clear(-58,26,8,12)then
  box(-58,0,26,7,4.5,11,wood);box(-54.4,1,26,.2,2.7,9,{.16,.11,.10})
  box(-54.2,1,25,.2,2,2.5,{.36,.42,.30})
 end
 -- Small study corner, with blue carpet, desk, journal and a fallen chair.
 rect(35,-47,19,16,.055,{.20,.23,.33})
 for i=0,4 do for j=0,3 do disk(27+i*3.7,.057,-53+j*3.8,.43,{.39,.43,.49},6)end end
 for _,x in ipairs({29.5,38.5})do for _,z in ipairs({-50,-43})do box(x,0,z,.85,5,.85,wood)end end
 box(34,5,-46.5,12,1,10,wood)
 -- Open book: two slightly sloping page halves and a dark centre fold.
 quad({32,6.05,-47.8},{34,6.45,-47.8},{34,6.45,-44.8},{32,6.05,-44.8},pale)
 quad({34,6.45,-47.8},{36,6.05,-47.8},{36,6.05,-44.8},{34,6.45,-44.8},pale)
 for z=-47.3,-45.3,.55 do
  segment(32.3,z,33.65,z,.10,6.46,{.45,.40,.33})
  segment(34.35,z,35.7,z,.10,6.46,{.45,.40,.33})
 end
 box(30.5,6.05,-49,2.4,.65,3.2,{.28,.36,.25})
 box(30.5,6.7,-49,2.5,.25,3.3,{.23,.30,.23})
 box(43,0,-48,3.5,2.4,3.5,wood);box(44.4,2.4,-48,.7,3.5,3.5,wood)
 for _,p in ipairs({{24,-52},{42,-38},{44,-43},{-32,-46},{-34,-51},{-46,39}})do
  local x,z=p[1],p[2]
  quad({x-1.3,.06,z-1.7},{x+1.5,.06,z-.9},{x+.9,.06,z+1.8},{x-1.7,.06,z+1},pale)
 end
 -- Reference statue: slate body, pointed ears, red eyes and a stone pedestal.
 local function ellipsoid(x,y,z,rx,ry,rz,c)
  for j=0,5 do local a,b=-math.pi/2+j*math.pi/6,-math.pi/2+(j+1)*math.pi/6
   for i=0,11 do local u,v=i*math.pi/6,(i+1)*math.pi/6
    local function p(t,s)return{x+rx*math.cos(s)*math.cos(t),y+ry*math.sin(s),z+rz*math.cos(s)*math.sin(t)}end
    quad(p(u,a),p(v,a),p(v,b),p(u,b),c,.80+.15*math.cos(u))
   end
  end
 end
 box(0,0,-55,10,1,8,slate);box(0,1,-55,8,6,6,stone)
 box(0,2,-51.95,4.5,3.8,.15,{.57,.48,.29})
 box(0,7,-55,10,.8,8,stone)
 ellipsoid(0,11,-55,2.8,3.4,2.2,stone)
 ellipsoid(0,16,-55,4,3.1,2.6,stone)
 for _,s in ipairs({-1,1})do
  ellipsoid(s*2.0,8.8,-53.9,1.2,1.1,1.5,slate)
  ellipsoid(s*2.8,12,-54.2,.85,2.1,.9,slate)
  local a={s*2.0,17.6,-54.8};local b={s*4.0,20.3,-55};local c={s*3.8,16.7,-54.4};local d={s*3,17.4,-56.4}
  quad(a,b,c,a,stone);quad(a,d,b,a,slate);quad(c,b,d,c,slate)
  quad({s*.8,15.4,-52.38},{s*2.7,16.5,-52.6},{s*2.4,14.9,-52.48},{s*1.1,14.7,-52.38},{.79,.23,.18})
 end
 -- Small broken stones decorate the rear without covering the actor positions.
 for _,p in ipairs({{-51,-40},{-37,-56},{38,-57},{52,29},{-59,40},{29,54}})do
  if clear(p[1],p[2],3,3)then box(p[1],.04,p[2],2.3,1.2,2.7,cream)end
 end
end
return R
