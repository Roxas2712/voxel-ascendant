-- Each plant keeps its rigid voxel shape but is planted on the same triangle
-- surface as actors. Prepare shared relative-height variants while terrain
-- is built, never create a mesh in the gameplay draw path.
local V=...
local M={}
local Budget=V.require('BuildBudget')

function M.prepare(map,S,props)
  local P=V.require('VoxelItems')
  local heights,Grades,elevation
  for _,p in ipairs(props)do
    local model=P.models[p.kind]
    if p.claimed and p.terrainDecoration and model and model.groundParts then
      Budget.tick()
      elevation=elevation or V.require('LedgeElevation')
      if not heights and type(elevation.map)=='function'then heights=elevation.map(map)end
      Grades=Grades or V.require('WalkableGrades')
      local levels,base={},math.huge
      for i,part in ipairs(model.groundParts)do
        local x,z=p.tx*8+part.x,p.ty*8+part.z
        local h=heights and Grades.height(map,heights,S,x,z)
        if h==nil then
          h=heights and heights:atTile(math.floor(x/8),math.floor(z/8))
            or elevation.basisAtCell(map,math.floor(x/16),math.floor(z/16))
        end
        levels[i]=h;base=math.min(base,h)
      end
      local offsets,raised={},false
      for i,h in ipairs(levels)do
        local delta=h-base
        offsets[i]=tostring(delta)
        if delta~=0 then raised=true end
      end
      local kind=p.kind
      if raised then
        kind=p.kind..'_grade_'..table.concat(offsets,'_')
        if not P.models[kind]then
          local variant={}
          for k,v in pairs(model)do variant[k]=v end
          variant.groundParts=nil;variant.boxes={}
          for _,b in ipairs(model.boxes)do
            local copy={};for k,v in pairs(b)do copy[k]=v end
            variant.boxes[#variant.boxes+1]=copy
          end
          for i,part in ipairs(model.groundParts)do
            for b=part.first,part.last do
              variant.boxes[b][2]=variant.boxes[b][2]+levels[i]-base
            end
          end
          P.models[kind]=variant
        end
      end
      -- Resolve in the cooperative terrain builder so the first visible
      -- sloped flower cannot cause a synchronous GPU upload during drawing.
      P.resolveKind(kind)
      local old=p.decorPlacement
      if not old or old.kind~=kind or old.base~=base then
        p.decorPlacement={kind=kind,base=base}
      end
    end
  end
end
return M
