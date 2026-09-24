-- Presentation only. KASC supplies discovered access points from its current
-- quest state. No collision edits, progress writes or inferred unlocks here.
local V=...
local M={}
local cache={}
local colors={REGICE={.38,.82,1},REGIROCK={1,.65,.26},REGISTEEL={.70,.88,1}}
local angles={south=0,down=0,north=math.pi,up=math.pi,
 east=math.pi/2,right=math.pi/2,west=-math.pi/2,left=-math.pi/2}
function M.rows(state)
  if not(state and state.map)then return {}end
  local game=require('src.core.Game')
  local now=love.timer.getTime()
  if cache.map==state.map and cache.save==game.save and now<cache.untilTime then return cache.rows end
  local handle=V.mod:find('kanto_ascendant')
  local api=handle and handle.exports and handle.exports.worldAccessPresentation
  local rows=api and api.forMap(game,state.map.id)or{}
  cache={map=state.map,save=game.save,untilTime=now+.2,rows=rows}
  return rows
end
local registered=false
local function models()
  local P=V.require('VoxelItems')
  if registered then return P end
  local c=P.decorColors
  local function model(id,boxes)P.models[id]={directBoxes=true,boxes=boxes}end
  model('access_buoys',{
    {-9,0,-2,5,1.5,4,c.silver},{4,0,-2,5,1.5,4,c.silver},
    {-8,1.5,-1.5,3,2,3,c.clay},{5,1.5,-1.5,3,2,3,c.clay},
    {-7.5,3.5,-1,2,2,2,c.silver},{5.5,3.5,-1,2,2,2,c.silver}})
  model('access_buoy_glow',{{-7.5,5.5,-1,2,1.5,2,c.paperWindow},{5.5,5.5,-1,2,1.5,2,c.paperWindow}})
  model('access_arrow',{{-1,.1,-4,2,.12,4,c.paperWindow},
    {-3,.1,0,6,.12,1,c.paperWindow},{-2,.1,1,4,.12,1,c.paperWindow},
    {-1,.1,2,2,.12,1,c.paperWindow}})
  local boxes={}
  -- 3x5 bitmap EXIT, embedded in a flat ground mesh (no texture asset).
  local glyphs={E={'111','100','110','100','111'},X={'101','101','010','101','101'},
    I={'111','010','010','010','111'},T={'111','010','010','010','010'}}
  for i,ch in ipairs({'E','X','I','T'})do for y,line in ipairs(glyphs[ch])do
    for x=1,3 do if line:sub(x,x)=='1'then boxes[#boxes+1]={-8+(i-1)*4+x-1,.1,y-7,1,.12,1,c.paperWindow}end end
  end end
  -- Arrow below the lettering; its tip points out of the chamber.
  for _,b in ipairs({{-1,.1,0,2,.12,5,c.paperWindow},{-3,.1,2,6,.12,1,c.paperWindow},{-2,.1,3,4,.12,1,c.paperWindow}})do boxes[#boxes+1]=b end
  model('access_exit',boxes)
  registered=true
  return P
end
local function matrix(map,x,y,facing)
  local Mat=V.require('Mat4')
  local h=V.require('VoxelScene').groundAt(map,math.floor(x),math.floor(y))
  return Mat.mul(Mat.translate(x*16+8,h+.3,y*16+8),Mat.rotateY(angles[facing]or 0))
end
function M.water(map,x,y)
  return map.isWaterCell and (not map.inBounds or map:inBounds(x,y)) and map:isWaterCell(x,y) or false
end
function M.draw(state)
  local rows=M.rows(state);if #rows==0 then return end
  local P=models();local R=V.require('Voxel3D')
  local function draw(kind,mat)local mesh,tex=P.resolveKind(kind);if mesh then R.draw(mesh,tex,mat,0)end end
  local function mark(x,y,facing,kind,lit,theme)
    local mat=matrix(state.map,x,y,facing)
    local water=M.water(state.map,x,y)
    local color=colors[theme]or{.55,.85,.70}
    if water then
      mat[8]=mat[8]+.25*math.sin(love.timer.getTime()*1.6+x*.3)
      draw('access_buoys',mat)
      R.flatten(color,1);draw('access_buoy_glow',mat)
    else
      R.flatten(lit and color or{.53,.59,.55},lit and .8 or 1)
      draw(kind=='exit'and'access_exit'or'access_arrow',mat)
    end
    R.flatten(nil,0)
  end
  for _,row in ipairs(rows)do
    -- An approach arrow points toward the scientist instead of being
    -- hidden underneath his feet; the interaction itself is unchanged.
    local y=row.kind=='researcher'and row.y+1 or row.y
    mark(row.x,y,row.facing,row.kind,row.lit,row.theme)
    for i,p in ipairs(row.path or{})do
      local x,z=p.x or p[1],p.y or p[2]
      if i%2==1 then
        local n=row.path[i+1]or{x=row.x,y=row.y};local nx,nz=n.x or n[1],n.y or n[2]
        local facing=nx>x and'east'or nx<x and'west'or nz<z and'north'or'south'
        mark(x,z,facing,'trail',row.lit,row.theme)
      end
    end
  end
end
function M.appendLights(state,sources)
  for _,row in ipairs(M.rows(state))do if row.lit then
    local mat=matrix(state.map,row.x,row.y,row.facing)
    local water=M.water(state.map,row.x,row.y)
    sources[#sources+1]={x=mat[4],y=mat[8]+(water and 6 or 2),z=mat[12],normal={0,-1,0},radius=water and 22 or 14,
      power=water and .75 or .25,color=colors[row.theme]or{.46,1,.73},owner={},kind='access'}
  end end
end
return M
