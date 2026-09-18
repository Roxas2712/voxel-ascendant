-- Optional human eyelid presentation. Original bodies and native game state
-- remain untouched. Source-reviewed layouts; caller owns scene admission.
local Blink={}
local PACKED_SHADER=[=[

 extern Image closed;extern vec2 closedSize;
 extern vec4 eye0;extern vec4 eye1;
 extern vec2 pixel; extern vec2 offset0; extern vec2 offset1;
 extern float reverse;
 extern float amount;extern float cleanUpper;
 vec4 packedLid(vec2 uv,vec4 eye,vec2 slot){return Texel(closed,(uv*closedSize+slot)/vec2(256.0,384.0));}
 vec4 blink(Image tex,vec2 uv,vec4 p,vec4 eye,float direction,vec2 offset){
  if(eye.z<=eye.x || amount<=0.0)return p;
  vec2 pad=pixel*4.0;
  vec2 v=(uv-eye.xy+pad)/max(eye.zw-eye.xy+2.0*pad,vec2(.00001));
  if(v.x<0.0 || v.x>1.0 || v.y<0.0 || v.y>1.0)return p;
  vec4 lid=packedLid(uv,eye,offset);
  vec2 skinUV=vec2((eye.x+eye.z)*.5,eye.w+3.0*pixel.y);
  vec3 gain=clamp(Texel(tex,skinUV).rgb/max(packedLid(skinUV,eye,offset).rgb,vec3(.05)),vec3(.65),vec3(1.4));
  vec3 rgb=lid.rgb*gain;
  float rawY=(uv.y-eye.y)/(eye.w-eye.y);
  rgb=mix(rgb,mix(Texel(tex,skinUV).rgb,rgb,smoothstep(.38,.58,rawY)),cleanUpper);
  float edge=1.0-smoothstep(.65,1.0,length((v-.5)*2.0));
  edge*=smoothstep(eye.y-pixel.y*.5,eye.y+pixel.y*.5,uv.y);
  // Sweep the lid over the original iris; never rescale eye pixels.
  float rawX=(uv.x-eye.x)/(eye.z-eye.x);
  float lateral=rawX*2.0-1.0;
  float sweep=amount*1.2-.1+.05*(1.0-lateral*lateral);
  float feather=pixel.y/(eye.w-eye.y)*.65;
  if(amount<.995)edge*=1.0-smoothstep(sweep-feather,sweep+feather,(uv.y-eye.y)/(eye.w-eye.y));
  return vec4(mix(p.rgb,rgb,edge),p.a);
 }
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){vec4 p=sourceRim(t,uv,Texel(t,uv));p=blink(t,uv,p,eye0,reverse,offset0);p=blink(t,uv,p,eye1,-1.0,offset1);return p*c;}
 ]=]
