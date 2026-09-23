-- Native Gen1 badge glazing. Small static artwork is shared by the roof and
-- projected room light. No gameplay geometry, items or badge state is changed.
local V=...
local M={SIZE=256}
local badges={PEWTER_GYM='boulder',CERULEAN_GYM='cascade',VERMILION_GYM='thunder',
 CELADON_GYM='rainbow',FUCHSIA_GYM='soul',SAFFRON_GYM='marsh',CINNABAR_GYM='volcano',VIRIDIAN_GYM='earth',FIGHTING_DOJO='dojo'}
local dojoProfile={tileset='DOJO',width=5,height=6}
local weatherTransmission={rain=.35,storm=.18,snow=.4,fog=.3}
local plans=setmetatable({},{__mode='k'})
function M.layout(map)
 local d=map and map.def;local p=d and V.require('Gen1GymInteriors').profiles[map.id]
 if d and map.id=='FIGHTING_DOJO'then p=dojoProfile end
 if not p or d.generation==2 or d.outdoor or d.tileset~=p.tileset or d.width~=p.width
  or d.height~=p.height or next(d.connections or {})then return nil end
 local old=plans[map];if old and old.w==d.width*32 and old.d==d.height*32 then return old end
 local w,depth=d.width*32,d.height*32;local size=math.min(128,w*.6)
 local out={badge=badges[map.id],w=w,d=depth,h=160,size=size,cx=w/2,cz=depth*.53}
 out.rect={out.cx-size/2,out.cx+size/2,out.cz-size/2,out.cz+size/2}
 out.family='badge_skylight_'..out.badge;plans[map]=out;return out
