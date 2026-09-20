-- Authored idle fronts for fixed encounters and static Wilds fallbacks.
-- Only captured 3D poses change. All loading/clocks run in pipeline update;
-- mirrors and shadows read the same frozen pose without advancing animation.
local V=...
local Assets=require('src.render.Assets')
local M={}
local slots,pending={},{}
local owner,activeMap,tick=nil,nil,0
local previousMotion
-- 12 world units per metre for upright bodies (the player card is 16).
-- Long/coiled bodies and spread wings use an authored display footprint.
local large={GROUDON=48,KYOGRE=56,RAYQUAZA=56,MOLTRES=32,
 MEWTWO=24,ARTICUNO=28,ZAPDOS=28,RAIKOU=23,ENTEI=25,SUICUNE=24,
 LUGIA=56,HO_OH=44,CELEBI=8,MEW=6,JIRACHI=6,DEOXYS=20,
 REGIROCK=20,REGICE=22,REGISTEEL=23,LATIAS=26,LATIOS=30}
local fixed={}
local function add(map,name,species)
 if map and name then fixed[map..':'..name]=species end
end
local function discover()
 if not(V.mod and V.mod.find)then return end
 for _,id in ipairs({'kanto_ascendant','trainer_rematch'})do
  local ok,h=pcall(V.mod.find,id)
  if not ok or not h then ok,h=pcall(V.mod.find,V.mod,id)end
  local x=ok and h and h.exports
  if x and x.crystalAnimation then
   local d=x.postgameData or{}
   for species,r in pairs(d.staticLegends or{})do add(r.map,r.object,species)end
   for species,r in pairs(d.spawnedLegends or{})do add(r.map,r.name,species)end
   for species,r in pairs(d.roamers or{})do
    for _,map in ipairs(d.roamerRoutes or{})do add(map,r.name,species)end
   end
   for _,r in ipairs(x.hoennResearchSanctums67 and x.hoennResearchSanctums67.rows or{})do add(r.map,r.object,r.species)end
   for _,species in ipairs({'GROUDON','KYOGRE','RAYQUAZA'})do
    add('KA_HEVO_'..species..'_CHAMBER','KA_HEVO_'..species,species)
   end
   add('KA_MOLTRES_VOLCANO','KA_MOLTRES_VOLCANO','MOLTRES')
   add('KA_MOLTRES_VOLCANO_ASCENT','KA_MOLTRES_MAGMAR_GUARD','MAGMAR')
   add('KA_HOENN_WISH_CHAMBER','KA_HOENN_JIRACHI','JIRACHI')
   return x
  end
 end
end
local function enabled()
 local a=owner and owner.worldEncounterAnimations
 if a and a.enabled then local ok,on=pcall(a.enabled);return ok and on~=false end
 return owner~=nil
end
function M.identify(p)
 local e=p.entity;local d=e and e.def or{}
 if p.isPlayer or not e or e.pikachuFollower or e._wildsFollowerSpecies
     or e._pokepcFollowerSpecies or e._ascendantPokemonOverworld
     or d.trainer or e.trainer or p.stadiumMon or p.swimming then return end
 local def=p.sprite and p.sprite.def or{}
 -- The selected HD/card/model provider owns this pose, including fixed bosses.
 -- Never replace its artwork with the optional pixel-art idle fallback.
 if def.ascendantAtlasImage or def.ascendantPokemonAnimationCards
     or def.providerId=='ascendant_walksheets'
     or e.ascendantPokemonModelSource=='stadium2' then return end
 local species=fixed[tostring(p.mapId)..':'..tostring(d.name)]
 if species then return species,true end
 if type(e.species)=='string' and large[e.species]then return e.species,true end
 -- Existing directional/HD animations retain their chosen source and pose.
 if (tonumber(def.frames)or 1)>1 or def.ascendantAtlasImage
     or e.ascendantPokemonModelSource=='stadium2' then return end
 species=e.species or d.pokemonSpecies or def.pokemonSpecies
 if type(species)=='string' and species~='' then return species,false end
end
local function card(image,species,height,key)
 local w,h=image:getDimensions()
 if w<8 or h<8 or w>512 or h>512 then return end
 local s={image=image,shadowImage=image,def={id='VASC_WORLD_IDLE_'..species,
  image=key,frames=1,walker=false,trueColor=true,frameWidth=w,frameHeight=h,
  voxelChamberCard=true,voxelWorldWidth=height*w/h,voxelWorldHeight=height}}
 function s:resolveImage()return self.image end
 return s
