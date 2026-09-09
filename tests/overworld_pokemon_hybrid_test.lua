local root=assert(arg[1])
local P=assert(loadfile(root.."/integrated/ascendant_pokemon_overworld/src/presentation_policy.lua"))()
local S=assert(loadfile(root.."/integrated/ascendant_pokemon_overworld/src/pokemon_walksheets.lua"))()
local Options=assert(loadfile(root.."/lib/OverworldPokemonOptions.lua"))()
local mode="auto"
local available={[25]=true}
local policy=P.new({mod={_vascIntegrated=true,
  _vascStadiumAvailable=function(dex) return available[dex]==true end,
  options={get=function() return mode end}},
  compat={vascStatus=function() return {available=true,stadium2Models=true} end}})
assert(policy:register("pokemon_go",{available=function() return true end,animated=true}))
local n=0
local function check(v,m) n=n+1;assert(v,m) end
for _,context in ipairs({"follower","grass","city","wilds_town"}) do
  local function source(value,dex) return policy:select(dex or 25,{context=context,spriteSource=value}).id end
  mode="auto"
  check(source("hd")=="stadium2",context.." auto keeps a usable model even without animation-capability metadata")
  check(source("hd",26)=="pokemon_go",context.." missing individual model uses HD")
  check(source("pokemmo")=="sprite",context.." MMO overrides model")
  check(source("full_hd")=="pokemon_go",context.." HD overrides model")
  mode="go_only"
  check(source("stadium2")=="stadium2",context.." local model overrides global HD")
  check(source("stadium2",26)=="sprite",context.." local model has sprite fallback")
  check(source("stadium2",300)=="sprite",context.." out-of-roster cannot claim model")
end
mode="auto";policy.mod._vascStadiumAvailable=function() error("provider unavailable") end
check(policy:select(25,{}).id=="pokemon_go","provider exception preserves HD fallback")
policy.mod._vascStadiumAvailable=nil
check(policy:select(25,{}).id=="pokemon_go","capability alone never claims an unimplemented renderer")
local sheets=setmetatable({mod={_vascIntegrated=true,options={get=function() return "stadium2" end}}},S)
check(sheets:sourceForContext("city")=="stadium2","context choice reaches model policy")
for _,spec in ipairs(Options.schema({})) do
  if spec.key:match("sprite_source$") then
    local choices={};for _,row in ipairs(spec.choices) do choices[row[2]]=true end
    check(choices.hd and choices.stadium2 and choices.full_hd and choices.pokemmo,"complete hybrid menu choices")
  end
end
print("PASS APO hybrid sources: "..n.." checks, context overrides, per-Dex availability, missing ROM/model, provider error")
