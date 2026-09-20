-- Team Rocket Hideout 2: compact office scene for integration by PANDY.
-- Visual direction: ODias; supplied office concept art and Rocket R icon.
-- Reuse host bowl, camera, participants, trainer plinths and branding.
local R={revision='rocket-hideout-office-compact-v1'}
function R.appliesTo(mapId)return mapId=='ROCKET_HIDEOUT_B4F'end
local black={.085,.095,.105}
local red={.57,.12,.15}
local trim={.77,.76,.70}
local wood={.37,.20,.12}

local function rocket(q,x,y,z,size)
 local function at(a,b)return{x+a*size,y+b*size,z}end
 local c={.84,.035,.055}
 -- Block R drawn as separate strokes so the counter remains genuinely open.
 q(at(-.62,-.86),at(-.22,-.86),at(-.22,.87),at(-.62,.87),c)
 q(at(-.22,.87),at(.34,.87),at(.58,.66),at(-.22,.49),c)
 q(at(.29,.56),at(.58,.66),at(.67,.28),at(.30,.20),c)
 q(at(-.22,.18),at(.30,.20),at(.67,.28),at(.46,-.12),c)
 q(at(-.22,.18),at(.46,-.12),at(.20,-.23),at(-.22,-.23),c)
 q(at(.01,-.12),at(.39,-.06),at(.76,-.86),at(.27,-.86),c)
