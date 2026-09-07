local root=assert(arg[1])
local Options=assert(loadfile(root.."/lib/OverworldPokemonOptions.lua"))()
local values={apo_pokemon_collision_mode="soft"}
local mod={id="VOXEL_ASCENDANT",options={get=function(_,key)return values[key]end}}
local ModSetting=assert(loadfile(root.."/lib/ModSetting.lua"))({mod=mod})
local game={save={options={modOptions={VOXEL_ASCENDANT=values}}},
  mods={modOptions={VOXEL_ASCENDANT=values}},writeOptions=function()end}
local keys={}
for _,spec in ipairs(Options.schema(mod))do keys[spec.key]=spec end
assert(keys.apo_pikachu_head_ride.default==false)
assert(keys.apo_pokemon_card_style.default=="off")
assert(keys.apo_pokemon_card_style.choices[4][2]=="comic")
assert(#keys.apo_pokemon_collision_mode.choices==2)
local collision
for _,entry in ipairs(Options.entries(mod,ModSetting))do
  if entry[1].key=="apo_pokemon_collision_mode" then collision=entry[1] end
end
assert(collision:row().value()=="SOFT: BLOCKED")
assert(values.apo_pokemon_collision_mode=="soft","read rewrote saved preference")
assert(collision:schema().visible_if.not_equals=="soft")
collision:row().step(game,1)
assert(values.apo_pokemon_collision_mode=="passable")
for _=1,10 do collision:cycle(game,1);assert(values.apo_pokemon_collision_mode~="soft")end
values.apo_pokemon_collision_mode="soft"
mod.find=function(_,id)if id=="translation-german-universal"then return {exports={bootLanguage="de"}}end end
assert(collision:row().value()=="WEICH: GESPERRT")
local normal,legacy=0,0
for _,spec in ipairs(Options.managerSchema(mod))do
  if spec.key=="apo_pokemon_collision_mode"then
    assert(spec.visible_if.key==spec.key)
    if spec.visible_if.equals=="soft"then legacy=legacy+1;assert(spec.choices[1][1]=="WEICH: GESPERRT")
    else normal=normal+1;for _,c in ipairs(spec.choices)do assert(c[2]~="soft")end end
  end
end
assert(normal==1 and legacy==1,"manager rows must be mutually exclusive")
local deSchema=Options.schema(mod)
for i,spec in ipairs(deSchema) do
  local english=Options.schema({})[i]
  assert(spec.key==english.key and spec.default==english.default)
  assert(spec.description~=english.description,"missing German help: "..spec.key)
  for j,choice in ipairs(spec.choices or {})do
    assert(choice[2]==english.choices[j][2],"translated saved option value")
  end
end
local entries=Options.entries(mod,ModSetting)
for _,entry in ipairs(entries)do
  if entry[1].key=="apo_hd_walking_sprites"then assert(entry[1].labels[2]=="AN")end
  if entry[1].key=="apo_actor_voxel_cubes"then assert(entry[1].labels[1]=="FLACHE SCHICHTEN")end
end
mod.find=function()return {exports={bootLanguage="en"}}end
for i,spec in ipairs(Options.schema(mod))do
  assert(spec.description==Options.schema({})[i].description,"German leaked into English session")
end
print("PASS RC32 options: defaults, comic, preserved blocked SOFT, EN/DE, two-stop native ladder and conditional manager rows")
