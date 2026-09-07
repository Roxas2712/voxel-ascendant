local M={}
local STATUS_DE={idle="BEREIT",checking="PRÜFUNG",downloading="LÄDT",ready="FERTIG",cancelled="ABGEBROCHEN",error="FEHLER"}
local MESSAGE_DE={
  ["Public download source not configured"]="Die öffentliche Download-Quelle ist noch nicht eingerichtet. Bereits installierte Pakete bleiben nutzbar.",
  ["Checking available packages"]="Verfügbare Pakete werden geprüft.",
  ["Download verified. Restart the game to enable HD."]="Download geprüft. Spiel neu starten, um HD zu aktivieren.",
  ["All selected packages are installed"]="Alle gewählten Pakete sind installiert.",
  ["Stopped. Verified chunks are retained for resume."]="Abgebrochen. Geprüfte Teile bleiben zum Fortsetzen erhalten.",
  ["Catalog checked; choose a generation or package"]="Katalog geprüft. Generation oder Paket wählen.",
  ["Network unavailable in this engine"]="Diese Spielversion stellt keine Download-Verbindung bereit.",
  ["Network unavailable"]="Keine Netzwerkverbindung verfügbar.",
  ["Network polling failed"]="Die Netzwerkabfrage ist fehlgeschlagen.",
  ["Request failed; choose download to resume"]="Anfrage fehlgeschlagen. Download erneut wählen, um fortzusetzen.",
  ["Response exceeds content limit"]="Die Serverantwort überschreitet die erlaubte Größe.",
  ["Invalid content catalog"]="Der Inhaltskatalog ist ungültig.",
  ["Catalog downgrade rejected"]="Ein veralteter Katalog wurde abgelehnt.",
  ["Manifest does not match catalog"]="Die Paketbeschreibung passt nicht zum Katalog.",
  ["Package size mismatch"]="Die Paketgröße stimmt nicht überein.",
  ["Truncated chunk"]="Ein Download-Teil ist unvollständig.",
  chunk_verification_failed="Die Prüfsumme eines Download-Teils stimmt nicht.",
  cache_write_failed="Die Download-Daten konnten nicht gespeichert werden.",
  manifest_verification_failed="Die Paketbeschreibung konnte nicht geprüft werden.",
  incomplete_package="Das Paket ist noch unvollständig.",
  manifest_write_failed="Die Paketbeschreibung konnte nicht gespeichert werden.",
  activation_write_failed="Die Paketaktivierung konnte nicht gespeichert werden.",
  revision_not_newer="Diese Paketversion ist bereits installiert oder veraltet.",
  path_conflict="Das Paket kollidiert mit einer bereits installierten Datei.",
  journal_limit="Die maximale Zahl gespeicherter Aktivierungen wurde erreicht.",
}
local function message(d,de)
  local raw=tostring(d.message or "")
  if raw==""then return raw end
  if MESSAGE_DE[raw]then return de and MESSAGE_DE[raw] or raw end
  local first,last=raw:match("^apo%.pokemon%-hd%.g%d+%.dex(%d+)%-(%d+)$")
  -- Native bitmap fonts interpret # as the POKe ligature and do not have an
  -- en-dash glyph. Keep the range literal in both generations' help panes.
  if first then return (de and "Paket %d-%d wird geladen." or "Downloading package %d-%d."):format(tonumber(first),tonumber(last))end
  -- Transport errors may contain private origins, tokens and arbitrarily
  -- long URLs. Show bounded diagnoses, never untrusted raw fetch output.
  if raw:find("curl: %(60%)") or raw:find("SSL",1,true) then
    return de and "Sichere Verbindung fehlgeschlagen (TLS/Zertifikat). Kein Download."
      or "Secure connection failed (TLS/certificate). No download."
  end
  return de and "Download fehlgeschlagen. Verbindung prüfen und erneut versuchen."
    or "Download failed. Check the connection and try again."
