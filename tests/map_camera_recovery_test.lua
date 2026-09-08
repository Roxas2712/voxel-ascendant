local file = assert(io.open('lib/BattleCam.lua'))
local source = file:read('*a'); file:close()
local first = assert(source:find('local function renderedActorFrameRescue', 1, true))
local last = assert(source:find('-- DISCS has no terrain corridors', first, true))
local chunk = assert(loadstring(source:sub(first, last - 1)
  .. 'return renderedActorFrameRescue'))
local battle, arena = {}, {map={}, player={1,2}, enemy={3,4}}
local camera = {eye={10,20,100}, focus={0,0,0}, fov=.76}
local calls, acceptedFactor = 0, nil
local env = {activeBattle=battle, BattleCam={}, copyCamera=function(c)
  return {eye={unpack(c.eye)}, focus={unpack(c.focus)}, fov=c.fov}
end}
env.screenSafeCamera = function(owner, stage, ground, candidate, context)
  assert(owner == battle and stage == arena and ground == 0)
  assert(context.actual and context.opticalOnly)
  calls = calls + 1
  local factor = math.tan(candidate.fov / 2) / math.tan(camera.fov / 2)
  -- The portrait Tauros pose still crosses the edge at the former 1.75x cap.
  if factor < 1.84 then return false, 'player-outside-safe-frame' end
  acceptedFactor = factor
  return true, 'actor-hulls-clear'
end
setfenv(chunk, setmetatable(env, {__index=_G}))
local recover = chunk()
for _, reason in ipairs({'player-outside-safe-frame','enemy-outside-safe-frame',
    'player-under-message','enemy-under-player-status',
    'owner-render-unsafe','status-card-overlap'}) do
  calls = 0
  local result, pitch = recover(arena, 0, camera, .5, reason, {})
  assert(result and pitch == .5 and acceptedFactor > 1.75)
  assert(calls <= 7 and env.lastScreenSafe.battle == battle)
  assert(result.eye[1] == camera.eye[1] and result.focus[2] == camera.focus[2])
end
assert(camera.fov == .76 and arena.player[1] == 1 and arena.enemy[1] == 3)
calls = 0
for _, reason in ipairs({'owner-render-pending','provider-bounds-malformed',
    'actor-contact-outside-ground','evaluator-error:failed'}) do
  assert(not recover(arena, 0, camera, .5, reason, {}))
end
assert(not recover(arena, 0, camera, .5, 'player-under-message', {manual=true}))
assert(not recover({map={}, discs=true}, 0, camera, .5, 'player-under-message', {}))
assert(calls == 0)
for _, verdict in ipairs({'unsafe','pending'}) do
  calls = 0
  env.screenSafeCamera = function()
    calls = calls + 1
    if verdict == 'unsafe' then return false, 'enemy-under-player-status' end
    return nil, 'owner-render-pending'
  end
  assert(not recover(arena, 0, camera, .5, 'player-under-message', {}))
  assert(calls == 7, 'camera search exceeded its bound')
end
print('MAP portrait camera recovery: ok')
