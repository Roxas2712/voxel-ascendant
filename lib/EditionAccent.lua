-- One generation-neutral edition accent for VASC's shared ASC/ORAS surfaces.
--
-- Red/Blue/Yellow and Gold/Silver/Crystal keep the same geometry, fills,
-- typography and controls.  Only this one-pixel border colour changes.  The
-- resolver reads the engine's public GameVersion contract and fails open to
-- VASC's existing cyan when a host cannot identify its edition.

local Accent = {}

local SHARED = {
  id="shared", label="Shared ORAS",
  border={0.04, 0.80, 0.97, 1},
}

local EDITIONS = {
  red = {
    id="red", label="Red", border={0.90, 0.20, 0.18, 1},
  },
  blue = {
    id="blue", label="Blue", border={0.16, 0.45, 0.92, 1},
  },
  yellow = {
    id="yellow", label="Yellow", border={0.98, 0.76, 0.08, 1},
  },
  gold = {
    id="gold", label="Gold", border={0.78, 0.56, 0.12, 1},
  },
  silver = {
    id="silver", label="Silver", border={0.58, 0.65, 0.74, 1},
  },
  crystal = {
    id="crystal", label="Crystal", border={0.16, 0.72, 0.80, 1},
  },
}

local ORDER = { "red", "blue", "yellow", "gold", "silver", "crystal" }

local function normalized(value)
  if type(value) == "table" then
    value = value.id or value.version or value.edition
      or value.label or value.displayName
  end
  value = tostring(value or ""):lower()
  value = value:gsub("pokémon", "pokemon"):gsub("pokemon", "")
               :gsub("version", ""):gsub("edition", "")
               :gsub("[%s_%-]", "")
  for _, id in ipairs(ORDER) do
    if value == id or value == id .. "version" then return id end
  end
  return nil
end

local function callPublic(owner, name, ...)
  local fn = type(owner) == "table" and owner[name] or nil
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok and value ~= nil then return value end
  ok, value = pcall(fn, owner, ...)
  if ok then return value end
  return nil
end

function Accent.fromGameVersion(GameVersion)
  if type(GameVersion) ~= "table" then return SHARED, SHARED.id end

  local id = normalized(callPublic(GameVersion, "get"))
  if not id then
    id = normalized(callPublic(GameVersion, "info"))
  end
  if not id then
    id = normalized(GameVersion.current or GameVersion.id
      or GameVersion.version or GameVersion.edition)
  end
  if not id then
    local predicates = {
      red="isRed", blue="isBlue", yellow="isYellow",
      gold="isGold", silver="isSilver", crystal="isCrystal",
    }
    for _, candidate in ipairs(ORDER) do
      if callPublic(GameVersion, predicates[candidate]) == true then
        id = candidate
        break
      end
    end
  end
  return EDITIONS[id] or SHARED, id or SHARED.id
end

function Accent.resolve(explicit)
  local id = normalized(explicit)
  if id then return EDITIONS[id], id end
  if explicit ~= nil then return SHARED, SHARED.id end

  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if not ok then return SHARED, SHARED.id end
  return Accent.fromGameVersion(GameVersion)
end

function Accent.color(explicit)
  local palette, id = Accent.resolve(explicit)
  return palette.border, id
end

function Accent.editions()
  local out = {}
  for index, id in ipairs(ORDER) do out[index] = id end
  return out
end

function Accent.palette(id)
  return EDITIONS[normalized(id)]
end

Accent.apiVersion = 1
Accent.policy = "shared-oras-thin-edition-border"
Accent.shared = SHARED
Accent.palettes = EDITIONS

return Accent
