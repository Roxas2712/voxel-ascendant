-- Window-space owner for VASC's large menu presentations on touch devices.
--
-- Desktop is deliberately a no-op: decorated screens keep calling the exact
-- draw/drawWidescreen methods captured from A24.  Android/iOS (and the
-- POKEPORT_TOUCH=1 QA path) move only the presentation into render.hud, where
-- the safe area and the live, user-positioned touch controls are expressed in
-- the same LÖVE-unit coordinate space.  Native update/input/stack ownership is
-- never replaced.

local V = ...
local M = {
  apiVersion = 2,
  owner = "voxel_ascendant.mobile_menu_presentation",
  VIEWPORT_SCHEMA = "vasc-mobile-viewport/v1",
  attached = 0,
  hudHook = false,
  visibilityHook = false,
  lastError = nil,
  viewportRevision = 0,
  viewportReceipt = nil,
}

local configs = setmetatable({}, { __mode="k" })
-- Complete menu renderers are allowed to reset the graphics origin (and the
-- ORAS Bag deliberately stages another Canvas of its own).  Keep one logical
-- layer per owner so those internal resets can never erase the final
-- safe-viewport transform.
local stagedLayers = setmetatable({}, { __mode="k" })
local stagedDensities = setmetatable({}, { __mode="k" })
local unpackValues = table.unpack or unpack
local viewportSignature

local function packed(...)
  return { n=select("#", ...), ... }
end

local function runtimeMember(runtime, key)
  if type(runtime) ~= "table" then return nil end
  local ok, value = pcall(function() return runtime[key] end)
  if ok then return value end
  return nil
end

-- Mod chunks run behind an environment proxy.  `_G` is therefore not the
-- table that owns the exposed LÖVE proxy and rawget(_G, "love") can be nil on
-- a real device even while ordinary `love.graphics` access is available.
-- Resolve through the environment's normal index path, but keep denied
-- modules fail-open behind pcall.
local function runtimeLove()
  local ok, value = pcall(function() return love end)
  return ok and type(value) == "table" and value or nil
end

local SafeArea, TouchControls, TouchSkin, Diagnostics
pcall(function() SafeArea = require("src.core.SafeArea") end)
pcall(function() TouchControls = require("src.core.TouchControls") end)
pcall(function() TouchSkin = require("src.core.TouchSkin") end)
if type(V) == "table" and type(V.require) == "function" then
  pcall(function() Diagnostics = V.require("Diagnostics") end)
end

local TransientClasses = {}
for _, name in ipairs({
  "src.render.TextBox", "src.ui.ChoiceBox", "src.ui.Menu",
  "src.ui.QuantityBox",
}) do
  local ok, class = pcall(require, name)
  if ok and type(class) == "table" then TransientClasses[#TransientClasses + 1] = class end
end

local function diagnostic(event, fields)
  if type(Diagnostics) == "table" and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function finite(value)
  value = tonumber(value)
  return value and value == value and value > -math.huge and value < math.huge
end

local function positive(value, fallback)
  value = tonumber(value)
  if value and value > 0 then return value end
  return fallback
end

local function copyRect(value, fallback)
  value = type(value) == "table" and value or {}
  fallback = type(fallback) == "table" and fallback or { x=0, y=0, w=1, h=1 }
  return {
    x=tonumber(value.x) or tonumber(value[1]) or fallback.x,
    y=tonumber(value.y) or tonumber(value[2]) or fallback.y,
    w=positive(value.w or value[3], fallback.w),
    h=positive(value.h or value[4], fallback.h),
  }
end

local function clampRect(rect, bounds)
  local x1 = math.max(bounds.x, math.min(bounds.x + bounds.w, rect.x))
  local y1 = math.max(bounds.y, math.min(bounds.y + bounds.h, rect.y))
  local x2 = math.max(x1, math.min(bounds.x + bounds.w, rect.x + rect.w))
  local y2 = math.max(y1, math.min(bounds.y + bounds.h, rect.y + rect.h))
  return { x=x1, y=y1, w=math.max(1, x2-x1), h=math.max(1, y2-y1) }
end

local function forcedTouch(value)
  if value ~= nil then return value == true end
  if os and type(os.getenv) == "function"
      and os.getenv("POKEPORT_TOUCH") == "1" then
    return true
  end
  return nil
end

local function visibleTouchRuntime()
  -- love.system is intentionally hidden from mod chunks and love._os is not
  -- a contractual field on every mobile shell.  The engine-owned touch pad
  -- is the stronger runtime fact anyway: when it is visibly composited over
  -- the game, full-window menu presentation must be active.  This also lets
  -- a menu pushed during early boot recover on its first visible frame once
  -- the touch overlay becomes available.
  if type(TouchControls) == "table"
      and type(TouchControls.visible) == "function" then
    local ok, visible = pcall(TouchControls.visible, TouchControls)
    if ok and visible == true then return true end
  end
  return false
end

local function mobilePlatform(platform, forced)
  platform = tostring(platform or "")
  return platform == "Android" or platform == "iOS" or forcedTouch(forced)
end

local function mobileRuntime(platform, forced)
  platform = tostring(platform or "")
  if platform == "Android" or platform == "iOS" or forced == true then
    return true
  end
  -- Do not sample touch services on a positively identified desktop. Apart
  -- from preserving the desktop no-op contract, this prevents a connected
  -- controller skin from reclassifying an ordinary desktop render.
  if platform ~= "" and platform ~= "unknown" and platform ~= "Unknown" then
    return false
  end
  return forced ~= false and visibleTouchRuntime()
end

local function controlHalf(name, zone)
  if name == "start" or name == "select" then return zone.w * .70 end
  return zone.w * .65
end

local function touchRects(safe, controls)
  local rects = {}
  local gutter = math.max(6, math.min(safe.w, safe.h) * .016)
  for name, zone in pairs(type(controls) == "table" and controls or {}) do
    if type(zone) == "table" and type(zone.rect) == "table"
        and finite(zone.rect.x) and finite(zone.rect.y)
        and positive(zone.rect.w) and positive(zone.rect.h) then
      local rect = zone.rect
      if rect.x + rect.w > safe.x and rect.x < safe.x + safe.w
          and rect.y + rect.h > safe.y and rect.y < safe.y + safe.h then
        rects[#rects + 1] = clampRect({
          x=rect.x-gutter, y=rect.y-gutter,
          w=rect.w+gutter*2, h=rect.h+gutter*2,
        }, safe)
      end
    elseif type(zone) == "table" and finite(zone.cx) and finite(zone.cy)
        and positive(zone.w) then
      local half = controlHalf(name, zone)
      local left, right = zone.cx - half, zone.cx + half
      local top, controlBottom = zone.cy - half, zone.cy + half
      if right > safe.x and left < safe.x + safe.w
          and controlBottom > safe.y and top < safe.y + safe.h then
        rects[#rects + 1] = clampRect({
          x=left-gutter, y=top-gutter,
          w=right-left+gutter*2, h=controlBottom-top+gutter*2,
        }, safe)
      end
    end
  end
  return rects, gutter
