local root = arg and arg[1] or "."

local bootLanguage = "de"
local SaveData = {
  modsDiffNotice=function() return "This save was made with mods" end,
}
local QuarantineReport = {
  new=function()
    return { lines={ "Save recovered from", " the .bak backup copy",
      "Moved to LOST box:", "Items removed:", "Location reset:",
      "Restored:" } }
  end,
}
package.preload["src.core.SaveData"] = function() return SaveData end
package.preload["src.ui.QuarantineReport"] = function() return QuarantineReport end

local mod = {
  find=function(id)
    if id == "translation-german-universal" and bootLanguage then
      return { exports={ bootLanguage=bootLanguage } }
    end
  end,
  options={ get=function() return "de" end }, -- stale battle-only preference
}
local module = assert(loadfile(root .. "/lib/Gen1GermanUiCompat.lua"))({mod=mod})
assert(module.install())
local diff = { removed={"a","b","c"}, changed={{id="d"},{id="e"}}, added={"f"} }
local notice = SaveData.modsDiffNotice(diff, {mods={1,2,3,4,5,6}})
assert(notice == "Dieser Spielstand wurde mit 6 Mods erstellt; 3 sind nicht mehr aktiv, 2 Versionen geändert, 1 neu aktiv")
local report = QuarantineReport.new()
assert(report.lines[1] == "Spielstand gerettet")
assert(report.lines[2] == " aus .bak-Sicherung")
assert(report.lines[3] == "In VERLOREN-Box:")
assert(report.lines[4] == "Gegenstände entfernt:")
assert(report.lines[5] == "Ort zurückgesetzt:")
assert(report.lines[6] == "Wiederhergestellt:")

bootLanguage = "en"
assert(SaveData.modsDiffNotice(diff, {mods={}}) == "This save was made with mods")
assert(QuarantineReport.new().lines[1] == "Save recovered from")
bootLanguage = nil
assert(not module.germanActive(), "HUD language translated menus without a translation mod")
assert(SaveData.modsDiffNotice(diff, {mods={}}) == "This save was made with mods")
assert(QuarantineReport.new().lines[1] == "Save recovered from")

-- Gen1Recomp 0.1.90 has no modsDiffNotice method.  That optional absence must
-- not abort the independent quarantine-report translation hook.
local LegacySaveData = {}
local LegacyReport = { new=function()
  return { lines={ "Save recovered from", "Items removed:" } }
end }
local legacyRequire = require
local legacyChunk = assert(loadfile(root .. "/lib/Gen1GermanUiCompat.lua"))
bootLanguage = "de"
package.loaded["src.core.SaveData"] = nil
package.loaded["src.ui.QuarantineReport"] = nil
package.preload["src.core.SaveData"] = function() return LegacySaveData end
package.preload["src.ui.QuarantineReport"] = function() return LegacyReport end
local legacy = legacyChunk({mod=mod})
local installed, reason = legacy.install()
assert(installed == true)
assert(reason == "SaveData.modsDiffNotice unavailable")
assert(LegacyReport.new().lines[1] == "Spielstand gerettet")
assert(LegacyReport.new().lines[2] == "Gegenstände entfernt:")
require = legacyRequire
print("Gen-1 Universal German dynamic UI compatibility: ok")
