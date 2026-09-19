local D=assert(loadfile(arg[2] or 'lib/Gen1FacadeDetails.lua'))()
local cases=0
for _,material in ipairs({'timber','stone','plaster','half_timber'})do
 for _,side in ipairs({'north','south','west','east'})do
  for _,width in ipairs({14,22,30})do
   local doors={{side=side,at=24,width=width}}
   local boxes={};local function b(...)boxes[#boxes+1]={...}end
   D.add({wallMaterial=material,facadeVariant=1,roofShape='hipped'},b,function()end,{},doors,64,48,40,8,0,0,true,false)
   -- World-space pane volume from Gen1KantoBuildings' native door transform.
   local half=width/2;local pane
   if side=='north'then pane={25-half,5,1,width-2,15,1}
   elseif side=='south'then pane={25-half,5,43,width-2,15,1}
   elseif side=='west'then pane={1,5,25-half,1,15,width-2}
   else pane={62,5,25-half,1,15,width-2}end
   for _,a in ipairs(boxes)do
    local overlap=true
    for i=1,3 do if math.max(a[i],pane[i])>=math.min(a[i]+a[i+3],pane[i]+pane[i+3])then overlap=false end end
    assert(not overlap,material..' relief penetrates '..side..' door at height '..a[2])
   end
   -- A doorway must not remove the whole building's timber courses.
   if material=='timber'then assert(#boxes>20,'facade stripped instead of trimmed')end
   cases=cases+1
  end
 end
end
print('PASS_DOOR_RELIEFS '..cases..' material/direction/width combinations')
