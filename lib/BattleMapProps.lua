-- Static room furniture and live visible item objects share one snapshot in
-- the MAP colour/depth passes. Never advance NPC poses or recreate map actors.
local V=...
local F=V.require("VoxelFurniture")
local P=V.require("VoxelItems")
local M=V.require("Mat4")
local B={}
local shifted=setmetatable({},{__mode='k'})
local signatures=setmetatable({},{__mode='k'})
local records=setmetatable({},{__mode='kv'})
local receipts=setmetatable({},{__mode='k'})
local preparedWorld=setmetatable({},{__mode='k'})
local receiptSerial=0
local function worldMatrix(mat,ox,oy)
  ox,oy=ox or 0,oy or 0
  if ox==0 and oy==0 then return mat end
  local cached=mat._voxelStatic and shifted[mat]
  if cached and cached.ox==ox and cached.oy==oy then return cached.mat end
  local out=M.mul(M.translate(ox,0,oy),mat)
  if mat._voxelStatic then out._voxelStatic=true;shifted[mat]={ox=ox,oy=oy,mat=out}end
  return out
end
local function propSignature(p)
  local pane=p.extra and p.extra.mesh
  local paneTex=p.extra and p.extra.tex
  local old=p.mat._voxelStatic and signatures[p.mat]
  if old and old.mesh==p.mesh and old.tex==p.tex and old.shade==p.shade and old.pane==pane and old.paneTex==paneTex then return old.value end
  local parts={tostring(p.mesh),tostring(p.tex),tostring(p.shade),tostring(pane),tostring(paneTex)}
  for i=1,16 do parts[#parts+1]=tostring(p.mat[i])end
  local value=table.concat(parts,',')
  if p.mat._voxelStatic then signatures[p.mat]={mesh=p.mesh,tex=p.tex,shade=p.shade,pane=pane,paneTex=paneTex,value=value}end
  return value
end
-- Compare the exact ordered descriptors, but publish only an immutable short
-- receipt. Shadow passes concatenate this identity several times per frame;
-- serializing every tree's matrix again made a static forest allocate large
-- temporary strings. No hash: any descriptor change gets a fresh receipt.
local function shadowReceipt(host,batch)
  local saved=receipts[host]
  if not saved then saved={parts={}};receipts[host]=saved end
  local parts=saved.parts
  local n,changed=0,not saved.valid
  saved.valid=false
  local function check(value)
    n=n+1
    if parts[n]~=value then parts[n]=value;changed=true end
  end
  check(#batch.furniture);check(#batch.items)
  for _,part in ipairs(batch.furnitureParts)do check(part)end
  for _,p in ipairs(batch.items)do check(propSignature(p))end
  for i=#parts,n+1,-1 do parts[i]=nil;changed=true end
  if changed or not saved.signature then
    receiptSerial=receiptSerial+1
    saved.signature={'map-props:'..receiptSerial}
  end
  saved.valid=true
  return saved.signature
end
function B.capture(state,host,neighbors)
  local batch={map=host,furniture={},items={},signature={},furnitureParts={}}
  local function furniture(map,ox,oy)
    local room=map==state.map and state or {map=map}
    local function record(mesh,tex,mat,shade,extra)
      local world=worldMatrix(mat,ox,oy)
      local value=shade or 1
      local prop=world._voxelStatic and records[world]
      if not prop or prop.mesh~=mesh or prop.tex~=tex or prop.shade~=value or prop.extra~=extra then
        prop={mesh=mesh,tex=tex,mat=world,shade=value,extra=extra}
        if world._voxelStatic then records[world]=prop end
      end
      -- Records are immutable here; the clearance adapter only filters them.
      -- Keep live pane emission via extra, but avoid a table per tree/frame.
      return prop
    end
    local prepared=F.snapshot and F.snapshot(room)
    if prepared and prepared._voxelStaticSnapshot then
      -- The producer already checked live claims, settings, height ownership
      -- and GPU resources. Reuse the translated descriptors as one segment;
      -- retain the shared pane objects so their emission stays live.
      local segment=preparedWorld[prepared]
      if not segment or segment.ox~=(ox or 0) or segment.oy~=(oy or 0) then
        segment={ox=ox or 0,oy=oy or 0}
        for _,p in ipairs(prepared)do
          segment[#segment+1]=record(p.mesh,p.tex,p.mat,p.shade,p.extra)
        end
        preparedWorld[prepared]=segment
      end
      batch.furnitureParts[#batch.furnitureParts+1]=segment
      for _,p in ipairs(segment)do batch.furniture[#batch.furniture+1]=p end
    else
      local function add(mesh,tex,mat,shade,extra)
        local prop=record(mesh,tex,mat,shade,extra)
        batch.furniture[#batch.furniture+1]=prop
        batch.furnitureParts[#batch.furnitureParts+1]=propSignature(prop)
      end
      if prepared then
        for _,p in ipairs(prepared)do add(p.mesh,p.tex,p.mat,p.shade,p.extra)end
      else F.each(room,add)end
    end
  end
  furniture(host)
  for _,n in ipairs(neighbors or {})do furniture(n.map,n.ox,n.oy)end
  -- A relocated battle must not borrow the source room's item actors.
  if host==state.map and P.setting:get() then
    for _,e in ipairs(state.entities or {})do
      local sprite=e.sprite
      if sprite and P.kind(sprite.def,sprite.seed) then
        local mesh,tex=P.resolve(sprite.def,sprite.seed)
        if mesh then
          local height=V.require("VoxelScene").groundForEntity(host,e,false)
          height=F.supportAt(host,e.px,e.py) or height
          batch.items[#batch.items+1]={mesh=mesh,tex=tex,mat=P.model(e.px,e.py,height,0),shade=1}
        end
      end
    end
  end
  -- Pane emission is colour-only; geometry, texture, order and transforms
  -- participate in the receipt and invalidate static shadows when changed.
  batch.signature=shadowReceipt(host,batch)
  return batch
end
local function renderProps(batch,draw,pass,vp,k,cx,cz)
  local visibility=V.require('PropVisibility')
  local visible=visibility and visibility.forView(vp,k,cx,cz)
  local function each(_,emit)
    local function prop(p)
        if not visible or not P.bounds or visible(P.bounds(p.mesh),p.mat)
          or(p.extra and visible(P.bounds(p.extra.mesh),p.mat))then
          emit(p.mesh,p.tex,p.mat,p.shade,p.extra)
        end
    end
    local spatial=P.bounds and visible and V.require('PropSpatialIndex')
    if spatial then spatial.each(batch.map,batch.furniture,visible,prop)
    else for _,p in ipairs(batch.furniture)do prop(p)end end
    for _,p in ipairs(batch.items)do prop(p)end
  end
  local batching=V.require('VoxelPropBatch')
  if batching and batch.map then batching.draw(batch,each,draw,pass)else each(batch,draw)end
end
function B.cast(batch,shadow)
  renderProps(batch,function(mesh,tex,mat,shade,extra)
    shadow.draw(mesh,tex,mat)
    if extra and extra.mesh then shadow.draw(extra.mesh,extra.tex,mat)end
  end,'battle-shadow',shadow.clipVP)
end
function B.draw(batch)
  local g=love.graphics
  local G=V.require('Voxel3D')
  renderProps(batch,F.drawProp,'battle-color',G.vp,G.curveK,G.curveX,G.curveZ)
  g.setColor(1,1,1,1)
end
return B
