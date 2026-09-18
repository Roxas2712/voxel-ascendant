-- Experimental runtime separation of the generated mother pose sheet.
-- The body plate is shared across all views; source PNGs are never changed.
local M={}
function M.new(texture,frames,own,headOnly)
 own=own or function(v)return v end
 local shader=own(love.graphics.newShader([[
 extern vec4 cell;extern float bodyPass;extern vec4 otherCell;
 vec4 sampleCell(Image t,vec2 p,vec4 c){
  vec2 localPixel=p+vec2(c.z,c.w);
  if(localPixel.x<0.0||localPixel.x>=512.0||localPixel.y<0.0||localPixel.y>=512.0)return vec4(0.0);
  return Texel(t,(localPixel+c.xy*512.0)/vec2(1536.0,1024.0));
 }
 float hair(vec4 c){return c.a>.05&&c.r>c.g*1.35&&c.g>c.b*1.35?1.0:0.0;}
 float head(Image t,vec2 p,vec4 c,vec4 pixel){
  if(p.y< -276.0)return 1.0;
  if(p.y< -254.0&&abs(p.x)<25.0)return 1.0;
  if(p.y> -214.0||abs(p.x)<20.0||abs(p.x)>110.0)return 0.0;
  float mask=hair(pixel);
  if(max(pixel.r,max(pixel.g,pixel.b))<.28){
   mask=max(mask,hair(sampleCell(t,p+vec2(2.0,0.0),c)));
   mask=max(mask,hair(sampleCell(t,p-vec2(2.0,0.0),c)));
   mask=max(mask,hair(sampleCell(t,p+vec2(0.0,2.0),c)));
   mask=max(mask,hair(sampleCell(t,p-vec2(0.0,2.0),c)));
  }
  return mask;
 }
 vec4 effect(vec4 color,Image t,vec2 uv,vec2 screen){
  vec2 p=uv*512.0-vec2(256.0,480.0);
  vec4 a=sampleCell(t,p,cell);
  // Source-authored empty space under the hair tuft was painted white.
  // Limit the matte correction to the top tuft; eyes and clothes stay intact.
  if(p.y< -385.0&&min(a.r,min(a.g,a.b))>.80)a.a=0.0;
  float mask=head(t,p,cell,a);
  if(bodyPass<.5)return vec4(a.rgb,a.a*mask);
  a.a*=1.0-mask;
  vec4 b=sampleCell(t,p,otherCell);b.a*=1.0-head(t,p,otherCell,b);
  float alpha=a.a+b.a*(1.0-a.a);
  return alpha>.0?vec4((a.rgb*a.a+b.rgb*b.a*(1.0-a.a))/alpha,alpha):vec4(0.0);
 }
 ]]))
 local heads={};local body
 local function cell(f)return {f.col,f.row,f.footX,f.bottom}end
 local function make(f,isBody)
  local canvas=own(love.graphics.newCanvas(512,512));canvas:setFilter('linear','linear')
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.origin();love.graphics.setScissor();love.graphics.setDepthMode();love.graphics.clear(0,0,0,0)
  love.graphics.setColor(1,1,1);love.graphics.setShader(shader);love.graphics.setBlendMode('replace','premultiplied')
  shader:send('cell',cell(f));shader:send('otherCell',cell(frames[5]));shader:send('bodyPass',isBody and 1 or 0)
  love.graphics.draw(texture,0,0,0,512/texture:getWidth(),512/texture:getHeight())
  love.graphics.pop();return canvas
 end
 if not headOnly then body=make(frames[1],true)end
 for i,f in ipairs(frames)do heads[i]=make(f,false)end
 shader:release()
 local api={body=body,heads=heads}
 function api:draw(index,x,y,scale)
  love.graphics.push('all');love.graphics.setColor(1,1,1);love.graphics.setBlendMode('alpha','alphamultiply')
  if body then love.graphics.draw(body,x-256*scale,y-480*scale,0,scale,scale)end
  love.graphics.draw(assert(heads[index]),x-256*scale,y-480*scale,0,scale,scale)
  love.graphics.pop()
 end
 return api
end
return M
