-- Fixed local compute worker: data in, SHA-256 out. No game state or I/O.
require('love.data')
require('love.thread')
local raw,channel=...
local ok,digest=pcall(function()
 assert(type(raw)=='string' and #raw<=16*1024*1024)
 return love.data.encode('string','hex',love.data.hash('sha256',raw))
end)
channel:push(ok and digest or false)
