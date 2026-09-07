-- Pokémon Essentials battle-animation programs, adapted to Gen1Recomp's
-- 160x144 battle field. This is a decorator around the native AnimPlayer:
-- balls, catches, unsupported moves and native screen effects remain wholly
-- native, while reviewed VASC move programs draw their supplied 192px cells.

local V = ...
local VascBattleAnimPlayer = {}

local CELL = 192
local ESSENTIALS_W, ESSENTIALS_H = 512, 384
local USER_X, USER_Y = 128, 224
local TARGET_X, TARGET_Y = 384, 96
local GB_W, GB_H = 160, 144
local CELL_SCALE = GB_W / ESSENTIALS_W
local TICKS_PER_FRAME = 3 -- Essentials animations advance at 20fps.

local PLAYER_ANCHOR = { 26, 96 }
local ENEMY_ANCHOR = { 124, 56 }
local frameAnchors = nil

local Player = {}
Player.__index = Player

local COLOR_SHADER = [[
  uniform number hueShift;
  uniform vec4 overlayColor;
  uniform vec4 toneAdjust;

  vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -0.3333333333, 0.6666666667, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    number d = q.x - min(q.w, q.y);
    number e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e), q.x);
  }

  vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 0.6666666667, 0.3333333333))
                 * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
  }

  vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
    vec4 px = Texel(texture, tc);
    if (px.a <= 0.0) return px;
    if (abs(hueShift) > 0.0001) {
      vec3 hsv = rgb2hsv(px.rgb);
      hsv.x = fract(hsv.x + hueShift);
      px.rgb = hsv2rgb(hsv);
    }
    px.rgb = clamp(px.rgb + toneAdjust.rgb, 0.0, 1.0);
    number gray = dot(px.rgb, vec3(0.299, 0.587, 0.114));
    px.rgb = mix(px.rgb, vec3(gray), clamp(toneAdjust.a, 0.0, 1.0));
    px.rgb = mix(px.rgb, overlayColor.rgb, overlayColor.a);
    return px * color;
  }
]]

local shader -- nil=untried, false=unavailable

local function colorShader()
  if shader == nil then
    local g = love and love.graphics
    local ok, made = false, nil
    if g and type(g.newShader) == "function" then
      ok, made = pcall(g.newShader, COLOR_SHADER)
    end
    shader = ok and made or false
  end
  return shader or nil
end

local function finite(value, fallback)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge
      or value == -math.huge then return fallback end
  return value
end

local function anchors(attackerIsPlayer)
  local player = frameAnchors and frameAnchors.player
  local enemy = frameAnchors and frameAnchors.enemy
  if player and enemy then
    if attackerIsPlayer then
      return player.emitter or player.body, enemy.body or enemy.emitter
    end
    return enemy.emitter or enemy.body, player.body or player.emitter
  end
  if attackerIsPlayer then return PLAYER_ANCHOR, ENEMY_ANCHOR end
  return ENEMY_ANCHOR, PLAYER_ANCHOR
end

-- The staged Kanto renderer knows the exact alpha hull of both live cards.
-- It publishes those two screen-space profiles only while drawAnimLayer is
-- running.  Keeping the context frame-local prevents a map change, switch or
-- hot reload from leaking yesterday's Charizard mouth into the next battle.
function VascBattleAnimPlayer.setFrameAnchors(value)
  frameAnchors = type(value) == "table" and value or nil
end

function VascBattleAnimPlayer.clearFrameAnchors()
  frameAnchors = nil
end

function VascBattleAnimPlayer.frameAnchorStatus()
  return frameAnchors
end

