-- Cancellable construction. Texture and flat mesh are borrowed and
-- must remain stable until the job completes or is cancelled.
local Builder={}
function Builder.factory(args)
 return function()
  local pixels,original
  local function cleanup()
   if original then original:release();original=nil end
   if pixels then pixels:release();pixels=nil end
  end
  local function run(checkpoint)
   local texture,neutral,row=args.texture,args.neutral,args.row
   local cw,ch=texture:getDimensions()
   pixels=texture:newImageData();checkpoint(true)
   local virtual={getDimensions=function()return cw*3,ch*4 end,getPixel=function(_,x,y)
    if x<0 or x>=cw or y<row*ch or y>=(row+1)*ch then return 0,0,0,0 end
    return pixels:getPixel(x,y-row*ch)
   end}
   local b=assert(args.bounds(virtual,row,0,nil,nil,checkpoint),'empty composite')
   b.layout={anchorX=(neutral.left+neutral.right)/2,anchorY=neutral.bottom-row*ch,referenceHeight=neutral.bottom-neutral.top}
   local voxel={pushQuad=function(indices,n)checkpoint();return args.voxel.pushQuad(indices,n)end,
    newMesh=function(vertices,indices)
     original=args.voxel.newMesh(vertices,indices)
     return original
    end}
   original=assert(args.cardMesh(voxel,b,args.visibleHeight or ch,false,true,args.cubes,args.shadingNeutral~=false,args.continuousSurface),'empty grid')
   checkpoint(true)
   local shape=args.stencil.build(original,args.flat,cw,ch,neutral,row,checkpoint,args.flatUnit,args.visibleHeight)
   cleanup()
   return {shape=shape,texture=texture}
  end
  return run,cleanup
 end
end
return Builder
