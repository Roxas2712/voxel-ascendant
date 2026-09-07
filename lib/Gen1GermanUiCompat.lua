-- German presentation fixes for native Gen1Recomp screens whose dynamic
-- text bypasses src.core.Strings. The engine remains the sole owner of load
-- validation, quarantine data and screen navigation.
local V = ...
local mod = V and V.mod

local M = { installed=false }

local function findMod(id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, handle = pcall(mod.find, id)
  if not ok or handle == nil then
    ok, handle = pcall(mod.find, mod, id)
  end
  return ok and handle or nil
end

local function germanActive()
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, "hud_language")
    value = ok and tostring(value or ""):lower() or ""
    if value == "de" or value == "deutsch" or value == "german" then
      return true
    elseif value == "en" or value == "english" then
      return false
    end
  end
  local universal = findMod("translation-german-universal")
  local boot = type(universal) == "table" and universal.exports
    and universal.exports.bootLanguage
  if boot == "de" then return true elseif boot == "en" then return false end
  for _, id in ipairs({ "universal_german", "deutsch",
      "deutsch-blau", "deutsch-gelb" }) do
    if findMod(id) then return true end
  end
  return false
end

local function germanModsNotice(diff, meta)
  if type(diff) ~= "table" then return nil end
  local removed = #(diff.removed or {})
  local changed = #(diff.changed or {})
  local added = #(diff.added or {})
  if removed == 0 and changed == 0 and added == 0 then return nil end
  local wrote = #((type(meta) == "table" and meta.mods) or {})
  local parts = {}
  if removed > 0 then
    parts[#parts + 1] = removed == 1
      and "1 ist nicht mehr aktiv" or (removed .. " sind nicht mehr aktiv")
  end
  if changed > 0 then
    parts[#parts + 1] = changed == 1
      and "1 Version geändert" or (changed .. " Versionen geändert")
  end
  if added > 0 then
    parts[#parts + 1] = added == 1
      and "1 neu aktiv" or (added .. " neu aktiv")
  end
  return ("Dieser Spielstand wurde mit %d Mod%s erstellt; %s"):format(
    wrote, wrote == 1 and "" or "s", table.concat(parts, ", "))
end

local FIXED_REPORT_LINES = {
  ["Save recovered from"]="Spielstand gerettet",
  ["Moved to LOST box:"]="In VERLOREN-Box:",
  ["Items removed:"]="Gegenstände entfernt:",
  ["Location reset:"]="Ort zurückgesetzt:",
  ["Restored:"]="Wiederhergestellt:",
}

local function translateReportLines(lines)
  for index, line in ipairs(type(lines) == "table" and lines or {}) do
    if FIXED_REPORT_LINES[line] then
      lines[index] = FIXED_REPORT_LINES[line]
    elseif tostring(line):match("^ the %.") then
      lines[index] = tostring(line):gsub("^ the ", " aus ")
        :gsub(" backup copy$", "-Sicherung")
    end
  end
  return lines
end

function M.install()
  if M.installed then return true end
  local okSave, SaveData = pcall(require, "src.core.SaveData")
  local okReport, QuarantineReport = pcall(require, "src.ui.QuarantineReport")
  local saveNoticeAvailable = okSave and type(SaveData) == "table"
    and type(SaveData.modsDiffNotice) == "function"
  local reportAvailable = okReport and type(QuarantineReport) == "table"
    and type(QuarantineReport.new) == "function"

  -- These two surfaces were introduced in different Gen1Recomp revisions.
  -- Treat them as independent optional seams: an older engine missing one of
  -- them must not prevent every other German UI hook from installing.
  if saveNoticeAvailable and not SaveData.__vascGermanModsNoticePatched then
    local nativeNotice = SaveData.modsDiffNotice
    SaveData.modsDiffNotice = function(diff, meta)
      if germanActive() then return germanModsNotice(diff, meta) end
      return nativeNotice(diff, meta)
    end
    SaveData.__vascGermanModsNoticePatched = true
  end
  if reportAvailable and not QuarantineReport.__vascGermanLinesPatched then
    local nativeNew = QuarantineReport.new
    QuarantineReport.new = function(...)
      local screen = nativeNew(...)
      if germanActive() and type(screen) == "table" then
        translateReportLines(screen.lines)
      end
      return screen
    end
    QuarantineReport.__vascGermanLinesPatched = true
  end
  M.installed = true
  local unavailable = {}
  if not saveNoticeAvailable then
    unavailable[#unavailable + 1] = "SaveData.modsDiffNotice unavailable"
  end
  if not reportAvailable then
    unavailable[#unavailable + 1] = "QuarantineReport.new unavailable"
  end
  return true, #unavailable > 0 and table.concat(unavailable, "; ") or nil
end

M.germanActive = germanActive
M.germanModsNotice = germanModsNotice
M.translateReportLines = translateReportLines
return M
