-- Gen-1 sun/moon and local irradiance. Lamps use authored flame/glass
-- geometry and world transforms; no map tiles or saves are changed.
local V = ...
local M = { MAX_LIGHTS = 8, MAX_BATTLE_LIGHTS = 4, MAX_BLOCKERS = 8, MAX_PORTALS = 4 }
local platform = V.require('CanvasPresentation').OS
M.mobile = platform == 'iOS' or platform == 'Android'
M.supported = not (V.mod and V.mod._vascHostGeneration and V.mod._vascHostGeneration~=1)
M.ownerActive = true -- the Gen1 host closes this until its Card activates
if M.mobile then M.MAX_LIGHTS=4;M.MAX_BATTLE_LIGHTS=2;M.MAX_BLOCKERS=4;M.MAX_PORTALS=2 end
function M.available() return M.supported and M.ownerActive and not M.failure end
function M.fail(reason) M.failure=tostring(reason);M.clear(true) end
function M.setOwnerActive(value) M.ownerActive=value==true;if not value then M.invalidate() end end
M.setting = V.require('ModSetting').new('localLights', 'DYNAMIC LIGHTING',
  {true, false}, {'ON', 'OFF'}, M.supported)
M.setting:setGate(function(value) return not value or M.supported end)

local shapes = setmetatable({}, {__mode='k'})
local frame = {lights={}, blockers={}}
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function distance(x,y,z, p)
  return (x-p[1])^2 + (y-p[2])^2 + (z-p[3])^2
end

-- Panes are thin boxes. Their narrow axis and position within the building
-- determine the outward direction, including side windows and roof glazing.
function M.shape(model, glass)
  local cached = shapes[model]
  if cached and cached.glass == glass then return cached end
  local out = {glass=glass, panes={}, lo={math.huge,math.huge,math.huge},
    hi={-math.huge,-math.huge,-math.huge}}
  for _,b in ipairs(model.boxes or {}) do
    for axis=1,3 do
      out.lo[axis]=math.min(out.lo[axis],b[axis])
      out.hi[axis]=math.max(out.hi[axis],b[axis]+b[axis+3])
    end
  end
  if out.lo[1] == math.huge then out.lo={0,0,0};out.hi={0,0,0} end
  for _,b in ipairs(glass and glass.boxes or {}) do
    local axis=1
    for a=2,3 do if b[a+3]<b[axis+3] then axis=a end end
    local centre={b[1]+b[4]/2,b[2]+b[5]/2,b[3]+b[6]/2}
    local n={0,0,0}
    n[axis]=axis==2 and 1 or
      (centre[axis] >= (out.lo[axis]+out.hi[axis])/2 and 1 or -1)
    -- Start just outside the pane, so its surrounding trim can receive light.
    centre[axis]=centre[axis]+n[axis]*(b[axis+3]/2+.5)
    local area=b[4]*b[5]*b[6]/math.max(.1,b[axis+3])
    out.panes[#out.panes+1]={position=centre,normal=n,
      radius=clamp(30+math.sqrt(area)*2.3,38,76),
      power=clamp(.65+math.sqrt(area)/22,.8,1.5)}
  end
  shapes[model]=out
  return out
end

