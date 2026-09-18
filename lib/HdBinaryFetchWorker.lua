-- One bounded-duration worker; curl's pipe must be binary on Windows.
local url, seconds, result, limit = ...
limit = math.min(4194304, math.max(1, tonumber(limit) or 4194304))
require("love.filesystem")
require("love.system")
require("love.thread")
local ok, body, err = pcall(function()
  local origin, path
  if type(url) == "string" then origin, path = url:match("^(https://[^/]+)(/.*)$") end
  local packageOrigin = origin == "https://vasc-sprite-files.ascendant-content.workers.dev"
  local nasOrigin = origin == "https://ascendant-logs.pausihausi.synology.me"
  if packageOrigin or nasOrigin then
    local route = nasOrigin and path and path:match("^/sprites(/.*)$") or path
    local digest, index = (route or ""):match("^/package%-versions/([a-f0-9]+)/chunks/(%d+)$")
    assert(digest and #digest == 64 and index, "Invalid package route")
  end
  assert(packageOrigin or nasOrigin or origin == "https://vasc-downloads.ascendant-content.workers.dev"
    or origin == "https://vasc-content.maarten-paus.chatgpt.site", "Unapproved HD origin")
  assert(path and not path:find("[%s?#]"), "Invalid HD route")
  local Host = assert(love.filesystem.load("src/core/HostShell.lua"))()
  local popen, pclose = Host.popen, Host.pclose
  local pipes = {}
  function Host.popen(command, mode, options)
    if love.system.getOS() == "Windows" and mode == "r" then mode = "rb" end
    local pipe = popen(command, mode, options)
    if not pipe then return nil end
    local proxy = {}
    function proxy:read(format)
      if format ~= "*a" then return pipe:read(format) end
      local parts, received = {}, 0
      while true do
        local chunk = pipe:read(32768)
        if not chunk then break end
        received = received + #chunk
        -- HostShell appends its HTTP status marker. Allow only bounded overhead.
        assert(received <= limit + 4096, "Response exceeds content limit")
        parts[#parts+1] = chunk
        result:push({status="pending", receivedBytes=math.min(received,limit)})
      end
      return table.concat(parts)
    end
    pipes[proxy] = pipe
    return proxy
  end
  function Host.pclose(pipe) return pclose(pipes[pipe] or pipe) end
  return Host.httpGet(url, "gen1recomp-mod/VOXEL_ASCENDANT", nil, seconds)
end)
if not ok then err = body; body = nil end
if type(body) == "string" and #body > limit then
  body = nil; err = "Response exceeds content limit"
end
result:push(body and {status="ok",body=body}
  or {status="error",err=tostring(err or "Network unavailable")})
