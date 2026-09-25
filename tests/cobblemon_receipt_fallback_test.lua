local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local hash=string.rep('a',64)
love={data={hash=function()return hash end,encode=function(_,_,s)return s end}}
local catalog='{"commit":"test","files":[],"importRevision":1,"speciesCount":1}'
local bundled='{"schema":1,"commit":"test","catalogHash":"'..hash..'","importRevision":1,"speciesCount":1,"complete":true,"species":{"1":{"normal":"'..hash..'"}}}'
for _,receipt in ipairs({'{','null','false','true','42','"text"','[]','{}','{"schema":1,"commit":"test","species":false}'})do
 local mod={cache={read=function()return receipt end}}
 function mod:read(path)
  if path=='assets/cobblemon-catalog.json'then return catalog end
  if path=='assets/cobblemon-prepared/index.json'then return bundled end
  if path=='lib/HdBinaryFetch.lua'then return 'return {new=function()return {}end}'end
  return read(path)
 end
 local modules={CobblemonJson={encode=function()end},CobblemonImport={}}
 local content=assert(loadfile('lib/CobblemonContent.lua'))({mod=mod,require=function(n)return assert(modules[n],n)end})
 assert(content.complete()and content.available(1),'bad optional receipt hid included models: '..receipt)
end
print('PASS malformed, null, scalar, array and invalid cache receipts retain bundled models')
