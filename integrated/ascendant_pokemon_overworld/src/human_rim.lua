-- Shared, opt-in source-rim cleanup for reviewed human atlases. No source
-- texture is changed; rig and eyelid canvases apply the same sampling rule.
-- Soft-edge profiles retain alpha and recolor only translucent gray fringe
-- beside a verified dark contour. Opaque artwork and clothing stay intact.
local M={}
M.shader=[[
 extern vec4 rimShape;extern float rimSoftEdge;extern vec4 rimTrimBottom;
 bool rimPale(vec4 p){return p.a>.1 && min(p.r,min(p.g,p.b))>.78 && max(p.r,max(p.g,p.b))-min(p.r,min(p.g,p.b))<.12;}
 bool rimBoundary(Image t,vec2 uv,vec2 d){
  vec4 outside=Texel(t,uv+d),inside=Texel(t,uv-d);
  vec4 outside2=Texel(t,uv+2.0*d),inside2=Texel(t,uv-2.0*d);
  bool edge=outside.a<.05 || (rimPale(outside)&&outside2.a<.05);
  bool dark=(inside.a>.65&&max(inside.r,max(inside.g,inside.b))<.62)||(inside2.a>.65&&max(inside2.r,max(inside2.g,inside2.b))<.62);
  return edge&&dark;
 }
 vec4 rimInterior(Image t,vec2 uv,vec2 d,vec4 best){
  vec4 q=Texel(t,uv+d);
  if(q.a>.65 && q.a>best.a && max(q.r,max(q.g,q.b))<.62)return q;
  return best;
 }
 vec4 sourceRim(Image t,vec2 uv,vec4 p){
  float sourceRow=floor(uv.y*4.0);float localY=uv.y*4.0-sourceRow;
  float trim=sourceRow<0.5?rimTrimBottom.x:(sourceRow<1.5?rimTrimBottom.y:(sourceRow<2.5?rimTrimBottom.z:rimTrimBottom.w));
  if(trim>0.0&&localY>=trim)return vec4(0.0);
  bool region=rimShape.w>0.0 && mod(uv.y/rimShape.y,rimShape.z)<rimShape.w;
  if(!region)return p;
  float hi=max(p.r,max(p.g,p.b)),lo=min(p.r,min(p.g,p.b));
  if(rimSoftEdge>.5){if(!(p.a>.01 && p.a<.75 && lo>.4 && hi-lo<.15))return p;}
  else if(!rimPale(p))return p;
  bool boundary=(rimBoundary(t,uv,vec2(rimShape.x,0.0))||rimBoundary(t,uv,vec2(-rimShape.x,0.0))
      ||rimBoundary(t,uv,vec2(0.0,rimShape.y))||rimBoundary(t,uv,vec2(0.0,-rimShape.y)));
  if(rimSoftEdge>.5){
   if(boundary && p.a>.01 && p.a<.75 && lo>.4 && hi-lo<.15){
    vec4 inside=vec4(0.0);
    inside=rimInterior(t,uv,vec2(rimShape.x,0.0),inside);
    inside=rimInterior(t,uv,vec2(-rimShape.x,0.0),inside);
    inside=rimInterior(t,uv,vec2(0.0,rimShape.y),inside);
    inside=rimInterior(t,uv,vec2(0.0,-rimShape.y),inside);
    inside=rimInterior(t,uv,vec2(2.0*rimShape.x,0.0),inside);
    inside=rimInterior(t,uv,vec2(-2.0*rimShape.x,0.0),inside);
    inside=rimInterior(t,uv,vec2(0.0,2.0*rimShape.y),inside);
    inside=rimInterior(t,uv,vec2(0.0,-2.0*rimShape.y),inside);
    if(inside.a>.65)return vec4(inside.rgb,p.a);
   }
   return p;
  }
  if(boundary && rimPale(p))return vec4(0.0);
  return p;
 }

]]
function M.send(shader,w,h,profile)
 local extent=profile and tonumber(profile.rimHeadEnd) or 0
 local enabled=w==495 and h==900 and extent>0 and extent<=165
 local trim={0,0,0,0}
 if profile and w==495 and h==900 and type(profile.trimBottomRows)=='table' then
  for row=0,3 do
   local v=profile.trimBottomRows[row]
   if type(v)=='number' and v>0 and v<1 then trim[row+1]=v end
  end
 end
 shader:send('rimShape',{1/w,1/h,h/4,enabled and extent or 0})
 shader:send('rimSoftEdge',enabled and profile.rimSoftEdge and 1 or 0)
 shader:send('rimTrimBottom',trim)
end

-- The reviewed youngster has matte fragments around his head and hands.
-- Clean that source once for every animation mode, including classic cards.
-- Keep the source asset, bounds, eyes, socks and shoes unchanged. These exact
-- three atlases share the same silhouette; no other art opts in implicitly.
function M.prepare(texture,path)
 local name=type(path)=='string' and path:match('([^/]+)$')
 if name~='youngster-gen1-bald-hd-4x3-walk-sheet-v1.png'
  and name~='youngster-gen1-bald-hd-4x3-walk-sheet-v1-bald-green.png'
  and name~='youngster-gen1-bald-hd-4x3-walk-sheet-v1-bald-red.png' then return end
 local w,h=texture:getDimensions()
 if w~=495 or h~=900 then return end
 local g=love.graphics
 local shader=g.newShader(M.shader..[[
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){return sourceRim(t,uv,Texel(t,uv))*c;}
 ]])
 local canvas=g.newCanvas(w,h)
 g.push('all')
 local ok,err=pcall(function()
  g.setCanvas(canvas);g.origin();g.setScissor();g.setDepthMode()
  g.clear(0,0,0,0);g.setColor(1,1,1,1)
  g.setBlendMode('replace','premultiplied');g.setShader(shader)
  M.send(shader,w,h,{rimHeadEnd=165});g.draw(texture)
 end)
 g.pop();shader:release()
 if not ok then canvas:release();error(err)end
 local min,mag,aniso=texture:getFilter();canvas:setFilter(min,mag,aniso)
 return canvas
end
return M
