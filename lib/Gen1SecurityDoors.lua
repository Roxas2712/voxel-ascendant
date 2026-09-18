-- Native card-key/lift gate visuals. Only audited room/block combinations
-- are accepted; flags, collision and opening transactions remain game-owned.
local M={}
M.specs={
 -- Native story6.lua Mansion switch block coordinates. Open/closed state
 -- comes exclusively from the live block, including inverted switch gates.
 POKEMON_MANSION_1F={15,14,{{12,6,45},{8,3,45},{10,8,45},{13,13,45}}},
 POKEMON_MANSION_2F={15,14,{{4,2,95},{9,4,84},{3,11,95}}},
 POKEMON_MANSION_3F={15,9,{{7,2,95},{7,5,95}}},
 POKEMON_MANSION_B1F={15,14,{{13,8,45},{6,11,95},{4,3,95},{8,8,84}}},
 SILPH_CO_2F={15,9,{{2,2,84},{2,5,84}}},
 SILPH_CO_3F={15,9,{{4,4,95},{8,4,95}}},
 SILPH_CO_4F={15,9,{{2,6,84},{6,4,84}}},
 SILPH_CO_5F={15,9,{{3,2,95},{3,6,95},{7,5,95}}},
 SILPH_CO_6F={13,9,{{2,6,95}}},
 SILPH_CO_7F={13,9,{{5,3,84},{10,2,84},{10,6,84}}},
 SILPH_CO_8F={13,9,{{3,4,95}}},
 SILPH_CO_9F={13,9,{{1,4,95},{9,2,84},{9,5,84},{5,6,95}}},
 SILPH_CO_10F={8,9,{{5,4,84}}},
 SILPH_CO_11F={9,9,{{3,6,32}},'INTERIOR'},
 ROCKET_HIDEOUT_B1F={15,14,{{12,8,84}}},
 ROCKET_HIDEOUT_B4F={15,12,{{12,5,45}}},
}
local masks={
 [84]={8,8,8,8,24,24,24,24,1,1,1,1,1,1,1,1},
 [95]={1,1,36,37,1,1,36,37,1,1,36,37,1,1,36,37},
 [45]={1,1,1,1,1,1,1,1,8,8,8,8,24,24,24,24},
 [32]={31,31,31,31,31,31,31,31,93,93,93,93,94,94,94,94},
}
function M.forMap(map)
 local out={};local d=map and map.def;local spec=M.specs[map and map.id]
 if not spec or not d or d.generation==2 or d.width~=spec[1] or d.height~=spec[2]
  or d.tileset~=(spec[4]or'FACILITY') or not map.tileset or not map.tileset.blocks then return out end
 for _,slot in ipairs(spec[3])do
  local bx,by,closedBlock=unpack(slot)
  local n=d.blocks[by*d.width+bx+1];local opened=spec[4] and 3 or 14
  local pixels=map.tileset.blocks[(n or -1)+1];local valid=pixels~=nil
  if n==closedBlock or n==opened then
   for i=1,16 do
    if pixels and pixels[i]~=(n==closedBlock and masks[closedBlock][i] or spec[4] and 31 or 1)then valid=false end
   end
   if valid then
    local vertical=closedBlock==95;local offset=(closedBlock==45 or closedBlock==32)and 16 or 0
    out[#out+1]={vertical=vertical,at=vertical and bx*32+16 or by*32+offset,
     from=vertical and by*32 or bx*32,upto=(vertical and by*32 or bx*32)+32,
     closed=n==closedBlock,tx=bx*4+(vertical and 2 or 0),ty=by*4+offset/8,
     w=vertical and 2 or 4,h=vertical and 4 or 2}
   end
  end
 end
 return out
end
function M.addPanels(map,out)
 for _,d in ipairs(M.forMap(map))do
  for _,side in ipairs(d.vertical and {'east','west'}or{'south','north'})do
   local at=d.at+((side=='west' or side=='north')and 16 or 0);local target
   for _,p in ipairs(out)do
    if p.edge==side and p.at==at and p.from<=d.from and p.upto>=d.upto then target=p;break end
   end
   if not target then
    target={edge=side,at=at,from=d.from-8,upto=d.upto+8,openings={}}
    out[#out+1]=target
   end
   local kept={}
   for _,opening in ipairs(target.openings)do
    if opening.upto<=d.from or opening.from>=d.upto then kept[#kept+1]=opening end
   end
   kept[#kept+1]={from=d.from,upto=d.upto,height=24,open=not d.closed,material='room_security_door'}
   target.openings=kept
  end
 end
end
return M
