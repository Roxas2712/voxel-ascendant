-- Original-pixel human arm rig. Caller owns scene/option admission.
-- Shared source composites; weak per-actor mesh state prevents pose aliasing.
local HumanRig={}
-- Share only bit-identical Lua vertex attributes; UV/shade seams stay split.
local function compactVertices(vertices,indices)
 local unique,lookup,remap={},{},{}
 for i,v in ipairs(vertices)do
  local key=string.format('%.17g,%.17g,%.17g,%.17g,%.17g,%.17g',v[1],v[2],v[3],v[4],v[5],v[6])
  local index=lookup[key]
  if not index then index=#unique+1;unique[index]=v;lookup[key]=index end
  remap[i]=index
 end
 for i,index in ipairs(indices)do indices[i]=remap[index]end
 return unique
end
-- A role can have distinct original artworks; sharing the role is not
-- permission to use another atlas's hand landmarks.
function HumanRig.profileFor(profiles,role,atlas)
 local base=profiles[role]
 if not base or type(atlas)~='string' then return nil end
 local function suffix(path)return atlas==path or atlas:sub(-#path-1)=='/'..path end
 local function matches(p)
  if not p.atlas or suffix(p.atlas) then return true end
  for _,path in ipairs(p.variants or {})do if suffix(path) then return true end end
 end
 local found=matches(base) and base or nil
 for _,candidate in ipairs(base.alternates or {})do
  if matches(candidate)then if found then return nil end;found=candidate end
 end
 return found
end
function HumanRig.new(voxel,hands)
 local rim=HumanRig.rim
 local rimShader=rim and rim.shader or 'vec4 sourceRim(Image t,vec2 uv,vec4 p){return p;}'
 local compose=love.graphics.newShader(rimShader..[[
 extern float row;extern float column;extern float shift;extern vec4 bounds;
 extern float protectHands;extern vec4 handShape;extern vec4 handWindow;
 extern vec2 legWindow;extern float mirrorAxis;
 extern vec4 staticRegion0;extern vec4 staticRegion1;
 float staticMask(vec2 p,vec4 r){
  if(r.z<=r.x || r.w<=r.y)return 0.0;
  float x=smoothstep(r.x-.015,r.x,p.x)*(1.0-smoothstep(r.z,r.z+.015,p.x));
  float y=smoothstep(r.y-.015,r.y,p.y)*(1.0-smoothstep(r.w,r.w+.015,p.y));
  return x*y;
 }
 vec4 effect(vec4 color,Image tex,vec2 uv,vec2 sc){
  vec4 upper=sourceRim(tex,uv,Texel(tex,uv));vec2 lo=uv+vec2(column/3.0,shift);
  if(mirrorAxis>0.0)lo.x=mirrorAxis-uv.x;
  vec4 lower=lo.y<row/4.0 || lo.y>=(row+1.0)/4.0?vec4(0.0):sourceRim(tex,lo,Texel(tex,lo));
  float u=(uv.x-bounds.x)/bounds.z;float v=(uv.y-bounds.y)/bounds.w;
  float width=.18+max(0.0,v-.68)*1.5;
  float k=smoothstep(legWindow.x,legWindow.y,v)*(1.0-smoothstep(width,width+.04,abs(u-.5)));
  if(protectHands>0.0){
   float band=smoothstep(handWindow.x,handWindow.y,v)*(1.0-smoothstep(handWindow.z,handWindow.w,v));
   float left=1.0-smoothstep(handShape.y,handShape.y+.04,abs(u-handShape.x));
   float right=1.0-smoothstep(handShape.w,handShape.w+.04,abs(u-handShape.z));
   k*=1.0-band*max(left,right);
  }
  // Exact source-specific equipment regions remain in the neutral card.
  // This prevents authored cane/basket fragments from following leg frames.
  k*=1.0-max(staticMask(vec2(u,v),staticRegion0),staticMask(vec2(u,v),staticRegion1));
  vec4 p=mix(vec4(upper.rgb*upper.a,upper.a),vec4(lower.rgb*lower.a,lower.a),k);
  return p.a>0.0?vec4(p.rgb/p.a,p.a):vec4(0.0);
 }
 ]])
 local cache={}
 local usage,entries={},{}
 local serial,sourceCount,meshCount=0,0,0
 local closed=false
 -- Budget the canvases actually materialized, not twelve hypothetical cells
 -- per source. Idle crowds usually need only one cell from each atlas.
 local SOURCE_LIMIT,MESH_LIMIT=128,128
 local PIXEL_LIMIT=24*12*165*225
 local cells={};local cellCount,cellPixels=0,0
 local actors=setmetatable({}, {__mode="k"})
 local metrics={draws=0,loads=0,loadMs=0,maxLoadMs=0,updates=0,updateMs=0,maxUpdateMs=0,templates=0,actorMeshes=0,composites=0,composeMs=0,maxComposeMs=0}
 metrics.residentSources,metrics.residentMeshes,metrics.evictions=0,0,0
 metrics.residentComposites,metrics.residentPixels,metrics.compositeEvictions=0,0,0
 local function releaseCell(canvas)
  local cell=cells[canvas]
  if not cell then return end
  cell.row.textures[cell.column]=nil;cells[canvas]=nil;canvas:release()
  cellCount,cellPixels=cellCount-1,cellPixels-cell.pixels
  metrics.residentComposites,metrics.residentPixels=cellCount,cellPixels
 end
 local function reservePixels(pixels)
  if pixels<=0 or pixels>PIXEL_LIMIT then error('human rig cell exceeds canvas budget')end
  while cellPixels+pixels>PIXEL_LIMIT do
   local oldest,stamp
   for canvas,cell in pairs(cells)do if not stamp or cell.used<stamp then oldest,stamp=canvas,cell.used end end
   releaseCell(assert(oldest));metrics.compositeEvictions=metrics.compositeEvictions+1
  end
 end
 local function releaseEntry(entry)
  if not entries[entry]then return end
  entry.mesh:release();entries[entry]=nil
  if entry.container[entry.key]==entry then entry.container[entry.key]=nil end
  meshCount=meshCount-1;metrics.residentMeshes=meshCount
 end
 local function releaseSource(texture)
  local a=cache[texture]
  if a then
   for owner,actor in pairs(actors)do if actor.source==a then actors[owner]=nil end end
   for entry in pairs(entries)do if entry.source==a then releaseEntry(entry)end end
   for _,row in pairs(a.rows)do for _,canvas in pairs(row.textures)do releaseCell(canvas)end end
  end
  cache[texture]=nil;usage[texture]=nil
  sourceCount=sourceCount-1;metrics.residentSources=sourceCount
 end
 local function reserveSource()
  if sourceCount<SOURCE_LIMIT then return end
  local oldest,stamp
  for texture,used in pairs(usage)do if not stamp or used<stamp then oldest,stamp=texture,used end end
  if oldest then releaseSource(oldest);metrics.evictions=metrics.evictions+1 end
 end
 local function reserveMesh()
  if meshCount<MESH_LIMIT then return end
  local oldest
  for entry in pairs(entries)do if not oldest or entry.used<oldest.used then oldest=entry end end
  if oldest then releaseEntry(oldest);metrics.evictions=metrics.evictions+1 end
 end
 local function sourceBuilder(texture,bounds,profile)
  local started=love.timer.getTime()
  local w,h=texture:getDimensions();local cw,ch=w/3,h/4
  local a={w=w,h=h,cw=cw,ch=ch,rows={}}
  for row=0,3 do
   local r={frames={},meshes={},textures={}}
   for col=0,2 do
    local source=assert(bounds[row][col]);local frame={left=source.left,right=source.right,top=source.top,bottom=source.bottom}
    local bottoms=profile.bodyBottoms and profile.bodyBottoms[row]
    if bottoms and type(bottoms[col+1])=='number' then
     frame.bottom=math.min(frame.bottom,row*ch+bottoms[col+1])
     if frame.bottom<=frame.top then error('human rig body bottom excludes source body')end
    end
    r.frames[col]=frame
   end
   a.rows[row]=r
  end
  local ms=(love.timer.getTime()-started)*1000;metrics.loads=metrics.loads+1;metrics.loadMs=metrics.loadMs+ms;metrics.maxLoadMs=math.max(metrics.maxLoadMs,ms)
  return a
 end
 -- Materialize only the direction/step being drawn. Later requests reuse
 -- that cell; unused directions cost no offscreen render or canvas allocation.
 local function cellTexture(a,texture,row,col,rig,protectHands,legWindow,profile)
  local r=a.rows[row]
  if r.textures[col] then
   cells[r.textures[col]].used=serial
   return r.textures[col]
  end
  local started=love.timer.getTime()
  local n=r.frames[0];local w,h=a.w,a.h;local cw,ch=a.cw,a.ch
  reservePixels(cw*ch)
  local c=love.graphics.newCanvas(cw,ch);c:setFilter('linear','linear')
  love.graphics.push('all')
  local ok,err=pcall(function()
   love.graphics.setCanvas(c);love.graphics.origin();love.graphics.setScissor()
   love.graphics.setDepthMode();love.graphics.setColor(1,1,1,1);love.graphics.clear(0,0,0,0)
   love.graphics.setBlendMode('replace','premultiplied');love.graphics.setShader(compose)
   if rim then rim.send(compose,w,h,profile)end
   local sampledCol=rig.reuseFirstStep and col==2 and 1 or col
   compose:send('row',row);compose:send('column',sampledCol)
   -- Only explicitly reviewed directions may reuse a reflected lower step.
   -- Neutral upper body, equipment and the ordinary source path stay intact.
   compose:send('mirrorAxis',rig.mirrorSecondStep and col==2
    and (n.left+n.right+r.frames[sampledCol].left+r.frames[sampledCol].right)/(2*w) or 0)
   compose:send('protectHands',protectHands and 1 or 0)
   local maskRadius=rig.maskRadius or rig.radius
   compose:send('handShape',{rig.centers[1],maskRadius[1],rig.centers[2],maskRadius[2]})
   compose:send('handWindow',rig.window)
   compose:send('legWindow',legWindow or {.685,.710})
   local regions=rig.staticRegions or {}
   compose:send('staticRegion0',regions[1] or {0,0,0,0})
   compose:send('staticRegion1',regions[2] or {0,0,0,0})
   compose:send('shift',(r.frames[sampledCol].bottom-n.bottom)/h)
   compose:send('bounds',{n.left/w,n.top/h,(n.right-n.left)/w,(n.bottom-n.top)/h})
   local quad=love.graphics.newQuad(0,row*ch,cw,ch,w,h)
   love.graphics.draw(texture,quad,0,0);quad:release()
  end)
  love.graphics.pop()
  if not ok then c:release();error(err) end
  r.textures[col]=c
  cells[c]={row=r,column=col,pixels=cw*ch,used=serial}
  cellCount,cellPixels=cellCount+1,cellPixels+cw*ch
  metrics.residentComposites,metrics.residentPixels=cellCount,cellPixels
  local ms=(love.timer.getTime()-started)*1000
  metrics.composites=metrics.composites+1;metrics.composeMs=metrics.composeMs+ms
  metrics.maxComposeMs=math.max(metrics.maxComposeMs,ms)
  return c
 end
 local function smooth(a,b,x)local t=math.max(0,math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)end
 local function bell(x,r)return 1-smooth(r,r+.08,math.abs(x))end
 local function meshFor(a,row,unit,stride,rig,originalMesh,owner,lean)
  lean=lean or 0
  local r=a.rows[row];local relief=originalMesh:getVertexCount()==16
  local _,_,_,_,_,firstShade=originalMesh:getVertex(1)
  local key=string.format('%.6f',unit)..(relief and ':relief:'..tostring(firstShade) or ':flat')..':'..tostring(originalMesh);local actor=actors[owner]
  if not actor or actor.source~=a then
   if actor then for _,row in pairs(actor.rows)do for _,entry in pairs(row)do releaseEntry(entry)end end end
   actor={source=a,rows={}};actors[owner]=actor
  end
  actor.rows[row]=actor.rows[row] or {}
  local meshes=actor.rows[row];local entry=meshes[key]
  local n=r.frames[0];local anchor=(n.left+n.right)/2;local height=(n.bottom-n.top)*unit
  if not entry then
   -- Only vertex positions and the GPU mesh belong to an individual actor.
   -- Landmarks, topology and neutral geometry are immutable for this source
   -- and original mesh, so a room of identical cards builds them only once.
   r.templates=r.templates or {}
   local templates=r.templates[rig]
   if not templates then templates=setmetatable({}, {__mode="k"});r.templates[rig]=templates end
   local template=templates[originalMesh]
   if not template or template.key~=key then
    template={vertices={},indices={},key=key}
    -- Preserve every original subdivision in the moving shoulder band.
    -- Head/feet are affine static surfaces: their interior rows add no detail.
    local heightPixels=n.bottom-n.top
    local first=math.max(1,math.floor((n.top-row*a.ch+rig.window[1]*heightPixels)/a.ch*32))
    local last=math.min(31,math.ceil((n.top-row*a.ch+rig.window[4]*heightPixels)/a.ch*32))
    local cuts={0};for gy=first,last do cuts[#cuts+1]=gy end;cuts[#cuts+1]=32
    for yi=1,#cuts-1 do for gx=0,23 do
     local ya,yb=cuts[yi]/32,cuts[yi+1]/32
     local bi=#template.vertices/4
     for _,p in ipairs({{gx/24,yb},{(gx+1)/24,yb},{(gx+1)/24,ya},{gx/24,ya}})do
      local x,y=p[1]*a.cw,(row+p[2])*a.ch
      local z,shade=0,1
      if relief then
       local f=math.max(0,math.min(1,(x-n.left)/(n.right-n.left)))*4
       local segment=math.min(3,math.floor(f));local t=f-segment
       local _,_,za,_,_,sa=originalMesh:getVertex(segment*4+1)
       local _,_,zb=originalMesh:getVertex(segment*4+2)
       z=za+(zb-za)*t;shade=sa
      end
      template.vertices[#template.vertices+1]={8+(x-anchor)*unit,(n.bottom-y)*unit,z,x/a.cw,(y-row*a.ch)/a.ch,shade}
     end;voxel.pushQuad(template.indices,bi)
    end end
    template.vertices=compactVertices(template.vertices,template.indices)
    template.base={};template.weights={}
    local win=rig.window;local gains=rig.gains or {1,1}
    for i,p in ipairs(template.vertices)do
     template.base[i]={p[1],p[2]}
     local u=(p[4]*a.cw-n.left)/(n.right-n.left);local v=((p[5]+row)*a.ch-n.top)/(n.bottom-n.top)
     local t=smooth(win[1],win[2],v);local shoulder=t*(1-smooth(win[3],win[4],v))
     if row==1 or row==3 then
      local arm=shoulder*bell(u-rig.centers[1],rig.radius[1])
      if rig.pinSecond then arm=arm*(1-bell(u-rig.centers[2],rig.radius[2]))end
     -- Keep a small continuous weight transfer underneath the authored
     -- neutral/A/B cadence. The torso rises between passing poses and shifts
     -- by less than half a source pixel while the sole remains planted. This
     -- softens the side-view step change without blending or mirroring shoes.
     local support=1-smooth(.68,.98,v)
     template.weights[i]={arm*height*.026+support*height*.0015,0,0,
       arm*height*.003,support*height*.0035}
     else
      local l=.5+(rig.centers[1]-.5)*(.65+.35*t);local rr=.5+(rig.centers[2]-.5)*(.65+.35*t)
      local delta=shoulder*(gains[1]*bell(u-l,rig.radius[1])-gains[2]*bell(u-rr,rig.radius[2]))
      local support=1-smooth(.68,.98,v)
      template.weights[i]={support*height*.0015,-delta*height*.003,
        -delta*height*.012,0,support*height*.0035}
     end
    end
    templates[originalMesh]=template
    metrics.templates=(metrics.templates or 0)+1
   end
   entry={vertices={},indices=template.indices,base=template.base,weights=template.weights}
   for i,p in ipairs(template.vertices)do
    entry.vertices[i]={p[1],p[2],p[3],p[4],p[5],p[6]}
   end
   reserveMesh()
   entry.mesh=assert(voxel.newMesh(entry.vertices,entry.indices))
   -- Keep the identity alive while its cache key is resident. Different
   -- relief depth/UV/shade layouts must never reuse another source mesh.
   entry.original=originalMesh
   entry.source,entry.container,entry.key,entry.used=a,meshes,key,serial
   entries[entry]=true;meshCount=meshCount+1;metrics.residentMeshes=meshCount
   meshes[key]=entry;metrics.actorMeshes=metrics.actorMeshes+1
  end
  entry.used=serial
  if entry.stride~=stride or entry.lean~=lean then
   local started=love.timer.getTime()
   entry.stride,entry.lean=stride,lean;local magnitude=math.abs(stride)
   local stepPulse=stride*stride
   for i,p in ipairs(entry.vertices)do
    local base,weight=entry.base[i],entry.weights[i]
    p[1]=base[1]+weight[1]*stride+weight[2]*magnitude+base[2]*lean
    p[2]=base[2]+weight[3]*stride+weight[4]*magnitude+(weight[5] or 0)*stepPulse
   end
   entry.mesh:setVertices(entry.vertices)
   local ms=(love.timer.getTime()-started)*1000;metrics.updates=metrics.updates+1;metrics.updateMs=metrics.updateMs+ms;metrics.maxUpdateMs=math.max(metrics.maxUpdateMs,ms)
  end
  return entry.mesh
 end
 local api={metrics=metrics}
 function api:prepare(record,originalMesh,source,row,column)
  if closed or not record or not record.humanMotion then return nil end
  local role=record.def and record.def.ascendantRole or record.role
  local atlas=tostring(record.def and record.def.ascendantAtlasImage or "")
  local profile=HumanRig.profileFor(hands,role,atlas)
  if not profile then return nil end
  local count=originalMesh:getVertexCount()
  if count~=4 and count~=16 then return nil end
  local texture=source.texture
  serial=serial+1
  if usage[texture]then usage[texture]=serial end
  if cache[texture]==false then return nil end
  local ok,m,t=pcall(function()
   local a=cache[texture]
   if not a then
    reserveSource();a=sourceBuilder(texture,source.bounds,profile);cache[texture]=a
    usage[texture]=serial;sourceCount=sourceCount+1;metrics.residentSources=sourceCount
   end
   local x,_,_,u=originalMesh:getVertex(1);local x2,_,_,u2=originalMesh:getVertex(2)
   local unit=(x2-x)/((u2-u)*a.w)
   if unit~=unit or unit<=0 or unit==math.huge then return nil end
   local stride=record.humanMotion.armStride
   if stride==nil then stride=math.sin(record.humanMotion.distance/32*math.pi*2)end
   local shiftScale=profile.idleShiftScale
   if shiftScale==nil then shiftScale=.012 end
   local lean=(record.humanMotion.idleShift or 0)*shiftScale
   local mesh=meshFor(a,row,unit,stride,profile[row],originalMesh,record,lean)
   return mesh,cellTexture(a,texture,row,column,profile[row],profile.protectHands,profile[row].legWindow or profile.legWindow,profile)
  end)
  if not ok then
   self.error=m
   if usage[texture]then releaseSource(texture)else reserveSource()end
   cache[texture]=false;usage[texture]=serial;sourceCount=sourceCount+1;metrics.residentSources=sourceCount
   return nil
  end
  if m then metrics.draws=metrics.draws+1 end
  return m,t
 end
 function api:resetActors()
  for entry in pairs(entries)do releaseEntry(entry)end
  actors=setmetatable({}, {__mode="k"})
 end
 function api:clear()
  if closed then return end
  self:resetActors()
  for texture in pairs(usage)do releaseSource(texture)end
  compose:release();closed=true
 end
 return api
end
return HumanRig
