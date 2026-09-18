-- MAP adapter; the visibility and geometry rules are shared with the overworld.
local V=...
local C=V.require('SightClearance')
local B={intersects=C.intersects,removeQuad=C.removeQuad}
function B.apply(arena,terrain,props,map,cards,eye)
 if not arena or arena.discs or arena.portableStage then return terrain,props end
 local mesh,filtered=C.scene(arena,terrain,props,map,C.cardTargets(cards),eye)
 arena.battleTrainerClearance=C.status(arena)
 return mesh,filtered
end
return B
