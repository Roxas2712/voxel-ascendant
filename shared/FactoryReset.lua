-- Reset only this mod's declared settings. Never erase saves, imported ROM
-- paths, downloaded assets, or another mod's option bucket.
local M = {}

function M.apply(mod, game, config)
  if not (game and game.save and game.save.options and game.mods
      and game.mods.events and type(game.mods.events.emit) == "function"
      and type(game.writeOptions) == "function") then
    return false, "No active game/options writer"
  end
  local id = mod.id or "VOXEL_ASCENDANT"
  local settings, defaults = {}, {}
  for _, entry in ipairs(config.settings or {}) do
    local setting = entry[1]
    if setting and setting.key and setting.values then
      local value = setting.values[setting.defaultIndex or 1]
      if value ~= nil then
        defaults[setting.key] = value
        settings[#settings + 1] = setting
      end
    end
  end
  if #settings == 0 then return false, "No factory defaults available" end
  -- The device preset runs last, exactly as at a new game's startup. Child
  -- notifications may select CUSTOM; AUTO then resolves for this hardware.
  table.sort(settings, function(a, b)
    if a.key == b.key then return false end
    if a.key == "deviceProfile" then return false end
    if b.key == "deviceProfile" then return true end
    return a.key < b.key
  end)
  if config.factoryResetPrepare then config.factoryResetPrepare(game) end
  local stores = {game.save.options, game.mods}
  if game.options then stores[#stores + 1] = game.options end
  if game.mods.options then stores[#stores + 1] = game.mods.options end
  for _, store in ipairs(stores) do
    store.modOptions = store.modOptions or {}
    store.modOptions[id] = store.modOptions[id] or {}
    for key, value in pairs(defaults) do store.modOptions[id][key] = value end
  end
  for _, setting in ipairs(settings) do setting:sync(defaults[setting.key]) end
  for _, setting in ipairs(settings) do
    -- Earlier notifications may rewrite DEVICE to CUSTOM. Restore the value
    -- immediately before its own notification, like the native option writer.
    for _, store in ipairs(stores) do
      store.modOptions[id][setting.key] = defaults[setting.key]
    end
    setting:sync(defaults[setting.key])
    game.mods.events:emit("mod.options_changed", {
      mod=id, key=setting.key, value=defaults[setting.key],
      source="vasc_factory_reset", game=game,
    })
  end
  if config.factoryResetFinish then config.factoryResetFinish(game) end
  -- Sprite decorators normally refresh on a row write. A batch reset also
  -- refreshes existing actors while standing still, without touching assets.
  local api = mod.exports and mod.exports.overworldPokemon
  for _, name in ipairs({"walkingSprites", "pokemonWorldSprites"}) do
    local sprites = api and api[name]
    if sprites and type(sprites.refresh) == "function" then sprites.refresh(game) end
  end
  for _, setting in ipairs(settings) do
    setting:sync(game.mods.modOptions[id][setting.key])
  end
  local ok, result = pcall(game.writeOptions, game)
  if not ok or result == false then
    return false, "Options could not be saved: " .. tostring(result)
  end
  return true
end

return M
