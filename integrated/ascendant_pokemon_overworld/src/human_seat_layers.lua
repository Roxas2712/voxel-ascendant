-- Disposable seated-pose experiment. This does not alter native actor state.
local M={}
function M.new(seat,morph,own)
 own=own or function(v)return v end
 local bodyShader=own(love.graphics.newShader([[
 vec4 effect(vec4 color,Image t,vec2 uv,vec2 screen){
  vec4 c=Texel(t,uv);vec2 p=uv*vec2(1024.0,1536.0);
  // Keep the authored shoulders and collar below the chin. The moving
  // head overlaps this plate; cutting at 605 removed the shoulder tops.
  if(p.y<550.0)return vec4(0.0);
  if(p.x<440.0&&p.y<685.0&&c.r>c.g*1.35&&c.g>c.b*1.35)c=Texel(t,vec2(1.0-uv.x,uv.y));
  return c;
 }
 ]]))
 local blinkShader=own(love.graphics.newShader([[
 extern float closure;extern vec4 blinkEye0;extern vec4 blinkEye1;
 vec4 eyelid(Image tex,vec2 uv,vec4 p,vec4 eye){
  if(eye.z<=eye.x)return p;
  vec2 pixel=uv*512.0;
  vec2 mid=(eye.xy+eye.zw)*.5;
  vec2 radius=(eye.zw-eye.xy)*.5;
  vec2 local=(pixel-mid)/radius;
  float edge=length(max(abs(local)-vec2(.65,.7),vec2(0.0)))/.3;
  float mask=1.0-smoothstep(.5,1.0,edge);
  float sweep=closure*1.35-.1;
  mask*=1.0-smoothstep(sweep-.035,sweep+.035,(pixel.y-eye.y)/(eye.w-eye.y));
  vec3 skin=Texel(tex,vec2(256.0,157.0)/512.0).rgb;
  float lineY=eye.y+(eye.w-eye.y)*min(sweep,.72);
  lineY-=1.5*(1.0-local.x*local.x);
  float ink=(1.0-smoothstep(.55,1.15,abs(pixel.y-lineY)))*(1.0-smoothstep(.68,1.0,abs(local.x)));
  vec3 lid=mix(skin,vec3(.20,.11,.07),ink);
  return vec4(mix(p.rgb,lid,mask),p.a);
 }
 vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen){
  vec4 p=Texel(tex,uv);
  p=eyelid(tex,uv,p,blinkEye0);
  p=eyelid(tex,uv,p,blinkEye1);
  return p*color;
 }
 ]]))
 local body=own(love.graphics.newCanvas(512,768));local texture=own(love.graphics.newCanvas(512,768))
 love.graphics.push('all');love.graphics.setCanvas(body);love.graphics.origin();love.graphics.setScissor();love.graphics.setDepthMode();love.graphics.clear(0,0,0,0)
 love.graphics.setColor(1,1,1);love.graphics.setBlendMode('replace','premultiplied');love.graphics.setShader(bodyShader)
 love.graphics.draw(seat,0,0,0,.5,.5);love.graphics.pop();bodyShader:release()
 local eyes={
  [1]={{211,140,244,180},{263,139,297,180}},
  [3]={{265,137,300,179},{302,140,311,168}},
  [6]={{209,137,250,179},{193,141,203,169}},
 }
 local api={texture=texture,body=body,updates=0}
 function api:update(a,b,t,blink)
  local eye=eyes[t==0 and a or t==1 and b or false]
  blink=eye and (blink or 0) or 0
  if a==self.a and b==self.b and t==self.t and blink==self.blink then return end
  love.graphics.push('all');love.graphics.setCanvas(texture);love.graphics.origin();love.graphics.setShader();love.graphics.setScissor();love.graphics.setDepthMode()
  love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1);love.graphics.setBlendMode('alpha','alphamultiply');love.graphics.draw(body)
  if blink>0 then blinkShader:send('closure',blink);blinkShader:send('blinkEye0',eye[1]);blinkShader:send('blinkEye1',eye[2]);love.graphics.setShader(blinkShader)end
  morph:draw(a,b,t,256,623.85,1.275,true)
  love.graphics.pop();self.a,self.b,self.t,self.blink=a,b,t,blink;self.updates=self.updates+1
 end
 -- Warm the actual lid draw before the co-operative builder publishes the pose.
 api:update(1,2,0,1);api:update(1,2,0,0);return api
end
return M
