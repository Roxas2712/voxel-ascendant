-- Shared classification for native mansion/store stair warps. Tile numbers
-- alone are insufficient: a real warp and the complete 16px drawing agree.
local M={}
function M.classForWarp(map,warp)
 local d=map and map.def
 if not d or d.generation==2 or (d.tileset~='MANSION' and d.tileset~='LOBBY')then return nil end
 local blocks=map.tileset and map.tileset.blocks
 if not blocks then return nil end
 local function tile(x,y)
  if x<0 or y<0 or x>=d.width*4 or y>=d.height*4 then return nil end
  local block=blocks[(d.blocks[math.floor(y/4)*d.width+math.floor(x/4)+1]or -1)+1]
  return block and block[y%4*4+x%4+1]
 end
 local x,y=warp.x*2,warp.y*2
 local a,b,c,e=tile(x,y),tile(x+1,y),tile(x,y+1),tile(x+1,y+1)
 if a==12 and b==13 and c==28 and e==29 then return 'stair_e' end
 if a==10 and b==11 and c==26 and e==27 then return 'stair_down_w' end
end
return M
