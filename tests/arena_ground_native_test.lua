local root=os.getenv('QA_VASC_SOURCE') or '.'
local catalog=assert(loadfile(root..'/data/arena_ground.lua'))()
local Ground=assert(loadfile(os.getenv('QA_GROUND_MODULE') or root..'/lib/ArenaGround.lua'))({data=function()return catalog end})
local out=os.getenv('QA_GROUND_RESULT') and assert(io.open(os.getenv('QA_GROUND_RESULT'),'w'))
local count,failed=0,0
for path,spec in pairs(catalog)do
 local f=assert(io.open(root..'/'..path,'rb'));local bytes=f:read('*a');f:close()
 local data=love.image.newImageData(love.filesystem.newFileData(bytes,path))
 local w,h=data:getDimensions();local result=Ground.resolve(path,data,w,h)
 count=count+1
 if result then
  assert(result.source=='reviewed-ground/v1')
  if path:find('arena_ship-cabins.',1,true) then
   assert(result.player.y<=.74 and result.enemy.y<=.72,'cabin ground marks overlap command dock')
   assert(result.enemy.x-result.player.x>=.27,'cabin pair lost readable separation')
  end
  for _,side in ipairs({'player','enemy','trainerPlayer','trainerEnemy'})do
   local p=result[side];assert(Ground.supports(spec.regions,p.x,p.y,.055,.025))
  end
  if out then out:write(path,'\t',result.player.x,'\t',result.player.y,'\t',result.enemy.x,'\t',result.enemy.y,'\n') end
 else failed=failed+1;print('GROUND_MISSING',path,data:getFormat(),#data:getString(),w*h*4,love.data.encode('string','hex',love.data.hash('sha256',data:getString()))==spec.digest)end
 local digest=spec.digest;spec.digest="changed"
 assert(not Ground.resolve(path,data,w,h),"changed bitmap accepted an unrelated mask");spec.digest=digest
 data:release()
end
if out then out:close() end;print('GROUND_TOTAL',count,failed);assert(failed==0,'shipped arena missing valid semantic placement')
-- A bright, opaque river remains forbidden regardless of its RGB content.
local regions={{{.2,.5},{.8,.5},{.8,.8},{.2,.8}}}
assert(not Ground.supports(regions,.5,.3,.05,.02),'river accepted')
assert(not Ground.supports(regions,.22,.6,.05,.02),'contact patch crossed bank')
assert(Ground.supports(regions,.5,.6,.05,.02),'interior ground rejected')
print('Arena ground native contracts: ok')

local concave={{{0,0},{1,0},{1,1},{.63,1},{.63,.4},{.61,.4},{.61,1},{0,1}}}
assert(not Ground.supports(concave,.5,.6,.3,.2),'thin inlet crossed between sample points')
local shifted=assert(Ground.fit(regions,{x=.3,y=.6},{.1,.58,.2,.04},.2,.46))
assert(shifted.x>.3,'asymmetric contact origin was not moved away from the bank')
assert(Ground.supports(regions,shifted.x-.1,shifted.y,.104,.024),'fitted footprint still crosses the bank')
