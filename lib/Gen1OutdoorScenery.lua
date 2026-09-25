-- Deterministic outdoor scenery. Native collision, Cut and encounter tiles
-- remain authoritative; these claims are used only by the 3D renderer.
local V=...
local M={}
local safariMaps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,
 SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
-- FOREST's connected hills use a different atlas spelling from OVERWORLD
-- cliffs. Keep the native volume/ledge geometry, including its walkable
-- interior and stairs; only replace the enlarged original rock drawing.
local safariHillWalls={[14]=true,[15]=true,[29]=true,[31]=true,
 [45]=true,[47]=true,[61]=true,[62]=true,[63]=true}
local S=V.require('ModSetting')
M.ground=S.new('outdoorGround','OUTDOOR GROUND',{true,false},{'ON','OFF'})
M.trees=S.new('outdoorTrees','TREES',{true,false},{'ON','OFF'})
M.stone=S.new('outdoorStone','ROCKS + FENCES',{true,false},{'ON','OFF'})
function M.profile(map)
 local d=map and map.def
 if not d or not M.ground:get()then return nil end
 if map.id=='KANTO_ASCENDANT_DRIFTGLASS' and V.require('KascDriftglass').matches(map)then return 'kasc_driftglass' end
 if map.id=='KA_HOENN_BIRTH_ISLAND'and V.require('KascBirthIsland').matches(map)then return 'kasc_birth'end
 if map.id=='KA_HEVO_RAYQUAZA_CHAMBER'and V.require('KascSkySanctum').matches(map)then return 'kasc_sky'end
 if d.runtimeAuthority=='KASC_6_7_STARTER_HABITAT_V2_3'and V.require('KascHabitatScenery').profile(map)then return 'kasc_habitat'end
 if (map.id or ''):match('^KA_MOLTRES_VOLCANO')and V.require('KascVolcano').profile(map)then return 'kasc_volcano'end
 if d.generation==2 then return nil end
 if d.tileset=='CAVERN'and V.require('KascLegendAtmosphere').profile(map)then return 'kasc_legend'end
 if d.tileset=='OVERWORLD' or d.tileset=='FOREST' or d.tileset=='PLATEAU'then return true end
 if d.tileset=='SHIP_PORT'and V.require('Gen1Harbor').kind(map)=='dock'then return true end
end
function M.isRoad(map,x,y)
 if not x or not y or type(map.tileAt)~='function'then return false end
 local function edge(ox,oy,dx,dy)
  for n=1,32 do
   local xx,yy=ox+dx*n,oy+dy*n
   if xx<0 or yy<0 or xx>=map.def.width*4 or yy>=map.def.height*4 then return false end
   local t=map:tileAt(xx,yy)
   if t~=35 then return t==16 or t==32 or t==33 end
  end
  return false
 end
 local function straight(xx,yy)
  return (edge(xx,yy,-1,0)and edge(xx,yy,1,0))
   or(edge(xx,yy,0,-1)and edge(xx,yy,0,1))
 end
 if straight(x,y)then return true end
 -- Fill a two-tile corner only when it directly joins proven horizontal
 -- and vertical road surfaces. Stay on the same blank road art throughout;
 -- do not jump over a curb or pave an adjacent garden/roof strip.
 local function joins(dx,dy)
  for sign=-1,1,2 do for distance=1,2 do
   local xx,yy=x+dx*sign*distance,y+dy*sign*distance
   if xx<0 or yy<0 or xx>=map.def.width*4 or yy>=map.def.height*4
      or map:tileAt(xx,yy)~=35 then break end
   if straight(xx,yy)then return true end
  end end
  return false
 end
 return joins(1,0)and joins(0,1)
end
local function checkerPaving(map,x,y)
 if not x or not y or not map.def.blocks or type(map.tileAt)~='function' then return false end
 local bx,by=math.floor(x/4),math.floor(y/4)
 local block=map.def.blocks[by*map.def.width+bx+1]
 local first,second
 if block==122 then first,second=44,48
 elseif block==123 then first,second=48,57
 else return false end
 -- Mods may reuse the block number. Only the complete native alternation
 -- is a paving motif; mixed shore, garden and custom blocks stay untouched.
 for dy=0,3 do for dx=0,3 do
  if map:tileAt(bx*4+dx,by*4+dy)~=((dx+dy)%2==0 and first or second)then return false end
 end end
 return true
