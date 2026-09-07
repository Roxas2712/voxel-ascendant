-- A successful ORAS frame owns one BattleState across throw/send-out/switch,
-- return and attack shot churn. Real provider failures remain native-readable,
-- and neither a fresh nor a copied BattleState may inherit the latch.

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local value = assert(handle:read("*a"))
  handle:close()
  return value
end

local orasSource = read("battle_hud_oras.lua")
local receiptStart = assert(orasSource:find(
  "function FloatingHud.hasExactHudSnapReceipt", 1, true))
local receiptEnd = assert(orasSource:find(
  "\n\n-- VASC reserves its edge HUD", receiptStart, true))
local nativeStart = assert(orasSource:find(
  "function FloatingHud.nativeReplacementCommitted", 1, true))
local nativeEnd = assert(orasSource:find(
  "\n\n-- A successful provider already ran", nativeStart, true))
local decisionStart = assert(orasSource:find(
  "function FloatingHud.providerFrameComplete", 1, true))
local decisionEnd = assert(orasSource:find(
  "\n\nlocal hudProvider =", decisionStart, true))

local activeReceipt = nil
local OverworldBattle = {
  hudSnapReceipt=function() return activeReceipt end,
}
local FloatingHud = {}
local function supportedFloatingLayout(battle)
  return battle ~= nil and not battle.demo
end
local function floatingCommandsEnabled() return true end
local source = orasSource:sub(receiptStart, receiptEnd - 1)
  .. "\n\n" .. orasSource:sub(nativeStart, nativeEnd - 1)
  .. "\n\n" .. orasSource:sub(decisionStart, decisionEnd - 1)
  .. "\nreturn FloatingHud\n"
local env = setmetatable({
  FloatingHud=FloatingHud,
  OverworldBattle=OverworldBattle,
  supportedFloatingLayout=supportedFloatingLayout,
  floatingCommandsEnabled=floatingCommandsEnabled,
  isAscendantHost=true,
  hostProviderAvailable=true,
  type=type,
  rawget=rawget,
  pcall=pcall,
}, { __index=_G })
local chunk, compileError
if loadstring then
  chunk, compileError = loadstring(source, "@battle-owner-latch")
  if chunk then setfenv(chunk, env) end
else
  chunk, compileError = load(source, "@battle-owner-latch", "t", env)
end
assert(chunk, compileError)
FloatingHud = chunk()

local firstShot = {}
local battle = { voxelAscendantShot=firstShot, phase="messages" }
activeReceipt = {
  schema="voxel-ascendant/hud-snap/v1",
  shot=firstShot,
  snapped=true,
  owner="voxel_ascendant.oras",
}
eq(FloatingHud.nativeReplacementCommitted(battle), true,
  "first exact ORAS receipt did not establish battle ownership")
check(FloatingHud.battleHudOwnerLatched(battle),
  "exact ORAS frame did not publish a per-battle latch")

-- The real engine can expose a new staged shot before the next exact receipt
-- is observed. Every listed transition must stay with the established owner.
for _, phase in ipairs({
    "throw", "sendOut", "switch", "return", "attack",
    "firstAttackAfterSwitch",
  }) do
  battle.phase = phase
  battle.voxelAscendantShot = { phase=phase }
  eq(FloatingHud.nativeReplacementCommitted(battle), true,
    phase .. " handed a stale successful owner back to Cartridge 2D")
  eq(FloatingHud.providerFrameComplete(
      battle, true, false, false, false, false), true,
    phase .. " rejected the expected actor-receipt gap")
end

-- Message/menu ownership is stricter: continuity may bridge a status actor,
-- but it may not claim a required ORAS textbox which was not actually drawn.
eq(FloatingHud.providerFrameComplete(
    battle, true, false, true, false, false), false,
  "battle latch hid a missing required ORAS message/menu")
eq(FloatingHud.providerFrameComplete(
    battle, true, false, true, true, false), true,
  "battle latch rejected a drawn ORAS message during actor churn")

-- A real failed provider deliberately publishes snapped=false. The old latch
-- must not erase the only readable fallback UI.
activeReceipt = {
  schema="voxel-ascendant/hud-snap/v1",
  shot=battle.voxelAscendantShot,
  snapped=false,
  reason="provider-failed",
  owner="voxel_ascendant.oras",
}
eq(FloatingHud.nativeReplacementCommitted(battle), false,
  "provider failure was hidden by an old battle latch")

