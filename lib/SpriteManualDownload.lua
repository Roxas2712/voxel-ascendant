-- Manual recovery shares exactly the catalog pins used by automatic downloads.
-- Host actions are explicit capabilities; unavailable clipboard never reports success.
local M={}
local function https(url)
  return type(url)=='string' and #url<=2048 and url:match('^https://[%w.-]+/') and not url:find('[%s\\]')
end
function M.new(d)
  local self={}
  function self:links(id)
    if not d.catalog.packages[id] then return {} end
    local result={}
    for _,r in ipairs((d.links or {})[id] or {})do
      if https(r.url) and type(r.label)=='string' then result[#result+1]={label=r.label,url=r.url}end
    end
    return result
  end
  function self:text(id)
    local rows={};for _,r in ipairs(self:links(id))do rows[#rows+1]=r.url end
    return table.concat(rows,'\n')
  end
  function self:copy(id,index)
    local links=self:links(id);local value=index and links[index] and links[index].url or (not index and self:text(id))
    if not value or value=='' then return false,'no_manual_links' end
    if not d.copy then return false,'clipboard_unavailable' end
    local ok,yes=pcall(d.copy,value)
    return ok and yes==true,ok and yes==true and 'links_copied' or 'clipboard_unavailable'
  end
  function self:open(id,index)
    local r=self:links(id)[index]
    if not r then return false,'no_manual_links' end
    if not d.open then return false,'browser_unavailable' end
    local ok,yes=pcall(d.open,r.url)
    return ok and yes==true,ok and yes==true and 'browser_opened' or 'browser_unavailable'
  end
  function self:show(session,id,de)
    local function tr(en,german)return de and german or en end
    local rows={{label=tr('LINK PAGE / QR CODE','LINKLISTE / QR-CODE'),action='linkCard'},{label=tr('COPY ALL LINKS','ALLE LINKS KOPIEREN'),action='copyAll'}}
    for i,r in ipairs(self:links(id))do
      rows[#rows+1]={label=r.label..tr(' / COPY',' / KOPIEREN'),action='copy',index=i,help=r.url}
      rows[#rows+1]={label=r.label..tr(' / OPEN',' / ÖFFNEN'),action='open',index=i,help=r.url}
    end
    rows[#rows+1]={label=tr('CHOOSE DOWNLOADED FILE / IMPORT','HERUNTERGELADENE DATEI IMPORTIEREN'),action='import'}
    return session:pushMenu('vasc_manual_'..id,tr('DOWNLOAD KEEPS FAILING?','DOWNLOAD SCHLÄGT WEITER FEHL?'),rows,function(row)
      if row.action=='linkCard' then return session:openLinkCard(id)end
      if row.action=='import' then return session:openPackageImport(id)end
      local ok,why
      if row.action=='copyAll' then ok,why=self:copy(id)
      elseif row.action=='copy' then ok,why=self:copy(id,row.index)
      elseif row.action=='open' then ok,why=self:open(id,row.index)end
      if not ok and (why=='clipboard_unavailable' or why=='browser_unavailable')then return session:openLinkCard(id)end
      session:notice(why)
    end,tr('Copy the COMPLETE link carefully, including any link key. Open it in your browser on this or another device. Download ONE matching package file, keep it unchanged, transfer it to the device running Ascendant, then select IMPORT below. If clipboard is unavailable, open the link list on your phone or computer and select/copy the text there.',
      'Den VOLLSTÄNDIGEN Link sorgfältig kopieren, auch einen möglichen Link-Schlüssel. Im Browser auf diesem oder einem anderen Gerät öffnen. EINE passende Paketdatei unverändert herunterladen und auf das Ascendant-Gerät übertragen. Dann unten IMPORTIEREN wählen. Ohne Zwischenablage die Linkliste auf Handy oder Computer öffnen und den Text dort markieren/kopieren.'))
  end
  return self
end
return M