-- Preserve Essentials' focus semantics while fitting its 512x384 editor
-- coordinates onto Gen1's battle field. Focus 3 is the important projectile
-- path: it maps the authored user->target axis directly onto the live side
-- order, so an attack can never originate at the wrong Pokémon.
function VascBattleAnimPlayer.mapPoint(cel, attackerIsPlayer, targetMode)
  local user, target = anchors(attackerIsPlayer)
  local x = finite(cel and cel.x, 0)
  local y = finite(cel and cel.y, 0)
  local focus = finite(cel and cel.f, 4)
  if focus == 1 or focus == 2 or focus == 3 then
    -- Focus selects endpoint ownership/timing, but focused cel coordinates all
    -- live in the same authored user->target plane. Mapping f=1/f=2 as two
    -- unrelated translations made travelling effects originate at Gen-1
    -- feet. Project the full plane onto Kanto's live actor axis. Johto keeps
    -- the same resolver contract in its own independent package file.
    local ax, ay = TARGET_X - USER_X, TARGET_Y - USER_Y
    local alen2 = ax * ax + ay * ay
    local rx, ry = x - USER_X, y - USER_Y
    local along = (rx * ax + ry * ay) / alen2
    local across = (rx * -ay + ry * ax) / alen2
    local dx, dy = target[1] - user[1], target[2] - user[2]
    local mappedX = user[1] + along * dx + across * -dy
    local mappedY = user[2] + along * dy + across * dx
    if targetMode == "self" then
      -- Focus 1 is authored around the target endpoint. Move that complete
      -- local cluster onto the live user's body without collapsing its shape.
      -- Focus 2 already belongs to the user. Focus 3 keeps its path shape but
      -- progressively folds the opponent endpoint back onto the user.
      local _, userBody = anchors(not attackerIsPlayer)
      local shiftX, shiftY = userBody[1] - target[1], userBody[2] - target[2]
      if focus == 1 then
        mappedX, mappedY = mappedX + shiftX, mappedY + shiftY
      elseif focus == 3 then
        local endpoint = math.max(0, math.min(1, along))
        mappedX = mappedX + shiftX * endpoint
        mappedY = mappedY + shiftY * endpoint
      end
    end
    return mappedX, mappedY
  end
  return x * (GB_W / ESSENTIALS_W), y * (GB_H / ESSENTIALS_H)
end

local function frameTargetMode(targetMode, frameIndex, frameCount)
  if targetMode ~= "self-then-foe" then return targetMode end
  -- The supplied FLY program is a ten-frame target swoop.  Its first third is
  -- staged at the user as the visible take-off cue; the remaining frames keep
  -- their authored opponent endpoint for the strike.  Scale the split for a
  -- future replacement program instead of hard-coding one catalog length.
  local launchFrames = math.max(1, math.min(3,
    math.floor(math.max(1, tonumber(frameCount) or 1) / 3)))
  return (tonumber(frameIndex) or 1) <= launchFrames and "self" or "foe"
end

