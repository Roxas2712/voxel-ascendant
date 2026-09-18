-- Small regional houses for the outer scenery ring. Near silhouettes receive
-- facade relief; distant rows keep the same materials with fewer boxes.
-- Coordinates stay inside one 48px cell and use OutdoorHorizon's shared atlas.
local B={}
local schemes={
 woodland={walls={15,29,13},roofs={25,28,8}},
 lavender={walls={13,24,15},roofs={16,23,14}},
 safari={walls={19,29,15},roofs={25,28,8}},
 volcanic={walls={18,29,6},roofs={30,28,9}},
 foothills={walls={18,6,29},roofs={30,8,28}},
 garden={walls={29,10,15},roofs={25,28,30}},
 city={walls={18,29,24},roofs={30,9,28}},
 harbor={walls={11,29,15},roofs={30,28,8}},
 riverside={walls={29,11,19},roofs={30,25,28}},
}
function B.selected(kind,seed,row)
 local mountain=kind:find('mountain')or kind:find('rock')or kind:find('cliff')
 if mountain then return false end
 local city=kind=='metropolis'or kind=='town'or kind=='smalltown'
 return (city and seed%11<(row<=1 and 4 or 2))or(not city and seed%19==0)
end
function B.geometry(profile,seed,row,edge,emit)
 local scheme=schemes[profile]or schemes.woodland
 local variant=seed%3+1;local wall=scheme.walls[variant]
 local roof=scheme.roofs[(math.floor(seed/3)+variant)%3+1]
 local near=row<=1;local dark=profile=='lavender'
 local timber=wall==13 or wall==15 or wall==19
 local trim=dark and 14 or timber and 8 or 29
 local h=24+seed%3*4;local w=32+(seed%2)*4;local d=32
 local x=24-w/2;local z=8
 local turn=({north=0,south=2,east=1,west=3})[edge]or 0
 local function b(xx,y,zz,ww,hh,dd,c,lit)
  if turn==1 then xx,zz,ww,dd=48-zz-dd,xx,dd,ww
  elseif turn==2 then xx,zz=48-xx-ww,48-zz-dd
  elseif turn==3 then xx,zz,ww,dd=zz,48-xx-ww,dd,ww end
  emit(xx,y,zz,ww,hh,dd,c,lit)
 end
 b(x-1,0,z-1,w+2,3,d+2,18)
 b(x,3,z,w,h-3,d,wall)
 b(x-2,h,z-2,w+4,2,d+4,trim)
 local flat=profile=='city'and variant==1
 for r=0,(flat and 0 or 3)do
  local hip=variant==2 and r*3 or 0
  b(x-2+r*4,h+2+r*3,z-2+hip,w+4-r*8,3,d+4-hip*2,roof)
 end
 if near then b(x+w-8,h+4,z+8,4,13,4,trim)end
 -- The door always faces the resident map, including west/east boundaries.
 b(21,3,39,8,15,2,trim)
 if near then b(23,4,41,4,11,1,dark and 15 or 19)end
 local function window(xx,y,zz,side)
  if side then
   if near then b(xx,y,zz,2,9,8,trim)end
   b(xx+(xx<24 and -1 or near and 2 or 1),y+1,zz+1,1,7,6,17,true)
  else
   if near then b(xx,y,zz,8,9,2,trim)end
   b(xx+1,y+1,zz+(zz<24 and -1 or near and 2 or 1),6,7,1,17,true)
  end
 end
 window(x+2,10,39);window(x+w-10,10,39)
 window(x+w-10,10,7)
 window(x-1,10,19,true);window(x+w-1,10,19,true)
 if near then
  if timber then
   b(x,3,40,2,h-3,1,trim);b(x+w-2,3,40,2,h-3,1,trim)
   b(x,21,40,w,2,1,trim)
  else
   b(x,3,40,3,5,1,18);b(x+w-3,17,40,3,4,1,18)
  end
  if dark then
   -- Uneven boards and muted plaster, without cheerful flower boxes.
   b(x+2,15,42,9,2,1,15);b(x+w-9,10,42,2,8,1,14)
  elseif variant==2 then
   b(x+1,7,40,10,3,4,19);b(x+2,10,41,8,2,2,26)
   b(x+3,12,41,2,2,2,28);b(x+7,12,41,2,2,2,29)
  elseif variant==3 then
   b(19,19,39,12,2,6,roof);b(19,3,43,2,16,2,trim)
  end
  if not dark and seed%5==0 then
   b(20,h+1,42,8,4,1,28);b(20,h-3,42,8,4,1,29)
   b(20,h,43,8,1,1,14);b(23,h-1,44,2,3,1,29)
  end
 end
end
return B
