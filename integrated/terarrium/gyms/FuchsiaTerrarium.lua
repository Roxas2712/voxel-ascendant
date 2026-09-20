-- Fuchsia Gym / Koga. Compact interior for integration by PANDY.
-- Visual direction: ODias; supplied Let's Go concept art and Soul Badge.
-- Reuse the host bowl, camera, participants, trainer plinths and branding.
local F={revision='fuchsia-compact-v2'}
local wood={.29,.17,.11}
local trim={.17,.105,.085}
local warm={.96,.83,.58}
local stone={.62,.64,.61}
local purple={.56,.22,.42}
local green={.42,.47,.20}
function F.appliesTo(mapId)return mapId=='FUCHSIA_GYM'end

function F.button(h)
 local q=h.quad
 -- Rounded, tapered pink heart with the shallow upper notch of Soul Badge.
 local outline={{0,.56},{-.20,.64},{-.43,.79},{-.64,.76},{-.82,.55},{-.96,.23},
  {-.99,-.03},{-.88,-.33},{-.69,-.63},{-.43,-.94},{-.16,-1.18},{0,-1.25},
  {.19,-1.14},{.46,-.85},{.70,-.52},{.87,-.19},{.96,.13},{.91,.43},
  {.74,.72},{.54,.88},{.35,.91},{.17,.77}}
 local function at(p,scale,d)return{p[1]*7.7*scale,-5+p[2]*7.7*scale,78.35+d}end
 for i=1,#outline do local j=i%#outline+1
  local a,b=outline[i],outline[j]
  q({0,-5,78.35},at(a,1,0),at(b,1,0),{0,-5,78.35},{.92,.13,.82})
  q(at(a,.985,.02),at(b,.985,.02),at(b,.80,.02),at(a,.80,.02),i>15 and{1,.66,.98}or{.96,.31,.93})
  q({0,-5,78.40},at(a,.80,.05),at(b,.80,.05),{0,-5,78.40},{.98,.35,.95})
 end
 q({0,-3.4,78.43},{-.18,-4.1,78.43},{.27,-12.4,78.43},{.69,-12,78.43},{.94,.19,.88})
 local function glint(x,y,rx,ry,angle)
  local function point(a)return{x+math.cos(a)*rx*math.cos(angle)-math.sin(a)*ry*math.sin(angle),
   y+math.cos(a)*rx*math.sin(angle)+math.sin(a)*ry*math.cos(angle),78.46}end
  for i=0,19 do q({x,y,78.46},point(i*math.pi/10),point((i+1)*math.pi/10),{x,y,78.46},{1,.97,1})end
 end
 glint(3.7,-2.3,1.0,2.0,.65);glint(5.25,-5.8,.52,1.0,-.65)
end

