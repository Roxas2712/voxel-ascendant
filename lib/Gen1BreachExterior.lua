-- Read-only terrain preview behind Cerulean's story breach. Reciprocal native
-- warps select the real yard; no second world, actors, events or collision map.
local B={}
local colors={{.66,.82,.89},{.77,.88,.91},{.38,.65,.29},{.43,.70,.34},
 {.71,.66,.50},{.79,.74,.59},{.19,.45,.63},{.28,.57,.73},
 {.28,.20,.11},{.16,.35,.17},{.25,.47,.22},{.36,.57,.28},
 {.49,.40,.29},{.65,.54,.38},{.82,.74,.56},{.55,.29,.18}}
function B.opening(map,warp)
 local d=map and map.def
 return d and (not d.generation or d.generation==1) and map.id=='CERULEAN_TRASHED_HOUSE'
  and d.tileset=='HOUSE' and d.width==4 and d.height==4
  and warp.x==3 and warp.y==0 and warp.destWarp==8 and warp.destMap=='LAST_MAP'
end
function B.source(map,data)
 local d=map and map.def;local warp=d and d.warps and d.warps[3]
 if not (warp and B.opening(map,warp))then return nil end
 if not data then local ok,G=pcall(require,'src.core.Game');data=ok and G and G.data end
 local city=data and data.maps and data.maps.CERULEAN_CITY
 local ts=data and data.tilesets and data.tilesets.OVERWORLD
 local back=city and city.warps and city.warps[8]
 if not(city and city.width==20 and city.height==18 and city.tileset=='OVERWORLD'
  and ts and ts.blocks and back and back.x==27 and back.y==9
  and back.destMap==map.id and back.destWarp==3)then return nil end
 local house=data.tilesets.HOUSE
 if not(house and house.blocks)then return nil end
 for dy,row in ipairs({{35,74},{84,85}})do for dx,wanted in ipairs(row)do
  local tx,ty=5+dx,dy-1
  local block=d.blocks[math.floor(ty/4)*d.width+math.floor(tx/4)+1]
  local tiles=block and house.blocks[block+1]
  if not(tiles and tiles[ty%4*4+tx%4+1]==wanted)then return nil end
 end end
 local result={mapId='CERULEAN_CITY',warp=8,x=back.x,y=back.y,cells={}}
 local function tile(x,y)
  local block=city.blocks[math.floor(y/4)*city.width+math.floor(x/4)+1]
  local tiles=block and ts.blocks[block+1];return tiles and tiles[y%4*4+x%4+1]
 end
 for y=back.y-8,back.y-1 do for x=back.x-3,back.x+3 do
  local top,foot=tile(x*2,y*2),tile(x*2,y*2+1)
  local kind=(top==42 or top==64)and 'tree' or foot==20 and 'water'
   or foot==44 and 'grass' or foot==91 and 'path' or foot==55 and 'ledge'
  if not kind then return nil end -- changed topology keeps the native fallback
  result.cells[#result.cells+1]={x=x,y=y,kind=kind}
 end end
 return result
end
function B.paint(g,w,h)
 for i,c in ipairs(colors)do
  g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',0,(i-1)*h/#colors,w,h/#colors+1)
 end
 g.setColor(1,1,1,1)
end
function B.geometry(map,panel,door,height,data)
 local source=B.source(map,data);if not source or not door.breach then return nil end
 local g={family='room_breach_exterior',vertices={},indices={},interiorPanel=panel,
  doorFrame=true,source=source}
 local function quad(corners,color,shade)
  local base=#g.vertices;local u,v=.5,(color-.5)/#colors
  for _,p in ipairs(corners)do g.vertices[#g.vertices+1]={p[1],p[2],p[3],u,v,shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do g.indices[#g.indices+1]=base+i end
 end
 local function box(x,y,z,w,h,d,c)
  quad({{x,y,z},{x+w,y,z},{x+w,y+h,z},{x,y+h,z}},c,.75)
  quad({{x+w,y,z+d},{x,y,z+d},{x,y+h,z+d},{x+w,y+h,z+d}},c,.9)
  quad({{x,y,z+d},{x,y,z},{x,y+h,z},{x,y+h,z+d}},c,.8)
  quad({{x+w,y,z},{x+w,y,z+d},{x+w,y+h,z+d},{x+w,y+h,z}},c,.95)
  quad({{x,y+h,z},{x+w,y+h,z},{x+w,y+h,z+d},{x,y+h,z+d}},c)
 end
 local x0,x1,z0=door.from-48,door.upto+48,-128
 -- Sky closes the far and side edges of the small preview, beneath the room
 -- rim. It shares the ordinary world time tint instead of a glowing canvas.
 for _,s in ipairs({{x0,z0,x1,z0},{x0,0,x0,z0},{x1,z0,x1,0}})do
  for y=0,height-1,4 do
   quad({{s[1],y,s[2]},{s[3],y,s[4]},{s[3],math.min(height,y+4),s[4]},
    {s[1],math.min(height,y+4),s[2]}},y<height/2 and 2 or 1)
  end
 end
 local terrain=g
 g={family='room_breach_roof',kind='ground',vertices={},indices={},interiorPanel=panel,doorFrame=true}
 terrain.roof=g
 quad({{x0,height,z0},{x1,height,z0},{x1,height,0},{x0,height,0}},1)
 g=terrain
 for _,cell in ipairs(source.cells)do
  local x,z=door.from+(cell.x-source.x)*16,(cell.y-source.y)*16
  local phase=(cell.x*3+cell.y*7)%2
  local color=cell.kind=='water' and 7+phase or cell.kind=='path' and 5+phase or 3+phase
  quad({{x,0,z},{x+16,0,z},{x+16,0,z+16},{x,0,z+16}},color)
  -- Small surface variations follow the source cell without changing heights.
  for k=0,2 do
   local a,b=x+2+(k*5+phase)%11,z+2+(k*3+phase)%11
   quad({{a,.02,b},{a+2,.02,b},{a+2,.02,b+1},{a,.02,b+1}},color+(phase==0 and 1 or -1))
  end
  if cell.kind=='tree' then
   local h=24+(cell.x+cell.y)%3*3
   box(x+6,0,z+6,4,10,4,9)
   box(x+1,8,z+1,14,7,14,10);box(x+2,15,z+2,12,6,12,11)
   box(x+4,21,z+4,8,h-21,8,12)
  elseif cell.kind=='ledge' then box(x,0,z,16,4,3,13)end
 end
 local result=g
 g={family='room_breach_frame',vertices={},indices={},interiorPanel=panel,doorFrame=true}
 result.frame=g
 -- Jagged exposed masonry stays outside the complete native 16px walk lane.
 for y=0,door.height-1,4 do
  local w=y%8==0 and 3 or 2
  box(door.from-w,y,-2,w,4,4,y%8==0 and 14 or 15)
  box(door.upto,y,-2,5-w,4,4,y%8==0 and 15 or 14)
 end
 for x=door.from-2,door.upto,4 do
  box(x,door.height,-2,4,2+(x%3),4,14)
 end
 -- A few fallen bricks flank the threshold, never inside its walk lane.
 box(door.from-5,0,1,3,1,3,16);box(door.upto+1,0,2,3,2,2,16)
 return result
end
-- Indoor rooms use noon lighting. Only the terrain beyond the opening gets
-- the outdoor clock tint, and every draw restores the caller's colour.
function B.draw(renderer,rim,model,clock,gfx)
 local r,g,b,a=gfx.getColor();local tint=clock.tint(true)
 gfx.setColor(tint[1],tint[2],tint[3],a)
 local ok,result=pcall(renderer.draw,rim.mesh,rim.texture,model)
 gfx.setColor(r,g,b,a)
 if not ok then error(result,0)end
 return result
end
return B
