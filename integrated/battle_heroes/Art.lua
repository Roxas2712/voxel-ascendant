local load=...
local Motion=load('Motion.lua')
local bit=require('bit')
return function(mod,data)
 local G=love.graphics
 local images,quads={}, {}
 local A={}
 local journeys
 local function image(path)
  if not images[path] then images[path]=G.newImage(mod.resolveAsset and mod.resolveAsset(path)
    or (path:match('^assets/') and mod.path..'/'..path or path)) end
  return images[path]
 end
 local chars=load('CharSprite.lua')
 local heroAtlas=load('HeroAtlas.lua').new(mod,chars)
 local ballStyles=load('BallStyles.lua')
 local armShader
 local shaderSource=[[
 extern vec4 region;
 extern vec4 arm;
 extern float layer;
 extern float facing;
 vec4 effect(vec4 tint,Image tex,vec2 uv,vec2 screen){
  vec2 p=(uv-region.xy)/region.zw;
  float mask=(1.0-smoothstep(arm.y*.82,arm.y,abs(p.x-arm.x)))
   *smoothstep(arm.z,arm.z+.025,p.y)*(1.0-smoothstep(arm.w-.025,arm.w,p.y));
  vec4 px=Texel(tex,uv);
  if(layer>0.5) return vec4(px.rgb,px.a*mask)*tint;
  vec2 behind=uv;behind.x+=facing*arm.y*1.35*region.z;
  vec4 body=Texel(tex,behind);
  return mix(px,body,mask)*tint;
 }
 ]]
 local function hero(role,row,column)
  column=column or 0
  local img,b=heroAtlas(role,row,column)
  local key=role..':'..row..':'..column..':'..chars.revision
  return img,b,key
 end
 local function smooth(a,b,x)
  local t=math.max(0,math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)
 end
 local function angle(action,age)
  if action=='throw' then
   if age<12 then return 2.5*smooth(0,12,age) end
   if age<18 then return 2.5-3.8*smooth(12,18,age) end
   return -1.3*(1-smooth(18,54,age))
  elseif action=='command' then return -.95*math.sin(math.min(1,age/54)*math.pi) end
  return 0
 end
 function A.drawHero(role,x,y,height,frame,action,age,side,heldBall,view)
  side=side or 'player'
  local spec=chars.get(role)
  local column,row,authored=chars.frame(spec,action,action and age or frame,side,view)
  local img,b,key=hero(role,row,column)
  local l,t,r,bot,w,h=unpack(b)
  local profile=spec.rig
  profile=profile and profile[row]
  local armIndex=view=="terarrium-back" and 2 or 1
  local cx=profile and (profile.centers[armIndex] or profile.centers[1]) or .5
  local radius=profile and (profile.radius[armIndex] or profile.radius[1]) or .14
  local win=profile and profile.window or {.43,.61,.74,.79}
  local shoulder=win[1]
  local rot=(authored and 0 or angle(action,age or 0))*(side=='enemy' and -1 or 1)
  local width=height*(r-l)/(bot-t)
  local q=quads[key]
  if not q then q=G.newQuad(column*w+l,row*h+t,r-l,bot-t,img:getDimensions());quads[key]=q end
  G.setColor(1,1,1,1)
  if math.abs(rot)<.001 then
   G.draw(img,q,x-width/2,y-height,0,height/(bot-t))
  else
  armShader=armShader or G.newShader(shaderSource)
  armShader:send('region',{(column*w+l)/(spec.columns*w),(row*h+t)/(spec.rows*h),(r-l)/(spec.columns*w),(bot-t)/(spec.rows*h)})
  armShader:send('arm',{cx,radius,shoulder,win[4]})
  armShader:send('facing',(view=='terarrium-back' or view=='terarrium-front') and (cx>.5 and -1 or 1) or (side=='enemy' and -1 or 1))
  G.push('all');G.setShader(armShader)
  armShader:send('layer',0)
  G.draw(img,q,x-width/2,y-height,0,height/(bot-t))
  armShader:send('layer',1)
  -- Separate original-pixel arm layer rotates at the shoulder; torso/feet
  -- are stationary. The covered body is sampled from adjacent torso art.
  G.draw(img,q,x+(cx-.5)*width,y-(1-shoulder)*height,rot,
   height/(bot-t),height/(bot-t),cx*(r-l),shoulder*(bot-t))
  G.pop()
  end
  if heldBall and (age or 0)<18 and not authored then
   local hand=A.hand(role,side,age or 0,view)
   local stem=journeys.ballSprites[heldBall] or 'poke_ball'
   local tex=image('assets/journeys_balls/'..stem..'.png')
   local key='held:'..stem
   quads[key]=quads[key] or G.newQuad(0,0,32,64,tex:getDimensions())
   local scale=1.5*height/220
   G.push('all');G.setShader();G.setColor(1,1,1,1)
   G.draw(tex,quads[key],x+(hand[1]*192-96)*height/220,y+(hand[2]*256-246)*height/220,0,scale,scale,16,32)
   G.pop()
  end
 end
 function A.hand(role,side,age,view)
  local spec=chars.get(role)
  if age==18 and view~="terarrium-back" and view~="terarrium-front" and spec.releaseHand and spec.releaseHand[side] then return spec.releaseHand[side] end
  local row=view=='terarrium-back' and spec.backRow or view=='terarrium-front' and spec.frontRow
   or (side=='enemy' and spec.leftRow or spec.rightRow)
  local _,b=hero(role,row,spec.idleColumn or 0)
  local l,t,r,bot=unpack(b)
  local profile=spec.rig and spec.rig[row]
  local armIndex=view=="terarrium-back" and 2 or 1
  local cx=profile and (profile.centers[armIndex] or profile.centers[1]) or .5
  local win=profile and profile.window or {.43,.61,.74,.79}
  local theta=angle('throw',age or 18)*(side=='enemy' and -1 or 1)
  local length=(win[3]-win[1])*220
  local x=96+(cx-.5)*220*(r-l)/(bot-t)-length*math.sin(theta)
  local y=246-(1-win[1])*220+length*math.cos(theta)
  return {x/192,y/256}
 end
 function A.releaseHand(role,side,view)return A.hand(role,side,18,view)end
 function A.heroCanvas(role,frame,action,age,canvas,side,heldBall,view)
  canvas=canvas or G.newCanvas(192,256)
  G.push('all')
  local ok,err=pcall(function()
   G.setCanvas(canvas);G.origin();G.setScissor();G.setShader();G.setDepthMode();G.clear(0,0,0,0)
   G.setBlendMode('alpha');A.drawHero(role,96,246,220,frame,action,age,side,heldBall,view)
  end)
  G.pop();if not ok then error(err) end
  return canvas
 end
 local function objPalette(name)
  return data.palettes.battleObjects and data.palettes.battleObjects[name]
 end
 local Palette=require('src.render.GbcPalette')
 function A.drawNative(state,runnerOverride)
  local runner=runnerOverride or state.runner
  for _,obj in ipairs(runner:oam()) do
   local entry,index
   for n=#runner.loaded,1,-1 do local v=runner.loaded[n]
    if obj.tile>=v.tile and obj.tile<v.tile+math.max(v.tiles,1) then entry=v;index=obj.tile-v.tile;break end
   end
   local sheet=entry and data.anims.gfx[entry.gfx]
   if sheet then
    local img=image(sheet.image)
    local wide=sheet.wide or 8
    local key=entry.gfx..':'..index
    local q=quads[key]
    if not q then q=G.newQuad(index%wide*8,math.floor(index/wide)*8,8,8,img:getDimensions());quads[key]=q end
    local sx=bit.band(obj.attr,32)~=0 and -1 or 1
    local sy=bit.band(obj.attr,64)~=0 and -1 or 1
    local x,y=obj.x-8,obj.y-16
    if not runnerOverride then x,y=Motion.transfer(state,x,y,runner.frames) end
    local function draw()
     G.setColor(1,1,1,1);G.draw(img,q,x+(sx<0 and 8 or 0),y+(sy<0 and 8 or 0),0,sx,sy)
    end
    local colors=objPalette(obj.palette)
    if state.modern and sheet.image:find('poke_ball',1,true) then colors=ballStyles[state.ball] or ballStyles.POKE_BALL end
    if colors and Palette.available() then Palette.with(colors,draw) else draw() end
   end
  end
 end
 local view={image=function(_,path)return image(path)end}
 view.drawObjects=function(_,runner,state)return A.drawNative(state,runner)end
 journeys=load('JourneysBalls.lua')({mod=mod,view=view,markTrueColor=require('src.render.PaletteFX').markTrueColor})
 assert(journeys.install())
 function A.drawCatch(state)
  if not state.modern then return A.drawNative(state) end
  local r=state.runner
  local mapped={}
  for _,obj in ipairs(r:oam()) do
   local o={};for k,v in pairs(obj)do o[k]=v end
   o.x,o.y=Motion.transfer(state,o.x,o.y,r.frames)
   mapped[#mapped+1]=o
  end
  state.drawOam=mapped
  state.drawProxy=state.drawProxy or setmetatable({oam=function()return state.drawOam end},{__index=r})
  view.drawObjects(view,state.drawProxy,state)
 end
 A.ballStatus=journeys.status
 return A
end
