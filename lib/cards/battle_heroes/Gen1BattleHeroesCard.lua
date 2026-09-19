-- Ascendant Battle Heroes 1.0.1, hosted as an independent presentation Card.
local V=...
local C={ID="vasc.gen1.battle-heroes",VERSION="1.0.1"}
local definitions={
 {"enabled","battleHeroesEnabled","BALL THROWS",false,
  "Enable Johto-style throws. Standing trainers have their own switch; active throws finish safely when disabled."},
 {"trainer_stays","battleHeroesTrainerStays","TRAINERS IN BATTLE",true,
  "Keep trainers visible after the throw."},
 {"gestures","battleHeroesGestures","TRAINER GESTURES",true,
  "Animate trainer commands during battle."},
 {"qolModernBallSkins","battleHeroesModernBalls","MODERN BALLS",true,
  "Use modern ball skins in the Johto throw animation."},
}
local settings,api,registry
local function external()
 local ok,handle=pcall(V.mod.find,V.mod,"ascendant_battle_heroes")
 return ok and handle~=nil
end
function C.entries()
 if not settings then
  settings={}
  local Setting=V.require("ModSetting")
  for _,d in ipairs(definitions) do
   settings[d[1]]=Setting.new(d[2],d[3],{false,true},{"OFF","ON"},d[4])
  end
 end
 local result={}
 for _,d in ipairs(definitions) do result[#result+1]={settings[d[1]],d[5],full=true} end
 return result
end
function C.descriptor()
 return {
  schema="ascendant.card/v1",id=C.ID,version=C.VERSION,owner="voxel_ascendant",
  requires={},optionalRequires={},consumes={},provides={},saveNamespace=false,
  tests={"tests/battle_heroes_integration_test.lua","tests/battle_heroes_card_test.lua"},
  docs={"docs/maintainer/BATTLE_HEROES_CARD.md"},
  impact={runtimeOwners={"gen1.battle.trainer-presentation"},saveWrites={},
   publicHooks={},files={"integrated/battle_heroes/main.lua","lib/BattleHeroesBridge.lua"}},
  lifecycle={
   install=function() C.entries(); return {} end,
   activate=function()
    if not api then
     local proxy={path=V.mod.path.."/integrated/battle_heroes",exports={},log=V.mod.log,
      renderer=V.require("OverworldBattle"),
      standingTrainers=function()return not external() and settings.trainer_stays:get()==true end}
     proxy.resolveAsset=function(path)return V.require("SharedCharacterAssets").resolve(V.mod.path,path)end
     function proxy:read(path) return V.mod:read("integrated/battle_heroes/"..path) end
     function proxy:find(id) return V.mod:find(id) end
     proxy.options={define=function()end,get=function(_,key)
      if key=="enabled" and external() then return false end
      local renderer=V.require('OverworldBattle')
      local plan=renderer.presentationPlan()
      local terrarium=plan and plan.terarrium or (not plan and renderer.setting:get()=='terarrium')
      if terrarium and (key=='enabled' or key=='trainer_stays') then return true end
      return settings[key] and settings[key]:get() or false
     end}
     local chunk=assert(loadstring(assert(proxy:read("main.lua")),"@"..proxy.path.."/main.lua"))
     chunk()(proxy)
     api=proxy.exports
     -- Gen1 Youngster is the bald child used on the overworld. The upstream
     -- throw pack's capped youngster remains available for JR_TRAINER_M.
     local rigSource=assert(V.mod:read("integrated/ascendant_pokemon_overworld/src/human_rig_profiles.lua"))
     local rigs=assert(loadstring(rigSource,"@Gen1HumanRigProfiles"))()
     api.charsprite.register("trainers/gen1-youngster",{
      path=V.mod.path.."/integrated/ascendant_pokemon_overworld/assets/characters/"..rigs.youngster.atlas,
      frontRow=0,backRow=2,rig=rigs.youngster,
     })
     api.charsprite.bindTrainer("OPP_YOUNGSTER","trainers/gen1-youngster")
     V.mod.exports.battleHeroes=api
    end
    api.setActive(true)
    return {state="active"}
   end,
   deactivate=function(_,state)
    if api then api.setActive(false) end
    if state then state.state="retired" end
    return true
   end,
   abort=function() if api then api.setActive(false) end return true end,
   health=function(_,_,state)
    return {schema="ascendant.battle-heroes-health/v1",ok=state~=nil,
     state=state and state.state or "inactive",enabled=api and api.isActive() or false,
     externalOwner=external()}
   end,
  },
 }
end
function C.boot()
 if registry then return end
 registry=V.require("core/AscendantCardRegistry").new()
 local ok,reason=registry:register(C.descriptor())
 if ok then ok,reason=registry:activate(C.ID,{generation=1,host="VOXEL_ASCENDANT"}) end
 V.mod.exports.battleHeroesCardStatus=function() return registry:health(C.ID,{generation=1,host="VOXEL_ASCENDANT"}) end
 if not ok and V.mod.log then V.mod.log:warn("Battle Heroes Card unavailable: %s",tostring(reason)) end
 return ok,reason
end
return C