local freshBattle = { voxelAscendantShot={} }
activeReceipt = {
  schema="voxel-ascendant/hud-snap/v1",
  shot=firstShot,
  snapped=true,
  owner="voxel_ascendant.oras",
}
eq(FloatingHud.nativeReplacementCommitted(freshBattle), false,
  "new battle inherited the previous battle's ORAS owner")
freshBattle._ascendantBattleHudOwnerLatch =
  battle._ascendantBattleHudOwnerLatch
eq(FloatingHud.battleHudOwnerLatched(freshBattle), false,
  "copied latch was accepted for a different BattleState")

eq(FloatingHud.clearBattleHudOwner(battle), true,
  "battle finish could not clear ORAS owner")
eq(FloatingHud.battleHudOwnerLatched(battle), false,
  "ORAS owner survived battle finish")

-- A successful ORAS HUD owner is battle-scoped, but the pixels in a rendered
-- scene remain deployment-scoped. A switch can reuse the same side canvas:
-- neither a fresh nor a previously committed session may retain the old
-- monster under the new battler identity. Exact actor receipts still bridge a
-- genuinely transient scene miss.
local overworldSource = read("lib/OverworldBattle.lua")
local matchStart = assert(overworldSource:find(
  "local function actorMatchesTexture", 1, true))
local matchEnd = assert(overworldSource:find(
  "\n\n-- ------- per-frame", matchStart, true))
local matchChunk, matchError = (loadstring or load)(
  overworldSource:sub(matchStart, matchEnd - 1)
    .. "\nreturn shotMatchesTextures, shouldRetainCommittedShot, "
    .. "retainAfterRenderFailure, retryAfterNilFrame\n",
  "@committed-shot-retention")
assert(matchChunk, matchError)
local _, shouldRetainCommittedShot, retainAfterRenderFailure,
  retryAfterNilFrame = matchChunk()
local battlerA, monA, battlerB, monB = {}, {}, {}, {}
local oldCanvas, newCanvas = {}, {}
local oldShot = { actorVisuals={ player={
  schema="voxel-ascendant/actor-render/v1",
  canvas=oldCanvas, battler=battlerA, mon=monA,
  modelKey="A", textureToken=1, view="front",
} } }
local changedTextures = { player={
  canvas=newCanvas, vascRenderBattler=battlerB, vascRenderMon=monB,
  vascRenderModelKey="B", vascRenderTextureToken=2, vascSpriteView="front",
} }
eq(shouldRetainCommittedShot({
    shot=oldShot, presentationCommitted=false,
  }, changedTextures), false,
  "fresh session retained a mismatched pre-commit actor")
eq(shouldRetainCommittedShot({
    shot=oldShot, presentationCommitted=true,
  }, changedTextures), false,
  "committed battle retained a stale monster across a switch")

local failureSession = { shot=oldShot, presentationCommitted=true }
eq(retainAfterRenderFailure(failureSession, changedTextures), false,
  "render failure retained a committed scene with mismatched actors")

local matchingTextures = { player={
  canvas=oldCanvas, vascRenderBattler=battlerA, vascRenderMon=monA,
  vascRenderModelKey="A", vascRenderTextureToken=1, vascSpriteView="front",
} }
failureSession = { shot=oldShot, presentationCommitted=true }
eq(retainAfterRenderFailure(failureSession, matchingTextures), true,
  "first exact-actor transient render failure discarded the committed scene")
eq(retainAfterRenderFailure(failureSession, matchingTextures), true,
  "second exact-actor transient render failure discarded the committed scene")
eq(retainAfterRenderFailure(failureSession, matchingTextures), false,
  "persistent exact-actor render failure never failed open")

local nilSession = { shot=oldShot, presentationCommitted=true }
local retry, retain = retryAfterNilFrame(nilSession, matchingTextures)
eq(retry, true, "first exact-actor nil frame exhausted the retry budget")
eq(retain, true, "exact-actor nil frame did not retain last-good")
retryAfterNilFrame(nilSession, matchingTextures)
retry, retain = retryAfterNilFrame(nilSession, matchingTextures)
eq(retry, false, "persistent exact-actor nil frames were unbounded")
eq(retain, true, "exact actor identity changed during nil retry accounting")

nilSession = { shot=nil, presentationCommitted=false }
for _ = 1, 11 do
  retry, retain = retryAfterNilFrame(nilSession, changedTextures)
  eq(retry, true, "cold scene exhausted its bounded build window too early")
  eq(retain, false, "cold scene claimed a non-existent last-good frame")
end
retry = retryAfterNilFrame(nilSession, changedTextures)
eq(retry, false, "cold render nil remained pending without a bound")

print("per-battle ORAS owner continuity: ok")
