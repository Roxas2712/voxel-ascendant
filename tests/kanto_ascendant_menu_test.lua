-- Compile the entry file too: the bridge has a small install/export call site
-- there even though this headless test exercises the isolated module.
assert(loadfile("main.lua"))
local Compat = assert(loadfile("lib/KantoAscendantCompat.lua"))()

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ")
    .. (" (expected %s, got %s)"):format(tostring(expected), tostring(actual)))
end

local function ascendantHandle(id)
  return {
    id = id,
    version = id == "kanto_ascendant" and "6.7.0" or "6.0.0",
    exports = {
      ascendantMenu = {
        collect = function() end,
        open = function() end,
      },
    },
  }
end

local function fixture(handles)
  local captured, pushes = {}, {}
  local mod = {
    find = function(id) return handles and handles[id] or nil end,
    hooks = {
      wrap = function(_, name, callback, priority)
        captured.name, captured.callback, captured.priority =
          name, callback, priority
      end,
    },
    ui = {
      insertBefore = function(items, anchor, item)
        local index = #items + 1
        for i, row in ipairs(items) do
          if row.label == anchor then index = i; break end
        end
        table.insert(items, index, item)
        return items
      end,
      push = function(game, screen)
        pushes[#pushes + 1] = { game = game, screen = screen }
      end,
    },
  }
  return mod, captured, pushes
end

local function baseRows()
  return { { label = "POKéMON" }, { label = "SAVE" }, { label = "QUIT" } }
end

-- The bridge is registered below KASC's priority-1000 collector, so KASC
-- receives the descriptor returned by this inner hook and moves it out of
-- the ordinary Start menu.
local mod, hook, pushes = fixture({
  kanto_ascendant = ascendantHandle("kanto_ascendant"),
})
assert(Compat.install(mod))
eq(hook.name, "ui.start_menu.items", "bridge uses the public Start-menu hook")
eq(hook.priority, 900, "bridge runs inside KASC's collector")

local game = {}
local rows = hook.callback(function(_, input) return input end, game, baseRows())
eq(#rows, 4, "current KASC receives one VASC descriptor")
eq(rows[2].label, "VOXEL ASCENDANT", "descriptor is inserted before SAVE")
eq(rows[2].ascendantMenu, true, "descriptor opts into KASC collection")
eq(rows[2].ascendantKey, "voxel_ascendant", "descriptor has a stable key")
eq(rows[2].ascendantOrder, 990, "descriptor sorts after KASC gameplay pages")

rows[2].onSelect()
eq(#pushes, 1, "selecting VASC opens exactly one screen")
eq(pushes[1].game, game, "settings use the active game")
eq(pushes[1].screen, "OptionsMenu", "settings stay owned by VASC Options rows")

-- Legacy KASC used the trainer_rematch id but exported the same menu facade.
local legacy, legacyHook = fixture({
  trainer_rematch = ascendantHandle("trainer_rematch"),
})
Compat.install(legacy)
local legacyRows = legacyHook.callback(
  function(_, input) return input end, game, baseRows())
eq(legacyRows[2].ascendantKey, "voxel_ascendant",
  "legacy KASC receives the same descriptor")

-- An absent, disabled or lookalike mod leaves the ordinary Start menu byte-
-- for-byte equivalent: no standalone VASC row and no hard dependency.
for _, handles in ipairs({
  {},
  { kanto_ascendant = { exports = {} } },
  { trainer_rematch = { exports = { ascendantMenu = {} } } },
}) do
  local absent, absentHook = fixture(handles)
  Compat.install(absent)
  local original = baseRows()
  local output = absentHook.callback(
    function(_, input) return input end, game, original)
  eq(output, original, "unsupported KASC shapes are a no-op")
  eq(#output, 3, "unsupported KASC shapes add no row")
end

-- Future KASC can ship the same row itself without a duplicate from VASC.
local existing = baseRows()
table.insert(existing, 2, {
  label = "RENDERER",
  ascendantMenu = true,
  ascendantKey = "voxel_ascendant",
})
local dedupe, dedupeHook = fixture({
  kanto_ascendant = ascendantHandle("kanto_ascendant"),
})
Compat.install(dedupe)
local deduped = dedupeHook.callback(
  function(_, input) return input end, game, existing)
eq(#deduped, 4, "a native KASC row is not duplicated")

local receipt = Compat.receipt()
eq(receipt.schema, "voxel-ascendant/kanto-menu/v1")
eq(receipt.optional, true)
eq(receipt.hook, "ui.start_menu.items")
eq(receipt.menuKey, "voxel_ascendant")
eq(receipt.kantoAscendantIds[1], "kanto_ascendant")
eq(receipt.kantoAscendantIds[2], "trainer_rematch")

print("ok optional KASC menu integration uses public runtime hooks")
