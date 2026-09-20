-- Viridian Gym / Giovanni. Compact terrarium for integration by PANDY.
-- Visual direction: ODias; supplied Let's Go concept art and Earth Badge.
-- Reuse host bowl, camera, participants, trainer plinths and branding.
local V={revision='viridian-compact-v1'}
local wood={.30,.18,.12}
local iron={.13,.14,.15}
local ivory={.83,.82,.73}
local red={.49,.12,.15}
local green={.055,.42,.29}
local blue={.055,.40,.62}
local gold={.82,.70,.16}
function V.appliesTo(mapId)return mapId=='VIRIDIAN_GYM'end

function V.button(h)
 local q=h.quad
 local function at(p,d)return{p[1]*7.4,-7+p[2]*7.4,78.35+d}end
 local function poly(points,c,d)
  for i=2,#points-1 do q(at(points[1],d),at(points[i],d),at(points[i+1],d),at(points[1],d),c)end
 end
 -- The Earth Badge is a diagonal bud with five faceted green tips and a stem.
 poly({{.17,-.32},{.31,-.30},{.91,-.87},{.96,-1},{.88,-1.03},{.74,-.94}}, {.48,.62,.14},0)
 poly({{.26,-.38},{.36,-.42},{.88,-.92},{.87,-.96},{.77,-.89}}, {.74,.90,.39},.025)
 poly({{-.58,.51},{-.14,.76},{.29,.18},{.42,-.22},{.37,-.51},{.06,-.55},{-.35,-.21}}, {.015,.40,.06},.03)
 poly({{-.58,.51},{-.14,.76},{-.25,-.24},{-.35,-.21}}, {.52,.94,.69},.04)
 poly({{-.14,.76},{.29,.18},{-.25,-.24}}, {.015,.69,.27},.045)
 poly({{-.25,-.24},{-.20,.03},{-.02,.14},{.29,.18},{.42,-.22},{.37,-.51},{.06,-.55}}, {.66,.86,.34},.05)
 poly({{-.25,-.24},{-.20,.03},{-.02,.14},{.29,.18},{.06,-.14}}, {.75,.98,.40},.06)
 local function gem(x,y,r,col,light)
  local pts={{x-r*.7,y+r*.7},{x+r*.25,y+r*.92},{x+r*.87,y+r*.12},{x+r*.61,y-r*.77},{x-r*.45,y-r*.94},{x-r*.93,y-r*.10}}
  local mid={x-r*.1,y-r*.03};local rim={}
  for i,p in ipairs(pts)do rim[i]={x+(p[1]-x)*1.06,y+(p[2]-y)*1.06}end
  poly(rim,{.025,.07,.035},.075)
  for i=1,6 do local j=i%6+1
   local c=i<3 and light or (i<5 and col or{col[1]*.55,col[2]*.55,col[3]*.55})
   q(at(mid,.09),at(pts[i],.09),at(pts[j],.09),at(mid,.09),c)
  end
 end
 gem(-.58,.70,.25,{.76,.99,.87},{.98,1,.96})
 gem(-.20,.69,.23,{.015,.57,.15},{.015,.75,.26})
 gem(.08,.49,.18,{.025,.51,.075},{.01,.73,.27})
 gem(-.81,.31,.26,{.015,.55,.20},{.025,.74,.29})
 gem(-.56,-.02,.25,{.015,.58,.20},{.54,.94,.66})
 local function leaf(points)
  poly(points,{.055,.11,.04},.105)
  local cx,cy=0,0;for _,p in ipairs(points)do cx=cx+p[1]/#points;cy=cy+p[2]/#points end
  for i=1,#points do local j=i%#points+1
   local function inset(p)return{cx+(p[1]-cx)*.90,cy+(p[2]-cy)*.90}end
   q(at({cx,cy},.13),at(inset(points[i]),.13),at(inset(points[j]),.13),at({cx,cy},.13),i<3 and{.91,1,.71}or{.65,.86,.34})
  end
 end
 leaf({{.30,.14},{.42,.02},{.56,-.19},{.55,-.36},{.43,-.43},{.29,-.38},{.23,-.26},{.24,-.08}})
 leaf({{-.23,-.53},{-.05,-.40},{.13,-.37},{.28,-.43},{.33,-.56},{.25,-.67},{.06,-.68},{-.10,-.61}})
end

