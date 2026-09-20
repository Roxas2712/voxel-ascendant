-- Elite Four / Lorelei. Compact creation for PANDY.
-- Visual direction: ODias; supplied concept art and winged Elite Four badge.
local T={
 name="Lorelei",
 key="lorelei",
 mapId="LORELEIS_ROOM",
 style="league_ice",
 family="ice",
 kind="ice",
 subtitle="GELO · AZUL E ROSA",
 tiles={{0.28,0.66,0.81},{0.65,0.85,0.91},{0.39,0.75,0.88},{0.75,0.89,0.92}},
 grout={0.7,0.84,0.91},
 floorHighlight={0.85,0.96,0.97},
 court={0.82,0.57,0.77},
 courtGrid={0.88,0.67,0.83},
 courtEdge={0.39,0.36,0.57},
 courtLine={0.97,0.94,0.96},
 markFront={0.62,0.84,0.92},
 markBack={0.86,0.62,0.8},
 wall={0.59,0.8,0.87},
 cap={0.86,0.64,0.83},
 trim={0.37,0.35,0.61},
 windowFrame={0.29,0.49,0.67},
 window={0.84,0.96,0.96},
 columnDark={0.29,0.42,0.64},
 columnLight={0.8,0.96,0.98},
 columnTones={{0.26,0.64,0.8},{0.47,0.81,0.9},{0.7,0.92,0.94}},
 doorFrame={0.35,0.32,0.57},
 door={0.78,0.78,0.84},
 badgeShadow={0.19,0.32,0.48},
 badgeMetal={0.54,0.77,0.87},
 badgeLight={0.88,0.96,0.98},
 gem={0.43,0.85,0.96},
 gemLight={0.93,0.99,1},
 gemShade={0.21,0.58,0.77},
 ballTop={0.26,0.68,0.85},
 ballBottom={0.94,0.78,0.88}
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
 local function polygonFloor(points,y,c)
  for i=2,#points-1 do quad({points[1][1],y,points[1][2]},{points[i][1],y,points[i][2]},
   {points[i+1][1],y,points[i+1][2]},{points[1][1],y,points[1][2]},c)end
 end
 -- Circular floor and square tiles, retaining the palette of each illustrated room.
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},{math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},T.grout)
 end
 for x=-68,68,8 do for z=-68,68,8 do
  if (math.abs(x)+3.9)^2+(math.abs(z)+3.9)^2<73^2 then
   local n=(math.floor(x/8)*7+math.floor(z/8)*13+3000)%4
   rect(x,z,7.7,7.7,.034,T.tiles[n+1])
   if T.kind=='ice'then
    polygonFloor({{x-3.4,z-3.2},{x-2.3,z-3.2},{x+3.2,z+2.2},{x+3.2,z+3.3}},.037,T.floorHighlight)
   elseif T.kind=='rock' and n%2==0 then
    polygonFloor({{x-3.5,z-1.9},{x-.1,z+.5},{x+2.8,z+1.3},{x+.1,z+.28},{x-3.3,z-2.0}},.037,T.crack)
   elseif T.kind=='ghost' and n==1 then
    rect(x+3.3,z+2,1.7,1.8,.037,T.moss)
    rect(x+2.2,z+3.3,2.7,.8,.038,T.moss)
   elseif T.kind=='dragon' and n%2==0 then
    polygonFloor({{x-3,z-2},{x-1,z-2.8},{x+2.8,z+1.6},{x+1.6,z+2.6}},.037,T.floorHighlight)
   end
  end
 end end
 -- Shared central court geometry, with member-specific coloured Poké Ball halves.
 rect(0,0,67,87,.041,T.courtEdge)
 rect(0,0,65.6,85.6,.043,T.courtLine)
 rect(0,0,64.6,84.6,.045,T.court)
 for x=-30,30,4 do rect(x,0,.15,84,.047,T.courtGrid)end
 for z=-40,40,4 do rect(0,z,64,.15,.047,T.courtGrid)end
 local radius=10.2
 for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
  local c=i<32 and T.markFront or T.markBack
  quad({0,.049,0},{math.cos(a)*radius,.049,math.sin(a)*radius},{math.cos(b)*radius,.049,math.sin(b)*radius},{0,.049,0},c)
  quad({math.cos(a)*radius,.052,math.sin(a)*radius},{math.cos(b)*radius,.052,math.sin(b)*radius},
   {math.cos(b)*(radius-.42),.052,math.sin(b)*(radius-.42)},{math.cos(a)*(radius-.42),.052,math.sin(a)*(radius-.42)},T.courtLine)
 end
 rect(0,0,64.5,.5,.054,T.courtLine)
 for i=0,47 do local a,b=i*math.pi/24,(i+1)*math.pi/24
  quad({0,.056,0},{math.cos(a)*3.2,.056,math.sin(a)*3.2},{math.cos(b)*3.2,.056,math.sin(b)*3.2},{0,.056,0},T.courtLine)
  quad({0,.058,0},{math.cos(a)*2.7,.058,math.sin(a)*2.7},{math.cos(b)*2.7,.058,math.sin(b)*2.7},{0,.058,0},T.court)
 end
 -- Generic turned pillar helper: all surfaces are opaque geometry.
 local function profile(x,z,rings,sides,colors)
  for j=1,#rings-1 do
   local a,b=rings[j],rings[j+1]
   for i=0,sides-1 do local u,v=i*2*math.pi/sides,(i+1)*2*math.pi/sides
    quad({x+math.cos(u)*a[2],a[1],z+math.sin(u)*a[2]},
     {x+math.cos(v)*a[2],a[1],z+math.sin(v)*a[2]},
     {x+math.cos(v)*b[2],b[1],z+math.sin(v)*b[2]},
     {x+math.cos(u)*b[2],b[1],z+math.sin(u)*b[2]},colors[(i+j)%#colors+1],.77+(i%4)*.055)
   end
  end
  local top=rings[#rings]
  for i=0,sides-1 do local a,b=i*2*math.pi/sides,(i+1)*2*math.pi/sides
   quad({x,top[1],z},{x+math.cos(a)*top[2],top[1],z+math.sin(a)*top[2]},
    {x+math.cos(b)*top[2],top[1],z+math.sin(b)*top[2]},{x,top[1],z},T.columnLight)
  end
 end
 local function pillar(x,z)
  if T.kind=='ice'then
   profile(x,z,{{0,5},{1.2,5},{1.8,4.1}},8,{T.trim,T.columnDark})
   profile(x,z,{{1.8,3.8},{3,3.7},{8,2.3},{10,1.8},{11,2.8},{12,2.8},{13,1.9},{22,2.0},{23,3.6},{24.5,4.5},{26,4.7}},8,T.columnTones)
   for _,s in ipairs({-1,1})do
    quad({x+s*1.2,13.4,z+1.8},{x+s*1.55,13.4,z+1.7},{x+s*1.5,21.8,z+1.7},{x+s*1.1,21.8,z+1.8},T.columnLight)
   end
  elseif T.kind=='rock'then
   box(x,0,z,8.2,1.5,8.2,T.columnDark);box(x,1.5,z,7.4,1.3,7.4,T.columnLight)
   for course=0,7 do
    profile(x,z,{{2.8+course*2.45,3.0},{5.1+course*2.45,3.0}},10,T.columnTones)
   end
   profile(x,z,{{10.1,3.2},{12.5,3.2}},10,{T.columnLight})
   box(x,22.4,z,7,1.4,7,T.columnDark);box(x,23.8,z,8.5,2,8.5,T.columnLight)
   -- Round inset on the broad central belt evokes the carved martial emblem.
   for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
    quad({x+math.cos(a)*1,11.3+math.sin(a)*1,z+3.22},{x+math.cos(b)*1,11.3+math.sin(b)*1,z+3.22},
     {x+math.cos(b)*.66,11.3+math.sin(b)*.66,z+3.23},{x+math.cos(a)*.66,11.3+math.sin(a)*.66,z+3.23},T.columnDark)
   end
  elseif T.kind=='ghost'then
   box(x,0,z,8.4,1.3,8.4,T.columnDark);box(x,1.3,z,7.4,1.1,7.4,T.trim)
   box(x,2.4,z,5.4,21,5.4,T.columnDark)
   for _,dx in ipairs({-2.5,2.5})do box(x+dx,2.4,z+.2,.38,21,5.3,T.columnLight)end
   for y=3,21,3 do
    if y<9 or y>15 then
     quad({x-1.8,y,z+2.75},{x,y+1.3,z+2.75},{x+1.8,y,z+2.75},{x,y+.35,z+2.75},T.trim)
    end
   end
   box(x,10,z+2.8,4,4.6,.5,T.columnLight)
   box(x,10.5,z+3.1,2.9,3.5,.2,T.gem)
   box(x,11.2,z+3.23,1.5,2.1,.12,T.gemLight)
   box(x,23.4,z,7.2,1.2,7.2,T.trim);box(x,24.6,z,8.1,1.5,8.1,T.columnDark)
  else
   profile(x,z,{{0,4.7},{1.4,4.7},{2.2,3.7}},12,{T.columnDark,T.trim})
   profile(x,z,{{2.2,2.7},{23,2.7}},12,T.columnTones)
   -- Small raised diamonds follow the shaft, evoking scales without a texture.
   for row=0,6 do for i=0,11 do
    local a=(i+(row%2)*.5)*math.pi/6;local r=2.74;local yy=4+row*2.6
    local function at(aa,y)return{x+math.cos(aa)*r,y,z+math.sin(aa)*r}end
    quad(at(a-.23,yy),at(a,yy+1.1),at(a+.23,yy),at(a,yy-1.1),T.columnLight,.84+(i%3)*.04)
   end end
   profile(x,z,{{23,2.9},{24,3.7},{25.2,4.2},{26,4.2}},12,{T.columnLight,T.columnTones[1]})
   for i=0,3 do local a=i*math.pi/2;local u,v=math.cos(a),math.sin(a)
    quad({x+u*3-v*.8,1.5,z+v*3+u*.8},{x+u*3+v*.8,1.5,z+v*3-u*.8},
     {x+u*4.7,4.5,z+v*4.7},{x+u*3-v*.8,1.5,z+v*3+u*.8},T.columnLight)
   end
  end
 end
 -- Three pairs of columns match the reference composition.
 local pillars={}
 for _,s in ipairs({-1,1})do for _,v in ipairs({{44,-33},{66,0},{58,33}})do
  local x,z=s*v[1],v[2]
  if clear(x,z,10,10)then pillar(x,z);pillars[#pillars+1]={x,z}end
 end end
 -- Short rear wall and peripheral window panels leave the top completely open.
 for _,s in ipairs({-1,1})do for i=0,2 do
  local x=s*(14+i*8.7)
  box(x,0,-62,8.6,26,2,T.wall)
  box(x,1,-60.8,8.3,1.2,.4,T.trim)
  box(x,24.6,-62,8.8,1.5,2.6,T.cap)
  box(x,8,-60.7,3.1,13,.25,T.windowFrame)
  box(x,8.6,-60.45,2.25,11.8,.12,T.window)
  box(x,11.5,-60.25,2.7,.25,.2,T.windowFrame)
 end end
 for _,s in ipairs({-1,1})do
  for _,z in ipairs({-34,-17,0,17,34})do
   local x=s*63
   local nearColumn=false
   for _,p in ipairs(pillars)do if math.abs(p[1]-x)<7 and math.abs(p[2]-z)<10 then nearColumn=true end end
   if not nearColumn and x*x+(math.abs(z)+4)^2<73^2 and clear(x,z,2.5,8)then
    box(x,0,z,1.7,15,8,T.wall)
    box(x,15,z,2.3,1,8.5,T.cap)
    box(x-s*1.0,2,z,.25,11,5.8,T.windowFrame)
    box(x-s*1.2,2.7,z,.15,9.5,4.6,T.window)
   end
  end
 end
 -- League doorway and smaller version of the same winged crest above it.
 box(0,0,-61.2,18,23,2,T.doorFrame)
 box(0,1,-59.9,14.8,20.5,.45,T.door)
 box(0,1,-59.55,.6,20.5,.35,T.badgeMetal)
 for _,x in ipairs({-8.4,8.4})do
  box(x,0,-59.5,2.0,24,3.2,T.doorFrame)
  box(x,0,-59.2,2.5,1,3.6,T.trim)
 end
 box(0,23,-60,19,1,3,T.trim)
 crest(quad,0,25.6,-58.2,3.8)
 -- Matching entry paving, with a narrow coloured border.
 rect(0,61,16,19,.041,T.trim);rect(0,61,14.5,17.5,.043,T.tiles[2])
 for z=54,68,4 do rect(0,z,14.5,.12,.045,T.grout)end
end
return E

