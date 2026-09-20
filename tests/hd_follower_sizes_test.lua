-- Real admitted animation metadata: follower readability must not regress
-- battle sizes or the existing pixel-art size tiers.
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
  assert(follower>=ordinary and follower<math.huge)
  local layout=record.animationCards.layout
  local visible=follower
  if dex<=151 and layout.referenceHeight and layout.referenceHeight>0 then
    visible=follower*(layout.bottom-layout.top)/layout.referenceHeight
  end
  local minimum=({pokemon_small=16,pokemon_medium=18,pokemon_large=21.6})[record.scaleClass]
  assert(visible+1e-8>=minimum,'HD body below readable unit tier: '..dex)
  assert(Scale.worldHeightForRecord(record,'battle')==ordinary,'battle changed')
  for _,context in ipairs({'city','grass','wilds_town'})do
    assert(Scale.worldHeightForRecord(record,context)==follower)
  end
  if follower>ordinary then adjusted=adjusted+1 end
  local resolver=setmetatable({mod={path='test'},scaleProfiles=Scale,idleEvents={},
    resolveContext=function()return record end},Sheets)
  assert(resolver:def(nil,{},nil,'follower').ascendantWorldHeight==follower)
  assert(resolver:def(nil,{},nil,'city').ascendantWorldHeight==follower)
  if dex==151 then
    assert(ordinary<3 and follower>ordinary)
    mew[f[5]]=follower
    mewRecord=record
  end
  count=count+1
end
file:close()
assert(count>=302 and adjusted>2)
assert(mew.normal>5.4 and mew.shiny==mew.normal)
for _,class in ipairs({'pokemon_small','pokemon_medium','pokemon_large'})do
  assert(Scale.worldHeightForRecord({scaleClass=class},'follower')==Scale.worldHeightForClass(class))
end
print('PASS_HD_FOLLOWER_BODY_MINIMUM',count,'variants',adjusted,'adjusted; battle/pixel sizes preserved; follower/city/wilds use readable units')

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
assert(direct.ascendantWorldHeight==mew.normal and direct~=original)
local owner={followerSprites={resolve=function()return original.image end,
  configure=function()return original,original.image end}}
assert(runtime:_installDelegated('kanto_ascendant',owner))
local delegated=owner.followerSprites.configure(game,mon)
assert(delegated.ascendantWorldHeight==mew.normal and delegated~=original)
assert(original.ascendantWorldHeight==nil)
runtime.restore()
assert(owner.followerSprites.configure(game,mon)==original)
print('PASS_HD_FOLLOWER_STANDALONE_AND_DELEGATED_SCALE')
