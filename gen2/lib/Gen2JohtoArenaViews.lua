-- Small, retained exterior silhouettes for Johto's existing gym windows.
-- Decorative regional views, not reconstructions or extra playable maps.
local A={WIDTH=256,HEIGHT=128}
local maps={
 VIOLET_GYM={5,8,'TILESET_ELITE_FOUR_ROOM','town','VIOLET_CITY'},
 AZALEA_GYM={5,8,'TILESET_ELITE_FOUR_ROOM','forest','AZALEA_TOWN'},
 GOLDENROD_GYM={10,9,'TILESET_ELITE_FOUR_ROOM','city','GOLDENROD_CITY'},
 CIANWOOD_GYM={5,9,'TILESET_TOWER','coast','CIANWOOD_CITY'},
 OLIVINE_GYM={5,8,'TILESET_CHAMPIONS_ROOM','coast','OLIVINE_CITY'},
 MAHOGANY_GYM={5,9,'TILESET_ELITE_FOUR_ROOM','ridge','MAHOGANY_TOWN'},
 BLACKTHORN_GYM_1F={5,9,'TILESET_ELITE_FOUR_ROOM','ridge','BLACKTHORN_CITY'},
 BLACKTHORN_GYM_2F={5,9,'TILESET_ELITE_FOUR_ROOM','ridge','BLACKTHORN_CITY'},
}
local kinds={town=true,forest=true,city=true,coast=true,ridge=true}
function A.kind(family)
 local name=type(family)=='string' and family:match('^johto_view_(%a+)$')
 return name and kinds[name] and name or nil
end
function A.geometry(map,view,belt)
 local d=map and map.def;local s=map and maps[map.id]
 if not(s and view and view.city==s[5] and d and d.generation==2
  and d.width==s[1] and d.height==s[2] and d.tileset==s[3]
  and d.environment=='INDOOR' and d.outdoor~=true and not next(d.connections or{}))then return nil end
 local w,h=d.width*32,d.height*32
 -- Separate from the 32px wall apron. The lower picture edge is hidden by
 -- the intact wall beneath the sill; the transparent top exposes real sky.
 local distance=math.max(96,(belt or 32)+32)
 local top=view.sill+88
 local x0,z0,x1,z1=-distance,-distance,w+distance,h+distance
 local result={family='johto_view_'..s[4],vertices={},indices={},top=top,distance=distance}
 for _,line in ipairs({{x0,z0,x1,z0},{x1,z0,x1,z1},{x1,z1,x0,z1},{x0,z1,x0,z0}})do
  local span=math.abs(line[3]-line[1])+math.abs(line[4]-line[2])
  local n=#result.vertices
  local uv={{0,1},{span/A.WIDTH,1},{span/A.WIDTH,0},{0,0}}
  for i,p in ipairs({{line[1],top-A.HEIGHT,line[2]},{line[3],top-A.HEIGHT,line[4]},
    {line[3],top,line[4]},{line[1],top,line[2]}})do
   result.vertices[#result.vertices+1]={p[1],p[2],p[3],uv[i][1],uv[i][2],1}
  end
  for _,i in ipairs({1,2,3,1,3,4})do result.indices[#result.indices+1]=n+i end
 end
 return result
end

-- Original code-native pixel scenery; five shared 256x128 RGBA Canvases at
-- most (640 KiB base texels). No per-room bitmap, shader, actor or animation.
function A.paint(g,family)
 local kind=A.kind(family);if not kind then return false end
 local W,H=A.WIDTH,A.HEIGHT
 g.clear(0,0,0,0)
 local function rect(c,x,y,w,h)
  x,y,w,h=math.floor(x/2)*2,math.floor(y/2)*2,math.ceil(w/2)*2,math.ceil(h/2)*2
  if w<=0 or h<=0 then return end
  g.setColor(c[1],c[2],c[3],1)
  -- Bake edge-crossing shapes on both ends of the repeating strip.
  x=x%W
  while w>0 do
   local span=math.min(w,W-x);g.rectangle('fill',x,y,span,h)
   w=w-span;x=0
  end
 end
 local pineDark,pineLight={.16,.28,.25},{.29,.43,.31}
 local function pine(x,y,r)
  rect({.25,.24,.19},x-2,y+r*2,4,20)
  for row=0,r*2,2 do rect(row%6==0 and pineLight or pineDark,x-row*.45,y+row,row*.9+4,2)end
 end
 local function crown(x,y,r,c)
  for dy=-r,r,2 do
   local dx=math.sqrt(math.max(0,r*r-dy*dy))
   rect(c,x-dx,y+dy,dx*2+2,2)
  end
 end
 local function house(x,y,w,roof,wall)
  rect(wall,x,y+16,w,56)
  for row=0,16,2 do
   rect(row%6==0 and {.49,.45,.36}or roof,x+w*.22-row*.45,y+row,w*.56+row*.9,2)
  end
  rect(roof,x-4,y+16,w+8,4)
  for wx=x+6,x+w-8,12 do
   rect({.17,.26,.29},wx,y+28,6,12)
   rect({.72,.76,.60},wx+2,y+30,2,8)
  end
 end
 if kind=='forest' then
  rect({.17,.30,.25},0,54,W,H-54)
  for x=-16,W+24,28 do
   local row=math.floor((x+16)/28)%3
   pine(x+10,10+row*6,18)
   crown(x,44+row*6,20,{.25,.42,.32})
   crown(x-6,40+row*6,14,{.37,.53,.34})
  end
  rect({.13,.24,.21},0,100,W,28)
 elseif kind=='ridge' then
  rect({.29,.40,.43},0,64,W,64)
  for x=-32,W+48,72 do
   local summit=10+(math.floor((x+32)/72)%3)*8
   for row=0,80,2 do
    rect(row<14 and {.65,.73,.72}or {.38,.48,.51},x-row*.7,summit+row,row*1.4+6,2)
    rect({.26,.37,.43},x+4,summit+row,row*.7+2,2)
   end
  end
  for x=-12,W+24,24 do pine(x,74+((x+12)%48)/4,14)end
 elseif kind=='coast' then
  -- A level sea horizon, not green land filling the ocean-facing opening.
  rect({.35,.57,.67},0,42,W,H-42)
  for y=48,H-1,8 do
   for x=-8,W+16,32 do rect({.58,.74,.76},x+(y%16),y,18,2)end
  end
  -- Low distant headland; a lighthouse belongs only to this coastal strip.
  for y=24,42,2 do rect({.31,.45,.42},190-(y-24)*2,y,32+(y-24)*3,2)end
  rect({.81,.79,.64},210,12,10,26);rect({.35,.41,.42},208,8,14,6)
  rect({.76,.69,.36},212,10,6,4)
  rect({.36,.29,.24},28,100,68,6)
  rect({.27,.26,.23},38,96,4,32);rect({.27,.26,.23},80,96,4,32)
 else
  rect({.25,.36,.28},0,70,W,58)
  local wall=kind=='city'and{.62,.57,.44}or{.63,.57,.41}
  local roof=kind=='city'and{.31,.37,.43}or{.30,.39,.34}
  for x=-20,W+40,64 do
   local y=20+((math.floor((x+20)/64)%3)*10)
   house(x,y,48,roof,wall)
   if kind=='city' then house(x+30,y+18,28,{.40,.33,.31},{.66,.62,.50})
   else pine(x+48,y+20,14)end
  end
 end
 return true
end
return A