end
function R.button(h)rocket(h.quad,0,-7,78.4,8.3)end

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
 disk(0,.02,0,73.5,{.23,.24,.27},96)
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(math.floor(x/8)*7+math.floor(z/8)*3+200)%4
   rect(x,z,7.8,7.8,.034,({{.30,.31,.34},{.34,.35,.38},{.28,.29,.32},{.32,.33,.36}})[n+1])
  end
 end end
 -- Dark seams and tiny red floor indicators echo the industrial office tiles.
 for _,x in ipairs({-42,42})do rect(x,0,.65,103,.039,black)end
 for _,z in ipairs({-38,38})do rect(0,z,97,.65,.039,black)end
 for _,x in ipairs({-48,48})do for z=-40,40,16 do
  for _,dx in ipairs({-.5,.5})do for _,dz in ipairs({-.5,.5})do rect(x+dx,z+dz,.7,.7,.042,{.76,.19,.19})end end
 end end
 -- Red runner with dark border and small corner flourishes.
 rect(0,17,34,82,.045,black);rect(0,17,32.4,80.4,.047,{.54,.09,.12})
 for _,x in ipairs({-14.7,14.7})do rect(x,17,.33,76,.049,{.23,.12,.14})end
 for _,z in ipairs({-20.7,54.7})do rect(0,z,29.4,.33,.049,{.23,.12,.14})end
 for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
  for i=0,2 do
   quad({sx*(13.8-i),.052,17+sz*(36-i*1.2)},{sx*(12.8-i),.052,17+sz*(35-i*1.2)},
    {sx*(13.8-i),.052,17+sz*(34-i*1.2)},{sx*(14.4-i),.052,17+sz*(35-i*1.2)},{.25,.11,.14})
  end
 end end
 -- Low red panelled rear wall, framed in pale trim.
 box(0,0,-64,66,27,2.4,trim)
 for x=-30,30,5 do
  box(x,1.3,-62.6,4.8,23.8,.35,red)
  box(x-2.2,1.3,-62.3,.12,23.8,.15,{.39,.085,.10})
 end
 for _,x in ipairs({-32,-16,16,32})do box(x,0,-62.05,.6,27,.45,trim)end
 box(0,26,-64,67,1.2,2.8,trim)
 box(0,0,-62.2,66,1.1,.4,black)
 -- Central black pennant and the red Rocket R above the executive chair.
 box(0,16,-61.7,9.5,12,.5,black)
 quad({-4.75,16,-61.38},{4.75,16,-61.38},{0,12.5,-61.38},{-4.75,16,-61.38},black)
 rocket(quad,0,21,-61.1,4.3)
 -- Small framed interpretations of the Persian and Rhydon pictures.
 local function picture(x,which)
  box(x,15.5,-62.05,13.4,8.3,.65,wood)
  box(x,16,-61.65,12.4,7.3,.35,{.75,.60,.33})
  box(x,16.45,-61.4,11.5,6.4,.22,which=='persian'and{.14,.25,.39}or{.26,.17,.32})
  local function p(a,b)return{x+a,16.6+b,-61.12}end
  local function poly(points,c)
   for i=2,#points-1 do quad(p(points[1][1],points[1][2]),p(points[i][1],points[i][2]),p(points[i+1][1],points[i+1][2]),p(points[1][1],points[1][2]),c)end
  end
  if which=='persian'then
   local c={.89,.80,.52}
   poly({{-4,1.3},{-3.1,2.7},{-1.7,2.4},{1.9,1.8},{3.2,1.1},{1.0,.8},{-1.7,1.3}},c)
   poly({{-3.5,2.4},{-3.8,4.4},{-3,3.95},{-2.15,4.1},{-1.65,4.75},{-1.4,2.8},{-2.2,2.3}},c)
   poly({{2.6,1.1},{4.6,1.9},{4.9,3.7},{4.0,4.4},{3.3,3.9},{3.4,3.3},{4.0,3.7},{4.2,2.5}},c)
   poly({{-4.3,.6},{-.4,.6},{-.9,1.2},{-3.3,1.4}},c)
  else
   local c={.62,.64,.63}
   poly({{-2.8,1.0},{-3.4,2.3},{-1.9,3.2},{-.5,3.5},{1.4,2.5},{2.1,.9}},c)
   poly({{.2,3},{.0,4.8},{1.2,4.1},{2.8,4.6},{3.8,3.2},{2.7,2.3}},c)
   poly({{2.4,3.3},{4.6,4.3},{3.2,2.7}},{.91,.92,.85})
   poly({{-3.0,2.5},{-4.8,4.2},{-4.1,1.8}},c)
   poly({{-2.9,.7},{-1.3,.7},{-1.0,1.5},{-2.1,1.6}},c)
  end
 end
 picture(-22,'persian');picture(22,'rhydon')
 -- Executive desk, small paper pad, monitor and high-backed black chair.
 box(0,0,-53,31,6.3,9.5,{.26,.11,.12})
 box(0,6.3,-53,33,1.1,11,red)
 box(0,1,-47.95,28,4.6,.2,{.40,.14,.15})
 box(0,6.35,-47.35,29,.3,.35,{.73,.34,.30})
 rect(-2,-52.4,12,4.7,7.42,{.83,.81,.72})
 rect(-11,-53,3.3,3.8,7.43,{.89,.88,.81})
 for z=-54,-52,.6 do rect(-11,z,2.3,.1,7.45,{.34,.36,.35})end
 box(9,7.4,-53,2.5,.35,2.5,black);box(9,7.75,-53,.55,1.5,.55,black)
 box(9,9.25,-53,6,4.5,.7,black);box(9,9.65,-52.55,5.2,3.6,.12,{.20,.27,.29})
 box(0,0,-59,1,3,1,black);box(0,3,-59,7,1.2,5.2,black)
 box(0,4.2,-60.8,7.2,10.8,1.3,black)
 box(0,5,-60,5.4,7.8,.4,{.15,.17,.17})
 for _,x in ipairs({-3.5,3.5})do box(x,4.2,-59,1,3,4,black)end
 -- Two low bookshelves on the left, facing the centre of the bowl.
 for _,z in ipairs({-24,33})do local x=-58
  if clear(x,z,8,13)then
   box(x,0,z,6,14,12,wood)
   box(x+3.1,1,z,.3,12,10,{.16,.11,.095})
   for _,y in ipairs({1.3,6.8,12.4})do box(x+3.3,y,z,1.1,.55,11,wood)end
   for row=0,1 do for i=0,7 do
    local c=({trim,{.31,.49,.60},{.65,.27,.23},{.77,.67,.37}})[(i+row)%4+1]
    box(x+3.3,1.85+row*5.5,z-4.3+i*1.2,.65,3.9-(i%3)*.35,.83,c)
   end end
  end
 end
 -- Side computer station, with the purple office chair from the reference.
 local tx,tz=54,24
 if clear(tx,tz,12,11)then
  for _,x in ipairs({tx-4,tx+4})do box(x,0,tz,.7,5.7,7,black)end
  box(tx,5.7,tz,10,1,8,black)
  box(tx,6.7,tz-1,6,4.5,1,black)
  box(tx,7.1,tz-.35,5.1,3.5,.12,{.86,.93,.91})
  rect(tx,tz+2,5,2,6.72,{.56,.62,.63})
  for x=tx-2,tx+2,.6 do rect(x,tz+2,.10,1.5,6.74,black)end
  box(tx+6,0,tz+5,.8,3,.8,black)
  box(tx+6,3,tz+5,4.3,1,4.2,{.52,.24,.50})
  box(tx+7.7,4,tz+5,.75,4,4.2,{.52,.24,.50})
 end
 -- Flowerpots on small rear pedestals.
 for _,x in ipairs({-31,31})do
  box(x,0,-54,4.5,3.5,4.5,wood);box(x,3.5,-54,4.8,.5,4.8,trim)
  box(x,4,-54,2.7,2.4,2.7,{.85,.84,.77})
  for i=0,5 do local a=i*math.pi/3
   disk(x+math.cos(a)*1.5,6.6,-54+math.sin(a)*1.5,1.2,{.17,.40,.23},8)
   disk(x+math.cos(a)*1.1,6.8+(i%2)*.15,-54+math.sin(a)*1.1,.8,{.78,.13,.13},8)
  end
 end
 -- Short side wall panels with static red fixtures; no lighting effects.
 for _,s in ipairs({-1,1})do for _,z in ipairs({-32,-10,12,34})do
  local x=s*64
  if x*x+(math.abs(z)+4)^2<73^2 and clear(x,z,2,8)then
   box(x,0,z,1.5,14,8,trim);box(x-s*.9,1,z,.25,12,6.6,red)
   box(x-s*1.1,5,z,.2,5,2.1,black)
   box(x-s*1.22,5.4,z,.12,4.2,1.4,{.72,.26,.22})
   for y=6,9 do box(x-s*1.35,y,z,.1,.12,1.5,black)end
  end
 end end
 rect(0,65,17,10,.042,black)
 for z=61.5,69,2.5 do rect(0,z,15,2.2,.046,{.57,.58,.57})end
end
return R
