for _,prefix in ipairs({'','gen2/'})do
 local M=assert(loadfile(prefix..'lib/ModSetting.lua'))({mod={}})
 local setting=M.new('test','TEST',{'first','default','optional'},{'FIRST','DEFAULT','OPTIONAL'},'default')
 local enabled=false;setting:setGate(function()return enabled end);setting:sync('optional')
 assert(setting:get()=='default');assert(setting:row().value()=='DEFAULT','display disagrees with effective fallback: '..prefix)
 enabled=true;assert(setting:get()=='optional'and setting:row().value()=='OPTIONAL','gate recovery lost stored choice')
 enabled=false;setting:cycle(nil,1);assert(setting:get()=='default')
 setting:sync('unknown');assert(setting:get()=='default')
end
print('PASS both generations: non-first default, unavailable stored choice, recovery and cycling')
