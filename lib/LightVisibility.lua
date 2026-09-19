-- Cache geometry visibility in a small world-space volume, rather than
-- tracing eight building boxes and twelve cave cells for every screen pixel.
-- Light colour/flicker, diffuse response and water glints stay per pixel.
local V=...
local M={SIZE=32,LAYERS=8,STEP=8}
local atlas,shader,key,lastFrame
local function signature(frame)
 local parts={tostring(frame.wall and frame.wall.texture)}
 local function n(x)parts[#parts+1]=string.format('%.4f',x or 0)end
 for _,l in ipairs(frame.lights)do
  n(l.x);n(l.y);n(l.z);n(l.radius);n(l.owner.index)
 end
 parts[#parts+1]='portals'
 for _,p in ipairs(frame.portals or {})do
  for _,x in ipairs(p.position)do n(x)end
  for _,x in ipairs(p.normal)do n(x)end
 end
 if #(frame.portals or {})>0 then
  for i=1,3 do parts[#parts+1]=string.format('%.3f',frame.portalSky.direction[i])end
  n(frame.map.def.width);n(frame.map.def.height)
 end
 parts[#parts+1]='blockers'
 for _,b in ipairs(frame.blockers)do for _,x in ipairs(b.lo)do n(x)end;for _,x in ipairs(b.hi)do n(x)end end
 return table.concat(parts,',')
end
function M.prepare(frame,lights,blank)
 local count=#frame.lights+#(frame.portals or {})
 if count==0 then return blank end
 if atlas and lastFrame==frame then return atlas end
 local nextKey=signature(frame)
 if atlas and key==nextKey then lastFrame=frame;return atlas end
 local g=love.graphics
 if not shader then
  shader=g.newShader(lights.glsl(true)..[[
   uniform vec4 visibilityArea;
   uniform vec4 visibilityOrigin; // emitter xyz, owning blocker
   uniform vec3 visibilityNormal;
   uniform vec3 visibilitySun;
   uniform float visibilityPortal;
   uniform float visibilityBase;
   vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
    vec2 cell=mod(sc,32.0)/32.0;
    float layer=floor(sc.y/32.0);
    vec3 world=vec3(visibilityArea.x+cell.x*visibilityArea.z,
      visibilityBase+layer*8.0,visibilityArea.y+cell.y*visibilityArea.w);
    vec3 origin=visibilityOrigin.xyz;
    if(visibilityPortal>.5) {
      float facing=dot(visibilitySun,visibilityNormal);
      if(abs(facing)<.015)return vec4(0,0,0,1);
      float t=dot(origin-world,visibilityNormal)/facing;
      if(t<0.0||t>400.0)return vec4(0,0,0,1);
      origin=world+visibilitySun*t+visibilityNormal*.4;
    }
    float lit=localVisible(origin,world,visibilityOrigin.w);
    return vec4(lit,lit,lit,1);
   }
  ]])
 end
 if not atlas then
  atlas=g.newCanvas((lights.MAX_LIGHTS+lights.MAX_PORTALS)*M.SIZE,M.SIZE*M.LAYERS,{dpiscale=1})
  atlas:setFilter('linear','linear')
 end
 g.push('all')
 local ok,err=pcall(function()
 g.origin();g.setScissor();g.setCanvas(atlas);g.setDepthMode()
 g.setMeshCullMode('none');g.setBlendMode('replace');g.setShader(shader);g.setColor(1,1,1,1);g.clear(1,1,1,1)
 shader:send('localWallSize',frame.wall and frame.wall.size or {0,0})
 shader:send('localWallMask',frame.wall and frame.wall.texture or blank)
 shader:send('localBlockCount',#frame.blockers)
 for i,b in ipairs(frame.blockers)do shader:send('localLo'..(i-1),b.lo);shader:send('localHi'..(i-1),b.hi)end
 shader:send('visibilitySun',frame.portalSky and {unpack(frame.portalSky.direction,1,3)} or {0,1,0})
 for i,l in ipairs(frame.lights)do
  shader:send('visibilityPortal',0);shader:send('visibilityOrigin',{l.x,l.y,l.z,l.owner.index or 0})
  shader:send('visibilityNormal',{0,1,0});shader:send('visibilityBase',l.y-24)
  shader:send('visibilityArea',{l.x-l.radius,l.z-l.radius,l.radius*2,l.radius*2})
  g.rectangle('fill',(i-1)*M.SIZE,0,M.SIZE,M.SIZE*M.LAYERS)
 end
 for i,p in ipairs(frame.portals or {})do
  shader:send('visibilityPortal',1);shader:send('visibilityOrigin',{p.position[1],p.position[2],p.position[3],0})
  shader:send('visibilityNormal',p.normal);shader:send('visibilityBase',p.position[2]-24)
  shader:send('visibilityArea',{0,0,frame.map.def.width*32,frame.map.def.height*32})
  g.rectangle('fill',(lights.MAX_LIGHTS+i-1)*M.SIZE,0,M.SIZE,M.SIZE*M.LAYERS)
 end
 end)
 g.pop()
 if not ok then M.invalidate();error(err,0) end
 key=nextKey;lastFrame=frame
 M.rebuilds=(M.rebuilds or 0)+1
 return atlas
end
function M.invalidate()
 if atlas then atlas:release()end
 if shader then shader:release()end
 atlas,shader,key,lastFrame=nil,nil,nil,nil
end
return M
