local root=assert(arg[1])
local noop=function()end
for _,os in ipairs({'iOS','Android','OS X'})do
 local maxTexture=8192
 love={graphics={getSystemLimits=function()return {texturesize=maxTexture}end,getSupported=function()return {instancing=true}end,drawInstanced=noop},system={getOS=function()return os end}}
 local setting={new=function(key,label,values,labels,default)
  local t={value=default or values[1]};function t:get()return self.value end;return t
 end}
 local modules={ModSetting=setting,CanvasPresentation={OS=os},Mat4=assert(loadfile(root..'/gen2/lib/Mat4.lua'))()}
 local V={require=function(k)return modules[k] or {}end}
 local aa=assert(loadfile(root..'/gen2/lib/AntiAlias.lua'))(V)
 local gpu=assert(loadfile(root..'/gen2/lib/Voxel3D.lua'))(V)
 assert(gpu.canInstance()==(os=='OS X'),'mobile must use expanded tree geometry; desktop keeps acceleration')
 local function size(w,h,ew,eh)local x,y=aa.expand(w,h);assert(x==ew and y==eh,os..' target '..x..'x'..y..' expected '..ew..'x'..eh)end
 size(2868,1320,1920,884);size(1320,2868,884,1920);size(480,900,480,900)
 aa.resolution.value='native';size(2868,1320,2868,1320)
 aa.resolution.value='economy';size(2868,1320,1280,589)
 aa.resolution.value='native';aa.setting.value=4
 if os~='OS X'then size(2868,1320,2868,1320)else size(2868,1320,5736,2640)end
 maxTexture=2048;size(2868,1320,2048,943)
 gpu.rejectInstancing();assert(not gpu.canInstance())
 print('PASS render policy '..os..': resolution, rotation, no mobile supersampling, texture limit, instancing')
end
