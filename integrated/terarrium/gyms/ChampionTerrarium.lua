-- Champion battle: compact creation for PANDY.
-- Visual direction: ODias; supplied concept art and winged league badge.
local T={
 key="champion",
 mapId="CHAMPIONS_ROOM",
 badgeShadow={0.29,0.17,0.045},
 badgeMetal={0.85,0.59,0.13},
 badgeLight={1,0.87,0.43},
 gem={0.39,0.79,0.91},
 gemLight={0.9,0.99,1},
 gemShade={0.18,0.49,0.69},
 ballTop={0.95,0.065,0.09},
 ballBottom={0.94,0.94,0.91}
}
-- Self-contained scene: shared helpers below require no external files or textures.
local E={revision=T.key..'-compact-v1'}
function E.appliesTo(mapId)return mapId==T.mapId end

local function crest(q,cx,cy,z,size)
 local function at(p,d)return{cx+p[1]*size,cy+p[2]*size,z+d}end
 local function poly(points,color,d)
  for i=2,#points-1 do q(at(points[1],d),at(points[i],d),at(points[i+1],d),at(points[1],d),color)end
 end
 -- Four swept feathers on each side preserve the supplied Elite Four silhouette.
 for _,s in ipairs({-1,1})do
  local feathers={
   {{.29,-.04},{.44,.27},{.70,.56},{1,.67},{.79,.44},{.71,.06},{.43,-.16}},
   {{.30,-.27},{.45,-.02},{.69,.10},{.88,.27},{.84,.02},{.66,-.17},{.37,-.40}},
   {{.27,-.48},{.38,-.28},{.61,-.20},{.79,-.04},{.70,-.30},{.48,-.48},{.24,-.61}},
   {{.19,-.69},{.30,-.48},{.50,-.45},{.66,-.33},{.55,-.56},{.28,-.83},{.13,-.85}}}
  for j,points in ipairs(feathers)do
   local p={};for i,v in ipairs(points)do p[i]={s*v[1],v[2]}end
   poly(p,T.badgeShadow,.01*j)
   local inset={};local ax,ay=0,0
   for _,v in ipairs(p)do ax=ax+v[1]/#p;ay=ay+v[2]/#p end
   for i,v in ipairs(p)do inset[i]={ax+(v[1]-ax)*.91,ay+(v[2]-ay)*.91}end
   poly(inset,T.badgeMetal,.01*j+.004)
   poly({inset[1],inset[2],inset[3],inset[4]},T.badgeLight,.01*j+.007)
  end
 end
 -- Long central shield and triangular jewel.
 poly({{-.39,.22},{.39,.22},{.20,-.82},{0,-1.04},{-.20,-.82}},T.badgeShadow,.06)
 poly({{-.35,.18},{.35,.18},{.17,-.79},{0,-.98},{-.17,-.79}},T.badgeMetal,.07)
 poly({{-.28,.105},{.28,.105},{0,-.81}},T.badgeShadow,.08)
 poly({{-.245,.07},{.245,.07},{0,-.735}},T.gem,.09)
 poly({{-.23,.06},{-.16,.04},{0,-.70}},T.gemLight,.10)
 poly({{.245,.07},{.18,-.01},{0,-.735}},T.gemShade,.10)
 -- Poké Ball above the shield: recoloured cap, pale lower half and central button.
 local function p(a,r,d)return at({math.cos(a)*r,.60+math.sin(a)*r},d)end
 for i=0,47 do local a,b=i*math.pi/24,(i+1)*math.pi/24
  q(p(a,.415,.11),p(b,.415,.11),p(b,.373,.12),p(a,.373,.12),i<24 and T.badgeLight or T.badgeMetal)
  q(at({0,.60},.13),p(a,.372,.13),p(b,.372,.13),at({0,.60},.13),i<24 and T.ballTop or T.ballBottom)
 end
 poly({{-.373,.575},{.373,.575},{.373,.625},{-.373,.625}},T.badgeShadow,.145)
 for i=0,31 do local a,b=i*math.pi/16,(i+1)*math.pi/16
  q(at({0,.60},.15),p(a,.16,.15),p(b,.16,.15),at({0,.60},.15),T.badgeShadow)
  q(at({0,.60},.16),p(a,.108,.16),p(b,.108,.16),at({0,.60},.16),T.gemLight)
 end
 poly({{-.29,.76},{-.19,.91},{.02,.95},{-.10,.88}},T.gemLight,.17)
