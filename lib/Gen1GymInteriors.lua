-- Red/Blue/Yellow gym interiors, authored independently of Gen2's Kanto
-- families. Dimensions are native Gen1 block dimensions, not pixel guesses.
-- Only retained enclosure textures are painted here; gameplay tiles, quiz
-- doors, hidden barriers, teleport pads and spin arrows keep their owners.
local M = {}
M.profiles = {
  PEWTER_GYM={tileset='GYM',width=5,height=7,material='quarry_arena',theme='rock_gallery'},
  CERULEAN_GYM={tileset='GYM',width=5,height=7,material='water_arena',theme='swimming_hall'},
  VERMILION_GYM={tileset='GYM',width=5,height=9,material='electric_arena',theme='electrical_training'},
  CELADON_GYM={tileset='GYM',width=5,height=9,material='garden_arena',theme='botanical_gym'},
  FUCHSIA_GYM={tileset='GYM',width=5,height=9,material='poison_arena',theme='ninja_dojo'},
  SAFFRON_GYM={tileset='FACILITY',width=10,height=9,material='psychic_arena',theme='psychic_chambers'},
  CINNABAR_GYM={tileset='FACILITY',width=10,height=9,material='fire_arena',theme='quiz_laboratory'},
  VIRIDIAN_GYM={tileset='GYM',width=10,height=9,material='earth_arena',theme='giovanni_earth'},
}
local colors = {
 quarry_arena={{.49,.48,.42},{.66,.64,.55},{.28,.29,.27},{.77,.70,.47}},
 water_arena={{.78,.87,.87},{.91,.95,.93},{.22,.42,.50},{.24,.63,.74}},
 electric_arena={{.43,.48,.48},{.62,.65,.61},{.20,.25,.27},{.78,.67,.30}},
 garden_arena={{.61,.65,.47},{.77,.79,.62},{.25,.36,.23},{.50,.32,.21}},
 poison_arena={{.53,.47,.49},{.70,.63,.64},{.27,.22,.30},{.59,.41,.57}},
 psychic_arena={{.55,.53,.68},{.75,.72,.84},{.29,.28,.43},{.65,.55,.77}},
 fire_arena={{.66,.66,.61},{.83,.82,.75},{.32,.33,.32},{.68,.31,.20}},
 earth_arena={{.59,.52,.40},{.76,.67,.51},{.32,.28,.22},{.62,.40,.22}},
}
function M.supports(material) return colors[material] ~= nil end
function M.paint(g, material, W, H, wall)
 local c=assert(colors[material], 'unreviewed Gen1 gym material')
 local function r(color,x,y,w,h)
  local x1,y1=math.min(W,math.ceil(x+w)),math.min(H,math.ceil(y+h))
  x,y=math.max(0,math.floor(x)),math.max(0,math.floor(y))
  if x1>x and y1>y then g.setColor(color[1],color[2],color[3],1);g.rectangle('fill',x,y,x1-x,y1-y)end
 end
 local function line(color,x,y,xx,yy,thickness)
  local n=math.max(1,math.ceil(math.max(math.abs(xx-x),math.abs(yy-y))))
  for i=0,n do local t=i/n;r(color,x+(xx-x)*t,y+(yy-y)*t,thickness or 1,thickness or 1)end
 end
 r(c[1],0,0,W,H)
 if not wall then
  -- Quiet structural cap. This texture never covers a playable floor tile.
  for y=0,H-1,32 do for x=0,W-1,32 do
   r(c[2],x+1,y+1,30,1);r(c[3],x+31,y,1,32)
  end end
  return
 end
 -- A shared scale ties upper scenery to Gen1's 16px cells. Sparse motifs
 -- leave the actual trainers and puzzle surfaces as the visual foreground.
 for y=0,H-1,16 do
  r(c[2],0,y+1,W,1)
  for x=(y%32==0 and 0 or 16),W-1,32 do r(c[3],x,y,1,16)end
 end
 r(c[3],0,H-40,W,40);r(c[1],0,H-37,W,28)
 for _,y in ipairs({8,H-42,H-10})do r(c[3],0,y,W,4);r(c[4],0,y+1,W,2)end
 if material=='quarry_arena' then
  -- Brock: a compact rock training gallery, with strata and fossil plaques.
  for _,cx in ipairs({32,96})do
   r(c[3],cx-21,30,42,65);r(c[1],cx-18,33,36,59)
   for layer=0,4 do
    for x=cx-17,cx+16 do r(c[2],x,40+layer*10+math.floor(math.sin(x*.12+layer)*2),1,2)end
   end
   local px,py=cx,64
   for i=1,60 do local a=i*.24;local radius=i*.19
    local x,y=cx+math.cos(a)*radius,64+math.sin(a)*radius
    line(c[4],px,py,x,y,1);px,py=x,y
   end
  end
 elseif material=='water_arena' then
  -- Misty's narrow Gen1 pool hall: tiled service walls and wave frieze.
  r(c[2],0,22,W,H-66)
  for y=24,H-44,8 do for x=0,W-1,8 do r(c[1],x,y,8,1);r(c[1],x,y,1,8)end end
  for x=0,W-1 do
   local y=H-29+math.floor(math.sin(x*math.pi/24)*3)
   r(c[4],x,y,1,2);r(c[2],x,y+5,1,1)
  end
  for _,x in ipairs({16,80})do r(c[3],x,36,30,24);r(c[4],x+2,38,26,20);r(c[2],x+4,40,22,1)end
 elseif material=='electric_arena' then
  -- Surge's switches stay solely on the native bins/barrier. These closed
  -- wall cabinets have identical neutral faces in every puzzle state.
  for _,x in ipairs({12,76})do
   r(c[3],x,28,40,75);r(c[1],x+3,31,34,69)
   for y=38,64,5 do r(c[3],x+8,y,24,2)end
   r(c[2],x+8,80,24,13);r(c[3],x+11,84,18,1)
  end
  for _,y in ipairs({18,H-27})do r(c[3],0,y,W,5);r(c[4],0,y+1,W,2)end
 elseif material=='garden_arena' then
  -- Erika's greenhouse/dojo, sized around Gen1's native cuttable hedges.
  for _,x in ipairs({8,72})do
   r(c[3],x,25,48,81);r({.35,.46,.29},x+3,28,42,75)
   for y=32,100,12 do
    for xx=x+4,x+43,12 do
     line(c[4],xx,y,xx+10,y+10,1);line(c[4],xx+10,y,xx,y+10,1)
    end
   end
   for i=0,8 do
    local xx=x+8+(i*17)%32;local yy=34+i*7
    r({.27,.42,.25},xx,yy,9,5);r({.56,.66,.38},xx+1,yy,5,1)
    if i%3==0 then r({.77,.60,.66},xx+3,yy+2,3,3)end
   end
  end
 elseif material=='poison_arena' then
  -- Koga, not Janine: opaque timber screens, no silhouettes or maze hints.
  for _,x in ipairs({8,72})do
   r(c[3],x,26,48,81);r({.67,.61,.58},x+3,29,42,75)
   for xx=x+12,x+44,12 do r(c[1],xx,29,2,75)end
   for y=42,98,14 do r(c[1],x+3,y,42,2)end
   line(c[3],x+20,96,x+28,49,2)
   line(c[3],x+25,67,x+12,53,2)
   r(c[4],x+24,46,8,5);r(c[4],x+9,50,7,5)
  end
 elseif material=='psychic_arena' then
  -- Sabrina's nine rooms share opaque panels. No invented doorways or
  -- direction-dependent symbols that could suggest a teleport destination.
  for _,cx in ipairs({32,96})do
   r(c[3],cx-23,27,46,79);r(c[1],cx-20,30,40,73)
   for radius=10,22,6 do
    line(c[4],cx,65-radius,cx+radius,65,2)
    line(c[4],cx+radius,65,cx,65+radius,2)
    line(c[4],cx,65+radius,cx-radius,65,2)
    line(c[4],cx-radius,65,cx,65-radius,2)
   end
   r(c[2],cx-2,63,4,4)
  end
 elseif material=='fire_arena' then
  -- Blaine's Gen1 quiz laboratory: cream facility panels, modest red service
  -- stripe and closed instrument cabinets. No Seafoam cave or furnace hall.
  r(c[2],0,24,W,H-68);r(c[4],0,48,W,7)
  for _,x in ipairs({12,76})do
   r(c[3],x,64,40,40);r(c[1],x+3,67,34,34)
   r({.25,.37,.32},x+7,71,26,17)
   for yy=75,83,4 do r({.57,.65,.47},x+11,yy,18,1)end
   r(c[3],x+8,93,24,2)
  end
 elseif material=='earth_arena' then
  -- Giovanni's large Gen1 spinner maze, never Blue's compact Gen2 hall.
  for _,cx in ipairs({32,96})do
   r(c[3],cx-22,27,44,78);r(c[1],cx-19,30,38,72)
   for y=38,92,9 do
    for x=cx-17,cx+17 do r(c[4],x,y+math.floor(math.sin(x*.09+y*.04)*2),1,2)end
   end
   line(c[2],cx-12,84,cx-5,52,2);line(c[2],cx-5,52,cx+11,83,2)
   line(c[2],cx+11,83,cx-12,84,2)
  end
 end
 -- Continuous edge framing joins repeated bays cleanly, with no floor props.
 for _,x in ipairs({0,W-4})do r(c[3],x,0,4,H);r(c[2],x+1,2,1,H-4)end
end
return M
