-- Native guarded tower timber: fixed cutaway collar plus animated upper shaft.
local V=...
local P={}
local art={
 {45,46,46,47},{61,62,62,63},{60,62,1,44},
 {77,78,78,79},{77,78,78,79},{93,94,94,95},
}
-- Four tile columns by six rows, exactly cells x=9..10,y=6..8.
local signature={
 [1]="0000000000000000000000000000000000000000000000000000000000000000",
 [2]="2222222211111111333333332221222221222112222222222112222222222221",
 [44]="0010222200101111001010100010010100100000001000000010000000100000",
 [45]="0111111101000000010000000100000001000000010000000100000001000000",
 [46]="1111111100000000000000000000000000000000000000000000000000000000",
 [47]="1110222200101111001033330010222200102112001022220010222200102221",
 [60]="0100000001000000010000000100000001000000010000000100000001000000",
 [61]="0100000001000000010000000100000001000000010000000100000001000000",
 [62]="0000000000000000000000000000000000000000000000000000000000000000",
 [63]="0010222200101111001033330010222200102112001022220010222200102221",
 [77]="0111111101111121012111210121111101111111011112110111121101111111",
 [78]="1111111111111111111111111111111111111111111111111111111111111111",
 [79]="1110000011200000112000001110000011100000121000001210000011100000",
 [93]="0101111100111010010101010010001000010100001000100000000000000000",
 [94]="1101111110111010010101011000100001010101101000100000000000000000",
 [95]="1100000010100000010000001010000001000000000000000000000000000000",
}
local animated={[93]=true,[95]=true,[77]=true,[79]=true,[60]=true,[44]=true,[61]=true,[63]=true,[45]=true,[47]=true}
local function key(x,y)return(y+64)*4096+x+64 end
function P.matches(map)
 local d=map and map.def;local ts=map and map.tileset
 local sprout=d and tonumber((map.id or''):match('^SPROUT_TOWER_(%d)F$'))
 local tin=d and tonumber((map.id or''):match('^TIN_TOWER_(%d)F$'))
 if not(d and ts and ((sprout and sprout>=1 and sprout<=3)or(tin and tin>=1 and tin<=9))
  and d.id==map.id and d.generation==2 and d.tileset=='TILESET_TOWER'
  and d.width==10 and d.height==(sprout and 8 or 9) and d.environment=='DUNGEON' and d.outdoor~=true
  and next(d.connections or{})==nil and ts.tilesPerRow==16 and ts.tilePalettes)then return false end
 for t in pairs(signature)do if ts.tilePalettes[t+1]~=6 then return false end end
 local count=0;local seen={}
 for _,f in ipairs((ts.anim or{}).frames or{})do
  if f.func=='AnimateTowerPillarTile'then
   if not animated[f.tile]or seen[f.tile]or f.frames~=5
    or f.sheet~=('assets/generated/tilesets/anim/tower_%02x.png'):format(f.tile)then return false end
   count=count+1;seen[f.tile]=true
  elseif f.func~='StandingTileFrame'and f.func~='WaitTileAnimation'and f.func~='DoneTileAnimation'then return false end
 end
 if count~=10 then return false end
 for y=6,8 do for x=9,10 do
  if map:cellCollision(x,y)~=7 or map:isWarpTileCell(x,y)then return false end
  for _,w in ipairs(d.warps or{})do if w.x==x and w.y==y then return false end end
 end end
 for y=0,5 do for x=0,3 do if map:tileAt(18+x,12+y)~=art[y+1][x+1]then return false end end end
 return true
end
local function valid(atlas,budget)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return false end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return false end
 for t,s in pairs(signature)do for y=0,7 do
  if budget and budget.tick then budget.tick()end
  for x=0,7 do
  local r,g,b,a=atlas:getPixel(t%16*8+x,math.floor(t/16)*8+y)
  local v=tonumber(s:sub(y*8+x+1,y*8+x+1))/3
  if math.abs(r-v)>.001 or math.abs(g-v)>.001 or math.abs(b-v)>.001 or math.abs(a-1)>.001 then return false end
 end end end
 return true
end

-- Expand only the premerged surface rows: bounded hundreds of faces, never
-- a 32*48*160 voxel scan during map entry. Each build owns its arrays because
-- the mesher consumes them after upload. Module data is immutable and shared.
function P.templates(budget)
 local rows=V.require("Gen2TowerPillarGeometry")
 local function decode(input)
  local out={}
  for _,row in ipairs(input)do
   if budget and budget.tick then budget.tick()end
   local q={u=row[13],v=row[14],shade=row[15]}
   for i=1,4 do local k=(i-1)*3;q[i]={row[k+1],row[k+2],row[k+3]}end
   out[#out+1]=q
  end
  return out
 end
 return decode(rows.base),decode(rows.upper)
end
local offsets={-2,-1,0,1,2,1,0,-1}
function P.modelMatrix(timer)
 local shear=offsets[math.floor(tonumber(timer)or 0)%8+1]/128
 -- y=32 is anchored inside the fixed collar, y=160 moves at most two px.
 return {1,shear,0,160-32*shear, 0,1,0,0, 0,0,1,120, 0,0,0,1}
end
function P.build(S,map,atlas,budget)
 if not(P.matches(map)and valid(atlas,budget)and S and S.skip and S.ground
  and S.shapeAt and S.tileAt and S.objectQuads and S.roundStamps)then return 0 end
 for y=0,5 do for x=0,3 do
  local k=key(18+x,12+y);local sh=S.shapeAt[k];local tile=art[y+1][x+1]
  if S.skip[k]or S.ground[k]~=nil or S.tileAt[k]~=tile or not sh then return 0 end
  if tile==1 then if sh.class~='void'or not sh.authored then return 0 end
  elseif tile==44 then if sh.class~='wall'or sh.authored then return 0 end
  elseif sh.class~='cliff'or not sh.authored or sh.h~=32 then return 0 end
 end end
 if S.towerPillar then return 0 end
 local base,upper=P.templates(budget)
 -- Commit only after both CPU arrays are complete. The fixed base provides
 -- a valid visible fallback even if the optional upper GPU upload fails.
 S.roundStamps[#S.roundStamps+1]={quads=base,mx=160,my=0,mz=120,r=24}
 S.towerPillar={quads=upper}
 for y=0,5 do for x=0,3 do local k=key(18+x,12+y);S.skip[k]=true;S.ground[k]=2 end end
 return 1
end
return P

