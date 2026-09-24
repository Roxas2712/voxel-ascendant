-- Native GPU test: a canvas already contains premultiplied fog RGB.
local root=assert(arg[1]);local modules={LocalLights={active=function()return false end},Sky={clock=7},
 Weather={isLavender=function()return true end},LedgeElevation={basisAtCell=function()return 0 end},
 KascLegendAtmosphere={profile=function()end}}
local M=assert(loadfile(root..'/lib/IndoorMist.lua'))({require=function(n)return assert(modules[n],n)end})
local g=love.graphics;local target=g.newCanvas(64,64,{format='rgba16f',dpiscale=1})
local data=love.image.newImageData(64,64)
for y=0,63 do for x=0,63 do data:setPixel(x,y,.9,.9,.9,1)end end
local depth=g.newImage(data);data:release()
local map={id='LAVENDER_TOWN',def={width=10,height=10,generation=1}}
local vp={1/32,0,0,0, 0,1/32,0,-1, 0,0,1/192,-5/6, 0,0,0,1}
g.setCanvas(target);g.clear(.1,.1,.1,1);g.setCanvas();g.setColor(1,1,1,1)
assert(M.draw(map,false,target,depth,vp))
local buffer
for i=1,80 do local k,v=debug.getupvalue(M.draw,i);if k=='buffer'then buffer=v;break end end
assert(buffer);local fog=buffer:newImageData();local out=target:newImageData();local tested=0;local maxError=0
local function sample(x,y,k)
 local values={fog:getPixel(math.max(0,math.min(31,x)),math.max(0,math.min(31,y)))};return values[k]
end
for y=1,62 do for x=1,62 do
 local u,v=x/2-.25,y/2-.25;local ix,iy=math.floor(u),math.floor(v);local fx,fy=u-ix,v-iy
 local function filtered(k)return sample(ix,iy,k)*(1-fx)*(1-fy)+sample(ix+1,iy,k)*fx*(1-fy)+sample(ix,iy+1,k)*(1-fx)*fy+sample(ix+1,iy+1,k)*fx*fy end
 local a=filtered(4)
 if a>.08 then
  local r=out:getPixel(x,y);local expected=filtered(1)+.1*(1-a)
  maxError=math.max(maxError,math.abs(r-expected));tested=tested+1
 end
end end
assert(tested>100,'fog was absent')
assert(maxError<.004,'fog RGB multiplied by alpha twice: error '..maxError)
print('PASS fog composite: premultiplied RGB blended once',tested,maxError)
fog:release();out:release();M.invalidate();target:release();depth:release()
