-- Optional art failure must never replace the complete scene or lose the
-- engine-owned text/update/callbacks. Old/new forms get distinct identities.
local root=assert(os.getenv('VASC_TEST_ROOT'))
local Class={};Class.__index=Class
package.loaded['src.ui.EvolutionState']=Class
local image={getDimensions=function()return 56,56 end}
package.loaded['src.render.PaletteFX']={shader=function()end,monPal=function()end}
local calls,boxes={},{}
local now=1
local g={newImage=function()return image end}
for _,name in ipairs{'push','pop','setShader','setScissor','setBlendMode','setColor','rectangle','ellipse','setLineWidth','draw','origin','translate','scale'}do g[name]=function()end end
love={graphics=g,timer={getTime=function()now=now+.02;return now end}}
local callbacks={};local choice='hd';local ready=false;local broken=false
local hd={create=function(_,mon)
 calls[#calls+1]=mon.species
 if mon.species=='NEW'then return nil,'missing'end
 if not ready then return nil,'pending'end
 return {image=image}
end,advancePresentation=function(p)
 if broken then error('damaged HD animation')end
 return p.image
end}
local modules={
 OrasPartyOverlayPresentation={decorateTextBox=function(s)s.wide=true end,drawTextBox=function(s)boxes[#boxes+1]=s end},
 BattleSpriteControl={choice=function()return choice end,setting={get=function()return false end}},
 HdPokemonPresentation=hd,
 Gen2CrystalFronts={resolve=function(_,mon)return {path=mon.species..'.png',trueColor=true}end},
 MobileMenuPresentation={attach=function()end},
}
local mod={find=function()end,events={on=function(_,name,fn)callbacks[name]=fn;return function()callbacks[name]=nil end end}}
local M=assert(loadfile(root..'/lib/EvolutionPresentation.lua'))({mod=mod,require=function(n)return assert(modules[n],n)end})
assert(M.install(mod))
local mon={species='OLD',shiny=true}
local intro={isTextBox=true,stay={},shown={{65}},draw=function()end}
local battle={player={},enemy={}}
local nativeUpdate=function()end;local nativeDraw=function()error('native scene leaked')end
local game={data={pokemon={OLD={spriteFront='old'},NEW={spriteFront='new'}}},save={options={}},stack={states={battle,intro}}}
local s=setmetatable({game=game,mon=mon,newSpecies='NEW',oldSprite=image,newSprite=image,update=nativeUpdate,draw=nativeDraw,t=0},Class)
game.stack.states[3]=s;callbacks['screen.pushed']({state=s})
assert(s.isOpaque and s:isWideBattleLayout());assert(s.update==nativeUpdate)
s:draw();assert(boxes[#boxes]==intro and s.__vascEvolutionIntroDrawn)
assert(calls[1]=='OLD' and calls[2]=='NEW','wrong new-form identity')
assert(s.__vascEvolutionSpriteSource=='crystal','pending HD lost colored fallback')
ready=true;s:draw();assert(s.__vascEvolutionSpriteSource=='hd','pending HD latched permanently')
assert(mon.species=='OLD','presentation applied evolution')
local result={isTextBox=true};game.stack.states[4]=result;callbacks['screen.pushed']({state=result})
assert(result.wide);local before=#boxes;s.done=true;s:draw();assert(#boxes==before and not s.__vascEvolutionIntroDrawn)
assert(s.__vascEvolutionSpriteSource=='crystal','missing evolved HD lost fallback')
s.canceled=true;s:draw();assert(s.__vascEvolutionSpriteSource=='hd','cancel did not show old form')
broken=true;s:draw();assert(s.__vascEvolutionSpriteSource=='crystal','damaged animation killed presentation')
local count=#calls;s:draw();assert(#calls==count,'damaged/missing art retried per frame')
assert(M.deactivate());assert(s.draw==nativeDraw and s.update==nativeUpdate and s.isOpaque==nil)
choice='original';assert(M.install(mod));game.stack.states[4]=nil;callbacks['screen.pushed']({state=s});s:draw()
assert(s.__vascEvolutionSpriteSource=='native','explicit original style overridden')
assert(mon.species=='OLD')
-- After the movie pops, the real retained intro owns the backdrop until the
-- engine's learn callback removes it. Its stale glyphs must never draw again.
intro.game=game
game.stack.states={battle,intro}
callbacks['screen.popped']({state=s})
assert(intro.isOpaque and intro.__vascEvolutionPresentation)
local learned={isTextBox=true};game.stack.states[3]=learned
callbacks['screen.pushed']({state=learned});assert(learned.wide)
local count=#boxes;intro:draw();assert(#boxes==count,'retained intro text leaked into learned message')
local menu={isOpaque=true};game.stack.states[3]=menu
local nested={isTextBox=true};game.stack.states[4]=nested
callbacks['screen.pushed']({state=nested});assert(not nested.wide,'evolution stole move-learn owner')
game.stack.states={battle};callbacks['screen.popped']({state=intro})
assert(mon.species=='OLD' and s.update==nativeUpdate)
print('PASS evolution: HD fallback, identities, text, original, engine update; post-movie backdrop handoff and opaque move-menu ownership')
