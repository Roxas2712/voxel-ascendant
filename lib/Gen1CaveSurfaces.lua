-- Dedicated rough rock and gravel for native cave terrain. Rendering only:
-- never change a shape, coordinate, map tile, animated water or collision.
local V=...
local P=V.require('Gen1CavePanoramas')
local M={}
local names={'seafoam','rock_tunnel','diglett','victory_road','cerulean','mt_moon'}
local ids={};for i,name in ipairs(names)do ids['cave_'..name]=i end
local moon={MT_MOON_1F=true,MT_MOON_B1F=true,MT_MOON_B2F=true}
local walls={};for _,tile in ipairs({2,3,18,19,12,13,28,29,16,17,49,23,4,7,40,37,38,14,15,30,31,6,39,36,1})do walls[tile]=true end
local floors={[5]=true,[41]=true,[32]=true,[33]=true,[42]=true,[35]=true}
local sources={'assets/scenery/cave_surface_rock.png','assets/scenery/cave_surface_gravel.png'}
local atlas,failed
function M.texture(prepare)
 if atlas or not prepare or failed then return atlas end
 if not (love and love.image and love.graphics and type(V.path)=='string')then return nil end
 local data,source,result
 local ok=pcall(function()
  local g=love.graphics;local limit=g.getSystemLimits().texturesize
  -- Two square surface tiles, independent of all panorama images. Limit
  -- the retained atlas to 512 x 1024 before upload even on large GPUs.
  local size=math.max(1,math.min(512,math.floor(limit/2)))
  data=love.image.newImageData(size,size*2)
  for i,path in ipairs(sources)do
   source=love.image.newImageData(V.path..'/'..path)
   local sw,sh=source:getWidth(),source:getHeight()
   assert(sw==sh and sw>0,'cave surface must be square')
   if size==sw then
    data:paste(source,0,(i-1)*size,0,0,size,size)
   else
    data:mapPixel(function(x,y)
      return source:getPixel(math.min(sw-1,math.floor((x+.5)*sw/size)),
        math.min(sh-1,math.floor((y-(i-1)*size+.5)*sh/size)))
    end,0,(i-1)*size,size,size)
   end
   source:release();source=nil
  end
  result=g.newImage(data,{mipmaps=false,linear=false})
  result:setFilter('nearest','nearest');result:setWrap('clamp','clamp')
 end)
 if source then source:release()end
 if data then data:release()end
 if not ok then if result then result:release()end;failed=true;return nil end
 atlas=result;return atlas
end
function M.profile(map)
 local mapId=map and (map.id or (map.def and map.def.id))
 local id=ids[P.materialFor(map)]
 if not id and moon[mapId] and map.def.tileset=='CAVERN'then id=6 end
 if not id then return nil end
 local wallOn=V.require('HorizonWall').enabled()
 local floorOn=V.require('Gen1InteriorFloors').setting:get()==true
 if not(wallOn or floorOn)or not M.texture(true)then return nil end
 return {id=id,walls=wallOn,floors=floorOn,map=map,markedFloor=P.extensionMaps[mapId]~=nil}
end
function M.material(p,class,tile,face,synthetic,tx,ty)
 if not p then return nil end
 if p.walls and class=='wall' and walls[tile]then return -(face=='side' and 200 or 210)-p.id end
 if face=='side' then return nil end
 -- Extension maps use complete native blocks as ice, bridge, switch and
 -- orientation landmarks. Repaint only their ordinary block-25 floor.
 if p.markedFloor then
  local def=p.map.def
  if not(tx and ty and def.blocks)or def.blocks[math.floor(ty/4)*def.width+math.floor(tx/4)+1]~=25 then return nil end
 end
 if p.floors and ((class=='ground' and floors[tile])or(class=='ledge'and(tile==5 or tile==41))
    or(class=='void'and(tile==0 or tile==35)))then return -220-p.id end
end
function M.retry()failed=nil end
M.GLSL=[[
  uniform Image caveSurfaceAtlas;
  uniform vec2 caveSurfaceSize;
  float caveMirror(float x) { return 1.0-abs(mod(x,2.0)-1.0); }
  vec4 caveSurface(float material, vec3 world) {
    float code=floor(-material+0.5);
    float family=code-200.0;
    // One square material spans four gameplay cells. World coordinates
    // preserve scale through all wall bands instead of stretching a cliff
    // panorama across a horizontal floor. Mirroring closes tile boundaries.
    vec2 uv=vec2(caveMirror((world.x+world.z)/64.0),caveMirror(world.y/64.0));
    float row=0.0;
    if(code>220.0) {
      family=code-220.0;
      row=1.0;
      uv=vec2(caveMirror(world.x/64.0),caveMirror(world.z/64.0));
    } else if(code>210.0) {
      family=code-210.0;
      uv=vec2(caveMirror(world.x/64.0),caveMirror(world.z/64.0));
    }
    vec2 halfPixel=0.5/max(caveSurfaceSize,vec2(1.0));
    uv.x=mix(halfPixel.x,1.0-halfPixel.x,uv.x);
    uv.y=row*0.5+mix(halfPixel.y,0.5-halfPixel.y,uv.y);
    vec4 p=Texel(caveSurfaceAtlas,uv);
    // Mineral hues keep each cave identifiable while retaining the texture's
    // full grit/fissure contrast; no flat-colour wash or polished highlights.
    vec3 tint=vec3(0.77,0.96,1.09);
    if(family==2.0) tint=vec3(0.93,0.87,0.77);
    if(family==3.0) tint=vec3(1.15,0.85,0.60);
    if(family==4.0) tint=vec3(0.85,0.85,0.97);
    if(family==5.0) tint=vec3(0.82,0.99,1.04);
    if(family==6.0) tint=vec3(0.91,0.85,1.08);
    p.rgb=clamp((p.rgb-vec3(0.40))*1.12+vec3(0.40),0.0,1.0)*tint;
    return vec4(p.rgb,1.0);
  }
]]
return M
