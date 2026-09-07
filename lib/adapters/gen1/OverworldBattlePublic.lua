-- Reviewed Gen-1 compatibility boundary for the private battle renderer.
--
-- Older KASC releases legitimately extend a small presentation surface on
-- OverworldBattle (trainer/Mega textures and the cooperative wide HUD).  RC11
-- also adds lifecycle, process-lease and native-preflight controls which must
-- never become callable merely because the historical module name is public.
-- This proxy keeps the reviewed presentation contract while withholding every
-- owner/control seam and the raw renderer table itself.

local Public = {
  API_VERSION = 1,
  SCHEMA = "ascendant.gen1-overworld-battle-public/v1",
  LEGACY_BRIDGE_SCHEMA =
    "ascendant.gen1-overworld-battle-legacy-bridge/v1",
}

local unpackValues = table.unpack or unpack

local function packValues(...)
  return { n=select("#", ...), ... }
end

-- Explicit read contract.  Missing platform-dependent fields (notably
-- snapHUDs on iOS) remain nil because lookup always reflects the live owner.
local READABLE = {}
for _, key in ipairs({
  "KEY", "LABEL", "ARENA", "FLAT_B",
  "NATIVE_FRONT_RIGHT", "NATIVE_FRONT_BASELINE", "NATIVE_FRONT_MAX",
  "ARENA_ART_KEY", "ARENA_ART_LABEL", "ART_MIX", "ART_VASC", "ART_FRLG",
  "DISK_ART_KEY", "DISK_ART_LABEL",
  "POKEMON_BACK_KEY", "POKEMON_BACK_LABEL",
  "TRAINER_BACK_KEY", "TRAINER_BACK_LABEL", "BACK_KEY", "BACK_LABEL",
  "CLASSIC_BACK_CARD_MAX", "ANCHOR", "SLOT_W", "HUD_RECT", "TEXT_RECT",
  "HUD_BAND", "ANCHOR_SPAN", "ANIM_SCALE_MIN", "ANIM_SCALE_MAX",
  "TEX_AX", "TEX_AY",
  "setting", "arenaArtSetting", "diskArtSetting", "pokemonBackSetting",
  "trainerBackSetting", "backSetting",
  "nativeCartridgeFrontPlacement", "arenaArtMode", "latchArenaArt",
  "diskArtMode", "latchDiskArt", "discs", "arenaMode", "portable",
  "enabled", "stadium", "backCardExceedsClassicSlot",
  "classicBackCardScale", "pokemonBackSelected", "capturePresentationPlan",
  "presentationPlan", "fullBodyBackApproved", "pokemonPresentation",
  "trainerBackOptionAvailable", "trainerPresentation", "pokemonBackPinned",
  "trainerBackPinned", "backPinned", "playerBackPinned",
  "trainerBackStaged", "pinnedPic", "wantsFront", "wantsTrainerFront",
  "wantsTrainerBack", "routeTrainerSprite", "animScale", "textRects",
  "partyRects", "snapRects", "textPlacements", "persistentPartyPlacements",
  "hudSnapReceipt", "battleHudProviderReceipt", "battleHudCameraBounds",
  "battleHudCameraSafe", "arena", "shot",
  "battlerHeightIn", "finalizeSideTexture", "worldPlayerSprite",
  "sideTexture", "flashing", "textures", "hudLive", "hudTexture",
  "partyTexture", "textTexture", "snapHUDs", "drawHudPanels",
}) do
  READABLE[key] = true
end

-- These exact presentation functions are extended by released KASC builds.
-- Their wrapper chains live only in the proxy below.  The owner calls the
-- private bridge installed by Public.new at its reviewed render boundaries;
-- no public write ever replaces a function on the raw renderer table.
local PRESENTATION_HOOK = {
  sideTexture=true,
  hudTexture=true,
  snapHUDs=true,
  textRects=true,
  hudLive=true,
  drawHudPanels=true,
}

-- KASC 6.5.17 wraps these historical entry names to *decline* two battles
-- whose approved staged assets are unavailable.  They are virtual guard
-- chains, not aliases for the renderer's real lifecycle functions.
local LEGACY_GUARD = { begin=true, ensure=true }

local function extensionMarker(key)
  if type(key) ~= "string" then return false end
  return key:find("^__kasc") ~= nil
    or key:find("^__kantoAscendant") ~= nil
    or key:find("^__ascendant") ~= nil
    or key:find("^kantoAscendant") ~= nil
end