function V.build(h,setup)
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
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},{math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},{.35,.34,.35})
 end
 -- Diagonal grey stone tiles inspired by the polished floor in the concept art.
 for u=-15,15 do for v=-15,15 do
  local x,z=(u-v)*5,(u+v)*5
  if (math.abs(x)+4.94)^2+z*z<73^2 and x*x+(math.abs(z)+4.94)^2<73^2 then
   local c=({{.43,.415,.425},{.47,.45,.455},{.40,.39,.405},{.45,.435,.44}})[(u*7+v*3+100)%4+1]
   quad({x-4.92,.034,z},{x,.034,z-4.92},{x+4.92,.034,z},{x,.034,z+4.92},c)
  end
 end end
 -- Arrow plates are floor decoration; no forced movement or puzzle logic.
 local function plate(x,z,kind,angle)
  local c=kind=='stop' and gold or(kind=='blue' and blue or green)
  rect(x,z,7.6,7.6,.044,{.60,.62,.55});rect(x,z,7,6.7,.048,c)
  for _,dz in ipairs({-3.3,3.3})do
   for dx=-3,3,1 do rect(x+dx,z+dz,.64,.35,.052,{.85,.85,.66})end
  end
  if kind=='stop'then rect(x,z,4.9,1.4,.059,{.97,.97,.89});return end
  local function at(a,b)return{x+a*math.cos(angle)-b*math.sin(angle),.059,z+a*math.sin(angle)+b*math.cos(angle)}end
  for _,dx in ipairs({-1.6,1.2})do
   quad(at(dx-1,-2),at(dx+1.2,0),at(dx-1,2),at(dx-1,-2),{.94,.97,.88})
  end
 end
 local plates={{-34,39,'green',-1.57},{-34,30,'blue',-1.57},{-34,21,'blue',0},{-25,21,'green',0},{-16,21,'stop',0},
  {-16,12,'green',-1.57},{-16,3,'blue',-1.57},{-16,-6,'blue',0},{-7,-6,'green',0},{2,-6,'stop',0},
  {20,36,'green',0},{29,36,'green',-1.57},{29,27,'stop',0},{36,9,'green',-1.57},{36,-9,'green',-1.57},
  {29,-30,'green',3.14},{20,-30,'green',3.14},{11,-30,'blue',-1.57},{0,-39,'blue',-1.57},{0,-49,'stop',0},
  {-34,-30,'stop',0},{-25,-39,'green',0}}
 for _,v in ipairs(plates)do plate(v[1],v[2],v[3],v[4])end
 -- Low wooden posts and crossed iron braces, segmented around participant spaces.
 local function rail(x,z,alongX)
  local w,d=alongX and 8 or 1.3,alongX and 1.3 or 8
  if not clear(x,z,w,d)then return end
  for _,p in ipairs(plates)do
   if math.abs(x-p[1])<w/2+3.8 and math.abs(z-p[2])<d/2+3.8 then return end
  end
  box(x,4.2,z,w,.65,d,wood)
  for _,t in ipairs({-3.8,3.8})do
   box(x+(alongX and t or 0),0,z+(alongX and 0 or t),1,5,1,wood)
  end
  local function point(t,y)return{x+(alongX and t or .18),y,z+(alongX and .18 or t)}end
  for _,s in ipairs({-1,1})do
   quad(point(-3.6,s>0 and 1 or 3.8),point(3.6,s>0 and 3.8 or 1),
    point(3.6,s>0 and 4.05 or 1.25),point(-3.6,s>0 and 1.25 or 4.05),iron)
  end
 end
 for _,z in ipairs({-24,25.5,44.5})do for x=-28,28,8 do if math.abs(x)>5 then rail(x,z,true)end end end
 for z=-32,32,8 do rail(43,z,false)end
 for z=-24,0,8 do rail(-34,z,false)end
 for x=-4,20,8 do rail(x,11,true)end
 -- Two rows of red seats on pale stepped side terraces.
 for _,s in ipairs({-1,1})do for row=0,1 do for z=-32,32,6.4 do
  local x=s*(54+row*6)
  if (math.abs(x)+2.7)^2+(math.abs(z)+2.8)^2<72^2 and clear(x,z,5.4,6)then
   local y=2.2+row*3.2
   box(x,0,z,5.8,y,6.1,ivory)
   box(x,y,z,4.7,.9,5,red)
   box(x+s*1.8,y+.9,z,.8,3,5,red)
   box(x-s*2.6,y,z,.22,3.6,6,wood)
  end
 end end end
 -- Rear ivory panels and brown columns frame Giovanni's red carpet.
 for _,s in ipairs({-1,1})do for i=0,2 do
  local x=s*(13+i*9.5)
  box(x,0,-61,9.4,21,2,wood)
  box(x,1.4,-59.8,8,18,.4,ivory)
  box(x,20.5,-61,9.6,.8,2.5,wood)
 end end
 local function carpet(x,z,w,d)
  rect(x,z,w,d,.045,{.26,.19,.18});rect(x,z,w-1.4,d-1.4,.05,{.61,.06,.10})
  for _,dx in ipairs({-w/2+1.5,w/2-1.5})do rect(x+dx,z,.35,d-3,.055,{.39,.10,.13})end
  for _,dz in ipairs({-d/2+1.5,d/2-1.5})do rect(x,z+dz,w-3,.35,.055,{.39,.10,.13})end
 end
 carpet(0,-60,13,19);carpet(0,62,15,18)
 local function lamp(x,z,y)
  box(x,0,z,.7,y, .7,wood)
  box(x,y,z,1.8,.35,1.8,iron)
  box(x,y+.35,z,1.35,2,1.35,{.96,.89,.64})
  box(x,y+2.35,z,1.8,.3,1.8,wood)
 end
 for _,x in ipairs({-8.5,8.5})do lamp(x,-57,13)end
 -- Small Rhydon-inspired stone figures: horns and side arms read at compact scale.
 for _,x in ipairs({-13,13})do
  if clear(x,53,6,6)then
   box(x,0,53,5.5,1.1,5.5,ivory);box(x,1.1,53,4.7,2.5,4.7,{.49,.50,.48})
   box(x,1.6,55.4,2.6,1.4,.12,gold)
   box(x,3.6,53,3.1,2.6,3,ivory);box(x,6.2,53.1,3.6,2,3.2,ivory)
   for _,s in ipairs({-1,1})do box(x+s*2,4.4,53,1.3,2,1.6,{.62,.63,.58})end
   quad({x-.55,7.2,54.7},{x+.55,7.2,54.7},{x,8.3,56.1},{x-.55,7.2,54.7},ivory)
   box(x-1.2,8.1,52.8,.7,1,.8,ivory);box(x+1.2,8.1,52.8,.7,1,.8,ivory)
  end
 end
end
return V
