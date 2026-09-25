# Screenshot error reports

Errors stores up to 32 incidents for the current session. Reports are frozen at the first observation, with first/last observation time and a repeated-burst count. Opening the menu does not replace incident-time values with menu-time measurements.

The first report page includes platform/version, available hardware information, Lua heap and graphics texture allocation, frame times, map, requested/actual rendering, and failure reason. Longer reports paginate above navigation. Every page carries the incident ID and session suffix. Send every page belonging to the incident.

Details preserve up to 4096 characters; explicit truncation markers distinguish a bounded report from a complete compiler message. Named diagnostic fields include phase, battle ID, provider/checkpoint, installation and selection states, location/placement, species/assets when supplied. Three nearby incidents on the same map and activity within eight seconds may be included as context; they are not automatically considered causes. Graphics-check incidents stay separate from gameplay.

Hardware availability is host-dependent. The current mod sandbox provides GPU renderer/vendor/device, logical processor count, Lua architecture, Lua heap, texture memory and graphics counters. It does not reliably expose exact device/CPU model, total/free/system-used RAM, process resident or peak RAM. Missing values are shown explicitly. Lua heap is not total process RAM; texture allocation is not total VRAM. No shell commands, FFI or forced garbage collection are used to collect reports.

Reports contain allowlisted primitive fields. URLs and local user paths are redacted; arbitrary saves or objects are not serialized. The text form is available from `mod.exports.errors.reportText(receipt)`. Copy only reports success when the host acknowledges it or exact readback succeeds. Current engine clipboard stubs return false, so screenshots remain the supported route there.

Logs remain useful for timing history, crashes before an incident can be recorded, and visual defects that do not raise errors. A report does not automatically upload or send anything.

Validation: `error_inbox_test.lua`, `error_report_detail_test.lua`, `errors_menu_owner_test.lua`, `error_report_ui_driver.lua`. The native driver uses explicit TEST FIXTURE incidents, isolated save identity and `BATTLE_QA` output directory.
