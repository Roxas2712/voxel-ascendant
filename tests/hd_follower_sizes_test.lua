-- Real admitted animation metadata: follower readability must not regress
-- battle/world sizes or the existing pixel-art size tiers.
local root=(arg and arg[1]) or '.'
local apo=root..'/integrated/ascendant_pokemon_overworld/'
local Scale=assert(loadfile(apo..'src/scale_profiles.lua'))()
local Sheets=assert(loadfile(apo..'src/pokemon_walksheets.lua'))()
local file=assert(io.open(apo..'production/pokemon-animation-cards-runtime.tsv','r'))
file:read('*l')
local count,adjusted,mew=0,0,{}
local mewRecord
for line in file:lines() do
  local f={};for v in (line..'\t'):gmatch('(.-)\t')do f[#f+1]=v end
  local dex=assert(tonumber(f[1]))
  local record={dex=dex,scaleClass=Scale.species[dex] or 'pokemon_medium',
    palette=f[5],runtime='runtime.png',atlas='atlas.png',runtimeContentHeight=16,
    animationCards={id=f[9],layout={top=tonumber(f[17]),bottom=tonumber(f[19]),referenceHeight=tonumber(f[22])}}}
  local ordinary=Scale.worldHeightForRecord(record)
  local follower=Scale.worldHeightForRecord(record,'follower')
  assert(follower>=5.4 and follower<math.huge)
  assert(follower==math.max(5.4,ordinary))
  for _,context in ipairs({'battle','city','grass','wilds_town'})do
    assert(Scale.worldHeightForRecord(record,context)==ordinary)
  end
  if ordinary<5.4 then adjusted=adjusted+1 else assert(follower==ordinary)end
  local resolver=setmetatable({mod={path='test'},scaleProfiles=Scale,idleEvents={},
    resolveContext=function()return record end},Sheets)
  assert(resolver:def(nil,{},nil,'follower').ascendantWorldHeight==follower)
  assert(resolver:def(nil,{},nil,'city').ascendantWorldHeight==ordinary)
  if dex==151 then
    assert(ordinary<3 and follower==5.4)
    mew[f[5]]=follower
    mewRecord=record
  end
  count=count+1
end
file:close()
assert(count>=302 and adjusted>2)
assert(mew.normal==5.4 and mew.shiny==mew.normal)
for _,class in ipairs({'pokemon_small','pokemon_medium','pokemon_large'})do
  assert(Scale.worldHeightForRecord({scaleClass=class},'follower')==Scale.worldHeightForClass(class))
end
print('PASS_HD_FOLLOWER_BODY_MINIMUM',count,'variants',adjusted,'adjusted; battle/world/pixel sizes preserved')

-- Both standalone and delegated followers must pass the follower context;
-- owner-owned definitions are cloned rather than given the new scale.
local Runtime=assert(loadfile(apo..'src/runtime.lua'))()
local original={id='SPRITE_PIKACHU',image='original.png'}
local mon={species='MEW',hp=10}
local game={data={sprites={SPRITE_PIKACHU=original}}}
local runtime=Runtime.new{mod={path='test',_vascIntegrated=true},generation=1,
  catalog={FRAMES=6,asset=function()return 'original.png',151,'original.png' end},
  compat={},characters={},scaleProfiles=Scale,
  pokemonWalksheets={idleEvents={},resolveFollower=function()return mewRecord end}}
local direct=assert(runtime:configure(game,{},mon))
assert(direct.ascendantWorldHeight==5.4 and direct~=original)
local owner={followerSprites={resolve=function()return original.image end,
  configure=function()return original,original.image end}}
assert(runtime:_installDelegated('kanto_ascendant',owner))
local delegated=owner.followerSprites.configure(game,mon)
assert(delegated.ascendantWorldHeight==5.4 and delegated~=original)
assert(original.ascendantWorldHeight==nil)
runtime.restore()
assert(owner.followerSprites.configure(game,mon)==original)
print('PASS_HD_FOLLOWER_STANDALONE_AND_DELEGATED_SCALE')
