local cases={{'iOS','OS X','nested-caller'},{'Android','OS X','nested-caller'},
 {'OS X','iOS','nested-caller'},{'Windows','Windows','physical-screen'},
 {'Linux','Linux','physical-screen'},{false,false,'nested-caller'}}
for _,case in ipairs(cases)do
 local native,platform,expected=unpack(case);local probes=0
 love={_os=native or 'iOS',system={getOS=function()probes=probes+1;if not native then error('sandbox denied')end;return native end},
 graphics={getSupported=function()return {}end,getSystemLimits=function()return {texturesize=8192}end}}
 package.loaded['src.core.Platform']=platform and {detect=function()probes=probes+1;return {os=platform}end}or nil
 package.preload['src.core.Platform']=function()error('legacy host without Platform')end
 local cp=assert(loadfile('gen2/lib/CanvasPresentation.lua'))({})
 local modules={CanvasPresentation=cp,Mat4=assert(loadfile('gen2/lib/Mat4.lua'))(),VoxelState={},Quality={},ActorLighting={install=function()end},
 ModSetting={new=function(_,_,values,_,default)return {get=function()return default or values[1]end}end}}
 local V={require=function(n)return modules[n]or {}end}
 local aa=assert(loadfile('gen2/lib/AntiAlias.lua'))(V)
 local gpu=assert(loadfile('gen2/lib/Voxel3D.lua'))(V)
 local shadow=assert(loadfile('gen2/lib/ShadowMap.lua'))(V)
 local before=probes
 for i=1,600 do
  assert(aa.canvasRestorePolicy()==expected);assert(gpu.canvasRestorePolicy()==expected)
  assert(shadow.canvasRestorePolicy()==expected)
 end
 assert(probes==before,'render path repeated platform detection: '..(probes-before))
 print('PASS shared platform receipt: '..tostring(native)..' / '..tostring(platform)..', 1800 policy checks without host probes')
end
