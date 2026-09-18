-- Registered two-view turns. Exact profile ownership is supplied by HumanActing.
local M={}
local shaderSource=[=[extern Image otherView;
extern Image forwardFlow;
extern Image backwardFlow;
extern float progress;
extern float blinkAmount;
extern vec4 eye0;extern vec4 eye1;
vec4 eyelid(Image tex,vec2 p,vec4 eye,vec4 original){
 if(blinkAmount<=0.0 || eye.z<=eye.x)return original;
 vec2 pixel=vec2(1.0/256.0);
 vec2 raw=(p-eye.xy)/(eye.zw-eye.xy);
 if(raw.x<-.15 || raw.x>1.15 || raw.y<0.0 || raw.y>1.25)return original;
 vec3 skin=Texel(tex,vec2((eye.x+eye.z)*.5,eye.w+2.0*pixel.y)).rgb;
 float curve=.78-.1*(raw.x*2.0-1.0)*(raw.x*2.0-1.0);
 float distance=abs(raw.y-curve)*(eye.w-eye.y)/pixel.y;
 float ink=(1.0-smoothstep(.25,.8,distance))*smoothstep(0.0,.15,min(raw.x,1.0-raw.x));
 float edge=smoothstep(eye.x-pixel.x,eye.x,p.x)*(1.0-smoothstep(eye.z,eye.z+pixel.x,p.x));
 edge*=smoothstep(eye.y,eye.y+pixel.y*.5,p.y)*(1.0-smoothstep(eye.w,eye.w+pixel.y*2.0,p.y));
 float sweep=blinkAmount*1.2-.1+.05*(1.0-pow(raw.x*2.0-1.0,2.0));
 if(blinkAmount<.995)edge*=1.0-smoothstep(sweep-.05,sweep+.05,raw.y);
 return vec4(mix(original.rgb,mix(skin,vec3(.10,.07,.055),ink),edge),original.a);
}
vec4 restingView(Image tex,vec2 p){
 vec4 v=Texel(tex,p);v=eyelid(tex,p,eye0,v);return eyelid(tex,p,eye1,v);
}

vec4 sampleView(Image tex, vec2 p) {
 if(p.x<0.0||p.y<0.0||p.x>=1.0||p.y>=1.0)return vec4(0.0);
 return Texel(tex,p);
}
vec4 effect(vec4 color, Image tex, vec2 p, vec2 screen) {
 if(progress<=0.0)return restingView(tex,p);
 if(progress>=1.0)return restingView(otherView,p);
 if(p.y>=240.0/256.0)return vec4(0.0);
 vec2 a=p,b=p;
 for(int i=0;i<3;i++) {
  vec2 f=Texel(forwardFlow,clamp(a,vec2(0.0),vec2(1.0))).rg;
  vec2 r=Texel(backwardFlow,clamp(b,vec2(0.0),vec2(1.0))).rg;
  float foot=1.0-smoothstep(220.0/256.0,240.0/256.0,p.y);
  f.y*=foot;r.y*=foot;
  a=p-progress*f;
  b=p-(1.0-progress)*r;
 }
 vec4 A=sampleView(tex,a),B=sampleView(otherView,b);
 float alpha=mix(A.a,B.a,progress);
 return alpha>.00001?vec4(mix(A.rgb*A.a,B.rgb*B.a,progress)/alpha,alpha):vec4(0.0);
}
]=]
function M.new(root,profile,idle)
 local owned={}
 local function own(r)owned[#owned+1]=r;return r end
 local function release()
  for i=#owned,1,-1 do owned[i]:release();owned[i]=nil end
 end
 local ok,result=pcall(function()
  local function bytes(name)
   local data=assert(love.filesystem.read(root..'/'..profile.path..'/'..name))
   assert(love.data.encode('string','hex',love.data.hash('sha256',data))==profile.hashes[name],'turn source hash mismatch')
   return data
  end
  local function image(name)
   local file=love.filesystem.newFileData(bytes(name),name)
   local ok,im=pcall(love.graphics.newImage,file);file:release();assert(ok,im)
   own(im);assert(im:getWidth()==256 and im:getHeight()==256,'turn view dimensions')
   im:setFilter('linear','linear');return im
  end
  local a,b=image('source-1.png'),image('source-2.png')
  local function flow(name)
   local data=bytes(name);assert(#data==128*128*16,'turn flow dimensions')
   local d=love.image.newImageData(128,128,'rgba32f',data)
   local ok,im=pcall(love.graphics.newImage,d);d:release();assert(ok,im)
   own(im);im:setFilter('linear','linear');return im
  end
  local forward,backward=flow('forward.bin'),flow('backward.bin')
  local shader=own(love.graphics.newShader(shaderSource))
  shader:send('otherView',b);shader:send('forwardFlow',forward);shader:send('backwardFlow',backward)
  local canvas=own(love.graphics.newCanvas(256,256));canvas:setFilter('linear','linear')
  local bound={left=0,right=256,top=16,bottom=240,imageWidth=256,imageHeight=256}
  local source={id=root..'/'..profile.path..'#turn',texture=canvas,bounds={}}
  for r=0,3 do source.bounds[r]={};for c=0,2 do source.bounds[r][c]=bound end end
  local api={updates=0,progress=0,blinkAmount=0};local sprite,last,rendered,renderedBlink
  local blinkState={}
  function api:reset()sprite=nil;last=nil;self.progress=0;self.blinkAmount=0;blinkState={} end
  function api:prepare(actorSprite,direction,now,initialDirection)
   if self.error then return end
   local target=direction==profile.to and 1 or direction==profile.from and 0 or nil
   if target==nil or type(now)~='number' or now~=now or math.abs(now)==math.huge then self:reset();return end
   if sprite~=actorSprite then
    self:reset();sprite=actorSprite
    -- Start from an observed matching view when available. With no observed
    -- view, adopt the requested endpoint rather than invent a visible turn.
    local initial=initialDirection==profile.from and 0 or initialDirection==profile.to and 1 or nil
    self.progress=initial~=nil and initial or target
   end
   local dt=last and math.max(0,math.min(.1,now-last))or 0;last=now
   self.progress=self.progress+(target-self.progress)*(1-math.exp(-14*dt))
   if math.abs(target-self.progress)<.002 then self.progress=target end
   local eyes=profile.eyes and profile.eyes[self.progress==0 and 1 or self.progress==1 and 2 or 0]
   self.blinkAmount=idle and idle.blink(blinkState,now,eyes~=nil,.61)or 0
   if rendered~=self.progress or renderedBlink~=self.blinkAmount then
    love.graphics.push('all')
    local ok,err=pcall(function()
     shader:send('progress',self.progress)
     shader:send('blinkAmount',self.blinkAmount)
     for i=1,2 do
      local eye=eyes and eyes[i]or {0,0,0,0}
      shader:send('eye'..(i-1),{eye[1]/256,eye[2]/256,eye[3]/256,eye[4]/256})
     end
     love.graphics.setCanvas(canvas);love.graphics.origin();love.graphics.setScissor();love.graphics.setDepthMode()
     love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1)
     love.graphics.setBlendMode('replace','premultiplied');love.graphics.setShader(shader);love.graphics.draw(a)
    end)
    love.graphics.pop()
    if not ok then self.error=err;self:reset();return end
    rendered=self.progress;renderedBlink=self.blinkAmount;self.updates=self.updates+1
   end
   return source
  end
  function api:restore()self:reset();release()end
  return api
 end)
 if not ok then release();return nil,result end
 return result
end
return M
