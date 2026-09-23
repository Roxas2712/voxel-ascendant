-- Prepare the engine's exact chip PCM incrementally while battle menus/intro
-- are visible. Playback, timing and channel arbitration stay in Sound.lua.
local M={}
local Synth=require('src.core.ChipSynth')
local Audio=require('src.core.ChipAudio')
local queue,entries={},{}
local bytes,serial=0,0
local LIMIT=8*1024*1024
local previous,previousCry,configuration
local function config()
  local v={Synth.SAMPLE_RATE,tostring(Synth.getStereo())}
  for i=1,4 do v[#v+1]=Synth.getChannelVolume(i);v[#v+1]=Synth.getChannelPitch(i) end
  v[#v+1]=Synth.getNoiseVolume()
  return table.concat(v,':')
end
function M.clear()
  for _,e in pairs(entries)do
    if e.pcm then e.pcm:release()end
    if e.building then e.building:release()end
  end
  queue,entries={},{};bytes=0;configuration=config()
end
local function key(data,header,pitch,tempo,plain)
  return tostring(data)..':'..tostring(header)..':'..tostring(pitch or 0)..':'..tostring(tempo or 128)..':'..tostring(plain or 0)
end
local function prepare(e)
  local rate=Synth.SAMPLE_RATE
  local engine=Synth.newEngine(e.data,e.header,e.options)
  local values,count={},0
  while count<rate*12 and not engine:finished()do
    count=count+1;values[count]=engine:sample()
    if count%512==0 then coroutine.yield()end
  end
  if count<math.floor(rate/100)then return end
  local pcm=love.sound.newSoundData(count,rate,16,2)
  e.building=pcm
  for i=1,count do
    pcm:setSample(i-1,1,values[i]);pcm:setSample(i-1,2,values[i])
    if i%512==0 then coroutine.yield()end
  end
  e.building=nil;e.pcm=pcm;e.bytes=count*4;bytes=bytes+e.bytes
  while bytes>LIMIT do
    local oldest,age
    for k,row in pairs(entries)do if row~=e and row.pcm and (not age or row.used<age)then oldest,age=k,row.used end end
    if not oldest then break end
    local row=entries[oldest];bytes=bytes-row.bytes;row.pcm:release();entries[oldest]=nil
  end
end
local function enqueue(k,data,header,options)
  if entries[k] or #queue>=32 then return end
  serial=serial+1
  local e={data=data,header=header,options=options,used=serial}
  e.co=coroutine.create(function()prepare(e)end);entries[k]=e;queue[#queue+1]=e
end
function M.enqueue(data,anim)
  local header=anim and data.audio and data.audio.sfx and data.audio.sfx[anim.sound]
  if type(header)~='table' or not(header.header or header.chip or header.address)then return end
  enqueue(key(data,header,anim.pitch,anim.tempo,0),data,header,
    {sfx=true,allowLoops=false,frequencyOffset=anim.pitch or 0,
     frameTicks=128+(anim.tempo or 128),plainFrames=0})
end
-- Mirror Sound's bounded derived-cry lookup only for preparation. File/PCM
-- cries and invalid chains retain the engine path; Sound still owns playback,
-- volume, source reuse, Yellow clip selection and move-cry pitch adjustments.
local function resolveCry(data,def,depth)
  if type(def)~='table' then return nil end
  if not def.base then return (def.header or def.chip) and def or nil end
  if depth>8 then return nil end
  local cries=data.audio and data.audio.cries
  local base=resolveCry(data,cries and cries[def.base],depth+1)
  if not base then return nil end
  return {header=base.header,chip=base.chip,
    pitch=def.pitch or base.pitch,length=def.length or base.length}
end
local function cryKey(data,cry)
  return 'cry:'..tostring(data)..':'..tostring(cry.chip or cry.header)
    ..':'..tostring(cry.pitch or 0)..':'..tostring(cry.length)
end
function M.enqueueCry(data,species)
  local def=data.audio and data.audio.cries and data.audio.cries[species]
  local cry=resolveCry(data,def,0)
  if not cry then return end
  enqueue(cryKey(data,cry),data,cry.chip and cry or cry.header,
    {sfx=true,allowLoops=false,frequencyOffset=cry.pitch,cryLength=cry.length})
end
function M.scan(battle)
  if not battle or battle.animPlaying then return end
  if configuration~=config()then M.clear();battle._vascSoundMoves=nil end
  -- Queue the current entrants before move sounds so their PCM is ready
  -- during the native introduction. Changed battlers enqueue on switches too.
  for _,side in ipairs({'enemy','player'})do
    local mon=battle[side] and battle[side].mon
    if mon and mon.species then M.enqueueCry(battle.data,mon.species)end
  end
  local ids={}
  for _,side in ipairs({'player','enemy'})do
    for _,move in ipairs(battle[side] and battle[side].curMoves or{})do ids[#ids+1]=move.id end
  end
  local stamp=table.concat(ids,':')
  if battle._vascSoundMoves==stamp then return end
  battle._vascSoundMoves=stamp
  -- Native send-out sound is not part of the battlers' move lists.
  M.enqueue(battle.data,{sound='Ball_Poof'})
  for _,id in ipairs(ids)do
    local def=battle.data.moves[id];M.enqueue(battle.data,def and def.anim)
    -- Native row sounds may reference a different move's pitch/tempo.
    -- Native BattleState constructs this player from the animation registry,
    -- not the whole game data. The latter silently lost all row sounds when
    -- a decorated start failed (e.g. Surf's later Battle_2A sound).
    local ok,player=pcall(require('src.battle.AnimPlayer').new,battle.data.battle_anims)
    if ok and player then
      local started=pcall(player.start,player,id,true)
      local native=player.native or player
      if started then for _,ev in ipairs(native.events or{})do
        local row=ev.sound and battle.data.moves[ev.sound];M.enqueue(battle.data,row and row.anim)
      end end
      if player.release then pcall(player.release,player)end
    end
  end
end
function M.pump(battle)
  if battle and battle.animPlaying then return end
  local deadline=love.timer.getTime()+.002
  repeat
    local e=queue[1];if not e then return end
    local ok=coroutine.resume(e.co)
    if not ok or coroutine.status(e.co)=='dead'then
      if e.building then e.building:release();e.building=nil end
      table.remove(queue,1);e.co=nil
    end
  until love.timer.getTime()>=deadline
end
function M.install()
  if previous then return end
  M.clear();previous=Audio.newSfx
  Audio.newSfx=function(data,name,pitch,tempo,header,plain)
    header=header or data.audio.sfx[name]
    local e=configuration==config() and entries[key(data,header,pitch,tempo,plain)]
    if e and e.pcm then
      serial=serial+1;e.used=serial
      M.hits=(M.hits or 0)+1
      return love.audio.newSource(e.pcm,'static')
    end
    M.misses=(M.misses or 0)+1
    return previous(data,name,pitch,tempo,header,plain)
  end
  previousCry=Audio.newCry
  if type(previousCry)=='function' then
    Audio.newCry=function(data,species,resolved)
      local cry=resolved or (data.audio and data.audio.cries and data.audio.cries[species])
      local e=type(cry)=='table' and (cry.header or cry.chip)
        and configuration==config() and entries[cryKey(data,cry)]
      if e and e.pcm then
        serial=serial+1;e.used=serial
        M.cryHits=(M.cryHits or 0)+1
        return love.audio.newSource(e.pcm,'static')
      end
      M.cryMisses=(M.cryMisses or 0)+1
      return previousCry(data,species,resolved)
    end
  end
  require('src.render.Assets').register(M.clear)
end
return M
