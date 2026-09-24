-- Bounded session-only incident receipts. No disk I/O, rendering or recovery actions.
local M={LIMIT=32}
function M.clean(value,limit)
 if type(value)~='string' and type(value)~='number' and type(value)~='boolean' then return '?' end
 local s=tostring(value):gsub('%c',' ')
 s=s:gsub('https?://%S+','[URL]'):gsub('/Users/[^%s]+','[path]'):gsub('/home/[^%s]+','[path]'):gsub('%a:\\[^%s]+','[path]')
 return s:sub(1,limit or 180)
end
local function ends(s,suffix)return s:sub(-#suffix)==suffix end
function M.classify(event,f)
 f=f or {};local status=tostring(f.status or ''):lower();local e=tostring(event):lower()
 if f.expected==true or status=='expected_fallback' or status=='off' or status=='disabled' or status=='inactive' or status=='pending' then return end
 if ends(e,'battle-map-placement-fallback') then return 'E_MAP','fallback' end
 if ends(e,'battle-native-latch') or ends(e,'mobile-battle-fallback') then return 'D14','fallback' end
 if ends(e,'battle-sprite-unavailable') then return 'E_ART','fallback' end
 if ends(e,'hook-error') then return 'E_HOOK','error' end
 if ends(e,'engine-error') then return 'E_ENGINE','error' end
 local failed=status=='failure' or status=='failed' or status=='error' or ends(e,'-error') or ends(e,'-failed') or ends(e,'-failure')
 if e=='first-failure' or ends(e,'.first-failure') then failed=true end
 if ends(e,'mobile-renderer-fallback') and status=='fallback' then failed=true end
 if not failed then return end
 local code=tostring(f.code or '')
 if not code:match('^D0[4-9]$') and not code:match('^D1[0-4]$') then code='E_RENDER' end
 return code,status=='fallback' and 'fallback' or 'error'
end
function M.new(clock)
 local self={items={},serial=0,unread=0,context={}}
 self.clock=clock or function()return love and love.timer and love.timer.getTime and love.timer.getTime() or 0 end
 function self:observe(event,f)
  f=type(f)=='table' and f or {};local code,kind=M.classify(event,f);if not code then return end
  local reason=M.clean(f.reason or f.error or f.message or f.checkpoint or event)
  local map=M.clean(f.mapId or f.map or self.context.map,60)
  local caller=M.clean(f.caller or f.owner or f.source or event,90)
  local activity=M.clean(f.activity or self.context.activity or 'gameplay',24)
  local key=code..'|'..map..'|'..caller..'|'..activity..'|'..reason
  local now=self.clock()
  for _,r in ipairs(self.items)do if r.key==key then
   -- Counts represent observation bursts, never every rendered frame.
   if now-r.last>=1 then r.count=math.min(99999,r.count+1);r.last=now end
   return r,false
  end end
  self.serial=self.serial+1
  local r={id=self.serial,key=key,activity=activity,code=code,kind=kind,event=M.clean(event,90),reason=reason,map=map,caller=caller,
   requested=M.clean(f.requested or f.mode or f.provider or self.context.requested,48),
   actual=M.clean(f.actual or (code=='D14' and 'VANILLA / 2D') or f.fallbackStatus,48),
   x=M.clean(f.cellX or self.context.x,12),y=M.clean(f.cellY or self.context.y,12),
   platform=M.clean(f.platform or self.context.platform,40),version=M.clean(self.context.version,32),
   engine=M.clean(self.context.engine,32),session=M.clean(self.context.session,64),first=now,last=now,count=1,unread=true}
  table.insert(self.items,1,r);if #self.items>M.LIMIT then table.remove(self.items)end
  self.unread=0;for _,v in ipairs(self.items)do if v.unread then self.unread=self.unread+1 end end
  if self.onNew then pcall(self.onNew,r)end
  return r,true
 end
 function self:read(r)if r and r.unread then r.unread=false;self.unread=math.max(0,self.unread-1)end end
 return self
end
return M
