local V = ...
local Router = V.require("weather_music/Gen1WeatherMusicRouter")

local Card = {
  ID="vasc.gen1.weather-music.router",
  VERSION="1.0.0",
  CAPABILITY="ascendant.weather-music.router/v1",
  CATALOG_CAPABILITY="ascendant.weather-music.catalog/v1",
}

function Card.descriptor()
  return {
    schema="ascendant.card/v1", id=Card.ID, version=Card.VERSION,
    owner="voxel_ascendant", requires={}, optionalRequires={},
    consumes={ Card.CATALOG_CAPABILITY }, provides={ Card.CAPABILITY },
    tests={ "tests/weather_music/router_test.lua" },
    docs={ "docs/maintainer/VASC_GEN1_WEATHER_MUSIC.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.weather-music.router" }, saveWrites={},
      publicHooks={}, files={
        "lib/weather_music/Gen1WeatherMusicRouter.lua",
        "lib/cards/weather_music/Gen1WeatherMusicRouterCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function(context)
        local capability, reason = context.capability(Card.CATALOG_CAPABILITY)
        local catalog = capability and capability.value
        local owner, routerReason = Router.new(catalog)
        if not owner then return false, routerReason or reason end
        local public = {
          schema=Router.SCHEMA, apiVersion=Router.API_VERSION,
          select=function(input) return owner:select(input) end,
        }
        return { owner=owner, public=public }, public
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function(_, _, active)
        return { schema="ascendant.compat-status/v1",
          ok=active ~= nil, state=active and "active" or "inactive" }
      end,
    },
  }
end

return Card
