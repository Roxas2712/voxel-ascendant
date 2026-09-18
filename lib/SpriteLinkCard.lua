-- A device-independent link card when the engine exposes no clipboard/browser API.
-- The QR points only to the public package page, never to a code or credential.
local M={}
function M.new(game,matrix,id)
  assert(type(matrix)=='table' and #matrix>=21)
  local G=love.graphics;local vertices={}
  for y,row in ipairs(matrix)do for x=1,#row do if row:sub(x,x)=='1' then
    local a,b=x-1,y-1
    for _,v in ipairs({{a,b},{a+1,b},{a+1,b+1},{a,b},{a+1,b+1},{a,b+1}})do vertices[#vertices+1]={v[1],v[2],0,0,0,0,0,1}end
  end end end
  local mesh=G.newMesh(vertices,'triangles','static')
  local self={opaque=true,age=0}
  function self:update(dt)
    self.age=self.age+(dt or 0)
    if self.age>.25 and game.input and (game.input:wasPressed('a') or game.input:wasPressed('b'))then
      game.stack:pop();if mesh then mesh:release();mesh=nil end
    end
  end
  function self:draw()
    local canvas=G.getCanvas();local w,h
    if canvas then w,h=canvas:getDimensions()else w,h=G.getDimensions()end
    G.push('all');G.origin();G.setScissor();G.setShader();G.setColor(.04,.07,.12,1);G.rectangle('fill',0,0,w,h)
    local scale=math.max(1,math.floor(math.min(w-16,h-32)/#matrix));local size=#matrix*scale
    local x,y=math.floor((w-size)/2),math.floor((h-size)/2)
    G.setColor(1,1,1,1);G.rectangle('fill',x,y,size,size)
    if mesh then G.draw(mesh,x,y,0,scale,scale)end
    G.setColor(1,1,1,1);G.printf('DOWNLOAD LINKS',4,4,w-8,'center')
    G.printf('SCAN / A/B: BACK',4,h-12,w-8,'center')
    G.pop()
  end
  return self
end
return M
