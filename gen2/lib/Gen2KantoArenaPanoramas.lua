-- Native Crystal Kanto interior panoramas. Retained, opaque murals live on
-- the existing outer room shell; no floor cells, puzzles, NPCs or warps move.
-- Cerulean's aquarium and Celadon's greenhouse keep their bespoke owners.
local P={WALL_WIDTH=256,GROUND_PERIOD=128}
local specs={
 PEWTER_GYM={tileset='TILESET_TOWER',width=5,height=7,material='kanto_quarry'},
 VERMILION_GYM={tileset='TILESET_GAME_CORNER',width=5,height=9,material='kanto_electric'},
 FUCHSIA_GYM={tileset='TILESET_LAB',width=5,height=9,material='kanto_poison'},
 SAFFRON_GYM={tileset='TILESET_UNDERGROUND',width=10,height=9,material='kanto_psychic'},
 VIRIDIAN_GYM={tileset='TILESET_TRAIN_STATION',width=5,height=9,material='kanto_champion'},
 FIGHTING_DOJO={tileset='TILESET_TRAIN_STATION',width=5,height=6,material='kanto_training'},
 SEAFOAM_GYM={tileset='TILESET_CAVE',width=5,height=4,material='kanto_ember',cave=true},
}
local materials={};for _,s in pairs(specs)do materials[s.material]=s end
function P.specFor(map)
 local d=map and map.def;local s=d and specs[map.id or d.id]
 if not(s and d.generation==2 and d.tileset==s.tileset
  and d.width==s.width and d.height==s.height and d.environment=='INDOOR'
  and d.outdoor~=true and next(d.connections or{})==nil)then return nil end
 return s
end
function P.profileFor(map)
 local s=P.specFor(map);return s and not s.cave and s or nil
end
function P.materialFor(map)local s=P.specFor(map);return s and s.material end
function P.hasMaterial(name)return materials[name]~=nil end
function P.architectural(name)local s=materials[name];return s and not s.cave or false end
function P.caveMaterial(name)return name=='kanto_ember' end

local palette={
 kanto_quarry={{.17,.19,.18},{.43,.39,.31},{.72,.65,.48}},
 kanto_electric={{.14,.21,.26},{.27,.38,.43},{.87,.70,.24}},
 kanto_poison={{.17,.13,.24},{.32,.24,.39},{.61,.48,.63}},
 kanto_psychic={{.12,.12,.23},{.30,.25,.44},{.67,.54,.75}},
 kanto_champion={{.23,.25,.24},{.45,.46,.39},{.78,.67,.39}},
 kanto_training={{.22,.15,.10},{.55,.44,.29},{.81,.76,.59}},
 kanto_ember={{.19,.13,.10},{.43,.29,.17},{.70,.47,.24}},
}