-- A source pool may exceed the shader budget in a city. Selection is stable
-- for ties, and importance measures the pool's reach towards the view focus.
-- Sources fade near the selection boundary, avoiding hard pops.
function M.select(candidates, focus, limit)
  for i,l in ipairs(candidates) do
    local d=math.sqrt(distance(l.x,l.y,l.z,focus))
    l.score=l.power*l.radius/(l.radius+d)
    l.order=i
  end
  table.sort(candidates,function(a,b)
    if a.score==b.score then return a.order<b.order end
    return a.score>b.score
  end)
  local result={}
  local cutoff=candidates[limit+1] and candidates[limit+1].score or 0
  for i=1,math.min(limit,#candidates) do
    local l=candidates[i]
    l.weight=cutoff>0 and clamp((l.score-cutoff)/math.max(.04,l.score*.15),0,1) or 1
    result[i]=l
  end
  return result
end

function M.enabled() return M.available() and M.setting:get() end
-- The cinematic rig keeps low-angle shafts long enough to read, bounded
-- to two caster heights. OFF continues using the release's compact rig.
function M.shearAt(t)
 local D=V.require('DayNight')
 if not D.bodyAt then return D.shearAt(t) end
 local bearing,elevation,moon=D.bodyAt(t)
 local length=math.min(2,1/math.tan(math.rad(math.max(.5,elevation))))
 return -math.cos(math.rad(bearing))*length,-math.sin(math.rad(bearing))*length,moon
end
function M.sky(map, outdoor, weather, enabled)
  if not (enabled == true or M.enabled()) or not (outdoor or V.require('DayNight').isCanopy(map)) then return nil end
  local D=V.require('DayNight')
  local x,z,moon=M.shearAt(D.rigTime())
  local length=math.sqrt(x*x+1+z*z)
  local overcast=weather=='rain' or weather=='storm' or weather=='fog' or weather=='snow'
  return {direction={-x/length,1/length,-z/length,D.strengthAt(D.time())*(overcast and .2 or 1)},
    canopy=D.isCanopy(map) and 1 or 0,moon=moon and 1 or 0}
end
function M.clear(suppressed) frame={lights={},blockers={},suppressed=suppressed} end
function M.current() return frame end
function M.active() return M.available() and not frame.suppressed and (frame.battle == true or M.enabled()) end
-- A portable ARENA carries its environment, not the map's coordinates.
function M.stage(sky,tint,lights)
  M.clear();frame.battle=true;frame.sky=sky;frame.tint=tint;frame.lights=lights or {}
  return frame
end

local wallFields=setmetatable({},{__mode='k'})
local blankWall
local function wallField(map)
 local hit=wallFields[map]
 if hit then return hit end
 local w,h=map.def.width*2,map.def.height*2
 local data=love.image.newImageData(w,h)
 local torches=V.require('CaveTorches')
 for y=0,h-1 do for x=0,w-1 do
   data:setPixel(x,y,torches.wallCell(map,x,y) and 1 or 0,0,0,1)
 end end
 local texture=love.graphics.newImage(data);data:release()
 texture:setFilter('nearest','nearest');texture:setWrap('clamp','clamp')
 hit={texture=texture,size={w*16,h*16}};wallFields[map]=hit
 return hit
end
local function emptyWall()
 if not blankWall then
   local data=love.image.newImageData(1,1)
   blankWall=love.graphics.newImage(data);data:release()
 end
 return blankWall
end

function M.prepare(state, outdoor, focus, dark, weather, battle, props)
  M.clear()
  if not M.available() or not (battle == true or M.enabled()) or not state
      or not state.map or state.map.def.generation==2 then return frame end
  frame.battle=battle == true
  local Items=V.require('VoxelItems')
  local sources, buildings={},{}
  local interior,indoorTint
  if not outdoor then interior,indoorTint=V.require('InteriorLights').prepare(state.map) end
  frame.interior=interior
  frame.map=state.map
  local cave=V.require('CaveTorches').eligible(state.map)
  local tower=V.require('TowerAtmosphere').active(state.map)
  frame.sky=M.sky(state.map,outdoor,weather,battle)
  if cave then frame.wall=wallField(state.map) end
  frame.tint=indoorTint or V.require('Voxel3D').tint
  if tower and not dark then frame.tint={.34,.36,.49} end
  if indoorTint or tower then V.require('Voxel3D').tint=frame.tint end
  if interior then
    local D=V.require('DayNight');local sky=M.sky(state.map,true,weather,battle)
    frame.portalSky=sky
    local night=D.windowLight()
    frame.portalColor={1-night*.48,.88-night*.20,.65+night*.35}
    frame.portals={}
    for _,p in ipairs(interior.portals)do
      if #frame.portals<M.MAX_PORTALS then frame.portals[#frame.portals+1]=p end
      local q=p.position
      sources[#sources+1]={x=q[1],y=q[2],z=q[3],normal=p.normal,radius=72,
        power=.46-night*.30,color=frame.portalColor,owner={},kind='window'}
    end
    for _,l in ipairs(interior.lamps)do
      local q=l.position
      sources[#sources+1]={x=q[1],y=q[2],z=q[3],normal=l.normal,radius=l.radius,
        power=l.power*(.35+night*.65),color=l.color,owner={},fixture=l,kind=l.kind}
    end
    for _,b in ipairs(interior.blockers)do buildings[#buildings+1]=b end
  end
  if outdoor and V.require('DayNight').windowLight and V.require('DayNight').windowLight()<=0 then return frame end
  if not outdoor and not cave and not interior and not V.require('TowerAtmosphere').active(state.map) then return frame end
  -- The visible neighborhood supplies translated matrices, including its
  -- ledge elevation. This is the same enumeration used by the furniture pass.
  local function eachSource(fn)
    if props then
      for _,p in ipairs(props.furniture or {})do fn(p.mesh,p.tex,p.mat,p.shade,p.extra)end
    else V.require('VoxelFurniture').eachWorld(state,fn,true) end
  end
  eachSource(function(_,_,mat,_,extra)
    local model=extra and extra.lightModel
    if not model then return end
    if model.lightSource then
      local e=model.lightSource;local pos=e.position
      local flicker=1
      if tower then
        local t=V.require('Sky').clock or 0;local phase=mat[4]*.17+mat[12]*.31
        flicker=.91+.06*math.sin(t*3.7+phase)+.03*math.sin(t*8.1+phase*1.7)
      end
      sources[#sources+1]={x=pos[1]+mat[4],y=pos[2]+mat[8],z=pos[3]+mat[12],
        normal=e.normal,radius=dark and 26 or e.radius,
        power=(extra.glow or 0)*e.power*flicker,color=e.color,owner={},kind=e.kind or 'torch'}
      return
    end
    if not outdoor or not model.terrain then return end
    local shape=M.shape(model,Items.models[model.glassKind])
    local building={lo={},hi={}}
    for a=1,3 do
      building.lo[a]=shape.lo[a]+mat[a*4]
      building.hi[a]=shape.hi[a]+mat[a*4]
    end
    buildings[#buildings+1]=building
    if (extra.glow or 0)<=0 then return end
    for _,p in ipairs(shape.panes) do
      local x,y,z=p.position[1]+mat[4],p.position[2]+mat[8],p.position[3]+mat[12]
      if distance(x,y,z,focus)<(p.radius+320)^2 then
        sources[#sources+1]={x=x,y=y,z=z,radius=p.radius,
          power=p.power*extra.glow,normal=p.normal,owner=building}
      end
    end
  end)
  frame.lights=M.select(sources,focus,battle and M.MAX_BATTLE_LIGHTS or M.MAX_LIGHTS)
  if cave and not tower and not dark and #frame.lights>0 then
    local tint=frame.tint or {1,1,1}
    frame.tint={tint[1]*.65,tint[2]*.63,tint[3]*.60}
    V.require('Voxel3D').tint=frame.tint
  end
  -- Only blockers intersecting a selected light's range can affect this pass.
  for i,b in ipairs(buildings) do
    b.order=i;b.score=math.huge
    for _,l in ipairs(frame.lights) do
      local d=distance(clamp(l.x,b.lo[1],b.hi[1]),clamp(l.y,b.lo[2],b.hi[2]),
        clamp(l.z,b.lo[3],b.hi[3]),{l.x,l.y,l.z})
      if d<l.radius*l.radius then b.score=math.min(b.score,d) end
    end
  end
  table.sort(buildings,function(a,b)
    if a.score==b.score then return a.order<b.order end
    return a.score<b.score
  end)
  for i=1,math.min(M.MAX_BLOCKERS,#buildings) do
    local b=buildings[i]
    if b.score<math.huge then b.index=i;frame.blockers[i]=b end
  end
  return frame
end

-- Separate scalar uniforms avoid uniform-array indexing problems on older
-- drivers. Phones use fewer scalar slots and the same bounded visibility atlas.
function M.glsl(rawVisibility)
  if not M.supported then return '' end
  local s={[[
uniform float localLightCount;
uniform vec4 localSkyDir;
uniform vec3 localSkyState; // enabled, canopy, wind clock
uniform vec3 localSceneTint;
float localSurfaceShade(float original, vec3 n, vec3 world) {
  if(localSkyState.x<.5) return original;
  float direct=max(0.0,dot(n,localSkyDir.xyz))*localSkyDir.w;
  if(localSkyState.y>.5 && world.y<45.0) {
    vec2 q=(world.xz+localSkyDir.xz*(48.0-world.y)/max(.2,localSkyDir.y))*.13;
    float leaves=sin(q.x+sin(q.y*.71)+localSkyState.z*.24)*sin(q.y-localSkyState.z*.17);
    direct*=.25+.75*smoothstep(-.15,.6,leaves);
  }
  return .38+.78*direct;
}

uniform float localBlockCount;
uniform Image localWallMask;
uniform vec2 localWallSize;
float localCaveVisible(vec3 from, vec3 to) {
  if(localWallSize.x<=0.0) return 1.0;
  for(int i=1;i<=12;i++) {
    vec3 p=mix(from,to,float(i)/13.0);
    vec2 uv=p.xz/localWallSize;
    if(p.y<38.0 && p.y>-.5 && uv.x>=0.0 && uv.y>=0.0 && uv.x<1.0 && uv.y<1.0
       && Texel(localWallMask,uv).r>.5) return 0.0;
  }
  return 1.0;
}
float localBoxHit(vec3 from, vec3 to, vec3 lo, vec3 hi) {
  vec3 delta=to-from;
  if((abs(delta.x)<.0001 && (from.x<lo.x || from.x>hi.x)) ||
     (abs(delta.y)<.0001 && (from.y<lo.y || from.y>hi.y)) ||
     (abs(delta.z)<.0001 && (from.z<lo.z || from.z>hi.z))) return 0.0;
  vec3 safe=sign(delta)*max(abs(delta),vec3(.0001));
  safe+=vec3(1.0)-abs(sign(delta));
  vec3 a=(lo-from)/safe, b=(hi-from)/safe;
  vec3 enter=min(a,b), leave=max(a,b);
  if(abs(delta.x)<.0001){enter.x=-1e6;leave.x=1e6;}
  if(abs(delta.y)<.0001){enter.y=-1e6;leave.y=1e6;}
  if(abs(delta.z)<.0001){enter.z=-1e6;leave.z=1e6;}
  float first=max(max(enter.x,enter.y),enter.z);
  float last=min(min(leave.x,leave.y),leave.z);
  // Do not shadow a receiving facade merely because the endpoint touches it.
  return first<.985 && last>.015 && first<last ? 1.0 : 0.0;
}
]]}
  for i=0,M.MAX_BLOCKERS-1 do
    s[#s+1]=('uniform vec3 localLo%d; uniform vec3 localHi%d;'):format(i,i)
  end
  s[#s+1]='float localVisible(vec3 from, vec3 to, float owner) { float visible=1.0;'
  for i=0,M.MAX_BLOCKERS-1 do
    s[#s+1]=('if(localBlockCount>%.1f && abs(owner-%.1f)>.1) visible*=1.0-localBoxHit(from,to,localLo%d,localHi%d);'):format(i+.5,i+1,i,i)
  end
  s[#s+1]='return visible*localCaveVisible(from,to); }'
  s[#s+1]=[[
vec3 localLamp(vec3 world, vec4 pos, vec4 dir, vec4 tint) {
  vec3 d=world-pos.xyz;
  float r2=dot(d,d)/(pos.w*pos.w);
  if(r2>=1.0 || tint.w<=0.0) return vec3(0.0);
  float front=dot(dir.xyz,dir.xyz)<.1 ? 1.0 : smoothstep(-1.5,3.0,dot(d,dir.xyz));
  if(front<=0.0) return vec3(0.0);
  float fall=(1.0-r2)*(1.0-r2)/(1.0+3.0*r2);
  return tint.rgb*tint.w*front*fall*localVisible(pos.xyz,world,dir.w);
}
]]
  for i=0,M.MAX_LIGHTS-1 do
    s[#s+1]=('uniform vec4 localPos%d; uniform vec4 localDir%d; uniform vec4 localTint%d;'):format(i,i,i)
  end
  s[#s+1]=[[
uniform float localPortalCount;
uniform vec4 localPortalSun;
uniform vec3 localPortalColor;
uniform Image localPortalDepth;
uniform mat4 localPortalVP;
uniform vec3 localPortalShadow; // enabled, bias, texel
float localPortalDepthAt(vec2 uv) {
  vec4 c=Texel(localPortalDepth,uv);return c.r+c.g/255.0;
}
float localPortalOcclusion(vec3 world) {
  if(localPortalShadow.x<.5)return 1.0;
  vec3 p=(localPortalVP*vec4(world,1.0)).xyz;
  if(p.x<0.0||p.y<0.0||p.x>1.0||p.y>1.0||p.z>1.0)return 1.0;
  float z=p.z-localPortalShadow.y,t=localPortalShadow.z*.5;
  float lit=step(z,localPortalDepthAt(p.xy+vec2(-t,-t)))
    +step(z,localPortalDepthAt(p.xy+vec2(t,-t)))
    +step(z,localPortalDepthAt(p.xy+vec2(-t,t)))
    +step(z,localPortalDepthAt(p.xy+vec2(t,t)));
  vec2 edge=min(p.xy,1.0-p.xy);
  return 1.0-.9*smoothstep(0.0,.06,min(edge.x,edge.y))*(1.0-lit*.25);
}
float localPortalBeam(vec3 world,vec4 plane,vec4 rect,vec3 inward) {
  vec3 ray=localPortalSun.xyz;
  float facing=-dot(ray,inward);
  if(facing<.015 || localPortalSun.w<=0.0) return 0.0;
  float t=dot(plane.xyz-world,inward)/dot(ray,inward);
  if(t<0.0 || t>400.0) return 0.0;
  vec3 hit=world+ray*t;
  float along=plane.w<2.0 ? hit.z : hit.x;
  float edge=min(min(along-rect.x,rect.y-along),min(hit.y-rect.z,rect.w-hit.y));
  float soft=.35+t*.008;
  float pane=smoothstep(-soft,soft,edge);
  // The window mullions project onto walls, the floor and actors together.
  float bar=min(abs(along-(rect.x+rect.y)*.5),abs(hit.y-(rect.z+rect.w)*.5));
  pane*=smoothstep(.3,.7+soft*.2,bar);
  return pane*facing*localPortalSun.w*localVisible(hit+inward*.4,world,0.0);
}
]]
  for i=0,M.MAX_PORTALS-1 do
    s[#s+1]=('uniform vec4 localPortalP%d; uniform vec4 localPortalRect%d; uniform vec3 localPortalN%d;'):format(i,i,i)
  end
  s[#s+1]='vec3 localWindowLight(vec3 world,vec3 normal) { float light=0.0;'
  for i=0,M.MAX_PORTALS-1 do
    s[#s+1]=('if(localPortalCount>%.1f) light+=localPortalBeam(world,localPortalP%d,localPortalRect%d,localPortalN%d);'):format(i+.5,i,i,i)
  end
  s[#s+1]='return localPortalColor*light*localPortalOcclusion(world)*(.25+.75*max(0.0,dot(normal,localPortalSun.xyz))); }'
  s[#s+1]='vec3 localIrradiance(vec3 world, vec3 normal) { vec3 light=localWindowLight(world,normal);'
  for i=0,M.MAX_LIGHTS-1 do
    s[#s+1]=('if(localLightCount>%.1f) light+=localLamp(world,localPos%d,localDir%d,localTint%d)*(.12+.88*max(0.0,dot(normal,normalize(localPos%d.xyz-world))));'):format(i+.5,i,i,i,i)
  end
  s[#s+1]='return min(light,vec3(.85)); }'
  s[#s+1]='vec3 localActorIrradiance(vec3 world,vec3 normal) { vec3 light=localWindowLight(world,vec3(0,1,0));'
  for i=0,M.MAX_LIGHTS-1 do
    s[#s+1]=('if(localLightCount>%.1f) light+=localLamp(world,localPos%d,localDir%d,localTint%d)*(.55+.45*max(0.0,dot(normal,normalize(localPos%d.xyz-world))));'):format(i+.5,i,i,i,i)
  end
  s[#s+1]='return min(light,vec3(.85)); }'
  s[#s+1]='vec3 localWaterLight(vec3 world, vec3 reflected) { vec3 light=localWindowLight(world,vec3(0,1,0))*.2;'
  for i=0,M.MAX_LIGHTS-1 do
    s[#s+1]=('if(localLightCount>%.1f) { vec3 l=localLamp(world,localPos%d,localDir%d,localTint%d); float shine=pow(max(0.0,dot(reflected,normalize(localPos%d.xyz-world))),24.0); light+=l*(.07+shine*.9); }'):format(i+.5,i,i,i,i)
  end
  s[#s+1]='return min(light,vec3(1.0)); }'
  local source=table.concat(s,'\n')
  if not rawVisibility then
    -- Keep ray tests only in the cached visibility prepass. This also avoids
    -- enormous inlined programs/register spills on Apple's OpenGL driver.
    local first=assert(source:find('uniform float localBlockCount;',1,true))
    local last=assert(source:find('vec3 localLamp(',first,true))
    source=source:sub(1,first-1)..[[
      uniform Image localVisibility;
      uniform vec2 localPortalVolume;
      float localCachedVisibility(vec3 world,vec4 area,float base,float slot) {
        vec2 cell=clamp((world.xz-area.xy)/area.zw*32.0,vec2(.5),vec2(31.5));
        float layer=clamp((world.y-base)/8.0,0.0,7.0);
        float lo=floor(layer),hi=min(7.0,lo+1.0);
        float x=(slot*32.0+cell.x)/384.0;
        float a=Texel(localVisibility,vec2(x,(lo*32.0+cell.y)/256.0)).r;
        float b=Texel(localVisibility,vec2(x,(hi*32.0+cell.y)/256.0)).r;
        if(slot>=8.0) {
          // A thin partition must not leak sunlight through interpolation
          // with an adjacent visible cell on the other side of that wall.
          vec2 left=vec2((slot*32.0+max(.5,cell.x-1.0))/384.0,0);
          vec2 right=vec2((slot*32.0+min(31.5,cell.x+1.0))/384.0,0);
          float za=(lo*32.0+cell.y)/256.0,zb=(hi*32.0+cell.y)/256.0;
          a=min(a,min(Texel(localVisibility,vec2(left.x,za)).r,Texel(localVisibility,vec2(right.x,za)).r));
          b=min(b,min(Texel(localVisibility,vec2(left.x,zb)).r,Texel(localVisibility,vec2(right.x,zb)).r));
          float nearZ=max(.5,cell.y-1.0),farZ=min(31.5,cell.y+1.0);
          a=min(a,min(Texel(localVisibility,vec2(x,(lo*32.0+nearZ)/256.0)).r,Texel(localVisibility,vec2(x,(lo*32.0+farZ)/256.0)).r));
          b=min(b,min(Texel(localVisibility,vec2(x,(hi*32.0+nearZ)/256.0)).r,Texel(localVisibility,vec2(x,(hi*32.0+farZ)/256.0)).r));
        }
        return mix(a,b,layer-lo);
      }
    ]]..source:sub(last)
    source=source:gsub('vec4 tint%) {','vec4 tint,float slot) {',1)
    source=source:gsub('localVisible%(pos.xyz,world,dir.w%)',
      'localCachedVisibility(world,vec4(pos.xz-vec2(pos.w),vec2(pos.w*2.0)),pos.y-24.0,slot)')
    source=source:gsub('vec3 inward%) {','vec3 inward,float slot) {',1)
    source=source:gsub('localVisible%(hit%+inward%*%.4,world,0.0%)',
      'localCachedVisibility(world,vec4(0,0,localPortalVolume),plane.y-24.0,slot)')
    for i=0,M.MAX_LIGHTS-1 do
      source=source:gsub('localDir'..i..',localTint'..i..'%)','localDir'..i..',localTint'..i..','..i..'.0)')
    end
    for i=0,M.MAX_PORTALS-1 do
      source=source:gsub('localPortalN'..i..'%)','localPortalN'..i..','..(M.MAX_LIGHTS+i)..'.0)')
    end
  end
  source=source:gsub('/384%.0','/'..((M.MAX_LIGHTS+M.MAX_PORTALS)*32)..'.0')
  source=source:gsub('slot>=8%.0','slot>='..M.MAX_LIGHTS..'.0')
  return source
end

local sent=setmetatable({},{__mode="k"})
local warm={1,.64,.27}
function M.send(shader, enabled)
  if not M.supported or not shader:hasUniform('localLightCount') then return false end
  enabled=enabled and M.active()
  local previous=sent[shader]
  if previous and previous.frame==frame and previous.enabled==enabled then return false end
  local lights=enabled and frame.lights or {}
  local sky=enabled and frame.sky
  -- Water uses its own wave normals; localSurfaceShade also replaces its
  -- fixed face light. All programs explicitly reset their previous scene.
  if shader:hasUniform('localSkyDir') then shader:send('localSkyDir',sky and sky.direction or {0,1,0,0}) end
  if shader:hasUniform('localSkyState') then
    shader:send('localSkyState',{sky and 1 or 0,sky and sky.canopy or 0,V.require('Sky').clock or 0})
  end
  if shader:hasUniform('localSceneTint') then
    shader:send('localSceneTint',enabled and frame.tint or {1,1,1})
  end
  local portals=enabled and frame.portals or {}
  local ps=enabled and frame.portalSky
  if shader:hasUniform('localPortalCount') then
    shader:send('localPortalCount',#portals)
    local SM=#portals>0 and V.require('ShadowMap')
    local shadow=SM and V.require('Shadows').enabled() and SM.active()
    shader:send('localPortalDepth',shadow and SM.texture() or emptyWall())
    shader:send('localPortalVP','row',shadow and SM.uvVP or {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1})
    shader:send('localPortalShadow',{shadow and 1 or 0,SM and SM.bias or .002,SM and 1/SM.res or 0})
    local dir=ps and ps.direction or {0,1,0,0}
    shader:send('localPortalSun',{dir[1],dir[2],dir[3],dir[4]*(ps and ps.moon==1 and .40 or 1.9)})
    shader:send('localPortalColor',enabled and frame.portalColor or {1,1,1})
    for i,p in ipairs(portals)do
      local q=p.position
      shader:send('localPortalP'..(i-1),{q[1],q[2],q[3],p.axis})
      shader:send('localPortalRect'..(i-1),p.rect)
      shader:send('localPortalN'..(i-1),p.normal)
    end
  end
  if shader:hasUniform('localVisibility') then
    local visibility=emptyWall()
    if enabled then
      local ok,result=pcall(V.require('LightVisibility').prepare,frame,M,visibility)
      if ok then visibility=result else M.fail(result);return M.send(shader,false) end
    end
    shader:send('localVisibility',visibility)
  end
  if shader:hasUniform('localPortalVolume') then
    shader:send('localPortalVolume',frame.map and {frame.map.def.width*32,frame.map.def.height*32} or {1,1})
  end
  shader:send('localLightCount',#lights)
  for i,l in ipairs(lights) do
    local n=l.normal
    local color=l.color or warm
    shader:send('localPos'..(i-1),{l.x,l.y,l.z,l.radius})
    shader:send('localDir'..(i-1),{n[1],n[2],n[3],l.owner.index or 0})
    shader:send('localTint'..(i-1),{color[1],color[2],color[3],l.power*l.weight*.72})
  end
  sent[shader]={frame=frame,enabled=enabled}
  return true
end
-- A renderer reset retires all GPU textures owned by this lighting pass.
-- Forget uniform receipts as well, so surviving card shaders get fresh ones.
function M.invalidate()
  V.require('LightVisibility').invalidate()
  for _,wall in pairs(wallFields)do wall.texture:release()end
  wallFields=setmetatable({},{__mode='k'})
  if blankWall then blankWall:release();blankWall=nil end
  sent=setmetatable({},{__mode='k'})
  M.failure=nil
  M.clear(true)
end
return M
