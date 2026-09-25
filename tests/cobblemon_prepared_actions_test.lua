local V={};local modules={}
function V.require(n)if not modules[n]then modules[n]=assert(loadfile('lib/'..n..'.lua'))(V)end;return modules[n]end
local J=V.require('ContentJson');local G=V.require('CobblemonGeometry')
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return J.decode(s)end
local catalog=read('assets/cobblemon-catalog.json');local index=read('assets/cobblemon-prepared/index.json')
assert(index.importRevision==catalog.importRevision and index.importRevision>=5,'stale bundled animation index')
local required=V.require('CobblemonMotion').REQUIRED
local poses=read('assets/cobblemon-prepared/poses.json');assert(poses.importRevision==index.importRevision)
local count,samples,variants=0,0,0
local unique={}
for dex,row in pairs(index.species)do
 for variant,hash in pairs(row)do
 variants=variants+1
 local manifest=assert(poses.species[dex][variant]);assert(manifest.model==hash)
 local m=read('assets/cobblemon-prepared/models/'..hash..'.json')
 for _,action in ipairs(required)do
  assert(m.actions[action] and manifest.actions[action]==m.actions[action],dex..'/'..variant..' missing '..action)
  assert(manifest.sources[action]==m.actionSources[action], 'incorrect provenance')
 end
 assert(m.motionProfile.kind==manifest.profile)
 if not unique[hash] then
 unique[hash]=true
 assert(m.source=='cobblemon' and m.actions.attack_default and m.actionSources.attack_default=='vasc',dex..' no independent fallback')
 for name,i in pairs(m.actions)do
  assert(m.anims[i],dex..' dangling action '..name)
  for _,f in ipairs({0,.1,.25,.5,.75,1,1.5,2.1})do
   local out=G.sample(m,i,m.anims[i].seconds*30*f,true)
   assert(#out==m.boneCount,'missing bone poses');samples=samples+1
  end
 end
 end
 end
 count=count+1
end
assert(count==catalog.speciesCount,'incomplete compiled roster')
local schema=assert(loadfile('gen2/options.lua'))();local found
for _,s in ipairs(schema)do if s.key=='pokemonModelSkin'then for _,c in ipairs(s.choices)do if c[2]=='cobblemon'then found=true end end end end
assert(found,'Gen2 menu cannot select bundled Cobblemon battle provider')
assert(variants==1894,'lost existing variants')
print('PASS prepared roster: '..count..' species, '..variants..' variants, '..samples..' finite action samples, revision and Gen2 menu choice')
