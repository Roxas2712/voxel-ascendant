-- Voxel reliefs use the same silhouettes and type palette as the party UI.
-- Glyphs are evaluated once, then emitted as horizontal runs in the building's
-- existing emissive mesh. No texture download or per-frame canvas is needed.
local E={}
local colors={ROCK=29,WATER=19,ELECTRIC=20,GRASS=21,POISON=24,PSYCHIC=27,FIRE=18,GROUND=25,FIGHTING=22}
local shapes={
 FIGHTING={-.38,.04,-.38,-.24,-.24,-.24,-.24,-.37,.24,-.37,.35,-.24,.35,.12,.18,.36,-.16,.36,-.16,.12},
 FIRE={0,-.45,.30,-.05,.20,.38,0,.48,-.28,.18,-.13,-.08},
 WATER={0,-.48,.30,.12,.18,.40,-.18,.40,-.30,.12},
 GRASS={-.32,.30,-.18,-.18,.34,-.36,.20,.16},
 ELECTRIC={.08,-.48,-.25,.05,-.02,.03,-.12,.48,.30,-.12,.06,-.08},
 ROCK={-.38,.28,-.26,-.28,.10,-.43,.40,-.05,.22,.38},
 GROUND={-.45,.35,-.08,-.35,.12,0,.26,-.18,.45,.35},
}
local function polygon(points,x,y)
 local inside=false;local j=#points-1
 for i=1,#points,2 do
  local ax,ay,bx,by=points[i],points[i+1],points[j],points[j+1]
  if (ay>y)~=(by>y)and x<(bx-ax)*(y-ay)/(by-ay)+ax then inside=not inside end
  j=i
 end
 return inside
end
local function glyph(kind,x,y)
 if kind=='PSYCHIC'then
  local ellipse=(x/.40)^2+(y/.25)^2
  return (ellipse<=1 and (x/.33)^2+(y/.18)^2>=1)or x*x+y*y<=.01
 elseif kind=='POISON'then
  return x*x+(y+.08)^2<=.25^2 or (x+.25)^2+(y-.26)^2<=.11^2 or (x-.25)^2+(y-.26)^2<=.11^2
 end
 local filled=polygon(shapes[kind],x,y)
 if kind=='FIRE'and polygon({0,-.05,.10,.29,-.10,.31},x,y)then return false end
 return filled
end
function E.add(b,g,kind,x,y,z)
 local color=assert(colors[kind],'unsupported gym type')
 -- Rounded octagonal plaque, with a dark edge and solid coloured enamel.
 b(x+4,y,z,24,32,6,3);b(x,y+4,z,32,24,6,3)
 b(x+4,y+2,z+6,24,28,1,color);b(x+2,y+4,z+6,28,24,1,color)
 for row=0,23 do
  local col=0
  while col<24 do
   if glyph(kind,(col+.5)/24-.5,(row+.5)/24-.5)then
    local stop=col+1
    while stop<24 and glyph(kind,(stop+.5)/24-.5,(row+.5)/24-.5)do stop=stop+1 end
    g(x+4+col,y+27-row,z+7,stop-col,1,2,4);col=stop
   else col=col+1 end
  end
 end
end
return E