local PROCEDURAL_SHADER=[=[

 extern vec4 eye0;extern vec4 eye1;extern vec4 clipA0;extern vec4 clipB0;extern vec4 clipA1;extern vec4 clipB1;extern vec4 clipC0;extern vec4 clipD0;extern vec4 clipC1;extern vec4 clipD1;extern vec2 skinSample0;extern vec2 skinSample1;extern vec2 lidStart0;extern vec2 lidStart1;extern vec2 pixel;extern float reverse;extern float amount;extern float coloredIris;
 // Convex eight-point apertures are source-reviewed. Pixel-space tolerance
 // includes boundary pixel centres despite normalized-UV rounding.
 float clipSide(vec2 p,vec2 a,vec2 b){return ((p.x-a.x)*(b.y-a.y)-(p.y-a.y)*(b.x-a.x))/(pixel.x*pixel.y);}
 vec4 blink(Image tex,vec2 uv,vec4 p,vec4 eye,float direction,vec2 lidStart,vec4 clipA,vec4 clipB,vec4 clipC,vec4 clipD,vec2 skinSample){
  if(clipA.x>=0.0){
   float a=clipSide(uv,clipA.xy,clipA.zw),b=clipSide(uv,clipA.zw,clipB.xy);
   float c=clipSide(uv,clipB.xy,clipB.zw),d=clipSide(uv,clipB.zw,clipC.xy);
   float e=clipSide(uv,clipC.xy,clipC.zw),f=clipSide(uv,clipC.zw,clipD.xy);
   float g=clipSide(uv,clipD.xy,clipD.zw),h=clipSide(uv,clipD.zw,clipA.xy);
   if(min(min(min(a,b),min(c,d)),min(min(e,f),min(g,h)))<-.001 && max(max(max(a,b),max(c,d)),max(max(e,f),max(g,h)))>.001)return p;
  }
  if(eye.z<=eye.x || amount<=0.0)return p;
  vec2 pad=pixel*4.0;
  vec2 v=(uv-eye.xy+pad)/max(eye.zw-eye.xy+2.0*pad,vec2(.00001));
  if(v.x<0.0 || v.x>1.0 || v.y<0.0 || v.y>1.0)return p;
  vec2 raw=(uv-eye.xy)/(eye.zw-eye.xy);
  vec2 skinUV=vec2((eye.x+eye.z)*.5,eye.w+2.0*pixel.y);
  if(skinSample.x>=0.0)skinUV=skinSample;
  vec3 skin=Texel(tex,skinUV).rgb;
  if(skin.r<.45 || skin.g<.22 || skin.b<.12 || skin.g/skin.r<.55 || skin.b/max(skin.g,.01)<.52){
   skin=Texel(tex,vec2((eye.x+eye.z)*.5,eye.w+2.0*pixel.y)).rgb;
  }
  float curve=.78-.1*(raw.x*2.0-1.0)*(raw.x*2.0-1.0);
  float distance=abs(raw.y-curve)*(eye.w-eye.y)/pixel.y;
  float ink=(1.0-smoothstep(.25,.8,distance))*smoothstep(0.0,.15,min(raw.x,1.0-raw.x));
  vec3 rgb=mix(skin,vec3(.10,.07,.055),ink);
  float edge=1.0-smoothstep(.65,1.0,length((v-.5)*2.0));
  // Optional source-reviewed sloping eye edge, in atlas pixels. Zero is the
  // existing horizontal edge; retain the brow above it throughout closure.
  float top=eye.y+mix(lidStart.x,lidStart.y,clamp(raw.x,0.0,1.0))*pixel.y;
  edge*=smoothstep(top-.5*pixel.y,top+.5*pixel.y,uv.y);
  edge*=smoothstep(eye.x-pixel.x,eye.x,uv.x)*(1.0-smoothstep(eye.z,eye.z+pixel.x,uv.x));
  bool hair=p.r>.3 && ((p.g/p.r<.66 && p.b/max(p.g,.01)<.5) || (p.r/max(p.g,.01)>3.0 && p.b/max(p.g,.01)>1.1));
  // Only reviewed eye boxes may admit red iris pixels through the hair guard.
  bool iris=coloredIris>.5 && raw.x>=0.0 && raw.x<=1.0 && raw.y>=0.0 && raw.y<=1.0;
  if(hair && !iris)edge=0.0;
  // A reviewed mask aperture provides the contour; do not leave an iris halo.
  if(clipA.x>=0.0)edge=1.0;
  // Sweep the lid over the original iris; never rescale eye pixels.
  float rawX=(uv.x-eye.x)/(eye.z-eye.x);
  float lateral=rawX*2.0-1.0;
  float sweep=amount*1.2-.1+.05*(1.0-lateral*lateral);
  float feather=pixel.y/(eye.w-eye.y)*.65;
  if(amount<.995)edge*=1.0-smoothstep(sweep-feather,sweep+feather,(uv.y-eye.y)/(eye.w-eye.y));
  return vec4(mix(p.rgb,rgb,edge),p.a);
 }
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){vec4 p=sourceRim(t,uv,Texel(t,uv));p=blink(t,uv,p,eye0,reverse,lidStart0,clipA0,clipB0,clipC0,clipD0,skinSample0);p=blink(t,uv,p,eye1,-1.0,lidStart1,clipA1,clipB1,clipC1,clipD1,skinSample1);return p*c;}
 ]=]
