local root=assert(os.getenv("VASC_TEST_ROOT"))
for _,prefix in ipairs({"","gen2/"})do
 local P=assert(loadfile(root.."/"..prefix.."lib/VascBattleAnimPlayer.lua"))({})
 local registry=assert(loadfile(root.."/data/vasc_battle_animations.lua"))()
 assert(registry.programs.GUST.opp.frames[1][3].x==128)
 for _,pair in ipairs({{{20,100},{140,30}},{{80,110},{80,20}}})do
  P.setFrameAnchors({player={emitter=pair[1],body=pair[1]},enemy={emitter=pair[2],body=pair[2]}})
  for _,side in ipairs({true,false})do
   local native={steps={},start=function()end}
   local player=P.Player.new(native,{registry=registry})
   player:start("GUST",side)
   assert(player.custom and player.customVariant=="move")
   local cel=player.program.frames[1][3]
   local x,y=P.mapPoint(cel,side)
   local target=side and pair[2]or pair[1]
   local caster=side and pair[1]or pair[2]
   local d=(x-target[1])^2+(y-target[2])^2
   assert(d<100 and d<(x-caster[1])^2+(y-caster[2])^2)
  end
 end
end
print("PASS_GUST_BOTH_ATTACKERS_BOTH_GENERATIONS")