local function pseudoSprites(program, attackerIsPlayer, targetMode)
  local steps = {}
  local frames = program.frames or {}
  for frameIndex, frame in ipairs(frames) do
    local sprites = {}
    local frameTarget = frameTargetMode(
      targetMode, frameIndex, #frames)
    for _, cel in ipairs(frame) do
      if finite(cel.p, -1) >= 0 then
        local x, y = VascBattleAnimPlayer.mapPoint(
          cel, attackerIsPlayer, frameTarget)
        sprites[#sprites + 1] = { x=x + 8, y=y + 16, ts=0, tile=0 }
      end
    end
    if #sprites == 0 then
      local user = attackerIsPlayer and PLAYER_ANCHOR or ENEMY_ANCHOR
      sprites[1] = { x=user[1] + 8, y=user[2] + 16, ts=0, tile=0 }
    end
    steps[#steps + 1] = { dur=TICKS_PER_FRAME, sprites=sprites }
  end
  return steps
end

local function graphicsPath(relative)
  if type(V) == "table" and type(V.path) == "string" then
    return V.path .. "/" .. relative
  end
  return relative
end

function Player.new(native, holder)
  return setmetatable({
    native=native,
    holder=holder,
    images={}, quads={},
    steps=native.steps, stepIndex=native.stepIndex,
    stepLeft=native.stepLeft,
    custom=false, program=nil, attackerIsPlayer=true,
    targetMode="foe", presentationPhase=nil, presentationActor=nil,
    nativeStarted=false, nativeStartError=nil,
  }, Player)
end

function Player:releaseCustom()
  for _, image in pairs(self.images) do
    if image and image.release then pcall(image.release, image) end
  end
  for _, byPattern in pairs(self.quads) do
    for _, quad in pairs(byPattern) do
      if quad and quad.release then pcall(quad.release, quad) end
    end
  end
  self.images, self.quads = {}, {}
end

function Player:release()
  self:releaseCustom()
  if self.native and self.native.release then self.native:release() end
end

function Player:start(moveId, attackerIsPlayer, opts)
  self.custom = false
  self.program = nil
  self.customVariant = nil
  self.lastCustomDrawFrame = nil
  self.lastCustomDrawnCels = 0
  self.nativeStarted = false
  self.nativeStartError = nil
  self.attackerIsPlayer = attackerIsPlayer and true or false
  local presentation = type(opts) == "table" and opts.presentation == true
  local nativeSpecial = opts ~= nil and not presentation
  local requestedTarget = presentation and opts.target or nil
  local registry = self.holder.registry or {}
  local semanticTarget = registry.targetModes
    and registry.targetModes[moveId] or nil
  self.targetMode = requestedTarget == "self" and "self"
    or requestedTarget == "foe" and "foe"
    or semanticTarget == "self" and "self"
    or semanticTarget == "self-then-foe" and "self-then-foe"
    or "foe"
  self.presentationPhase = presentation and opts.phase or nil
  self.presentationActor = presentation and opts.actor or nil

  -- Legacy opts mark native capture/send-out/special chains. Presentation
  -- opts are explicitly tagged and remain eligible for a custom program.
  local entry = not nativeSpecial
    and registry.programs and registry.programs[moveId]
  local source = registry.nativeSources and registry.nativeSources[moveId]
  if source == nil then
    -- A reviewed custom program with no verified matching native alias uses a
    -- named Gen-I safety source directly. Native-only/capture ids still pass
    -- through unchanged because they have no custom entry.
    source = entry and registry.defaultNativeSource or moveId
    if source == nil then source = moveId end
  end
  local okNative, nativeError = pcall(
    self.native.start, self.native, source, attackerIsPlayer, opts)
  if not okNative and registry.defaultNativeSource
      and registry.defaultNativeSource ~= source then
    okNative, nativeError = pcall(self.native.start, self.native,
      registry.defaultNativeSource, attackerIsPlayer, opts)
  end
  self.nativeStarted = okNative and true or false
  self.nativeStartError = okNative and nil or tostring(nativeError)

  -- Capture/send-out chains use native OAM state and finalSprites. They must
  -- never be replaced even if a content mod happens to reuse one of the ids.
  local variant = attackerIsPlayer and "move"
                  or (entry and entry.opp and "opp" or "move")
  local program = entry and entry[variant]
  if not (program and type(program.frames) == "table"
          and #program.frames > 0) then
    if self.nativeStarted then
      self.steps, self.stepIndex, self.stepLeft =
        self.native.steps, self.native.stepIndex, self.native.stepLeft
    else
      -- A broken optional/native provider must not replay the previous move's
      -- state.  End cleanly; reviewed VASC programs below remain independent
      -- and can still run even when their companion native source failed.
      self.steps, self.stepIndex, self.stepLeft = {}, 1, 0
    end
    return
  end

  self.custom = true
  self.program = program
  self.customVariant = variant
  self.steps = pseudoSprites(
    program, self.attackerIsPlayer, self.targetMode)
  self.stepIndex = 1
  self.stepLeft = self.steps[1] and self.steps[1].dur or 0

  -- One record per selected move, never per frame.  This makes a live report
  -- distinguish "custom program selected" from a native safety fallback.
  if type(V) == "table" and type(V.require) == "function" then
    local okDiagnostics, diagnostics = pcall(V.require, "Diagnostics")
    if okDiagnostics and diagnostics
        and type(diagnostics.write) == "function" then
      pcall(diagnostics.write, "battle-animation-selected", {
        move=tostring(moveId), provider="vasc", variant=variant,
        target=self.targetMode,
        custom=true, nativeSafety=self.nativeStarted == true,
      })
    end
  end
end

function Player:update()
  if self.nativeStarted and self.native and not self.native:isDone() then
    self.native:update()
  end
  if not self.custom then
    if self.nativeStarted then
      self.steps, self.stepIndex, self.stepLeft =
        self.native.steps, self.native.stepIndex, self.native.stepLeft
    else
      -- Keep a failed second native/provider start terminal. Copying the
      -- wrapped player's previous fields here would revive stale sprites.
      self.steps, self.stepIndex, self.stepLeft = {}, 1, 0
    end
    return
  end
  if self:isDone() then return end
  self.stepLeft = self.stepLeft - 1
  while self.stepLeft <= 0 do
    self.stepIndex = self.stepIndex + 1
    local step = self.steps[self.stepIndex]
    if not step then break end
    self.stepLeft = step.dur
  end
end

function Player:isDone()
  if self.custom then return self.steps[self.stepIndex] == nil end
  return not self.nativeStarted or self.native:isDone()
end

function Player:pollEffects()
  if self.nativeStarted and self.native and self.native.pollEffects then
    return self.native:pollEffects()
  end
  return {}
end

function Player:sheetImage(sheetId)
  local held = self.images[sheetId]
  if held ~= nil then return held or nil end
  local catalog = self.holder.catalog or {}
  local spec = catalog.sheets and catalog.sheets[sheetId]
  local g = love and love.graphics
  local ok, image = false, nil
  if spec and g and type(g.newImage) == "function" then
    ok, image = pcall(g.newImage, graphicsPath(spec.path))
  end
  if ok and image then
    if image.setFilter then pcall(image.setFilter, image, "linear", "linear") end
    self.images[sheetId] = image
  else
    self.images[sheetId] = false
  end
  return self.images[sheetId] or nil
end

function Player:cellQuad(sheetId, pattern)
  local catalog = self.holder.catalog or {}
  local spec = catalog.sheets and catalog.sheets[sheetId]
  if not spec then return nil end
  local sx = (pattern % 5) * CELL
  local sy = math.floor(pattern / 5) * CELL
  if sx < 0 or sy < 0 or sx + CELL > spec.w or sy + CELL > spec.h then
    return nil
  end
  local byPattern = self.quads[sheetId]
  if not byPattern then byPattern = {}; self.quads[sheetId] = byPattern end
  local quad = byPattern[pattern]
  if quad == nil then
    local g = love and love.graphics
    if g and type(g.newQuad) == "function" then
      local ok, made = pcall(g.newQuad, sx, sy, CELL, CELL, spec.w, spec.h)
      quad = ok and made or false
    else
      quad = false
    end
    byPattern[pattern] = quad
  end
  return quad or nil
end

local function send(shaderObject, key, value)
  if shaderObject and shaderObject.send then
    pcall(shaderObject.send, shaderObject, key, value)
  end
end

function Player:drawCustom()
  local frame = self.program and self.program.frames[self.stepIndex]
  local sheetId = self.program and self.program.sheet
  local image = sheetId and self:sheetImage(sheetId)
  local g = love and love.graphics
  if not frame then return true end
  if not (image and g and type(g.draw) == "function") then return false end

  local pushed = false
  if type(g.push) == "function" then
    pushed = pcall(g.push, "all")
    if not pushed then pushed = pcall(g.push) end
  end
  local effect = colorShader()
  local drawn = 0
  for _, cel in ipairs(frame) do
    local pattern = finite(cel.p, -1)
    local quad = pattern >= 0 and self:cellQuad(sheetId, pattern) or nil
    if quad then
      local x, y = VascBattleAnimPlayer.mapPoint(
        cel, self.attackerIsPlayer,
        frameTargetMode(self.targetMode, self.stepIndex,
          self.program and #self.program.frames or 0))
      local zoomX = finite(cel.zx, 100) / 100 * CELL_SCALE
      local zoomY = finite(cel.zy, finite(cel.zx, 100)) / 100 * CELL_SCALE
      if finite(cel.m, 0) ~= 0 then zoomX = -zoomX end
      local opacity = math.max(0, math.min(255, finite(cel.o, 255))) / 255
      if g.setBlendMode then
        local blend = finite(cel.b, 0)
        if blend == 1 then pcall(g.setBlendMode, "add")
        elseif blend == 2 then pcall(g.setBlendMode, "subtract")
        else pcall(g.setBlendMode, "alpha") end
      end
      if g.setColor then g.setColor(1, 1, 1, opacity) end
      if effect and g.setShader then
        g.setShader(effect)
        send(effect, "hueShift", (finite(self.program.hue, 0) % 360) / 360)
        send(effect, "overlayColor", {
          finite(cel.cr, 0) / 255, finite(cel.cg, 0) / 255,
          finite(cel.cb, 0) / 255, finite(cel.ca, 0) / 255,
        })
        send(effect, "toneAdjust", {
          finite(cel.tr, 0) / 255, finite(cel.tg, 0) / 255,
          finite(cel.tb, 0) / 255, finite(cel.ty, 0) / 255,
        })
      end
      g.draw(image, quad, x, y,
             math.rad(finite(cel.a, 0)), zoomX, zoomY, CELL / 2, CELL / 2)
      drawn = drawn + 1
      if effect and g.setShader then g.setShader() end
    end
  end
  if pushed and g.pop then
    g.pop()
  else
    if g.setShader then g.setShader() end
    if g.setBlendMode then pcall(g.setBlendMode, "alpha") end
    if g.setColor then g.setColor(1, 1, 1, 1) end
  end
  self.lastCustomDrawFrame = self.stepIndex
  self.lastCustomDrawnCels = drawn
  -- A deliberately empty authored frame is a pause, not a provider failure.
  -- If the frame did reference graphics but none of its quads were usable,
  -- let draw() expose the already-running native safety layer instead of an
  -- invisible attack.
  local expected = false
  for _, cel in ipairs(frame) do
    if finite(cel.p, -1) >= 0 then expected = true; break end
  end
  return drawn > 0 or not expected
end

function Player:draw(colorFn)
  if self.custom then
    local customVisible = self:drawCustom()
    if customVisible ~= false then return customVisible end
  end
  if self.nativeStarted and self.native and self.native.draw then
    return self.native:draw(colorFn)
  end
end

function Player:finalSprites()
  return self.nativeStarted and self.native and self.native.finalSprites
         and self.native:finalSprites() or nil
end

function Player:drawSprites(sprites, colorFn)
  if self.nativeStarted and self.native and self.native.drawSprites then
    return self.native:drawSprites(sprites, colorFn)
  end
end

-- Patch only the public constructor and hold the original player by identity.
-- Hot reload updates the catalog/registry without stacking another decorator.
function VascBattleAnimPlayer.install(catalog, registry)
  local AnimPlayer = require("src.battle.AnimPlayer")
  if type(AnimPlayer) ~= "table" or type(AnimPlayer.new) ~= "function" then
    return false
  end
  local held = rawget(AnimPlayer, "voxelAscendantAnimationFactory")
  if held then
    if AnimPlayer.new ~= held.wrapper then return false end
    held.catalog, held.registry = catalog, registry
    return true
  end
  held = { original=AnimPlayer.new, catalog=catalog, registry=registry }
  held.wrapper = function(data)
    return Player.new(held.original(data), held)
  end
  AnimPlayer.new = held.wrapper
  AnimPlayer.voxelAscendantAnimationFactory = held
  return true
end

VascBattleAnimPlayer.Player = Player
VascBattleAnimPlayer.TICKS_PER_FRAME = TICKS_PER_FRAME
VascBattleAnimPlayer.PLAYER_ANCHOR = PLAYER_ANCHOR
VascBattleAnimPlayer.ENEMY_ANCHOR = ENEMY_ANCHOR
VascBattleAnimPlayer.frameTargetMode = frameTargetMode

return VascBattleAnimPlayer
