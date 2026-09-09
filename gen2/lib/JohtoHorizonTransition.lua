-- One continuous strip follows both arms of a verified woodland/ridge turn.
-- Terrain/collision/loading/map definitions are unchanged. Route45/46's
-- re-entrant turn is chamfered strictly outside the resident apron union.
local T={FAMILY='johto_transition',WIDTH=384,HEIGHT=128,ARM=192}
local PAIRS={
  {ridge='BLACKTHORN_CITY',forest='ROUTE_44',rw=20,rh=18,fw=30,fh=9,offset=9},
  {ridge='ROUTE_45',forest='ROUTE_46',rw=10,rh=45,fw=10,fh=18,offset=36,chamfer=true},
}
local function node(x,z)return x..':'..z end
local function key(id,axis,wall,along)return id..':'..axis..':'..wall..':'..along end
local function native(e,w,h)
  local d=e and e.map and e.map.def
  return d and d.width==w and d.height==h and d.tileset=='TILESET_JOHTO'
    and (d.environment=='TOWN' or d.environment=='ROUTE')
end
function T.build(maps,H,checkpoint)
  local result={panels={},joins=0}
  local byId={};for _,e in ipairs(maps)do byId[e.map.id]=e end
  local C,D=H.CELL,H.OUTDOOR_WALL_DISTANCE
  local function inside(x,z)
    for _,r in ipairs(maps)do
      if x>=r.x0-D and x<r.x1+D and z>=r.z0-D and z<r.z1+D then return true end
    end
    return false
  end
  local function crossesInterior(a,b,r)
    local enter,leave=0,1
    for axis,range in ipairs({{r.x0-D,r.x1+D},{r.z0-D,r.z1+D}})do
      local delta=b[axis]-a[axis]
      if delta==0 then
        if a[axis]<=range[1]or a[axis]>=range[2]then return false end
      else
        local t0,t1=(range[1]-a[axis])/delta,(range[2]-a[axis])/delta
        enter=math.max(enter,math.min(t0,t1));leave=math.min(leave,math.max(t0,t1))
      end
    end
    return enter<leave-1e-9
  end
  for _,pair in ipairs(PAIRS)do
    local r,f=byId[pair.ridge],byId[pair.forest]
    local c=r and r.map.def.connections and r.map.def.connections.west
    if native(r,pair.rw,pair.rh) and native(f,pair.fw,pair.fh)
      and c and (c.mapId or c.map)==pair.forest and c.offset==pair.offset
      and f.ox==r.ox-f.w and f.oy==r.oy+pair.offset*C then
      local segments,nodes={},{}
      for _,entry in ipairs({f,r})do
        for _,edge in ipairs({'north','south','west','east'})do
          local axis=(edge=='north' or edge=='south')and'z'or'x'
          local outward=(edge=='north' or edge=='west')and -1 or 1
          local wall=axis=='z' and(outward<0 and entry.z0-D or entry.z1+D)
            or(outward<0 and entry.x0-D or entry.x1+D)
          local start=axis=='z' and entry.x0-D or entry.z0-D
          local finish=axis=='z' and entry.x1+D or entry.z1+D
          for along=start,finish-C,C do
            local mid=along+C/2
            local x,z=axis=='z' and mid or wall,axis=='z' and wall or mid
            local dx,dz=axis=='x' and outward or 0,axis=='z' and outward or 0
            if inside(x-dx,z-dz) and not inside(x+dx,z+dz)then
              local localAlong=along-(axis=='z' and entry.ox or entry.oy)
              local kind,_,p=H.panelProfile(entry.map,edge,localAlong)
              local forest=entry==f and kind=='forest' and not(p and p.editor)
              local ridge=entry==r and kind=='mountain' and p and p.johtoRidge
              if forest or ridge then
                local a={axis=='z' and along or wall,axis=='z' and wall or along}
                local b={axis=='z' and along+C or wall,axis=='z' and wall or along+C}
                local s={id=entry.map.id,axis=axis,wall=wall,along=along,
                  forest=forest,a=a,b=b}
                s.key=key(s.id,axis,wall,along);segments[s.key]=s
                for _,point in ipairs({a,b})do
                  local n=node(point[1],point[2]);nodes[n]=nodes[n]or{}
                  nodes[n][#nodes[n]+1]=s
                end
              end
            end
          end
          if checkpoint then checkpoint()end
        end
      end
      local ordered={};for name in pairs(nodes)do ordered[#ordered+1]=name end
      table.sort(ordered)
      for _,name in ipairs(ordered)do local n=nodes[name];if #n==2 and n[1].axis~=n[2].axis
        and n[1].forest~=n[2].forest then
        local a,b=n[1],n[2]
        local corner
        for _,p in ipairs({a.a,a.b})do for _,q in ipairs({b.a,b.b})do
          if p[1]==q[1] and p[2]==q[2]then corner=p end
        end end
        local proposed,ends={},{};local complete=corner~=nil
        for _,s in ipairs({a,b})do if complete then
          local at=s.axis=='z' and corner[1]or corner[2]
          local sign=at==s.along and 1 or -1
          -- A resident Route29 can shorten Route46's exposed return to only
          -- 96px. Use the actual run, never skip that corner or cross its turn.
          local available=0
          for step=0,2*T.ARM/C-1 do
            local along=at+(sign>0 and step*C or -(step+1)*C)
            local part=segments[key(s.id,s.axis,s.wall,along)]
            if not part or part.forest~=s.forest then break end
            available=available+C
          end
          local last=at+sign*available
          local endNode=nodes[node(s.axis=='z'and last or s.wall,s.axis=='z'and s.wall or last)]
          if endNode and #endNode==2 and endNode[1].forest~=endNode[2].forest then
            available=math.floor(available/(2*C))*C
          end
          local arm=math.min(T.ARM,available)
          ends[s.forest and 'forest'or'ridge']={s.axis=='z'and at+sign*arm or s.wall,s.axis=='z'and s.wall or at+sign*arm}
          if arm<C then complete=false end
          for step=0,arm/C-1 do
            local along=at+(sign>0 and step*C or -(step+1)*C)
            local k=key(s.id,s.axis,s.wall,along)
            local segment=segments[k]
            if not segment or segment.forest~=s.forest or result.panels[k]then complete=false;break end
            proposed[#proposed+1]={key=k,axis=s.axis,corner=at,sign=sign,forest=s.forest,arm=arm}
          end
        end end
        if complete then
          local path
          if pair.chamfer then
            local safe=true
            for _,r in ipairs(maps)do if crossesInterior(ends.forest,ends.ridge,r)then safe=false;break end end
            if safe then path=ends end
          end
          result.joins=result.joins+1
          for _,p in ipairs(proposed)do p.path=path;result.panels[p.key]=p end
        end
      end end
    end
  end
  return result
end
function T.panel(plan,entry,kind,corners,placement)
  if not plan or placement and placement.editor then return nil end
  local axis=corners[1][3]==corners[2][3]and'z'or'x'
  local wall=(axis=='z'and corners[1][3]+entry.oy or corners[1][1]+entry.ox)
  local along=axis=='z' and math.min(corners[1][1],corners[2][1])+entry.ox
    or math.min(corners[1][3],corners[2][3])+entry.oy
  local p=plan.panels[key(entry.map.id,axis,wall,along)]
  if not p or (p.forest and kind~='forest')
    or(not p.forest and not(kind=='mountain' and placement and placement.johtoRidge))then return nil end
  local uv,out={},{}
  for i,v in ipairs(corners)do
    local coord=axis=='z' and v[1]+entry.ox or v[3]+entry.oy
    local distance=(coord-p.corner)*p.sign
    local u=.5+(p.forest and -1 or 1)*distance/(2*p.arm)
    local h=96+u*32
    local x,z=v[1],v[3]
    if p.path then
      x=p.path.forest[1]*(1-u)+p.path.ridge[1]*u-entry.ox
      z=p.path.forest[2]*(1-u)+p.path.ridge[2]*u-entry.oy
    end
    out[i]={x,i>2 and h or 0,z}
    uv[i]={(0.5+u*(T.WIDTH-1))/T.WIDTH,i>2 and 0 or 1}
  end
  return out,uv
end

-- Only the first/last two strip cells need a blend. Small 32x128 baked tiles
-- preserve the old panorama's exact UV, height and face shade at the outside
-- endpoint; the shared 384x128 transition owns the middle. No per-frame blend
-- shader, source-master residency or alteration of Voxel3D is needed.
local blendSpecs,blendCount,blendShader={},0,nil
T.BLEND_LIMIT=64
T.BLEND_VRAM_LIMIT=T.BLEND_LIMIT*32*128*4
function T.blendFamily(baseFamily,oldUV,oldCorners,shade,newUV,newCorners)
  local u0=(newUV[1][1]*T.WIDTH-.5)/(T.WIDTH-1)
  local u1=(newUV[2][1]*T.WIDTH-.5)/(T.WIDTH-1)
  if math.min(u0,u1)>=1/6-1e-9 and math.max(u0,u1)<=5/6+1e-9 then return nil end
  local numbers={oldUV[1][1],oldUV[2][1],oldUV[3][2],oldUV[1][2],
    oldCorners[3][2],shade,newUV[1][1],newUV[2][1],newCorners[4][2],newCorners[3][2]}
  local fields={'johto_blend',baseFamily}
  for _,n in ipairs(numbers)do fields[#fields+1]=('%.12g'):format(n)end
  local family=table.concat(fields,':')
  if not blendSpecs[family]then
    -- Edited streaming graphs must not grow the shared material cache forever.
    -- At the cap retain the joined source, not a missing texture/2D fallback.
    if blendCount>=T.BLEND_LIMIT then return nil end
    blendCount=blendCount+1
    blendSpecs[family]={baseFamily=baseFamily,n=numbers}
  end
  return family
end
function T.blendSpec(family)return blendSpecs[family]end
local SHADER=[[
extern Image previous;
extern vec4 oldUV;
extern vec4 shape;
extern vec2 joinedU;
vec4 effect(vec4 color, Image joined, vec2 tc, vec2 sc) {
  float h=mix(shape.z,shape.w,tc.x);
  float v=1.0-(1.0-tc.y)*h/shape.x;
  vec4 a=vec4(0.0);
  if(v>=0.0 && v<=1.0) a=Texel(previous,vec2(mix(oldUV.x,oldUV.y,tc.x),mix(oldUV.z,oldUV.w,v)));
  float u=mix(joinedU.x,joinedU.y,tc.x);
  vec4 b=Texel(joined,vec2(u,tc.y));
  float t=(u*384.0-0.5)/383.0;
  float w=clamp(min(t,1.0-t)*6.0,0.0,1.0);
  float alpha=mix(a.a,b.a,w);
  vec3 rgb=mix(a.rgb*a.a*shape.y,b.rgb*b.a,w)/max(alpha,0.00001);
  return vec4(rgb,alpha);
}
]]
function T.bakeBlend(g,spec,previous,joined,newCanvas)
  if not(previous and joined)then return nil end
  local canvas=newCanvas(g,32,128)
  if not canvas then return nil end
  local pushed=false
  local ok=pcall(function()
    blendShader=blendShader or g.newShader(SHADER)
    local n=spec.n
    g.push('all');pushed=true;g.origin();g.setCanvas(canvas);g.clear(0,0,0,0)
    g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1)
    blendShader:send('previous',previous)
    blendShader:send('oldUV',{n[1],n[2],n[3],n[4]})
    blendShader:send('shape',{n[5],n[6],n[9],n[10]})
    blendShader:send('joinedU',{n[7],n[8]})
    g.setShader(blendShader);g.draw(joined,0,0,0,32/T.WIDTH,128/T.HEIGHT)
    g.pop();pushed=false
  end)
  if not ok then
    if pushed then pcall(g.pop)end
    -- An optional seam shader must not become a new requirement for 3D on
    -- older mobile GPUs. Reuse this tile with the matching source slice if
    -- shader compilation fails; retain the joined geometry and its UVs.
    pushed=false
    local quad
    local fallback=pcall(function()
      local n=spec.n;local left=math.min(n[7],n[8])*T.WIDTH
      local width=math.abs(n[8]-n[7])*T.WIDTH
      quad=g.newQuad(left,0,width,T.HEIGHT,T.WIDTH,T.HEIGHT)
      g.push('all');pushed=true;g.origin();g.setCanvas(canvas);g.clear(0,0,0,0)
      g.setShader();g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1)
      local reverse=n[8]<n[7]
      g.draw(joined,quad,reverse and 32 or 0,0,0,(reverse and -1 or 1)*32/width,1)
      g.pop();pushed=false
    end)
    if quad then pcall(quad.release,quad)end
    if not fallback then
      if pushed then pcall(g.pop)end
      canvas:release();return nil
    end
  end
  return canvas
end
function T.clearMaterials()
  if blendShader and blendShader.release then pcall(blendShader.release,blendShader)end
  blendShader=nil;blendSpecs={};blendCount=0
end
return T
