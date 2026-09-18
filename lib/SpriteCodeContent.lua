-- Automatic content fulfillment for VALIDATED Pokémon code receipts only.
-- This module never sees plaintext codes and never grants/consumes a reward.
-- resolve(eventId) uses the trusted reward profile's exact sprite/form/palette contract.
local M={KEY="sprite-content/code-content-pending-v1.json"}
local function id(s)return type(s)=="string" and #s<=160 and s:match("^[a-zA-Z0-9_.:-]+$")end
function M.new(d)
  assert(d.catalog and d.store and d.resolve and d.cache and d.encode and d.decode,"missing code-content adapter")
  local self={queue={},state="idle"}
  local ok,raw=pcall(d.cache.read,d.cache,M.KEY)
  if ok and raw then
    local yes,q=pcall(d.decode,raw)
    if not yes or type(q)~="table" or #q>128 then self.state="error";self.error="invalid_code_content_queue"
    else
      for _,row in ipairs(q)do
        if type(row)~="table" or not id(row.receiptKey) or not id(row.eventId) then self.state="error";self.error="invalid_code_content_queue";break end
      end
      if self.state~="error" then self.queue=q end
    end
  elseif not ok then self.state="error";self.error="code_content_read_failed" end
  local function save()
    local raw=d.encode(self.queue)
    local ok,yes=pcall(d.cache.write,d.cache,M.KEY,raw)
    local read,back=pcall(d.cache.read,d.cache,M.KEY)
    return ok and yes==true and read and back==raw
  end
  local function plan(row)
    -- Re-resolve each time, never trust URLs/package lists from code text or a saved queue.
    local ok,keys=pcall(d.resolve,row.eventId)
    if not ok or type(keys)~="table" or #keys==0 then return nil,"sprite_contract_missing" end
    local yes,p=pcall(d.catalog.plan,d.catalog,keys,d.store)
    if not yes then return nil,"sprite_contract_invalid" end
    return p
  end
  function self:enqueue(receiptKey,eventId,validated)
    if validated~=true then return false,"code_not_validated" end
    if self.error or not id(receiptKey) or not id(eventId) then return false,self.error or "invalid_receipt" end
    for _,row in ipairs(self.queue) do
      if row.receiptKey==receiptKey then
        return row.eventId==eventId,row.eventId==eventId and "already_queued" or "receipt_conflict"
      end
    end
    if #self.queue>=128 then return false,"code_content_queue_full" end
    local row={receiptKey=receiptKey,eventId=eventId};local p,err=plan(row)
    if not p then return false,err end
    self.queue[#self.queue+1]=row
    if not save() then table.remove(self.queue);return false,"code_content_write_failed" end
    return true,p.ready and "already_installed" or "queued"
  end
  function self:retry()
    if self.error then return false,self.error end
    if self.state=="downloading" then return false,"busy" end
    self.state="idle";return true
  end
  function self:update()
    if self.error or self.state=="waiting_retry" or self.state=="waiting_restart" then return end
    local row=self.queue[1];if not row then self.state="idle";return end
    if self.state=="downloading" then
      -- Shared session owns installer ticking; this module only observes completion.
      if d.installer.state=="error" or d.installer.state=="cancelled" then self.state="waiting_retry";return end
      if d.installer.state~="ready" then return end
      self.state="idle"
    end
    local p,err=plan(row)
    if not p then self.state="waiting_retry";self.lastError=err;return end
    if p.ready then
      for _,key in ipairs(p.packages)do
        if not d.store:packageMounted(key) then self.state="waiting_restart";return end
      end
      -- Caller continues the existing idempotent code ledger; no second Pokémon grant.
      local ok,yes=pcall(d.onReady,row.receiptKey,row.eventId)
      if not ok or yes~=true then self.state="waiting_retry";return end
      table.remove(self.queue,1)
      if not save() then table.insert(self.queue,1,row);self.state="waiting_retry";return end
      self.state="idle";return
    end
    if not p.canDownload then self.state="waiting_retry";self.lastError="sprite_not_published";return end
    if not d.safe or d.safe()~=true or (d.busy and d.busy()) then return end
    -- Validating/submitting the code includes its disclosed sprite download.
    -- No second download prompt and no whole-generation preset.
    local ok,yes=pcall(d.installer.start,d.installer,p,true)
    if not ok or yes~=true then self.state="waiting_retry";return end
    self.state="downloading"
  end
  return self
end
return M
