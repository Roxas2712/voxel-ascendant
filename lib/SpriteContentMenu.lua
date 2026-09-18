-- Drop-in screen factory for VascPokemonHdDownloads using the existing guided menu.
-- Session owns the shared installer, exact import availability and safe removal service.
local M={SCREEN="VascPokemonHdDownloads"}
function M.new(mod,game,guided,de,session)
  assert(session and session.model and session.removal,"missing unified content session")
  local function tr(en,german)return de and german or en end
  local function push(menu)game.stack:push(menu)end
  local function notice(reason)if session.notice then session:notice(reason)end end
  local function busy()
    local job,err=session.removal:pending()
    return job~=nil or err~=nil or (session.maintenance and session.maintenance:pending()~=nil) or (session.busy and session:busy())
  end
  local function make(key,title,rows,choose,help)
    local builder=type(rows)=='function' and rows or nil
    local menu=guided(mod,game,{key=key,title=title,rows=builder and builder() or rows,help=help or "",
      footer=tr("A:SELECT SEL:HELP B:BACK","A:WAHL SEL:HILFE B:ZURÜCK"),onChoose=choose})
    menu.ascendantContentInventory=true
    menu.showFirstGuide=function()return false end
    if builder and menu.items then
      local update,epoch=menu.update,session.epoch
      function menu:update(...)
        if epoch~=session.epoch then
          epoch=session.epoch;local helpRow
          for _,r in ipairs(self.items)do if r.value=='__vasc_help' or r.value=='__kasc_help' then helpRow=r end end
          local fresh=builder();if helpRow then fresh[#fresh+1]=helpRow end
          self.items=fresh;self.index=math.max(1,math.min(self.index or 1,#fresh))
        end
        if update then return update(self,...)end
      end
    end
    return menu
  end
  local batchHelp=tr('Base + all HD. Only missing files. Then save + restart.',
    'Basis + alle HD. Nur fehlende Dateien. Dann speichern + Neustart.')
  local function selection(group)
    local families={}
    local function include(g)
      if g.children then for _,child in ipairs(g.children)do include(child)end else families[g.id]=true end
    end
    if group then include(group)end
    local ids,checking={},false
    for _,g in ipairs(session.model:groups())do if not group or families[g.id]then
      for _,p in ipairs(g.packages)do
        ids[#ids+1]=p.id
        if not p.installed and p.localFiles and p.localFiles.checking then checking=true end
      end
    end end
    return ids,session:planFor(ids),checking
  end
  local function downloadSelection(group)
    if session.pendingDownloadIds or session.installer and session.installer.state=='downloading'then return session:openStatus()end
    if busy()then return notice('busy_or_restart_required')end
    local ids,plan,checking=selection(group)
    if plan.ready then return notice('already_installed')end

    if not plan.canDownload then return notice('not_yet_available')end
    return session:confirmDownload(ids)
  end
  local function allRow(group)
    if session.pendingDownloadIds or session.installer and session.installer.state=='downloading'then return {label=tr('VIEW ACTIVE DOWNLOAD','LAUFENDEN DOWNLOAD ANZEIGEN'),action='all',help=batchHelp}end
    local ids,plan,checking=selection(group)
    local checked,total=0,0;if session.inventoryProgress then checked,total=session:inventoryProgress(ids)end
    local status=checking and (tr('Checking: ','Pruefung: ')..checked..'/'..total..'. ')or plan.ready and tr('Already installed. ','Bereits installiert. ')or string.format('%.1f MiB. ',plan.downloadBytes/1048576)
    return {label=group and tr('DOWNLOAD / UPDATE','LADEN / AKTUALISIEREN')or tr('DOWNLOAD / UPDATE ALL','ALLES LADEN / UPDATEN'),action='all',
      muted=false,help=status..(group and group.help or batchHelp)}
  end
  local function confirmDelete(id,p)
    if busy() then return notice("busy_or_restart_required") end
    local localFiles=p and p.localFiles
    local external=localFiles and not localFiles.checking and localFiles.present>0
    push(make("vasc_content_delete_"..id,tr("DELETE PACKAGE?","PAKET LÖSCHEN?"),{
      {label=tr("CANCEL","ABBRECHEN"),action="cancel"},
      {label=tr("DELETE","LÖSCHEN"),action="delete"}},function(row)
        if row.action=="cancel" then return game.stack:pop() end
        if row.action=="delete" then
          if external then
            local ok,why=session.bundledRemoval:request(id,true)
            if not ok then return notice(why)end
            local receipt=session.store:receipt(id)
            if receipt or p.cachePartial then
              local removed,err=session.removal:request(id,true)
              if not removed then return notice(err)end
            end
            game.stack:pop()
            return notice(tr('Removal requested. Close the game, run manage-sprites.py from the desktop update bundle, then restart. Local files stay until the helper confirms removal.',
              'Entfernen vorgemerkt. Spiel schliessen, manage-sprites.py aus dem Desktop-Updatepaket starten, dann neu starten. Alte Dateien bleiben bis zur bestaetigten Entfernung durch den Helfer.'))
          end
          local ok,why=session.removal:request(id,true)
          if ok then game.stack:pop() end
          notice(why)
        end
      end,external and tr('Includes old built-in files. The engine cannot delete them in-game. This prepares a desktop helper request with backup; no files are deleted now. Close the game before running the helper.',
        'Enthaelt alte Moddateien. Die Engine kann diese nicht im Spiel loeschen. Bereitet den Desktop-Helfer mit Backup vor; jetzt wird nichts geloescht. Vor dem Helfer das Spiel schliessen.')
        or tr("Deletion happens on restart. Shared files stay. Missing sprites use the original style.",
        "Löschen erfolgt beim Neustart. Gemeinsame Dateien bleiben erhalten. Fehlende Sprites nutzen den Originalstil.")))
  end
  local function packageMenu(p)
    if session.bundledRemoval then session.bundledRemoval:prioritize(p.id)end
    local function packageRows()
      for _,group in ipairs(session.model:groups())do for _,fresh in ipairs(group.packages)do if fresh.id==p.id then p=fresh end end end
    local rows={{label=tr("STATUS","STATUS"),right=p.statusLabel,action="status"}}
    if p.localFiles then
      local f=p.localFiles
      rows[#rows+1]={label=tr('OLD MOD FILES','ALTE MODDATEIEN'),right=f.checking and tr('CHECKING','PRUEFUNG') or (f.present..' / '..f.total),
        help=tr('Actual files in this mod. Presence does not claim verified download checksums. Partial sets remain usable and can be completed by a download.',
          'Tatsaechliche Dateien dieser Mod. Vorhandensein ist keine verifizierte Download-Pruefsumme. Teilsammlungen bleiben nutzbar und koennen per Download ergaenzt werden.')}
      local job=session.bundledRemoval and session.bundledRemoval:pending()
      if job and job.packageIds[1]==p.id and f.present>0 then
        rows[#rows+1]={label=tr('EXTERNAL REMOVAL PENDING','EXTERNES ENTFERNEN AUSSTEHEND'),action='externalHelp'}
        rows[#rows+1]={label=tr('CANCEL REMOVAL REQUEST','ENTFERNAUFTRAG ABBRECHEN'),action='cancelExternal'}
      end
    end
    if p.installed then
      rows[#rows+1]={label=tr("ALREADY INSTALLED","BEREITS INSTALLIERT"),action="status"}
    else
      rows[#rows+1]={label=tr("DOWNLOAD","HERUNTERLADEN"),right=string.format("%.1f MiB",p.downloadBytes/1048576),action="download",muted=not p.downloadable}
    end
    rows[#rows+1]={label=tr("CHOOSE FILE / IMPORT","DATEI WÄHLEN / IMPORTIEREN"),action="packageImport"}
    rows[#rows+1]={label=tr("Download keeps failing? Click here.","Download schlägt fehl? Hier klicken."),action="manual"}
    -- Visible even before installation; unused delete explains there's nothing to remove.
    rows[#rows+1]={label=tr("DELETE","LÖSCHEN"),action="delete",muted=not p.canDelete}
    return rows
    end
    local first,last=p.id:match('dex(%d+)%-(%d+)')
    local title=first and ('POKEMON '..tonumber(first)..'-'..tonumber(last))or tr('SPRITE PACKAGE','SPRITE-PAKET')
    push(make("vasc_content_package_"..p.id,title,packageRows,function(row)
      if row.action=='externalHelp' then
        return notice(tr('Close the game. Run manage-sprites.py from the update bundle and select this mod and its shared cache. Restart after the helper confirms removal.',
          'Spiel schliessen. manage-sprites.py aus dem Updatepaket starten und diese Mod samt gemeinsamem Cache waehlen. Nach bestaetigter Entfernung neu starten.'))
      elseif row.action=='cancelExternal' then
        local inv=session.bundledRemoval
        local cached=session.removal:pending()
        if cached and cached.id==p.id then
          local key='sprite-content/removal-pending-v1.json'
          if session.cache:remove(key)~=true or session.cache:read(key)~=nil then return notice('queue_remove_failed')end
        end
        local ok,why=inv:cancel(p.id);session.epoch=session.epoch+1
        return notice(why)
      elseif row.action=='megaCollection' then
        local exports=game.mods and game.mods.exports
        local kasc=exports and exports.kanto_ascendant
        local collections=kasc and kasc.megaSpriteCollections
        if not collections then return notice('kasc_required')end
        local ok,why=collections:select(game,row.version)
        if ok then notice(tr('Mega collection selected.','Mega-Sammlung ausgewaehlt.'))
        elseif why~='sprite_download_required' then notice(why)end
        return
      elseif row.action=="packageImport" then
        if busy() then return notice("busy_or_restart_required")end
        return session:openPackageImport(p.id)
      elseif row.action=="manual" then return session:openManual(p.id,de)
      elseif row.action=="delete" then
        if p.localFiles and p.localFiles.checking then return notice(tr('Checking existing files. Please wait.','Vorhandene Dateien werden geprueft. Bitte warten.'))end
        if not p.canDelete then return notice("not_installed") end
        return confirmDelete(p.id,p)
      elseif row.action=="download" then
        if p.localFiles and p.localFiles.checking then return notice(tr('Checking existing files. Please wait.','Vorhandene Dateien werden geprueft. Bitte warten.'))end
        if busy() then return notice("busy_or_restart_required") end
        if not p.downloadable then return notice("not_yet_available") end
        -- Session opens the existing size-confirmation view, replans at confirmation.
        return session:confirmDownload({p.id})
      end
    end))
  end
  local function packageList(g,packages,title)
    local function rows()
      local result={}
      for _,fresh in ipairs(session.model:groups())do if fresh.id==g.id then
        for _,p in ipairs(fresh.packages)do if not packages or packages[p.id]then
          local first,last=p.id:match("dex(%d+)%-(%d+)")
          local label=first and (tonumber(first).."-"..tonumber(last))
            or p.id:find('pokemon-hoenn-legacy',1,true)and tr('STARTERS 252-260','STARTER 252-260')
            or p.id:find('pokemon-mega-original-20260830',1,true)and tr('FULL MEGA ANIMATIONS','VOLLE MEGA-ANIMATIONEN')
            or tr('PART ','TEIL ')..tonumber(p.id:match('part(%d+)$')or 1)
          result[#result+1]={label=label,right=p.statusLabel,package=p,help=g.help}
        end end
      end end
      return result
    end
    push(make("vasc_content_group_"..g.id,title or g.label,rows,function(row)
      if row.package then packageMenu(row.package)end
    end,g.help))
  end
  local function hdCollections(g)
    local names={"KANTO","JOHTO","HOENN"}
    local ranges={"1-151","152-251","252-386"}
    local function collection(generation)
      local c={ids={},selected={},installed=0,checking=false}
      for _,fresh in ipairs(session.model:groups())do if fresh.id==g.id then
        for _,p in ipairs(fresh.packages)do
          local gen=tonumber(p.id:match("%.g(%d+)%."))
          if not generation or gen==generation then
            c.ids[#c.ids+1]=p.id;c.selected[p.id]=true
            if p.installed then c.installed=c.installed+1 end
            c.checking=c.checking or (p.localFiles and p.localFiles.checking) or false
          end
        end
      end end
      c.plan=session:planFor(c.ids)
      c.complete=#c.ids>0 and c.installed==#c.ids
      c.status=c.complete and tr("Installed","Installiert")
        or c.checking and tr("Checking","Pruefung")
        or c.installed>0 and tr("Partial","Teilweise") or tr("Available","Verfuegbar")
      return c
    end
    local function download(generation)
      if busy()then return notice("busy_or_restart_required")end
      local c=collection(generation)
      if c.complete then return notice("already_installed")end
      
      if not c.plan.canDownload then return notice("not_yet_available")end
      return session:confirmDownload(c.ids)
    end
    local function generationMenu(gen)
      local help=tr("HD walking sprites for ","HD-Laufsprites fuer ")..names[gen].." ("..ranges[gen].."). "
        ..tr("Only missing content is downloaded.","Nur fehlende Inhalte werden geladen.")
      push(make("vasc_content_hd_generation_"..gen,names[gen].." HD",function()
        local c=collection(gen)
        return {
          {label=tr("STATUS","STATUS"),right=c.status,help=help},
          {label=c.complete and tr("ALREADY INSTALLED","BEREITS INSTALLIERT") or tr("DOWNLOAD","LADEN"),
            right=c.complete and "" or string.format("%.1f MiB",c.plan.downloadBytes/1048576),action="download",muted=c.complete,help=help},
          {label=tr("IMPORT FILE","DATEI IMPORTIEREN"),action="import",help=tr("Import a manually downloaded sprite package.","Ein manuell heruntergeladenes Sprite-Paket importieren.")},
          {label=tr("MANAGE / DELETE","VERWALTEN / LOESCHEN"),action="manage",help=help},
          {label=tr("DOWNLOAD FAILED?","DOWNLOAD-FEHLER?"),action="manual",help=tr("Choose a missing package, then open its alternative download links. You can import the downloaded file here.","Fehlendes Paket waehlen und dessen alternative Downloadlinks oeffnen. Die heruntergeladene Datei kannst du hier importieren.")},
        }
      end,function(row)
        if row.action=="download"then return download(gen)end
        if row.action=="import"then
          if busy()then return notice("busy_or_restart_required")end
          return session:openPackageImport()
        end
        if row.action=="manage"or row.action=="manual"then
          return packageList(g,collection(gen).selected,names[gen]..tr(" - MANAGE"," - VERWALTEN"))
        end
      end,help))
    end
    local help=tr("HD walking sprites: Kanto, Johto and Hoenn. Only missing content is downloaded.",
      "HD-Pokemon aus Kanto, Johto und Hoenn. Nur fehlende Inhalte werden geladen.")
    return push(make("vasc_content_hd_collections",tr("HD POKEMON","HD-POKEMON"),function()
      local all=collection()
      local rows={{label=all.complete and tr("ALREADY INSTALLED","BEREITS INSTALLIERT") or tr("ALL HD","ALLE HD"),
        action="all",right=all.complete and "" or string.format("%.0f MiB",all.plan.downloadBytes/1048576),muted=all.complete,help=help}}
      for gen=1,3 do local c=collection(gen)
        if #c.ids>0 then rows[#rows+1]={label=names[gen],right=c.status,generation=gen,
          help=names[gen].." HD ("..ranges[gen].."). "..tr("Download only missing sprites of this generation. Open to import, manage or delete.",
            "Nur fehlende Sprites dieser Generation laden. Oeffnen fuer Import, Verwaltung und Loeschen.")}end
      end
      return rows
    end,function(row)
      if row.action=="all"then return download()end
      if row.generation then return generationMenu(row.generation)end
    end,help))
  end
  local function groupsMenu(g)
    if g.children and g.id~='pokemon'then
      local function children()
        local rows={allRow(g)}
        for _,child in ipairs(g.children)do rows[#rows+1]={label=child.label,group=child,help=child.help}end
        return rows
      end
      return push(make('vasc_content_category_'..g.id,g.label,children,function(row)
        if row.action=='all'then return downloadSelection(g)end
        if row.group then groupsMenu(row.group)end
      end,g.help or batchHelp))
    end
    if g.id=="pokemon-hd-3d"then return hdCollections(g)end
    return push(make('vasc_content_collection_'..g.id,g.label,function()
      return {allRow(g),
        {label=tr('IMPORT FILE','DATEI IMPORTIEREN'),action='import',help=tr('Import a sprite package downloaded in your browser.','Ein im Browser geladenes Sprite-Paket importieren.')},
        {label=tr('MANAGE / DELETE','VERWALTEN / LOESCHEN'),action='manage',help=tr('Check installed parts, delete a part, or download individual Pokemon ranges.','Installierte Teile ansehen, loeschen oder einzelne Pokemon-Bereiche laden.')},
        {label=tr('DOWNLOAD FAILED?','DOWNLOAD-FEHLER?'),action='manual',help=tr('Choose a part to copy alternative download links and import its file.','Teil auswaehlen, alternative Downloadlinks kopieren und die Datei importieren.')}}
    end,function(row)
      if row.action=='all'then return downloadSelection(g)end
      if row.action=='manage'or row.action=='manual'then
        if g.id=='pokemon'then
          local rows={};for _,child in ipairs(g.children)do rows[#rows+1]={label=child.label,group=child}end
          return push(make('vasc_content_base_manage',tr('MANAGE BASE PACK','BASISPAKET VERWALTEN'),rows,function(row)
            if row.group then return packageList(row.group)end
          end,tr('Advanced: installed files, deletion, imports and alternative links. Downloads always complete the whole base pack.','Erweitert: installierte Dateien, Loeschen, Import und alternative Links. Downloads vervollstaendigen immer das gesamte Basispaket.')))
        end
        return packageList(g)
      end
      if row.action=='import'then
        if session.pendingDownloadIds or session.installer and session.installer.state=='downloading'then return session:openStatus()end
    if busy()then return notice('busy_or_restart_required')end
        return session:openPackageImport()
      end
    end,g.help..' '..batchHelp))
  end
  local function importMenu(p)
    local function importRows()
      for _,fresh in ipairs(session.model:imports())do if fresh.id==p.id then p=fresh end end
      return {
      {label=tr("STATUS","STATUS"),right=p.statusLabel},
      {label=tr("CHOOSE FILE / IMPORT","DATEI WÄHLEN / IMPORTIEREN"),action="import"},
      {label=tr("DELETE IMPORTED PACKAGE","IMPORTIERTES PAKET LÖSCHEN"),action="delete",muted=not p.canDelete}}
    end
    push(make("vasc_content_import_"..p.id,p.label,importRows,function(row)
        if row.action=="delete" then
          if not p.canDelete then return notice("not_installed") end
          return confirmDelete(p.id)
        elseif row.action=="import" then
          if busy() then return notice("busy_or_restart_required") end
          return session:openImport(p.id)
        end
      end,tr("Use the existing Stadium importer. Deletion removes the generated package; your source ROM stays.",
        "Nutzt den vorhandenen Stadium-Importer. Löschen entfernt das erzeugte Paket; deine Quell-ROM bleibt erhalten.")))
  end
  local function categoryGroups()
    local base={id='pokemon',label=tr('BASE SPRITE PACK','BASIS-SPRITEPAKET'),children={},
      help=tr('Crystal, Mega, animations, pixel sprites + icons. Complete pack.',
        'Crystal, Mega, Animationen, Pixel-Sprites + Icons. Komplettpaket.')}
    local hd={id='full-hd',label=tr('OPTIONAL HD SPRITES','OPTIONALE HD-SPRITES'),children={},
      help=tr('Optional HD sprites. Download all HD or select a collection.','Optionale HD-Sprites. Alle HD laden oder eine Sammlung waehlen.')}
    for _,g in ipairs(session.model:groups())do
      local bucket=g.id:match('^pokemon%-hd%-')and hd or base
      bucket.children[#bucket.children+1]=g
    end
    return {base,hd}
  end
  local function maintenanceMenu()
    local result={}
    result[#result+1]={label=tr('CHECK / REPAIR SPRITES','SPRITES PRUEFEN / REPARIEREN'),action='repair',help=tr('Check downloaded packs and repair interrupted or damaged downloads.','Geladene Pakete pruefen und unterbrochene oder beschaedigte Downloads reparieren.')}
    result[#result+1]={label=tr('REINSTALL DOWNLOADS','DOWNLOADS NEU INSTALLIEREN'),action='reinstall',help=tr('Clear the shared KASC/VASC sprite cache after restart and download previous packs again.','Gemeinsamen KASC/VASC-Spritecache nach Neustart leeren und bisherige Pakete neu laden.')}
    result[#result+1]={label=tr('DELETE ALL DOWNLOADS','ALLE DOWNLOADS LOESCHEN'),action='deleteAll',help=tr('Delete downloaded sprites and interrupted download files. Keep saves and Stadium imports.','Heruntergeladene Sprites und Downloadreste loeschen. Spielstaende und Stadium-Importe behalten.')}
    return push(make('sprite_maintenance',tr('SPRITE MAINTENANCE','SPRITES VERWALTEN'),result,function(row)
      return session:confirmMaintenance(row.action=='deleteAll'and'delete'or row.action)
    end,tr('Shared by KASC and VASC. Saves, bundled art and Stadium imports are kept.','Gemeinsam fuer KASC und VASC. Spielstaende, mitgelieferte Grafiken und Stadium-Importe bleiben.')))
  end
  local function rows()
    local buckets=categoryGroups()
    local result={allRow()}
    for _,bucket in ipairs(buckets)do
      if #bucket.children>0 then
        local _,plan,checking=selection(bucket)
        local details=bucket.help..' '..(plan.ready and tr('Already installed.','Bereits installiert.')or string.format('%.1f MiB.',plan.downloadBytes/1048576))
        result[#result+1]={label=bucket.label,group=#bucket.children==1 and bucket.children[1]or bucket,help=details}
      end
    end
    for _,p in ipairs(session.model:imports())do result[#result+1]={label='STADIUM 2',right=p.statusLabel,import=p,help=tr('Import your Stadium 2 file or remove its generated models. Your source file is kept.','Stadium-2-Datei importieren oder die erzeugten Modelle löschen. Die Quelldatei bleibt erhalten.')}end
    result[#result+1]={label=tr('SPRITE MAINTENANCE','SPRITES VERWALTEN'),action='maintenance',help=tr('Check, repair, reinstall or clear downloaded sprite packs.','Geladene Sprite-Pakete pruefen, reparieren, neu installieren oder leeren.')}
    result[#result+1]={label=tr('IMPORT FILE','DATEI IMPORTIEREN'),action='packageImport'}
    result[#result+1]={label=tr('DOWNLOAD STATUS','DOWNLOAD-STATUS'),action='status'}
    result[#result+1]={label=tr('STARTUP PROMPT','STARTABFRAGE'),right=session.promptDisabled and tr('OFF','AUS') or tr('ON','AN'),action='startupPrompt',help=tr('Show the graphics choice at startup while packs are missing. Select to turn this on or off.','Grafikauswahl beim Start zeigen, solange Pakete fehlen. Hier die Abfrage an- oder abschalten.')}
    result[#result+1]={label=tr('LOGS & REPORTS','LOGS & BERICHTE'),action='diagnostics'}
    for _,row in ipairs(result)do
      row.help=row.help or tr('Download Pokemon sprites or import a downloaded package. Installed packages show their status and can be deleted. More sprites can be added here later.','Pokémon-Sprites herunterladen oder eine Paketdatei importieren. Installierte Pakete zeigen ihren Status und lassen sich löschen. Weitere Sprites kannst du hier später hinzufügen.')
    end
    return result
  end
  local menu=make("vasc_pokemon_hd_downloads",tr("SPRITE DOWNLOADS","SPRITE-DOWNLOADS"),rows,function(row)
    if row.action=='all'then return downloadSelection()end
    if row.action=='maintenance'then return maintenanceMenu()end
    if row.group then return groupsMenu(row.group) end
    if row.import then return importMenu(row.import) end
    if row.action=="packageImport" then
      if busy() then return notice("busy_or_restart_required") end
      return session:openPackageImport()
    end
    if row.action=='startupPrompt' then
      local ok,err=session:setStartupPrompt(session.promptDisabled);if not ok then return notice(err)end
      return
    end
    if row.action=="status" then return session:openStatus() end
    if row.action=="diagnostics" then return session:openDiagnostics() end
  end)
  function menu:downloadAll()return downloadSelection()end
  function menu:openCategory(id)
    for _,g in ipairs(categoryGroups())do if g.id==id then
      if #g.children==1 then return groupsMenu(g.children[1])end
      if #g.children>1 then return groupsMenu(g)end
    end end
    return notice('not_yet_available')
  end
  function menu:openFamily(id)
    if not id:match('^pokemon%-hd%-')then return self:openCategory('pokemon')end
    for _,g in ipairs(session.model:groups())do if g.id==id then return groupsMenu(g)end end
    return notice('not_yet_available')
  end
  -- Reopening the screen always refreshes verified installation state. The host
  -- refreshes submenus on session epoch changes, preserving stable row IDs/focus.
  return menu
end
return M