end
local function warnings(d,de)
  local value=""
  if d.warnings and d.warnings.fallback_used then
    value=value.."\n\n"..(de and "Alternative Downloadquelle wird verwendet."
      or "Using alternative download source.")
  end
  if d.warnings and d.warnings.receipt_unconfirmed then
    value=value.."\n\n"..(de and "Download-Zählung nicht bestätigt. Geprüfte Pakete bleiben nutzbar."
      or "Download count not confirmed. Verified packages remain usable.")
  end
  if d.warnings and d.warnings.catalog_not_saved then
    value=value.."\n\n"..(de and "Katalog nur für diese Sitzung verfügbar: Speichern fehlgeschlagen."
      or "Catalog available for this session only: saving failed.")
  end
  return value
end
function M.offer(mod,game,guided,de,spec)
  assert(type(spec)=="table" and type(spec.decide)=="function")
  local function tr(en,german)return de and german or en end
  local help=string.format(tr("%d new HD stages (%.1f MB). Choose downloads or Later. No automatic download. Always available in Pokemon + Models. HD characters stay included.",
    "%d neue HD-Etappen (%.1f MB). Downloads auswählen oder Später. Kein automatischer Download. Immer unter Pokemon + Modelle verfügbar. HD-Charaktere bleiben enthalten."),spec.count,spec.bytes/1024/1024)
  -- The portrait side pane is deliberately compact. Keep its selected-row
  -- explanation complete; the HELP row retains the detailed paginated text.
  local summary=string.format(tr("%d HD stages\n%.1f MB\n", "%d HD-Etappen\n%.1f MB\n"),
    spec.count,spec.bytes/1024/1024)
  local laterHelp=summary..tr("Not now. Find them in Pokemon + Models.",
    "Nicht jetzt. Unter Pokemon + Modelle laden.")
  local reviewHelp=summary..tr("Choose packages. Confirm before downloading.",
    "Pakete wählen. Vor dem Laden bestätigen.")
  local menu
  menu=guided(mod,game,{key="vasc_hd_startup_offer",title=tr("POKEMON HD","POKéMON-HD"),
    help=help,footer=tr("A:SELECT SEL:HELP B:LATER","A:WAHL SEL:HILFE B:SPÄTER"),
    rows={{label=tr("LATER","SPÄTER"),action="later",help=laterHelp},
      {label=tr("CHOOSE DOWNLOADS","DOWNLOADS AUSWÄHLEN"),action="review",help=reviewHelp}},
    onChoose=function(item,owner)
      if not item or (item.action~="later" and item.action~="review")then return end
      if game.stack:top()~=(owner or menu)then return end
      if item.action=="review"then
        -- Build first: a failed download screen must not dismiss the offer.
        local Screens=require("src.ui.Screens")
        local nextMenu=Screens.build(game,"VascPokemonHdDownloads")
        spec.decide();game.stack:pop();game.stack:push(nextMenu)
      else spec.decide();game.stack:pop()end
    end})
  local cancel=menu.onCancel
  menu.onCancel=function(...)spec.decide();if cancel then return cancel(...)end end
  return menu