end

local function intersects(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w
    and a.y < b.y + b.h and b.y < a.y + a.h
end

local function legacyPlan(owner, logicalW, logicalH, window, safe)
  local scale = math.min(window.w / logicalW, window.h / logicalH)
  if scale >= 1 then scale = math.max(1, math.floor(scale)) end
  local x = math.floor(window.x + (window.w - logicalW * scale) / 2)
  local y = math.floor(window.y + (window.h - logicalH * scale) / 2)
  return {
    active=false, reason="desktop-native-path", owner=owner,
    logicalW=logicalW, logicalH=logicalH, scale=scale, x=x, y=y,
    w=logicalW*scale, h=logicalH*scale,
    window=window, safe=safe, usable=copyRect(window),
  }
end

-- Pure planning seam used by the LÖVE contract. All values are LÖVE window
-- units; framebuffer dimensions/DPI are receipt-only and never feed layout.
function M.planFor(opts)
  opts = type(opts) == "table" and opts or {}
  local owner = tostring(opts.owner or "menu")
  local logicalW = positive(opts.logicalW, 512)
  local logicalH = positive(opts.logicalH, 288)
  local window = copyRect(opts.window, { x=0, y=0, w=1, h=1 })
  local safe = clampRect(copyRect(opts.safe, window), window)
  if not mobilePlatform(opts.platform, opts.forcedTouch) then
    local plan = legacyPlan(owner, logicalW, logicalH, window, safe)
    plan.receipt = {
      owner=owner, platform=tostring(opts.platform or "unknown"),
      active=false, window=copyRect(window), safe=copyRect(safe),
      usable=copyRect(plan.usable), scale=plan.scale, x=plan.x, y=plan.y,
      logicalW=logicalW, logicalH=logicalH,
    }
    return plan
  end

  -- Full-screen content owns the complete notch-safe viewport. Touch controls
  -- are a transparent input/HUD overlay, not layout chrome: subtracting their
  -- hit rectangles reduced a 832x420 iPhone landscape surface to a 472x325
  -- centre island. Keep their geometry for diagnostics, but deliberately let
  -- them overlay the presentation just as they overlay the world view.
  -- All coordinates remain LÖVE window units; framebuffer pixels/DPI are
  -- receipt-only and can never distort this calculation.
  local usable = copyRect(safe)
  local touchRectsUsed, touchReserved, gutter = {}, false, 0
  if opts.touchVisible == true then
    touchRectsUsed, gutter = touchRects(safe, opts.touch)
    touchReserved = #touchRectsUsed > 0
  end
  local scale = math.min(usable.w / logicalW, usable.h / logicalH)
  scale = math.max(.01, scale)
  local width, height = logicalW * scale, logicalH * scale
  local x = usable.x + (usable.w - width) * .5
  local y = usable.y + (usable.h - height) * .5
  local plan = {
    active=true,
    reason=touchReserved and "mobile-safe-touch-overlay" or "mobile-safe",
    owner=owner, logicalW=logicalW, logicalH=logicalH,
    scale=scale, x=x, y=y, w=width, h=height,
    window=window, safe=safe, usable=usable,
    touch=opts.touch, touchVisible=opts.touchVisible == true,
  }
  local overlapCount = 0
  local presentation = { x=x, y=y, w=width, h=height }
  for _, control in ipairs(touchRectsUsed) do
    if intersects(presentation, control) then overlapCount = overlapCount + 1 end
  end
  plan.receipt = {
    schema=M.VIEWPORT_SCHEMA,
    revision=tonumber(opts.viewportRevision),
    owner=owner, platform=tostring(opts.platform or "unknown"), active=true,
    orientation=tostring(opts.orientation or "unknown"),
    window=copyRect(window), safe=copyRect(safe), usable=copyRect(usable),
    pixelWidth=tonumber(opts.pixelWidth), pixelHeight=tonumber(opts.pixelHeight),
    dpiX=tonumber(opts.dpiX), dpiY=tonumber(opts.dpiY),
    touchVisible=opts.touchVisible == true, touchRects=touchRectsUsed,
    touchGutter=gutter, touchOverlapCount=overlapCount,
    touchLayoutPolicy=touchReserved and "overlay-active-controls"
      or opts.touchVisible == true and "no-control-geometry" or "inactive",
    coordinateSpace="love-window-units", framebufferDiagnosticOnly=true,
    scale=scale, x=x, y=y,
    width=width, height=height, logicalW=logicalW, logicalH=logicalH,
  }
  return plan
end

local function runtimePlatform()
  local nativeOS
  local loveApi = runtimeLove()
  local system = runtimeMember(loveApi, "system")
  local getOS = runtimeMember(system, "getOS")
  if type(getOS) == "function" then
    local ok, value = pcall(getOS)
    if ok and type(value) == "string" and value ~= "" then
      nativeOS = value
      if value == "iOS" or value == "Android" then return value end
    end
  end
  local bootstrapOS = runtimeMember(loveApi, "_os")
  if bootstrapOS == "iOS" or bootstrapOS == "Android" then
    return bootstrapOS
  end
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  if okPlatform and type(Platform) == "table"
      and type(Platform.detect) == "function" then
    local okInfo, info = pcall(Platform.detect)
    if okInfo and type(info) == "table" and type(info.os) == "string" then
      return info.os
    end
  end
  if type(bootstrapOS) == "string" and bootstrapOS ~= "" then
    return bootstrapOS
  end
  return nativeOS or "unknown"
end

-- Side-effect-free platform predicate for presentation callers. In
-- particular it does not read SafeArea, TouchControls, TouchSkin geometry or
-- pixel metrics, so Desktop renderers can reject the mobile branch before
-- touching any of those runtime services.
function M.isMobileRuntime()
  return mobileRuntime(runtimePlatform(), forcedTouch())
end

local function runtimeWindow(winW, winH)
  local graphics = runtimeMember(runtimeLove(), "graphics")
  -- drawPhysical() resets the transform with graphics.origin(), therefore its
  -- coordinates are always the complete LÖVE window.  Newer mobile engines
  -- pass render.hud a smaller emulation/GameViewport receipt; trusting that
  -- rectangle produced the left two-thirds menus and a floating START panel
  -- seen on real iPhones.  The hook dimensions remain a fallback for older
  -- engines/headless tests only.
  local hookW, hookH = tonumber(winW), tonumber(winH)
  if graphics and type(graphics.getDimensions) == "function" then
    local ok, width, height = pcall(graphics.getDimensions)
    if ok then winW, winH = tonumber(width), tonumber(height) end
  end
  if not (winW and winH and winW > 0 and winH > 0) then
    winW, winH = hookW, hookH
  end
  return { x=0, y=0, w=positive(winW, 1), h=positive(winH, 1) }
end

local function runtimeSafe(window)
  -- graphics.origin() also makes SafeArea.rect()'s window-space contract the
  -- matching one.  Do not convert it through an emulation viewport.
  if type(SafeArea) == "table" and type(SafeArea.rect) == "function" then
    local ok, x, y, w, h = pcall(SafeArea.rect)
    if ok then return clampRect({x=x,y=y,w=w,h=h}, window) end
  end
  return copyRect(window)
end

local function runtimeSkinControls()
  if type(TouchSkin) ~= "table" or TouchSkin.active == nil
      or type(TouchSkin.page) ~= "function"
      or type(TouchSkin.controlGeometry) ~= "function" then
    return nil
  end
  local okPage, page = pcall(TouchSkin.page)
  if not okPage or type(page) ~= "table"
      or type(page.controls) ~= "table" then return nil end
  local width, height, originX, originY
  if type(TouchControls) == "table"
      and type(TouchControls.surfaceRect) == "function" then
    local ok, w, h, x, y = pcall(TouchControls.surfaceRect)
    if ok then width, height, originX, originY = w, h, x, y end
  end
  local graphics = runtimeMember(runtimeLove(), "graphics")
  if not (positive(width) and positive(height))
      and graphics and type(graphics.getDimensions) == "function" then
    local ok, w, h = pcall(graphics.getDimensions)
    if ok then width, height = w, h end
  end
  width, height = positive(width, 1), positive(height, 1)
  originX, originY = tonumber(originX) or 0, tonumber(originY) or 0
  local controls = {}
  for index, control in ipairs(page.controls) do
    if type(control) == "table" and control.decorative ~= true then
      local ok, cx, cy, halfW, halfH = pcall(TouchSkin.controlGeometry,
        page, control, width, height, originX, originY)
      if ok and finite(cx) and finite(cy)
          and positive(halfW) and positive(halfH) then
        local mod = positive(control.rangeMod, 1)
        local left = halfW * positive(control.reachLeft, 1) * mod
        local right = halfW * positive(control.reachRight, 1) * mod
        local up = halfH * positive(control.reachUp, 1) * mod
        local down = halfH * positive(control.reachDown, 1) * mod
        controls["skin:" .. tostring(index)] = {
          rect={x=cx-left, y=cy-up, w=left+right, h=up+down},
          source="TouchSkin", spec=control.spec,
        }
      end
    end
  end
  return next(controls) and controls or nil
end

local function runtimeTouch()
  if type(TouchControls) ~= "table" then return false, nil end
  local visible = false
  if type(TouchControls.visible) == "function" then
    local ok, value = pcall(TouchControls.visible, TouchControls)
    visible = ok and value == true
  end
  if not visible then
    return visible, nil
  end
  local custom = runtimeSkinControls()
  if custom then return true, custom end
  if type(TouchControls.layout) ~= "function" then return true, nil end
  local ok, layout = pcall(TouchControls.layout, TouchControls)
  return visible, ok and layout or nil
end

local function pixelMetrics(window)
  local graphics = runtimeMember(runtimeLove(), "graphics")
  local pw, ph = window.w, window.h
  if graphics and type(graphics.getPixelDimensions) == "function" then
    local ok, width, height = pcall(graphics.getPixelDimensions)
    if ok then pw, ph = positive(width, pw), positive(height, ph) end
  end
  return pw, ph, pw / window.w, ph / window.h
end

local function runtimeOrientation(window)
  local loveApi = runtimeLove()
  local windowApi = runtimeMember(loveApi, "window")
  if type(windowApi) == "table"
      and type(windowApi.getDisplayOrientation) == "function" then
    local ok, value = pcall(windowApi.getDisplayOrientation)
    if ok and type(value) == "string" and value ~= ""
        and value:lower() ~= "unknown" then return value:lower(), "love.window" end
  end
  return window.w >= window.h and "landscape" or "portrait", "geometry"
end

local function rectSignature(rect)
  rect = type(rect) == "table" and rect or {}
  return table.concat({ tostring(rect.x), tostring(rect.y),
    tostring(rect.w), tostring(rect.h) }, ",")
end

local function receiptSignature(receipt)
  local controls = {}
  for _, rect in ipairs(type(receipt.touchRects) == "table"
      and receipt.touchRects or {}) do
    controls[#controls + 1] = rectSignature(rect)
  end
  table.sort(controls)
  return table.concat({ tostring(receipt.platform),
    tostring(receipt.orientation), rectSignature(receipt.window),
    rectSignature(receipt.safe),
    tostring(receipt.pixelWidth), tostring(receipt.pixelHeight),
    tostring(receipt.dpiX), tostring(receipt.dpiY),
    tostring(receipt.touchVisible), receipt.touchLayoutPolicy or "",
    table.concat(controls, ";") }, "|")
end

local function orientationMatchesGeometry(orientation, window)
  orientation = tostring(orientation or ""):lower()
  if orientation:find("portrait", 1, true) then return window.h >= window.w end
  if orientation:find("landscape", 1, true) then return window.w >= window.h end
  return nil
end

function M.runtimePlan(owner, logicalW, logicalH, winW, winH)
  local platform, touchForced = runtimePlatform(), forcedTouch()
  local window = runtimeWindow(winW, winH)
  -- Desktop is a strict legacy lane: do not query SafeArea, touch layout,
  -- framebuffer metrics or orientation and do not mutate mobile revisions.
  local mobile = mobileRuntime(platform, touchForced)
  if not mobile then
    return M.planFor({ owner=owner, platform=platform, forcedTouch=false,
      window=window, safe=window, logicalW=logicalW, logicalH=logicalH })
  end
  local safe = runtimeSafe(window)
  local visible, touch = runtimeTouch()
  local pw, ph, dpiX, dpiY = pixelMetrics(window)
  local orientation, orientationSource = runtimeOrientation(window)
  local plan = M.planFor({
    owner=owner, platform=platform, forcedTouch=mobile,
    window=window, safe=safe, touchVisible=visible, touch=touch,
    logicalW=logicalW, logicalH=logicalH,
    pixelWidth=pw, pixelHeight=ph, dpiX=dpiX, dpiY=dpiY,
    orientation=orientation,
  })
  local signature = receiptSignature(plan.receipt)
  local changed = signature ~= viewportSignature
  if changed then
    M.viewportRevision = M.viewportRevision + 1
    viewportSignature = signature
  end
  local receipt = plan.receipt
  receipt.revision = M.viewportRevision
  receipt.orientationSource = orientationSource
  receipt.orientationGeometryOk = orientationMatchesGeometry(
    orientation, window)
  receipt.changed = changed
  M.viewportReceipt = receipt
  if changed then
    diagnostic("mobile-viewport-revision", {
      status=receipt.orientationGeometryOk == false and "stale" or "ready",
      revision=receipt.revision, platform=receipt.platform,
      orientation=receipt.orientation, source=receipt.orientationSource,
      windowWidth=window.w, windowHeight=window.h,
      safeX=safe.x, safeY=safe.y, safeWidth=safe.w, safeHeight=safe.h,
      usableX=receipt.usable.x, usableY=receipt.usable.y,
      usableWidth=receipt.usable.w, usableHeight=receipt.usable.h,
      pixelWidth=pw, pixelHeight=ph, dpiX=dpiX, dpiY=dpiY,
      touchVisible=visible, touchOverlapCount=receipt.touchOverlapCount,
      touchLayoutPolicy=receipt.touchLayoutPolicy,
    })
  end
  return plan
end

function M.viewportStatus()
  return M.viewportReceipt
end

local function topState(game)
  local stack = game and game.stack
  if type(stack) ~= "table" then return nil end
  if type(stack.top) == "function" then
    local ok, state = pcall(stack.top, stack)
    if ok then return state end
  end
  local states = stack.states
  return type(states) == "table" and states[#states] or nil
end

local function configEnabled(state, config)
  if type(state) == "table" and state.__vascMobilePresentationFailed then
    return false
  end
  if not config or config.enabled == nil then return true end
  if type(config.enabled) ~= "function" then return config.enabled == true end
  local ok, value = pcall(config.enabled, state)
  return ok and value == true
end

local TRANSIENT_IDS = {
  TextBox=true, ChoiceBox=true, QuantityBox=true, Menu=true,
}
local TRANSIENT_MARKERS = {
  "__usefulBagHelp", "__kascBagHelp", "__ascendantBagActions",
  "__ascendantFireRedPcAccessPrompt", "__kascFeatureHelp", "__itemHelp",
}

local function classInstance(state, class)
  if type(state) ~= "table" or type(class) ~= "table" then return false end
  local mt = getmetatable(state)
  return mt == class or (type(mt) == "table" and rawget(mt, "__index") == class)
end

local function transientOverlay(state)
  if type(state) ~= "table" or state.isOpaque == true then return false end
  -- ASC BOX deliberately upgrades its genuine TextBox/ChoiceBox overlays to
  -- wide draw methods. Their identity remains transient; testing the wide
  -- flag first incorrectly relinquished the Party owner during field moves,
  -- item targeting and confirmation prompts.
  if TRANSIENT_IDS[tostring(state.screenId or state.id or "")] then return true end
  for _, key in ipairs(TRANSIENT_MARKERS) do
    if state[key] then return true end
  end
  for _, class in ipairs(TransientClasses) do
    if classInstance(state, class) then return true end
  end
  -- Unknown wide surfaces are full-screen children, not modals. They must
  -- take ownership themselves or fall back to their native render path.
  if state.drawsWidescreen == true
      or type(rawget(state, "drawWidescreen") or state.drawWidescreen) == "function" then
    return false
  end
  return false
end

local function ownerInStack(game)
  local stack = game and game.stack
  local states = type(stack) == "table" and stack.states or nil
  if type(states) ~= "table" then return nil, nil end
  for index = #states, 1, -1 do
    local state = states[index]
    local config = configs[state]
    if config and configEnabled(state, config) then
      local ownsSlice = true
      for above = index + 1, #states do
        if not transientOverlay(states[above]) then ownsSlice = false break end
      end
      if ownsSlice then return state, index end
    end
  end
  return nil, nil
end

local function stateIndex(game, wanted)
  local stack = game and game.stack
  local states = type(stack) == "table" and stack.states or nil
  if type(states) ~= "table" then return nil end
  for index = 1, #states do
    if states[index] == wanted then return index end
  end
end

-- Read-only receipt/test seam: returns the decorated presentation owner that
-- remains underneath a transient native Menu/TextBox/ChoiceBox.  It does not
-- change stack input/update ownership.
function M.presentationOwner(game)
  return ownerInStack(game)
end

-- Read-only QA receipt for a concrete screen. This intentionally exposes no
-- mutable config fields or callbacks; it lets device diagnostics distinguish
-- "not attached" from an attached provider whose live option disabled the
-- presentation before render.hud.
function M.attachmentStatus(state)
  local config = type(state) == "table" and configs[state] or nil
  local predicateOk, predicateValue = true, nil
  if config and type(config.enabled) == "function" then
    predicateOk, predicateValue = pcall(config.enabled, state)
  elseif config then
    predicateValue = config.enabled
  end
  return {
    attached=config ~= nil,
    owner=config and config.owner or nil,
    enabled=config and configEnabled(state, config) or false,
    predicateOk=predicateOk,
    predicateValue=predicateValue,
    failed=type(state) == "table" and
      state.__vascMobilePresentationFailed == true or false,
  }
end

function M.isTopOwner(state, game)
  return type(state) == "table" and topState(game or state.game) == state
end

local function activeFor(state)
  -- Platform must be the first gate: desktop must not even evaluate a
  -- state-owned enabled predicate (some menu predicates normalize mutable
  -- skin state). This keeps the frozen native draw count/side effects exact.
  if not mobileRuntime(runtimePlatform(), forcedTouch()) then return false end
  if type(state) ~= "table" or not M.hudHook or state.__vascMobileHudDrawing then
    return false
  end
  local owner = ownerInStack(state.game)
  if owner ~= state then return false end
  return configEnabled(state, configs[state])
end

local function inputEdge(input)
  if type(input) ~= "table" or type(input.wasPressed) ~= "function" then
    return nil
  end
  for _, key in ipairs({ "right", "left" }) do
    local ok, value = pcall(input.wasPressed, input, key)
    if ok and value then return key end
  end
  return nil
end

local function inputSource(input, key)
  if type(input) ~= "table" or not key then return "unknown" end
  local sources = type(input.sources) == "table" and input.sources[key]
  if type(sources) == "table" then
    for rawSource in pairs(sources) do
      local source = tostring(rawSource)
      if source:match("^touch:") then return "overlay" end
      if source:match("^pad:") or source:match("^joy:") then return "gamepad" end
      if source:match("^key:") then return "keyboard" end
      if source:match("^mod:") then return "mod" end
    end
  end
  if type(TouchControls) == "table" and type(TouchControls.held) == "table"
      and TouchControls.held[key] then return "overlay" end
  return "physical"
end

-- Mobile-only observability around the authoritative bag implementation. Both
-- reviewed providers (Useful Bag and KASC 6.7.1) consume the overlay's native
-- left/right edges themselves. This wrapper therefore never invents a second
-- alias or mutates Input; it samples before/after exactly one native update.
function M.instrumentPocketUpdate(state, nativeUpdate, opts)
  opts = type(opts) == "table" and opts or {}
  if type(nativeUpdate) ~= "function" then return nativeUpdate end
  local pocketIndex = type(opts.pocketIndex) == "function"
    and opts.pocketIndex or function(owner)
      return tonumber(rawget(owner, "__pocketIndex")
        or rawget(owner, "pocketIndex")) or 1
    end
  return function(self, ...)
    local forced = opts.forcedTouch
    if forced == nil then forced = forcedTouch() end
    if not mobileRuntime(runtimePlatform(), forced) then
      return nativeUpdate(self, ...)
    end
    local args = packed(...)
    local input = self.game and self.game.input
    local edge = inputEdge(input)
    local before = pocketIndex(self)
    local source = type(opts.inputSource) == "function"
      and opts.inputSource(self, edge) or inputSource(input, edge)
    local ok, returned = xpcall(function()
      return packed(nativeUpdate(self, unpackValues(args, 1, args.n)))
    end, function(message)
      return debug and type(debug.traceback) == "function"
        and debug.traceback(tostring(message), 2) or tostring(message)
    end)
    if not ok then error(returned, 0) end
    local after = pocketIndex(self)
    local receipt = type(self.__vascMobileMenuReceipt) == "table"
      and self.__vascMobileMenuReceipt or {}
    receipt.owner = opts.owner or receipt.owner or "bag"
    receipt.input = edge
    receipt.inputSource = source
    receipt.inputAlias = nil
    receipt.pocketBefore = before
    receipt.pocketAfter = after
    receipt.pocketChanged = before ~= after
    self.__vascMobileMenuReceipt = receipt
    if edge or before ~= after then
      diagnostic("mobile-menu-pocket", {
        owner=receipt.owner, input=edge or "none", inputSource=source,
        inputAlias="none", pocketBefore=before, pocketAfter=after,
      })
    end
    return unpackValues(returned, 1, returned.n)
  end
end

local function resolveLogical(state, config)
  if type(config.logicalSize) == "function" then
    local ok, width, height = pcall(config.logicalSize, state)
    if ok and positive(width) and positive(height) then return width, height end
  end
  return positive(config.logicalW, 512), positive(config.logicalH, 288)
end

-- Convert a window-space pointer back into the exact logical space used
-- by drawPhysical. Desktop is a hard pass-through and never enters the mobile
-- planner; unattached/failed owners also fail open to the existing coordinates.
function M.pointerToLogical(state, x, y)
  local physicalX, physicalY = tonumber(x), tonumber(y)
  if not finite(physicalX) or not finite(physicalY) then return x, y, false end
  if not mobileRuntime(runtimePlatform(), forcedTouch()) then
    return physicalX, physicalY, false
  end
  local config = type(state) == "table" and configs[state] or nil
  if not config or not configEnabled(state, config) then
    return physicalX, physicalY, false
  end
  local logicalW, logicalH = resolveLogical(state, config)
  local plan = M.runtimePlan(config.owner, logicalW, logicalH)
  local scale = plan and tonumber(plan.scale)
  local planX, planY = plan and tonumber(plan.x), plan and tonumber(plan.y)
  if not plan or plan.active ~= true or not finite(scale) or scale <= 0
      or not finite(planX) or not finite(planY) then
    return physicalX, physicalY, false
  end
  return (physicalX - planX) / scale, (physicalY - planY) / scale, true, plan
end

local function fillBackdrop(graphics, config, state, plan)
  if config.backdrop == false then return false end
  if type(config.backdrop) == "function" then
    return config.backdrop(state, plan)
  end
  local color = type(config.backdrop) == "table" and config.backdrop
    or { .025, .045, .085, 1 }
  graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0,
    color[4] == nil and 1 or color[4])
  graphics.rectangle("fill", plan.window.x, plan.window.y,
    plan.window.w, plan.window.h)
end

local function restoreCanvas(graphics, canvas)
  if canvas ~= nil then graphics.setCanvas(canvas) else graphics.setCanvas() end
end

local function stagedLayer(graphics, key, width, height, density)
  if type(key) ~= "table" then return nil, "mobile logical owner unavailable" end
  if not (type(graphics.newCanvas) == "function"
      and type(graphics.getCanvas) == "function"
      and type(graphics.setCanvas) == "function"
      and type(graphics.clear) == "function"
      and type(graphics.draw) == "function") then
    return nil, "mobile logical Canvas unavailable"
  end
  local layer = stagedLayers[key]
  if stagedDensities[key] ~= density then layer = nil end
  if layer and type(layer.getDimensions) == "function" then
    local ok, currentW, currentH = pcall(layer.getDimensions, layer)
    if not ok or currentW ~= width or currentH ~= height then layer = nil end
  else
    layer = nil
  end
  if not layer then
    local ok, created = pcall(graphics.newCanvas, width, height, { dpiscale=density })
    if not ok or not created then
      return nil, tostring(created or "mobile logical Canvas allocation failed")
    end
    layer = created
    stagedLayers[key] = layer
    stagedDensities[key] = density
    if type(layer.setFilter) == "function" then
      pcall(layer.setFilter, layer, "nearest", "nearest")
    end
  end
  return layer
end

-- Render a complete logical screen before applying the device transform.
-- This is intentionally public so the Gen-1 START presenter can use the same
-- atomic contract even though it is not an ordinary stack-owned menu.
function M.presentLogical(state, plan, callback, config)
  config = type(config) == "table" and config or {}
  local graphics = runtimeMember(runtimeLove(), "graphics")
  if not (graphics and type(graphics.push) == "function"
      and type(graphics.pop) == "function" and type(graphics.origin) == "function"
      and type(graphics.translate) == "function" and type(graphics.scale) == "function"
      and type(graphics.rectangle) == "function" and type(callback) == "function") then
    return false, "mobile staged presenter unavailable"
  end
  if type(plan) ~= "table" or plan.active ~= true then
    return false, "mobile staged plan unavailable"
  end
  local width, height = positive(plan.logicalW, 512), positive(plan.logicalH, 288)
  -- Opt-in for the Gen1 post-title artwork only. Keep the logical coordinate
  -- system and final transform identical, but do not reduce HD sprites to
  -- 26/34 pixels before enlarging them for the phone. Other menus retain
  -- their reviewed one-pixel logical Canvas. Bound allocation on large displays.
  local density = 1
  if config.displayDensity == true then
    local receipt = plan.receipt or {}
    local dpi = math.max(positive(receipt.dpiX, 1), positive(receipt.dpiY, 1))
    density = math.max(1, math.min(6, math.ceil(positive(plan.scale, 1) * dpi)))
  end
  local layer, layerError = stagedLayer(graphics,
    type(config.cacheKey) == "table" and config.cacheKey or state, width, height, density)
  if not layer then return false, layerError end
  local okCanvas, previousCanvas = pcall(graphics.getCanvas)
  if not okCanvas then return false, tostring(previousCanvas) end

  local pushed, returned = false, nil
  local ok, err = xpcall(function()
    graphics.push("all")
    pushed = true
    graphics.setCanvas(layer)
    graphics.origin()
    if type(graphics.setShader) == "function" then graphics.setShader() end
    if type(graphics.setScissor) == "function" then graphics.setScissor() end
    if type(graphics.setBlendMode) == "function" then
      local blendOk = pcall(graphics.setBlendMode, "alpha", "alphamultiply")
      if not blendOk then graphics.setBlendMode("alpha") end
    end
    graphics.clear(0, 0, 0, 0)
    returned = packed(callback())
    if returned[1] == false then error("mobile logical renderer declined", 0) end
    graphics.pop()
    pushed = false
    restoreCanvas(graphics, previousCanvas)

    graphics.push("all")
    pushed = true
    graphics.origin()
    if type(graphics.setShader) == "function" then graphics.setShader() end
    if type(graphics.setScissor) == "function" then graphics.setScissor() end
    if type(graphics.setBlendMode) == "function" then
      local blendOk = pcall(graphics.setBlendMode, "alpha", "alphamultiply")
      if not blendOk then graphics.setBlendMode("alpha") end
    end
    fillBackdrop(graphics, config, state, plan)
    graphics.translate(plan.x, plan.y)
    graphics.scale(plan.scale, plan.scale)
    if type(graphics.setColor) == "function" then graphics.setColor(1, 1, 1, 1) end
    graphics.draw(layer, 0, 0)
    graphics.pop()
    pushed = false
  end, function(message)
    return debug and type(debug.traceback) == "function"
      and debug.traceback(tostring(message), 2) or tostring(message)
  end)
  if pushed then pcall(graphics.pop) end
  pcall(restoreCanvas, graphics, previousCanvas)
  if not ok then return false, err end
  return true, unpackValues(returned, 1, returned.n)
end

local function stateUiSize(state)
  if type(state) == "table" and type(state.uiSize) == "function" then
    local ok, width, height = pcall(state.uiSize, state)
    if ok and positive(width) and positive(height) then return width, height end
  end
  return 160, 144
end

function M.modalPlan(logicalW, logicalH, modalW, modalH)
  logicalW, logicalH = positive(logicalW, 512), positive(logicalH, 288)
  modalW, modalH = positive(modalW, 160), positive(modalH, 144)
  local scale = math.min(logicalW / modalW, logicalH / modalH)
  if scale >= 1 then scale = math.max(1, math.floor(scale)) end
  return {
    logicalW=modalW, logicalH=modalH, scale=scale,
    x=math.floor((logicalW - modalW * scale) / 2),
    y=math.floor((logicalH - modalH * scale) / 2),
  }
end

local function drawModalStack(owner, ownerIndex, logicalW, logicalH)
  local game = owner and owner.game
  local stack = game and game.stack
  local states = type(stack) == "table" and stack.states or nil
  if type(states) ~= "table" then return end
  local graphics = love.graphics
  local drawn = 0
  for index = ownerIndex + 1, #states do
    local state = states[index]
    local visible = true
    if type(stack.renderVisible) == "function" then
      local ok, value = pcall(stack.renderVisible, stack, state)
      if ok then visible = value == true end
    end
    local drawer = state and (rawget(state, "__vascMobileMenuNativeDraw")
      or rawget(state, "draw") or state.draw) or nil
    if visible and type(drawer) == "function" then
      local width, height = stateUiSize(state)
      local modal = M.modalPlan(logicalW, logicalH, width, height)
      graphics.push("all")
      graphics.translate(modal.x, modal.y)
      graphics.scale(modal.scale, modal.scale)
      local oldDrawing = state.__vascMobileHudDrawing
      state.__vascMobileHudDrawing = true
      local ok, err = pcall(drawer, state)
      state.__vascMobileHudDrawing = oldDrawing
      graphics.pop()
      if not ok then error(err, 0) end
      drawn = drawn + 1
    end
  end
  return drawn
end

local function drawPhysical(state, ownerIndex, config, viewport)
  local graphics = runtimeMember(runtimeLove(), "graphics")
  if not (graphics and type(graphics.push) == "function"
      and type(graphics.pop) == "function" and type(graphics.translate) == "function"
      and type(graphics.scale) == "function" and type(graphics.rectangle) == "function") then
    return false, "mobile HUD graphics unavailable"
  end
  local logicalW, logicalH = resolveLogical(state, config)
  local plan = M.runtimePlan(config.owner, logicalW, logicalH,
    viewport and viewport.width, viewport and viewport.height)
  if not plan.active then return false, "desktop native path" end
  local oldDrawing = state.__vascMobileHudDrawing
  local ok, err = M.presentLogical(state, plan, function()
    state.__vascMobileHudDrawing = true
    if type(config.drawLogical) == "function" then
      -- `nil` is the normal success return for several render-only adapters.
      -- An explicit false, however, is their contract for a controlled
      -- provider decline. Treat it like a render failure so the next frame
      -- releases this owner and executes the captured native path.
      if config.drawLogical(state, plan) == false then
        error("mobile logical renderer declined", 0)
      end
    elseif type(config.nativeDraw) == "function" then
      config.nativeDraw(state)
    end
    state.__vascMobileModalDrawCount = drawModalStack(
      state, ownerIndex, logicalW, logicalH)
  end, config)
  state.__vascMobileHudDrawing = oldDrawing
  if not ok then return false, err end
  local receipt = plan.receipt
  receipt.screenOwner = config.owner
  receipt.screenId = tostring(state.screenId or state.id or state.__name or "menu")
  receipt.nativeOwnerSuppressed = M.visibilityHook == true
  receipt.modalDrawCount = tonumber(state.__vascMobileModalDrawCount) or 0
  state.__vascMobileMenuReceipt = receipt
  return true
end

local function installHudHook()
  if M.hudHook then return true end
  local hooks = V and V.mod and V.mod.hooks
  if not (hooks and type(hooks.wrap) == "function") then
    return false, "render.hud hook unavailable"
  end
  hooks:wrap("render.hud", function(next, game, viewport)
    local out = next(game, viewport)
    if not mobileRuntime(runtimePlatform(), forcedTouch()) then return out end
    local state, ownerIndex = ownerInStack(game)
    local config = configs[state]
    if not config or not configEnabled(state, config) then
      return out
    end
    local ok, reason = drawPhysical(state, ownerIndex, config, viewport)
    if ok then
      M.lastError = nil
    else
      M.lastError = tostring(reason)
      state.__vascMobileMenuError = M.lastError
      -- Fail closed after the first presentation error. On the next native
      -- pass configEnabled is false, the captured draw/update paths run
      -- unchanged, and no state remains suppressed by this module.
      state.__vascMobilePresentationFailed = true
      diagnostic("mobile-menu-render-error", {
        owner=config.owner, reason=M.lastError,
      })
    end
    return out
  end, 15160)
  M.hudHook = true
  hooks:wrap("screen.render_visible", function(next, state)
    local visible = next(state)
    if visible == false or type(state) ~= "table" then return visible end
    if not mobileRuntime(runtimePlatform(), forcedTouch()) then
      return visible
    end
    local owner, ownerIndex = ownerInStack(state.game)
    if not owner or owner.__vascMobileHudDrawing then return visible end
    local index = stateIndex(state.game, state)
    -- The final HUD pass redraws the configured owner and every transient
    -- state above it exactly once in the same transform. Suppress precisely
    -- that contiguous slice during StateStack's native pass; lower world or
    -- battle states remain untouched. During drawModalStack the owner's HUD
    -- flag is set, so this hook delegates to the rest of the visibility chain.
    -- The opaque owner itself must stay visible to StateStack.visibleBase so
    -- the world/battle below it remains culled. Its attached draw method is
    -- already a mobile no-op. Only the transient overlays are suppressed and
    -- redrawn in the final HUD transform.
    if index and ownerIndex and index > ownerIndex then return false end
    return visible
  end, 15161)
  M.visibilityHook = true
  return true
end

function M.attach(state, opts)
  if type(state) ~= "table" then return state, false, "not a state" end
  opts = type(opts) == "table" and opts or {}
  if not mobileRuntime(runtimePlatform(), opts.forcedTouch) then
    return state, false, "desktop-native-path"
  end
  if configs[state] then return state, true, configs[state].owner end
  local nativeDraw = rawget(state, "draw") or state.draw
  local nativeWide = rawget(state, "drawWidescreen") or state.drawWidescreen
  if type(nativeDraw) ~= "function" and type(opts.drawLogical) ~= "function" then
    return state, false, "draw unavailable"
  end
  local okHook, reason = installHudHook()
  if not okHook then return state, false, reason end
  local config = {
    owner=tostring(opts.owner or "menu"),
    logicalW=positive(opts.logicalW, 512), logicalH=positive(opts.logicalH, 288),
    logicalSize=opts.logicalSize, backdrop=opts.backdrop,
    enabled=opts.enabled,
    displayDensity=opts.displayDensity == true,
    drawLogical=opts.drawLogical, nativeDraw=nativeDraw, nativeWide=nativeWide,
  }
  configs[state] = config
  state.__vascMobileMenuOwner = config.owner
  state.__vascMobileMenuNativeDraw = nativeDraw
  state.__vascMobileMenuNativeWide = nativeWide
  if type(nativeDraw) == "function" then
    state.draw = function(self, ...)
      if activeFor(self) then return end
      return nativeDraw(self, ...)
    end
  end
  if type(nativeWide) == "function" then
    state.drawWidescreen = function(self, ...)
      if activeFor(self) then return end
      return nativeWide(self, ...)
    end
  end
  M.attached = M.attached + 1
  diagnostic("mobile-menu-attached", { owner=config.owner, count=M.attached })
  return state, true, config.owner
end

function M.usableRect(winW, winH, owner, logicalW, logicalH)
  local plan = M.runtimePlan(owner or "menu",
    positive(logicalW, 512), positive(logicalH, 288), winW, winH)
  return plan.usable.x, plan.usable.y, plan.usable.w, plan.usable.h, plan
end

return M
