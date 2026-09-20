-- Cinnabar Gym / Blaine. Compact terrarium for integration by PANDY.
-- Visual direction: ODias; supplied anime battlefield, fan arena and Volcano Badge.
-- Reuse the host bowl, camera, participants, trainer plinths and branding.
local C={revision='cinnabar-compact-v1'}
local basalt={.24,.23,.235}
local dark={.12,.12,.14}
local metal={.40,.36,.30}
local pale={.90,.80,.58}
function C.appliesTo(mapId)return mapId=='CINNABAR_GYM'end

function C.button(h)
 local q=h.quad
 local outline={{0,1.05},{-.17,.94},{-.32,.69},{-.49,.48},{-.69,.43},{-.87,.51},{-1,.78},
  {-1.12,.51},{-1.14,.27},{-1.05,.07},{-.88,-.18},{-.87,-.32},{-1.02,-.60},{-1.02,-.82},
  {-.89,-1.07},{-.64,-1.24},{-.31,-1.32},{0,-1.35},{.36,-1.29},{.72,-1.13},{.96,-.88},
  {1.02,-.59},{.88,-.32},{.85,-.17},{1.02,.11},{1.08,.37},{1.04,.58},{.96,.83},
  {.83,.58},{.60,.43},{.39,.46},{.23,.74},{.09,.99}}
 local function p(a,s,z)return{a[1]*6.8*s,-5+a[2]*6.8*s,78.35+z}end
 for i=1,#outline do local j=i%#outline+1;local a,b=outline[i],outline[j]
  q({0,-5,78.35},p(a,1,0),p(b,1,0),{0,-5,78.35},{.73,.015,.18})
  q(p(a,.985,.02),p(b,.985,.02),p(b,.80,.02),p(a,.80,.02),i>20 and{1,.49,.70}or{.86,.025,.22})
  q({0,-5,78.40},p(a,.80,.05),p(b,.80,.05),{0,-5,78.40},{1,.07,.23})
 end
 local drop={{0,.05},{-.17,-.10},{-.33,-.40},{-.38,-.62},{-.24,-.85},{.02,-1.02},{.28,-.81},{.38,-.57},{.24,-.25}}
 for i=1,#drop do local j=i%#drop+1
  q({0,-8.5,78.44},p(drop[i],1,.09),p(drop[j],1,.09),{0,-8.5,78.44},{.35,.025,.12})
  local a,b=drop[i],drop[j]
  local function inner(v)return{v[1]*.87,-.49+(v[2]+.49)*.90}end
  q({0,-8.5,78.47},p(inner(a),1,.12),p(inner(b),1,.12),{0,-8.5,78.47},i>5 and{1,.60,.78}or{.98,.32,.59})
 end
end

