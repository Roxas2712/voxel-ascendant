-- Retained, procedural harbor silhouette for the electric gym's high windows.
-- Drawn once into a 256x128 transparent Canvas, never a live city simulation.
local Art={}
function Art.paint(g,W,H)
  local function rect(c,x,y,w,h)
    g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',x,y,w,h)
  end
  -- Leave sky transparent; a low horizon does not turn the hall into a cave.
  rect({.30,.48,.56},0,H-40,W,40)
  for y=H-38,H-1,5 do
    for x=0,W-1,24 do
      rect({.50,.66,.69},(x+y*3)%W,y,12,1)
    end
  end
  local dark,mid,edge={.22,.29,.33},{.38,.44,.45},{.65,.63,.48}
  -- Warehouses and moored cargo silhouettes, not walkthrough architecture.
  for _,b in ipairs({{8,42,26},{65,35,19},{133,50,22},{210,32,17}})do
    rect(mid,b[1],H-40-b[3],b[2],b[3])
    rect(dark,b[1]-2,H-43-b[3],b[2]+4,3)
    for x=b[1]+4,b[1]+b[2]-4,8 do rect(edge,x,H-34-b[3],3,4)end
  end
  rect(dark,0,H-41,W,4)
  for _,c in ipairs({{54,42},{185,58}})do
    local x,high=c[1],H-40-c[2]
    rect(dark,x,high,4,c[2]);rect(mid,x+1,high,1,c[2])
    rect(dark,x-22,high,62,4)
    rect(edge,x-19,high+1,55,1)
    -- Fixed diagonal bracing and suspended hook, no animation allocation.
    for i=0,8 do rect(mid,x+3+i*3,high+3+i*2,3,2)end
    rect(dark,x+32,high+4,1,20);rect(dark,x+29,high+23,4,2)
  end
  rect(dark,91,H-26,40,6);rect(mid,98,H-33,17,7)
  rect(edge,101,H-37,6,4)
end
return Art
