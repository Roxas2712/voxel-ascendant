-- Real native-map eligibility and GPU deformation. A taller wall must never
-- turn a walkable cell/warp into a raised surface or leak into another view.
local root=assert(arg[1]);local engine=assert(os.getenv('GEN1RECOMP_ROOT'))
local P=assert(loadfile(root..'/lib/Gen1CavePanoramas.lua'))()
local M=assert(loadfile(root..'/lib/Gen1CaveWalls.lua'))({require=function()return P end})
local Map=assert(loadfile(engine..'/src/world/Map.lua'))()
local maps=assert(loadfile(engine..'/red/data/generated/maps.lua'))()
local tilesets=assert(loadfile(engine..'/red/data/generated/tilesets.lua'))()
local Shape=assert(loadfile(root..'/lib/TileShape.lua'))({data=function()
 return assert(loadfile(root..'/data/voxel_heights.lua'))()
end})
local caves,rock,warps=0,0,0
for id,def in pairs(maps)do
 local map=Map.new(def,tilesets[def.tileset]);local snapshot=table.concat(def.blocks,',')
 if M.native(map)then
  caves=caves+1;local shapes=Shape.forMap(map)
  assert(shapes[2].h==16,'native support profile was raised')
  for level=0,7 do assert(M.amount(map,level)==(level>=6 and 1 or 0))end
  for y=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   for dy=0,1 do for dx=0,1 do
    local tx,ty=x*2+dx,y*2+dy
    if map:isWalkableCell(x,y) or map:isWaterCell(x,y) or map:warpAtCell(x,y)then
     assert(not M.eligible(map,tx,ty),'floor/warp eligible: '..id)
    elseif M.eligible(map,tx,ty)then rock=rock+1 end
   end end
  end end
  for _,w in ipairs(def.warps or{})do
   assert(not M.eligible(map,w.x*2,w.y*2));warps=warps+1
  end
  assert(not M.eligible(map,-1,0) and not M.eligible(map,0,def.height*4))
 else assert(M.amount(map,7)==0 and not M.eligible(map,0,0))end
 assert(snapshot==table.concat(def.blocks,','))
end
assert(caves>=19 and rock>1000 and warps>50)
assert(not M.native{id='DIGLETTS_CAVE',def={tileset='CAVERN',generation=2}})
assert(M.native{id='KA_HEVO_TUNNEL_ALL',def={tileset='CAVERN'}})
assert(not M.native{id='KA_HEVO_TUNNEL_ALL',def={tileset='CUSTOM_CAVERN'}})
assert(not M.native{id='UNKNOWN_CAVE',def={tileset='CAVERN'}})
local g=love.graphics
local shader=g.newShader('#ifdef VERTEX\n'..M.GLSL..[[
 vec4 position(mat4 transform_projection,vec4 p){
  return transform_projection*caveWallPosition(p,VertexTexCoord.xy);
 }
 #endif
 #ifdef PIXEL
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){return vec4(1.0);}
 #endif
]])
local canvas=g.newCanvas(64,64,{dpiscale=1})
local function check(material,tag,tall,expected)
 local mesh=g.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2}},
  {{0,6,0,material,tag},{8,6,0,material,tag},{8,38,0,material,tag},{0,38,0,material,tag}},'fan','static')
 g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.clear(0,0,0,0)
 g.setShader(shader);shader:send('caveWallsTall',tall);g.setColor(1,1,1,1);g.draw(mesh)
 g.setCanvas();g.pop()
 local data=canvas:newImageData();local maxY=-1
 for y=0,63 do local _,_,_,a=data:getPixel(4,y);if a>.5 then maxY=y end end
 assert(maxY==expected-1,'GPU wall/cutaway height mismatch')
 local _,_,_,a=data:getPixel(4,5);assert(a==0,'wall base moved')
 data:release();mesh:release()
end
for _,material in ipairs({-201,-206,-211,-216})do
 check(material,1024+22,0,22);check(material,1024+22,1,38)
end
for _,material in ipairs({-221,-226,-173,0})do check(material,1024+22,0,38)end
check(-201,.5,0,38) -- old/untagged assets retain their geometry
shader:release();canvas:release()
print('PASS_CAVE_CUTAWAY_GPU',caves,'caves',rock,'eligible tiles',warps,'warps protected')
