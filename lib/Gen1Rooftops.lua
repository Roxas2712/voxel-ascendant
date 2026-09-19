-- Presentation on the original rooftop footprint. Native cells, warps and
-- collision stay authoritative; a roof shed must not match generic tables.
local M={}
-- Indoor tilesets do not make these two native terraces enclosed rooms.
local profiles={
 CELADON_MANSION_ROOF={tileset='MANSION',width=4,height=6},
 CELADON_MART_ROOF={tileset='LOBBY',width=10,height=4},
}
function M.matches(map)
 local d=map and map.def or{};local p=profiles[map and map.id or d.id]
 return p~=nil and d.generation~=2 and d.tileset==p.tileset
  and d.width==p.width and d.height==p.height
end
function M.register(P,F)
 local C=P.decorColors
 local model={boxes={},terrain=true,step=1,frameW=48,frameH=100,depth=64,offsetY=-36}
 P.models.celadon_roof_house=model
 local function b(x,y,z,w,h,d,c)
  model.boxes[#model.boxes+1]={x,y,z,w,h,d,c}
 end
 -- The native door spans local x=16..32 on the southern cell. Keep that
 -- whole approach open instead of painting a door onto a solid facade.
 b(0,0,0,48,3,48,C.slate or 16)
 b(1,3,1,46,27,3,14)
 b(1,3,4,3,27,56,14);b(44,3,4,3,27,56,14)
 b(1,0,60,15,28,4,14);b(32,0,60,15,28,4,14)
 b(16,24,60,16,4,4,14)
 b(14,0,63,2,26,1,C.walnut);b(32,0,63,2,26,1,C.walnut)
 b(14,26,63,20,2,1,C.walnut)
 b(16,0,48,16,1,16,C.slate or 16)
 -- A shallow hipped cap, with a continuous eave, reads as a small building.
 b(0,28,0,48,2,64,C.slate or 16)
 for i=0,5 do b(i,30+i,i,48-i*2,1,64-i*2,C.roofGreen or 10)end
 -- Small windows flank the entrance; no pane covers its opening.
 for _,x in ipairs({4,36})do
  b(x,12,64,8,10,1,C.walnut);b(x+1,13,65,6,8,1,8)
  b(x+3,13,66,1,8,1,14);b(x+1,17,66,6,1,1,14)
 end
 local tiles={{38,39,39,39,39,41}}
 for i=2,6 do tiles[i]={54,55,55,55,55,57}end
 tiles[7]={48,30,81,82,30,93};tiles[8]={48,30,83,84,6,7}
 table.insert(F.patterns,1,{kind='celadon_roof_house',sets={MANSION=true},
  maps={CELADON_MANSION_ROOF=true},x=2,y=8,tiles=tiles,groundTile=1,
  guard=function(map)
   if map.def.width~=4 or map.def.height~=6 then return false end
   for _,w in ipairs(map.def.warps or{})do
    if w.x==2 and w.y==7 and w.destMap=='CELADON_MANSION_ROOF_HOUSE'then return true end
   end
   return false
  end})
end
return M