function Public.new(owner)
  if type(owner) ~= "table" then
    error("VOXEL_ASCENDANT: OverworldBattle owner table is required", 2)
  end
  if type(owner.setLegacyCompatibilityBridge) ~= "function" then
    error("VOXEL_ASCENDANT: OverworldBattle legacy bridge is required", 2)
  end
  local fields = {
    apiVersion=Public.API_VERSION,
    schema=Public.SCHEMA,
    legacyBridgeSchema=Public.LEGACY_BRIDGE_SCHEMA,
  }
  local proxy = {}
  local extensions = {}
  local base = {}
  local baseActive = {}
  local readableShims = {}
  local contexts = {}
  local retired = false

  -- Capture each reviewed owner implementation once.  These shims are what a
  -- legacy wrapper receives as its `original*` function.  Calling one bypasses
  -- the proxy chain and therefore cannot recursively re-enter that wrapper.
  for key in pairs(PRESENTATION_HOOK) do
    local original = owner[key]
    if type(original) == "function" then
      base[key] = (function(ownerKey, callback)
        return function(...)
          -- A current owner implementation never redispatches its own key,
          -- but make that invariant fail closed: a future base which routes
          -- back through the bridge must not recurse through itself forever.
          if retired or baseActive[ownerKey] then return nil end
          baseActive[ownerKey] = true
          local called = packValues(pcall(callback, ...))
          baseActive[ownerKey] = nil
          if called[1] ~= true then error(called[2], 0) end
          return unpackValues(called, 2, called.n)
        end
      end)(key, original)
    end
  end

  -- Reviewed read-only functions stay live while the owner is active, but a
  -- caller which captured one before a hot handoff must not retain authority
  -- through the old proxy.  Resolve the current owner function at call time and
  -- close every shim over the same retirement bit as the presentation bases.
  local function readableValue(key)
    local value = owner[key]
    if type(value) ~= "function" then return value end
    if readableShims[key] == nil then
      readableShims[key] = (function(ownerKey)
        return function(...)
          if retired then return nil end
          local callback = owner[ownerKey]
          if type(callback) ~= "function" then return nil end
          return callback(...)
        end
      end)(key)
    end
    return readableShims[key]
  end

  local guardBase = {}
  guardBase.begin = function(state, battle, ...)
    if retired then return false end
    local context = contexts[#contexts]
    if type(context) ~= "table" or context.kind ~= "guard"
        or context.entry ~= "begin" or context.state ~= state
        or context.battle ~= battle then
      return false
    end
    context.delegated = true
    return context.allowToken
  end
  guardBase.ensure = function(battle, ...)
    if retired then return false end
    local context = contexts[#contexts]
    if type(context) ~= "table" or context.kind ~= "guard"
        or context.entry ~= "ensure" or context.battle ~= battle then
      return false
    end
    context.delegated = true
    return context.allowToken
  end

  -- Historical KASC calls finish only while declining a guard, or from its
  -- staged Jessie/James sideTexture fallback.  Outside an owner-mediated call
  -- this function is inert, so the public name can never end an arbitrary
  -- renderer session.
  local function legacyFinish()
    if retired then return false end
    local context = contexts[#contexts]
    if type(context) ~= "table" or context.battle == nil then return false end
    if context.kind == "presentation" and context.key ~= "sideTexture" then
      return false
    end
    context.finishRequested = true
    return true
  end

  local function callInContext(context, callback, ...)
    contexts[#contexts + 1] = context
    local called = packValues(pcall(callback, ...))
    contexts[#contexts] = nil
    local values = { n=math.max(0, called.n - 1) }
    for index = 2, called.n do values[index - 1] = called[index] end
    return called[1] == true, values
  end

  -- The raw owner stores only this VASC-owned bridge object.  KASC callbacks
  -- remain closed over by this proxy and are discarded atomically on owner
  -- retirement/replacement.
  local bridge = {
    schema=Public.LEGACY_BRIDGE_SCHEMA,
    apiVersion=1,
  }

  function bridge.invoke(key, ...)
    if retired or not PRESENTATION_HOOK[key] then
      return {
        schema=Public.LEGACY_BRIDGE_SCHEMA,
        ok=false,
        error=retired and "legacy bridge retired"
          or "unsupported legacy presentation hook",
        values={ n=0 },
      }
    end
    local reentry = false
    for index = #contexts, 1, -1 do
      local context = contexts[index]
      if context.kind == "presentation" and context.key == key then
        reentry = true
        break
      end
    end
    -- A captured `original*` normally calls the base shim directly.  This
    -- additional key-local bypass reaches the owner base at most once; the
    -- base-active guard above makes a self-redispatching future base inert.
    local callback = reentry and base[key] or extensions[key] or base[key]
    if type(callback) ~= "function" then
      return {
        schema=Public.LEGACY_BRIDGE_SCHEMA,
        ok=false,
        error="legacy presentation hook unavailable: " .. tostring(key),
        values={ n=0 },
      }
    end
    local args = packValues(...)
    local context = {
      kind="presentation",
      key=key,
      battle=args[1],
      finishRequested=false,
    }
    local ok, values = callInContext(
      context, callback, unpackValues(args, 1, args.n))
    return {
      schema=Public.LEGACY_BRIDGE_SCHEMA,
      ok=ok,
      error=ok and nil or tostring(values[1]),
      values=values,
      finishRequested=context.finishRequested == true,
      battle=context.battle,
      key=key,
    }
  end

  function bridge.guard(entry, ...)
    if retired or not LEGACY_GUARD[entry] then
      return {
        schema=Public.LEGACY_BRIDGE_SCHEMA,
        ok=false,
        allowed=false,
        error=retired and "legacy bridge retired"
          or "unsupported legacy battle guard",
      }
    end
    local args = packValues(...)
    local context = {
      kind="guard",
      entry=entry,
      state=entry == "begin" and args[1] or nil,
      battle=entry == "begin" and args[2] or args[1],
      allowToken={},
      delegated=false,
      finishRequested=false,
    }
    local callback = extensions[entry] or guardBase[entry]
    local ok, values = callInContext(
      context, callback, unpackValues(args, 1, args.n))
    local allowed = ok and context.delegated == true
      and values.n > 0 and values[1] == context.allowToken
    return {
      schema=Public.LEGACY_BRIDGE_SCHEMA,
      ok=ok,
      allowed=allowed,
      error=ok and (allowed and nil or "legacy battle guard declined")
        or tostring(values[1]),
      finishRequested=context.finishRequested == true,
      battle=context.battle,
    }
  end

  function bridge.overridden(key)
    return not retired and extensions[key] ~= nil
      and extensions[key] ~= base[key]
  end

  function bridge.retire()
    if retired then return false end
    retired = true
    for key in pairs(extensions) do extensions[key] = nil end
    for key in pairs(baseActive) do baseActive[key] = nil end
    for key in pairs(readableShims) do readableShims[key] = nil end
    for index = #contexts, 1, -1 do contexts[index] = nil end
    for key in pairs(proxy) do rawset(proxy, key, nil) end
    return true
  end

  local installed, installReason = owner.setLegacyCompatibilityBridge(bridge)
  if installed ~= true then
    pcall(bridge.retire)
    error("VOXEL_ASCENDANT: OverworldBattle legacy bridge rejected: "
      .. tostring(installReason or "unknown reason"), 2)
  end

  return setmetatable(proxy, {
    __index=function(_, key)
      if retired then return nil end
      local own = rawget(proxy, key)
      if own ~= nil then return own end
      if fields[key] ~= nil then return fields[key] end
      if key == "finish" then return legacyFinish end
      if LEGACY_GUARD[key] then return extensions[key] or guardBase[key] end
      if PRESENTATION_HOOK[key] then return extensions[key] or base[key] end
      if READABLE[key] then return readableValue(key) end
      return nil
    end,
    __newindex=function(_, key, value)
      if retired then
        error("VOXEL_ASCENDANT: OverworldBattle compatibility bridge "
          .. "is retired", 2)
      end
      if PRESENTATION_HOOK[key] or LEGACY_GUARD[key] then
        if value ~= nil and type(value) ~= "function" then
          error("VOXEL_ASCENDANT: compatibility override "
            .. tostring(key) .. " must be a function or nil", 2)
        end
        extensions[key] = value
        return
      end
      -- Marker receipts belong to the compatibility proxy, never to the raw
      -- renderer.  rawget-based legacy probes therefore keep working without
      -- becoming a back door to lifecycle ownership.
      if extensionMarker(key) then
        rawset(proxy, key, value)
        return
      end
      error("VOXEL_ASCENDANT: OverworldBattle compatibility field is read-only: "
        .. tostring(key), 2)
    end,
    __metatable="VOXEL_ASCENDANT Gen-1 battle compatibility boundary",
  })
end

return Public
