-- Solid, original voxel props for the native Gen1 item-object sprites.
-- Live entities retain all script/visibility ownership; this is render-only.
local V = ...
local Assets = require('src.render.Assets')
local G = V.require('Voxel3D')
local Mat4 = V.require('Mat4')
local Budget = V.require('BuildBudget')
local P = {models={}}
P.setting = V.require('ModSetting').new('voxelItems', 'Voxel Items', {true,false}, {'ON','OFF'})
local cache, texture = {}, nil
local sharedGeometry={}
local meshBounds=setmetatable({},{__mode='k'})
function P.bounds(mesh)return meshBounds[mesh]end
local palette = {
  {211,67,55}, {235,231,216}, {48,51,57}, {251,247,224},
  {174,40,46}, {231,77,65}, {94,201,223}, {28,63,71},
  {145,216,198}, {75,132,131}, {247,197,80}, {100,170,118},
  {117,33,43}, {203,213,210}, {249,135,106}, {56,80,86},
}
P.typeColors = {
  NORMAL={174,174,147}, FIRE={224,103,66}, WATER={95,166,205},
  ELECTRIC={246,207,72}, GRASS={124,174,107}, ICE={133,216,224},
  FIGHTING={191,91,72}, POISON={158,104,182}, GROUND={199,165,99},
  FLYING={152,171,224}, PSYCHIC={226,115,160}, BUG={162,182,70},
  ROCK={168,150,92}, GHOST={123,109,165}, DRAGON={127,113,205},
  DARK={108,96,88}, STEEL={167,185,193}, FAIRY={227,165,197},
  ARCHIVE={143,150,153},
}
local typeIndex={}
P.typeOrder={'NORMAL','FIRE','WATER','ELECTRIC','GRASS','ICE','FIGHTING','POISON',
  'GROUND','FLYING','PSYCHIC','BUG','ROCK','GHOST','DRAGON','DARK','STEEL','FAIRY','ARCHIVE'}
