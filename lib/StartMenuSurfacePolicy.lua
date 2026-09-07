-- Final Gen-1 START-menu surface policy.
--
-- Feature providers contribute their descriptors early so KASC's public
-- ASCENDANT collector can consume them. This later owner removes only entries
-- that must never remain as ordinary field-menu shortcuts. Their registered
-- screens, item callbacks, FLY routes and collected ASCENDANT entries are not
-- changed.

local Policy = {
  installed = false,
  filtered = 0,
}

Policy.HOOK_PRIORITY = 2100

local HIDDEN_TOP_LEVEL_IDS = {
  vasc_kanto_fly_map = true,
  vasc_kanto_fly_map_widescreen = true,
}

function Policy.filter(items)
  if type(items) ~= "table" then return items end
  local out, changed = {}, false
  for _, row in ipairs(items) do
    local hidden = type(row) == "table"
      and HIDDEN_TOP_LEVEL_IDS[tostring(row.id or "")] == true
    if hidden then
      changed = true
      Policy.filtered = Policy.filtered + 1
    else
      out[#out + 1] = row
    end
  end
  return changed and out or items
end

function Policy.install(mod)
  if Policy.installed then return true end
  local hooks = type(mod) == "table" and mod.hooks or nil
  if not (type(hooks) == "table" and type(hooks.wrap) == "function") then
    return false, "ui.start_menu.items hook unavailable"
  end
  local ok, err = pcall(hooks.wrap, hooks, "ui.start_menu.items",
    function(nextItems, game, items)
      -- The high priority is intentional: KASC's collector (1000) receives
      -- the descriptor first; only its leftover top-level copy is removed.
      return Policy.filter(nextItems(game, items))
    end, Policy.HOOK_PRIORITY)
  if not ok then return false, tostring(err) end
  Policy.installed = true
  return true
end

function Policy.status()
  return {
    installed=Policy.installed,
    filtered=Policy.filtered,
    priority=Policy.HOOK_PRIORITY,
  }
end

return Policy
