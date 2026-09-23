-- HD battle/Dex cards retain logical GB dimensions, with denser textures.
-- One preparation step per rendered frame; native sprites remain available.
local V=...
local M={}
local Assets=require('src.render.Assets')
local cache,clock,frame={},0,0
local CACHE_BYTES=32*1024*1024
local active,atlas
local extents=setmetatable({}, {__mode='k'})
local decoder
local ok,value=pcall(function()return V.require('HdImageDecode')end)
if ok then decoder=value end
function M.extent(image)return extents[image]end
function M.density(image)
 return extents[image] and image.getDPIScale and image:getDPIScale() or 1
end
local function release(object)
 if object and object.release then pcall(object.release,object)end
end
local function clearAtlas()
 if atlas then release(atlas.texture);atlas=nil end
end
local function discard(job)
 if not job then return end
 if job.worker and decoder then decoder.cancel(job.worker)end
 release(job.data)
 for _,frames in pairs(job.frames or {})do
  for _,image in ipairs(frames)do release(image)end
 end
 job.worker,job.data,job.frames=nil,nil,nil
end
function M.resolve(game,mon)
 if not mon or mon.egg or mon._ascMegaForm or mon.ascMegaForm then return end
 local api=V.mod.exports.overworldPokemon
 api=api and api.pokemonWalksheets
 if not(api and api.resolveContext)then return end
 local yes,r=pcall(api.resolveContext,game,mon,'battle')
 if yes and r and r.animationCards and r.animationCards.verified then return r end
end
local function describe(cards,view,size)
 local l,clip=cards.layout,cards.idle
 if not(l and clip and type(clip.sheet)=='string' and type(cards.id)=='string')then return end
 local w,h=tonumber(l.cellWidth),tonumber(l.cellHeight)
 local n,duration=tonumber(clip.columns),tonumber(clip.duration)
 if not(w and h and n and duration and w>0 and h>0 and n>=1 and n<=64
     and n==math.floor(n) and duration>0 and duration<3600
     and w*n*h*4*4<=32*1024*1024)then return end
 local left,top,right,bottom=tonumber(l.left),tonumber(l.top),tonumber(l.right),tonumber(l.bottom)
 if not(left and top and right and bottom and left>=0 and top>=0
     and right>left and bottom>top and right<=w and bottom<=h)then return end
 local dpi=size==128 and 2 or 4
 local bytes=size*size*dpi*dpi*4*n*(size==56 and 4 or 1)
 if bytes>16*1024*1024 then return end
 local source=table.concat({cards.id,clip.sheet,w,h,n,left,top,right,bottom,duration},':')
 return {key=source..':'..size,source=source,path=clip.sheet,
  width=w*n,height=h*4,cellW=w,cellH=h,columns=n,duration=duration,
  left=left,top=top,bw=right-left,bh=bottom-top,
  rows=size==56 and {0,1,2,3} or {view=='back' and 2 or 0},
  size=size,dpi=dpi,bytes=bytes}
end
local function request(game,mon,view,size)
 if view~='front' and view~='back' and view~='left'
     and view~='right' and view~='world_back' then return end
 size=size or (view=='back' and 28 or 56)
 if size~=28 and size~=56 and size~=128 then return end
 local r=M.resolve(game,mon);if not r then return end
 local spec=describe(r.animationCards,view,size);if not spec then return end
 clock=clock+1
 local entry=cache[spec.key]
 if not entry then entry={spec=spec,pending=true,order=clock};cache[spec.key]=entry end
 entry.last,entry.requested=clock,frame
 while true do
  local count,bytes,oldest,oldKey=0,0,math.huge
  for k,v in pairs(cache)do
   count=count+1;bytes=bytes+v.spec.bytes
   if k~=spec.key and v.last<oldest then oldest,oldKey=v.last,k end
  end
  if (count<=6 and bytes<=CACHE_BYTES) or not oldKey then break end
  if active and active.entry==cache[oldKey]then discard(active);active=nil end
  -- Live presentations own completed frames; eviction cannot release those.
  cache[oldKey]=nil
 end
 return entry
