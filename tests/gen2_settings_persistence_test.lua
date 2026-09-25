-- Migrating or writing VASC options must preserve other mods and loader state.
local file={profiles={keep=true},modOptions={OTHER={keep=9},VOXEL_ASCENDANT={mode='canonical'}}}
local fail=false;local writes=0
package.loaded['src.core.SaveData']={loadOptions=function()return file end,saveOptions=function(value)
 writes=writes+1;if fail then return false,'disk full'end;file=value;return true end}
local nativeCalls=0
local Manager={setOption=function()nativeCalls=nativeCalls+1;return 'native'end,openOptions=function()return 'opened'end}
package.loaded['src.mods.ManagerState']=Manager
local P=assert(loadfile('gen2/lib/ModSettingsPersistence.lua'))({mod={id='VOXEL_ASCENDANT'}})
assert(P.install());local wrapper=Manager.setOption;assert(P.install()and Manager.setOption==wrapper)
assert(Manager.setOption({},'OTHER','mode','x')=='native'and writes==0)
assert(Manager.setOption({},'VOXEL_ASCENDANT','mode','new')=='native'and writes==1)
assert(file.profiles.keep and file.modOptions.OTHER.keep==9)
local manager={game={options={modOptions={VOXEL_ASCENDANT={mode='stale',added=false}}},mods={modOptions={}}}}
assert(Manager.openOptions(manager,{id='VOXEL_ASCENDANT'})=='opened')
assert(file.modOptions.VOXEL_ASCENDANT.mode=='new'and file.modOptions.VOXEL_ASCENDANT.added==false)
assert(manager.game.mods.modOptions.VOXEL_ASCENDANT.mode=='new'and manager.game.mods.modOptions.VOXEL_ASCENDANT.added==false)
fail=true;assert(Manager.setOption({},'VOXEL_ASCENDANT','mode','retry')=='native');assert(P.status().failures==1 and P.status().lastError=='disk full')
assert(nativeCalls==3 and not P.status().globalPersistPatch)
print('PASS Gen2 settings: scoped write, migration precedence/false values, native return, idempotent install and write-error reporting')