function Blink.profileFor(profiles,role,path)
 local base=profiles[role]
 if not base or type(path)~='string' then return nil end
 local function matches(p)return path==p.path or path:sub(-#p.path-1)=='/'..p.path end
 local found=matches(base)and base or nil
 for _,p in ipairs(base.alternates or {})do
  if matches(p)then if found then return nil end;found=p end
 end
 return found
end
function Blink.new(Assets,root,profiles)
 local graphics=love.graphics
 local rim=Blink.rim
 local rimShader=rim and rim.shader or 'vec4 sourceRim(Image t,vec2 uv,vec4 p){return p;}'
 -- Retain at most 32 owners until eviction so every GPU object has an
 -- explicit release path, even when an actor leaves the world.
 local states={}
 local resources={};local serial=0;local proceduralShader;local shaders={}
 local warmFrame,warmCount
 local metrics={draws=0,renders=0,warmups=0,deferredWarmups=0,evictions=0,reuses=0}
 local api={metrics=metrics}
 local function release(state)
  if not state then return end
  if state.canvas then state.canvas:release();state.canvas=nil end
  for key,quad in pairs(state.quads or {})do quad:release();state.quads[key]=nil end
 end
 local function resource(role,profile)
  if resources[profile]==nil then
   local packedShader
   local ok,result=pcall(function()
    local r={}
    if profile.procedural then
     if not proceduralShader then
      proceduralShader=graphics.newShader(rimShader..PROCEDURAL_SHADER);shaders[proceduralShader]=true
     end
     r.shader=proceduralShader
    else
     packedShader=graphics.newShader(rimShader..PACKED_SHADER);shaders[packedShader]=true;r.shader=packedShader
    end
    if profile.packed then
     r.image=assert(Assets.image(root..'/assets/characters/expressions/'..role..'-eyelids.png'))
     local w,h=r.image:getDimensions();assert(w==256 and h==384,'unexpected eyelid atlas dimensions')
     r.image:setFilter('linear','linear')
    end
    return r
   end)
   resources[profile]=ok and result or false
   if not ok then
    api.error=result
    if packedShader then packedShader:release();shaders[packedShader]=nil end
   end
  end
  return resources[profile] or nil
 end
 function api:prepare(record,source,row,column)
  if not record or not record.humanMotion or not source then return nil end
  local embedded=source.humanBlink
  if not embedded and (row==2 or column~=0) then return nil end
  local role=record.def and record.def.ascendantRole or record.role
  local path=tostring(record.def and record.def.ascendantAtlasImage or '')
  local profile=embedded or Blink.profileFor(profiles,role,path)
  local profileRow=embedded and 0 or row
  if not profile or not profile.rows[profileRow] or not (profile.procedural or profile.packed)then return nil end
  local w,h=source.texture:getDimensions()
  if w~=profile.width or h~=profile.height then return nil end
  local amount=record.humanMotion.blinkAmount or 0
  if amount~=amount or amount<0 or amount>1 then return nil end
  -- Shader warmup belongs to the exact eye profile, not each actor. Otherwise
  -- an open-eyed crowd larger than the LRU limit churns canvases every frame.
  local cached=resources[profile]
  if amount<=0 and cached and cached.warmed then return nil end
  -- Different profiles used to warm synchronously on the first idle draw.
  -- Spread shader/image creation and the first offscreen render across
  -- presentation frames. A blink already in progress always renders
  -- immediately, so this scheduling is invisible.
  local observed=record.humanMotion.blinkObserved
  if amount<=0 and type(observed)=='number' then
   if warmFrame~=observed then warmFrame,warmCount=observed,0 end
   if warmCount>=1 then metrics.deferredWarmups=metrics.deferredWarmups+1;return nil end
   warmCount=warmCount+1
  end
  local r=resource(role,profile);if not r then return nil end
  if amount<=0 and r.warmed then return nil end
  serial=serial+1
  local state=states[record]
  if state and (state.source~=source.texture or state.sourceId~=source.id
      or state.role~=role or state.profile~=profile)then release(state);states[record]=nil;state=nil end
  if not state then
   local count,oldest,oldestKey=0,nil,nil
   for key,value in pairs(states)do
    count=count+1
    if not oldest or value.used<oldest.used then oldest,oldestKey=value,key end
   end
   local canvas,quads
   local canvasWidth,canvasHeight=profile.fullAtlas and w or w/3,profile.fullAtlas and h or h/4
   if count>=32 then
    -- A matching canvas/quad set can be repainted for the next owner. Reset
    -- all content metadata so equal blink amounts never reuse another face.
    if oldest.canvasWidth==canvasWidth and oldest.canvasHeight==canvasHeight then
     canvas,quads=oldest.canvas,oldest.quads
     oldest.canvas,oldest.quads=nil,nil;metrics.reuses=metrics.reuses+1
    end
    release(oldest);states[oldestKey]=nil;metrics.evictions=metrics.evictions+1
   end
   if not canvas then
    local ok,result=pcall(graphics.newCanvas,canvasWidth,canvasHeight)
    if not ok then self.error=result;return nil end
    canvas=result;canvas:setFilter('linear','linear')
   end
   state={canvas=canvas,source=source.texture,sourceId=source.id,role=role,profile=profile,
    width=w,height=h,canvasWidth=canvasWidth,canvasHeight=canvasHeight,
    quads=quads or {}};states[record]=state
  end
  state.used=serial
  -- Exercise the actual closed-eye shader path offscreen before the first blink.
  -- Later open-eye frames reuse the original texture without extra GPU work.
  if state.amount==nil or amount>0 and (state.amount~=amount or state.row~=profileRow)then
   local shader=r.shader
   local renderAmount=state.amount==nil and amount<=0 and 1 or amount
   graphics.push('all')
   local ok,err=pcall(function()
    graphics.setCanvas(state.canvas);graphics.origin();graphics.setScissor();graphics.setDepthMode()
    graphics.clear(0,0,0,0);graphics.setColor(1,1,1,1);graphics.setBlendMode('replace','premultiplied');graphics.setShader(shader)
    if profile.packed then
     shader:send('closed',r.image);shader:send('closedSize',profile.packed.size)
     shader:send('cleanUpper',role=='blue' and row==0 and 1 or 0)
    end
    if profile.procedural then shader:send('coloredIris',profile.coloredIris and 1 or 0)end
    if rim then rim.send(shader,w,h,profile)end
    shader:send('pixel',{1/w,1/h});shader:send('amount',renderAmount);shader:send('reverse',row==3 and -1 or 1)
    for i=1,2 do
     local e=profile.rows[profileRow][i]
     shader:send('eye'..(i-1),e and {e[1]/w,e[2]/h,e[3]/w,e[4]/h} or {0,0,0,0})
     if profile.procedural then
      local starts=profile.lidStarts and profile.lidStarts[profileRow]
      shader:send('lidStart'..(i-1),starts and starts[i] or {0,0})
      local clip=profile.eyeClips and profile.eyeClips[profileRow] and profile.eyeClips[profileRow][i]
      shader:send('clipA'..(i-1),clip and {clip[1]/w,clip[2]/h,clip[3]/w,clip[4]/h} or {-1,-1,-1,-1})
      shader:send('clipB'..(i-1),clip and {clip[5]/w,clip[6]/h,clip[7]/w,clip[8]/h} or {-1,-1,-1,-1})
      shader:send('clipC'..(i-1),clip and {clip[9]/w,clip[10]/h,clip[11]/w,clip[12]/h} or {-1,-1,-1,-1})
      shader:send('clipD'..(i-1),clip and {clip[13]/w,clip[14]/h,clip[15]/w,clip[16]/h} or {-1,-1,-1,-1})
      local sample=profile.skinSamples and profile.skinSamples[profileRow] and profile.skinSamples[profileRow][i]
      shader:send('skinSample'..(i-1),sample and {sample[1]/w,sample[2]/h} or {-1,-1})
     end
     if profile.packed then shader:send('offset'..(i-1),profile.packed.rows[profileRow][i] or {0,0})end
    end
    if profile.fullAtlas then
     graphics.draw(source.texture)
    else
     state.quads[profileRow]=state.quads[profileRow] or graphics.newQuad(0,profileRow*h/4,w/3,h/4,w,h)
     graphics.draw(source.texture,state.quads[profileRow])
    end
   end)
   graphics.pop()
   if not ok then self.error=err;release(state);states[record]=nil;resources[profile]=false;return nil end
   metrics.renders=metrics.renders+1
   if not r.warmed then metrics.warmups=metrics.warmups+1;r.warmed=true end
   state.amount,state.row=renderAmount,profileRow
  end
  if amount<=0 then return nil end
  metrics.draws=metrics.draws+1
  return state.canvas
 end
 function api:clear()
  for key,state in pairs(states)do release(state);states[key]=nil end
  for shader in pairs(shaders)do shader:release();shaders[shader]=nil end
  -- Assets.image returns shared textures; their lifetime belongs to Assets.
  resources={};proceduralShader=nil;serial=0;warmFrame,warmCount=nil,nil
 end
 return api
end
return Blink
