-- Resolve implicit reward art from live registered ownership. A missing explicit
-- assetAuthority is not proof that the Pokemon uses built-in game graphics.
local M={}
function M.resolve(mod,game,profile,sprites)
 local data=game and game.data
 local species=data and data.pokemon and data.pokemon[profile.species]
 if not species then return nil end
 local paths,seen={},{}
 local prefix=mod.path..'/'
 local function relative(path)
  if type(path)~='string'or path==''or path:find('[%z\r\n]')then return false end
  if not seen[path]then paths[#paths+1]=path;seen[path]=true end
  return true
 end
 local function registered(path)
  if type(path)~='string'or path==''then return false end
  if path:sub(1,#prefix)==prefix then return relative(path:sub(#prefix+1))end
  return true -- Engine or another mod owns this registered path.
 end
 if not registered(species.spriteFront)or not registered(species.spriteBack)then return nil end
 for _,role in ipairs({'ascendantOptionalFront','ascendantOptionalBack'})do
  if species[role]and not registered(species[role])then return nil end
 end
 local icons=data.icons or{}
 local entry=icons.bySpecies and icons.bySpecies[profile.species]or species.icon
 local icon=type(entry)=='table'and entry.image or type(entry)=='string'and icons.icons and icons.icons[entry]
 if not icon and species.dex and icons.byDex and icons.icons then icon=icons.icons[icons.byDex[species.dex]]end
 -- Match the engine's icon hook chain: later species authorities can replace
 -- legacy bySpecies entries (including paths that no longer belong to a pack).
 if sprites and type(sprites.iconPath)=='function'then
  for _,shiny in ipairs({false,true})do
   local resolved=sprites.iconPath(data,{species=profile.species,shiny=shiny},icon)
   if not registered(resolved)then return nil end
  end
 elseif not registered(icon)then return nil end
 local exports=mod.exports or{}
 local followers=exports.followerSprites
 if #paths>0 and followers and type(followers.definition)=='function'then
  local def=followers.definition(game,profile.species)
  if def then
   for _,role in ipairs({'normalRelative','shinyRelative'})do
    if def[role]and not relative(def[role])then return nil end
   end
  end
 end
 local backend=exports.backendGiftSpecies67
 if backend and type(backend.spriteContentPaths)=='function'then
  for _,path in ipairs(backend.spriteContentPaths(profile.species)or{})do
   if not relative(path)then return nil end
  end
 end
 local function formAssets(provider,key,id)
  if not key then return true end
  local form=provider and provider.byKey and provider.byKey[key]
  if not form or form.id~=id or form.species~=profile.species then return false end
  local art=form.backendArt or form.art
  if art then
   for _,path in pairs(art.paths or{})do if not relative(path)then return false end end
   for _,animation in pairs(art.animations or{})do
    if not relative(animation.root..'/001.png')then return false end
   end
  elseif form.asset then
   -- Existing Mega controllers use these registered static runtime images.
   -- Their manifest also owns the matching normal/shiny animation frames.
   for _,side in ipairs({'front','back'})do
    for _,suffix in ipairs({'','_shiny'})do
     relative('assets/mega_runtime/'..form.asset..'_'..side..suffix..'.png')
     relative('assets/mega_gen1_runtime/'..form.asset..'_'..side..suffix..'.png')
    end
   end
   local collection=exports.megaSpriteCollections
   local data=collection and collection.data
   local original=data and data.forms and data.forms[form.id]
   if original and original.asset==form.asset and collection:selected()==data.id then
    relative(data.root..'mega_animated_runtime/'..form.asset..'/front/normal/001.png')
   end
  else return false end
  return true
 end
 if not formAssets(exports.backendMegaForms67,profile.megaSourceKey,profile.megaFormId)
  or not formAssets(exports.backendGigantamaxForms67,profile.gigantamaxSourceKey,profile.gigantamaxFormId)then return nil end
 table.sort(paths);return paths
end
return M