function F.build(h,setup)
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
 -- Dark circular backing and individually clipped staggered floorboards.
 for i=0,95 do local a,b=i*math.pi/48,(i+1)*math.pi/48
  quad({0,.02,0},{math.cos(a)*73.5,.02,math.sin(a)*73.5},{math.cos(b)*73.5,.02,math.sin(b)*73.5},{0,.02,0},trim)
 end
 for row=-17,17 do local z=row*4;local half=math.sqrt(73^2-(math.abs(z)+1.94)^2)
  for col=-5,5 do
   local start=col*16+(row%3)*5.3
   local a,b=math.max(-half,start),math.min(half,start+15.85)
   if b>a then
    local n=(row*7+col*3+200)%5
    local c=({{.36,.23,.15},{.40,.26,.17},{.33,.205,.14},{.38,.24,.16},{.43,.28,.18}})[n+1]
    rect((a+b)/2,z,b-a,3.85,.034,c)
    if b-a>5 then
     rect((a+b)/2,z-.8,(b-a)*.65,.10,.037,{.29,.18,.12})
     rect(a+.6,z+1.1,.24,.24,.04,trim)
    end
   end
  end
 end
 -- Koga's green mat, bordered by pink woven geometric bands.
 rect(0,-9,19,15,.05,trim)
 rect(0,-9,18,14,.06,green)
 rect(0,-9,16.4,10,.07,{.64,.66,.32})
 for z=-13.7,-4.3,.8 do rect(0,z,16,.12,.075,{.57,.59,.27})end
 for _,z in ipairs({-15,-3})do
  rect(0,z,18,1.7,.08,purple)
  for x=-8,8,2 do
   quad({x-.8,.09,z},{x,.09,z-.6},{x+.8,.09,z},{x,.09,z+.6},{.93,.68,.72})
  end
 end
 -- Low rear shoji wall, warm translucent-paper colours baked into geometry.
 box(0,0,-62.5,66,28,2,trim)
 for col=-2,2 do local x=col*12.6
  box(x,1,-61.25,11.8,8,.45,wood)
  for dx=-5,5,1.25 do box(x+dx,1,-60.9,.3,8,.35,trim)end
  box(x,9.5,-61.2,11.5,12,.4,warm)
  for _,dx in ipairs({-5.7,-2.9,0,2.9,5.7})do box(x+dx,9.5,-60.8,.27,12,.3,wood)end
  for _,y in ipairs({10,13.5,18,21.5})do box(x,y,-60.7,11.8,.32,.4,wood)end
  -- Curved fan motif in the lower paper window.
  for i=0,11 do local a,b=i*math.pi/12,(i+1)*math.pi/12
   quad({x+math.cos(a)*4.5,11+math.sin(a)*4.5,-60.4},{x+math.cos(b)*4.5,11+math.sin(b)*4.5,-60.4},
    {x+math.cos(b)*4.15,11+math.sin(b)*4.15,-60.4},{x+math.cos(a)*4.15,11+math.sin(a)*4.15,-60.4},wood)
  end
  box(x,23,-61,11.5,3,.4,{.42,.29,.18})
  -- Abstract pierced-wood scrolls suggest the carved transoms in the artwork.
  for dx=-4,4,2 do
   quad({x+dx-1,23.5,-60.7},{x+dx,25.2,-60.7},{x+dx+1,24.9,-60.7},{x+dx,23.2,-60.7},trim)
  end
 end
 for _,x in ipairs({-32,-19,-6.4,6.4,19,32})do box(x,0,-60.4,1.3,28,2,trim)end
 box(0,27.5,-62,67,1.3,3,wood)
 -- Two compact stepped rows of purple and olive seats on each side.
 for _,s in ipairs({-1,1})do for row=0,1 do for z=-32,32,6.4 do
  local x=s*(54+row*6)
  if (math.abs(x)+2.7)^2+(math.abs(z)+2.7)^2<72^2 and clear(x,z,5.3,6)then
   local y=2+row*3;local c=row==0 and purple or green
   box(x,0,z,5.8,y,6.2,wood)
   box(x,y,z,4.6,.8,5.1,c)
   box(x+s*1.9,y+.8,z,.7,3.3,5.1,c)
   box(x-s*2.6,y,z,.3,3.8,5.8,trim)
  end
 end end end
 -- Fog is reserved for a future host effect; no fog geometry is emitted.
 -- Low wooden entry partition, clipped around trainer positions.
 for _,x in ipairs({-35,-25,25,35})do
  if clear(x,43,9,2)then
   box(x,0,43,9,2.7,1.2,wood);box(x,2.7,43,9,.6,1.6,trim)
   box(x-4,0,43,.8,4,1.5,trim)
  end
 end
 -- Slate entry, paired gym statues, and a red mat with pale decorative lines.
 rect(0,56,33,12,.05,trim)
 for x=-14,14,4.7 do for z=52,60,4 do rect(x,z,4.4,3.7,.06,{.25,.245,.25})end end
 for _,x in ipairs({-11,11})do
  if clear(x,55,5,5)then
   box(x,.06,55,5.4,1.1,5.4,stone);box(x,1.16,55,4.5,1.1,4.5,trim)
   box(x,2.26,55,3.1,3.1,3,stone);box(x,5.36,55,3.4,2,3.1,stone)
   for _,s in ipairs({-1,1})do box(x+s*1.3,7,55,.7,1.1,.9,stone)end
  end
 end
 rect(0,65,16,7,.06,{.70,.20,.28})
 for _,z in ipairs({62.2,62.7,67.3,67.8})do rect(0,z,15,.18,.07,{.94,.80,.68})end
 for _,x in ipairs({-5,5})do
  for i=0,11 do local a,b=i*math.pi/6,(i+1)*math.pi/6
   quad({x+math.cos(a)*1.3,.08,65+math.sin(a)*1.3},{x+math.cos(b)*1.3,.08,65+math.sin(b)*1.3},
    {x+math.cos(b)*1.0,.08,65+math.sin(b)*1.0},{x+math.cos(a)*1.0,.08,65+math.sin(a)*1.0},{.94,.80,.68})
  end
 end
end
return F
