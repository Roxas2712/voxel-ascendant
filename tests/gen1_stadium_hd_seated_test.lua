local root=assert(arg[1], 'package root required')..'/'
local on=true
local tex={setFilter=function()end}
package.loaded['src.render.Assets']={image=function()return tex end}
local release=0
local renderer={pushQuad=function(t)t[1]=1 end,newMesh=function(rows)return{rows=rows,release=function()release=release+1 end}end}
local V={mod={path=root,exports={overworldPokemon={walkingSprites={enabled=function()return on end}}}},require=function()return renderer end}
local M=assert(loadfile(root..'lib/HdAuthoredFigures.lua'))(V)
local old={mesh={},wx=6,wz=40,y=8,w=12,hdActor='pokecenter_seated_man'}
local new,image=M.resolve(old);assert(new~=old and image==tex and new.y>0 and new.y<old.y)
assert(new.mesh.rows[1][4]>0 and new.mesh.rows[2][4]<1,'sprite body UV bounds')
local same={mesh={},wx=6,wz=40,y=8,w=12};assert(M.resolve(same)==same,'unmarked furniture changed')
on=false;assert(M.resolve(old)==old,'OFF lost original figure')
on=true;assert(M.resolve(old)~=old,'ON did not recover')
M.invalidate();assert(release==1)
package.loaded['src.render.Assets'].image=function()error('missing')end
assert(M.resolve(old)==old,'missing asset must preserve original figure')
package.loaded['src.render.Assets'].image=function()return tex end
M.invalidate();assert(M.resolve(old)~=old,'graphics invalidation did not recover')
print('PASS seated figure HD toggles, sprite UV, seat anchor, unrelated furniture, missing asset and graphics invalidation')
