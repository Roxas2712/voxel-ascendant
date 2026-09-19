-- Supersample only the integrated map's final UI blit. Logical UI dimensions,
-- input, palette zones, final effects and the engine compositor stay native.
local M = {enabled=true}
local current, frame, paintedFrame, canvas, quality = nil, 0, nil, nil, nil

function M.release(owner)
  if owner and owner~=current then return end
  if canvas then pcall(canvas.release,canvas) end
  current,canvas,quality,paintedFrame,M.receipt=nil,nil,nil,nil,nil
end

function M.bind(MapScreen)
  if M.bound then return end
  M.bound=true
  local Renderer=require('src.render.Renderer')
  local paint=MapScreen.draw
  function MapScreen:draw(...)
    if current~=self then M.release();current=self end
    frame=frame+1
    return paint(self,...)
  end
  local oldExit=MapScreen.exit
  function MapScreen:exit(...)
    M.release(self)
    if oldExit then return oldExit(self,...) end
  end

  local blit=Renderer.blitCanvas
  function Renderer:blitCanvas(image,sx,sy,zones,zx,zy,bx,by,cx,cy,cw,ch,dx,dy)
    local owner=current
    local stack=owner and owner.game and owner.game.stack
    local top=stack and stack:top()
    local isMap=top==owner or (top and rawget(top,'_active')==owner
      and rawget(top,'_stage')=='wide')
    local isInfo=top and rawget(top,'__vascKantoMapOwner')==owner and owner~=nil
    if not (isMap or isInfo) then M.release();owner=nil end
    local q=math.max(1,math.min(4,math.ceil(math.max(
      math.abs(sx or 1)*(dx or 1),math.abs(sy or 1)*(dy or 1)))))
    if M.enabled and owner and image==self.canvas and q>1 then
      if quality~=q then
        if canvas then pcall(canvas.release,canvas) end
        canvas,quality,paintedFrame=nil,nil,nil
        local w,h=owner:uiSize()
        local ok,value=pcall(love.graphics.newCanvas,w*q,h*q,{dpiscale=1})
        if ok then
          canvas,quality=value,q
          canvas:setFilter('linear','linear')
        end
      end
      if canvas and paintedFrame~=frame then
        local g=love.graphics
        g.push('all')
        local prior=owner.__vascKantoHD
        local ok=pcall(function()
          g.setCanvas(canvas);g.origin();g.setShader();g.setScissor()
          g.setStencilTest();g.setDepthMode();g.setColorMask(true,true,true,true)
          g.setBlendMode('alpha');g.clear(0,0,0,0);g.scale(q,q)
          owner.__vascKantoHD=true
          paint(owner)
          if isInfo then top:draw() end
        end)
        owner.__vascKantoHD=prior
        g.pop()
        paintedFrame=ok and frame or nil
        if ok then
          local w,h=canvas:getDimensions()
          M.receipt={width=w,height=h,scale=q,owner=owner,info=isInfo==true}
        else M.receipt=nil end
      end
      if canvas and paintedFrame==frame then
        -- Zone/clip coordinates remain logical. Only the sampled texture and
        -- its draw scale change; the existing engine still applies palettes.
        return blit(self,canvas,sx/q,sy/q,zones,zx,zy,bx,by,cx,cy,cw,ch,dx,dy)
      end
    end
    return blit(self,image,sx,sy,zones,zx,zy,bx,by,cx,cy,cw,ch,dx,dy)
  end
  local ok,Assets=pcall(require,'src.render.Assets')
  if ok and Assets.register then Assets.register({release=M.release}) end
end

return M
