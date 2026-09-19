local root=arg[1]or'.'
local D=assert(loadfile(arg[2]or(root..'/lib/Gen1FacadeDetails.lua')))()
local count=0
for theme=1,11 do for variant=0,3 do for _,shape in ipairs({'gable','hipped','side_gable'})do
 local opaque,panes={},{}
 local function sink(list)return function(...)list[#list+1]={...}end end
 local a={facadeVariant=variant,roofShape=shape,wallMaterial=({'plaster','timber','stone','half_timber'})[variant+1]}
 D.add(a,sink(opaque),sink(panes),{}, {},64,48,40,theme,16,20,true,false)
 assert(#panes>=3,'back windows missing')
 for _,g in ipairs(panes)do
  assert(g[4]>0 and g[5]>0 and g[6]>0)
  for _,b in ipairs(opaque)do
   local overlap=true
   for axis=1,3 do
    if math.max(g[axis],b[axis])>=math.min(g[axis]+g[axis+3],b[axis]+b[axis+3])then overlap=false end
   end
   assert(not overlap,'solid facade/frame overlaps glass: theme '..theme..', variant '..variant..', '..shape)
  end
  count=count+1
 end
end end end
print('PASS '..count..' facade panes: no solid backing/frame intersection across 11 themes, four variants, three roof shapes')
