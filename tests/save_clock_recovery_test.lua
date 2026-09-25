package.loaded['src.render.PaletteFX']={}
for _,prefix in ipairs({'','gen2/'})do
 local value;local modules={};local V={mod={save={get=function()return value end}}}
 function V.require(name)
  if modules[name]then return modules[name]end
  if name=='CanvasPresentation'then return{}end
  local m=assert(loadfile(prefix..'lib/'..name..'.lua'))(V);modules[name]=m;return m
 end
 for _,name in ipairs({'DayNight','SkyEvents'})do
  local m=V.require(name)
  for _,bad in ipairs({false,'invalid',{},math.huge,-math.huge,0/0})do
   value=bad;m.restore();assert(type(m.clock)=='number'and m.clock==m.clock and m.clock~=math.huge and m.clock~=-math.huge,prefix..name..' accepted invalid persisted clock')
  end
  value=-5;m.restore();local cycle=name=='DayNight'and m.CYCLE or 1000003;assert(m.clock==cycle-5)
  value=cycle+5;m.restore();assert(m.clock==5)
 end
end
print('PASS saved day/night and sky clocks: invalid values reset, finite times wrap, both generations')
