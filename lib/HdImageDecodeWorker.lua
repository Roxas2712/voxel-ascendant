-- Fixed local worker: no filesystem reads, GPU calls or game-state access.
require('love.image')
require('love.filesystem')
require('love.thread')
local raw,channel,width,height=...
local ok,data=pcall(function()
 local file=love.filesystem.newFileData(raw,'hd-card.png')
 local success,value=pcall(love.image.newImageData,file)
 file:release()
 assert(success,value)
 local w,h=value:getDimensions()
 if w~=width or h~=height then value:release();error('HD dimensions changed') end
 return value
end)
channel:performAtomic(function(result)
 if result:pop()=='pending' then result:push(ok and data or false)
 else
  if ok then data:release() end
  result:push('cancelled')
 end
end)
