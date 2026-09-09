-- Crystal's summit is a roof viewed from above, not a room surrounded by
-- tall walls. Keep its native walkway at zero; pitch the blocked roof away
-- below it. Exact source-layout guard, no map/collision/event writes.
local Roof={}
local roofShape={class='roof',art='top',h=0,flat=false,authored=true}
local function key(x,y)return (y+64)*4096+x+64 end
local west={0x16,0x24,0x16,0x06}
local east={0x25,0x35,0x34,0x35}
local function expected(x,y)
  if x<4 or x>=32 then return 0x01,false end
  if x<16 then return west[(x-4)%4+1],true end
  if x>=20 then return east[(x-20)%4+1],true end
  if y<9 or y>=28 then return 0x50+x%2,true end
  if y==9 then return 0x52+x%2,true end
  if y>=26 and x>=18 then return 0x0e+(x-18)+(y-26)*16,false end
  return 0x02,false
end
function Roof.matches(map)
  if not map or map.id~='TIN_TOWER_ROOF' or not map.def
      or map.def.tileset~='TILESET_TOWER' or map.def.width~=10 or map.def.height~=9 then return false end
  local warps=map.def.warps
  local w=warps and #warps==1 and warps[1]
  if not w or w.x~=9 or w.y~=13 or w.destMap~='TIN_TOWER_9F' or w.destWarp~=4 then return false end
  for y=0,35 do for x=0,39 do
    local tile,roof=expected(x,y)
    if map:tileAt(x,y)~=tile then return false end
    if roof and map:isWalkableCell(math.floor(x/2),math.floor(y/2)) then return false end
  end end
  return true
end
local function height(x,z)
  local across=math.max(128-x,x-160,0)/3
  local along=math.max(80-z,z-224,0)/2
  return -math.min(32,math.max(across,along))
end
function Roof.build(S,map)
  if not Roof.matches(map)then return false end
  local ts=map.tileset;local aw,ah=ts.imageWidth or 128,ts.imageHeight or 128
  local row=ts.tilesPerRow or 16
  local function face(c,tile,shade)
    local u,v=tile%row*8,math.floor(tile/row)*8
    c.uv={{(u+.02)/aw,(v+.02)/ah},{(u+7.98)/aw,(v+.02)/ah},
      {(u+7.98)/aw,(v+7.98)/ah},{(u+.02)/aw,(v+7.98)/ah}}
    c.shade=shade;S.objectQuads[#S.objectQuads+1]=c
  end
  local count=0
  for y=0,35 do for x=4,31 do
    local tile,roof=expected(x,y)
    if roof then
      local x0,x1,z0,z1=x*8,x*8+8,y*8,y*8+8
      face({{x0,height(x0,z0),z0},{x1,height(x1,z0),z0},
        {x1,height(x1,z1),z1},{x0,height(x0,z1),z1}},tile,1)
      local k=key(x,y)
      S.skip[k]=true;S.ground[k]=nil;S.runs[k]=nil;S.shapeAt[k]=roofShape
      count=count+1
    end
  end end
  -- Close the eaves with native ridge boarding. All outer corners sit -32;
  -- two 8px courses avoid stretching the grain. The underside is opaque void
  -- art, not an open mesh edge visible from a low orbit.
  for z=0,280,8 do for y=-48,-40,8 do
    face({{32,y,z},{32,y,z+8},{32,y+8,z+8},{32,y+8,z}},0x50,.72)
    face({{256,y,z+8},{256,y,z},{256,y+8,z},{256,y+8,z+8}},0x51,.82)
  end end
  for x=32,248,8 do for y=-48,-40,8 do
    face({{x+8,y,0},{x,y,0},{x,y+8,0},{x+8,y+8,0}},0x50,.68)
    face({{x,y,288},{x+8,y,288},{x+8,y+8,288},{x,y+8,288}},0x51,.9)
  end end
  face({{32,-48,288},{256,-48,288},{256,-48,0},{32,-48,0}},0x01,.3)
  return count
end
return Roof
