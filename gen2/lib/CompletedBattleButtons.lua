-- Optional completed ORAS art. Original assets are never rewritten. Convert
-- the generated solid-magenta backing to alpha once, at native sprite scale.
local M = {cache={}}
local bounds = {
  de_bag={310,46,1224,744}, de_mega={93,148,1069,969},
  de_pokemon={99,100,1054,1044}, de_run={385,81,1213,625},
  en_bag={64,111,1320,855}, en_mega={112,156,1028,945},
  en_pokemon={107,105,1036,1029}, en_run={311,84,1348,644},
}
local shader
function M.image(path, original, loader)
  if not original then return nil end
  if M.cache[path] ~= nil then return M.cache[path] or original end
  local G = love and love.graphics
  if not (G and G.newShader and G.newCanvas and G.newImage) then return original end
  local source = loader(path)
  if not source then M.cache[path]=false; return original end
  local previous = G.getCanvas()
  G.push("all")
  local ok, result = pcall(function()
    if not shader then shader=G.newShader([[
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
        vec4 p = Texel(tex, uv);
        if (min(p.r,p.b) > 0.55 && min(p.r,p.b)-p.g > 0.47 && abs(p.r-p.b) < 0.255)
          return vec4(0.0);
        return p * color;
      }
    ]]) end
    local crop = bounds[path:match("([^/]+)%.png$")]
      or {0,0,source:getWidth(),source:getHeight()}
    local w = original:getWidth()
    local h = math.max(1, math.floor(w*crop[4]/crop[3]+.5))
    local quad = G.newQuad(crop[1],crop[2],crop[3],crop[4],source:getDimensions())
    local canvas = G.newCanvas(w,h)
    G.setCanvas(canvas);G.origin();G.setScissor();G.clear(0,0,0,0)
    G.setShader(shader);G.setBlendMode("replace");G.setColor(1,1,1,1)
    G.draw(source,quad,0,0,0,w/crop[3],h/crop[4])
    G.setCanvas(previous)
    local data = canvas:newImageData()
    local image = G.newImage(data)
    image:setFilter("linear","linear")
    data:release();canvas:release();quad:release()
    return image
  end)
  G.setCanvas(previous);G.pop()
  M.cache[path] = ok and result or false
  return ok and result or original
end
return M
