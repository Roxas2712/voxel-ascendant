local reads,reports,live,decodes=0,0,0,0
local valid,fault=false,nil
local content={catalog={},epoch=0,available=function()return true end,
 record=function()reads=reads+1;if valid then return {texture='base',layers={'layer'}}end end,
 read=function(path)if fault=='layer-missing'and path=='layer'then return nil end;return path end}
local function resource()
 live=live+1
 return {release=function(self)assert(not self.freed);self.freed=true;live=live-1 end,
 getWidth=function()return 2 end,getHeight=function()return 2 end,
 mapPixel=function()if fault=='blend'then error('blend failed')end end,
 setFilter=function()if fault=='filter'then error('filter failed')end end}
end
love={image={newImageData=function(fd)decodes=decodes+1;if fault=='decode'then error('decode failed')end;return resource()end},
 graphics={newImage=function()if fault=='upload'then error('upload failed')end;return resource()end}}
local modules={CobblemonContent=content,CobblemonGeometry={},Diagnostics={write=function()reports=reports+1 end},
 EngineCompat={fs=function()return {newFileData=function()return resource()end}end}}
local pack=assert(loadfile('lib/CobblemonPack.lua'))({require=function(n)return assert(modules[n],n)end})
for i=1,600 do assert(not pack.load(1))end
assert(reads==1 and reports==1,'failed model repeats disk reads and diagnostics every frame')
valid=true;content.epoch=1;local model=assert(pack.load(1));assert(pack.load(1)==model and reads==2,'new content epoch must recover')
for _,failure in ipairs({'decode','layer-missing','blend','upload','filter'})do
 fault=failure;model.textures={{}};local n=reports
 assert(not pack.image(model,1));assert(live==0,'partial texture resources leaked: '..failure)
 local d=decodes;for i=1,60 do assert(not pack.image(model,1))end
 assert(decodes==d and reports==n+1,'failed image retries every frame')
end
fault=nil;model.textures={{}};local image=assert(pack.image(model,1));assert(live==1);assert(pack.image(model,1)==image)
image:release();assert(live==0)
print('PASS missing-model caching across 600 frames, content-epoch recovery, five partial texture failure paths, successful image ownership')