end
function M.new(mod,game,guided,de)
  local api=mod.exports and mod.exports.pokemonHdContent
  local d=api and api.downloader()
  local function tr(en,german)return de and german or en end
  local help=tr("Optional Pokemon HD downloads. Choose a generation or one stage, then press A again to approve its size. Cancel keeps verified chunks for resume. After downloading, restart the game. HD people stay installed; missing Pokemon use MMO/original sprites. Downloads are counted anonymously, not by device.",
    "Optionale Pokemon-HD-Pakete: Generation oder Etappe wählen, dann Größe mit A bestätigen. Abbruch behält geprüfte Teile zum Fortsetzen. Danach Spiel neu starten. HD-Menschen bleiben installiert; fehlende Pokemon nutzen MMO/Original. Downloads werden anonym ohne Gerätekennung gezählt.")
  local rows,armed={},nil
  local function build()
    rows={
      {label=tr("DOWNLOAD STATUS","DOWNLOAD-STATUS"),action="status",right="",help=help},
      {label=tr("CHECK FOR UPDATES","UPDATES PRÜFEN"),action="check",help=help},
      {label=tr("CANCEL / KEEP PARTS","ABBRECHEN / TEILE BEHALTEN"),action="cancel",help=help},
    }
    for gen=1,9 do
      local bytes,count=0,0
      if d then for _,p in ipairs(d.catalog.packages)do
        if p.rosterGeneration==gen and not d:installed(p)then bytes=bytes+p.fileBytes;count=count+1 end
      end end
      rows[#rows+1]={label=tr("GENERATION ","GENERATION ")..gen,
        generation=gen,action="download",bytes=bytes,muted=count==0,
        right=count>0 and string.format("%.0f MB",bytes/1024/1024) or "--",help=help}
    end
    if d then for _,p in ipairs(d.catalog.packages)do
      local a,b=p.id:match("dex(%d+)%-(%d+)$")
      rows[#rows+1]={label=string.format("%d-%d",tonumber(a),tonumber(b)),
        packageId=p.id,action="download",bytes=p.fileBytes,
        muted=d:installed(p),right=d:installed(p) and tr("INSTALLED","INSTALLIERT")
          or string.format("%.0f MB",p.fileBytes/1024/1024),help=help}
    end end
  end
  build()
  local menu=guided(mod,game,{key="vasc_pokemon_hd_downloads",title=tr("POKEMON HD DOWNLOADS","POKéMON-HD-DOWNLOADS"),
    help=help,rows=rows,footer=tr("A:SELECT  SEL:HELP  B:BACK","A:WAHL  SEL:HILFE  B:ZURÜCK"),
    onChoose=function(item,owner)
      if not item or not d then return end
      if item.action=="status" then
        if owner and type(owner.onSelectKey)=="function"then return owner.onSelectKey(item,owner)end
        return
      end
      if item.action=="cancel"then armed=nil;return d:cancel()end
      if item.action=="check"then armed=nil;return d:check()end
      if item.action~="download" or item.muted or d:busy()then return end
      local key=item.packageId or item.generation
      if armed~=key then
        armed=key;item.right=tr("A:CONFIRM","A:BESTÄTIGEN")
        item.help=string.format(tr("Download %.1f MB from the VASC content server? A confirms. No automatic paid/cellular-data check; use Wi-Fi if needed. Restart after completion.",
          "%.1f MB vom VASC-Server laden? A bestätigt. Keine automatische Mobilfunkprüfung; bei Bedarf WLAN nutzen. Danach neu starten."),item.bytes/1024/1024)
        return
      end
      armed=nil;d:start(item.generation,item.packageId,true)
    end})
  local update=menu.update
  local lastCatalog=d and d.catalog;local lastEpoch=d and d.store.epoch
  function menu:update(...)
    if d then d:update()end
    if d and (lastCatalog~=d.catalog or lastEpoch~=d.store.epoch)then
      lastCatalog,lastEpoch=d.catalog,d.store.epoch
      local helpRow=self.items and self.items[#self.items]
      build();self.items={};for i,row in ipairs(rows)do self.items[i]=row end
      if helpRow and (helpRow.__kascFeatureHelp or tostring(helpRow.value):find("vasc_help"))then self.items[#self.items+1]=helpRow end
    end
    local row=self.items and self.items[1] or rows[1]
    if row then
      row.right=d and (d:busy() and string.format("%.0f/%.0f MB",d.doneBytes/1024/1024,d.totalBytes/1024/1024)
        or d.changed and tr("RESTART","NEUSTART") or (de and STATUS_DE[d.status] or d.status:upper())) or tr("UNAVAILABLE","NICHT VERFÜGBAR")
      row.help=d and (message(d,de)..warnings(d,de).."\n\n"..help) or help
    end
    return update(self,...)
  end
  return menu
end
return M
