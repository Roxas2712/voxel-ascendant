local M=assert(loadfile('lib/TerrariumZoomProfile.lua'))()
local records,writes,reads,warnings={},0,0,0
local fail=false
local storage={
 read=function(_,game,key)assert(key==M.KEY);reads=reads+1;return records[game.save.id]end,
 write=function(_,game,key,data)
  assert(key==M.KEY and data.version==1);writes=writes+1
  if fail then return false,'disk full' end
  records[game.save.id]={version=data.version,zoom=data.zoom};return true
 end,
}
local function fresh()return M.new(storage,.45,3,function()warnings=warnings+1 end)end
local game={save={id='first'}};local p=fresh()
assert(p.load(game)==1 and writes==0)
for i=1,50 do p.remember(1-i*.005);p.update(.005)end
assert(writes==0,'pinch wrote per movement')
p.update(.36);assert(writes==1 and records.first.zoom==.75)
assert(fresh().load(game)==.75,'restart lost profile')
local readCount=reads;p.load(game);assert(reads==readCount,'read profile every frame')
p.remember(.6);assert(p.flush()and records.first.zoom==.6,'battle-end flush lost final gesture')
fail=true;p.remember(.8);p.update(.36)
assert(records.first.zoom==.6 and warnings==1)
for i=1,60 do p.update(.01)end
assert(writes==3,'unbounded write retries')
fail=false;p.update(1);assert(records.first.zoom==.8,'failed save not retried')
assert(fresh().load(game)==.8)
-- Never write an old gesture into a replacement save's storage scope.
p.remember(.9);game.save={id='second'};assert(not p.flush())
assert(p.load(game)==1 and records.second==nil and records.first.zoom==.8)
for _,data in ipairs{{version=1,zoom='bad'},{version=2,zoom=.7},{version=1,zoom=0/0},
 {version=1,zoom=math.huge}}do
 records.second=data;assert(fresh().load(game)==1,'corrupt profile accepted')
end
records.second={version=1,zoom=-5};assert(fresh().load(game)==.45)
records.second={version=1,zoom=50};assert(fresh().load(game)==3)
assert(game.save.id=='second' and next(game.save,'id')==nil,'profile modified game save')
print('PASS Terrarium zoom profile: restart, bounded writes/retry, final flush, scope isolation and malformed data')