function C.build(h,setup)
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
 local lava={{.96,.19,.025},{1,.30,.025},{1,.43,.035},{1,.56,.055},{1,.72,.10},{.83,.13,.02}}
 -- Flat molten basin: bounded palette and static polygon detail, no particles.
 local function lavaPoint(band,index)
  local i=index%96
  local a=(i+.24*math.sin(i*12.9+band*7))*math.pi/48
  local r=band*8.16
  if band>0 and band<9 then r=r+math.sin(i*3+band*7)*2.5 end
  if band==9 then a=i*math.pi/48 end
  return{math.cos(a)*r,.02,math.sin(a)*r}
 end
 for band=0,8 do local r1,r2=band*8.16,(band+1)*8.16
  for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
   local n=math.floor(math.abs(math.sin(i*12.9898+band*78.233))*10000)%6
   local p1,p2=lavaPoint(band,i),lavaPoint(band,i+1)
   local p3,p4=lavaPoint(band+1,i+1),lavaPoint(band+1,i)
   quad(p1,p2,p3,p4,lava[n+1])
   if band>4 and (i+band)%3==0 then
    local aa=a+.017;local bb=b-.011;local ra=r1+2.1;local rb=r2-1.2
    quad({math.cos(aa)*ra,.027,math.sin(aa)*ra},{math.cos(bb)*ra,.027,math.sin(bb)*ra},
     {math.cos(bb)*rb,.027,math.sin(bb)*rb},{math.cos(aa)*rb,.027,math.sin(aa)*rb},{1,.84,.25})
   end
  end
 end
 -- Dark central slab. Its battle surface stays at the host ground height.
 rect(0,0,98,90,.031,dark)
 rect(0,0,94,86,.036,basalt)
 for x=-44,44,4 do for z=-40,40,4 do
  local n=(x*13+z*7+5000)%5
  rect(x,z,4.02,4.02,.039,({{.24,.235,.24},{.265,.255,.25},{.23,.225,.235},{.28,.265,.26},{.255,.245,.245}})[n+1])
  if n%2==0 then
   quad({x-1.7,.043,z-1.3},{x-.1,.043,z+.5},{x+.05,.043,z+.4},{x-1.55,.043,z-1.4},dark)
   quad({x-.1,.043,z+.5},{x+1.5,.043,z+.9},{x+1.6,.043,z+.75},{x+.05,.043,z+.4},dark)
  end
 end end
 -- Thin arena boundary and central Poké Ball marking from the anime field.
 for _,x in ipairs({-44,44})do rect(x,0,.55,80,.055,pale)end
 for _,z in ipairs({-40,40})do rect(0,z,88,.55,.055,pale)end
 rect(0,0,88,.55,.055,pale)
 for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
  for _,r in ipairs({10,2.6})do
   quad({math.cos(a)*r,.058,math.sin(a)*r},{math.cos(b)*r,.058,math.sin(b)*r},
    {math.cos(b)*(r-.5),.058,math.sin(b)*(r-.5)},{math.cos(a)*(r-.5),.058,math.sin(a)*(r-.5)},pale)
  end
 end
 -- Support aprons under the host trainer plinths, keeping their feet above stone.
 for _,p in pairs(setup.trainers)do
  rect(p[1],p[3],16,16,.046,dark)
  rect(p[1],p[3],14.5,14.5,.048,basalt)
  if math.abs(p[1])>45 then
   for x=47,61,2 do rect((p[1]>0 and 1 or -1)*x,p[3],.25,13,.051,metal)end
  elseif p[3]>40 then
   for z=43,53,2 do rect(p[1],z,13,.25,.051,metal)end
  end
 end
 -- Narrow dark entry bridge across the lava.
 rect(0,57,13,24,.044,dark)
 for z=47,67,2.5 do rect(0,z,11.5,2.15,.05,basalt)end
 for _,x in ipairs({-6,6})do rect(x,57,.35,24,.053,metal)end
 -- Faceted volcanic outcrops with charcoal caps and warm lower rock faces.
 local function rock(x,z,r,height,seed)
  local rings={}
  for level=0,3 do
   local scale=({1,.93,.65,.23})[level+1];local y=({.03,.24,.73,1})[level+1]*height
   rings[level+1]={}
   for i=0,7 do local a=i*math.pi/4;local jitter=.89+((i*7+seed*3+level)%5)*.04
    rings[level+1][i+1]={x+math.cos(a)*r*scale*jitter+level*.22,y,z+math.sin(a)*r*scale*.77*jitter}
   end
  end
  for j=1,3 do for i=1,8 do local k=i%8+1
   quad(rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],j==1 and{.43,.25,.16}or{.30,.26,.25},.68+j*.07+(i%3)*.04)
  end end
  for i=1,8 do local k=i%8+1
   quad({x+.7,height*1.05,z},rings[4][i],rings[4][k],{x+.7,height*1.05,z},basalt)
  end
 end
 for _,v in ipairs({{-21,-62,7,23},{0,-67,6.2,29},{21,-62,7.5,25},{-39,-53,5.7,15},{39,-53,6.2,17},
  {-64,-24,4.8,8},{64,24,4.8,7},{-56,43,5.4,7},{56,43,5.4,8}})do
  if clear(v[1],v[2],v[3]*2,v[3]*1.6)then rock(v[1],v[2],v[3],v[4],7)end
 end
 -- Alternating metal chain links connect slab corners to low anchor posts.
 for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
  local ax,az=sx*46,sz*42;local bx,bz=sx*53,sz*49
  if clear(bx,bz,4,4)then
   box(bx,.03,bz,2.2,6,2.2,metal)
   for j=0,7 do
    local t=j/7;local x,z=ax+(bx-ax)*t,az+(bz-az)*t;local y=.8+5.3*t
    local function point(a,r)
     local u,v=math.cos(a)*1.2*r,math.sin(a)*.62*r
     if j%2==0 then return{x+sx*u*.707,y+v,z+sz*u*.707}end
     return{x+sx*u*.707-sz*v*.707,y,z+sz*u*.707+sx*v*.707}
    end
    for k=0,11 do local a,b=k*math.pi/6,(k+1)*math.pi/6
     quad(point(a,1),point(b,1),point(b,.60),point(a,.60),{.56,.48,.36})
    end
   end
  end
 end end
end
return C
