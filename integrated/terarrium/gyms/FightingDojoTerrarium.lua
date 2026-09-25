-- Fighting Dojo: compact interior for integration by PANDY.
-- Visual direction: ODias, based on the supplied LGPE Fighting Dojo concept art.
-- Reuse the host bowl, camera, participants, trainer platforms and branding.
local R={revision='fighting-dojo-compact-v1'}
local black={.13,.10,.08}
local wood={.36,.21,.12}
function R.appliesTo(mapId)return mapId=='FIGHTING_DOJO'end
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
 local timber={.48,.28,.14}
 local honey={.61,.39,.21}
 local dark={.24,.12,.065}
 local paper={.85,.81,.68}
 local scarlet={.73,.19,.11}
 local tatami={.64,.69,.36}
 local matEdge={.38,.42,.20}
 local function cyl(x,y,z,r,height,c,n)
  n=n or 16;disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*math.pi*2/n,(i+1)*math.pi*2/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.82+.12*math.cos(a))
  end
 end
 -- Clipped floorboards retain a clean circular silhouette.
 disk(0,.02,0,73.5,{.36,.21,.12},96)
 for row=0,34 do local z=-68+row*4
  local span=math.sqrt(math.max(0,73^2-(math.abs(z)+1.9)^2))
  for col=-6,6 do local x=col*14+(row%2)*7
   local left,right=math.max(x-6.9,-span),math.min(x+6.9,span)
   if right-left>.3 then
    local tone=({{.59,.38,.21},{.63,.41,.23},{.56,.34,.18},{.66,.43,.25}})[(row+col+20)%4+1]
    rect((left+right)/2,z,right-left,3.82,.035,tone)
    if right-left>5 then rect((left+right)/2,z+.85,right-left-2,.07,.038,{.51,.32,.17})end
   end
  end
 end
 -- Eight woven tatami panels with a red training boundary.
 rect(0,4,85,85,.045,dark);rect(0,4,83.8,83.8,.047,honey)
 rect(0,4,81.6,81.6,.049,matEdge)
 local panels={{-30,-16,20,40},{-30,24,20,40},{30,-16,20,40},{30,24,20,40},
  {0,-26,40,20},{0,34,40,20},{-10,4,20,40},{10,4,20,40}}
 for i,p in ipairs(panels)do local x,z,w,d=p[1],p[2],p[3],p[4]
  local tone=i%2==0 and tatami or{.68,.72,.40}
  rect(x,z,w-.35,d-.35,.052,tone)
  if w>d then
   for t=-d/2+1,d/2-1,.8 do rect(x,z+t,w-.8,.07,.054,{.58,.63,.32})end
  else
   for t=-w/2+1,w/2-1,.8 do rect(x+t,z,.07,d-.8,.054,{.58,.63,.32})end
  end
 end
 rect(-33.5,4,4.4,66,.060,scarlet);rect(33.5,4,4.4,66,.060,scarlet)
 rect(0,-27,67,4.4,.061,scarlet);rect(0,35,67,4.4,.061,scarlet)
 -- Rear wooden wall, plaster band and inset display alcove.
 box(0,0,-61,70,26,2.5,timber)
 for x=-32,32,4 do box(x,.7,-59.6,3.8,18.4,.35,(x%8==0)and honey or timber)end
 box(0,19.2,-59.5,67,5.1,.5,paper)
 box(0,18.5,-59.15,69,.7,.7,dark)
 box(0,24.9,-61,72,1.4,3.5,dark)
 box(0,.2,-59.15,69,1,.8,dark)
 for _,x in ipairs({-35,-18,18,35})do box(x,0,-59.3,1.5,26,1.5,dark)end
 box(0,5.2,-59.0,33,17.9,.6,{.73,.65,.42})
 box(0,23.0,-58.6,35,1.2,1.1,dark)
 -- Two short angled wall wings frame the room without closing its sides.
 local function wallWing(s)
  local ax,az=s*35,-60;local bx,bz=s*58,-39
  local dx,dz=bx-ax,bz-az;local l=math.sqrt(dx*dx+dz*dz)
  local nx,nz=-dz/l,dx/l
  if nx*s>0 then nx,nz=-nx,-nz end
  local function p(t,y,off)return{ax+dx*t+nx*off,y,az+dz*t+nz*off}end
  quad(p(0,0,0),p(1,0,0),p(1,22,0),p(0,26,0),timber,.82)
  for j=0,9 do local a,b=j/10+.006,(j+1)/10-.006
   quad(p(a,1,.08),p(b,1,.08),p(b,17,.08),p(a,17,.08),j%2==0 and honey or timber,.90)
  end
  quad(p(0,18,.15),p(1,18,.15),p(1,20.8,.15),p(0,24.8,.15),paper,.91)
  quad(p(0,24.8,0),p(1,20.8,0),p(1,22.1,0),p(0,26.1,0),dark)
  for _,t in ipairs({0,.5,1})do
   box(ax+dx*t,0,az+dz*t,1.5,26-4*t,1.5,dark)
  end
 end
 wallWing(-1);wallWing(1)
 -- Hanging scrolls: decorative brush strokes, not translated lettering.
 local ink={.15,.13,.105}
 local function stroke(x,y,z,dx,dy,width,c)
  local len=math.sqrt(dx*dx+dy*dy);local nx,ny=-dy/len*width/2,dx/len*width/2
  quad({x+nx,y+ny,z},{x+dx+nx,y+dy+ny,z},{x+dx-nx,y+dy-ny,z},{x-nx,y-ny,z},c)
 end
 for _,x in ipairs({-10,10})do
  box(x,8.5,-58.45,7.4,13.7,.3,{.48,.20,.13})
  box(x,9,-58.23,6.1,12.7,.12,{.90,.86,.72})
  box(x,8.4,-58.2,8,.5,.4,dark);box(x,21.8,-58.2,8,.5,.4,dark)
  for j=0,3 do local y=11+j*2.7
   stroke(x-1.4,y+1.1,-58.12,2.7,.4,.45,ink)
   stroke(x+.15,y+1.6,-58.1,-.4,-1.8,.48,ink)
   stroke(x-.4,y+.55,-58.09,-1.4,-.85,.40,ink)
   stroke(x-.1,y+.3,-58.08,1.8,-.7,.36,ink)
  end
  box(x+1.9,9.35,-58.06,.8,.8,.04,scarlet)
 end
 -- Low display shelf and two red cushions with gold tassels.
 box(0,0,-54.6,33,2.5,9,dark);box(0,2.5,-54.6,34,1,9.8,honey)
 box(0,3.5,-54.6,33,.4,9.5,timber)
 local function ball(x,z)
  box(x,3.9,z,7,.55,6.2,{.55,.16,.10});box(x,4.45,z,6.5,.4,5.8,scarlet)
  for _,s in ipairs({-1,1})do box(x+s*3,3.9,z+2.6,.45,.3,1.3,{.83,.60,.25})end
  local r,cy=2.4,7.27
  for j=0,11 do local a,b=-math.pi/2+j*math.pi/12,-math.pi/2+(j+1)*math.pi/12
   local tone=j>=6 and{.80,.12,.08}or{.88,.87,.78}
   for i=0,19 do local u,v=i*math.pi/10,(i+1)*math.pi/10
    local function p(t,s)return{x+r*math.cos(s)*math.sin(t),cy+r*math.sin(s),z+r*math.cos(s)*math.cos(t)}end
    quad(p(u,a),p(v,a),p(v,b),p(u,b),tone,.83+.12*math.cos(u-.5))
   end
  end
  cyl(x,cy-.17,z,2.415,.34,ink,20)
  local function button(r,zf,c)
   for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
    quad({x,cy,zf},{x+r*math.cos(a),cy+r*math.sin(a),zf},{x+r*math.cos(b),cy+r*math.sin(b),zf},{x,cy,zf},c)
   end
  end
  button(.80,z+2.43,ink);button(.55,z+2.46,{.95,.93,.83})
 end
 ball(-10,-54.4);ball(10,-54.4)
 -- Blue ceramic vase with leaves and three pink flower stems.
 cyl(0,3.9,-54.6,1.45,.5,{.21,.40,.44},16)
 cyl(0,4.4,-54.6,1.9,2.5,{.31,.56,.59},16)
 cyl(0,6.9,-54.6,1.6,1,{.36,.62,.63},16)
 cyl(0,7.9,-54.6,1.05,.6,{.20,.42,.44},16)
 for i=-1,1 do local x,z=i*.65,-54.6+math.abs(i)*.3
  box(x,8.4,z,.15,5.4-math.abs(i),.15,{.28,.43,.19})
  for j=0,4 do
   local y=10+j*.85-math.abs(i)*.65
   cyl(x,y,z,.54-.05*j,.55,j%2==0 and{.75,.37,.58}or{.89,.54,.70},8)
  end
 end
 for _,s in ipairs({-1,1})do
  quad({0,8.6,-54.5},{s*2.7,10.4,-54.7},{s*2.1,8.9,-53.9},{0,8.6,-54.5},{.30,.47,.18})
 end
 -- Paired wooden screens placed beside the display, clear of trainer platforms.
 local function screen(x)
  local z=-47.5
  local outerQuad=quad
  local s=x<0 and -1 or 1
  local function at(p)
   local u,v=p[1]-x,p[3]-z
   return{x+u*.8+s*v*.6,p[2],z-s*u*.6+v*.8}
  end
  local function quad(a,b,c,d,tone,shade)outerQuad(at(a),at(b),at(c),at(d),tone,shade)end
  local function box(cx,y,cz,w,h,d,tone)
   local a,b=cx-w/2,cx+w/2;local e,f=cz-d/2,cz+d/2;local t=y+h
   quad({a,t,e},{b,t,e},{b,t,f},{a,t,f},tone)
   quad({a,y,f},{b,y,f},{b,t,f},{a,t,f},tone,.88)
   quad({b,y,e},{a,y,e},{a,t,e},{b,t,e},tone,.76)
   quad({b,y,f},{b,y,e},{b,t,e},{b,t,f},tone,.91)
   quad({a,y,e},{a,y,f},{a,t,f},{a,t,e},tone,.84)
  end
  for _,dz in ipairs({-7,7})do
   box(x,0,z+dz,3.8,.65,3.2,dark);box(x,.65,z+dz,.9,16,.9,dark)
  end
  box(x,2,z,.7,13.7,14,timber)
  for _,y in ipairs({2.3,8.7,15.4})do box(x,y,z,1,.7,14.7,dark)end
  box(x,2.4,z,1,13,.65,dark)
  for _,dz in ipairs({-3.7,3.7})do
   for _,y in ipairs({5.5,12})do
    for _,s in ipairs({-1,1})do
     quad({x+s*.53,y-1,z+dz},{x+s*.53,y,z+dz+1.5},{x+s*.53,y+1,z+dz},{x+s*.53,y,z+dz-1.5},honey)
    end
   end
  end
 end
 screen(-30);screen(30)
 -- Two empty stone plinths, as in the reference (no statues).
 local function plinth(x,z)
  box(x,.04,z,8.8,.8,8.8,{.34,.34,.34})
  box(x,.84,z,7.1,4.6,7.1,{.51,.49,.43})
  box(x,5.44,z,8.5,1.1,8.5,{.74,.72,.63})
  box(x,1.7,z+3.61,3.9,2.5,.13,{.38,.36,.29})
  box(x,2.0,z+3.7,3.2,1.9,.12,{.70,.57,.29})
 end
 plinth(-35,52);plinth(35,52)
 -- Small red entry mat; no badge is added to the bowl button.
 rect(0,65,20,9,.045,dark);rect(0,65,18.8,7.8,.048,scarlet)
 rect(0,65,17.3,6.3,.050,{.79,.35,.19});rect(0,65,16.6,5.6,.052,{.59,.16,.10})
end
return R
