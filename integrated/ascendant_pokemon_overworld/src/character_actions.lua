-- Production action-atlas catalog for the six approved principal identities.
--
-- The renderer remains responsible for deciding when an action is active and
-- for advancing its phases.  This module only publishes stable, normalized
-- artwork paths and the shared 3x4 cardinal layout.

local CharacterActions = {}

CharacterActions.SCHEMA = "ascendant.character-actions/v1"
CharacterActions.WIDTH = 660
CharacterActions.HEIGHT = 1200
CharacterActions.COLUMNS = 3
CharacterActions.ROWS = 4
CharacterActions.DIRECTIONS = { "down", "left", "up", "right" }
CharacterActions.PHASES = { "idle", "phase_a", "phase_b" }

local identities = {
  red = true,
  blue = true,
  green = true,
  gold = true,
  kris = true,
  silver = true,
}

local actions = {
  bicycle = true,
  fishing = true,
}

local function normalized(value)
  if type(value) ~= "string" then return nil end
  return value:lower():gsub("[^a-z]", "")
end

function CharacterActions.relative(identity, action)
  identity = normalized(identity)
  action = normalized(action)
  if not identities[identity] or not actions[action] then return nil end
  return ("assets/characters/actions/%s/%s_4x3.png")
    :format(identity, action)
end

function CharacterActions.asset(mod, identity, action)
  local relative = CharacterActions.relative(identity, action)
  return relative and (mod.path .. "/" .. relative) or nil, relative
end

function CharacterActions.frame(direction, phase)
  direction = normalized(direction)
  phase = normalized(phase)
  local row, column
  for index, value in ipairs(CharacterActions.DIRECTIONS) do
    if value == direction then row = index - 1 break end
  end
  for index, value in ipairs(CharacterActions.PHASES) do
    if normalized(value) == phase then column = index - 1 break end
  end
  if row == nil or column == nil then return nil end
  return row * CharacterActions.COLUMNS + column, column, row
end

function CharacterActions.public(mod)
  local identityList, actionList = {}, {}
  for identity in pairs(identities) do identityList[#identityList + 1] = identity end
  for action in pairs(actions) do actionList[#actionList + 1] = action end
  table.sort(identityList)
  table.sort(actionList)
  return {
    schema = CharacterActions.SCHEMA,
    width = CharacterActions.WIDTH,
    height = CharacterActions.HEIGHT,
    columns = CharacterActions.COLUMNS,
    rows = CharacterActions.ROWS,
    identities = identityList,
    actions = actionList,
    directions = CharacterActions.DIRECTIONS,
    phases = CharacterActions.PHASES,
    relative = CharacterActions.relative,
    asset = function(identity, action)
      return CharacterActions.asset(mod, identity, action)
    end,
    frame = CharacterActions.frame,
  }
end

return CharacterActions