end
function M.material(map,profile,tile,x,y)
 if not profile then return nil end
 if profile=='kasc_driftglass' and (tile==35 or tile==44 or tile==48 or tile==57)then return -160 end
 if profile=='kasc_legend'then return V.require('KascLegendAtmosphere').material(map,x,y)end
 if profile=='kasc_birth'then return V.require('KascBirthIsland').material(map,x,y)end
 if profile=='kasc_volcano'then return -177 end
 if profile=='kasc_sky'then return -162 end
 if profile=='kasc_habitat'then return V.require('KascHabitatScenery').material(map,tile)end
 local ts=map.def.tileset
 if ts=='FOREST' and safariMaps[map.id] and x and y then
  -- The paired ground flecks use the native palette, leaving bright green
  -- strips in otherwise procedural earth. Recognize the complete pair;
  -- reused tile IDs and encounter grass retain their own presentation.
  if (tile==57 and map:tileAt(x+1,y)==95)
    or (tile==95 and map:tileAt(x-1,y)==57)then return -171 end
  -- Direction marks are floor art for real warps. The open timber portal
  -- now identifies the exit, while its floor joins the surrounding path.
  if tile>=80 and tile<=83 and map.warpAtCell
    and map:warpAtCell(math.floor(x/2),math.floor(y/2))then return -171 end
 end
 -- Seafoam's native sand/path checker is one beach. Its approach planks
 -- become stone landings; the native collision and cave warps stay intact.
 if ts=='OVERWORLD' and map.id=='ROUTE_20' then
  if tile==44 or tile==48 or tile==49 or tile==50 or tile==51 or tile==84 then return -160 end
  if tile==60 then return -162 end
 end
 -- Ground materials never claim water, entrances or puzzle markings.
 -- Grass blades keep their native silhouette in the separate grass pass.
 if ts=='OVERWORLD'and map.id=='CINNABAR_ISLAND'and (tile==48 or tile==57)then return -160
 elseif ts=='OVERWORLD'and map.id=='LAVENDER_TOWN'and (tile==48 or tile==57)then return -173
 -- Native blocks $7A/$7B alternate path/grass pixels as decorative paving.
 -- Match both complete motifs; $7A is used in Fuchsia and on Route 12.
 elseif ts=='OVERWORLD' and (tile==44 or tile==48 or tile==57) and checkerPaving(map,x,y)then
  return map.id=='CINNABAR_ISLAND'and -160 or map.id=='LAVENDER_TOWN'and -173 or -163
 elseif ts=='OVERWORLD' and tile==35 then return M.isRoad(map,x,y)and -165 or -159
 elseif ts=='OVERWORLD' and tile==16 then return -168
 elseif ts=='OVERWORLD' and tile==32 then return -169
 elseif ts=='OVERWORLD' and tile==33 then return -170
 -- Native block $55 is entirely walkable paving ($5B), used for plazas
 -- and route paths. Keep it flat and match the existing grey stone pavers.
 elseif ts=='OVERWORLD' and tile==91 then return -162
 -- Native pier planks also contain strong alternating pixels. Use actual
 -- wood on these walking surfaces; Seafoam's stone landing is handled above.
 elseif ts=='OVERWORLD' and tile==60 then return -130
 elseif ts=='OVERWORLD' and (tile==0 or tile==17 or tile==48) then
  return (map.id=='ROUTE_16' or map.id=='ROUTE_17' or map.id=='ROUTE_18')and -165 or -163
 elseif ts=='OVERWORLD' and tile==57 then return -164
 elseif ts=='OVERWORLD' and tile==82 then return -159
 elseif ts=='FOREST' and tile==32 then return -161
 elseif ts=='FOREST' and tile==48 then return -171
 elseif ts=='FOREST' and safariMaps[map.id] and tile==30 then return -176
 elseif ts=='FOREST' and (tile==52 or tile==55)then return -161
 elseif ts=='OVERWORLD' and tile==44 then
  if map.id=='CINNABAR_ISLAND' or map.id=='ROUTE_19' or map.id=='ROUTE_20' or map.id=='ROUTE_21'then return -160 end
  return -159
 elseif ts=='FOREST' and tile==0 then return -161
 elseif ts=='PLATEAU' and tile==69 then return -159
 elseif ts=='PLATEAU' and (tile==35 or tile==44 or tile==45)then return -162 end
end
-- Only confirmed native water receives this material; keep the water sink,
-- shoreline geometry, collision and original atlas intact.
local waterTiles={
 OVERWORLD={[20]=true,[49]=true,[50]=true,[51]=true,[84]=true,
  -- The coastal classifier can normalize these submerged boundary cells
  -- to water. Their dry tree/reef counterparts must retain their geometry.
  [42]=true,[43]=true,[58]=true,[59]=true},
 SHIP_PORT={[20]=true,[58]=true},
 FOREST={[20]=true},
 PLATEAU={[20]=true,[31]=true,[50]=true,[51]=true},
}
function M.waterMaterial(map,profile,class,tile)
 if profile=='kasc_habitat'and class=='water'then return -174 end
 local d=map and map.def
 local tiles=d and waterTiles[d.tileset]
 if d and d.tileset=='SHIP_PORT'and V.require('Gen1Harbor').kind(map)~='dock'then return nil end
 if profile and tiles and d.generation~=2 and class=='water' and tiles[tile]then return -174 end
end
-- Only the existing recessed bank face gets stone. Keep piers and their
-- wood artwork, as well as all bank vertices and walking/Surf boundaries.
function M.bankMaterial(map,profile,class,tile,neighborClass)
 if not profile or not map or not map.def or map.def.generation==2
  or neighborClass~='water' or (class~='ground'and class~='grass')then return nil end
 if tile==60 and map.def.tileset=='OVERWORLD'then return map.id=='ROUTE_20' and -167 or -130 end
 -- Existing signed coastal lips carry their old shore-water art rather
 -- than the adjacent dry ground tile. They are still bank geometry.
 if map.def.tileset=='OVERWORLD'and (tile==49 or tile==50 or tile==51 or tile==84)then return -167 end
 if M.material(map,profile,tile)then return -167 end
