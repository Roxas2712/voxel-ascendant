-- Only the packaged large background images use JPEG plus a lossless alpha mask.
-- Logical PNG paths stay stable for map data and arena selection. Other assets
-- use the engine loader unchanged; no engine-global image hooks are installed.
local V = ...
local manifest = V.require('CompactBackgroundManifest')
local Assets = require('src.render.Assets')
local M = { stats={loads=0,gpuMerges=0,cpuFallbacks=0} }
local shader
local function release(x) if x and x.release then pcall(x.release,x) end end
local function specFor(path)
  if type(path)~='string' then return end
  local prefix=V.path..'/'
  if path:sub(1,#prefix)~=prefix then return end
  return manifest[path:sub(#prefix+1)]
end
function M.has(path) return specFor(path)~=nil end
local function gpuMerge(rgb,mask,w,h)
  local g=love.graphics
  local color,alpha,canvas,out,pushed
  local ok,err=pcall(function()
    if not shader then shader=g.newShader([[
      extern Image alphaMask;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
        return vec4(Texel(tex,uv).rgb,Texel(alphaMask,uv).r);
      }
    ]]) end
    color=g.newImage(rgb,{linear=true});alpha=g.newImage(mask,{linear=true})
    color:setFilter('nearest','nearest');alpha:setFilter('nearest','nearest')
    canvas=g.newCanvas(w,h,{format='rgba8',readable=true,msaa=0})
    g.push('all');pushed=true;g.origin();g.setCanvas(canvas)
    g.setScissor();g.setStencilTest();g.setColorMask(true,true,true,true)
    g.clear(0,0,0,0);g.setColor(1,1,1,1)
    g.setBlendMode('replace','premultiplied');g.setShader(shader)
    shader:send('alphaMask',alpha);g.draw(color,0,0)
    g.pop();pushed=false
    out=canvas:newImageData()
    assert(out:getWidth()==w and out:getHeight()==h,'background merge dimensions')
  end)
  if pushed then pcall(g.pop) end
  -- Shader uniforms retain their texture; release this transient shader too.
  release(shader);shader=nil
  release(color);release(alpha);release(canvas)
  if not ok then release(out);return nil,err end
  return out
end
function M.imageData(path)
  local spec=specFor(path)
  if not spec then return Assets.imageData(path) end
  local rgb,mask,out
  local ok,err=pcall(function()
    rgb=Assets.imageData(V.path..'/'..spec.jpeg)
    assert(rgb:getWidth()==spec.width and rgb:getHeight()==spec.height,'background JPEG dimensions')
    assert(rgb:getFormat()=='rgba8','background JPEG format')
    if spec.alpha then
      mask=Assets.imageData(V.path..'/'..spec.alpha)
      assert(mask:getWidth()==spec.width and mask:getHeight()==spec.height,'background alpha dimensions')
      out=M.gpuMerge(rgb,mask,spec.width,spec.height)
      if out then M.stats.gpuMerges=M.stats.gpuMerges+1 else
        -- Cold/unsupported GPU readback must not turn a valid scene into 2D.
        rgb:mapPixel(function(x,y,r,g,b) local a=mask:getPixel(x,y);return r,g,b,a end)
        out=rgb;rgb=nil;M.stats.cpuFallbacks=M.stats.cpuFallbacks+1
      end
    else out=rgb;rgb=nil end
  end)
  release(rgb);release(mask)
  if not ok then release(out);error(err,0) end
  M.stats.loads=M.stats.loads+1
  return out
end
M.gpuMerge=gpuMerge
function M.newImage(path,...)
  if not specFor(path) then return love.graphics.newImage(path,...) end
  local data=M.imageData(path)
  local ok,img=pcall(love.graphics.newImage,data,...)
  release(data)
  if not ok then error(img,0) end
  return img
end
return M
