package.path = "./?.lua;./?/init.lua;"
  .. "/Users/maarten/Documents/Recompile/gen1recomp/?.lua;"
  .. "/Users/maarten/Documents/Recompile/gen1recomp/?/init.lua;"
  .. package.path

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)"):format(
      label, tostring(expected), tostring(actual)), 2)
  end
end

local ModSetting = {}
function ModSetting.new(_, _, _, _, default)
  return { get=function() return default end }
end
local AscBox = assert(loadfile("lib/gen2_a21_shared/AscBoxProvider.lua"))({
  require=function(name)
    assert(name == "ModSetting", "unexpected module " .. tostring(name))
    return ModSetting
  end,
})

local boxed = {
  id="pc:box:1:3", zone="box", box=1, slot=3,
  pokemon={ species="EEVEE", nickname="BOXMON", level=18 },
}
local model = {
  revision=9, surface="pc_box", locale="de", edition="crystal",
  focus={ zone="box", box=1, slot=3, id=boxed.id },
  selection={ ids={}, revision=9 },
  zones={ box={ capacity=20, entries={boxed} },
    party={ capacity=6, entries={} } },
  availability={
    navigate={enabled=true}, move={enabled=true}, inspect={enabled=true},
    withdraw={enabled=true}, release={enabled=true}, cancel={enabled=true},
  },
  surfaceData={ currentBox=1, boxCount=2, boxCapacity=20, partyCapacity=6 },
}
local calls = {}
local controller = setmetatable({ model=model, ctx={dispatch=function(action, payload)
  calls[#calls+1] = {action=action,payload=payload}
  return {status="applied", action=action, model=model}
end}}, AscBox.Controller)

assert(controller:handleInput({pressed={a=true}}),
  "Gen-2 mobile PC slot did not open action card")
eq(controller.carry, nil, "Gen-2 first A still entered carry mode")
eq(table.concat(controller.menu, ","),
  "move,inspect,withdraw,release,menu_cancel",
  "Gen-2 action card diverged from PC/Gen-1")
controller:handleInput({pressed={down=true}})
controller:handleInput({pressed={a=true}})
eq(calls[1].action, "inspect", "Gen-2 STATUS did not use native summary")
eq(calls[1].payload.target.id, boxed.id, "Gen-2 STATUS lost focused Pokemon")
assert(controller:handleInput({pressed={a=true}}))
controller:handleInput({pressed={up=true}})
controller:handleInput({pressed={a=true}})
eq(controller.menu, nil, "Gen-2 ABBRUCH did not close action card")
eq(#calls, 1, "Gen-2 ABBRUCH closed/mutated host surface")

print("Gen2 ASC Box: PC action-card parity and native STATUS dispatch ok")
