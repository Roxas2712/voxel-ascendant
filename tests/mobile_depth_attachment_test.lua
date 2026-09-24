-- Exercise the production allocator contract without loading the game.
local root=arg[1] or '.'
local f=assert(io.open(root..'/lib/Voxel3D.lua','rb'));local source=f:read('*a');f:close()
local first=assert(source:find('local DEPTH_FORMATS =',1,true))
local last=assert(source:find('\nlocal function depthTarget()',first,true))
local factory=assert((loadstring or load)(
 'return function(MOBILE_RUNTIME,PixelCanvas,mobileDiagnostic) '..source:sub(first,last-1)..'\n return newDepth end'))()
local calls,failures,accept={},{},'depth16'
love={graphics={newCanvas=function(w,h,opts)
 calls[#calls+1]={w=w,h=h,opts=opts}
 if opts.format~=accept then error('unsupported depth format')end
 return {width=w,height=h,options=opts}
end}}
local pixel=assert(loadfile(root..'/lib/PixelCanvas.lua'))()
local function diagnostic(kind,code,...)
 if kind=='capability' then failures[#failures+1]={code,...}end
end
local mobile=factory(true,pixel,diagnostic)
local sampled,attachment=mobile(782,360)
assert(sampled==nil and attachment,'mobile must own depth without enabling sampled effects')
assert(attachment.options.readable==false and attachment.options.dpiscale==1,'wrong mobile attachment policy')
assert(attachment.width==782 and attachment.height==360,'depth/colour pixel sizes diverged')
accept='depth32f';local _,resized=mobile(360,782)
assert(resized and resized.width==360 and resized.height==782,'portrait attachment not resized')
local desktop=factory(false,pixel,diagnostic)
local readable,extra=desktop(128,96)
assert(readable and readable.options.readable==true and extra==nil,'desktop reflections changed')
accept=nil;local absent,buffer=mobile(64,64)
assert(absent==nil and buffer==nil and #failures==1,'allocation failure must be diagnosed and fall back')
print('PASS mobile persistent allocation, format fallback, DPI/resize, desktop sampled depth and diagnosed failure')
