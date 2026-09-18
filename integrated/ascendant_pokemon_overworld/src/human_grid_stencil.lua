--  precompute UV interpolation once, then reuse the grid topology.
local Stencil={}
function Stencil.build(original,flat,cw,ch,neutral,row,checkpoint,flatUnit,visibleHeight)
 flatUnit=flatUnit or 1
 assert(type(flatUnit)=='number' and flatUnit>0 and flatUnit<math.huge,'invalid flat scale')
 assert(not visibleHeight or (type(visibleHeight)=='number' and visibleHeight>0 and visibleHeight<math.huge),'invalid visible height')
 local columns,us={},{}
 for i=1,flat:getVertexCount()do
  if checkpoint and i%64==0 then checkpoint()end
  local _,_,_,u,v=flat:getVertex(i);local key=math.floor(u*24000+.5)
  if not columns[key]then columns[key]={};us[#us+1]=key end
  columns[key][math.floor(v*32000+.5)]={index=i,x=8+(u*cw-(neutral.left+neutral.right)/2)*flatUnit,y=(neutral.bottom-row*ch-v*ch)*flatUnit}
 end
 table.sort(us)
 local ys={};for k in pairs(columns[us[1]])do ys[#ys+1]=k end;table.sort(ys)
 local function bracket(values,x)
  for i=2,#values do if x<=values[i]then return values[i-1],values[i]end end
  return values[#values-1],values[#values]
 end
 local shape={vertices={},indices=original:getVertexMap(),stencils={},unit=(visibleHeight or ch)/(neutral.bottom-neutral.top)/flatUnit,columns=columns}
 for i=1,original:getVertexCount()do
  if checkpoint and i%64==0 then checkpoint()end
  local x,y,z,u,v,shade=original:getVertex(i);u=u*3;v=v*4-row
  local ua,ub=bracket(us,u*24000);local va,vb=bracket(ys,v*32000)
  local tx=math.max(0,math.min(1,(u*24000-ua)/(ub-ua)));local ty=math.max(0,math.min(1,(v*32000-va)/(vb-va)))
  shape.vertices[i]={x,y,z,u,v,shade}
  shape.stencils[i]={columns[ua][va],columns[ub][va],columns[ua][vb],columns[ub][vb],tx,ty}
 end
 return shape
end
function Stencil.newPose(shape)
 local dxs,dys,samples={},{},{}
 for _,column in pairs(shape.columns)do for _,p in pairs(column)do samples[#samples+1]=p end end
 local function deform(v,i)
  local s=shape.stencils[i];local tx,ty=s[5],s[6]
  local a,b,c,d=s[1].index,s[2].index,s[3].index,s[4].index
  local dx=((dxs[a]*(1-tx)+dxs[b]*tx)*(1-ty)+(dxs[c]*(1-tx)+dxs[d]*tx)*ty)*shape.unit
  local dy=((dys[a]*(1-tx)+dys[b]*tx)*(1-ty)+(dys[c]*(1-tx)+dys[d]*tx)*ty)*shape.unit
  return v[1]+dx,v[2]+dy
 end
 return {update=function(_,flat)
  for _,p in ipairs(samples)do local x,y=flat:getVertex(p.index);dxs[p.index],dys[p.index]=x-p.x,y-p.y end
  return deform
 end}
end
function Stencil.pose(shape,flat)
 return Stencil.newPose(shape):update(flat)
end
return Stencil
