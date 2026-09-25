-- Professor Oak's Laboratory: compact interior for integration by PANDY.
-- Visual direction: ODias, based on the supplied LGPE laboratory concept art.
-- Reuse the host bowl, camera, participants, trainer platforms and branding.
local R={revision='oak-lab-inside-compact-v1'}
local black={.11,.14,.14}
local wood={.46,.31,.18}
function R.appliesTo(mapId)return mapId=='OAKS_LAB'end
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
 local white={.87,.87,.80}
 local light={.94,.93,.86}
 local gray={.54,.59,.57}
 local blue={.20,.39,.58}
 local cyan={.32,.65,.70}
 local teal={.32,.55,.52}
 local brown={.49,.33,.18}
 local cream={.78,.73,.55}
 local purple={.43,.26,.47}
 local bookColors={{.69,.25,.17},{.76,.43,.18},{.29,.45,.27},{.23,.35,.55},{.57,.28,.42},{.43,.66,.65},{.72,.69,.50}}
 local function cyl(x,y,z,r,height,c,n)
  n=n or 16;disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*math.pi*2/n,(i+1)*math.pi*2/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.84+.10*math.cos(a))
  end
 end
 -- Pale diagonal floor tiles, individually clipped to the compact bowl.
 disk(0,.02,0,73.5,{.73,.75,.71},96)
 for i=-18,18 do for j=-18,18 do local x,z=(i-j)*4,(i+j)*4
  if (math.abs(x)+3.96)^2+z*z<73^2 and x*x+(math.abs(z)+3.96)^2<73^2 then
   local c=(i+j)%3==0 and{.88,.87,.82}or{.84,.85,.80}
   quad({x-3.96,.033,z},{x,.033,z-3.96},{x+3.96,.033,z},{x,.033,z+3.96},c)
  end
 end end
 -- Cream rear panelling with a low brown skirting board.
 box(0,0,-61,76,28,2.5,cream)
 box(0,0,-59.6,76,2,.5,{.36,.24,.18})
 box(0,27,-61,78,1.2,3,{.66,.58,.40})
 for x=-36,36,6 do box(x,2,-59.65,.12,24.7,.18,{.68,.62,.46})end
 -- Short side returns frame the workspace without covering the battle area.
 for _,s in ipairs({-1,1})do
  quad({s*38,0,-60},{s*53,0,-44},{s*53,22,-44},{s*38,28,-60},cream,.94)
  quad({s*38,0,-59.8},{s*53,0,-43.8},{s*53,2,-43.8},{s*38,2,-59.8},{.36,.24,.18})
 end
 -- Shelves filled with books, files and storage boxes.
 local function bookshelf(x,z,w,h,seed)
  box(x,0,z-2.15,w,h,.5,{.58,.61,.56})
  box(x,.5,z-1.84,w-1,h-1,.12,{.34,.39,.35})
  box(x-w/2+.35,0,z+.15,.7,h+.5,5,white)
  box(x+w/2-.35,0,z+.15,.7,h+.5,5,white)
  box(x,h,z,w+1,.75,5.6,light)
  for row=0,3 do local y=.5+row*(h-1)/4
   box(x,y,z+.25,w-.7,.45,5,white)
   local count=math.floor((w-2)/1.15)
   for k=0,count-1 do
    local px=x-w/2+1.3+k*1.15
    local bh=(h-1)/4-.75-((k+seed)%3)*.20
    box(px,y+.45,z+1.7,.83,bh,1.3,bookColors[(k+row*3+seed)%7+1])
    if k%4==0 then box(px,y+bh-.08,z+2.4,.53,.12,.05,light)end
   end
  end
  for _,s in ipairs({-1,1})do
   box(x+s*w*.23,.96,z+2.6,w*.27,1.8,.6,{.55,.68,.65})
   box(x+s*w*.23,1.6,z+2.96,w*.12,.23,.05,light)
  end
 end
 bookshelf(28,-55,20,19,1)
 bookshelf(-51,-26,16,14,3)
 bookshelf(-53,34,16,12.5,2);bookshelf(53,34,16,12.5,5)
 box(31,19.8,-55,6,3.1,3.6,{.62,.45,.27})
 box(23,19.8,-55,4.5,1.9,3.8,white)
 -- Rear bench with glazed doors, books and framed photographs.
 box(-24,0,-54,18,7.5,6,gray);box(-24,7.5,-54,19,.8,7,blue)
 for _,x in ipairs({-28.3,-19.7})do
  box(x,.9,-50.89,7.3,5.6,.16,teal)
  box(x,1.45,-50.75,6.2,4.5,.1,{.45,.68,.67})
  box(x+2.4,3.1,-50.63,.22,1.3,.1,white)
 end
 for i=0,4 do box(-30+i*.95,8.3,-53,.72,2.6+(i%2)*.4,2,bookColors[i+1])end
 box(-21,8.3,-53,2.7,3.2,.35,brown)
 box(-21,8.6,-52.77,2.1,2.4,.1,cyan)
 box(-16.5,8.3,-53,3,.35,2.6,{.71,.63,.40})
 -- Oak's desk, computer and blue swivel chair.
 box(0,7,-54,23,1,8.5,brown)
 box(-9,0,-54,2,7,7,brown);box(8,0,-54,5,7,7,brown)
 for y=1,5,2 do
  box(8,y,-50.4,4,1.5,.2,{.56,.39,.23})
  box(8,y+.6,-50.23,1.1,.18,.12,{.72,.65,.43})
 end
 box(-1,8,-55,2,1,2,black);box(-1,9,-55,.6,2,.6,black)
 box(-1,10.5,-55,9,6.3,.7,black)
 box(-1,11.1,-54.56,7.8,5.1,.1,{.16,.28,.31})
 box(-1,11.4,-54.49,6.9,.15,.03,teal)
 box(6.5,8,-56,2.4,7,3.4,{.22,.25,.24})
 box(6.5,12,-54.2,1.5,.3,.10,gray)
 box(6.5,9.5,-54.18,.35,.35,.1,cyan)
 box(-1,8,-51.7,7.6,.35,2.1,gray)
 for k=0,6 do rect(-4+k,-51.7,.56,1.3,8.36,light)end
 box(-8,8,-54,3,.4,3.7,bookColors[1]);box(-8,8.4,-54,3.3,.4,3.4,bookColors[4])
 local function chair(x,z)
  cyl(x,.12,z,1.1,.55,gray,10)
  for _,a in ipairs({0,math.pi/2})do
   local dx,dz=math.cos(a)*3.1,math.sin(a)*3.1
   quad({x-dx,.5,z-dz-.23},{x+dx,.5,z+dz-.23},{x+dx,.5,z+dz+.23},{x-dx,.5,z-dz+.23},gray)
  end
  cyl(x,.6,z,.42,3,gray,10)
  box(x,3.6,z,5.4,.8,5,blue)
  box(x,4.4,z+2.0,4.8,5.6,.65,blue)
  box(x,4.4,z+2.39,3.8,4.9,.14,{.28,.44,.63})
 end
 chair(0,-44)
 -- Blue research cylinder and adjacent utility equipment.
 box(-35,.04,-45,16,.8,15,gray)
 cyl(-35,.84,-45,5.7,1.3,gray,24)
 cyl(-35,2.14,-45,4.8,12.8,cyan,24)
 cyl(-35,14.94,-45,5.4,1,white,24)
 cyl(-35,15.94,-45,5.7,1.3,gray,24)
 disk(-35,17.25,-45,4.8,{.13,.36,.45},24)
 for _,s in ipairs({-1,1})do
  box(-35+s*4.8,2.14,-45,.5,12.8,.65,white)
 end
 for j=0,6 do local a=-.30+j*.065;local b=a+.15;local y=3+j*1.55
  local function p(t,h)return{-35+math.sin(t)*4.86,h,-45+math.cos(t)*4.86}end
  quad(p(a,y),p(b,y),p(b+.065,y+1.56),p(a+.065,y+1.56),{.62,.82,.81})
 end
 box(-45,0,-54,8,14,5.7,gray)
 box(-45,1,-51.0,6.9,11.8,.2,white)
 for y=2,10,2 do box(-46.4,y,-50.82,2.2,1.1,.12,{.36,.43,.43})end
 box(-43.4,4,-50.8,1.1,5,.1,black)
 box(-43.4,10,-50.7,.55,.55,.12,bookColors[1])
 box(-45,14,-54,8,3.8,5.7,white)
 box(-45,16.1,-51.0,6,.6,.16,teal)
 -- Mobile research board placed beside the cylinder.
 for _,s in ipairs({-1,1})do
  box(-30+s*4.5,0,-28,2.1,.5,3,gray)
  box(-30+s*4.5,.5,-28,.4,6,.4,gray)
 end
 box(-30,5.6,-28,13,9,.65,gray)
 box(-30,6.1,-27.58,11.9,8,.12,light)
 for i=0,3 do
  box(-32.8,7.5+i*1.3,-27.46,4-(i%2)*.8,.22,.06,gray)
 end
 box(-26.6,10.8,-27.44,2.4,2,.08,{.63,.43,.54})
 box(-27.5,7.4,-27.44,3.5,.26,.08,teal)
 -- Scientific wall map and framed certificates; marks are decorative.
 box(-4,18,-59.4,24,8,.3,gray);box(-4,18.4,-59.15,23,7.2,.1,light)
 box(-1,19.4,-59.01,5.8,4.9,.08,{.38,.59,.36})
 box(-4.3,20.1,-58.97,2.4,3.5,.08,cyan)
 for _,p in ipairs({{-1,22.8},{1,21.3},{-.5,20.1}})do box(p[1],p[2],-58.9,.65,.65,.06,bookColors[2])end
 for i=0,3 do box(-11,19.4+i*1.3,-59.0,5-(i%2)*1.1,.24,.06,gray)end
 for _,x in ipairs({12,20})do
  box(x,20,-59.4,4.8,6.1,.25,brown);box(x,20.4,-59.22,4,5.3,.1,light)
  for j=0,3 do box(x,21.3+j,-59.1,2.9-(j%2)*.7,.16,.05,gray)end
 end
 -- Starter display table with three individual ball holders.
 for _,dx in ipairs({-10,10})do for _,dz in ipairs({-3,3})do box(40+dx,0,-33+dz,1.3,6,1.3,white)end end
 box(40,6,-33,23,1.3,9,white);rect(40,-33,21.3,7.4,7.31,{.40,.66,.41})
 local function ball(x,z)
  cyl(x,7.34,z,2.25,.45,gray,20);cyl(x,7.79,z,1.95,.35,white,20)
  local r,cy=1.85,9.62
  for j=0,11 do local a,b=-math.pi/2+j*math.pi/12,-math.pi/2+(j+1)*math.pi/12
   for i=0,19 do local u,v=i*math.pi/10,(i+1)*math.pi/10
    local function p(t,s)return{x+r*math.sin(t)*math.cos(s),cy+r*math.sin(s),z+r*math.cos(t)*math.cos(s)}end
    quad(p(u,a),p(v,a),p(v,b),p(u,b),j>=6 and{.78,.11,.08}or light,.86+.10*math.cos(u))
   end
  end
  cyl(x,cy-.12,z,1.87,.24,black,20)
  for k=0,1 do local r=k==0 and .56 or .36;local zz=z+1.88+k*.02
   for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
    quad({x,cy,zz},{x+r*math.cos(a),cy+r*math.sin(a),zz},{x+r*math.cos(b),cy+r*math.sin(b),zz},{x,cy,zz},k==0 and black or light)
   end
  end
 end
 ball(33,-33);ball(40,-33);ball(47,-33)
 -- Plants, a small reading table and a hanging lab coat.
 local function plant(x,z,scale,potColor,y)
  y=y or .04
  cyl(x,y,z,1.8*scale,2.6*scale,potColor,12)
  cyl(x,y+2.6*scale,z,2*scale,.4*scale,potColor,12)
  disk(x,y+3.01*scale,z,1.65*scale,brown,12)
  for i=0,6 do local a=i*2.39;local h=5+(i%3)*1.4
   quad({x,y+3*scale,z},{x+math.cos(a)*2.6*scale,y+h*scale,z+math.sin(a)*2.6*scale},
    {x+math.cos(a+.4)*1.6*scale,y+(h-1.7)*scale,z+math.sin(a+.4)*1.6*scale},{x,y+3*scale,z},i%2==0 and{.29,.48,.22}or{.39,.58,.27})
  end
 end
 cyl(-44,.05,51,1.8,.5,gray,12);cyl(-44,.55,51,.55,4.5,brown,12)
 cyl(-44,5.05,51,5,.55,{.69,.46,.27},24)
 plant(-44,51,.55,teal,5.61);chair(-31,54)
 plant(47,49,1.25,{.61,.32,.19})
 cyl(65,.04,5,1.8,.5,brown,12);cyl(65,.54,5,.25,13.8,brown,10)
 box(65,12.7,5,6.2,.4,.5,brown)
 box(65,5.7,5.45,3.7,6.8,.7,light)
 for _,s in ipairs({-1,1})do box(65+s*2.6,7.2,5.45,1.3,4.6,.7,white)end
 box(65,10.7,5.9,.6,1.7,.1,gray)
 for y=6.5,9.5,1 do box(65,y,5.9,.18,.18,.1,gray)end
 -- Purple entrance mat with a subtle Poké Ball motif.
 rect(0,64.5,21,10,.045,purple);rect(0,64.5,19.4,8.4,.048,{.60,.43,.62})
 rect(0,64.5,18.6,7.6,.051,purple)
 disk(0,.054,64.5,2.8,{.60,.43,.62},20);disk(0,.055,64.5,2.35,purple,20)
 rect(0,64.5,16,.45,.057,{.60,.43,.62});disk(0,.059,64.5,.85,{.66,.51,.68},16)
end
return R
