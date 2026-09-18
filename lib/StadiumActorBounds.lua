-- Conservative bounds of the current rigid-bone pose. Cache only immutable
-- source bounds; animated matrices and world placement are read every frame.
local M={}
local sources=setmetatable({},{__mode='k'})
local function extend(b,x,y,z)
  b[1],b[2],b[3]=math.min(b[1],x),math.min(b[2],y),math.min(b[3],z)
  b[4],b[5],b[6]=math.max(b[4],x),math.max(b[5],y),math.max(b[6],z)
end
local function empty()return {math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}end
function M.world(rig,world)
  local model=rig and rig.model
  if not (model and model.prims and rig.drawM and world)then return nil end
  local bones=sources[model]
  if bones==nil then
    bones={}
    for _,p in ipairs(model.prims)do for i=1,p.vertCount do
      local bone=p.bone[i]
      if not bone or bone<1 or bone>model.boneCount then sources[model]=false;return nil end
      local b=bones[bone]or empty();bones[bone]=b
      extend(b,p.px[i],p.py[i],p.pz[i])
    end end
    sources[model]=bones
  end
  if bones==false then return nil end
  local out=empty();local d=rig.drawM
  for bone,b in pairs(bones)do
    local o=(bone-1)*12
    if not d[o+12]then return nil end
    for ix=0,1 do for iy=0,1 do for iz=0,1 do
      local x,y,z=b[1+3*ix],b[2+3*iy],b[3+3*iz]
      local a=d[o+1]*x+d[o+2]*y+d[o+3]*z+d[o+4]
      local c=d[o+5]*x+d[o+6]*y+d[o+7]*z+d[o+8]
      local e=d[o+9]*x+d[o+10]*y+d[o+11]*z+d[o+12]
      extend(out,world[1]*a+world[2]*c+world[3]*e+world[4],
        world[5]*a+world[6]*c+world[7]*e+world[8],
        world[9]*a+world[10]*c+world[11]*e+world[12])
    end end end
  end
  if out[1]==math.huge then return nil end
  return out
end
return M
