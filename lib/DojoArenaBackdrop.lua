-- A small retained courtyard panorama behind the Gen1 dojo's real openings.
-- Decorative only: no native floor, door, collision or actor is replaced.
local Art={}
function Art.paint(g,W,H)
  local function r(c,x,y,w,h)
    x,y=math.floor(x),math.floor(y)
    w,h=math.min(math.ceil(w),W-x),math.min(math.ceil(h),H-y)
    if x>=0 and y>=0 and w>0 and h>0 then
      g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',x,y,w,h)
    end
  end
  -- The upper sky remains transparent and shares the normal day/night sky.
  r({.37,.47,.34},0,63,W,H-63)
  for x=0,W-1,4 do
    local y=49+math.sin(x*.065)*7+math.sin(x*.027)*5
    r({.31,.43,.34},x,y,4,70-y)
  end
  -- Low tiled garden wall, then raked sand rather than another playable room.
  r({.53,.51,.39},0,74,W,20)
  r({.24,.31,.29},0,72,W,4)
  for x=0,W-1,8 do r({.40,.44,.38},x,72,6,2)end
  r({.75,.72,.57},0,94,W,H-94)
  for y=99,H-1,6 do r({.61,.61,.49},0,y,W,1)end
  -- Bamboo grove and a red maple frame the quiet courtyard asymmetrically.
  for _,b in ipairs({{17,25},{27,34},{36,21},{47,29}})do
    r({.25,.35,.22},b[1],b[2],3,97-b[2])
    r({.50,.58,.30},b[1]+1,b[2],1,97-b[2])
    for y=b[2]+6,88,12 do
      r({.65,.62,.37},b[1],y,3,2)
      r({.23,.38,.25},b[1]-6,y-3,8,2)
      r({.30,.45,.25},b[1]+3,y-6,8,3)
    end
  end
  r({.33,.25,.18},199,47,5,55)
  for _,p in ipairs({{177,39,28,13},{196,31,30,16},{215,43,26,13},
    {183,52,32,12},{210,57,22,9}})do
    r({.61,.32,.22},p[1],p[2],p[3],p[4])
    r({.77,.46,.26},p[1]+3,p[2],p[3]-6,3)
  end
  -- Three stones and their restrained shadows, not fake entrances or loot.
  for _,s in ipairs({{82,108,19,12},{116,103,24,18},{150,110,15,10}})do
    r({.58,.57,.45},s[1]-3,s[2]+s[4]-2,s[3]+6,4)
    r({.37,.42,.39},s[1],s[2]+3,s[3],s[4]-3)
    r({.52,.56,.49},s[1]+3,s[2],s[3]-6,5)
  end
end
return Art
