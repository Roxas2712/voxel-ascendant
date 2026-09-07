-- Secure VASC Battle Layout Profile v1 importer.
--
-- This module is intentionally presentation- and filesystem-neutral.  It
-- accepts JSON text or an already decoded Lua table, validates/copies the
-- complete v1 exchange schema, applies the room/voxel role guard, and returns
-- deterministic plain tables.  Runtime code supplies two narrow capabilities:
--
--   canonicalImportRoot = "/real/import/root"
--   resolveRealPath(relativePath, context) -> canonical absolute path
--   resolveAsset(assetReference, context) -> optional typed receipt
--
-- `resolveRealPath` must perform the host's realpath/symlink resolution.  This
-- importer then verifies the canonical result is strictly below the canonical
-- root.  A back view is accepted only when `resolveAsset` returns all of:
--
--   { kind="pokemon"|"mega"|"trainer", view="back",
--     fullBodyBack=true }
--
-- No image dimensions, filenames, package IDs or private companion state are
-- consulted.  Missing/unsafe receipts deterministically fall back to a front
-- role while retaining authored geometry, scale, flipX and foot anchors.

local V = ...

local BattleLayoutProfile = {
  DOCUMENT_KIND = "vasc-battle-layout-profile",
  SCHEMA_VERSION = 1,
}

local MAX_JSON_BYTES = 4 * 1024 * 1024
local MAX_TREE_DEPTH = 64
local MAX_TREE_NODES = 20000

local function profileError(code, path, detail)
  return {
    __battleLayoutProfileError = true,
    code = code,
    path = path or "$",
    detail = detail,
  }
end

local function reject(code, path, detail)
  error(profileError(code, path, detail), 0)
end

local function finite(value)
  return type(value) == "number" and value == value
    and value > -math.huge and value < math.huge
end

local function integer(value)
  return finite(value) and value % 1 == 0
end

local function pathJoin(path, field)
  if not path or path == "$" then return "$." .. tostring(field) end
  return path .. "." .. tostring(field)
end

local function assertPlainTree(root)
  local visiting = {}
  local nodes = 0

  local function visit(value, path, depth)
    local kind = type(value)
    if kind ~= "table" then
      if kind == "nil" or kind == "boolean" or kind == "number"
          or kind == "string" then return end
      reject("invalid-type", path, "unsupported Lua value " .. kind)
    end
    if getmetatable(value) ~= nil then
      reject("metatable-not-allowed", path,
             "profile tables must be ordinary data tables")
    end
    if visiting[value] then
      reject("cyclic-table", path, "profile table contains a cycle")
    end
    if depth > MAX_TREE_DEPTH then
      reject("table-too-deep", path, "profile nesting exceeds limit")
    end
    nodes = nodes + 1
    if nodes > MAX_TREE_NODES then
      reject("table-too-large", path, "profile table exceeds node limit")
    end
    visiting[value] = true
    for key, child in pairs(value) do
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        reject("invalid-type", path, "table key must be string or integer")
      end
      visit(child, pathJoin(path, key), depth + 1)
    end
    visiting[value] = nil
  end

  visit(root, "$", 0)
end

local function expectObject(value, path)
  if type(value) ~= "table" then
    reject("invalid-type", path, "expected object")
  end
  for key in pairs(value) do
    if type(key) ~= "string" then
      reject("invalid-type", path, "object key must be a string")
    end
  end
  return value
end

local function expectArray(value, path, maximum)
  if type(value) ~= "table" then
    reject("invalid-type", path, "expected array")
  end
  local count, highest = 0, 0
  for key in pairs(value) do
    if not integer(key) or key < 1 then
      reject("invalid-type", path, "array key must be a positive integer")
    end
    count = count + 1
    if key > highest then highest = key end
  end
  if count ~= highest then
    reject("invalid-type", path, "array must be contiguous")
  end
  if maximum and count > maximum then
    reject("too-many-items", path, "maximum is " .. tostring(maximum))
  end
  return count
end

local function allowedProperties(value, allowed, path)
  expectObject(value, path)
  for key in pairs(value) do
    if not allowed[key] then
      reject("unknown-property", pathJoin(path, key),
             "property is not part of profile v1")
    end
  end
end

local function required(value, field, path)
  if value[field] == nil then
    reject("missing-property", pathJoin(path, field), "property is required")
  end
  return value[field]
end

local function expectBoolean(value, path)
  if value ~= nil and type(value) ~= "boolean" then
    reject("invalid-type", path, "expected boolean")
  end
  return value
end

