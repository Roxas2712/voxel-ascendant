-- The eleven-floor Kanto headquarters, on its unchanged native plot.
-- Near architecture and the distant landmark use the same geometry.
local V=...
local T={width=128,depth=192,height=304,storeys=11,tx=32,ty=20}
function T.matches(def)
 if not def or def.generation==2 or def.width~=20 or def.height~=18 or def.tileset~='OVERWORLD'then return false end
 for _,w in ipairs(def.warps or{})do
  if w.x==18 and w.y==21 and w.destMap=='SILPH_CO_1F'then return true end
 end
 return false
end
-- Only an orbit camera whose sightline actually crosses the tower needs
-- the low presentation. Eye-level views and the remote skyline stay whole.
function T.occludes(map,level,eye,focus)
 if not(map and map.id=='SAFFRON_CITY' and T.matches(map.def))
   or not(level and level>=1 and level<6 and eye and focus)then return false end
 local lo,hi=0,1
 for _,axis in ipairs({1,3})do
  local lower=axis==1 and T.tx*8 or T.ty*8
  local upper=lower+(axis==1 and T.width or T.depth)
  local origin,delta=focus[axis],eye[axis]-focus[axis]
  if math.abs(delta)<1e-6 then if origin<lower or origin>upper then return false end
  else
   local a,b=(lower-origin)/delta,(upper-origin)/delta
   if a>b then a,b=b,a end
   lo,hi=math.max(lo,a),math.min(hi,b)
   if lo>=hi then return false end
  end
 end
 local a=focus[2]+(eye[2]-focus[2])*lo
 local b=focus[2]+(eye[2]-focus[2])*hi
 return math.max(a,b)>34 and math.min(a,b)<T.height
end
function T.geometry(emit,doors)
 local function b(x,y,z,w,h,d,c,lit)
  assert(x>=0 and z>=0 and x+w<=T.width and z+d<=T.depth and y+h<=T.height,'Silph footprint')
  emit(x,y,z,w,h,d,c,lit==true)
 end
 local front=184
 -- Hollow shell: the doorway remains an actual opening, not a wall with a
 -- painted door. Native warps, walkability and the entrance facade own it.
 local door=40
 for _,v in ipairs(doors or{})do if v.side=='south'then door=v.at end end
 b(4,0,4,120,2,184,'stone')
 b(6,2,6,2,270,178,'wall');b(120,2,6,2,270,178,'wall')
 b(6,2,6,116,270,2,'wall')
 b(6,2,front,door-14,24,2,'wall');b(door+8,2,front,114-door,24,2,'wall')
 b(6,26,front,116,246,2,'wall')
 -- Eleven readable storeys: a taller lobby and ten office floors.
 for floor=0,10 do
  local y=floor==0 and 2 or 32+(floor-1)*24
  local h=floor==0 and 30 or 24
  for _,z in ipairs({4,front+2})do
   b(4,y+h-2,z,120,2,2,'navy')
   for x=12,108,16 do
    if floor>0 or z==4 or math.abs(x+6-door)>16 then
     b(x,y+6,z,12,16,2,'glass',true)
     b(x+4,y+6,z+(z==4 and -2 or 2),2,16,2,'silver')
    end
   end
  end
  for _,x in ipairs({4,122})do
   b(x,y+h-2,6,2,2,178,'navy')
   for z=14,166,20 do
    b(x,y+6,z,2,16,16,'glass',true)
    b(x+(x==4 and -2 or 2),y+6,z+6,2,16,2,'silver')
   end
  end
 end
 -- Continuous pale corner piers and a restrained, stepped roof crown.
 for _,x in ipairs({2,118})do for _,z in ipairs({2,178})do b(x,2,z,8,274,8,'trim')end end
 b(0,272,0,128,4,192,'trim');b(4,276,4,120,4,184,'navy')
 b(40,280,56,48,10,64,'wall');b(38,290,54,52,2,68,'silver')
 b(60,292,82,8,4,12,'navy');b(62,296,86,4,8,4,'silver')
 -- Corporate lettering above the highest windows. The raised sign is
 -- geometry, stays within the plot and remains readable in both languages.
 b(28,274,188,72,16,4,'navy')
 local glyphs=V.require('Gen1VoxelSigns').glyphs
 local text='SILPH CO'
 for i=1,#text do for row,line in ipairs(glyphs[text:sub(i,i)]or{})do
  for col=1,3 do if line:sub(col,col)=='1'then
   b(32+(i-1)*8+(col-1)*2,278+(5-row)*2,190,2,2,2,'trim',true)
  end end
 end end
 -- Human-scale canopy and sliding glass entrance, aligned to the native warp.
 b(door-12,26,182,24,4,10,'navy');b(door-10,28,180,20,2,12,'silver')
 b(door-10,2,184,2,24,2,'trim');b(door+8,2,184,2,24,2,'trim')
 b(door-8,4,186,16,20,2,'glass',true);b(door-1,4,188,2,20,2,'silver')
end
function T.create(P,kind,doors,light)
 local C=P.decorColors
 local indices={wall=14,trim=4,navy=C.navy,silver=C.silver,stone=C.stone,glass=C.silphGlass}
 local function model(name)
  local m={terrain=true,boxes={},step=2,frameW=T.width,frameH=T.height+T.depth,
   depth=T.depth,offsetY=-T.height,template='silph_co',nativeDoors=doors,
   landmarkHeight=T.height,storeys=T.storeys}
  P.models[name]=m;return m
 end
 local m=model(kind);local glass=model(kind..'_glass')
 m.glassKind=kind..'_glass';m.windowLight=light
 T.geometry(function(x,y,z,w,h,d,c,lit)
  local target=lit and glass or m
  target.boxes[#target.boxes+1]={x,y,z,w,h,d,assert(indices[c])}
 end,doors)
 -- Prepared once alongside the full building: no shader changes or scene
 -- rebuild while the player walks behind the tower. Keep the lobby/door and
 -- a closed low roof, while shadows continue to use the complete building.
 local low=model(kind..'_cutaway');local panes=model(kind..'_cutaway_glass')
 low.glassKind=kind..'_cutaway_glass';low.windowLight=light
 low.landmarkHeight,panes.landmarkHeight=34,34
 low.frameH,panes.frameH=34+T.depth,34+T.depth
 low.offsetY,panes.offsetY=-34,-34
 for _,pair in ipairs({{m,low},{glass,panes}})do
  for _,box in ipairs(pair[1].boxes)do if box[2]<32 then
   local b={};for i,v in ipairs(box)do b[i]=v end
   b[5]=math.min(b[5],32-b[2]);pair[2].boxes[#pair[2].boxes+1]=b
  end end
 end
 low.boxes[#low.boxes+1]={2,32,2,124,2,188,indices.navy}
 m.cutawayKind=kind..'_cutaway'
 return kind
end
return T