end
M.waterGLSL=[[
vec4 outdoorWater(vec2 pos, float phase) {
 vec2 p=floor(pos*2.0)*0.5;
 float swell=sin(p.x*0.13+p.y*0.08-phase)*0.5+0.5;
 float ripple=sin(p.x*0.38-p.y*0.19+sin(p.y*0.06)+phase*0.7);
 float crest=smoothstep(0.91,1.0,ripple)*0.18;
 vec3 blue=mix(vec3(0.12,0.32,0.43),vec3(0.19,0.44,0.53),swell);
 return vec4(mix(blue,vec3(0.49,0.69,0.70),crest),1.0);
}
]]
-- The Route 14 eastern promenade uses a low quay instead of full trees.
-- Only confirmed tree footprints with native sea immediately to the east
-- qualify; inland trees, Cut bushes and every walkable/warp cell stay native.
function M.quayAt(map,x,y)
 local d=map and map.def
 if not d or map.id~='ROUTE_14' or d.generation==2 or d.width~=10 or d.height~=27
    or x<30 or type(map.tileAt)~='function' then return false end
 return map:tileAt(x+2,y)==20 and map:tileAt(x+2,y+1)==20
end
-- Tile 44 is also walkable grass: only the blocked wall use gets rock.
-- Tile 53 closes the exposed end/corner of the same native cliff chain.
local rockTiles={[1]=true,[2]=true,[17]=true,[19]=true,[30]=true,[36]=true,[13]=true,[29]=true,[39]=true,[44]=true,[52]=true,[53]=true,[54]=true,[55]=true}
-- Exposed terrain underneath a raised floor is earth/rock, not a vertical
-- copy of its grass, flowers or roof atlas. Harbour banks keep their own trim.
function M.foundationMaterial(map,profile,class,tile,neighborClass)
 local bank=M.bankMaterial(map,profile,class,tile,neighborClass)
 if bank then return bank end
 local d=map and map.def
 if profile and d and d.generation~=2 and M.stone:get()
    and (d.tileset=='OVERWORLD' or d.tileset=='FOREST' or d.tileset=='PLATEAU')
    and class~='water' then return -175 end
end
local leagueWall={[3]=true,[13]=true,[14]=true,[15]=true,[5]=true,[6]=true,
 [21]=true,[22]=true,[32]=true,[33]=true,[46]=true,[47]=true}
local jumpDirections={down={0,1},up={0,-1},left={-1,0},right={1,0}}
local jumpCompass={down='south',up='north',left='west',right='east'}
local function jumpLanding(map,x,y,dir,data)
 if map:inBounds(x,y)then return map:isWalkableCell(x,y)end
 -- Native jumps can finish on a connected map (notably Route4 -> Route3).
 local conn=map.def.connections and map.def.connections[jumpCompass[dir]]
 local dest=conn and data.maps and data.maps[conn.map]
 local ts=dest and data.tilesets and data.tilesets[dest.tileset]
 if not ts then return false end
 local w,h=dest.width*2,dest.height*2
 if dir=='up'then x,y=x-conn.offset*2,h-1
 elseif dir=='down'then x,y=x-conn.offset*2,0
 elseif dir=='left'then x,y=w-1,y-conn.offset*2
 else x,y=0,y-conn.offset*2 end
 x,y=math.max(0,math.min(w-1,x)),math.max(0,math.min(h-1,y))
 return require('src.world.Map').defPassable(dest,ts,x,y,false)
end
function M.jumpDirection(map,tx,ty,data)
 if not map or not map.def or map.def.generation==2 or map.def.tileset~='OVERWORLD'
    or not M.stone:get()then return nil end
 if not data then data=require('src.core.Game').data end
 local rules=data and data.field and data.field.ledges
 if not rules then return nil end
 local x,y=math.floor(tx/2),math.floor(ty/2)
 local tile=map:cellTile(x,y)
 for _,rule in ipairs(rules)do
  local d=jumpDirections[rule.input]
  if d and rule.facing==rule.input and (rule.tileset or 'OVERWORLD')=='OVERWORLD'
     and rule.ledgeTile==tile then
   local sx,sy=x-d[1],y-d[2];local lx,ly=x+d[1],y+d[2]
   if map:inBounds(sx,sy)
      and map:cellTile(sx,sy)==rule.standingTile
      and map:isWalkableCell(sx,sy)and jumpLanding(map,lx,ly,rule.input,data)then return rule.input end
  end
 end
end
-- A broken stone crest belongs only to an actual native jump barrier. It is
-- confined to that blocked tile; the adjacent walking surface never moves.
-- Two shallow rock facets share the terrain mesh, with no extra draw calls.
-- Shared edge samples avoid a repeating crenellated silhouette along a ledge.
function M.jumpLip(direction,tx,ty,h,push)
 local material={{-175,0},{-175,0},{-175,1},{-175,1}}
 local vertical=direction=='left'or direction=='right'
 local along,lane=vertical and ty or tx,vertical and tx or ty
 local function sample(s)
  local seed=(s*s*13+s*37+lane*53)%101
  return 1.6+(seed%10)*.1,6.5+(seed%7)*.25
 end
 local function point(s,y,z)
  local x=s
  if direction=='up'then z=8-z
  elseif direction=='right'then x,z=z,s
  elseif direction=='left'then x,z=8-z,s end
  return{x+tx*8,y,z+ty*8}
 end
 for i=0,1 do
  local a,b=i*4,(i+1)*4
  local ah,az=sample(along*2+i);local bh,bz=sample(along*2+i+1)
  local top={point(a,h+.2,2),point(b,h+.2,2),point(b,h+bh,bz),point(a,h+ah,az)}
  -- The foot reaches the drop edge even where the upper rock is recessed.
  -- Otherwise the old grass cap peeks out as a bright stripe below the lip.
  local base={point(a,h,2),point(b,h,2),point(b,h,8),point(a,h,8)}
  -- The cardinal transforms above include reflections; retain terrain winding.
  local reverse=direction=='up'or direction=='right'
  local function face(q,shade)
   if reverse then q={q[4],q[3],q[2],q[1]}end
   push(q,material,shade)
  end
  face(top,.95)
  for j=1,4 do
   local k=j%4+1;local p,q=top[j],top[k]
   face({base[k],base[j],p,q},j==3 and .72 or .80)
  end
 end