end
function E.button(h)crest(h.quad,0,-7,78.35,8.7)end

function E.build(h,setup)
 local box,quad=h.box,h.quad
 local white={.91,.92,.88};local ice={.47,.78,.85};local navy={.055,.16,.32}
 local gold={.81,.58,.20};local brightGold={.98,.80,.38};local pale={.72,.89,.91}
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
  N=N or 32
  for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
   quad({x,y,z},{x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x,y,z},c)
  end
 end
 -- Dark lavender perimeter evokes the depth around the elevated champion court.
 disk(0,.02,0,73.5,{.22,.23,.35},96)
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(math.floor(x/8)*7+math.floor(z/8)*3+200)%4
   rect(x,z,7.75,7.75,.031,({{.38,.38,.49},{.46,.46,.56},{.42,.41,.52},{.51,.49,.59}})[n+1])
  end
 end end
 -- Octagonal border and white tiled platform, kept close to host ground level.
 local oct={{-49,-33},{-37,-45},{37,-45},{49,-33},{49,33},{37,45},{-37,45},{-49,33}}
 for i=1,8 do local j=i%8+1;local a,b=oct[i],oct[j]
  quad({0,.035,0},{a[1],.035,a[2]},{b[1],.035,b[2]},{0,.035,0},ice)
  quad({a[1],.038,a[2]},{b[1],.038,b[2]},{b[1]*.975,.038,b[2]*.975},{a[1]*.975,.038,a[2]*.975},pale)
 end
 rect(0,0,76,87,.041,{.66,.72,.75})
 for x=-34,34,4 do for z=-40,40,4 do
  local c=({white,{.95,.95,.92},{.86,.90,.90}})[(math.floor(x/4)+math.floor(z/4)+100)%3+1]
  rect(x,z,3.8,3.8,.043,c)
 end end
 -- Blue hexagonal channels flank the white floor, with static inset light discs.
 for _,s in ipairs({-1,1})do
  rect(s*42,0,9,72,.042,navy)
  for z=-32,32,6.8 do
   for _,dx in ipairs({-2.1,2.1})do
    disk(s*42+dx,.046,z+(dx>0 and 1.6 or 0),2.4,{.08,.31,.56},6)
   end
  end
  for z=-28,28,14 do
   disk(s*42,.05,z,1.7,{.30,.58,.78},24)
   disk(s*42,.052,z,1.2,pale,24);disk(s*42,.054,z,.68,{.95,.99,.96},16)
  end
 end
 -- Blue champion battle mat, dark outline and red/angular side markings.
 rect(0,0,73,61,.055,{.12,.17,.24})
 rect(0,0,70.5,58.5,.057,{.52,.56,.60})
 rect(0,0,57,60,.059,white)
 rect(0,0,55.7,58.7,.061,{.32,.66,.79})
 for x=-26,26,4 do rect(x,0,.11,58,.063,{.41,.72,.82})end
 for z=-28,28,4 do rect(0,z,55,.11,.063,{.41,.72,.82})end
 for _,s in ipairs({-1,1})do for _,d in ipairs({-1,1})do
  quad({s*29.2,.064,d*28.6},{s*34.1,.064,d*28.6},{s*34.1,.064,d*9},{s*29.2,.064,d*14},{.81,.035,.085})
  rect(s*34,d*27.4,4,2.6,.066,{.95,.05,.10})
 end end
 for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
  local c=i<32 and white or{.88,.14,.20}
  quad({0,.067,0},{math.cos(a)*9,.067,math.sin(a)*9},{math.cos(b)*9,.067,math.sin(b)*9},{0,.067,0},c)
  quad({math.cos(a)*9.1,.070,math.sin(a)*9.1},{math.cos(b)*9.1,.070,math.sin(b)*9.1},
   {math.cos(b)*8.6,.070,math.sin(b)*8.6},{math.cos(a)*8.6,.070,math.sin(a)*8.6},navy)
 end
 rect(0,0,71,.55,.072,white)
 disk(0,.074,0,3.5,navy);disk(0,.076,0,3.0,white);disk(0,.078,0,2.5,ice)
 -- Tall white-and-gold shafts with cyan inlays; no transparent materials.
 local function column(x,z,height,r)
  box(x,0,z,r*2.7,1.3,r*2.7,gold)
  box(x,1.3,z,r*2.4,1,r*2.4,brightGold)
  for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4
   quad({x+math.cos(a)*r,2.3,z+math.sin(a)*r},{x+math.cos(b)*r,2.3,z+math.sin(b)*r},
    {x+math.cos(b)*r,height-3,z+math.sin(b)*r},{x+math.cos(a)*r,height-3,z+math.sin(a)*r},i%2==0 and white or{.77,.83,.83},.84+(i%3)*.05)
  end
  box(x,height-3,z,r*2.15,2,r*2.15,white)
  box(x,height-1,z,r*2.5,1.1,r*2.5,brightGold)
  box(x,height+.1,z,r*2.0,.15,r*2.0,{1,.89,.54})
  box(x,4,z+r*.96,.65,height-9,.16,ice)
  box(x-.15,4.2,z+r*1.04,.18,height-9.5,.04,{.84,.99,1})
  for _,y in ipairs({3,height-7})do box(x,y,z,r*2.1,.5,r*2.1,{.63,.70,.72})end
 end
 local positions={}
 for _,s in ipairs({-1,1})do for _,v in ipairs({{44,-33,32,2.8},{66,0,27,2.6},{58,33,23,2.7},{18,-55,27,2.3}})do
  local x,z=s*v[1],v[2]
  if clear(x,z,8,8)then column(x,z,v[3],v[4]);positions[#positions+1]={x,z}end
 end end
 -- Ivory rear facade and raised doorway, with a small winged champion crest.
 box(0,0,-63,65,27,2.2,white)
 for x=-28,28,4 do
  box(x,3,-61.7,.22,22,.2,{.63,.82,.85})
  if math.abs(x)>21 then box(x,10,-61.35,1.1,12,.15,{.18,.42,.64})end
 end
 box(0,26.5,-63,66,1.0,2.8,gold)
 box(0,0,-56,19,5,13,{.32,.38,.47})
 box(0,5,-61,14,18,1.8,gold)
 box(0,5,-59.9,11.5,16,.35,navy)
 box(0,5.1,-59.65,8.5,13,.16,{.065,.09,.19})
 for i=0,3 do box(0,0,-45-i*2.6,12,1.2+i*1.2,2.6,{.28,.37,.46});box(0,1.2+i*1.2,-45-i*2.6,12,.12,2.6,ice)end
 crest(quad,0,24.5,-59.2,4.4)
 -- Short peripheral panels carry the blue inlays of the concept-art walls.
 for _,s in ipairs({-1,1})do for _,z in ipairs({-25,23})do
  local x=s*62;local near=false
  for _,p in ipairs(positions)do if math.abs(p[1]-x)<6 and math.abs(p[2]-z)<10 then near=true end end
  if not near and clear(x,z,2,8)then
   box(x,0,z,1.4,19,8,white);box(x,18.5,z,2,1,8.5,ice)
   box(x-s*.85,6,z,.2,10,1.8,{.14,.36,.58})
   box(x-s*1,6.7,z,.1,8.6,.75,pale)
  end
 end end
 -- Entrance bridge and gold railings, adapted to the bowl's flat host floor.
 rect(0,57,22,23,.042,{.55,.54,.66});rect(0,57,11,23,.046,navy)
 rect(0,57,2.6,23,.050,ice);rect(0,57,.7,23,.052,{.80,.98,1})
 for _,s in ipairs({-1,1})do
  box(s*7,4.0,57,.65,.7,21,gold)
  for z=47,67,5 do
   box(s*7,.04,z,.75,4.4,.75,brightGold)
   disk(s*7,4.5,z,.8,brightGold,12)
   disk(s*9.5,.054,z,1.1,{.49,.70,.80},20);disk(s*9.5,.056,z,.65,pale,16)
  end
 end
end
return E
