local V = ...
local ModSetting = V.require("ModSetting")

local Card = {
  ID="vasc.gen1.weather-music.option-ui",
  VERSION="1.0.0",
  CAPABILITY="ascendant.weather-music.option/v1",
  KEY="weatherMusic",
}

Card.setting = ModSetting.new(Card.KEY, "WEATHER MUSIC",
  { false, true }, { "OFF", "ON" }, true)

function Card.enabled()
  return Card.setting:get() == true
end

function Card.descriptor()
  return {
    schema="ascendant.card/v1", id=Card.ID, version=Card.VERSION,
    owner="voxel_ascendant", requires={}, optionalRequires={}, consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/weather_music/option_ui_test.lua" },
    docs={ "docs/maintainer/VASC_GEN1_WEATHER_MUSIC.md" },
    -- This Card owns one existing VASC mod-option leaf, not a gameplay save
    -- bucket.  Keeping the namespace at the exact leaf lets the Card contract
    -- describe the real write without claiming unrelated VASC options.
    saveNamespace="options.modOptions.VOXEL_ASCENDANT.weatherMusic",
    impact={
      runtimeOwners={ "gen1.weather-music.option-ui" },
      saveWrites={ "options.modOptions.VOXEL_ASCENDANT.weatherMusic" },
      publicHooks={},
      files={
        "lib/cards/weather_music/Gen1WeatherMusicOptionUiCard.lua",
        "main_gen1.lua", "lib/VascMenu.lua",
      },
    },
    lifecycle={
      install=function() return { setting=Card.setting } end,
      activate=function(_, installed)
        local public = {
          schema="ascendant.weather-music.option/v1", apiVersion=1,
          key=Card.KEY,
          enabled=function() return Card.enabled() end,
          row=function() return installed.setting:row() end,
        }
        return { public=public }, public
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function(_, _, active)
        return { schema="ascendant.compat-status/v1",
          ok=active ~= nil, state=active and "active" or "inactive",
          enabled=Card.enabled() }
      end,
    },
  }
end

return Card