-- Graphics is injected: production uses LÖVE, pure QA records these exact
-- draw commands. No image generation or allocation takes place per frame.
function P.draw(g,name,W,H,wall)
 local c=palette[name];if not c then return false end
 local function rect(color,x,y,w,h)
  if w<=0 or h<=0 then return end
  g.setColor(color[1],color[2],color[3],1)
  g.rectangle('fill',math.floor(x),math.floor(y),math.ceil(w),math.ceil(h))
 end
 local function line(color,x0,y0,x1,y1,width)
  local steps=math.max(1,math.ceil(math.max(math.abs(x1-x0),math.abs(y1-y0))/2))
  for i=0,steps do local t=i/steps
   rect(color,x0+(x1-x0)*t,y0+(y1-y0)*t,width or 2,width or 2)
  end
 end
 local function ring(color,x,y,rx,ry)
  for i=0,39 do
   local a,b=i*math.pi/20,(i+1)*math.pi/20
   line(color,x+math.cos(a)*rx,y+math.sin(a)*ry,x+math.cos(b)*rx,y+math.sin(b)*ry,2)
  end
 end
 rect(c[1],0,0,W,H)
 if not wall then
  -- This texture belongs only to the shell apron/ceiling, never native floor.
  if name=='kanto_ember' then
   for y=0,H-1,2 do for x=0,W-1,2 do
    local a,b=x*math.pi*2/W,y*math.pi*2/H
    local v=.28+.035*math.sin(a*3+b*2)+.028*math.sin(a*5-b*3)
    rect({v*1.42,v,v*.64},x,y,2,2)
   end end
   return true
  end
  for y=0,H-1,16 do for x=0,W-1,32 do
   rect(c[2],x+1,y+1,30,14)
   rect(c[1],x+2,y+12,28,2)
  end end
  return true
 end
 if name=='kanto_ember' then
  -- Warm, irregular rock faces with distant mineral seams; no city windows
  -- and no invented walkable lava floor in Blaine's small natural cavern.
  for y=0,H-1,2 do for x=0,W-1,2 do
   local strata=math.sin(x*.061+y*.073)+math.sin(x*.127-y*.033)
   local grain=((x*13+y*7)%19)/19
   local v=.28+strata*.045+grain*.05
   rect({v*1.42,v,v*.64},x,y,2,2)
  end end
  for _,start in ipairs({47,173})do
   local x=start
   for y=12,H-16,4 do
    local nextX=start+math.floor(math.sin(y*.10)*8+math.sin(y*.033)*15)
    line({.26,.11,.05},x-2,y,nextX-2,y+4,6)
    line({.82,.38,.10},x,y,nextX,y+4,2)
    if y%12==0 then line({.99,.66,.22},x,y,nextX,y+2,1)end
    x=nextX
   end
  end
  return true
 end

 -- A continuous high mural above the native-height room border, with a
 -- solid plinth below. All panels are opaque, so invisible-wall and warp
 -- puzzles receive no new sightline or projected floor-light clue.
 rect(c[2],0,12,W,H-36)
 rect(c[1],0,H-30,W,30)
 if name=='kanto_quarry' then
  for layer=0,4 do for x=0,W-1,4 do
   local y=22+layer*17+math.floor(math.sin(x*.034+layer)*5)
   rect({.33+layer*.035,.31+layer*.029,.26+layer*.020},x,y,4,17)
   rect({.58,.51,.37},x,y,4,2)
  end end
  for _,x in ipairs({60,190})do
   rect({.20,.23,.21},x-26,37,54,66)
   rect({.40,.39,.31},x-22,41,46,58)
   local px,py=x+2,69
   for i=0,83 do
    local a=i*.18;local r=1+i*.19
    local nx,ny=x+math.cos(a)*r,69+math.sin(a)*r
    line({.78,.70,.48},px,py,nx,ny,2);px,py=nx,ny
   end
  end
 elseif name=='kanto_electric' then
  rect({.13,.23,.32},12,22,W-24,82)
  -- Distant port gantries within the industrial mural, behind the frame.
  for _,x in ipairs({28,91,177})do
   rect({.27,.39,.46},x,43,5,61)
   line({.36,.48,.52},x,43,x+40,31,3)
   line({.25,.36,.43},x,62,x+40,31,2)
   line({.39,.48,.49},x+35,34,x+35,77,1)
  end
  for _,x in ipairs({8,W-16})do
   rect({.40,.48,.48},x,18,8,H-50)
   for y=24,H-42,12 do rect(c[3],x-2,y,12,3)end
  end
  for y=H-25,H-12,6 do rect(c[3],0,y,W,2)end
 elseif name=='kanto_poison' then
  for x=14,W-10,13 do
   local h=42+(x*17)%48
   line({.22,.32,.31},x,H-34,x+5,H-34-h,3)
   for j=1,4 do
    local y=H-34-j*h/5
    line({.37,.45,.39},x+2,y,x-8,y-8,2)
    line({.28,.39,.33},x+2,y-4,x+13,y-13,2)
   end
  end
  for _,x in ipairs({4,124,248})do
   rect({.17,.13,.24},x,10,5,H-34)
   rect({.55,.43,.59},x+1,10,1,H-34)
  end
  for y=32,110,26 do rect({.39,.29,.48},0,y,W,2)end
 elseif name=='kanto_psychic' then
  rect({.15,.16,.29},10,20,W-20,H-56)
  for i=1,39 do
   local x=12+(i*47)%(W-24);local y=24+(i*29)%(H-72)
   rect(i%4==0 and {.80,.70,.47} or {.49,.46,.65},x,y,2,2)
  end
  for _,x in ipairs({64,192})do
   for layer=0,2 do
    local rx=42-layer*9;local ry=35-layer*7
    for step=0,30 do
     local a=math.pi+step*math.pi/30
     rect({.51-layer*.08,.43-layer*.055,.64-layer*.07},x+math.cos(a)*rx,71+math.sin(a)*ry,3,3)
    end
    rect({.40,.34,.54},x-rx,71,3,38)
    rect({.40,.34,.54},x+rx,71,3,38)
   end
  end
 elseif name=='kanto_champion' then
  -- Blue's mixed-type team: a gallery of six colours, no Giovanni emblem.
  local flags={{.70,.28,.20},{.26,.48,.68},{.35,.58,.31},
   {.74,.64,.24},{.54,.35,.62},{.61,.59,.48}}
  for i,color in ipairs(flags)do
   local x=18+(i-1)*39
   rect(c[1],x-3,23,29,82)
   rect(color,x,26,23,72)
   ring(c[3],x+10,58,7,7)
   rect(c[3],x+9,45,3,27)
   rect(c[3],x-1,24,25,3)
  end
 elseif name=='kanto_training' then
  rect({.77,.73,.57},0,16,W,H-46)
  -- Restrained ink landscape on closed paper screens, not false doorways.
  for x=0,W-1,2 do
   local y=74+math.floor(math.sin(x*.031)*12+math.sin(x*.078)*7)
   rect({.49,.51,.41},x,y,2,H-34-y)
   local y2=89+math.floor(math.sin(x*.044+1)*7)
   rect({.32,.39,.32},x,y2,2,H-34-y2)
  end
  for _,x in ipairs({0,64,128,192,252})do
   rect({.25,.17,.10},x,0,5,H)
   rect({.49,.34,.18},x+1,0,2,H)
  end
  for _,y in ipairs({18,45,72,99})do rect({.48,.39,.24},0,y,W,2)end
 end
 for _,y in ipairs({0,9,H-34,H-8})do
  rect(c[1],0,y,W,6);rect(c[3],0,y+1,W,1)
 end
 return true
end
P.specs=specs
return P