end
function M.isFamily(f)return type(f)=='string'and f:sub(1,15)=='badge_skylight_' end
local lead={.025,.032,.045}
function M.paint(g,badge,W,H)
 g.push();g.scale(W/256,H/256);g.clear(lead[1],lead[2],lead[3],1)
 local function poly(c,p)
  g.setColor(c[1],c[2],c[3],1)
  for _,tri in ipairs(love.math.triangulate(p))do g.polygon('fill',tri)end
  g.setColor(lead[1],lead[2],lead[3],1);g.setLineWidth(2.5);g.polygon('line',p)
 end
 local function circle(c,x,y,r)
  g.setColor(c[1],c[2],c[3],1);g.circle('fill',x,y,r,48)
  g.setColor(lead[1],lead[2],lead[3],1);g.setLineWidth(3);g.circle('line',x,y,r,48)
 end
 local function line(x,y,xx,yy)
  g.setColor(lead[1],lead[2],lead[3],1);g.setLineWidth(2);g.line(x,y,xx,yy)
 end
 -- Radial panes use repeatable, slightly different glass colours; no RNG.
 local glass=badge=='dojo'and {{.68,.38,.14},{.90,.67,.32},{.97,.84,.54},{.74,.51,.25}}
  or {{.28,.49,.67},{.49,.67,.73},{.65,.75,.77},{.39,.59,.70}}
 for i=0,23 do
  local a,b=i*math.pi/12,(i+1)*math.pi/12
  -- Coloured panes fill the entire flush ceiling aperture. No black corner
  -- backing or external ring: only the internal stained-glass joints remain.
  local ra=129/math.max(math.abs(math.cos(a)),math.abs(math.sin(a)))
  local rb=129/math.max(math.abs(math.cos(b)),math.abs(math.sin(b)))
  poly(glass[i%4+1],{128,128,128+ra*math.cos(a),128+ra*math.sin(a),128+rb*math.cos(b),128+rb*math.sin(b)})
 end
 circle({.13,.23,.33},128,128,86)
 if badge=='dojo'then
  -- Warm glass and a martial-arts fist: a dojo emblem, not a ninth badge.
  poly({.78,.24,.13},{91,188,91,152,72,130,66,109,78,98,90,106,
   90,81,99,72,113,75,120,66,135,69,142,77,157,76,168,85,
   168,119,159,145,151,156,151,188})
  poly({.96,.64,.30},{91,152,115,142,157,145,151,160,151,177,91,177})
  line(113,76,113,110);line(140,78,140,110);line(90,109,113,119)
  line(113,119,156,119);line(91,177,151,177)
 elseif badge=='boulder'then
  local p={94,61,161,64,193,105,181,167,136,193,77,167,63,107}
  poly({.67,.64,.57},p)
  for i=1,#p,2 do local j=i+2;if j>#p then j=1 end
   poly(i%4==1 and {.82,.79,.68}or {.49,.51,.54},{128,126,p[i],p[i+1],p[j],p[j+1]})
  end
 elseif badge=='cascade'then
  poly({.12,.63,.98},{128,53,171,113,186,145,180,172,157,191,127,198,96,191,77,172,71,146,84,115})
  poly({.37,.85,1},{128,68,132,140,86,164,87,136})
  poly({.06,.34,.73},{132,140,174,148,166,179,127,188})
 elseif badge=='thunder'then
  local p={};for i=0,15 do local a=-math.pi/2+i*math.pi/8;local r=i%2==0 and 79 or 42;p[#p+1]=128+math.cos(a)*r;p[#p+1]=128+math.sin(a)*r end
  poly({1,.73,.08},p);circle({1,.92,.39},128,128,29)
  for i=1,#p,4 do line(128,128,p[i],p[i+1])end
 elseif badge=='rainbow'then
  local cols={{1,.28,.27},{1,.57,.13},{1,.89,.2},{.36,.79,.32},{.16,.70,.91},{.30,.39,.84},{.65,.37,.87},{.94,.39,.69}}
  for i=0,7 do local a=i*math.pi/4;local p={128,128}
   for j=-2,2 do local t=a+j*.15;p[#p+1]=128+math.cos(t)*(j==0 and 79 or 68);p[#p+1]=128+math.sin(t)*(j==0 and 79 or 68)end
   poly(cols[i+1],p)
  end;circle({1,.93,.62},128,128,25)
 elseif badge=='soul'then
  poly({.95,.35,.65},{128,94,151,69,177,72,194,94,191,121,176,145,128,194,80,145,65,120,63,94,79,73,103,68})
  line(128,94,128,192);line(69,104,128,141);line(188,104,128,141)
 elseif badge=='marsh'then
  circle({.90,.51,.08},128,128,76);circle({1,.84,.18},128,128,58);circle({1,.95,.49},128,128,31)
  for i=0,7 do local a=i*math.pi/4;line(128+31*math.cos(a),128+31*math.sin(a),128+76*math.cos(a),128+76*math.sin(a))end
 elseif badge=='volcano'then
  poly({.96,.26,.13},{128,54,144,87,166,70,163,106,192,105,177,133,192,153,163,173,128,196,90,177,65,153,82,128,65,106,95,108,93,71,113,87})
  poly({1,.70,.15},{128,93,157,131,147,161,128,178,107,160,99,132})
  poly({1,.93,.45},{128,119,141,147,128,164,116,149})
 elseif badge=='earth'then
  poly({.23,.69,.30},{169,57,177,102,167,148,137,182,89,192,70,157,77,112,112,79})
  poly({.53,.88,.33},{169,57,128,124,89,192,70,157,77,112,112,79})
  line(85,202,169,57);line(111,151,76,124);line(133,113,119,78);line(111,151,161,145)
 end
 g.pop()
end
function M.geometry(plan)
 local verts,indices={},{};local G=V.require('Voxel3D');local r=plan.rect
 -- Use the roof's GLOBAL grid, not a grid starting at the aperture edge.
 -- Shared edge vertices then bend identically under WorldCurve; coplanar
 -- glass closes the previous quarter-unit vertical gap as well.
 for z=math.floor(r[3]/32)*32,r[4]-.01,32 do for x=math.floor(r[1]/32)*32,r[2]-.01,32 do
  local a,b=math.max(x,r[1]),math.min(x+32,r[2])
  local c,d=math.max(z,r[3]),math.min(z+32,r[4]);G.pushQuad(indices,#verts/4)
  for _,p in ipairs({{a,c},{b,c},{b,d},{a,d}})do
   verts[#verts+1]={p[1],plan.h,p[2],(p[1]-r[1])/plan.size,(p[2]-r[3])/plan.size,1}
  end
 end end
 return verts,indices
end
-- Artistic, bounded projection: a full physical 160px-high sun ray would
-- leave compact Gen1 rooms at most clock angles. Drift remains tied to the
-- real sun bearing/elevation, while staying inside the authored arena.
function M.light(map,clock,weather)
 local p=M.layout(map);if not p then return nil end
 local texture=V.require('HorizonWall').gymSkylightTexture(map)
 if not texture then return nil end -- cold artwork is prepared by the horizon
 local t=clock.time();local bearing,elevation,moon=clock.bodyAt(t)
 local angle=math.rad(bearing);local drift=math.min(p.size*.17,24)*(1-math.sin(math.rad(math.max(0,elevation)))*.65)
 local size=p.size*(.78+.12*math.sin(math.rad(math.max(0,elevation))))
 local dim=weatherTransmission[weather]or 1
 local power=math.max(0,math.min(1,clock.strengthAt(t)))*dim*(moon and .09 or 1)
 return {texture=texture,area={p.cx-math.cos(angle)*drift,p.cz-math.sin(angle)*drift,size,p.h},
  color=moon and {.45,.60,1,power}or {1,.92,.82,power}}
end
function M.transmission(map,clock,weather)
 local light=M.light(map,clock,weather);if not light then return nil end
 local c=light.color;local strength=.16+math.sqrt(c[4])*1.18
 return {c[1]*strength,c[2]*strength,c[3]*strength,1}
end
function M.draw(renderer,rim,map,clock,weather,model)
 renderer.skylightTransmission(M.transmission(map,clock,weather))
 renderer.draw(rim.mesh,rim.texture,model)
 renderer.skylightTransmission(nil)
end
return M