local function expectString(value, path, maximum, allowEmpty)
  if type(value) ~= "string" then
    reject("invalid-type", path, "expected string")
  end
  if (not allowEmpty and #value == 0) or (maximum and #value > maximum) then
    reject("invalid-string", path, "string length is outside the contract")
  end
  return value
end

local function expectNumber(value, path, minimum, maximum, exclusiveMinimum)
  if value == nil then return nil end
  if not finite(value) then
    reject("invalid-number", path, "expected finite number")
  end
  if (minimum ~= nil and
      (exclusiveMinimum and value <= minimum or not exclusiveMinimum
       and value < minimum)) or (maximum ~= nil and value > maximum) then
    reject("invalid-number", path, "number is outside the contract")
  end
  return value
end

local function expectInteger(value, path, minimum, maximum)
  if value == nil then return nil end
  if not integer(value) or (minimum and value < minimum)
      or (maximum and value > maximum) then
    reject("invalid-number", path, "expected bounded integer")
  end
  return value
end

local function expectNormalized(value, path)
  return expectNumber(value, path, 0, 1, false)
end

local function expectNormalizedSize(value, path)
  return expectNumber(value, path, 0, 1, true)
end

local function expectScale(value, path)
  return expectNumber(value, path, .01, 100, false)
end

local function expectLayer(value, path)
  return expectInteger(value, path, -10000, 10000)
end

local function expectIdentifier(value, path)
  expectString(value, path, 128, false)
  if not value:match("^[A-Za-z0-9][A-Za-z0-9._:-]*$") then
    reject("invalid-identifier", path, "identifier contains unsafe bytes")
  end
  return value
end

local function expectEnum(value, allowed, path)
  if value == nil then return nil end
  if type(value) ~= "string" or not allowed[value] then
    reject("invalid-enum", path, "unsupported value " .. tostring(value))
  end
  return value
end

local function normalizePoint(value, path)
  if value == nil then return nil end
  allowedProperties(value, {x=true,y=true}, path)
  return {
    x = expectNormalized(required(value, "x", path), pathJoin(path, "x")),
    y = expectNormalized(required(value, "y", path), pathJoin(path, "y")),
  }
end

local function normalizeRect(value, path)
  allowedProperties(value, {x=true,y=true,width=true,height=true}, path)
  local out = {
    x = expectNormalized(required(value, "x", path), pathJoin(path, "x")),
    y = expectNormalized(required(value, "y", path), pathJoin(path, "y")),
    width = expectNormalizedSize(required(value, "width", path),
                                 pathJoin(path, "width")),
    height = expectNormalizedSize(required(value, "height", path),
                                  pathJoin(path, "height")),
  }
  if out.x + out.width > 1.0000001 or out.y + out.height > 1.0000001 then
    reject("invalid-number", path, "normalized rectangle leaves viewport")
  end
  return out
end

local function unsafeRelativePath(value)
  if type(value) ~= "string" or #value < 1 or #value > 1024 then return true end
  if value:find("[%z\1-\31\127]") or value:sub(1,1) == "/"
      or value:sub(1,1) == "~" or value:find("\\", 1, true)
      or value:lower():sub(1,5) == "file:"
      or value:match("^[A-Za-z]:") or value:find("//", 1, true) then
    return true
  end
  for component in (value .. "/"):gmatch("(.-)/") do
    if component == "" or component == "." or component == ".." then
      return true
    end
  end
  return false
end

local function canonicalAbsolute(value, path)
  if type(value) ~= "string" or value == ""
      or value:find("[%z\1-\31\127]") then
    reject("invalid-canonical-path", path, "resolver returned no path")
  end
  local normalized = value:gsub("\\", "/")
  local windows = normalized:match("^[A-Za-z]:/") ~= nil
  if not windows and normalized:sub(1,1) ~= "/" then
    reject("invalid-canonical-path", path, "canonical path is not absolute")
  end
  if normalized:find("//", 1, true) then
    reject("invalid-canonical-path", path, "canonical path is not normalized")
  end
  local prefixLength = windows and 3 or 1
  local tail = normalized:sub(prefixLength + 1)
  for component in (tail .. "/"):gmatch("(.-)/") do
    if component == "" or component == "." or component == ".." then
      reject("invalid-canonical-path", path,
             "canonical path contains an unresolved component")
    end
  end
  while #normalized > prefixLength and normalized:sub(-1) == "/" do
    normalized = normalized:sub(1, -2)
  end
  return normalized, windows
end

local function verifyResolvedPath(relativePath, options, context, path)
  if type(options) ~= "table"
      or type(options.canonicalImportRoot) ~= "string"
      or type(options.resolveRealPath) ~= "function" then
    reject("unverified-relative-path", path,
           "relative paths require canonical root and realpath resolver")
  end
  local root, rootWindows = canonicalAbsolute(
    options.canonicalImportRoot, "options.canonicalImportRoot")
  if root == "/" or root:match("^[A-Za-z]:/$") then
    reject("invalid-import-root", "options.canonicalImportRoot",
           "filesystem root is too broad")
  end
  local ok, resolved, resolverDetail = pcall(
    options.resolveRealPath, relativePath, context)
  if not ok or type(resolved) ~= "string" then
    reject("path-resolution-failed", path,
           ok and tostring(resolverDetail or "no canonical path")
             or tostring(resolved))
  end
  local canonical, pathWindows = canonicalAbsolute(resolved, path)
  if rootWindows ~= pathWindows then
    reject("path-outside-root", path, "path and root use different hosts")
  end
  local foldedRoot, foldedPath = root, canonical
  if pathWindows or options.caseInsensitivePaths == true then
    foldedRoot, foldedPath = root:lower(), canonical:lower()
  end
  if foldedPath == foldedRoot
      or foldedPath:sub(1, #foldedRoot + 1) ~= foldedRoot .. "/" then
    reject("path-outside-root", path,
           "canonical path escaped the import root")
  end
end

local function normalizeAsset(value, path, options, context)
  if value == nil then return nil end
  allowedProperties(value, {assetID=true,relativePath=true}, path)
  if value.assetID == nil and value.relativePath == nil then
    reject("missing-asset-reference", path,
           "assetID or relativePath is required")
  end
  local out = {}
  if value.assetID ~= nil then
    out.assetID = expectIdentifier(value.assetID, pathJoin(path, "assetID"))
  end
  if value.relativePath ~= nil then
    if unsafeRelativePath(value.relativePath) then
      reject("unsafe-relative-path", pathJoin(path, "relativePath"),
             "profile path is absolute, local or traversing")
    end
    out.relativePath = value.relativePath
    verifyResolvedPath(value.relativePath, options, context,
                       pathJoin(path, "relativePath"))
  end
  return out
end

local function normalizeAnimation(value, path)
  if value == nil then return nil end
  allowedProperties(value, {
    frameCount=true,columns=true,rows=true,fps=true,loops=true,
    frameDurationMilliseconds=true,
  }, path)
  local out = {}
  local function animationInteger(field, minimum, maximum)
    if value[field] ~= nil then
      out[field] = expectInteger(value[field], pathJoin(path, field),
                                 minimum, maximum)
    end
  end
  animationInteger("frameCount", 1, 256)
  animationInteger("columns", 1, 256)
  animationInteger("rows", 1, 256)
  if value.fps ~= nil then
    out.fps = expectNumber(value.fps, pathJoin(path, "fps"), .1, 120, false)
  end
  if value.loops ~= nil then
    out.loops = expectBoolean(value.loops, pathJoin(path, "loops"))
  end
  animationInteger("frameDurationMilliseconds", 1, 60000)
  if out.frameCount and out.columns and out.rows
      and out.frameCount > out.columns * out.rows then
    reject("invalid-animation", path,
           "frameCount exceeds columns times rows")
  end
  return out
end

local OBJECT_ROLES = {
  ["player-pokemon-front"]=true,
  ["player-pokemon-back"]=true,
  ["player-pokemon-retro-halfback"]=true,
  ["player-pokemon-mega"]=true,
  ["enemy-pokemon-front"]=true,
  ["enemy-pokemon-back"]=true,
  ["enemy-pokemon-retro-halfback"]=true,
  ["enemy-pokemon-mega"]=true,
  ["player-trainer"]=true,
  ["enemy-trainer"]=true,
  ["generic-sprite-2d"]=true,
}

local HUD_ROLES = {
  ["enemy-status"]=true,
  ["player-status"]=true,
  ["enemy-party-balls"]=true,
  ["player-party-balls"]=true,
  command=true,
  message=true,
  ["move-info"]=true,
}

local function baseContext(profile, role, instanceID)
  return {
    stageID = profile.stageID,
    mapID = profile.mapID,
    profileID = profile.profileID,
    profileVersion = profile.profileVersion,
    role = role,
    instanceID = instanceID,
  }
end

local function resolveAssetReceipt(asset, options, context, path)
  if not asset or type(options) ~= "table"
      or type(options.resolveAsset) ~= "function" then return nil end
  local ok, receipt, detail = pcall(options.resolveAsset, asset, context)
  if not ok then
    reject("asset-resolver-failed", path, tostring(receipt))
  end
  if receipt == nil then return nil end
  if type(receipt) ~= "table" or getmetatable(receipt) ~= nil then
    reject("invalid-asset-receipt", path,
           "VASC asset resolver returned no plain receipt")
  end
  local out = {}
  if receipt.kind ~= nil then
    out.kind = expectEnum(receipt.kind,
      {pokemon=true,mega=true,trainer=true}, pathJoin(path, "kind"))
  end
  if receipt.view ~= nil then
    out.view = expectEnum(receipt.view,
      {front=true,back=true,full_back=true}, pathJoin(path, "view"))
    if out.view == "full_back" then out.view = "back" end
  end
  if receipt.fullBodyBack ~= nil then
    out.fullBodyBack = expectBoolean(receipt.fullBodyBack,
                                     pathJoin(path, "fullBodyBack"))
  end
  if receipt.frontAsset ~= nil then
    out.frontAsset = normalizeAsset(receipt.frontAsset,
      pathJoin(path, "frontAsset"), options, context)
  end
  return out
end

local function normalizeObject(value, index, profile, options)
  local path = "$.layout.objects[" .. tostring(index) .. "]"
  allowedProperties(value, {
    role=true,instanceID=true,asset=true,visible=true,normalizedX=true,
    normalizedY=true,scale=true,baseline=true,footAnchor=true,flipX=true,
    flipY=true,layer=true,opacity=true,animation=true,
  }, path)
  local role = expectEnum(required(value, "role", path), OBJECT_ROLES,
                          pathJoin(path, "role"))
  local instanceID
  if value.instanceID ~= nil then
    instanceID = expectIdentifier(value.instanceID,
                                  pathJoin(path, "instanceID"))
  elseif role == "generic-sprite-2d" then
    reject("missing-instance-id", pathJoin(path, "instanceID"),
           "generic 2D objects require a stable instance ID")
  end
  local context = baseContext(profile, role, instanceID)
  local out = {role=role}
  if instanceID ~= nil then out.instanceID = instanceID end
  if value.asset ~= nil then
    out.asset = normalizeAsset(value.asset, pathJoin(path, "asset"),
                               options, context)
  end
  if value.visible ~= nil then
    out.visible = expectBoolean(value.visible, pathJoin(path, "visible"))
  end
  if value.normalizedX ~= nil then
    out.normalizedX = expectNormalized(value.normalizedX,
                                       pathJoin(path, "normalizedX"))
  end
  if value.normalizedY ~= nil then
    out.normalizedY = expectNormalized(value.normalizedY,
                                       pathJoin(path, "normalizedY"))
  end
  if value.scale ~= nil then
    out.scale = expectScale(value.scale, pathJoin(path, "scale"))
  end
  if value.baseline ~= nil then
    out.baseline = expectNormalized(value.baseline, pathJoin(path, "baseline"))
  end
  if value.footAnchor ~= nil then
    out.footAnchor = normalizePoint(value.footAnchor,
                                    pathJoin(path, "footAnchor"))
  end
  if value.flipX ~= nil then
    out.flipX = expectBoolean(value.flipX, pathJoin(path, "flipX"))
  end
  if value.flipY ~= nil then
    out.flipY = expectBoolean(value.flipY, pathJoin(path, "flipY"))
  end
  if value.layer ~= nil then
    out.layer = expectLayer(value.layer, pathJoin(path, "layer"))
  end
  if value.opacity ~= nil then
    out.opacity = expectNormalized(value.opacity, pathJoin(path, "opacity"))
  end
  if value.animation ~= nil then
    out.animation = normalizeAnimation(value.animation,
                                       pathJoin(path, "animation"))
  end
  local receipt = resolveAssetReceipt(out.asset, options, context,
                                      pathJoin(path, "assetReceipt"))
  return out, receipt, path
end

local function certifiedBack(receipt, expectedKind)
  if not receipt or receipt.view ~= "back"
      or receipt.fullBodyBack ~= true then return false end
  if expectedKind == "pokemon" then
    return receipt.kind == "pokemon" or receipt.kind == "mega"
  end
  return receipt.kind == expectedKind
end

local function roomFront(role)
  if role:sub(1,6) == "player" then return "player-pokemon-front" end
  return "enemy-pokemon-front"
end

local function markRoom(object, view, fullBodyBack, fallback, sourceRole, reason)
  object.room = {
    view = view,
    fullBodyBack = fullBodyBack == true,
    fallback = fallback == true,
  }
  if sourceRole and sourceRole ~= object.role then
    object.room.sourceRole = sourceRole
  end
  if reason then object.room.fallbackReason = reason end
  return object
end

local function frontFallback(object, receipt, newRole, reason)
  local sourceRole = object.role
  object.role = newRole or roomFront(sourceRole)
  object.asset = receipt and receipt.frontAsset or nil
  markRoom(object, "front", false, true, sourceRole, reason)
  return object
end

local function applyRoomGuard(object, receipt)
  local role = object.role
  if role == "generic-sprite-2d" then return nil, 0 end

  if role == "player-pokemon-front" or role == "enemy-pokemon-front" then
    if receipt and receipt.view == "back" then
      return frontFallback(object, receipt, role, "front-role-back-asset"), 90
    end
    return markRoom(object, "front", false, false), 100
  end

  if role == "player-pokemon-retro-halfback"
      or role == "enemy-pokemon-retro-halfback" then
    return frontFallback(object, receipt, roomFront(role), "retro-halfback"), 10
  end

  if role == "player-pokemon-back" or role == "enemy-pokemon-back" then
    if certifiedBack(receipt, "pokemon") then
      return markRoom(object, "back", true, false), 100
    end
    return frontFallback(object, receipt, roomFront(role),
                         "uncertified-back"), 20
  end

  if role == "player-pokemon-mega" or role == "enemy-pokemon-mega" then
    if object.asset == nil then
      return markRoom(object, "front", false, false), 100
    end
    if receipt and receipt.view == "front" then
      return markRoom(object, "front", false, false), 100
    end
    if certifiedBack(receipt, "pokemon") then
      return markRoom(object, "back", true, false), 100
    end
    return frontFallback(object, receipt, roomFront(role),
                         "unresolved-mega-view"), 15
  end

  if role == "player-trainer" then
    if object.asset == nil then
      return markRoom(object, "front", false, false), 100
    end
    if receipt and receipt.view == "front" and receipt.kind == "trainer" then
      return markRoom(object, "front", false, false), 100
    end
    if certifiedBack(receipt, "trainer") then
      return markRoom(object, "back", true, false), 100
    end
    return frontFallback(object, receipt, role,
                         "uncertified-trainer-view"), 20
  end

  -- Enemy trainers are full-body fronts.  A back receipt, even if valid for a
  -- player slot, is never accepted on the opponent side.
  if object.asset == nil then
    return markRoom(object, "front", false, false), 100
  end
  if receipt and receipt.view == "front" and receipt.kind == "trainer" then
    return markRoom(object, "front", false, false), 100
  end
  return frontFallback(object, receipt, role,
                       "invalid-enemy-trainer-view"), 20
end

local function objectIdentity(object)
  return object.role .. "\0" .. (object.instanceID or "")
end

local function normalizeObjects(value, profile, options)
  if value == nil then return nil end
  local count = expectArray(value, "$.layout.objects", 1024)
  local sourceIdentities = {}
  local resolved = {}
  for index = 1, count do
    local object, receipt, path = normalizeObject(value[index], index,
                                                  profile, options)
    local sourceKey = objectIdentity(object)
    if sourceIdentities[sourceKey] then
      reject("duplicate-object-role", path,
             "duplicate role and instanceID " .. sourceKey)
    end
    sourceIdentities[sourceKey] = true
    local guarded, priority = applyRoomGuard(object, receipt)
    if guarded then
      local key = objectIdentity(guarded)
      local candidate = {
        object=guarded,
        priority=priority,
        sourceRole=object.role,
        sourceKey=sourceKey,
      }
      local previous = resolved[key]
      if not previous or candidate.priority > previous.priority
          or candidate.priority == previous.priority
             and candidate.sourceKey < previous.sourceKey then
        resolved[key] = candidate
      end
    end
  end
  local out = {}
  for _, candidate in pairs(resolved) do
    out[#out + 1] = candidate.object
  end
  table.sort(out, function(left, right)
    return objectIdentity(left) < objectIdentity(right)
  end)
  return out
end

local function normalizeHUD(value)
  if value == nil then return nil end
  local count = expectArray(value, "$.layout.hud", 7)
  local seen, out = {}, {}
  for index = 1, count do
    local path = "$.layout.hud[" .. tostring(index) .. "]"
    local item = value[index]
    allowedProperties(item, {
      role=true,visible=true,normalizedX=true,normalizedY=true,
      normalizedWidth=true,normalizedHeight=true,scale=true,opacity=true,
      layer=true,respectsSafeArea=true,
    }, path)
    local role = expectEnum(required(item, "role", path), HUD_ROLES,
                            pathJoin(path, "role"))
    if seen[role] then
      reject("duplicate-hud-role", path, "duplicate HUD role " .. role)
    end
    seen[role] = true
    local normalized = {role=role}
    if item.visible ~= nil then
      normalized.visible = expectBoolean(item.visible,
                                         pathJoin(path, "visible"))
    end
    if item.normalizedX ~= nil then
      normalized.normalizedX = expectNormalized(item.normalizedX,
                                                pathJoin(path, "normalizedX"))
    end
    if item.normalizedY ~= nil then
      normalized.normalizedY = expectNormalized(item.normalizedY,
                                                pathJoin(path, "normalizedY"))
    end
    if item.normalizedWidth ~= nil then
      normalized.normalizedWidth = expectNormalizedSize(
        item.normalizedWidth, pathJoin(path, "normalizedWidth"))
    end
    if item.normalizedHeight ~= nil then
      normalized.normalizedHeight = expectNormalizedSize(
        item.normalizedHeight, pathJoin(path, "normalizedHeight"))
    end
    if item.scale ~= nil then
      normalized.scale = expectScale(item.scale, pathJoin(path, "scale"))
    end
    if item.opacity ~= nil then
      normalized.opacity = expectNormalized(item.opacity,
                                             pathJoin(path, "opacity"))
    end
    if item.layer ~= nil then
      normalized.layer = expectLayer(item.layer, pathJoin(path, "layer"))
    end
    if item.respectsSafeArea ~= nil then
      normalized.respectsSafeArea = expectBoolean(
        item.respectsSafeArea, pathJoin(path, "respectsSafeArea"))
    end
    out[#out + 1] = normalized
  end
  table.sort(out, function(left, right) return left.role < right.role end)
  return out
end

local function normalizeMask(value, index, profile, options)
  local path = "$.layout.backdrop.masks[" .. tostring(index) .. "]"
  allowedProperties(value, {
    maskID=true,asset=true,rect=true,opacity=true,inverted=true,
  }, path)
  local maskID = expectIdentifier(required(value, "maskID", path),
                                  pathJoin(path, "maskID"))
  if value.asset == nil and value.rect == nil then
    reject("missing-asset-reference", path,
           "mask requires asset or normalized rectangle")
  end
  local context = baseContext(profile, "backdrop-mask", maskID)
  local out = {maskID=maskID}
  if value.asset ~= nil then
    out.asset = normalizeAsset(value.asset, pathJoin(path, "asset"),
                               options, context)
  end
  if value.rect ~= nil then
    out.rect = normalizeRect(value.rect, pathJoin(path, "rect"))
  end
  if value.opacity ~= nil then
    out.opacity = expectNormalized(value.opacity, pathJoin(path, "opacity"))
  end
  if value.inverted ~= nil then
    out.inverted = expectBoolean(value.inverted, pathJoin(path, "inverted"))
  end
  return out
end

local function normalizeBackdrop(value, profile, options)
  if value == nil then return nil end
  local path = "$.layout.backdrop"
  allowedProperties(value, {
    asset=true,fit=true,normalizedX=true,normalizedY=true,scale=true,zoom=true,
    rotationDegrees=true,flipX=true,flipY=true,layer=true,opacity=true,
    horizon=true,vanishingPoint=true,masks=true,
  }, path)
  local out = {}
  if value.asset ~= nil then
    out.asset = normalizeAsset(value.asset, pathJoin(path, "asset"), options,
      baseContext(profile, "backdrop", nil))
  end
  if value.fit ~= nil then
    out.fit = expectEnum(value.fit, {crop=true,cover=true,contain=true},
                         pathJoin(path, "fit"))
  end
  local normalizedFields = {"normalizedX","normalizedY","opacity","horizon"}
  for _, field in ipairs(normalizedFields) do
    if value[field] ~= nil then
      out[field] = expectNormalized(value[field], pathJoin(path, field))
    end
  end
  for _, field in ipairs({"scale","zoom"}) do
    if value[field] ~= nil then
      out[field] = expectScale(value[field], pathJoin(path, field))
    end
  end
  if value.rotationDegrees ~= nil then
    out.rotationDegrees = expectNumber(value.rotationDegrees,
      pathJoin(path, "rotationDegrees"), -3600, 3600, false)
  end
  for _, field in ipairs({"flipX","flipY"}) do
    if value[field] ~= nil then
      out[field] = expectBoolean(value[field], pathJoin(path, field))
    end
  end
  if value.layer ~= nil then
    out.layer = expectLayer(value.layer, pathJoin(path, "layer"))
  end
  if value.vanishingPoint ~= nil then
    out.vanishingPoint = normalizePoint(value.vanishingPoint,
                                        pathJoin(path, "vanishingPoint"))
  end
  if value.masks ~= nil then
    local count = expectArray(value.masks, pathJoin(path, "masks"), 256)
    local seen = {}
    out.masks = {}
    for index = 1, count do
      local mask = normalizeMask(value.masks[index], index, profile, options)
      if seen[mask.maskID] then
        reject("duplicate-mask-id", pathJoin(path, "masks"),
               "duplicate mask " .. mask.maskID)
      end
      seen[mask.maskID] = true
      out.masks[#out.masks + 1] = mask
    end
    table.sort(out.masks, function(left, right)
      return left.maskID < right.maskID
    end)
  end
  return out
end

local function normalizeViewport(value)
  local path = "$.referenceViewport"
  allowedProperties(value, {
    width=true,height=true,aspectRatio=true,safeArea=true,
  }, path)
  local width = expectInteger(required(value, "width", path),
                              pathJoin(path, "width"), 1, 32768)
  local height = expectInteger(required(value, "height", path),
                               pathJoin(path, "height"), 1, 32768)
  local ratio = expectNumber(required(value, "aspectRatio", path),
                             pathJoin(path, "aspectRatio"), 0, nil, true)
  if math.abs(ratio - width / height) > .000001 then
    reject("invalid-viewport", path,
           "aspectRatio does not equal width divided by height")
  end
  local safePath = pathJoin(path, "safeArea")
  local safe = required(value, "safeArea", path)
  allowedProperties(safe, {
    top=true,leading=true,bottom=true,trailing=true,
  }, safePath)
  local normalizedSafe = {}
  for _, field in ipairs({"top","leading","bottom","trailing"}) do
    normalizedSafe[field] = expectNormalized(required(safe, field, safePath),
      pathJoin(safePath, field))
  end
  if normalizedSafe.top + normalizedSafe.bottom >= 1
      or normalizedSafe.leading + normalizedSafe.trailing >= 1 then
    reject("invalid-safe-area", safePath,
           "opposing safe-area insets consume the viewport")
  end
  return {
    width=width,
    height=height,
    aspectRatio=ratio,
    safeArea=normalizedSafe,
  }
end

local function normalizeImage(value)
  if value == nil then return nil end
  local path = "$.image"
  allowedProperties(value, {family=true,variant=true}, path)
  local out = {}
  if value.family ~= nil then
    out.family = expectIdentifier(value.family, pathJoin(path, "family"))
  end
  if value.variant ~= nil then
    out.variant = expectIdentifier(value.variant, pathJoin(path, "variant"))
  end
  return out
end

local function normalizeReview(value)
  if value == nil then return nil end
  local path = "$.review"
  allowedProperties(value, {status=true,note=true}, path)
  local out = {}
  if value.status ~= nil then
    out.status = expectEnum(value.status, {
      open=true,["in-progress"]=true,reviewed=true,blocked=true,
    }, pathJoin(path, "status"))
  end
  if value.note ~= nil then
    out.note = expectString(value.note, pathJoin(path, "note"), 32768, true)
    if out.note:find("\0", 1, true) then
      reject("invalid-string", pathJoin(path, "note"), "NUL is forbidden")
    end
  end
  return out
end

local function normalizeProfile(value, options)
  allowedProperties(value, {
    documentKind=true,schemaVersion=true,profileVersion=true,stageID=true,
    mapID=true,profileID=true,presetID=true,hudStyleID=true,image=true,
    referenceViewport=true,layout=true,review=true,
  }, "$")
  if required(value, "documentKind", "$") ~= BattleLayoutProfile.DOCUMENT_KIND
      or required(value, "schemaVersion", "$")
         ~= BattleLayoutProfile.SCHEMA_VERSION then
    reject("unsupported-document", "$",
           "documentKind or schemaVersion is unsupported")
  end
  local profile = {
    documentKind = BattleLayoutProfile.DOCUMENT_KIND,
    schemaVersion = BattleLayoutProfile.SCHEMA_VERSION,
    profileVersion = expectInteger(required(value, "profileVersion", "$"),
      "$.profileVersion", 1, 1000000),
    stageID = expectIdentifier(required(value, "stageID", "$"), "$.stageID"),
    mapID = expectIdentifier(required(value, "mapID", "$"), "$.mapID"),
    profileID = expectIdentifier(required(value, "profileID", "$"),
                                 "$.profileID"),
    presetID = expectIdentifier(required(value, "presetID", "$"),
                                "$.presetID"),
  }
  if value.hudStyleID ~= nil then
    profile.hudStyleID = expectIdentifier(value.hudStyleID, "$.hudStyleID")
  end
  profile.image = normalizeImage(value.image)
  profile.referenceViewport = normalizeViewport(
    required(value, "referenceViewport", "$"))
  local layoutValue = required(value, "layout", "$")
  allowedProperties(layoutValue, {backdrop=true,objects=true,hud=true},
                    "$.layout")
  profile.layout = {}
  profile.layout.backdrop = normalizeBackdrop(layoutValue.backdrop,
                                              profile, options)
  profile.layout.objects = normalizeObjects(layoutValue.objects,
                                            profile, options)
  profile.layout.hud = normalizeHUD(layoutValue.hud)
  profile.review = normalizeReview(value.review)
  return profile
end

-- Strict JSON syntax preflight.  The repository's small decoder is reused for
-- actual decoding, while this scanner closes its intentionally minimal gaps:
-- trailing bytes, duplicate keys, null erasure, malformed numbers and unsafe
-- control/UTF-8 sequences.
local function strictJSONPreflight(text)
  if type(text) ~= "string" or #text == 0 or #text > MAX_JSON_BYTES then
    reject("invalid-json", "$", "JSON text length is outside the limit")
  end
  local length = #text

  local function skipWhitespace(index)
    while index <= length do
      local byte = text:byte(index)
      if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then break end
      index = index + 1
    end
    return index
  end

  local function utf8Length(index)
    local first = text:byte(index)
    local needed, minimum
    if first >= 0xC2 and first <= 0xDF then needed, minimum = 2, 0x80
    elseif first >= 0xE0 and first <= 0xEF then needed, minimum = 3, 0x800
    elseif first >= 0xF0 and first <= 0xF4 then needed, minimum = 4, 0x10000
    else return nil end
    if index + needed - 1 > length then return nil end
    local code
    if needed == 2 then code = first - 0xC0
    elseif needed == 3 then code = first - 0xE0
    else code = first - 0xF0 end
    for offset = 2, needed do
      local byte = text:byte(index + offset - 1)
      if byte < 0x80 or byte > 0xBF then return nil end
      code = code * 64 + byte - 0x80
    end
    if code < minimum or code > 0x10FFFF
        or code >= 0xD800 and code <= 0xDFFF then return nil end
    return needed
  end

  local function utf8For(code)
    if code <= 0x7F then return string.char(code) end
    if code <= 0x7FF then
      return string.char(0xC0 + math.floor(code / 64),
                         0x80 + code % 64)
    end
    return string.char(0xE0 + math.floor(code / 4096),
      0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
  end

  local function parseString(index)
    if text:sub(index,index) ~= '"' then
      reject("invalid-json", "$", "expected string at " .. tostring(index))
    end
    index = index + 1
    local output = {}
    while index <= length do
      local byte = text:byte(index)
      if byte == 34 then return table.concat(output), index + 1 end
      if byte < 32 then
        reject("invalid-json", "$", "unescaped control in string")
      elseif byte == 92 then
        local escaped = text:sub(index + 1,index + 1)
        local simple = {
          ['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f",
          n="\n",r="\r",t="\t",
        }
        if simple[escaped] then
          output[#output + 1] = simple[escaped]
          index = index + 2
        elseif escaped == "u" then
          local hex = text:sub(index + 2,index + 5)
          if #hex ~= 4 or not hex:match("^[0-9A-Fa-f]+$") then
            reject("invalid-json", "$", "invalid unicode escape")
          end
          local code = tonumber(hex, 16)
          -- The existing repository helper is deliberately BMP-only. Reject
          -- surrogate escapes instead of accepting bytes it cannot reproduce.
          if code >= 0xD800 and code <= 0xDFFF then
            reject("invalid-json", "$", "unicode surrogate is unsupported")
          end
          output[#output + 1] = utf8For(code)
          index = index + 6
        else
          reject("invalid-json", "$", "invalid string escape")
        end
      elseif byte < 128 then
        output[#output + 1] = string.char(byte)
        index = index + 1
      else
        local bytes = utf8Length(index)
        if not bytes then reject("invalid-json", "$", "invalid UTF-8") end
        output[#output + 1] = text:sub(index,index + bytes - 1)
        index = index + bytes
      end
    end
    reject("invalid-json", "$", "unterminated string")
  end

  local parseValue

  local function parseNumber(index)
    local start = index
    if text:sub(index,index) == "-" then index = index + 1 end
    local first = text:sub(index,index)
    if first == "0" then
      index = index + 1
      if text:sub(index,index):match("%d") then
        reject("invalid-json", "$", "leading zero in number")
      end
    elseif first:match("[1-9]") then
      repeat index = index + 1
      until not text:sub(index,index):match("%d")
    else
      reject("invalid-json", "$", "invalid number at " .. tostring(start))
    end
    if text:sub(index,index) == "." then
      index = index + 1
      if not text:sub(index,index):match("%d") then
        reject("invalid-json", "$", "fraction has no digits")
      end
      repeat index = index + 1
      until not text:sub(index,index):match("%d")
    end
    local exponent = text:sub(index,index)
    if exponent == "e" or exponent == "E" then
      index = index + 1
      local sign = text:sub(index,index)
      if sign == "+" or sign == "-" then index = index + 1 end
      if not text:sub(index,index):match("%d") then
        reject("invalid-json", "$", "exponent has no digits")
      end
      repeat index = index + 1
      until not text:sub(index,index):match("%d")
    end
    return index
  end

  local function parseArray(index, depth)
    index = skipWhitespace(index + 1)
    if text:sub(index,index) == "]" then return index + 1 end
    while true do
      index = parseValue(index, depth + 1)
      index = skipWhitespace(index)
      local byte = text:sub(index,index)
      if byte == "]" then return index + 1 end
      if byte ~= "," then
        reject("invalid-json", "$", "expected comma or closing bracket")
      end
      index = skipWhitespace(index + 1)
    end
  end

  local function parseObject(index, depth)
    index = skipWhitespace(index + 1)
    local keys = {}
    if text:sub(index,index) == "}" then return index + 1 end
    while true do
      local key
      key, index = parseString(index)
      if keys[key] then
        reject("invalid-json", "$", "duplicate object key " .. key)
      end
      keys[key] = true
      index = skipWhitespace(index)
      if text:sub(index,index) ~= ":" then
        reject("invalid-json", "$", "expected colon")
      end
      index = parseValue(skipWhitespace(index + 1), depth + 1)
      index = skipWhitespace(index)
      local byte = text:sub(index,index)
      if byte == "}" then return index + 1 end
      if byte ~= "," then
        reject("invalid-json", "$", "expected comma or closing brace")
      end
      index = skipWhitespace(index + 1)
    end
  end

  parseValue = function(index, depth)
    if depth > MAX_TREE_DEPTH then
      reject("invalid-json", "$", "JSON nesting exceeds limit")
    end
    index = skipWhitespace(index)
    local byte = text:sub(index,index)
    if byte == '"' then local _, nextIndex = parseString(index); return nextIndex end
    if byte == "{" then return parseObject(index, depth) end
    if byte == "[" then return parseArray(index, depth) end
    if byte == "-" or byte:match("%d") then return parseNumber(index) end
    if text:sub(index,index + 3) == "true" then return index + 4 end
    if text:sub(index,index + 4) == "false" then return index + 5 end
    if text:sub(index,index + 3) == "null" then
      reject("invalid-json", "$", "null is outside the v1 schema")
    end
    reject("invalid-json", "$", "unexpected token at " .. tostring(index))
  end

  local finish = skipWhitespace(parseValue(skipWhitespace(1), 0))
  if finish <= length then
    reject("invalid-json", "$", "trailing JSON bytes")
  end
end

local cachedJSONDecoder
local attemptedJSONDecoder = false

local function jsonDecoder(options)
  if type(options) == "table" and type(options.decodeJSON) == "function" then
    return options.decodeJSON
  end
  if not attemptedJSONDecoder then
    attemptedJSONDecoder = true
    if type(V) == "table" and type(V.require) == "function" then
      local ok, helper = pcall(V.require, "json_decode")
      if ok and type(helper) == "table" and type(helper.decode) == "function" then
        cachedJSONDecoder = helper.decode
      end
    end
  end
  return cachedJSONDecoder
end

local function decodeInput(input, options)
  if type(input) == "table" then return input end
  if type(input) ~= "string" then
    reject("invalid-type", "$", "profile input must be JSON text or table")
  end
  strictJSONPreflight(input)
  local decoder = jsonDecoder(options)
  if not decoder then
    reject("json-decoder-unavailable", "$",
           "supply options.decodeJSON or VASC json_decode")
  end
  local ok, decoded, detail = pcall(decoder, input)
  if not ok or type(decoded) ~= "table" then
    reject("invalid-json", "$", ok and tostring(detail or "root is not object")
      or tostring(decoded))
  end
  return decoded
end

local function importUnsafe(input, options)
  if options ~= nil and type(options) ~= "table" then
    reject("invalid-options", "options", "expected options table")
  end
  local decoded = decodeInput(input, options or {})
  assertPlainTree(decoded)
  expectObject(decoded, "$")
  return normalizeProfile(decoded, options or {})
end

function BattleLayoutProfile.import(input, options)
  local ok, value = pcall(importUnsafe, input, options)
  if ok then return value, nil end
  if type(value) == "table" and value.__battleLayoutProfileError then
    return nil, value
  end
  return nil, profileError("internal-error", "$", tostring(value))
end

function BattleLayoutProfile.validate(input, options)
  local value, err = BattleLayoutProfile.import(input, options)
  if not value then return nil, err end
  return true, value
end

function BattleLayoutProfile.identity(profile)
  if type(profile) ~= "table" then return nil end
  if type(profile.stageID) ~= "string" or type(profile.mapID) ~= "string"
      or type(profile.profileID) ~= "string" then return nil end
  return {
    stageID=profile.stageID,
    mapID=profile.mapID,
    profileID=profile.profileID,
    profileVersion=profile.profileVersion,
    presetID=profile.presetID,
  }
end

function BattleLayoutProfile.identityKey(profile)
  local identity = BattleLayoutProfile.identity(profile)
  if not identity then return nil end
  return identity.stageID .. "\0" .. identity.mapID .. "\0" .. identity.profileID
end

function BattleLayoutProfile.errorMessage(err)
  if type(err) ~= "table" then return tostring(err or "unknown error") end
  local message = tostring(err.code or "profile-error")
    .. " at " .. tostring(err.path or "$")
  if err.detail then message = message .. ": " .. tostring(err.detail) end
  return message
end

return BattleLayoutProfile
