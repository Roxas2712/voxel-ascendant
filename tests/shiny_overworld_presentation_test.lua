local root=assert(arg[1])..'/integrated/ascendant_pokemon_overworld/'
local Catalog=assert(loadfile(root..'src/catalog.lua'))()
local Policy=assert(loadfile(root..'src/presentation_policy.lua'))()
local Sheets=assert(loadfile(root..'src/pokemon_walksheets.lua'))()
local probes=0
local policy=Policy.new{mod={_vascIntegrated=true,options={get=function()return 'auto'end},
 _vascStadiumAvailable=function()probes=probes+1;return true end},catalog=Catalog,compat={}}
policy:register('pokemon_go',{animated=true,available=function()return true end})
local shiny={species='MEW',shiny=true}
local dvs={species='MEW',dvs={attack=10,defense=10,speed=10,special=10}}
for _,mon in ipairs({shiny,dvs,{isShiny=true}})do
 for _,context in ipairs({'follower','city','grass','wilds_town'})do
  for _,source in ipairs({'hd','stadium2','full_hd','pokemmo'})do
   local p=policy:select(151,{mon=mon,context=context,spriteSource=source})
   assert(p.id~='stadium2','normal mesh claimed a shiny '..context)
  end
 end
end
assert(probes==0,'shiny queried normal-only pack')
local actor={}
assert(policy:decorate(actor,151,{mon={shiny=false},spriteSource='hd'}).id=='stadium2')
assert(actor.ascendantPokemonModelDex==151)
assert(policy:decorate(actor,151,{mon=shiny,spriteSource='hd'}).id=='pokemon_go')
assert(actor.ascendantPokemonModelDex==nil and policy.lastReason=='shiny_variant_card_fallback')
assert(policy:decorate(actor,151,{mon={shiny=false},spriteSource='hd'}).id=='stadium2')
local normal={dex=151,palette='normal',form='base',gender='none',scaleClass='pokemon_small'}
local exact={dex=151,palette='shiny',form='base',gender='none',scaleClass='pokemon_small'}
local s=setmetatable({mod={_vascIntegrated=true},catalog={isShiny=Catalog.isShiny,
 dexFor=function()return 151 end,presentationDexFor=function()return 151 end},
 byDex={[151]={base={none={normal=normal}}}},legacyByDex={},
 pokemmoByDex={[151]={base={none={normal=normal}}}},
 _withAnimationCards=function(_,r)return r end,_withFlameCards=function(_,r)return r end},Sheets)
assert(s:resolve(nil,shiny)==nil and s:resolvePokeMMO(nil,shiny)==nil,'wrong-palette fallback')
s.byDex[151].base.none.shiny=exact;s.pokemmoByDex[151].base.none.shiny=exact
assert(s:resolve(nil,dvs)==exact and s:resolvePokeMMO(nil,dvs)==exact)
assert(s:resolve(nil,{shiny=false})==normal)
-- Provider availability must use the already-resolved party identity, not
-- an NPC's stale/default shiny=false field.
s.resolve=function(_,game,mon)assert(Catalog.isShiny(mon));return exact end
s._usableRecord=function(_,r)return r==exact end
assert(s:goRenderCardProvider().available(151,{mon=dvs,entity={shiny=false}}))
print('PASS_SHINY_FLAGS_DVS_EXACT_PALETTES_ALL_CONTEXTS_LIVE_SWITCH_AND_PROVIDER_IDENTITY')
