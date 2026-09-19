-- Run against the packaged runtime, not a mock ownership ledger.
local root=assert(os.getenv('VASC_TEST_ROOT'),'VASC_TEST_ROOT required')
local modules={};local V={mod={exports={}}}
function V.require(name)
 if modules[name]~=nil then return modules[name]end
 local value=assert(loadfile(root..'/lib/'..name..'.lua'))(V)
 modules[name]=value;return value
end
local baseline=V.require('cards/gen2/A21FileOwnership')
assert(baseline.count()==217,'imported A21 baseline changed')
local host=V.require('Gen2SegmentCardHost')
local ok,reason=host.install({mod=V.mod});assert(ok,reason)
local public=host.public();assert(public.ok and #public.cards>0)
local owners={};local count=0
for _,card in ipairs(public.cards)do
 for _,path in ipairs(card.files)do
  assert(not owners[path],'duplicate ownership: '..path)
  owners[path]=card.id;count=count+1
 end
end
assert(owners['gen2/lib/FieldActorAppearance.lua']=='vasc.gen2.field-wilds','post-A21 actor adapter lost its owner')
assert(owners['gen2/lib/GoldVoxelBridge.lua']=='vasc.gen2.voxel-world','renderer owner missing')
assert(owners['gen2/main.lua']=='vasc.gen2.bootstrap','bootstrap owner missing')
assert(host.install({mod=V.mod})==true,'bootstrap not idempotent')
print('PASS_GEN2_BOOTSTRAP_OWNERSHIP',#public.cards,count)