end
function M.wallMaterial(map,class,tile,face)
 if not map or not map.def or map.def.generation==2 or not M.stone:get()then return nil end
 if map.def.tileset=='FOREST' and safariMaps[map.id]
    and ((class=='wall' and safariHillWalls[tile])or(class=='ledge' and tile==46))then
  return face=='top' and -176 or -175
 end
 -- Structures admits only the connected, gameplay-significant Seafoam
 -- barrier to this class. Keep its low profile, replace the old flat drums.
 if map.id=='ROUTE_20' and map.def.tileset=='OVERWORLD' and class=='reef'
    and (tile==42 or tile==43 or tile==58 or tile==59)then return -175 end
 if map.def.tileset=='OVERWORLD'and (class=='ledge' or class=='wall')then
  if rockTiles[tile]then
   -- Natural rock is separate from harbour masonry. Jump lips keep a
   -- grassy cap and their exact original support/collision surface.
   return class=='ledge'and face=='top'and -164 or -175
  end
 elseif map.def.tileset=='PLATEAU'and (class=='cliff'or class=='bookcase')and leagueWall[tile]then
  return tile==3 and -167 or face=='top'and -162 or -172
 end
end
-- A craggy silhouette above the blocked hill rim, never on the walkable
-- plateau, stair or warp. World-space samples join across adjacent tiles;
-- the small stepped facets are baked once into the terrain mesh.
function M.safariRockCrown(map,class,tile,tx,ty,h,push)
 if not map or not map.def or map.def.generation==2 or map.def.tileset~='FOREST'
    or not safariMaps[map.id] or not M.stone:get() or class~='wall'
    or not safariHillWalls[tile] or map:isWalkableCell(math.floor(tx/2),math.floor(ty/2))
    or map:isWarpTileCell(math.floor(tx/2),math.floor(ty/2)) then return false end
 local material={{-175,0},{-175,0},{-175,1},{-175,1}}
 local function rise(x,z)
  return 2+2*math.floor((math.sin(x*.21+z*.13)+math.sin(x*.09-z*.26)+2)*1.5)
 end
 local function face(q,shade)push(q,material,shade)end
 for z=0,6,2 do for x=0,6,2 do
  local xx,zz=tx*8+x,ty*8+z
  local high=h+rise(xx+1,zz+1)
  face({{xx,high,zz},{xx+2,high,zz},{xx+2,high,zz+2},{xx,high,zz+2}},1)
  local sides={
   {0,-2,{{xx+2,0,zz},{xx,0,zz},{xx,high,zz},{xx+2,high,zz}},.82},
   {0,2,{{xx,0,zz+2},{xx+2,0,zz+2},{xx+2,high,zz+2},{xx,high,zz+2}},.9},
   {-2,0,{{xx,0,zz},{xx,0,zz+2},{xx,high,zz+2},{xx,high,zz}},.78},
   {2,0,{{xx+2,0,zz+2},{xx+2,0,zz},{xx+2,high,zz},{xx+2,high,zz+2}},.86}}
  for _,s in ipairs(sides)do
   local nx,nz=x+s[1],z+s[2]
   local low=(nx<0 or nx>6 or nz<0 or nz>6)and h or h+rise(xx+s[1]+1,zz+s[2]+1)
   if low<high then s[3][1][2],s[3][2][2]=low,low;face(s[3],s[4])end
  end
 end end
 return true
