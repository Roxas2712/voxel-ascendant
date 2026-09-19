-- Shared by the offline capture and the runtime selector. Changed source
-- maps, tiles, roofs or palettes reject the capture instead of showing stale art.
local M={REVISION=2}
function M.serialize(value)
 local t=type(value)
 if t=='string'then return string.format('%q',value)end
 if t=='number'or t=='boolean'then return tostring(value)end
 if t~='table'then return 'nil'end
 local keys={};for k in pairs(value)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local rows={'{'};for _,k in ipairs(keys)do rows[#rows+1]='['..M.serialize(k)..']='..M.serialize(value[k])..','end
 rows[#rows+1]='}';return table.concat(rows)
end
function M.digest(maps,tilesets,roofs,palettes,ids,imageHash,hash)
 local rows={'johto-world-'..M.REVISION};local sets,images={},{}
 for _,id in ipairs(ids)do
  local d=maps and maps[id];if not d then return nil end
  rows[#rows+1]=M.serialize({id,d.width,d.height,d.tileset,d.blocks,d.connections,d.environment,d.palette,d.group})
  sets[d.tileset]=true
  local roof=roofs and roofs.mapGroupRoofs and roofs.mapGroupRoofs[d.group]
  local r=roof and roofs.roofs and roofs.roofs[roof]
  if r and r.image then images[r.image]=true;rows[#rows+1]=id..':'..r.image end
 end
 local names={};for k in pairs(sets)do names[#names+1]=k end;table.sort(names)
 for _,n in ipairs(names)do
  local t=tilesets and tilesets[n];if not t or t.trueColor then return nil end
  rows[#rows+1]=M.serialize({n,t.blocks,t.tilePalettes,t.tileAttrs,t.image,t.tilesPerRow})
  if t.image then images[t.image]=true end
 end
 names={};for n in pairs(images)do names[#names+1]=n end;table.sort(names)
 for _,name in ipairs(names)do local digest=imageHash(name);if not digest then return nil end;rows[#rows+1]=name..':'..digest end
 rows[#rows+1]=M.serialize(palettes)
 return hash(table.concat(rows,'\n'))
end
function M.near(maps,root,depth)
 local seen={[root]=true};local queue={{root,0}}
 local i=1
 while queue[i]do local p=queue[i];i=i+1
  if p[2]<depth then for _,c in pairs(maps[p[1]] and maps[p[1]].connections or{})do
   local id=c.mapId or c.map
   if maps[id] and not seen[id]then seen[id]=true;queue[#queue+1]={id,p[2]+1}end
  end end
 end
 return seen
end
return M