for _,kind in ipairs(P.typeOrder) do palette[#palette+1]=P.typeColors[kind];typeIndex[kind]=#palette end
P.decorColors={}
for _,entry in ipairs({{'walnut',99,70,54},{'oak',177,137,88},{'navy',40,62,85},
    {'purple',117,78,143},{'sage',179,201,169},{'silver',159,180,181},
    {'clay',171,85,62},{'slate',80,102,118},{'roofGreen',69,105,86},
    {'leafDark',47,92,57},{'leaf',72,124,67},{'leafLight',109,155,76},
    {'warmBrick',181,147,116},{'stone',146,153,145},
    {'oldTimber',112,87,64},{'oldBeam',67,50,41},{'oldBoard',133,108,79},
    {'oldShingle',75,67,57},{'paperWindow',205,182,130},
    {'fadedPlum',79,66,84},{'dustyGlass',101,121,116},{'oldPlaster',146,139,122},
    {'dryLeaves',104,96,62},
    {'looseRock1',95,94,88},{'looseRock2',126,124,112},{'looseRock3',157,152,133},
    {'looseRock4',94,83,70},{'looseRock5',128,111,88},{'looseRock6',159,140,111},
    {'martBlue',43,105,184},
    {'hauntedStone',96,99,111},{'hauntedMortar',49,51,63},
    {'hauntedWeathered',128,130,133},{'hauntedSlate',55,58,74},{'hauntedGlass',112,133,119},{'silphGlass',113,178,199}})do
  palette[#palette+1]={entry[2],entry[3],entry[4]};P.decorColors[entry[1]]=#palette
end
P.palette = palette
local directions = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}

P.objectKinds = {
  KA_EEVEE_MOSS_VIRIDIAN='moss_stone', KA_HEVO_ALTAR_MOSS_FIELD='moss_stone',
  KA_EEVEE_ICE_SEAFOAM='ice_stone', KA_HEVO_ALTAR_ICE_FIELD='ice_stone',
}
local identities={}
local vanillaStarters={OAKSLAB_CHARMANDER_POKE_BALL='CHARMANDER',
  OAKSLAB_SQUIRTLE_POKE_BALL='SQUIRTLE',OAKSLAB_BULBASAUR_POKE_BALL='BULBASAUR',
  OAKSLAB_EEVEE_POKE_BALL='EEVEE',OAKSLAB_PIKACHU_POKE_BALL='PIKACHU'}
function P.ballKind(species,data)
  local def=data and data.pokemon and data.pokemon[species]
  local kind=def and def.types and def.types[1]
  kind=tostring(kind or ''):upper():gsub('_TYPE$','')
  return 'ball_'..(typeIndex[kind] and kind or 'ARCHIVE'):lower()
end

-- Read existing KASC state; never choose a partner or generate an NG+ draw.
function P.labKind(name,game)
  local data=game.data or require('src.core.Data')
  local bucket=game.save and game.save.modData and game.save.modData.kanto_ascendant
  local run=bucket and bucket.legacy_journey
  if type(run)=='table' then
    if name=='OAKSLAB_SQUIRTLE_POKE_BALL' or name=='OAKSLAB_EEVEE_POKE_BALL' then
      return 'ball_archive'
    elseif name=='OAKSLAB_CHARMANDER_POKE_BALL' then
      local kasc=game.mods and game.mods.exports and game.mods.exports.kanto_ascendant
      local provider=kasc and kasc.legacyStarters
      if provider and type(provider.heroChoice)=='function' then
        local ok,hero=pcall(provider.heroChoice,game.save)
        if ok and type(hero)=='table' then return P.ballKind(hero.species,data) end
      end
      return 'ball_archive'
    elseif name=='OAKSLAB_BULBASAUR_POKE_BALL' then
      return P.ballKind(type(run.rivalPartner)=='table' and run.rivalPartner.base,data)
    end
  end
  if vanillaStarters[name] then return P.ballKind(vanillaStarters[name],data) end
end

function P.kind(def,seed)
  if not P.setting:get() then return nil end
  if not def or def.walker or (def.frames or 1) ~= 1 then return nil end
  if def.id == 'SPRITE_OLD_AMBER' then return 'old_amber' end
  if def.id == 'SPRITE_POKE_BALL' or def.id == 'SPRITE_FOSSIL' then
    if type(seed)=='string' then
      local Data=require('src.core.Data')
      local mapId,index=seed:match('^(.-)_obj_(%d+)$')
      local map=mapId and Data.maps and Data.maps[mapId]
      local cached=identities[seed]
      if not cached or cached.map~=map then
        local found=false
        for _,obj in ipairs(map and map.objects or {}) do
          if obj.index==tonumber(index) then found=obj;break end
        end
        cached={map=map,object=found};identities[seed]=cached
      end
      local obj=cached.object
      if obj then
        if P.objectKinds[obj.name] then return P.objectKinds[obj.name] end
        if P.itemKinds and P.itemKinds[obj.item] then return P.itemKinds[obj.item] end
        if obj.pokemon or obj.name=='FIGHTINGDOJO_HITMONLEE_POKE_BALL'
            or obj.name=='FIGHTINGDOJO_HITMONCHAN_POKE_BALL' then return 'ball' end
        if mapId=='OAKS_LAB' then
          local kind=P.labKind(obj.name,require('src.core.Game'))
          if kind then return kind end
        end
      end
    end
    return def.id=='SPRITE_FOSSIL' and 'helix_fossil' or 'item_capsule'
  end
  if def.id == 'SPRITE_POKEDEX' then
    if type(seed)~='string' then return 'pokedex' end
    local mapId,index=seed:match('^(.-)_obj_(%d+)$')
    local data=require('src.core.Data')
    local map=mapId and data.maps and data.maps[mapId]
    for _,obj in ipairs(map and map.objects or {})do
      if obj.index==tonumber(index) then
        if obj.name=='BLUESHOUSE_TOWN_MAP' then return 'town_map' end
        if obj.name=='MRFUJISHOUSE_POKEDEX' then return 'magazine' end
        if obj.name and obj.name:match('^POKEMONMANSION.*_DIARY%d*$') then return 'research_diary' end
        if obj.name=='OAKSLAB_POKEDEX1' or obj.name=='OAKSLAB_POKEDEX2' then return 'pokedex' end
      end
    end
    -- Reused book artwork is not proof that an unknown object is a Pokédex.
    return nil
  end
end

-- Half-pixel cells give the small device crisp buttons and stepped edges.
-- The ball uses the same 4.3-radius voxel sphere as Orange Island's Ivy lab.
function P.geometry(kind)
  local cells, ordered = {}, {}
  local ballType=kind:match('^ball_(.+)$')
  local ball=kind=='ball' or ballType~=nil
  local authored=P.models[kind]
  -- Architectural frames include sub-voxel metal profiles. Retain their
  -- authored boxes exactly instead of dropping thin pieces on the item grid.
  if authored and authored.directBoxes then
    local vertices,indices={},{}
    for _,b in ipairs(authored.boxes)do
      for face,corners in ipairs(G.FACE_CORNERS)do
        local base=#vertices
        for _,p in ipairs(corners)do
          vertices[#vertices+1]={b[1]+p[1]*b[4],b[2]+p[2]*b[5],b[3]+p[3]*b[6],
            (b[7]-.5)/#palette,.5,G.FACE_SHADE[face]}
        end
        for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=base+i end
      end
    end
    return vertices,indices
  end
  local step = authored and (authored.step or 1) or ball and 1 or 0.5
  local function key(x,y,z) return x..','..y..','..z end
  -- Integer lattices can use exact numeric addresses instead of allocating
  -- coordinate strings for every voxel and each of its six neighbours.
  -- One empty border cell prevents wraparound at either end of a row.
  local regular=true
  if authored and #authored.boxes>0 then
    local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
    for _,b in ipairs(authored.boxes)do for axis=1,3 do
      local a,z=b[axis]/step,(b[axis]+b[axis+3])/step
      if a~=math.floor(a)or z~=math.floor(z)then regular=false end
      lo[axis]=math.min(lo[axis],a);hi[axis]=math.max(hi[axis],z)
    end end
    local sx,sy,sz=hi[1]-lo[1]+2,hi[2]-lo[2]+2,hi[3]-lo[3]+2
    if regular and sx*sy*sz<2^52 then
      key=function(x,y,z)return x-lo[1]+1+(y-lo[2]+1)*sx+(z-lo[3]+1)*sx*sy end
    end
  end
  if authored and regular and #authored.boxes>0 and #authored.boxes<=400 then
    return V.require('BoxVoxelFaces')(authored.boxes,step,#palette,G)
  end
  local function put(x,y,z,c)
    Budget.tick()
    local k=key(x,y,z)
    if not cells[k] then ordered[#ordered+1]={x,y,z,k} end
    cells[k]=c
  end
  local function box(x,y,z,w,h,d,c)
    for ix=x/step,(x+w)/step-1 do
      for iy=y/step,(y+h)/step-1 do
        for iz=z/step,(z+d)/step-1 do put(ix,iy,iz,c) end
      end
    end
  end
  if authored then
    for _,b in ipairs(authored.boxes) do box(unpack(b)) end
  elseif ball then
    if ballType then
      box(2,0,3,12,1,10,3)
      box(3,1,4,10,1,8,typeIndex[ballType:upper()] or typeIndex.ARCHIVE)
    end
    for x=3,12 do for y=0,8 do for z=3,12 do
      if (x+.5-8)^2+(y+.5-4.5)^2+(z+.5-8)^2 <= 4.3^2 then
        local c=y>=4 and 1 or 2
        if y==4 then c=3 end
        if z>=11 and x>=6 and x<=9 and y>=3 and y<=6 then c=3 end
        if z>=11 and x>=7 and x<=8 and y>=4 and y<=5 then c=4 end
        if y>=7 and z<=7 and x>=6 and x<=7 then c=15 end
        put(x,y+(ballType and 2 or 0),z,c)
      end
    end end end
  elseif kind == 'moss_stone' or kind == 'ice_stone' then
    -- Chunky mineral with a raised leaf vein / icy crystalline crown.
    for x=4,27 do for y=0,15 do for z=5,26 do
      local dx,dz=(x+.5-16)/11,(z+.5-16)/10
      local radius=dx*dx+dz*dz
      if radius < 1 and y < 4+(1-radius)*10 then
        local c=kind=='ice_stone' and 7 or 16
        if y>6 then c=kind=='ice_stone' and 9 or 12 end
        if kind=='moss_stone' and (x+2*z)%11<4 and y>=4 then c=10 end
        put(x,y,z,c)
      end
    end end end
    if kind=='moss_stone' then
      for z=8,23 do
        local w=math.floor(4*math.sin((z-7)/17*math.pi))
        local y=13-math.floor(math.abs(z-16)/3)
        for x=16-w,16+w do put(x,y,z,12);put(x,y-1,z,12) end
        put(16,y+1,z,11)
      end
    else
      box(7,5,6,2,4,2,7);box(7.5,9,6.5,1,1,1,4)
      box(9,4,8,1.5,3,2,9);box(4.5,4,7,1.5,2,1.5,14)
    end
  elseif kind == 'pokedex' then
    -- Two rounded, open red leaves, a dark hinge, and raised instrument faces.
    for _,x in ipairs({1.5,8.5}) do
      box(x+.5,0,3.5,5,1,9,13)
      box(x,0.5,4,6,1,8,5)
      box(x+.5,1.5,4,5,0.5,8,6)
      box(x+.5,2,4,5,0.5,1,1)
    end
    box(7.5,.5,4,.5,1.5,8,3)
    box(8,.5,4,.5,1.5,8,13)
    for _,z in ipairs({4.5,7.5,10.5}) do box(7.5,2,z,1,.5,1,14) end
    -- Left display and blue scanning lens; all details are raised geometry.
    box(2,2,6,5,.5,4.5,3)
    box(2.5,2.5,6.5,4,.5,3.5,14)
    box(3,3,7,3,.5,2.5,8)
    box(3.5,3.5,7.5,2,.5,.5,9)
    box(3.5,3.5,8.5,1,.5,.5,10)
    box(2,2.5,4.5,1.5,.5,1,3)
    box(2.5,3,4.5,.5,.5,.5,7)
    box(4.5,2,4.5,.5,.5,.5,11)
    box(5.5,2,4.5,.5,.5,.5,12)
    box(3,2,11,3,.5,.5,3)
    -- Right information screen, directional pad, status and action buttons.
    box(9,2,5,5,.5,3,3)
    box(9.5,2.5,5.5,4,.5,2,9)
    box(10,3,6,2.5,.5,.5,10)
    box(9.5,2,9,2,.5,.5,3)
    box(10,2,8.5,.5,.5,1.5,3)
    box(12.5,2,9,1,.5,1,7)
    box(12,2,11,1.5,.5,.5,11)
  else return nil end
  if authored and regular then
    return V.require('GreedyVoxelFaces')(cells,ordered,key,directions,step,#palette,G)
  end
  local verts, indices, faceIds = {}, {}, {}
  for _,p in ipairs(ordered) do
    Budget.tick()
    local x,y,z,c=p[1],p[2],p[3],cells[p[4]]
    for face,n in ipairs(directions) do
      if not cells[key(x+n[1],y+n[2],z+n[3])] then
        faceIds[#faceIds+1]=face
        G.pushQuad(indices,#verts/4)
        for _,v in ipairs(G.FACE_CORNERS[face]) do
          verts[#verts+1]={(x+v[1])*step,(y+v[2])*step,(z+v[3])*step,
            (c-.5)/#palette,.5,G.FACE_SHADE[face]}
        end
      end
    end
  end
  return verts,indices,faceIds
end

function P.resolve(def,seed)
  local kind=P.kind(def,seed)
  if not kind then return nil end
  return P.resolveKind(kind)
end

function P.resolveKind(kind)
  if not cache[kind] then
    local authored=P.models[kind];local signature
    if authored then
      local rows={(authored.directBoxes and 'direct-boxes-v1:'or '')..tostring(authored.step or 1)}
      for _,b in ipairs(authored.boxes)do rows[#rows+1]=table.concat(b,',')end
      signature=table.concat(rows,';')
      if sharedGeometry[signature]then
        cache[kind]=sharedGeometry[signature];return cache[kind],texture
      end
    end
    local ok,result=pcall(function()
      if not texture then
        local data=love.image.newImageData(#palette,1)
        for i,c in ipairs(palette) do data:setPixel(i-1,0,c[1]/255,c[2]/255,c[3]/255,1) end
        texture=love.graphics.newImage(data)
        texture:setFilter('nearest','nearest')
        data:release()
      end
      local GeometryCache=signature and V.require('VoxelGeometryCache')
      local verts,indices
      if GeometryCache then verts,indices=GeometryCache.get(kind,signature,#palette) end
      if not verts then
        verts,indices=P.geometry(kind)
        if GeometryCache then GeometryCache.put(kind,signature,#palette,verts,indices) end
      end
      local bounds=V.require('PropVisibility').bounds(verts)
      -- Furniture claims run inside ChunkMesher's build coroutine. Honour
      -- its frame budget through model construction, including before the
      -- indivisible GPU upload. Direct draw/test callers remain synchronous.
      Budget.check()
      -- A foreground caller can resolve the same template (or an identical
      -- alias) while this build is suspended. Reuse its completed upload.
      local existing=cache[kind] or (signature and sharedGeometry[signature])
      if existing then return existing end
      local mesh=G.newMesh(verts,indices)
      if mesh then meshBounds[mesh]=bounds end
      return mesh
    end)
    if not ok or not result then return nil end -- retain the native sprite on GPU failure
    cache[kind]=result
    if signature then sharedGeometry[signature]=result end
  end
  return cache[kind],texture
end

function P.model(px,py,gh,lift)
  return Mat4.translate(px,gh+(lift or 0),py)
end

function P.supportHeight(sprite,px,py,gh)
  local game=require('src.core.Game')
  local map=game.overworld and game.overworld.map
  local mapId=type(sprite.seed)=='string' and sprite.seed:match('^(.-)_obj_%d+$')
  if map and map.id==mapId then
    local furniture=V.require('VoxelFurniture')
    if furniture.supportAt then return furniture.supportAt(map,px,py) or gh end
  end
  return gh
end

function P.draw(sprite,px,py,gh,lift)
  local mesh,tex=P.resolve(sprite.def,sprite.seed)
  if not mesh then return false end
  G.draw(mesh,tex,P.model(px,py,P.supportHeight(sprite,px,py,gh),lift),0)
  return true
end

function P.cast(p,shadow)
  local mesh,tex=P.resolve(p.sprite.def,p.sprite.seed)
  if not mesh then return false end
  shadow.draw(mesh,tex,P.model(p.px,p.py,P.supportHeight(p.sprite,p.px,p.py,p.gh),p.lift))
  return true
end

-- Gen1 keeps the cartridge artwork in 2D. Authored expansion maps may
-- explicitly opt into the generated projections without changing that default.
function P.use2D(map)
  return map and (map.def or map).voxelItems2D==true
end
function P.install2D()
  V.require('VoxelFurniture').install2D()
  local function rebuild() V.require('ChunkMesher').invalidate();V.require('ShadowMap').invalidate() end
  P.setting:onChange(rebuild)
  local sync=P.setting.sync
  P.setting.sync=function(self,value)
    local before=self:get();sync(self,value)
    if before~=self:get() then rebuild() end
  end
  local Renderer=require('src.render.SpriteRenderer')
  if Renderer.voxelItemsDraw then return end
  local original=Renderer.draw
  local images,quads={},{}
  Renderer.voxelItemsDraw=original
  Renderer.draw=function(sprite,px,py,camX,camY,facing,phase,flip,topHalf,forceFlip,frameOverride,oamRow)
    local Game=require('src.core.Game')
    local map=Game.overworld and Game.overworld.map
    if not P.use2D(map) then
      return original(sprite,px,py,camX,camY,facing,phase,flip,topHalf,forceFlip,frameOverride,oamRow)
    end
    local kind=P.kind(sprite.def,sprite.seed)
    if not kind then return original(sprite,px,py,camX,camY,facing,phase,flip,topHalf,forceFlip,frameOverride,oamRow) end
    if images[kind]==nil then
      local ok,img=pcall(Assets.image,V.path..'/assets/voxel_items/'..kind..'.png')
      images[kind]=ok and img or false
    end
    local img=images[kind]
    if not img then return original(sprite,px,py,camX,camY,facing,phase,flip,topHalf,forceFlip,frameOverride,oamRow) end
    local g=love.graphics
    local x,y=px-(camX or 0),py-(camY or 0)-4
    local start,height=0,16
    if oamRow=='bottom' then start,height=8,8
    elseif topHalf or oamRow=='top' then height=8 end
    local key=kind..':'..start..':'..height
    if not quads[key] then quads[key]=g.newQuad(0,start*4,64,height*4,64,64) end
    require('src.render.PaletteFX').markTrueColor(x,y+start,16,height)
    g.draw(img,quads[key],x,y+start,0,.25,.25)
  end
  Assets.register(function() images,quads={},{} end)
end

function P.invalidate()
  P.resourceVersion=(P.resourceVersion or 0)+1
  local released={}
  for _,mesh in pairs(cache) do if mesh.release and not released[mesh]then mesh:release();released[mesh]=true end end
  if texture then texture:release() end
  cache,texture,identities={},nil,{}
  sharedGeometry={}
  meshBounds=setmetatable({},{__mode='k'})
end
V.require("VoxelItemExtras")(P)
Assets.register(P.invalidate)
return P
