-- Optional Gen-1 wardrobe owner. KASC wins when present; no foreign save writes,
-- second cabinet or synthetic KASC export. The vanilla player remains Red.
local V=...
local M={}
function M.install(enabled)
 local mod=V.mod
 local kasc=mod:find('kanto_ascendant')
 if kasc then return kasc.exports and kasc.exports.wardrobe end
 if mod.exports.wardrobe then return mod.exports.wardrobe end
 local root='integrated/wardrobe/'
 local facade={id=mod.id,path=mod.path..'/'..root:sub(1,-2),exports={},
  content=mod.content,events=mod.events,hooks=mod.hooks,ui=mod.ui,cache=mod.cache,save=mod.save,find=mod.find,
  options={get=function(_,key)if key=='wardrobe_enabled'then return mod.options:get('wardrobeEnabled')~=false end;return mod.options:get(key)end}}
 local function load(_,name)
  local source=assert(mod:read(root..name))
  return assert((loadstring or _G.load)(source,'@'..facade.path..'/'..name))()
 end
 local characters={getPlayerCharacter=function()return'RED'end}
 facade.exports.extendedCharacters=characters
 local originals=setmetatable({},{__mode='k'})
 local W
 function characters.refreshVisuals(game)
  local player=game and game.overworld and game.overworld.player
  if not player or not W then return end
  local walking=mod.exports.overworldPokemon and mod.exports.overworldPokemon.walkingSprites
  local original=originals[player]
  if not original then
   local def=walking and walking.fieldNativeDef and walking.fieldNativeDef(player,game.overworld)
   if not def and player.sprite and not player.sprite.def.ascendantAtlasImage and not player.sprite.def.kaWardrobe2d then def=player.sprite.def end
   def=def or game.data.sprites.SPRITE_RED
   if not def then return end
   original=require('src.render.SpriteRenderer').new(def,'player');originals[player]=original
  end
  player.sprite=original;player.spriteDef=original.def
  W.walker2d.bind(game,player,'RED',original)
 end
 W=load(nil,'wardrobe_card.lua')(facade,{load=load,characters=characters})
 W.cardId='vasc.characters.wardrobe';W.card.id=W.cardId
 W.card.schema='ascendant.wardrobe-provider/v1';W.card.version='1.3.0'
 mod.exports.wardrobe=W
 for _,event in ipairs({'game.ready','save.loaded','save.created','map.entered','map.reloaded'})do
  mod.events:on(event,function(ev)
   local game=ev and ev.game
   if game then W.bind(game);W.refresh(game)end
  end,0)
 end
 return W
end
return M
