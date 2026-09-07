local V = ...
local Catalog = V.require("weather_music/Gen1WeatherMusicCatalog")

local Card = {
  ID="vasc.gen1.weather-music.catalog",
  VERSION="1.0.0",
  CAPABILITY="ascendant.weather-music.catalog/v1",
  PACKAGE_CAPABILITY="ascendant.weather-music.package-assets/v1",
}

function Card.descriptor()
  return {
    schema="ascendant.card/v1", id=Card.ID, version=Card.VERSION,
    owner="voxel_ascendant", requires={}, optionalRequires={},
    consumes={ Card.PACKAGE_CAPABILITY }, provides={ Card.CAPABILITY },
    tests={ "tests/weather_music/catalog_test.lua" },
    docs={ "docs/maintainer/VASC_GEN1_WEATHER_MUSIC.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.weather-music.catalog" }, saveWrites={},
      publicHooks={}, files={
        "lib/weather_music/Gen1WeatherMusicCatalog.lua",
        "lib/cards/weather_music/Gen1WeatherMusicCatalogCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function(context)
        local packageCapability, reason = context.capability(
          Card.PACKAGE_CAPABILITY)
        local service = packageCapability and packageCapability.value
        local document = service and type(service.document) == "function"
          and service.document() or nil
        local owner, catalogReason = Catalog.new(document)
        if not owner then return false, catalogReason or reason end
        return { owner=owner }, owner:public()
      end,
      deactivate=function() return true end,
      abort=function() return true end,
      health=function(_, _, active)
        return active and active.owner and active.owner:status()
          or { schema=Catalog.SCHEMA, ok=false, state="inactive" }
      end,
    },
  }
end

return Card
