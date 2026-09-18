-- Merge only coplanar, equally coloured voxel faces. The occupied cells,
-- outward winding, palette lookup and directional shade remain unchanged.
local V=...
local Budget=V.require('BuildBudget')
local function sortedKeys(t)
  local keys={};for k in pairs(t)do keys[#keys+1]=k end
  table.sort(keys);return keys
end
return function(cells,ordered,key,directions,step,paletteSize,G)
  -- Retain sub-tile tessellation for the curved-world vertex shader.
  local maxSpan=math.max(1,math.floor(8/step))
  local planes={}
  for face,n in ipairs(directions)do
    local normal=face<=2 and 1 or face<=4 and 2 or 3
    local uAxis=normal==1 and 3 or 1
    local vAxis=normal==2 and 3 or 2
    local slices={};planes[face]={slices,normal,uAxis,vAxis}
    for _,p in ipairs(ordered)do
      Budget.tick()
      if not cells[key(p[1]+n[1],p[2]+n[2],p[3]+n[3])]then
        local plane,u,v=p[normal],p[uAxis],p[vAxis]
        local slice=slices[plane];if not slice then slice={};slices[plane]=slice end
        local row=slice[v];if not row then row={};slice[v]=row end
        row[u]=cells[p[4]]
      end
    end
  end
  local verts,indices,faceIds={},{},{}
  for face,planeData in ipairs(planes)do
    local slices,normal,uAxis,vAxis=unpack(planeData)
    for _,plane in ipairs(sortedKeys(slices))do
      local slice=slices[plane]
      for _,v in ipairs(sortedKeys(slice))do
        Budget.check()
        local row=slice[v]
        for _,u in ipairs(sortedKeys(row))do
          local color=row[u]
          if color then
            local width,height=1,1
            while width<maxSpan and row[u+width]==color do width=width+1 end
            while height<maxSpan and slice[v+height]do
              local nextRow,match=slice[v+height],true
              for x=u,u+width-1 do if nextRow[x]~=color then match=false;break end end
              if not match then break end
              height=height+1
            end
            for y=v,v+height-1 do for x=u,u+width-1 do slice[y][x]=nil end end
            local origin,scale={},{1,1,1}
            origin[normal],origin[uAxis],origin[vAxis]=plane,u,v
            scale[uAxis],scale[vAxis]=width,height
            G.pushQuad(indices,#verts/4);faceIds[#faceIds+1]=face
            for _,corner in ipairs(G.FACE_CORNERS[face])do
              verts[#verts+1]={(origin[1]+corner[1]*scale[1])*step,
                (origin[2]+corner[2]*scale[2])*step,(origin[3]+corner[3]*scale[3])*step,
                (color-.5)/paletteSize,.5,G.FACE_SHADE[face]}
            end
          end
        end
      end
    end
  end
  return verts,indices,faceIds
end
