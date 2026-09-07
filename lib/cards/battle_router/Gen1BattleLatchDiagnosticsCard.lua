-- Always-on, behavior-neutral diagnostics owner for terminal Gen-1 battle
-- renderer latches. The renderer decides when an encounter becomes native;
-- this Card receives only an already-sanitized primitive receipt and writes it
-- to Diagnostics' bounded support log. It never owns a provider, transition,
-- save field or public hook.

local Card = {
  ID = "vasc.gen1.battle-latch-diagnostics",
  VERSION = "1.0.0",
  EVENT = "battle-native-latch",
  LIFECYCLE_CARD = "vasc.gen1.battle-lifecycle",
}

local PHASES = {
  ["texture-resolution-timeout"]=true,
  ["scene-render-failed"]=true,
  ["scene-cover-unavailable"]=true,
  ["scene-render-timeout"]=true,
  ["battle-update-failed"]=true,
}

local PROVIDERS = { MAP=true, ARENA=true, DISCS=true }

local function primitive(value)
  local kind = type(value)
  return kind == "string" or kind == "number" or kind == "boolean"
end

-- Treat the renderer receipt as an untrusted Card boundary. rawget prevents a
-- forged/stale table from running __index while the callback lease is live;
-- the closed field copy guarantees Diagnostics never receives an engine/save
-- object even if a future renderer accidentally adds one to its receipt.
function Card.fields(raw)
  if type(raw) ~= "table" then return nil, "latch receipt is not a table" end
  local generation = rawget(raw, "generation")
  local provider = rawget(raw, "provider")
  local phase = rawget(raw, "phase")
  local status = rawget(raw, "status")
  local reason = rawget(raw, "reason")
  local battleId = rawget(raw, "battleId")
  if generation ~= 1 then return nil, "latch generation is not Gen-1" end
  if not PROVIDERS[provider] then return nil, "unknown battle provider" end
  if not PHASES[phase] then return nil, "unknown native-latch phase" end
  if status ~= "native_latched" then return nil, "invalid latch status" end
  if type(reason) ~= "string" or reason == "" then
    return nil, "native-latch reason is unavailable"
  end
  if type(battleId) ~= "string"
      or battleId:match("^G1L%-%d+$") == nil then
    return nil, "invalid diagnostic battle id"
  end
  local fields = {
    generation=generation,
    provider=provider,
    phase=phase,
    status=status,
    reason=reason,
    battleId=battleId,
  }
  for _, value in pairs(fields) do
    if not primitive(value) then return nil, "non-primitive latch field" end
  end
  return fields
end

function Card.descriptor(dependencies)
  dependencies = dependencies or {}
  local renderer = dependencies.renderer
  local diagnostics = dependencies.diagnostics
  return {
    schema="ascendant.card/v1",
    id=Card.ID,
    version=Card.VERSION,
    owner="voxel_ascendant",
    requires={ Card.LIFECYCLE_CARD },
    optionalRequires={},
    consumes={},
    provides={},
    tests={
      "tests/gen1_battle_latch_diagnostics_card_test.lua",
      "tests/battle_frame_ownership_test.lua",
      "tests/support_session_log_test.lua",
    },
    docs={
      "docs/maintainer/VASC_66_GEN1_BATTLE_LATCH_DIAGNOSTICS_RECEIPT.json",
      "docs/maintainer/VASC_66_GEN1_BATTLE_LATCH_DIAGNOSTICS_ROLLBACK.md",
    },
    saveNamespace=false,
    impact={
      runtimeOwners={ "gen1.battle.native-latch-diagnostics" },
      saveWrites={},
      publicHooks={},
      files={
        "lib/OverworldBattle.lua",
        "lib/cards/battle_router/Gen1BattleLatchDiagnosticsCard.lua",
      },
    },
    lifecycle={
      install=function()
        if type(renderer) ~= "table"
            or type(renderer.installBattleLatchDiagnosticsV1) ~= "function" then
          return false, "Gen-1 battle latch reporter seam is unavailable"
        end
        if type(diagnostics) ~= "table"
            or type(diagnostics.write) ~= "function" then
          return false, "bounded support diagnostics are unavailable"
        end
        return { renderer=renderer, diagnostics=diagnostics }
      end,
      activate=function(_, installed)
        local active = {
          state="active", accepted=0, rejected=0, writeFailures=0,
        }
        local function report(raw)
          if active.state ~= "active" then return false end
          local fields = Card.fields(raw)
          if not fields then
            active.rejected = active.rejected + 1
            return false
          end
          local called, written = pcall(
            installed.diagnostics.write, Card.EVENT, fields)
          if not called or written == false then
            active.writeFailures = active.writeFailures + 1
            return false
          end
          active.accepted = active.accepted + 1
          return true
        end
        local control, reason =
          installed.renderer.installBattleLatchDiagnosticsV1(report)
        if not control then return false, reason end
        active.control = control
        return active
      end,
      deactivate=function(_, active)
        if type(active) ~= "table" then return true end
        active.state = "retired"
        if active.control and type(active.control.retire) == "function" then
          return active.control.retire()
        end
        return true
      end,
      abort=function(_, _, _, _, active)
        if type(active) ~= "table" then return true end
        active.state = "failed"
        if active.control and type(active.control.retire) == "function" then
          return active.control.retire()
        end
        return true
      end,
      health=function(_, _, active)
        if type(active) ~= "table" then
          return {
            schema="ascendant.compat-status/v1", apiVersion=1,
            ok=false, state="inactive",
          }
        end
        local downstream = active.control
          and type(active.control.health) == "function"
          and active.control.health() or nil
        return {
          schema="ascendant.compat-status/v1", apiVersion=1,
          ok=active.state == "active"
            and type(downstream) == "table" and downstream.ok == true,
          state=active.state,
          accepted=active.accepted,
          rejected=active.rejected,
          writeFailures=active.writeFailures,
          rendererReports=type(downstream) == "table"
            and downstream.reports or nil,
          rendererFailures=type(downstream) == "table"
            and downstream.failures or nil,
        }
      end,
    },
  }
end

return Card
