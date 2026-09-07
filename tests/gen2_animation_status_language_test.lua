local root=assert(arg[1])
local f=assert(io.open(root..'/gen2/main.lua','rb'))
local source=f:read('*a');f:close()
local body=assert(source:match('(local function gen2AnimationStatus%(%)%s.-)\n%-%- Patch only structural'))
local receipt={installed=false,reason='pending'}
local env=setmetatable({
  BattleAnimationCompat={status=function()return receipt end},
  BattleStadium3DFx={coverage=function()return {complete=true,reviewedMoves=251}end},
},{__index=_G})
local chunk=assert(loadstring(body..'\nreturn gen2AnimationStatus'))
setfenv(chunk,env)
local status=chunk()
assert(status().help.en:find('waiting',1,true))
assert(status().help.de:find('wartet',1,true))
receipt={installed=true,gen1=165,postGen=86,catalogValid=true,sheets=92,frames=2891}
assert(status().right=='251/251')
assert(status().help.en:find('251 reviewed',1,true))
assert(status().help.en:find('check: OK',1,true))
assert(status().help.de:find('geprüfte',1,true))
receipt.invalidFrames=1
assert(status().help.en:find('QUARANTINED',1,true))
assert(status().help.de:find('QUARANTÄNE',1,true))
receipt.invalidPrograms=1
assert(status().help.en:find('check: ERROR',1,true))
assert(status().help.de:find('FEHLER',1,true))
print('PASS Gen2 animation status EN/DE: pending, ready, quarantined, invalid')