end
local function bakeFrame(job)
 local spec=job.entry.spec
 local g=love.graphics
 local image,quad
 g.push('all')
 local yes,err=pcall(function()
  image=g.newCanvas(spec.size,spec.size,{dpiscale=spec.dpi})
  image:setFilter('linear','linear')
  g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setStencilTest()
  g.setColorMask(true,true,true,true);g.setBlendMode('replace');g.setColor(1,1,1,1)
  g.setCanvas(image);g.clear(0,0,0,0)
  local scale=(spec.size-4)/math.max(spec.bw,spec.bh)
  quad=g.newQuad(job.column*spec.cellW+spec.left,spec.rows[job.rowIndex]*spec.cellH+spec.top,
    spec.bw,spec.bh,spec.width,spec.height)
  g.draw(atlas.texture,quad,(spec.size-spec.bw*scale)/2,
    spec.size-2-spec.bh*scale,0,scale,scale)
 end)
 g.pop();release(quad)
 if not yes then release(image);error(err,0)end
 extents[image]=spec.size-4
 local row=spec.rows[job.rowIndex]
 job.frames[row]=job.frames[row] or {}
 job.frames[row][#job.frames[row]+1]=image;job.column=job.column+1
 if job.column==spec.columns then
  job.column=0;job.rowIndex=job.rowIndex+1
  if job.rowIndex>#spec.rows then
   job.entry.frames,job.entry.pending=job.frames,false
   job.frames=nil;active=nil
  end
 end
end
local function step(job)
 local spec=job.entry.spec
 if job.stage=='decode' then
  if atlas and atlas.source==spec.source then job.stage='bake';return end
  clearAtlas()
  if decoder then
   job.worker=decoder.start(Assets.resolve(spec.path),32*1024*1024,
     spec.width,spec.height,Assets.hdImageBytes)
   if job.worker==nil then return end
   if job.worker then job.stage='wait';return end
  end
  job.data=Assets.imageData(spec.path);job.stage='upload';return
 elseif job.stage=='wait' then
  local data=decoder.poll(job.worker)
  if data==nil then return end
  job.worker=nil
  job.data=data or Assets.imageData(spec.path);job.stage='upload';return
 elseif job.stage=='upload' then
  local w,h=job.data:getDimensions()
  assert(w==spec.width and h==spec.height,'invalid HD card dimensions')
  local texture=love.graphics.newImage(job.data)
  atlas={texture=texture,source=spec.source}
  release(job.data);job.data=nil;texture:setFilter('linear','linear')
  job.stage='bake';return
 end
 -- Two small canvases at most, independently from decode/upload.
 for _=1,2 do bakeFrame(job);if not active then break end end
end
function M.pump()
 frame=frame+1
 if decoder then decoder.pump()end
 for key,entry in pairs(cache)do
  if entry.pending and frame-entry.requested>3 then
   if active and active.entry==entry then discard(active);active=nil end
   cache[key]=nil
  end
 end
 if not active then
  local chosen
  for _,entry in pairs(cache)do
   if entry.pending and (not chosen or entry.order<chosen.order)then chosen=entry end
  end
  if not chosen then clearAtlas();return end
  active={entry=chosen,stage='decode',frames={},column=0,rowIndex=1}
 end
 local job=active
 local yes,err=pcall(step,job)
 if not yes then
  job.entry.pending=false;job.entry.failed=true
  M.lastError=tostring(err);discard(job);active=nil;clearAtlas()
 end
end
function M.create(game,mon,view,size)
 local entry=request(game,mon,view,size)
 if not entry then return nil,'missing' end
 if entry.pending then return nil,'pending'end
 if not entry.frames then return nil,'failed'end
 local row=({front=0,left=1,back=2,world_back=2,right=3})[view]
 local frames=entry.frames[row]
 return {image=frames[1],frames=frames,duration=entry.spec.duration,
  elapsed=0,frame=1,animated=true}
end
function M.advancePresentation(state,dt,game)
 local speed=game and game.logicSpeed and tonumber(game:logicSpeed()) or 1
 state.elapsed=(state.elapsed+math.max(0,tonumber(dt) or 0)/math.max(.1,speed or 1))%state.duration
 state.frame=math.min(#state.frames,1+math.floor(state.elapsed/state.duration*#state.frames))
 state.image=state.frames[state.frame];return state.image
end
function M.stats()
 local count,bytes,pending=0,0,0
 for _,entry in pairs(cache)do
  count=count+1;bytes=bytes+entry.spec.bytes
  if entry.pending then pending=pending+1 end
 end
 return {entries=count,budgetedBytes=bytes,pending=pending,active=active~=nil}
end
function M.dex(game,species)
 local state=M.create(game,{species=species},'front',128)
 if state then
  M.advancePresentation(state,love.timer.getTime(),nil)
  return {image=state.image,trueColor=true,source='hd'}
 end
end
return M
