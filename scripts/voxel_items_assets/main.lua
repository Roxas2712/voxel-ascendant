-- Run: VASC_SOURCE=/path/to/mod love scripts/voxel_items_assets
local root=assert(os.getenv('VASC_SOURCE'),'VASC_SOURCE must name the mod root')..'/'
function love.load()
 package.preload['src.render.Assets']=function()return {register=function()end}end
 local G={}
 -- Use the production mesher's face winding and face lighting.
 local f=assert(io.open(root..'lib/Voxel3D.lua'));local source=f:read('*a');f:close()
 local function extract(first,last)
   local a=assert(source:find(first,1,true));local b=assert(source:find(last,a+#first,true))
   if last=='\n}\n' then b=b+3 end
   local fn=assert(loadstring(source:sub(a,b-1)));setfenv(fn,setmetatable({Voxel3D=G},{__index=_G}));fn()
 end
 extract('Voxel3D.FACE_SHADE =','\n}\n')
 extract('Voxel3D.FACE_CORNERS =','-- Append')
 function G.pushQuad(m,n)for _,i in ipairs({1,2,3,1,3,4})do m[#m+1]=n*4+i end end
 local P
 local bridge={require=function(n)
   if n=='VoxelItems' then return P end
   if n=='Voxel3D' then return G elseif n=='ModSetting' then return {new=function()return {get=function()return true end}end} end
   return dofile(root..'lib/'..n..'.lua')
 end}
 P=assert(loadfile(root..'lib/VoxelItems.lua'))(bridge)
 assert(loadfile(root..'lib/VoxelFurniture.lua'))(bridge)
 local kinds={'ball','pokedex','moss_stone','ice_stone'}
 for _,t in ipairs(P.typeOrder) do kinds[#kinds+1]='ball_'..t:lower() end
 for kind in pairs(P.models) do kinds[#kinds+1]=kind end
 table.sort(kinds)
 for _,kind in ipairs(kinds) do
   local model=P.models[kind]
   local W,H=(model and model.frameW or 16)*4,(model and model.frameH or 16)*4
   local verts,_,faceIds=P.geometry(kind)
   local faces={}
   for i=1,#verts,4 do
     local a=verts[i]
     -- Only the top and south faces are visible in this fixed 2D view.
     if faceIds[(i-1)/4+1]==3 or faceIds[(i-1)/4+1]==5 then
       local poly,depth={},0
       for j=i,i+3 do
         local v=verts[j];poly[#poly+1]=v[1]*4
         if model and model.frameH then
           poly[#poly+1]=(model.frameH+(v[3]-model.depth)*.65-v[2]*.65-2)*4
         else poly[#poly+1]=48+(v[3]-8)*.6*4-v[2]*.8*4 end
         depth=depth+(model and model.frameH and (v[2]+v[3]) or (v[2]*.6+v[3]*.8))
       end
       faces[#faces+1]={poly=poly,depth=depth,c=P.palette[math.floor(a[4]*#P.palette)+1],shade=a[6]}
     end
   end
   table.sort(faces,function(a,b)return a.depth<b.depth end)
   local canvas=love.graphics.newCanvas(W,H)
   love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
   for _,q in ipairs(faces)do
     love.graphics.setColor(q.c[1]/255*q.shade,q.c[2]/255*q.shade,q.c[3]/255*q.shade,1)
     love.graphics.polygon('fill',q.poly)
   end
   love.graphics.setCanvas()
   local data=canvas:newImageData();local png=data:encode('png')
   local out=assert(io.open(root..'assets/voxel_items/'..kind..'.png','wb'));out:write(png:getString());out:close()
   print('BUILT '..kind..' '..#faces..' faces')
 end
 love.event.quit(0)
end
