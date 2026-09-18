-- One upgrade per persisted options profile. Subsequent player choices win.
local M = { KEY = "humanAnimationUpgrade1" }
local values = {
  apo_card_animation_mode = "natural",
  apo_human_acting_pilot = true,
  apo_hd_walking_sprites = true,
  apo_actor_voxel_grid = "off",
}
function M.apply(mod, game)
  local options = game and game.save and game.save.options
  local loader = game and game.mods
  if not options or not loader or type(game.writeOptions) ~= "function" then return false end
  local id = mod.id
  options.modOptions = options.modOptions or {}
  loader.modOptions = loader.modOptions or {}
  local saved = options.modOptions[id] or {}
  local live = loader.modOptions[id] or {}
  options.modOptions[id], loader.modOptions[id] = saved, live
  if saved[M.KEY] == 1 or live[M.KEY] == 1 then return false end
  local beforeSaved, beforeLive = {}, {}
  for key, value in pairs(values) do
    beforeSaved[key], beforeLive[key] = saved[key], live[key]
    saved[key], live[key] = value, value
  end
  saved[M.KEY], live[M.KEY] = 1, 1
  local ok, result = pcall(game.writeOptions, game)
  if not ok or result == false then
    for key in pairs(values) do saved[key], live[key] = beforeSaved[key], beforeLive[key] end
    saved[M.KEY], live[M.KEY] = nil, nil
    return false, tostring(result)
  end
  -- The native event updates cached menu rows and active sprite providers.
  if loader.events and loader.events.emit then
    for key, value in pairs(values) do
      loader.events:emit("mod.options_changed", {mod=id,key=key,value=value,game=game})
    end
  end
  return true
end
function M.install(mod)
  local currentGame
  for _, name in ipairs({"game.ready", "save.loaded", "save.created"}) do
    mod.events:on(name, function(payload)
      currentGame = (payload and payload.game) or currentGame
      local game = currentGame
      if not game and mod._vascHostGeneration == 1 then
        local ok, value = pcall(require, "src.core.Game")
        if ok then game = value end
      end
      local changed, err = M.apply(mod, game)
      if err and mod.log then mod.log:warn("Human animation upgrade pending: %s", err) end
    end, -100)
  end
end
return M
