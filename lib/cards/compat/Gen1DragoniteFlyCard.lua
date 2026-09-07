-- Gen-1 content compatibility Card for Dragonite's modern FLY access.
--
-- The engine's Pokemon registry remains the data owner.  This Card owns only
-- the one-time, idempotent compatibility patch and deliberately exposes no
-- renderer or save capability.

local Card = {
  ID = "vasc.gen1.compat.dragonite-fly",
  VERSION = "1.0.0",
}

function Card.normalize(pokemon)
  if type(pokemon) ~= "table" or type(pokemon.get) ~= "function"
      or type(pokemon.patch) ~= "function" then
    return nil, "Gen-1 Pokemon registry is unavailable"
  end

  local dragonite = pokemon:get("DRAGONITE")
  if type(dragonite) ~= "table" then
    return nil, "DRAGONITE definition is unavailable"
  end

  local tmhm, flySeen, changed = {}, false, false
  for _, move in ipairs(dragonite.tmhm or {}) do
    if move == "FLY" then
      if flySeen then
        changed = true
      else
        flySeen = true
        tmhm[#tmhm + 1] = move
      end
    else
      tmhm[#tmhm + 1] = move
    end
  end
  if not flySeen then
    tmhm[#tmhm + 1] = "FLY"
    changed = true
  end

  if changed then pokemon:patch("DRAGONITE", { tmhm=tmhm }) end
  return {
    schema="ascendant.compat-status/v1",
    apiVersion=1,
    ok=true,
    state="active",
    species="DRAGONITE",
    move="FLY",
    changed=changed,
    entries=#tmhm,
  }
end

function Card.descriptor(options)
  options = options or {}
  local pokemon = options.pokemon
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={},
    optionalRequires={},
    consumes={},
    provides={},
    tests={ "tests/gen1_dragonite_fly_card_test.lua" },
    docs={ "docs/maintainer/NEXT_PULL_LANE.md" },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.pokemon.DRAGONITE.tmhm" },
      saveWrites={},
      publicHooks={},
      files={ "lib/cards/compat/Gen1DragoniteFlyCard.lua" },
    },
    lifecycle={
      install=function()
        if type(pokemon) ~= "table" then
          return false, "Gen-1 Pokemon registry is unavailable"
        end
        return { pokemon=pokemon }
      end,
      activate=function(_, installed)
        return Card.normalize(installed.pokemon)
      end,
      deactivate=function(_, active)
        if type(active) == "table" then active.state = "retired" end
        return true
      end,
      abort=function(_, _, _, _, active)
        if type(active) == "table" then active.state = "failed" end
        return true
      end,
      health=function(_, _, active)
        if type(active) ~= "table" then
          return {
            schema="ascendant.compat-status/v1",
            apiVersion=1,
            ok=false,
            state="inactive",
          }
        end
        return {
          schema=active.schema,
          apiVersion=active.apiVersion,
          ok=active.ok,
          state=active.state,
          species=active.species,
          move=active.move,
          changed=active.changed,
          entries=active.entries,
        }
      end,
    },
  }
end

return Card
