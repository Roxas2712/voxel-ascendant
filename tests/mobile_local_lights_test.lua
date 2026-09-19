-- Actual GPU probes with mobile slot budgets; the OS remains native. This
-- verifies shader/math/resource contracts, not an iPhone GPU certification.
local root=assert(arg[1])
local f=assert(io.open(root..'/tests/local_lights_test.lua'));local code=f:read('*a');f:close()
code=code:gsub("local currentOS='OS X'", "local currentOS='iOS'")
assert(loadstring(code,'mobile_local_lights_gpu'))()
print('PASS_MOBILE_LOCAL_LIGHTS_GPU')
