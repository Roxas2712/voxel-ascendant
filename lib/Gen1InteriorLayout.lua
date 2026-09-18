-- Decorative walls follow native room boundaries; positions are pixels.
-- This module only reads layouts. Collision, doors and actors keep their owner.
local V = ...
local M = {}
local function add(out, edge, from, upto, at)
  if upto > from then
    local p={edge=edge,from=from,upto=upto,at=at,openings={}}
    out[#out+1]=p;return p
  end
end
local function perimeter(d,out)
  add(out,'north',0,d.width*32,0);add(out,'south',0,d.width*32,d.height*32)
  add(out,'west',0,d.height*32,0);add(out,'east',0,d.height*32,d.width*32)
end
local function blockFootprint(map, out)
  local d=map.def
  local function occupied(x,y)
    return x>=0 and y>=0 and x<d.width and y<d.height
      and d.blocks[y*d.width+x+1]~=d.borderBlock
  end
  for _,edge in ipairs({'north','south','west','east'})do
    local horizontal=edge=='north' or edge=='south'
    local across,along=horizontal and d.height or d.width,horizontal and d.width or d.height
    for at=0,across do
      local start
      for n=0,along do
        local x,y=horizontal and n or at,horizontal and at or n
        local inside,outside
        if edge=='north' then inside,outside=occupied(x,y),occupied(x,y-1)
        elseif edge=='south' then inside,outside=occupied(x,y-1),occupied(x,y)
        elseif edge=='west' then inside,outside=occupied(x,y),occupied(x-1,y)
        else inside,outside=occupied(x-1,y),occupied(x,y)end
        local exposed=n<along and inside and not outside
        if exposed and not start then start=n end
        if not exposed and start then add(out,edge,start*32,n*32,at*32).boundary=true;start=nil end
      end
    end
  end
end
local function tile(map,x,y)
  local d,t=map.def,map.tileset
  local b=d.blocks[math.floor(y/4)*d.width+math.floor(x/4)+1]
  local a=t.blocks[b+1]
  return a[y%4*4+x%4+1]
end
-- Reuse the authored stair/ladder pins instead of treating every warp as
-- a doorway. Inspect the complete cell; some stairs share door collision IDs.
local function verticalWarp(map,warp)
 if V and V.require and V.require('Gen1StairCells').classForWarp(map,warp) then return true end
 if not (V and V.data and map.tileset and map.def.blocks) then return false end
 local spec=V.data("voxel_heights");local groups=spec and spec.tilesets and spec.tilesets[map.def.tileset]
 if not groups then return false end
 for class,ids in pairs(groups)do
  if type(class)=="string" and (class:match("^stair") or class:find("ladder",1,true)) and type(ids)=="table" then
   for _,id in ipairs(ids)do for dy=0,1 do for dx=0,1 do
    if tile(map,warp.x*2+dx,warp.y*2+dy)==id then return true end
   end end end
  end
 end
 return false
end
M.verticalWarp=verticalWarp
local function opposing(out,panels,edge,offset)
  for _,p in ipairs(panels)do
    out[#out+1]=p
    local q=add(out,edge,p.from,p.upto,p.at+(p.thickness or offset))
    for _,door in ipairs(p.openings)do
      q.openings[#q.openings+1]={from=door.from,upto=door.upto,height=door.height,open=door.open,material=door.material}
    end
    -- Close the ends of the wall's thickness, not the adjacent passage.
    -- The two long faces alone leave a black slit when viewed obliquely.
    local lo,hi=math.min(p.at,q.at),math.max(p.at,q.at)
    local horizontal=p.edge=='north'or p.edge=='south'
    p.wallThickness=hi-lo
    local first=add(out,horizontal and'east'or'south',lo,hi,p.from)
    local last=add(out,horizontal and'west'or'north',lo,hi,p.upto)
    -- End caps belong to this partition, not to an independent wall. If
    -- both long faces are cut away, their narrow ends must disappear too.
    if first then first.endcap=true;first.cutawayFaces={p,q} end
    if last then last.endcap=true;last.cutawayFaces={p,q} end
  end
end
local function joinRun(out,edge,from,upto,at)
  local last=out[#out];local gap=last and from-last.upto
  -- A one/two-cell passage has a lintel. Wider gaps separate rooms.
  if last and last.at==at and gap>0 and gap<=32 then
    last.openings[#last.openings+1]={from=last.upto,upto=from,open=true}
    last.upto=upto
  else add(out,edge,from,upto,at) end
end
local function facility(map,out)
  local d=map.def
  perimeter(d,out)
  -- FACILITY's horizontal wall courses ($2a/$57) and their caps.
  -- Equipment, shelving, rubble and balustrades are separate native objects.
  local horizontal={}
  for y=1,d.height*4-2 do
    local start,core=nil,false
    for x=0,d.width*4 do
      local t=x<d.width*4 and tile(map,x,y)
      local band=t==0x2a or t==0x57;local cap=t==0x2d or t==0x2e
      if band or cap then start=start or x;core=core or band
      elseif start then
        if core then joinRun(horizontal,'south',start*8,x*8,y*8)end
        start=nil;core=false
      end
    end
  end
  opposing(out,horizontal,'north',16)
  -- The paired $2b/$2c vertical wall faces are 16px wide. Both sides
  -- receive a complete wall; camera cutaway chooses the visible room side.
  local vertical={}
  for x=1,d.width*4-3 do
    local start
    for y=0,d.height*4 do
      local band=y<d.height*4 and tile(map,x,y)==0x2b and tile(map,x+1,y)==0x2c
      if band then start=start or y
      elseif start then
        if y-start>=2 then joinRun(vertical,'east',start*8,y*8,x*8)end
        start=nil
      end
    end
  end
  opposing(out,vertical,'west',16)
end
local function silphOffice(map,out)
  local d=map.def
  perimeter(d,out)
  -- The top office uses INTERIOR instead of FACILITY. Exact wall courses
  -- keep its presidential desk, monitors, chairs and stair art separate.
  local horizontal={}
  for y=1,d.height*4-1 do
    local start,core=nil,false
    for x=0,d.width*4 do
      local t=x<d.width*4 and tile(map,x,y)
      local band=t==87 and tile(map,x,y-1)~=87;local cap=t==45 or t==46
      if band or cap then start=start or x;core=core or band
      elseif start then
        if core then
          joinRun(horizontal,'south',start*8,x*8,y*8)
          -- The president's north partition has two plan-view rows and
          -- two face rows. Put its room-facing panel at the actual front,
          -- rather than leaving the old white course in front of it.
          if y+3<d.height*4 then for at=start,x-1 do
            if tile(map,at,y+2)==52 and tile(map,at,y+3)==68 then
              horizontal[#horizontal].thickness=32;break
            end
          end end
        end
        start=nil;core=false
      end
    end
  end
  opposing(out,horizontal,'north',16)
  local vertical={}
  for x=0,d.width*4-2 do
    local start
    for y=0,d.height*4 do
      local band=y<d.height*4 and tile(map,x,y)==89 and tile(map,x+1,y)==90
      if band then start=start or y
      elseif start then
        if y-start>=2 then joinRun(vertical,'east',start*8,y*8,x*8)end
        start=nil
      end
    end
  end
  opposing(out,vertical,'west',16)
end
local function mansion(map,out)
  blockFootprint(map,out)
  local d=map.def
  -- Only the audited Mansion side-wall pairs, including their junctions.
  -- Stairs, desk tops and display cabinets use other tiles and stay separate.
  local pairsByLeft={[74]=75,[72]=73,[88]=89,[90]=91,[92]=93}
  local vertical={}
  for x=0,d.width*4-2 do
    local start
    for y=0,d.height*4 do
      local left=y<d.height*4 and tile(map,x,y)
      local wall=left and pairsByLeft[left] and tile(map,x+1,y)==pairsByLeft[left]
      if wall then start=start or y
      elseif start then
        if y-start>=2 then joinRun(vertical,'east',start*8,y*8,x*8)end
        start=nil
      end
    end
  end
  opposing(out,vertical,'west',16)
  local horizontal={}
  local baseCourse={[30]=true,[22]=true,[23]=true,[92]=true,[93]=true}
  for y=0,d.height*4-2 do
    local start
    for x=0,d.width*4 do
      local top=x<d.width*4 and tile(map,x,y)
      local wall=(top==76 or top==77) and baseCourse[tile(map,x,y+1)]
      if wall then start=start or x
      elseif start then
        if x-start>=2 then
          -- $16/$17 is a blocked decorative wall panel, not a doorway.
          add(horizontal,'south',start*8,x*8,y*8)
        end
        start=nil
      end
    end
  end
  opposing(out,horizontal,'north',16)
  -- All three native floors enter the room around the eastern end of the
  -- front wall: the one-cell gap between the vertical partition and that
  -- front wall. Fit a lintel to that verified floor cell, never to $16/$17.
  for _,side in ipairs(vertical)do
    for _,front in ipairs(horizontal)do
      if front.at==side.upto+16 and front.upto==side.at+16 then
        local x,y=side.at/8,side.upto/8
        local walkable={};for _,id in ipairs(map.tileset.walkable or{})do walkable[id]=true end
        if walkable[tile(map,x,y+1)] and walkable[tile(map,x+1,y+1)] then
          local portal={};local p=add(portal,'east',side.upto,front.at,side.at)
          p.openings={{from=side.upto,upto=front.at,open=true}}
          opposing(out,portal,'west',16)
        end
      end
    end
  end
end
local function underground(map,out)
  -- These maps contain wide black padding outside the corridor. The actual
  -- wall is the $06/$09 north band, $02 south edge and $16/$17 side rims.
  -- Fit to their inner faces rather than the padded map rectangle.
  local d=map.def;local west,east,north,south
  for y=0,d.height*4-1 do for x=0,d.width*4-1 do
    local t=tile(map,x,y)
    if t==0x16 then west=(x+1)*8
    elseif t==0x17 then east=x*8
    elseif t==0x09 then north=(y+1)*8
    elseif t==0x02 then south=y*8 end
  end end
  if not (west and east and north and south and west<east and north<south)then
    return perimeter(d,out)
  end
  add(out,'north',west,east,north);add(out,'south',west,east,south)
  add(out,'west',north,south,west);add(out,'east',north,south,east)
end
function M.panelsFor(map, profile)
  local d=map.def;local out={};local domesticInset=false
  if map.id=='LANCES_ROOM' or map.id=='CINNABAR_LAB' then blockFootprint(map,out)
  elseif tostring(map.id):match('^CELADON_MANSION_[123]F$') and map.tileset and map.tileset.blocks then mansion(map,out)
  elseif map.id=='SILPH_CO_11F' and d.tileset=='INTERIOR' and map.tileset and map.tileset.blocks then silphOffice(map,out)
  elseif d.tileset=='UNDERGROUND' and map.tileset and map.tileset.blocks then underground(map,out)
  elseif d.tileset=='FACILITY' and map.tileset and map.tileset.blocks then facility(map,out)
  else perimeter(d,out) end
  V.require('Gen1SecurityDoors').addPanels(map,out)
  for _,p in ipairs(out)do
    local horizontal=p.edge=='north' or p.edge=='south'
    for _,warp in ipairs(d.warps or{})do
      local along=(horizontal and warp.x or warp.y)*16
      local across=(horizontal and warp.y or warp.x)*16
      local row=p.at-((p.edge=='south' or p.edge=='east')and 16 or 0)
      if not p.endcap and (not tostring(map.id):match('^CELADON_MANSION_[123]F$') or p.boundary) and across==row and along>=p.from and along<p.upto and not verticalWarp(map,warp) then
        local breach=p.edge=='north' and V.require('Gen1BreachExterior').opening(map,warp)
        p.openings[#p.openings+1]={from=along,upto=math.min(along+16,p.upto),
          height=breach and 28 or nil,open=breach or nil,breach=breach or nil}
      end
    end
    -- These wall tiles contain a readable native sign, not just a blank
    -- decorative panel. Mount it on the corridor-facing side only. Native
    -- sign events still own the text and A-button interaction; PC events
    -- elsewhere on 3F must not turn into wall plaques.
    if tostring(map.id):match('^CELADON_MANSION_[123]F$') and p.edge=='north' and not p.endcap then
      for _,sign in ipairs(d.signs or{})do
        local x,y=sign.x*2,sign.y*2
        if p.at==(sign.y+1)*16 and sign.x*16>=p.from and (sign.x+1)*16<=p.upto
          and tile(map,x,y+1)==22 and tile(map,x+1,y+1)==23 then
          p.signs=p.signs or{}
          p.signs[#p.signs+1]={from=sign.x*16+1,upto=(sign.x+1)*16-1,
            bottom=17,top=24,text=sign.text}
        end
      end
    end
    for _,door in ipairs(p.openings)do door.height=door.height or math.min(24,profile.shellHeight-16) end
    table.sort(p.openings,function(a,b)return a.from<b.from end)
    local merged={}
    for _,door in ipairs(p.openings)do
      local last=merged[#merged]
      if last and last.height==door.height and last.open==door.open and last.material==door.material and door.from<=last.upto then
        last.upto=math.max(last.upto,door.upto)
      else merged[#merged+1]=door end
    end
    p.openings=merged
    if (profile.theme=="home" or profile.theme=="coastal_home" or profile.theme=="traditional_home")
        and p.edge=="north" and p.at==0 and #p.openings==0 then
      p.at=16;domesticInset=true
    end
  end
  if domesticInset then
    for _,p in ipairs(out)do
      if (p.edge=="west" or p.edge=="east") and p.from==0 then p.from=16 end
    end
  end
  return out
end
return M
