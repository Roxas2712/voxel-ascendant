local V = ...
local PackageAssets = V.require("weather_music/Gen1WeatherMusicPackageAssets")

local Card = {
  ID="vasc.gen1.weather-music.package-assets",
  VERSION="1.0.0",
  CAPABILITY="ascendant.weather-music.package-assets/v1",
}

function Card.descriptor(dependencies)
  dependencies = dependencies or {}
  return {
    schema="ascendant.card/v1", id=Card.ID, version=Card.VERSION,
    owner="voxel_ascendant", requires={}, optionalRequires={}, consumes={},
    provides={ Card.CAPABILITY },
    tests={ "tests/weather_music/package_assets_test.lua" },
    docs={ "docs/maintainer/VASC_GEN1_WEATHER_MUSIC.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.weather-music.package-assets" },
      saveWrites={}, publicHooks={},
      files={
        "data/gen1_weather_music.lua",
        "lib/weather_music/Gen1WeatherMusicPackageAssets.lua",
        "lib/cards/weather_music/Gen1WeatherMusicPackageAssetsCard.lua",
        "assets/audio/weather_music/gen1",
      },
    },
    lifecycle={
      install=function()
        local owner, reason = PackageAssets.new(
          dependencies.document, dependencies.mod)
        if not owner then return false, reason end
        return owner
      end,
      activate=function(_, owner)
        local ok, reason = owner:register()
        if not ok then return false, reason end
        return { owner=owner }, owner:public()
      end,
      deactivate=function(_, active)
        return not active or not active.owner or active.owner:unregister()
      end,
      abort=function(_, _, _, installed, active)
        local owner = active and active.owner or installed
        return not owner or owner:unregister()
      end,
      health=function(_, installed, active)
        local owner = active and active.owner or installed
        return owner and owner:status()
          or { schema=PackageAssets.CAPABILITY_SCHEMA, ok=false,
               state="inactive" }
      end,
    },
  }
end

return Card
