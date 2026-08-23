local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local fakeMod = { id="VOXEL_ASCENDANT" }
local V = { mod=fakeMod }
local Packs = assert(loadfile("lib/SpritePacks.lua"))(V)
local localEnabled = false
local LocalSprites = {
  resolve=function(_, value) return value end,
  enabled=function() return localEnabled end,
}
function V.require(name)
  if name == "SpritePacks" then return Packs end
  if name == "LocalSprites" then return LocalSprites end
  error("unexpected module " .. tostring(name))
end

local bad, why = Packs.register({ id="bad" })
eq(bad, nil, "unreceipted pack accepted")
if type(why) ~= "string" then error("pack rejection has no reason") end

local seen = {}
local unregister = assert(Packs.register({
  id="LEGAL_TEST", label="LEGAL TEST", version="1.0.0",
  sourceUrl="https://example.invalid/legal-test",
  sha256=string.rep("a", 64),
  license={spdx="CC0-1.0", url="https://example.invalid/license"},
  providers={
    pokemon=function(path) seen.pokemon=path return "pack-mon.png" end,
    player=function(path) seen.player=path return "pack-player.png" end,
    trainer=function(path) seen.trainer=path return "pack-trainer.png" end,
    icon=function(path) seen.icon=path return "pack-icon.png" end,
    overworld=function(def, ctx)
      seen.overworld=def.image
      seen.overworldCtx=ctx
      return "pack-npc.png"
    end,
  },
}))

local writes = 0
local game = { save={options={}}, mods={modOptions={}},
  writeOptions=function() writes=writes+1 end }
eq(Packs.select("LEGAL_TEST", game), true, "select")
eq(game.save.options.modOptions.VOXEL_ASCENDANT.spritePreset,
   "LEGAL_TEST", "save persistence")
eq(game.mods.modOptions.VOXEL_ASCENDANT.spritePreset,
   "LEGAL_TEST", "loader persistence")
eq(writes, 1, "write count")

local Runtime = {}
local wanted = {
  ["vasc.sprite.pokemon"]=true, ["vasc.sprite.battle"]=true,
  ["vasc.sprite.player"]=true, ["vasc.sprite.trainer"]=true,
  ["vasc.sprite.icon"]=true, ["vasc.sprite.overworld"]=true,
}
function Runtime.wantsHook(name) return wanted[name] end
function Runtime.call(name, vanilla, value)
  if name == "vasc.sprite.overworld" then
    local out = {}
    for k, v in pairs(value) do out[k] = v end
    out.image = value.image .. "|public-overworld"
    return out
  end
  return tostring(value) .. "|" .. name
end
package.loaded["src.mods.Runtime"] = Runtime

local Renderer = {}
function Renderer.new(def, seed) return { def=def, seed=seed } end
package.loaded["src.render.SpriteRenderer"] = Renderer
local BattleState = {}
function BattleState.trainerPicPath()
  return "base-enemy-trainer.png"
end
package.loaded["src.battle.BattleState"] = BattleState

local hooks = {}
local mod = { hooks={} }
function mod.hooks:wrap(name, callback, priority)
  hooks[name] = callback
  eq(priority, 1000000, "relay priority")
end
local SpriteHooks = assert(loadfile("lib/SpriteHooks.lua"))(V)
eq(SpriteHooks.install(mod), true, "hook install")

local function downstream(path) return "kasc:" .. tostring(path) end
Packs.select("base", game)
local protected = hooks["pokemon.sprite"](downstream, "base-mon.png",
                                           {kind="battle", species="PIKACHU"})
eq(protected, "kasc:base-mon.png", "default did not protect KASC sprite")
Packs.select("LEGAL_TEST", game)
local mon = hooks["pokemon.sprite"](downstream, "base-mon.png",
                                    {kind="battle", species="PIKACHU"})
eq(seen.pokemon, "kasc:base-mon.png", "pack did not see final KASC result")
eq(mon, "pack-mon.png|vasc.sprite.pokemon|vasc.sprite.battle",
   "battle relay order")

local player = hooks["player.sprite"](downstream, "base-player.png",
                                      {kind="battle"})
eq(seen.player, "kasc:base-player.png", "player downstream order")
eq(player, "pack-player.png|vasc.sprite.player|vasc.sprite.trainer",
   "trainer relay")

local icon = hooks["pokemon.icon"](downstream, "base-icon.png", {})
eq(seen.icon, "kasc:base-icon.png", "icon downstream order")
eq(icon, "pack-icon.png|vasc.sprite.icon", "icon relay")

local trainer = BattleState.trainerPicPath({}, {}, "OPP_RIVAL2", 1)
eq(seen.trainer, "base-enemy-trainer.png", "trainer provider input")
eq(trainer, "pack-trainer.png|vasc.sprite.trainer", "enemy trainer relay")

local rendered = Renderer.new({
  id="SPRITE_KA_CRYSTAL_GREEN_BIKE", image="base-npc.png", frames=4,
}, "player")
eq(seen.overworld, "base-npc.png", "overworld provider input")
eq(seen.overworldCtx.spriteId, "SPRITE_KA_CRYSTAL_GREEN_BIKE",
   "overworld id context")
eq(seen.overworldCtx.player, true, "overworld player context")
eq(seen.overworldCtx.playerState, "bike", "overworld state context")
eq(seen.overworldCtx.playerCharacter, "GREEN",
   "overworld character context")
eq(rendered.def.image, "pack-npc.png|public-overworld", "overworld relay")
eq(rendered.def.frames, 4, "overworld shape preserved")

local wrapper = Renderer.new
eq(SpriteHooks.install(mod), true, "hot reload rebind")
eq(Renderer.new, wrapper, "renderer wrapper stacked")
eq(BattleState.trainerPicPath,
   BattleState.voxelAscendantTrainerSpriteRelay.wrapper,
   "trainer wrapper stacked")

local list = Packs.list()
eq(#list, 2, "pack inventory")
eq(list[2].license.spdx, "CC0-1.0", "license receipt")
eq(list[2].providers, nil, "private provider leaked")
eq(Packs.public().requirements.bundledAssets, false, "bundled art claim")

eq(unregister(), true, "unregister")
local active, selected = Packs.active()
eq(active, nil, "removed pack still active")
eq(selected, "LEGAL_TEST", "saved choice should survive missing pack")
eq(Packs.resolve("pokemon", "base.png", {}), "base.png", "missing fail-open")

print("sprite pack hooks: ok")