end
function M.grassGroups(map,groups)
 if not M.profile(map)then return groups end
 local result={}
 for _,group in ipairs(groups)do
  local quads={}
  for _,q in ipairs(group.quads or{})do
   -- Retain exactly the native silhouette, feet occlusion and instancing.
   local copy={};for k,v in pairs(q)do copy[k]=v end
   copy.uv={{-166,0},{-166,0},{-166,0},{-166,0}};quads[#quads+1]=copy
  end
  result[#result+1]={placements=group.placements,quads=quads}
 end
 return result
end
function M.register(P,F)
 V.require('Gen1NuggetBridge').register(P,F)
 local C=P.decorColors
 local function make(kind,w,d)
  local a={terrain=true,boxes={},step=1,frameW=w,frameH=d+40,depth=d,offsetY=-40};P.models[kind]=a
  -- Only authored deciduous foliage receives the seasonal palette. Trunks
  -- retain their non-green texels; conifers (variant 3) remain evergreen.
  a.seasonalFoliage=(kind:match('^kanto_tree_') and not kind:match('_3$'))
    or kind:match('^kanto_cut_tree_') or (kind:match('^kanto_pillar_tree_') and not kind:match('_3$'))
  a.seasonalFoliage=a.seasonalFoliage and true or false
  return function(x,y,z,bw,bh,bd,c)
   assert(x>=0 and z>=0 and x+bw<=w and z+bd<=d,'outdoor footprint '..kind)
   a.boxes[#a.boxes+1]={x,y,z,bw,bh,bd,c}
  end
 end
 -- Cut bushes use their exact four native tiles. A slim forked trunk
 -- and low, asymmetric foliage distinguish them from full boundary trees.
 for variant=1,3 do
  local b=make('kanto_cut_tree_'..variant,16,16)
  b(6,0,6,4,2,4,C.walnut);b(7,2,7,2,12,2,C.oak)
  -- Exposed pale bark and a forked, sparse crown read as the small Cut
  -- sapling even at night. Keep the whole silhouette in its blocked cell.
  b(6,4,6,4,3,4,C.paperWindow)
  b(4,8,7,3,2,2,C.oak);b(3,9,7,2,5,2,C.oak)
  b(9,10,7,3,2,2,C.oak);b(11,11,7,2,3,2,C.oak)
  b(1,12,4,6,4,7,C.leaf or 12)
  b(2,16,5,4,2,5,C.leafLight or 5)
  b(9,13,5,6,4,6,C.leaf or 12)
  b(10,17,6,4,2,4,C.leafLight or 5)
  b(6,17+variant,6,4,3,4,C.leafLight or 5)
 end
 F.patterns[#F.patterns+1]={kind='kanto_cut_tree_1',sets={OVERWORLD=true},
  tiles={{45,46},{61,62}},voxelOnly=true,groundTile=44,
  enabled=function()return M.trees:get()end,
  guard=function(map,x,y)return map.def.generation~=2 and x%2==0 and y%2==0
    and not map:isWarpTileCell(x/2,y/2)end,
  variant=function(map,x,y)return 'kanto_cut_tree_'..(1+(math.floor(x/2)+math.floor(y/2))%3)end}
 -- Three small shoreline palms. Add their mesh without replacing the quay
 -- or its submerged cells; even with decoration enabled Surf stays native.
 for variant,at in ipairs({{8,24},{12,28},{38,28}})do
  local kind='cinnabar_palm_'..variant
  local b=make(kind,16,16);local height=24+variant*3
  for y=0,height-1,2 do
   local lean=math.floor(y/12)*(variant==2 and -1 or 1)
   b(6+lean,y,3,3,2,3,y%6==0 and C.oak or C.walnut)
  end
  -- Six separated, drooping fronds with a bright ridge and darker tips.
  for ray=0,5 do
   local angle=ray*math.pi/3+variant*.14
   for n=0,6 do
    local x=math.floor(7+math.cos(angle)*n)
    local z=math.floor(7+math.sin(angle)*n)
    local width=n<5 and 2 or 1
    b(x,height+2-math.floor(n*n/12),z,width,2,width,
      n<3 and (C.leafLight or C.sage)or n<5 and (C.leaf or 12)or (C.leafDark or 10))
   end
  end
  b(6,height-2,5,2,3,2,C.walnut);b(9,height-1,6,2,2,2,C.oak)
  F.patterns[#F.patterns+1]={kind=kind,sets={OVERWORLD=true},maps={CINNABAR_ISLAND=true},
   x=at[1],y=at[2],tiles={{51,51},{20,20}},voxelOnly=true,keepTerrain=true,
   enabled=function()return M.trees:get()end,
   guard=function(map,x,y)
    return map.def.generation~=2 and map.def.width==10 and map.def.height==9
     and not map:isWalkableCell(x/2,y/2)and not map:isWarpTileCell(x/2,y/2)
   end}
 end
 for size=1,2 do for variant=1,5 do
  local w=16*size;local b=make('kanto_tree_'..size..'_'..variant,w,w)
  -- All round silhouettes can host cherry blossom; placement chooses a
  -- stable irregular subset. Conifers never enter the blossom draw group.
  if variant~=3 then P.models['kanto_tree_'..size..'_'..variant].blossomSource={w/2,(variant==4 and 28 or 25)+(size-1)*8,w/2} end
  local mid=w/2;local tr=2*size
  b(mid-tr,0,mid-tr,tr*2,12*size,tr*2,variant==4 and 14 or C.walnut)
  b(mid-tr-1,0,mid-tr-1,tr*2+2,2,tr*2+2,C.oak)
  local colors={C.leafDark or 10,C.leaf or 12,C.leafLight or C.sage}
  if variant==3 then
   -- Conifers taper in four unequal whorls, with clipped round corners.
   for i=0,4 do local r=(7-i)*size
    for x=0,w-2,2 do for z=0,w-2,2 do
     if (x+1-mid)^2+(z+1-mid)^2<=r*r then b(x,8*size+i*4,z,2,4,2,colors[1+(x+z+i)%3])end
    end end
   end
  else
   local cy=17+(size-1)*8;local ry=variant==4 and 11 or 8
   for x=0,w-2,2 do for z=0,w-2,2 do for y=cy-ry,cy+ry,2 do
    local dx,dz=(x+1-mid)/(w/2-1),(z+1-mid)/(w/2-1)
    local dy=(y+1-cy)/ry
    local lump=0.08*math.sin((x+variant*3)*.6)*math.cos(z*.7)
    if dx*dx+dy*dy+dz*dz<1+lump then
     local color=colors[1+(math.floor(x/4)+math.floor(z/4)+math.floor(y/3)+variant)%3]
     if variant==2 and y>cy-2 and (x*13+z*7+y*3)%29==0 then color=1 end
     b(x,y,z,2,2,2,color)
    end
   end end end
  end
 end end
 for variant=1,4 do
  local b=make('kanto_stump_'..variant,16,16)
  local height=6+variant%3*2
  for x=0,14,2 do for z=0,14,2 do
   local r=math.sqrt((x+1-8)^2+(z+1-8)^2)
   if r<7 then
    local bark=(x+z+variant)%4==0 and C.oak or C.walnut
    b(x,0,z,2,height,2,bark)
    local ring=math.floor(r)%3==0 and C.walnut or C.oak
    b(x,height,z,2,1,2,ring)
   elseif r<8 and (x+z+variant)%3==0 then b(x,0,z,2,2,2,C.walnut)end
  end end
  b(2,1,5,2,2,4,C.leafDark or 10)
 end
 for variant=1,3 do
  local kind='kanto_pillar_tree_'..variant
  local b=make(kind,16,32)
  P.models[kind].frameH=96;P.models[kind].offsetY=-64
  b(0,0,16,16,32,16,14)
  for y=7,23,8 do b(0,y,31,16,1,1,C.silver)end
  b(0,30,16,16,2,16,4)
  -- The native canopy is drawn above the first pillar cell. Fold both
  -- rows onto that same support, keeping the whole 16x32 footprint.
  for _,q in ipairs(P.models['kanto_tree_1_'..variant].boxes)do
   b(q[1],q[2]+32,q[3]+16,q[4],q[5],q[6],q[7])
  end
 end
 for variant=1,4 do
  local b=make('kanto_rock_'..variant,16,16)
  local height=variant==4 and 5 or 8+variant*2
  b(2,0,2,12,2,12,16);b(1,2,3,14,3,10,14)
  b(3,5,2,10,height-4,11,C.silver);b(5,height+1,4,6,2,7,14)
  b(3,3,3,3,1,3,10)
 end
 -- Low, irregular outcrops for the League approach. Build solid columns
 -- from overlapping lobes, without the rectangular plinth of boundary rocks.
 for variant=1,4 do
  local b=make('kanto_plateau_rock_'..variant,16,16)
  local lobes={{6+variant%2,7,6,6,9+variant},{11,10,4,5,5+variant%3},{4,11,4,3,4}}
  for x=0,14,2 do for z=0,14,2 do
   local height=0
   for _,l in ipairs(lobes)do
    local r=((x+1-l[1])/l[3])^2+((z+1-l[2])/l[4])^2
    if r<1 then height=math.max(height,l[5]*math.sqrt(1-r))end
   end
   height=math.floor(height+0.6*math.sin(x*2+z+variant))
   if height>=2 then
    local color=(x+2*z+variant)%7<2 and C.silver or 14
    b(x,0,z,2,height,2,color)
    if height<5 and (x*3+z+variant)%11==0 then b(x,height,z,2,1,2,C.leafDark or 10)end
   end
  end end
 end
 -- Safari's small boundary boulders have their own four-tile drawing.
 -- The generic wall reader used to extrude its monochrome stippling into
 -- rectangular towers. Low, mossy stone keeps the blocked plot readable.
 for variant=1,4 do
  local b=make('kanto_safari_rock_'..variant,16,16)
  for x=0,14,2 do for z=0,14,2 do
   local dx,dz=(x+1-8)/(7+variant%2),(z+1-8)/7.5
   local r=dx*dx+dz*dz
   if r<1 then
    local h=math.max(2,math.floor((10+variant)*math.sqrt(1-r)))
    local stone=(x+z*3+variant)%7<2 and C.looseRock3 or C.looseRock2
    b(x,0,z,2,h,2,stone)
    if h>4 and (x*3+z+variant)%11==0 then
     b(x,h,z,2,1,2,C.leafDark or 10)
    end
   end
  end end
 end
 for sides=0,3 do local b=make('kanto_safari_fence_post_'..sides,16,32)
  b(4,0,20,8,3,8,C.looseRock1)
  b(5,3,21,6,20,6,C.oldTimber)
  b(5,3,21,1,20,1,C.oldBoard)
  for _,y in ipairs({8,16})do b(4,y,20,8,2,8,C.oldBeam)end
  b(3,23,19,10,2,10,C.oldBoard);b(5,25,21,6,1,6,C.oldTimber)
  -- Restore the native animal-topped Safari posts: weathered stone head
  -- above the fence, entirely within the already blocked 16px footprint.
  b(4,26,20,8,6,8,C.looseRock2)
  b(3,30,21,10,3,7,C.looseRock1)
  b(5,27,28,6,3,3,C.looseRock2)
  b(4,33,21,2,3,2,C.looseRock1);b(10,33,21,2,3,2,C.looseRock1)
  b(7,30,29,2,3,2,C.silver);b(7,33,29,1,2,1,C.silver)
  b(4,30,27,1,1,1,C.oldBeam);b(11,30,27,1,1,1,C.oldBeam)
  b(3,30,21,2,1,2,C.leafDark);b(4,28,20,1,3,1,C.leafDark)
  for _,y in ipairs({8,16})do
   for _,part in ipairs({{sides%2==1,0},{sides>=2,11}})do
    if part[1]then
     b(part[2],y,21,5,3,4,C.oldTimber);b(part[2],y+2,21,5,1,4,C.oldBoard)
    end
   end
  end
 end
 do local b=make('kanto_safari_fence_rail',16,16)
  for _,y in ipairs({8,16})do
   b(0,y,5,16,3,4,C.oldTimber);b(0,y+2,5,16,1,4,C.oldBoard)
  end
 end
 do local b=make('kanto_hedge',16,16)
  b(0,0,3,16,2,10,16)
  for y=2,6,3 do for x=0,12,4 do b(x,y,3,4,3,10,14)end end
  b(0,8,2,16,2,12,10);b(0,10,4,16,1,8,12)
 end
 do local b=make('kanto_boundary_shrub',16,16)
  b(1,0,4,14,2,8,C.oak)
  local colors={C.leafDark or 10,C.leaf or 12,C.leafLight or C.sage}
  for x=0,14,2 do for z=2,12,2 do for y=2,12,2 do
   local cx=x<8 and 4 or 12
   if ((x+1-cx)/5)^2+((z+1-8)/6)^2+((y+1-7)/7)^2<1.2 then
    b(x,y,z,2,2,2,colors[1+(x+z+y)%3])
   end
  end end end
 end
 do local b=make('kanto_boundary_wall',16,16)
  b(0,0,3,16,2,10,C.stone or 14)
  for row=0,2 do
   local offset=row%2*3
   for x=-offset,15,6 do
    local left,right=math.max(0,x),math.min(16,x+5)
    if right>left then b(left,2+row*3,4,right-left,3,8,C.warmBrick or C.oak)end
   end
  end
  b(0,11,2,16,2,12,C.stone or 14)
 end
 do local b=make('kanto_quay_east',16,16)
  b(7,0,0,9,2,16,C.stone or 14)
  b(9,2,0,6,5,16,C.walnut)
  for row=0,1 do
   for z=-row*4,15,8 do
    local lo,hi=math.max(0,z),math.min(16,z+7)
    if hi>lo then b(8,2+row*3,lo,8,3,hi-lo,C.stone or 14)end
   end
  end
  b(7,8,0,9,2,16,C.silver or 4)
 end
 do local b=make('kanto_quay_south',16,16)
  b(0,0,7,16,2,9,C.stone or 14)
  b(0,2,9,16,6,7,C.stone or 14)
  b(0,8,7,16,2,9,C.silver or 4)
  b(0,4,8,16,1,1,C.walnut)
 end
 do local b=make('kanto_post',8,16)
  b(2,0,6,4,9,4,C.oak);b(1,9,5,6,2,6,C.walnut);b(2,11,6,4,1,4,14)
 end
 local petals={4,11,C.purple,15,7,1}
 local clusters={
  {{2,2,4},{5,5,3}}, {{4,3,4}}, {{2,5,3},{5,2,5}},
  {{2,2,3},{5,4,4},{2,6,2}}, {{3,5,4},{6,2,3}}, {{3,2,5},{5,6,3}},
 }
 for variant=1,#petals do
  local b=make('kanto_flower_'..variant,8,8)
  local model=P.models['kanto_flower_'..variant]
  model.frost=true
  model.groundParts={}
  local stem=C.leafDark or 10;local petal=petals[variant]
  for _,at in ipairs(clusters[variant])do
   local x,z,h=at[1],at[2],at[3]
   local first=#model.boxes+1
   b(x,0,z,1,h,1,stem);b(x-1,1,z,3,1,1,C.leaf or 12)
   b(x-1,h,z,3,1,1,petal);b(x,h,z-1,1,1,3,petal);b(x,h+1,z,1,1,1,11)
   model.groundParts[#model.groundParts+1]={x=x+.5,z=z+.5,first=first,last=#model.boxes}
  end
 end
 F.patterns[#F.patterns+1]={kind='kanto_flower_1',sets={OVERWORLD=true},tiles={{3}},voxelOnly=true,groundTile=44,terrainDecoration=true,
  enabled=function(prop)return (prop.mapId=='PALLET_TOWN' and V.require('Gen1PalletVillage').surrounds or M.trees):get()end,
  guard=function(map)return map.def.generation~=2 end,
  variant=function(map,x,y)
   -- Occasional warm pink, blue and red patches among the original beds.
   -- Select by position once at placement; no per-frame colour or geometry work.
   local patch=(math.floor(x/8)*7+math.floor(y/8)*11)%11
   local shade=1+(x*17+y*31+x*y*7)%3
   return 'kanto_flower_'..(patch<3 and 4+patch or shade)
  end}
 local function region(id)
  if id=='KANTO_ASCENDANT_DRIFTGLASS'then return 'rock' end
  if id=='ROUTE_8'then return 'hedge' end
  if id=='CINNABAR_ISLAND' or id=='ROUTE_19' or id=='ROUTE_20' or id=='ROUTE_21'then return 'rock' end
  return 'tree'
 end
 local function add(grid,set,size,border)
  F.patterns[#F.patterns+1]={kind='kanto_tree',sets={[set]=true},tiles=grid,voxelOnly=true,
   groundTile=function(map,x,y)return V.require('Gen1Harbor').quayAt(map,x,y)and 20 or set=='FOREST'and 0 or 44 end,
   guard=function(map,x,y)
    if map.def.generation==2 or map.id=='PALLET_TOWN' or map.id=='ROUTE_20' then return false end
    if region(map.id)=='rock' and map.id~='KANTO_ASCENDANT_DRIFTGLASS'
       and (x<8 or y<8 or x>=map.def.width*4-8 or y>=map.def.height*4-8)then
     -- Only the short shore entrances below Pallet/Fuchsia get visible
     -- stone props. The outer sea boundary stays open toward the horizon.
     local shore = (map.id=='ROUTE_21' and y<6)
       or (map.id=='ROUTE_19' and y<20 and x>=4 and x<map.def.width*4-4)
     if not shore then return false end
    end
    return x%2==0 and y%2==0 and not map:isWarpTileCell(x/2,y/2)
      and not map:isWalkableCell(x/2,y/2)
   end,
   enabled=function(prop)return ((prop.kind=='kanto_quay_east'or prop.kind=='kanto_quay_south') and M.stone or region(prop.mapId)=='tree' and M.trees or M.stone):get()end,
   variant=function(map,x,y)
    if V.require('Gen1Harbor').quayAt(map,x,y)then return 'kanto_quay_south'end
    if M.quayAt(map,x,y)then return 'kanto_quay_east'end
    local n=math.floor(x/2)*7+math.floor(y/2)*11
    for i=1,#map.id do n=n+map.id:byte(i)end
    local r=region(map.id)
    if r=='hedge'then
     local section=(math.floor(x/12)+math.floor(y/12))%3
     return ({'kanto_hedge','kanto_boundary_shrub','kanto_boundary_wall'})[section+1]
    elseif r=='rock'then return 'kanto_rock_'..(1+n%4)end
    return 'kanto_tree_'..size..'_'..(1+n%5)
   end}
 end
 add({{4,5,6,7},{35,21,22,23},{36,37,38,39},{0,53,54,48}},'FOREST',2)
 add({{42,43},{58,59}},'OVERWORLD',1)
 add({{64,65},{80,81}},'OVERWORLD',1)
 local function nativeObstacle(map,x,y,w,h)
  if map.def.generation==2 or x%2~=0 or y%2~=0 then return false end
  for dy=0,h-1,2 do for dx=0,w-1,2 do
   if map:isWarpTileCell((x+dx)/2,(y+dy)/2)or map:isWalkableCell((x+dx)/2,(y+dy)/2)then return false end
  end end
  return true
 end
 F.patterns[#F.patterns+1]={kind='kanto_stump_1',sets={FOREST=true},
  tiles={{2,3},{18,19}},voxelOnly=true,groundTile=0,
  enabled=function()return M.trees:get()end,
  guard=function(map,x,y)return nativeObstacle(map,x,y,2,2)end,
  variant=function(map,x,y)return 'kanto_stump_'..(1+(math.floor(x/2)*7+math.floor(y/2)*11)%4)end}
 F.patterns[#F.patterns+1]={kind='kanto_safari_rock_1',sets={FOREST=true},
  maps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true},
  tiles={{84,85},{86,87}},voxelOnly=true,groundTile=48,
  enabled=function()return M.stone:get()end,
  guard=function(map,x,y)return nativeObstacle(map,x,y,2,2)end,
  variant=function(map,x,y)return 'kanto_safari_rock_'..(1+(math.floor(x/2)*7+math.floor(y/2)*11)%4)end}
 for _,p in ipairs({
  {kind='kanto_safari_fence_post_0',tiles={{48,48},{10,11},{26,27},{75,76}},
   variant=function(map,x,y)
    local left=map:tileAt(x-1,y+2)==66 and map:tileAt(x-1,y+3)==67
    local right=map:tileAt(x+2,y+2)==66 and map:tileAt(x+2,y+3)==67
    return 'kanto_safari_fence_post_'..((left and 1 or 0)+(right and 2 or 0))
   end},
  {kind='kanto_safari_fence_rail',tiles={{66,66},{67,67}}},
 })do
  p.sets={FOREST=true};p.maps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
  p.voxelOnly=true;p.groundTile=48
  p.enabled=function()return M.stone:get()end
  local height=#p.tiles
  p.guard=function(map,x,y)return nativeObstacle(map,x,y,2,height)end
  F.patterns[#F.patterns+1]=p
 end
 F.patterns[#F.patterns+1]={kind='kanto_plateau_rock_1',sets={PLATEAU=true},
  tiles={{42,43},{34,29}},voxelOnly=true,groundTile=44,
  enabled=function()return M.stone:get()end,
  guard=function(map,x,y)return nativeObstacle(map,x,y,2,2)end,
  variant=function(map,x,y)return 'kanto_plateau_rock_'..(1+(math.floor(x/2)*7+math.floor(y/2)*11)%4)end}
 F.patterns[#F.patterns+1]={kind='kanto_pillar_tree_1',sets={PLATEAU=true},
  tiles={{7,8},{23,24},{32,33},{46,47}},voxelOnly=true,groundTile=44,
  enabled=function()return M.trees:get()end,
  guard=function(map,x,y)return nativeObstacle(map,x,y,2,4)end,
  variant=function(map,x,y)return 'kanto_pillar_tree_'..(1+(math.floor(x/2)+math.floor(y/2))%3)end}
 F.patterns[#F.patterns+1]={kind='kanto_post',sets={OVERWORLD=true},tiles={{14},{85}},voxelOnly=true,groundTile=44,
  enabled=function()return M.stone:get()end,
  guard=function(map,x,y)return map.def.generation~=2 and map.id~='PALLET_TOWN' and not map:isWarpTileCell(math.floor(x/2),math.floor(y/2))end}
 V.require('Gen1BoundaryVegetation').register(P,F,M)
end
function M.bind(invalidate)
 for _,setting in ipairs({M.ground,M.trees,M.stone})do for _,method in ipairs({'setIndex','sync'})do
  local old=setting[method]
  setting[method]=function(self,...)
   local before=self:get();local result=old(self,...)
   if before~=self:get()then invalidate()end
   return result
  end
 end end
end
return M
