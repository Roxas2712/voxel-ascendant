local M=dofile('lib/ErrorInbox.lua')
local now=12;local inbox=M.new(function()return now end)
inbox.context={map='ROUTE_2',activity='gameplay',settings='battles=flatB',engine='test'}
local tail=' ERROR: reserved identifier patch at line 28'
local r=inbox:observe('battle-scene-error',{reason=string.rep('x',250)..tail,mode='DISCS',phase='menu',candidateCount=7,
 password='NEVER_COPY',request={token='NEVER_COPY'},reasonDetail=string.rep('x',250)..tail..' https://example.test/secret /Users/private/file.lua'})
assert(r.fullReason:find(tail,1,true) and not r.reason:find(tail,1,true))
assert(#r.reason==180 and #r.details==4)
inbox.context.settings='changed';assert(M.report(r):find('battles=flatB',1,true))
local text=M.report(r);assert(not text:find('NEVER_COPY',1,true) and not text:find('private',1,true) and not text:find('example.test',1,true))
now=13
local f=inbox:observe('battle-native-latch',{reason='scene-render-timeout',provider='DISCS'})
assert(#f.related==1 and f.related[1]:find('patch',1,true))
inbox.context.activity='graphics-check'
local check=inbox:observe('battle-native-latch',{reason='scene-render-timeout',provider='DISCS'})
assert(#check.related==0,'benchmark mixed with gameplay')
now=30;inbox.context.activity='gameplay'
local later=inbox:observe('hook-error',{error='later'})
assert(#later.related==0,'old incident linked as nearby')
local different=inbox:observe('battle-scene-error',{reason=string.rep('x',250)..' different tail',mode='DISCS'})
assert(different.id~=r.id,'distinct long errors merged')
inbox.captureContext=function()error('collector unavailable')end
assert(inbox:observe('hook-error',{error='report survives collector failure'}))
local huge=inbox:observe('hook-error',{error=string.rep('z',20000)})
assert(#huge.fullReason==4096 and huge.fullReason:sub(-3)=='...')

local ctx={};local sample={overworld={map={id='ROUTE_1'},player={cellX=4,cellY=8}},save={version='yellow',options={modOptions={VOXEL_ASCENDANT={battles=false,terarriumDome='clear'}}}},stack={top=function()return {phase='menu'}end}}
love={system={getOS=function()return 'Android'end},timer={getFPS=function()return 60 end},getVersion=function()return 11,5,0 end,
 graphics={getDimensions=function()return 720,1600 end,getStats=function()return {texturememory=1048576,drawcalls=12}end,getRendererInfo=function()return 'OpenGL ES','3.2','Vendor','GPU'end}}
local menu=dofile('lib/ErrorsMenu.lua');menu.captureContext(ctx,sample,{version='3.TEST'})
assert(ctx.map=='ROUTE_1' and ctx.x==4 and ctx.gameVersion=='yellow')
assert(ctx.settings:find('battles=false',1,true) and ctx.renderer=='OpenGL ES 3.2' and ctx.hardware[6][2]:find('1.0 MiB',1,true))
sample.overworld.player.cellX=9;menu.captureContext(ctx,sample,{version='3.TEST'});assert(ctx.x==9)
love.graphics.getRendererInfo=function()error('unsupported')end
assert(pcall(menu.captureContext,ctx,sample,{version='3.TEST'}))
inbox.captureContext=nil;inbox.context.hardware=ctx.hardware
local frozen=inbox:observe('hook-error',{error='hardware snapshot'});local before=M.report(frozen)
ctx.hardware[6][2]='CHANGED';assert(M.report(frozen)==before,'hardware was not frozen')
print('PASS detailed error reports: long reasons, distinct tails, frozen context, bounded correlation, redaction, failure isolation, runtime snapshot')
local mobile=M.new()
local D=assert(loadfile('lib/MobileVoxelDiagnostic.lua'))({_vascErrorInbox=mobile})
D.setLogger({write=function(event,fields)mobile:observe(event,fields);return true end,writeMobileRecoveryMarker=function()return true end})
D.fail('D07','shader-start',string.rep('compiler prefix ',35)..' ERROR patch line 28',{})
assert(mobile.items[1].fullReason:find('ERROR patch line 28',1,true),'mobile collector truncated detail before Errors')
assert(M.classify('battle-scene-error',{reason='Cannot compile pixel shader code: Line 28'})=='D07')
print('PASS mobile failure text survives diagnostic bridge and compiler error gets shader classification')
