-- Manual visual driver for a real Gen1Recomp/LÖVE run.
-- Launch with POKEPORT_DRIVER pointing at this file and a QA-only identity.
return function(game)
  while not (game and game.overworld and game.overworld.map
             and game.stack and game.stack:top() == game.overworld) do
    coroutine.yield()
  end

  local id = "VOXEL_ASCENDANT"
  local weather = os.getenv("VASC_QA_WEATHER") or "clear"
  local battleDistance = tonumber(os.getenv("VASC_QA_BATTLE_DISTANCE")) or 1
  if battleDistance ~= 1 and battleDistance ~= 2 and battleDistance ~= 3 then
    battleDistance = 1
  end
  local values = {
    battles = true,
    battleCameraDistance = 1,
    trainerBack = false,
    battleBack = false,
    sky = "full",
    weather = weather,
    shadows = false,
  }
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[id] = values
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = values

  -- Exercise the same closures as the options page. Several settings cache
  -- their first read, so mutating loader tables alone is not a valid visual
  -- test after a save has already initialized the mod.
  local Runtime = require("src.mods.Runtime")
  local rows = Runtime.call("ui.options.rows", function(_, base) return base end,
                            game, {})
  local wanted = {
    battles = "MAP", trainerBack = "OFF", battleBack = "OFF",
    weather = string.upper(weather), shadows = "OFF", sky = "FULL",
    battleCameraDistance = tostring(battleDistance) .. "X",
  }
  local selectedDistance = "MISSING"
  local function applyRows(available)
    for _, row in ipairs(available or {}) do
      local key = row.id and row.id:match("^" .. id .. ":(.+)$")
      if key and wanted[key] then
        -- Force one real closure step for this QA-only value even when the
        -- save already happens to match, then cycle back to the requested
        -- rung. This catches a displayed-but-not-writable setting row.
        if key == "battleCameraDistance" then row.step(game, 1) end
        for _ = 1, 10 do
          if row.value(game) == wanted[key] then break end
          row.step(game, 1)
        end
        if key == "battleCameraDistance" then
          selectedDistance = tostring(row.value(game))
        end
      end
    end
  end
  applyRows(rows)
  -- 3D-BTL may have been cached OFF when the first row list was built. Build
  -- it once more after MAP is selected so its conditional BTL CAM row exists.
  rows = Runtime.call("ui.options.rows", function(_, base) return base end,
                      game, {})
  applyRows(rows)

  game.overworld:setMap("PALLET_TOWN", 10, 12, "up")
  for _ = 1, 5 do coroutine.yield() end

  local status = game.modStatus or game.mods:status()
  for _, row in ipairs(status.available or {}) do
    if row.id == id or row.id == "kanto_ascendant" then
      print(("VASC_QA_MOD %s %s %s"):format(
        tostring(row.id), tostring(row.version), tostring(row.state)))
    end
  end

  local battle = require("src.battle.BattleState").newWild(
    game, "RATTATA", 3, { onFinish = function() end })
  print("VASC_QA_TRAINER_PATH " .. tostring(battle.playerBackPic))
  print("VASC_QA_TRAINER_TRUE_COLOR " .. tostring(battle.playerBackTrueColor))
  print("VASC_QA_BATTLE_WEATHER " .. tostring(weather))
  print("VASC_QA_BATTLE_DISTANCE " .. selectedDistance)
  game.overworld:pushBattle(battle)

  while true do coroutine.yield() end
end