end
local function create(req,game)
 local a=owner.crystalAnimation
 local mon={species=req.species,shiny=req.shiny,dvs=req.dvs}
 local ok,s=pcall(a.voxelPresentationAnimation,req.species,mon,'MAP',
  {data=game.data,forceStyle=true,kind='overworld'})
 local image,anim,frames,root,durations
 if ok and s and s.image and s.animated then image,anim=s.image,s
 else
  -- Small core pack keeps the fixed bosses animated without optional packs.
  -- Never substitute normal artwork for an explicitly shiny world encounter.
  local pack=owner.worldEncounterAnimations
  local row=not req.shiny and pack and pack.rows and pack.rows[req.species]
  if row then
   root=pack.path..'/'..row.root;durations=row.durations
   local yes,img=pcall(Assets.image,root..'/001.png')
   if yes and img then image=img;frames={[1]=img}end
  end
 end
 if not image then return false end
 local sprite=card(image,req.species,req.height,'vasc:world-idle:'..req.species..':'..tostring(req.shiny)..':'..tostring(image))
 if not sprite then return false end
 return {sprite=sprite,animation=anim,frames=frames,root=root,durations=durations,
  frame=1,elapsed=0,last=tick,species=req.species,shiny=req.shiny}
end
function M.update(game,dt,level)
 tick=tick+1
 local map=game and game.overworld and game.overworld.map
 if map~=activeMap or (tonumber(level)or 0)<=0 then
  slots,pending={},{};activeMap=map
 end
 if not map or (tonumber(level)or 0)<=0 or map.def and map.def.generation==2 then return end
 if not owner then owner=discover()end
 if not owner then return end
 local motion=enabled()
 if motion and previousMotion==false then slots,pending={},{}end
 previousMotion=motion
 dt=math.max(0,math.min(tonumber(dt)or 0,.1))
 local count=0
 for e,s in pairs(slots)do
  if tick-(s.last or 0)>4 then slots[e]=nil else count=count+1 end
 end
 local admitted=0
 for e,r in pairs(pending)do if tick-(r.last or 0)>4 then pending[e]=nil end end
 for e,r in pairs(pending)do
  if admitted>=2 or count>=16 then break end
  if not slots[e]then
   local ok,s=pcall(create,r,game)
   slots[e]=ok and s or {last=tick,failed=true}
   if slots[e]==false then slots[e]={last=tick,failed=true}end
   admitted=admitted+1;count=count+1
  end
  pending[e]=nil
 end
 for _,s in pairs(slots)do if s.sprite and not s.failed and motion then
  local image=s.sprite.image
  if s.animation then
   local ok,value=pcall(owner.crystalAnimation.advancePresentation,s.animation,dt,nil)
   if ok and value then image=value else s.failed=true end
  elseif s.durations and #s.durations>1 then
   s.elapsed=s.elapsed+dt*1000;local guard=0
   while s.elapsed>=(s.durations[s.frame]or 100) and guard<32 do
    s.elapsed=s.elapsed-math.max(1,s.durations[s.frame]or 100)
    s.frame=s.frame%#s.durations+1;guard=guard+1
   end
   if not s.frames[s.frame]then
    local ok,value=pcall(Assets.image,s.root..('/%03d.png'):format(s.frame))
    s.frames[s.frame]=ok and value or false
    if not s.frames[s.frame]then s.failed=true end
   end
   image=s.frames[s.frame]or image
  end
  local w,h=image:getDimensions()
  if w==s.sprite.def.frameWidth and h==s.sprite.def.frameHeight then s.sprite.image=image end
 end end
end
function M.prepare(state,posed)
 if not owner or state.map~=activeMap then return end
 for _,p in ipairs(posed)do
  local species,isFixed=M.identify(p)
  if species then
   local e=p.entity;local shiny=e.shiny==true or e.pokemon and e.pokemon.shiny==true
   local s=slots[e]
   if s and (s.species and s.species~=species or s.shiny~=nil and s.shiny~=shiny)then slots[e]=nil;s=nil end
   if s then
    s.last=tick
    if s.sprite then p.sprite=s.sprite;p.colors=nil end
   else
    pending[e]={species=species,shiny=shiny,dvs=e.pokemon and e.pokemon.dvs,last=tick,
      height=large[species]or (isFixed and 24 or 16)}
   end
  end
 end
end
function M.status()
 local n,frames=0,{}
 for _,s in pairs(slots)do if s.sprite then n=n+1;frames[s.species]=s.animation and s.animation.frame or s.frame end end
 return {active=n,frames=frames}
end
function M.invalidate()slots,pending={},{};owner=nil;fixed={};activeMap=nil;previousMotion=nil end
Assets.register(M.invalidate)
return M
