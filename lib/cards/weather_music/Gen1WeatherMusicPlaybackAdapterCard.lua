local V = ...
local Adapter = V.require("adapters/gen1/WeatherMusicPlaybackAdapter")

local Card = {
  ID="vasc.gen1.weather-music.playback-adapter",
  VERSION="1.0.0",
  CAPABILITY="ascendant.weather-music.playback/v1",
  ROUTER_CAPABILITY="ascendant.weather-music.router/v1",
  OPTION_CAPABILITY="ascendant.weather-music.option/v1",
}

function Card.descriptor(dependencies)
  dependencies = dependencies or {}
  return {
    schema="ascendant.card/v1", id=Card.ID, version=Card.VERSION,
    owner="voxel_ascendant", requires={}, optionalRequires={},
    consumes={ Card.ROUTER_CAPABILITY, Card.OPTION_CAPABILITY },
    provides={ Card.CAPABILITY },
    tests={ "tests/weather_music/playback_adapter_test.lua" },
    docs={ "docs/maintainer/VASC_GEN1_WEATHER_MUSIC.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.weather-music.playback-adapter" }, saveWrites={},
      publicHooks={ "music.select" }, files={
        "lib/adapters/gen1/WeatherMusicPlaybackAdapter.lua",
        "lib/cards/weather_music/Gen1WeatherMusicPlaybackAdapterCard.lua",
      },
    },
    lifecycle={
      install=function() return { installed=true } end,
      activate=function(context)
        local routed, routeReason = context.capability(Card.ROUTER_CAPABILITY)
        local option, optionReason = context.capability(Card.OPTION_CAPABILITY)
        local owner, reason = Adapter.new({
          mod=dependencies.mod,
          music=dependencies.music,
          diagnostics=dependencies.diagnostics,
          router=routed and routed.value,
          option=option and option.value,
        })
        if not owner then return false, reason or routeReason or optionReason end
        local active, activeReason = owner:activate()
        if not active then return false, activeReason end
        return { owner=owner }, owner:public()
      end,
      deactivate=function(_, active, reason)
        return not active or not active.owner or active.owner:deactivate(reason)
      end,
      abort=function(_, _, reason, _, active)
        return not active or not active.owner or active.owner:deactivate(reason)
      end,
      health=function(_, _, active)
        return active and active.owner and active.owner:status()
          or { schema=Adapter.SCHEMA, ok=false, state="inactive" }
      end,
    },
  }
end

return Card
