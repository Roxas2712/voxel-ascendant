-- Immutable translated props grouped into conservative world-space cells.
-- One group rejection skips all contained props. Missing/changed geometry
-- stays visible; the exact per-prop frustum test remains the final authority.
local V=...
local P=V.require('VoxelItems')
local B={}
local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
local cache=setmetatable({},{__mode='k'})
local function bounds(p)
 local m=p.mat
 if not (m and m._voxelStatic)then return end
 if m[1]~=1 or m[2]~=0 or m[3]~=0 or m[5]~=0 or m[6]~=1 or m[7]~=0
  or m[9]~=0 or m[10]~=0 or m[11]~=1 then return end
 local b=P.bounds(p.mesh);if not b then return end
 local result={b[1]+m[4],b[2]+m[8],b[3]+m[12],b[4]+m[4],b[5]+m[8],b[6]+m[12]}
 if p.extra and p.extra.mesh then
  b=P.bounds(p.extra.mesh);if not b then return end
  for a=1,3 do
   local offset=m[a*4]
   result[a]=math.min(result[a],b[a]+offset)
   result[a+3]=math.max(result[a+3],b[a+3]+offset)
  end
 end
 return result
end
function B.each(map,props,visible,emit)
 if not (map and visible and P.bounds)then for _,p in ipairs(props)do emit(p)end;return end
 local entry=cache[map]
 local same=entry and #entry.refs==#props
 if same then for i,p in ipairs(props)do
  if entry.refs[i]~=p or entry.panes[i]~=(p.extra and p.extra.mesh or false)then same=false;break end
 end end
 if not same then
  entry={refs={},panes={},groups={},loose={}}
  local cells={}
  for i,p in ipairs(props)do
   entry.refs[i]=p;entry.panes[i]=p.extra and p.extra.mesh or false
   local b=bounds(p)
   if not b then entry.loose[#entry.loose+1]=p else
    local key=math.floor(p.mat[4]/128)..':'..math.floor(p.mat[12]/128)
    local group=cells[key]
    if not group then group={box=b,props={}};cells[key]=group;entry.groups[#entry.groups+1]=group
    else for a=1,3 do group.box[a]=math.min(group.box[a],b[a]);group.box[a+3]=math.max(group.box[a+3],b[a+3])end end
    group.props[#group.props+1]=p
   end
  end
  cache[map]=entry
 end
 for _,group in ipairs(entry.groups)do
  if visible(group.box,identity)then for _,p in ipairs(group.props)do emit(p)end end
 end
 for _,p in ipairs(entry.loose)do emit(p)end
end
return B
